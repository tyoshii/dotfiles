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

# vim plugin
curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > /tmp/install.sh
sh /tmp/install.sh
rm -rf /tmp/install.sh

mkdir -p ~/.vim/bundle/

git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim
git clone https://github.com/Shougo/vimproc ~/.vim/bundle/vimproc
