#!/bin/bash

rm ~/.vimrc
rm ~/.bashrc
rm ~/.gitconfig
rm ~/.gitignore
rm -rf ~/.vim

PWD=`pwd`

ln -s $PWD/_vimrc ~/.vimrc
ln -s $PWD/_bashrc ~/.bashrc
ln -s $PWD/_bash_profile ~/.bash_profile
ln -s $PWD/_gitconfig ~/.gitconfig
ln -s $PWD/_gitignore ~/.gitignore

mkdir -p ~/.vim/
ln -s $PWD/_vim/filetype.vim ~/.vim/filetype.vim
ln -s $PWD/_vim/syntax ~/.vim/syntax

sh golang.sh
