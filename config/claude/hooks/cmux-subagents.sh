#!/bin/bash
# メインの裏で動いているもの（サブエージェント・バックグラウンドのシェル）の件数を cmux サイドバーへ送る。
# cmux はどちらも把握しないため、フックで自前で数える。
#  - サブエージェント: SubagentStart/Stop で増減。~/.cache/cmux-subagents/<workspace>/<surface>__<session>__<agent_id>（1ファイル=1件）
#  - バックグラウンドのシェル: 終了を知らせるフックが無いので、ターンが終わる（Stop）たびに
#    claude の子プロセスにいる Bash ツールのシェルを数え直す。シェルが終わると Claude が再開し、
#    また Stop が来るので数え直される。~/.cache/cmux-subagents/<workspace>/shells/<surface>__<session>（中身="待ち件数 サーバー件数"）
#    ポートを LISTEN しているシェル（dev server など）は終わらないので「サーバー」として別に数え、待ちに含めない。
#    サーバーは起動してからポートを開くまで時間がかかるので、Stop の少し後にもう一度数え直す。
#  - メインの手が空いたか: cmux は裏でサブエージェントが動いている間、ターンが終わっても working のままにする。
#    Stop で印を付け、UserPromptSubmit とサブエージェントの終了（メインが再開する）で外す。
#    ~/.cache/cmux-subagents/<workspace>/idle/<surface>__<session>
[ -z "$CMUX_WORKSPACE_ID" ] && exit 0
command -v cmux >/dev/null || exit 0

# Stop の後の数え直し（自分自身を裏で呼ぶ）: CMUX_RECOUNT_PID に claude の PID が入っている
if [ -n "$CMUX_RECOUNT_PID" ]; then
  input='{"hook_event_name":"Recount","session_id":"'"$CMUX_RECOUNT_SESSION"'"}'
else
  input=$(cat)
fi
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
agent=$(printf '%s' "$input" | jq -r '.agent_id // empty')
surface="${CMUX_SURFACE_ID:-nosurface}"

dir="$HOME/.cache/cmux-subagents/$CMUX_WORKSPACE_ID"
shells="$dir/shells"
idle="$dir/idle"
mkdir -p "$shells" "$idle"
# 取りこぼし対策: 3時間以上前のものは終わったとみなす
find "$dir" -type f -mmin +180 -delete 2>/dev/null

# このフックを起動した claude プロセスの PID（親をたどって探す）
claude_pid() {
  local pid=$PPID
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    case "$(ps -o comm= -p "$pid" 2>/dev/null)" in
      *claude*) echo "$pid"; return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

# 子孫プロセスの PID（自分を含む）
descendants() {
  echo "$1"
  for c in $(pgrep -P "$1" 2>/dev/null); do descendants "$c"; done
}

# claude の子にいる Bash ツールのシェルを「待ち」と「サーバー（ポートを LISTEN）」に分けて記録する
count_shells() {
  local pid=$1 wait=0 serve=0 sh pids
  for sh in $(pgrep -P "$pid" -f 'shell-snapshots/snapshot-' 2>/dev/null); do
    pids=$(descendants "$sh" | paste -sd, -)
    if lsof -nP -a -iTCP -sTCP:LISTEN -p "$pids" >/dev/null 2>&1; then
      serve=$((serve + 1))
    else
      wait=$((wait + 1))
    fi
  done
  if [ $((wait + serve)) -gt 0 ]; then
    echo "$wait $serve" > "$shells/${surface}__${session}"
  else
    rm -f "$shells/${surface}__${session}"
  fi
  [ "$wait" -gt 0 ]
}

case "$event" in
  SubagentStart)
    touch "$dir/${surface}__${session}__${agent:-$(date +%s%N)}" ;;
  UserPromptSubmit)
    rm -f "$idle/${surface}__${session}" ;;
  SubagentStop)
    rm -f "$idle/${surface}__${session}"
    if [ -n "$agent" ] && [ -e "$dir/${surface}__${session}__${agent}" ]; then
      rm -f "$dir/${surface}__${session}__${agent}"
    else
      # agent_id で対応が取れないときは、そのセッションの一番古いものを消す
      oldest=$(ls -tr "$dir" 2>/dev/null | grep "__${session}__" | head -1)
      [ -n "$oldest" ] && rm -f "$dir/$oldest"
    fi ;;
  Stop)
    touch "$idle/${surface}__${session}"
    # Bash ツールのコマンドはシェルスナップショットを読み込んでから動く
    pid=$(claude_pid)
    if [ -n "$pid" ] && count_shells "$pid"; then
      # 待ちに数えたシェルが後からポートを開くかもしれないので、少し後に数え直す
      CMUX_RECOUNT_PID=$pid CMUX_RECOUNT_SESSION=$session \
        nohup bash -c 'sleep 20; exec bash "$0"' "$0" </dev/null >/dev/null 2>&1 &
    fi ;;
  Recount)
    kill -0 "$CMUX_RECOUNT_PID" 2>/dev/null || exit 0
    # 次のターンが始まっていたら、そちらの Stop に任せる（ファイルが消えていれば何もしない）
    [ -e "$shells/${surface}__${session}" ] || exit 0
    count_shells "$CMUX_RECOUNT_PID" ;;
  SessionEnd|SessionStart)
    rm -f "$dir"/*"__${session}__"* "$shells/${surface}__${session}" "$idle/${surface}__${session}" 2>/dev/null ;;
esac

# 送り先:
#  - set-status claude_subagents: 標準サイドバー用の紫ピル
#  - set-progress のラベル: 自作サイドバー用（status はサイドバーのデータに載らないため）。
#    形式 "裏 N件 実行中 · <panelId>=<サブ件数>/<待ちシェル件数>/<サーバー件数>/<メインの手が空いていれば1>,..."
subs=$(find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
nshell=$(cat "$shells"/* 2>/dev/null | awk '{s+=$1} END {print s+0}')
nserve=$(cat "$shells"/* 2>/dev/null | awk '{s+=$2} END {print s+0}')
total=$((subs + nshell + nserve))
if [ "$total" -gt 0 ]; then
  per=$(
    {
      find "$dir" -maxdepth 1 -type f -exec basename {} \; | sed 's/__.*//' | awk '{print $1, 1, 0, 0, 0}'
      for f in "$shells"/*; do [ -f "$f" ] && echo "$(basename "$f" | sed 's/__.*//') 0 $(cat "$f") 0 0"; done
      for f in "$idle"/*; do [ -f "$f" ] && echo "$(basename "$f" | sed 's/__.*//') 0 0 0 1"; done
    } | awk '{s[$1]+=$2; b[$1]+=$3; v[$1]+=$4; i[$1]+=$5} END {for (k in s) if (s[k]+b[k]+v[k] > 0) printf "%s%s=%d/%d/%d/%d", (n++?",":""), k, s[k], b[k], v[k], (i[k]>0)}'
  )
  label=""
  [ "$subs" -gt 0 ] && label="サブ ${subs}件"
  [ "$nshell" -gt 0 ] && label="${label:+$label · }シェル ${nshell}件"
  # サブエージェントがいれば紫（Claude が裏で作業中）、シェルだけなら水色（コマンドの終わりを待っているだけ）
  # サーバーだけなら手は空いているので、ピルは出さない
  if [ $((subs + nshell)) -eq 0 ]; then
    cmux clear-status claude_subagents >/dev/null 2>&1
  elif [ "$subs" -gt 0 ]; then
    cmux set-status claude_subagents "${label} 実行中" --icon person.2.fill --color "#BF5AF2" --priority 90 >/dev/null 2>&1
  else
    cmux set-status claude_subagents "シェル ${nshell}件待ち" --icon terminal.fill --color "#64D2FF" --priority 90 >/dev/null 2>&1
  fi
  cmux set-progress 0 --label "裏 ${total}件 実行中 · ${per}" >/dev/null 2>&1
else
  cmux clear-status claude_subagents >/dev/null 2>&1
  cmux clear-progress >/dev/null 2>&1
fi
exit 0
