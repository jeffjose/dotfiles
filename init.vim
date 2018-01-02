" Transition from vim -> neovim
"
" Keep this file inside ~/.config/nvim/ as init.vim
"
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
