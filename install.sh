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

deps=(starship mise)
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

# ─── Claude Code ──────────────────────────────────────
mkdir -p "$HOME/.claude"
link "$DOTFILES/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
if [ -f "$HOME/.claude/settings.json" ]; then
  cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak"
  echo "  backup: ~/.claude/settings.json → ~/.claude/settings.json.bak"
fi
sed "s|__HOME__|$HOME|g" "$DOTFILES/config/claude/settings.json.tpl" > "$HOME/.claude/settings.json"
echo "  generated: ~/.claude/settings.json"

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
