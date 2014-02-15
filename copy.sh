#!/bin/bash

cp _vimrc ~/.vimrc
cp _bashrc ~/.bashrc
cp _gitconfig ~/.gitconfig

mkdir -p ~/.vim/syntax/
cp _vim/syntax/* ~/.vim/syntax/
