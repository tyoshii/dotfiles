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

# ─── Symlinks ──────────────────────────────────────────
link "$DOTFILES/zshrc"               "$HOME/.zshrc"
link "$DOTFILES/zprofile"            "$HOME/.zprofile"
link "$DOTFILES/gitconfig"           "$HOME/.gitconfig"
link "$DOTFILES/gitignore"           "$HOME/.gitignore"
link "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"

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
