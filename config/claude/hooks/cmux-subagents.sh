#!/bin/bash
# メインの裏で動いているもの（サブエージェント・バックグラウンドのシェル）の件数を cmux サイドバーへ送る。
# cmux はどちらも把握しないため、フックで自前で数える。
#  - サブエージェント: SubagentStart/Stop で増減。~/.cache/cmux-subagents/<workspace>/<surface>__<session>__<agent_id>（1ファイル=1件）
#  - バックグラウンドのシェル: 終了を知らせるフックが無いので、ターンが終わる（Stop）たびに
#    claude の子プロセスにいる Bash ツールのシェルを数え直す。シェルが終わると Claude が再開し、
#    また Stop が来るので数え直される。~/.cache/cmux-subagents/<workspace>/shells/<surface>__<session>（中身=件数）
[ -z "$CMUX_WORKSPACE_ID" ] && exit 0
command -v cmux >/dev/null || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
agent=$(printf '%s' "$input" | jq -r '.agent_id // empty')
surface="${CMUX_SURFACE_ID:-nosurface}"

dir="$HOME/.cache/cmux-subagents/$CMUX_WORKSPACE_ID"
shells="$dir/shells"
mkdir -p "$shells"
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

case "$event" in
  SubagentStart)
    touch "$dir/${surface}__${session}__${agent:-$(date +%s%N)}" ;;
  SubagentStop)
    if [ -n "$agent" ] && [ -e "$dir/${surface}__${session}__${agent}" ]; then
      rm -f "$dir/${surface}__${session}__${agent}"
    else
      # agent_id で対応が取れないときは、そのセッションの一番古いものを消す
      oldest=$(ls -tr "$dir" 2>/dev/null | grep "__${session}__" | head -1)
      [ -n "$oldest" ] && rm -f "$dir/$oldest"
    fi ;;
  Stop)
    pid=$(claude_pid)
    # Bash ツールのコマンドはシェルスナップショットを読み込んでから動く
    n=0
    [ -n "$pid" ] && n=$(pgrep -P "$pid" -f 'shell-snapshots/snapshot-' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -gt 0 ]; then
      echo "$n" > "$shells/${surface}__${session}"
    else
      rm -f "$shells/${surface}__${session}"
    fi ;;
  SessionEnd|SessionStart)
    rm -f "$dir"/*"__${session}__"* "$shells/${surface}__${session}" 2>/dev/null ;;
esac

# 送り先:
#  - set-status claude_subagents: 標準サイドバー用の紫ピル
#  - set-progress のラベル: 自作サイドバー用（status はサイドバーのデータに載らないため）。
#    形式 "裏 N件 実行中 · <panelId>=<サブ件数>/<シェル件数>,..."
subs=$(find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
nshell=$(cat "$shells"/* 2>/dev/null | awk '{s+=$1} END {print s+0}')
total=$((subs + nshell))
if [ "$total" -gt 0 ]; then
  per=$(
    {
      find "$dir" -maxdepth 1 -type f -exec basename {} \; | sed 's/__.*//' | awk '{print $1, 1, 0}'
      for f in "$shells"/*; do [ -f "$f" ] && echo "$(basename "$f" | sed 's/__.*//') 0 $(cat "$f")"; done
    } | awk '{s[$1]+=$2; b[$1]+=$3} END {for (k in s) printf "%s%s=%d/%d", (n++?",":""), k, s[k], b[k]}'
  )
  label=""
  [ "$subs" -gt 0 ] && label="サブ ${subs}件"
  [ "$nshell" -gt 0 ] && label="${label:+$label · }シェル ${nshell}件"
  cmux set-status claude_subagents "${label} 実行中" --icon person.2.fill --color "#BF5AF2" --priority 90 >/dev/null 2>&1
  cmux set-progress 0 --label "裏 ${total}件 実行中 · ${per}" >/dev/null 2>&1
else
  cmux clear-status claude_subagents >/dev/null 2>&1
  cmux clear-progress >/dev/null 2>&1
fi
exit 0
