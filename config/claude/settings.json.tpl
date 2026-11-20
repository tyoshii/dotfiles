{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "model": "opus",
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
            "command": "python3 __HOME__/.claude/hooks/japanese-guard.py"
          },
          {
            "type": "command",
            "command": "afplay /System/Library/Sounds/Funk.aiff"
          },
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code completed tasks.\" with title \"Claude Code\"'"
          },
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo '返答・途中経過の報告はすべて日本語で書くこと。'"
          },
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash __HOME__/.claude/skills/playwright-cli/scripts/post-close-reminder.sh",
            "if": "Bash(*playwright-cli*close*)"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash __HOME__/.claude/hooks/cmux-subagents.sh",
            "async": true
          }
        ]
      }
    ],
    "WorktreeCreate": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "command vibe start \"$(echo $CLAUDE_WORKTREE_NAME)\" --claude-code-worktree-hook"
          }
        ]
      }
    ],
    "WorktreeRemove": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "command vibe clean --force --claude-code-worktree-hook"
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Edit(~/.claude/projects/*/dev-server.yml)"
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
    "slack@cureapp": true,
    "kawaraban@cureapp": true,
    "breach-audit@breach-audit": true
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
    },
    "breach-audit": {
      "source": {
        "source": "directory",
        "path": "__HOME__/github/tyoshii/breach-audit"
      }
    }
  },
  "language": "japanese",
  "alwaysThinkingEnabled": false,
  "effortLevel": "xhigh",
  "modelSettings": {
    "claude-fable-5-1": {
      "effortLevel": "medium"
    },
    "claude-opus-5": {
      "effortLevel": "medium"
    },
    "claude-opus-5-5": {
      "effortLevel": "medium"
    }
  },
  "autoUpdatesChannel": "latest",
  "tui": "fullscreen",
  "skipDangerousModePermissionPrompt": true,
  "switchModelsOnFlag": false,
  "inputNeededNotifEnabled": true,
  "agentPushNotifEnabled": true,
  "voiceEnabled": true,
  "feedbackSurveyState": {
    "lastShownTime": 1756691160246
  }
}
