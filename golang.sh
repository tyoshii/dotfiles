#!/bin/sh

mkdir -p $HOME/.vim/ftdetect
mkdir -p $HOME/.vim/syntax
mkdir -p $HOME/.vim/autoload/go

rm -rf $HOME/.vim/ftdetect/gofiletype.vim
rm -rf $HOME/.vim/syntax/go.vim
rm -rf $HOME/.vim/autoload/go/complete.vim

ln -s /usr/local/go/misc/vim/ftdetect/gofiletype.vim $HOME/.vim/ftdetect/
ln -s /usr/local/go/misc/vim/syntax/go.vim $HOME/.vim/syntax
ln -s /usr/local/go/misc/vim/autoload/go/complete.vim $HOME/.vim/autoload/go

# https://github.com/jnwhiteh/vim-golang
