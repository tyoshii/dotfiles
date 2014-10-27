set nocompatible
set backspace=indent,eol,start

syntax on

"colorscheme pablo
hi Constant cterm=bold
hi Special cterm=bold
hi Comment cterm=bold ctermfg=green
hi Identifier cterm=bold
hi Statement cterm=bold
hi PreProc cterm=bold
hi Type cterm=bold
hi Error cterm=bold
hi Question cterm=bold
hi VertSplit cterm=bold
hi LineNr cterm=bold
hi ModeMsg cterm=bold ctermfg=yellow
hi Directory cterm=bold ctermfg=DarkRed

hi StorageClass cterm=bold ctermfg=yellow
hi Structure cterm=bold ctermfg=yellow
"hi Delimiter cterm=none ctermfg=none
highlight Pmenu ctermbg=4
highlight PmenuSel ctermbg=1
highlight PMenuSbar ctermbg=4

set termencoding=utf-8
set encoding=utf-8
set fileencodings=utf-8,cp932,iso-2022-jp,euc-jp
set ambiwidth=double

" tab
set tabstop=4
set expandtab
autocmd FileType cpp set tabstop=2
autocmd FileType php set tabstop=2
autocmd FileType php set noexpandtab
autocmd FileType html set tabstop=2
autocmd FileType htmljinja set tabstop=2
autocmd FileType css set tabstop=2
autocmd FileType ant set tabstop=2
autocmd FileType javascript set tabstop=2

" 表示関連
set showmatch
set showmode
set hlsearch
set ruler
set laststatus=2
set statusline=%y%{GetStatusEx()}%F%m%r%=<%l:%c>
hi StatusLine term=NONE cterm=NONE ctermfg=black ctermbg=white

" コマンドライン補完
set wildmenu 
set wildmode=list:longest

" 外部編集された際自リロ
set autoread

" バックアップ取らない
set nobackup

" 検索系
set magic
set incsearch
set ignorecase
set smartcase
set wrapscan

" 履歴
set history=50

" 関数
function! GetStatusEx()
let str = ''
let str = str . '' . &fileformat . ']'
if has('multi_byte') && &fileencoding != ''
let str = '[' . &fileencoding . ':' . str
else
let str = '[' . &encoding . ':' . str
endif
return str
endfunction

" git
autocmd BufNewFile,BufRead COMMIT_EDITMSG set filetype=git
autocmd FileType git :set fileencoding=utf-8

