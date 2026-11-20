#!/bin/bash
# サブエージェント（バックグラウンドエージェント含む）の実行数を cmux サイドバーへ送る。
# cmux は Claude Code のサブエージェントを把握しないため、SubagentStart/Stop で自前で数える。
# 状態: ~/.cache/cmux-subagents/<workspace>/<surface>__<session>__<agent_id>（1ファイル=実行中1件）
[ -z "$CMUX_WORKSPACE_ID" ] && exit 0
command -v cmux >/dev/null || exit 0

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // "nosession"')
agent=$(printf '%s' "$input" | jq -r '.agent_id // empty')
surface="${CMUX_SURFACE_ID:-nosurface}"

dir="$HOME/.cache/cmux-subagents/$CMUX_WORKSPACE_ID"
mkdir -p "$dir"
# 取りこぼし対策: 3時間以上前のものは終わったとみなす
find "$dir" -type f -mmin +180 -delete 2>/dev/null

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
  SessionEnd|SessionStart)
    rm -f "$dir"/*"__${session}__"* 2>/dev/null ;;
esac

# 送り先:
#  - set-status claude_subagents: 標準サイドバー用の紫ピル
#  - set-progress のラベル: 自作サイドバー用（status はサイドバーのデータに載らないため）。
#    形式 "サブ N件 実行中 · <panelId>=<件数>,..."
total=$(ls "$dir" 2>/dev/null | wc -l | tr -d ' ')
if [ "$total" -gt 0 ]; then
  per=$(ls "$dir" | sed 's/__.*//' | sort | uniq -c | awk '{printf "%s%s=%s", (NR>1?",":""), $2, $1}')
  cmux set-status claude_subagents "サブ ${total}件 実行中" --icon person.2.fill --color "#BF5AF2" --priority 90 >/dev/null 2>&1
  cmux set-progress 0 --label "サブ ${total}件 実行中 · ${per}" >/dev/null 2>&1
else
  cmux clear-status claude_subagents >/dev/null 2>&1
  cmux clear-progress >/dev/null 2>&1
fi
exit 0
