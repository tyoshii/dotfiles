if exists("did_load_filetypes")
  finish
endif
augroup filetypedetect

 au BufRead,BufNewFile *.py setf python
 au BufRead,BufNewFile *.php setf php
 au BufRead,BufNewFile *.twig set filetype=htmljinja

 " *.t perl test file
 au BufReadPost,BufNewFile *.t setf perl

augroup END
