source ~/.config/nvim/plugins.vim

""""""""""""""""""""""""""'
" Keybindings

let mapleader = "_"

" Ctrl-P opens fzf
map <C-p> :Files<CR>

" Space removes the highlight
nmap <Space> :nohlsearch<CR>

" Play with pairs!
imap () ()<left>
imap [] []<left>
imap <> <><left>
imap {} {}<left>
imap "" ""<left>
imap '' ''<left>

" Toggle line numbers
map <F12> :set number!<CR>

" Paste Toggle
map <F5> :set paste!<CR>

" python debug
iab pdb import pdb; pdb.set_trace()<Right><Esc>


" Move around split windows quickly
nmap <c-j> <c-w>j
nmap <c-k> <c-w>k
nmap <c-h> <c-w>h
nmap <c-l> <c-w>l

" Move between buffers
nmap <Tab> :bn<CR>
nmap <S-Tab> :bp<CR>

""""""""""""""""""""""""""'
" Editor config

" Automatically indent when adding a curly bracket, etc.
set autoindent

" Automatically detect file types
filetype plugin indent on
filetype on

" Enable syntax highlighting
" syntax on " Enabled in plugins.vim

" Tabs should be converted to a group of 4 spaces
set ts=2 sw=2 expandtab
set autoindent

set timeoutlen=300 " http://stackoverflow.com/questions/2158516/delay-before-o-opens-a-new-line

" Show line number, cursor position
set ruler

" Ruler format
set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%)

" Display incplete commands
set showcmd

" With lightline plugin, you dont need `--INSERT` text
set noshowmode

" Better search
set incsearch
set ignorecase
set smartcase
set gdefault


" Wildmenu/autocomplete settings
set wildmenu
set wildmode=list:longest
set wildignore=.hg,.svn,*~,*.png,*.jpg,*.gif,*.settings,Thumbs.db,*.min.js,*.swp,publish/*,intermediate/*,*.o,*.hi,Zend,vendor

" Disable the blinking cursor
set gcr=a:blinkon0

" Show matching brackets
set showmatch

" Disable mouse
set mouse=

" Format statusline
set laststatus=2
"set statusline=\ -%n-\ %<%F%h%m%r%h%w\ %=\ -%Y-%w\%=\ -(%l/%L)-%c-\ %P

" Remove trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e


""""""""""""""""""""""""""'
" Color stuff

" Adapted from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
"
set t_Co=256

if (match($TERM, "-256color") != -1) && (match($TERM, "screen-256color") == -1)
  " screen does not (yet) support truecolor
  " set termguicolors
endif

set background=dark
" let base16colorspace=256 " Unset this because of the blue bar at the bottom
let g:base16_shell_path="~/base16/templates/shell/scripts/"
colorscheme base16-onedark
syntax on
hi Normal ctermbg=NONE

" Customize colors
" Make comments more prominent
call Base16hi("Comment", g:base16_gui08, "", g:base16_cterm08, "", "", "")


""""""""""""""""""""""""""'
" Language settings

" Rust settings
let g:rustfmt_autosave = 1
let g:rustfmt_emit_files = 1
let g:rustfmt_fail_silently = 0
let g:rust_clip_command = 'xclip -selection clipboard'

