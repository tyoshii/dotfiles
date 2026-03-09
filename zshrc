# ─── PATH ──────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ─── History ────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # セッション間で履歴を共有
setopt HIST_IGNORE_ALL_DUPS   # 重複を削除
setopt HIST_IGNORE_SPACE      # スペース始まりのコマンドを記録しない
setopt HIST_REDUCE_BLANKS     # 余分な空白を削除

# ─── Completion ─────────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 大文字小文字を無視
zstyle ':completion:*' menu select                     # メニュー選択
zstyle ':completion:*' list-colors ''                  # 色付き補完

# ─── Key Bindings ───────────────────────────────────────
bindkey -e                          # Emacs キーバインド
bindkey '^[[A' history-search-backward   # ↑ で履歴検索
bindkey '^[[B' history-search-forward    # ↓ で履歴検索

# ─── Options ────────────────────────────────────────────
setopt AUTO_CD                # ディレクトリ名だけで cd
setopt AUTO_PUSHD             # cd 時に自動で pushd
setopt PUSHD_IGNORE_DUPS      # pushd の重複を無視
setopt CORRECT                # コマンドのtypo修正を提案
setopt INTERACTIVE_COMMENTS   # インタラクティブシェルでもコメントを許可

# ─── Aliases: General ───────────────────────────────────
alias ll='ls -lAFh'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias mkdir='mkdir -pv'
alias grep='grep --color=auto'
alias path='echo -e ${PATH//:/\\n}'

# ─── Aliases: Git ───────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -30'
alias gp='git push'
alias gpl='git pull'
alias gst='git stash'
alias gstp='git stash pop'

# ─── Title Bar ──────────────────────────────────────────
# ターミナルのタイトルバーに「コマンド名 - カレントディレクトリ」を表示
function set_terminal_title_precmd() {
  print -Pn "\e]0;%~\a"
}
function set_terminal_title_preexec() {
  print -Pn "\e]0;${1%% *} - %~\a"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd set_terminal_title_precmd
add-zsh-hook preexec set_terminal_title_preexec

# ─── RPROMPT ────────────────────────────────────────────
# 右プロンプトに時刻を表示（コマンド入力時に自動で消える）
setopt TRANSIENT_RPROMPT
RPROMPT='%F{240}%*%f'

# ─── Starship Prompt ───────────────────────────────────
eval "$(starship init zsh)"

# ─── Local ─────────────────────────────────────────────
[ -f "$HOME/.zshrc_local" ] && source "$HOME/.zshrc_local"

# mise (version manager)
eval "$(mise activate zsh)"

# vibe (worktree auto-cd)
eval "$(vibe shell-setup)"
