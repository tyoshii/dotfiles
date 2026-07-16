{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "model": "claude-opus-4-6",
  "hooks": {
    "PreToolUse": [],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Ping.aiff"
          },
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code is waiting for you.\" with title \"Claude Code\"'"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Funk.aiff"
          },
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code completed tasks.\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "__HOME__/.claude/statusline.sh"
  },
  "enabledPlugins": {
    "ai-usage-collector@cureapp": true,
    "gws@cureapp": true,
    "rewrite-claude-md@cureapp": true,
    "grow-rules@cureapp": true,
    "cc-source-inspector@cureapp": true,
    "frontend-design@claude-plugins-official": true,
    "reskill@cureapp": true,
    "refine@cureapp": true,
    "pinned-actions-manager@cureapp": true,
    "genshijin@genshijin": false,
    "slack@cureapp": true
  },
  "extraKnownMarketplaces": {
    "cureapp": {
      "source": {
        "source": "github",
        "repo": "CureApp/claude-skills"
      }
    },
    "genshijin": {
      "source": {
        "source": "github",
        "repo": "InterfaceX-co-jp/genshijin"
      }
    }
  },
  "language": "japanese",
  "alwaysThinkingEnabled": false,
  "effortLevel": "xhigh",
  "autoUpdatesChannel": "latest",
  "tui": "fullscreen",
  "skipDangerousModePermissionPrompt": true,
  "voiceEnabled": true,
  "feedbackSurveyState": {
    "lastShownTime": 1756691160246
  }
}
