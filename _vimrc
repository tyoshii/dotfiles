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
autocmd FileType ruby set tabstop=2
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

" ejs
autocmd BufNewFile,BufRead *.ejs set filetype=ejs
autocmd BufNewFile,BufRead *._ejs set filetype=ejs

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

" NeoBundle
 " Note: Skip initialization for vim-tiny or vim-small.
 if 0 | endif

 if has('vim_starting')
   if &compatible
     set nocompatible               " Be iMproved
   endif

   " Required:
   set runtimepath+=~/.vim/bundle/neobundle.vim/
 endif

 " Required:
 call neobundle#begin(expand('~/.vim/bundle/'))

 " Let NeoBundle manage NeoBundle
 " Required:
 NeoBundleFetch 'Shougo/neobundle.vim'

 " My Bundles here:
 " Refer to |:NeoBundle-examples|.
 " Note: You don't set neobundle setting in .gvimrc!

 " snippet
 NeoBundle 'Shougo/neocomplcache'
 NeoBundle 'Shougo/neosnippet'
 NeoBundle 'Shougo/neosnippet-snippets'

 "" snippet keybind
 " Plugin key-mappings.
 imap <C-k>     <Plug>(neosnippet_expand_or_jump)
 smap <C-k>     <Plug>(neosnippet_expand_or_jump)
 xmap <C-k>     <Plug>(neosnippet_expand_target)
 
 " SuperTab like snippets behavior.
 "imap <expr><TAB>
 " \ pumvisible() ? "\<C-n>" :
 " \ neosnippet#expandable_or_jumpable() ?
 " \    "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
 smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
 \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"
 
 " For conceal markers.
 if has('conceal')
   set conceallevel=2 concealcursor=niv
   endif
 
 "" snippet dir
 let g:neosnippet#snippets_directory='~/.vim/snippets/'

 " ejs syntax
 NeoBundle 'nikvdp/ejs-syntax'

 " rubocop
 NeoBundle 'scrooloose/syntastic'
 let g:syntastic_mode_map = { 'mode': 'passive',
             \ 'active_filetypes': ['ruby'] }
 let g:syntastic_ruby_checkers = ['rubocop']

 call neobundle#end()

 " Required:
 filetype plugin indent on

 " If there are uninstalled bundles found on startup,
 " this will conveniently prompt you to install them.
 NeoBundleCheck
