#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# ─── Helper ────────────────────────────────────────────
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    echo "  backup: $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  fi
  ln -s "$src" "$dst"
  echo "  linked: $dst → $src"
}

echo "=== dotfiles install ==="

# ─── Dependencies ─────────────────────────────────────
echo "--- dependencies ---"

if ! command -v brew &>/dev/null; then
  echo "  installing: Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
else
  echo "  found: brew"
fi

deps=(starship mise jq)
for dep in "${deps[@]}"; do
  if ! command -v "$dep" &>/dev/null; then
    echo "  installing: $dep"
    brew install "$dep"
  else
    echo "  found: $dep"
  fi
done

# ─── Symlinks ──────────────────────────────────────────
link "$DOTFILES/zshrc"               "$HOME/.zshrc"
link "$DOTFILES/zprofile"            "$HOME/.zprofile"
link "$DOTFILES/gitconfig"           "$HOME/.gitconfig"
link "$DOTFILES/gitignore"           "$HOME/.gitignore"
link "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"
link "$DOTFILES/config/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"
link "$DOTFILES/config/ghostty/config" "$HOME/.config/ghostty/config"
# Ghostty.app 専用 / cmux 専用の上書き設定（それぞれ相手には読まれない場所に置く）
link "$DOTFILES/config/ghostty/ghostty-only.ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
link "$DOTFILES/config/cmux/cmux-only.ghostty" "$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
link "$DOTFILES/config/cmux/sidebars/status-colors.js" "$HOME/.config/cmux/sidebars/status-colors.js"

# ─── Claude Code ──────────────────────────────────────
mkdir -p "$HOME/.claude"
link "$DOTFILES/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link "$DOTFILES/config/claude/hooks/cmux-subagents.sh" "$HOME/.claude/hooks/cmux-subagents.sh"
link "$DOTFILES/config/claude/hooks/japanese-guard.py" "$HOME/.claude/hooks/japanese-guard.py"
if [ -f "$HOME/.claude/settings.json" ]; then
  cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak"
  echo "  backup: ~/.claude/settings.json → ~/.claude/settings.json.bak"
fi
sed "s|__HOME__|$HOME|g" "$DOTFILES/config/claude/settings.json.tpl" > "$HOME/.claude/settings.json"
echo "  generated: ~/.claude/settings.json"

# ─── cmux ─────────────────────────────────────────────
# 自作サイドバーの選択は cmux.json に持てないため、cmux が起動していれば CLI で選ぶ
if command -v cmux &>/dev/null && cmux sidebar select status-colors &>/dev/null; then
  echo "  selected: cmux sidebar status-colors"
else
  echo "  skip: cmux sidebar select (cmux 起動後に: cmux sidebar select status-colors)"
fi

# ─── SSH (copy, not symlink) ──────────────────────────
mkdir -p "$HOME/.ssh"
cp "$DOTFILES/ssh/config" "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"
echo "  copied: ~/.ssh/config"

# ─── Local overrides ──────────────────────────────────
if [ ! -f "$HOME/.zshrc_local" ]; then
  touch "$HOME/.zshrc_local"
  echo "  created: ~/.zshrc_local (for machine-specific settings)"
fi

if [ ! -f "$HOME/.gitconfig.local" ]; then
  touch "$HOME/.gitconfig.local"
  echo "  created: ~/.gitconfig.local (for machine-specific git settings)"
fi

echo "=== done ==="
