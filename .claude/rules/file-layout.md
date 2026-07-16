# ファイル配置規約

## ファイル名と配置

- ホームディレクトリ直下にリンクするファイル（`.zshrc`, `.gitconfig` 等）はリポジトリルートにドットなしで配置する（例: `zshrc`, `gitconfig`）
- `~/.config/` 配下の設定は `config/` ディレクトリにディレクトリ構造ごとミラー配置する（例: `config/starship.toml`, `config/cmux/cmux.json`, `config/ghostty/config`）
- SSH 設定は `ssh/` ディレクトリに配置する

## 新しい設定ファイルの追加手順

1. リポジトリの適切な場所にファイルを配置する
2. `install.sh` に `link` 行を追加してシンボリックリンクを設定する
3. SSH のようにパーミッション管理が必要なファイルは `cp` + `chmod` を使う

## ローカルオーバーライド

マシン固有の設定は本体に書かず `*.local` ファイルに分離する（例: `.zshrc_local`, `.gitconfig.local`）。本体側でそのファイルを読み込む設定を入れておく。
