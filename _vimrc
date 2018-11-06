".local.vim
augroup vimrc-local
  autocmd!
  autocmd BufNewFile,BufReadPost * call s:vimrc_local(expand('<afile>:p:h'))
  autocmd BufReadPre .local.vim set ft=vim
augroup END

function! s:vimrc_local(loc)
  let files = findfile('.local.vim', escape(a:loc, ' ') . ';', -1)
  for i in reverse(filter(files, 'filereadable(v:val)'))
    source `=i`
  endfor
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set modeline
set nocompatible
set backspace=indent,eol,start
set noswapfile

set termencoding=utf-8
set encoding=utf-8
set fileencodings=utf-8,cp932,iso-2022-jp,euc-jp
set ambiwidth=double

" tab
set tabstop=4
set shiftwidth=4
set expandtab
autocmd FileType cpp set tabstop=2 shiftwidth=2
autocmd FileType ruby set tabstop=2 shiftwidth=2
autocmd FileType html set tabstop=2 shiftwidth=2
autocmd FileType htmljinja set tabstop=2 shiftwidth=2
autocmd FileType css set tabstop=2 shiftwidth=2
autocmd FileType ant set tabstop=2 shiftwidth=2
autocmd FileType javascript set tabstop=2 shiftwidth=2

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

" ejs
autocmd BufNewFile,BufRead *.ejs set filetype=ejs
autocmd BufNewFile,BufRead *._ejs set filetype=ejs

autocmd BufNewFile,BufRead *.vue set filetype=vue
autocmd FileType vue syntax sync fromstart
autocmd FileType vue set tabstop=2 shiftwidth=2

function! s:DetectEjs()
    if getline(1) =~ '^#!.*\<ejs\>'
        set filetype=ejs
    endif
endfunction

autocmd BufNewFile,BufRead * call s:DetectEjs()

" 行末の空白をハイライト
augroup HighlightTrailingSpaces
  autocmd!
  autocmd VimEnter,WinEnter,ColorScheme * highlight TrailingSpaces term=underline guibg=Red ctermbg=Red
  autocmd VimEnter,WinEnter * match TrailingSpaces /\s\+$/
augroup END

""""""""""""""""""""""""""""""
" 最後のカーソル位置を復元する
""""""""""""""""""""""""""""""
if has("autocmd")
    autocmd BufReadPost *
    \ if line("'\"") > 0 && line ("'\"") <= line("$") |
    \   exe "normal! g'\"" |
    \ endif
endif
""""""""""""""""""""""""""""""


""""""""""""""""""""""""""""""
" プラグインのセットアップ
""""""""""""""""""""""""""""""
call plug#begin('~/.vim/plugged')

" インデントに色を付けて見やすくする
Plug 'nathanaelkane/vim-indent-guides'
" vimを立ち上げたときに、自動的にvim-indent-guidesをオンにする
let g:indent_guides_enable_on_vim_startup = 1

" php indent
Plug '2072/PHP-Indenting-for-VIm'

" color scheme
Plug 'tomasr/molokai'
Plug 'posva/vim-vue'

" comment out
Plug 'tomtom/tcomment_vim'

" syntax
Plug 'w0rp/ale'
let g:ale_lint_on_text_changed = 0

" closetag
Plug 'alvan/vim-closetag'
let g:closetag_filenames = '*.html,*.vue'

" vim-over
Plug 'osyo-manga/vim-over'
" 全体置換
nnoremap <silent> <space>o :OverCommandLine<CR>%s//g<Left><Left>
" 選択範囲置換
vnoremap <silent> <space>o :OverCommandLine<CR>s//g<Left><Left>
" カーソルしたの単語置換
nnoremap sub :OverCommandLine<CR>%s/<C-r><C-w>//g<Left><Left>

call plug#end()
""""""""""""""""""""""""""""""

syntax enable
colorscheme molokai " カラースキームにmolokaiを設定する
