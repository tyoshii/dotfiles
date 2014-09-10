#!/bin/bash

PWD=`pwd`

# reset
rm ~/.vimrc
rm ~/.bashrc
rm ~/.gitconfig
rm ~/.gitignore
rm -rf ~/.vim/

# mkdir
mkdir -p ~/.vim/syntax/

# symlink
ln -s "${PWD}/_vimrc"     ~/.vimrc
ln -s "${PWD}/_bashrc"    ~/.bashrc
ln -s "${PWD}/_gitconfig" ~/.gitconfig
ln -s "${PWD}/_gitignore" ~/.gitignore

ln -s "${PWD}/_vim/filetype.vim"         ~/.vim/filetype.vim
ln -s "${PWD}/_vim/syntax/htmljinja.vim" ~/.vim/syntax/htmljinja.vim
ln -s "${PWD}/_vim/syntax/jinja.vim"     ~/.vim/syntax/jinja.vim

# golang
sh golang.sh
