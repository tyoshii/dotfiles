#!/bin/bash

# rm old file/dir
if [ -e ~/.vimrc ]; then
    rm ~/.vimrc
fi
if [ -e ~/.bashrc ]; then
    rm ~/.bashrc
fi
if [ -e ~/.bash_profile ]; then
    rm ~/.bash_profile
fi
if [ -e ~/.gitconfig ]; then
    rm ~/.gitconfig
fi
if [ -e ~/.gitignore ]; then
    rm ~/.gitignore
fi
if [ -e ~/.vim ]; then
    rm -rf ~/.vim
fi

PWD=`pwd`

# install neobundle
curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > install.sh
sh ./install.sh
rm install.sh

# symbolic link
ln -s $PWD/_vimrc ~/.vimrc
ln -s $PWD/_bashrc ~/.bashrc
ln -s $PWD/_bash_profile ~/.bash_profile
ln -s $PWD/_gitconfig ~/.gitconfig
ln -s $PWD/_gitignore ~/.gitignore

mkdir -p ~/.vim/
ln -s $PWD/_vim/filetype.vim ~/.vim/filetype.vim
ln -s $PWD/_vim/syntax ~/.vim/syntax

# about golang
sh golang.sh
