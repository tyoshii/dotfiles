#!/bin/bash

cp _vimrc ~/.vimrc
cp _bashrc ~/.bashrc
cp _gitconfig ~/.gitconfig
cp _gitignore ~/.gitignore

mkdir -p ~/.vim/syntax/
cp _vim/syntax/* ~/.vim/syntax/

sh golang.sh
