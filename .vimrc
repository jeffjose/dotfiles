" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" Use the 'google' package by default (see http://go/vim/packages).
" This doesnt work in laptops
"source ~/.vim/google.vim

" Automatically indent when adding a curly bracket, etc.
set autoindent
"set cindent
"set cinkeys-=0#
"set indentkeys-=0#
"set nosmartindent

" Automatically detect file types
filetype plugin indent on
filetype on

" Enable syntax highlighting.
syntax on

" Tabs should be converted to a group of 4 spaces.
" This is the official Python convention
" (http://www.python.org/dev/peps/pep-0008/)
" I didn't find a good reason to not use it everywhere.
" Studio uses the same convention
set ts=2 sw=2 expandtab

autocmd FileType html :setlocal sw=2 ts=2 sts=2 expandtab
autocmd FileType coffee :setlocal sw=2 ts=2 sts=2 expandtab
autocmd FileType js :setlocal sw=2 ts=2 sts=2 expandtab
autocmd FileType vue :setlocal sw=2 ts=2 sts=2 expandtab

"set shiftwidth=4
"set tabstop=4
"set expandtab
set smarttab

" Show line number, cursor position.
set ruler

" Ruler Format
set rulerformat=%30(%=\:b%n%y%m%r%w\ %l,%c%V\ %P%)

" Display incomplete commands.
set showcmd

" Search as you type.
set incsearch

" Ignore case when searching.
set ignorecase

" Show autocomplete menus.
set wildmenu

" Auto format comment blocks
set comments=sl:/*,mb:*,elx:*/

" Disable the blinking cursor
set gcr=a:blinkon0

" Show editing mode
colorscheme desert

" Highlight search items (Put this after `colorscheme`)
set hlsearch

" Search words werent highlighting. Fixing that.
hi Search ctermfg=0 ctermbg=3 guifg=Black guibg=Yellow

" Ctrl-N completion wasnt highlighting
hi Pmenu ctermfg=0 ctermbg=3 guifg=Black guibg=White


highlight OverLength ctermbg=grey ctermfg=white guibg=#FFD9D9
match OverLength /\%81v.\+/
"highlight ColorColumn ctermbg=darkgreen
"set colorcolumn=80


" Show relative numbers (only in vim7.3+)
" set relativenumber

" Command <tab> completion, list matches
" and complete the longest common part then,
" cycle through the matches
set wildmode=list:longest,full

" Show matching brackets
set showmatch

" Disable mouse
set mouse=

" Keep the temporary files in different folder
"set directory=/tmp/.vim_swp

" vim72 broke my backspace all of a sudden,
" this saved me
set backspace=indent,eol,start

" Never really used fixdel, its just here for completeness purposes
"fixdel

"func Backspace()
"  if col('.') == 1
"    if line('.')  != 1
"      return  "\<ESC>kA\<Del>"
"    else
"      return ""
"    endif
"  else
"    return "\<Left>\<Del>"
"  endif
"endfunc
"
"inoremap <BS> <c-r>=Backspace()<CR>

" It looks like vim is sending ^? instead of ^H for erase
imap  <Left><Del>
cmap  <Left><Del>


" vim72 Omnicompletion
autocmd FileType python set omnifunc=pythoncomplete#Complete
autocmd FileType css set omnifunc=csscomplete#CompleteCSS
inoremap <Nul> <C-x><C-o>


" Play with pairs!
imap () ()<left>
imap [] []<left>
imap <> <><left>
imap {} {}<left>
imap "" ""<left>
imap '' ''<left>

" Toggle Line Numbers
map <F12> :set number!<CR>


" Wrap quotes around my word!
"imap <F4> <Esc>WBi"<Esc>Ea"
"nmap <F4> WBi"<Esc>Ea"<Esc>h

" Unwrap me :)
"imap <F5> <Esc>ebXEx
"nmap <F5> ebXExh


" Toggle Buffers
map <F11> :ls<CR>

" Comment me baby !
" F2
imap <F2> <Esc>0i#<Esc>
nmap <F2> 0i#<Esc>
vmap <F2> :-1/^/s//#/<CR>

" Uncomment me, wont you ?
" F3
imap <F3> <Esc>0x<Esc>
nmap <F3> 0x<Esc>
vmap <F3> :-1/^#/s///<CR>


" Paste Toggle
map <F5> :set paste!<CR>

"iab pdb from PyQt4 import QtCore; QtCore.pyqtRemoveInputHook()<Right>; import pdb; pdb.set_trace()<Right><Esc>
iab pdb import pdb; pdb.set_trace()<Right><Esc>
iab stack import traceback; print traceback.print_stack()

iab rr if err != nil {}<Return><Return><Up>


" Wrap quotes around my word!
"imap <F4> <Esc>WBi"<Esc>Ea"
"nmap <F4> WBi"<Esc>Ea"<Esc>h

" Unwrap me :)
"imap <F5> <Esc>ebXEx
"nmap <F5> ebXExh


" oggle<CR>


" CTAGS
"Taglist variables
let Tlist_Ctags_Cmd = "/usr/bin/ctags"
let Tlist_WinWidth = 50
" Display function name in status bar:
let g:ctags_statusline=1
" Automatically start script
let generate_tags=1
" Displays taglist results in a vertical window:
let Tlist_Use_Horiz_Window=0
" Various Taglist diplay config:
let Tlist_Use_Right_Window = 1
let Tlist_Compact_Format = 1
let Tlist_Exit_OnlyWindow = 1
let Tlist_GainFocus_On_ToggleOpen = 1
let Tlist_File_Fold_Auto_Close = 1
" Shorter commands to toggle Taglist display
nnoremap TT :TlistToggle<CR>
map <F6> :TlistUpdate<CR>
map <F8> :TlistToggle<CR>
map <F9> :!/usr/bin/ctags -f ~/.vim/tags/python.ctags --languages=+python --fields=+iaS  %:p<CR>
"set tags+=$HOME/.vim/tags/python.ctags
set tags+=~/.vim/tags/python.ctags


" Doesnt work :(
map <silent><C-Left> <C-T>
map <silent><C-Right> <C-]>


" minibufExplorer
let g:miniBufExplMapWindowNavVim = 1
let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1
let g:miniBufExplModSelTarget = 1


" Tabs
let mapleader = "_"
map <leader>tt :tabnew<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
map <leader>tn :tabnext<cr>
map <leader>tp :tabprevious<cr>



" Open in last known position
" When editing a file, always jump to the last known cursor position.
" Don't do it when the position is invalid or when inside an event handler
" (happens when dropping a file on gvim).
autocmd BufReadPost *
\ if line("'\"") > 0 && line("'\"") <= line("$") |
\   exe "normal g`\"" |
\ endif


" Experimental
imap jk <Esc>
imap JK <Esc>

" Move around split windows quickly
nmap <c-j> <c-w>j
nmap <c-k> <c-w>k
nmap <c-h> <c-w>h
nmap <c-l> <c-w>l

" vim72 tabs
"nmap <C-S-l> :tabnext<CR>
"nmap <C-s-h> :tabprevious<CR>

" Press Space to turn off highlighting and clear any message already displayed
noremap <silent> <Space> :silent noh<Bar>echo<CR>

" Enter to enter a newline without entering Insert Mode
" nmap <CR> o <Esc>0

" Shift Enter should stay on the same line.
" nmap <CR> o<Esc>k

" Space bar toggles the folds. Use this in conjunction with :set foldmethod=indent
" nnoremap <space> za
" vnoremap <space> zf

" Search for the function declaration : Python specific
nmap gx yiw/def <C-R>"<CR>zz
nmap gc yiw/class <C-R>"<CR>zz

" prc_checkout
function! PrcCheckout()
    exe ':!pco %:p'
    endfunction
map _o :call PrcCheckout()<CR>

" prc_checkin
function! PrcCheckin()
    exe ':!pci %:p'
    endfunction
map _i :call PrcCheckin()<CR>

" prc_softCheckout
function! PrcSoftCheckout()
    exe ':!pco -s %:p'
    endfunction
map _s :call PrcSoftCheckout()<CR>

" prc_release
function! PrcRelease()
    exe ':!prc_release %:p'
    endfunction
map _r :call PrcRelease()<CR>

" prc_release
function! PrcFill()
    exe ':!prc_fill %:p'
    endfunction
map _f :call PrcFill()<CR>

" prc_open/pcp
function! PrcOpen()
    exe ':!prc_open %:p'
    endfunction
map _p :call PrcOpen()<CR>

" For ADB Syntax,
"
" adb Syntax
" #1. include the following lines in .vim/ftdetect/adb.vim
" au! BufRead,BufNewFile *.adb setfiletype pdiadb
"
" #2. have a syntax file in .vim/syntax/pdiadb.vim


" Pydiction
" If you were using a version of Pydiction less than 1.0, make sure you delete
" the old pydiction way of doing things from your vimrc. You should ***NOT***
" have this in your vimrc anymore:
"if has ("autocmd")
"    autocmd FileType python set complete+=k/work/td/pydiction iskeyword+=.,(
"endif

"let g:pydiction_location = '/work/td/pydiction'
"let g:pydiction_menu_heigh = 20



" To jump between python libraries

"python << EOF

"import os,sys,vim

"import studioenv
"for p in sys.path:
"    if os.path.isdir(p):
"        vim.command(r"set path+=%s" % (p.replace(" " , r"\ ")))
"EOF

" Tab and Shift-Tab to move between Tabs in normalMode
nmap <tab> :bn <cr>
nmap <s-tab> :bp <cr>


if has ('gui_running')
    " Remove the Toolbar
    set guioptions-=T

    imap <MM> +gP
endif


"au! Syntax pdiscript    so /studio/common/aux/vim/pdiscript.vim
"au! Syntax pdiadb       so /studio/common/aux/vim/pdiadb.vim
"au! Syntax pdicdf       so /studio/common/aux/vim/pdicdf.vim

"augroup filetype
    "au! BufRead,BufNewFile *.s  set filetype=pdiscript
    "au! BufRead,BufNewFile *.adb  set filetype=pdiadb
    "au! BufRead,BufNewFile *.cdf  set filetype=pdicdf
    "au! BufRead,BufNewFile *.sl set filetype=sl	"renderman sl, not s-lang
"augroup END
"

function! OpenPyModule()
    let pyFile=expand("<cWORD>")
    let path = system("src_which_python ".pyFile)
    exe 'vertical split '.escape(path, ' ')
endfunction
command! OpenPyFile call OpenPyModule()
nnoremap _m :OpenPyFile<CR>


function! CurDir()
"   let curdir = substitute(getcwd(), '/home/jeffjose', "~/", "g")
   return curdir
"    return getcwd()
endfunction

" Set autoread.
" useful when you're using VIM instead of tail -f
set autoread

" Format the statusline
"set cmdheight=2
set laststatus=2
set statusline=\ -%n-\ %<%F%h%m%r%h%w\ %=\ -%Y-%w\%=\ -(%l/%L)-%c-\ %P
"set statusline=%<%F%h%m%r%h%w%y\ %{&ff}\ %{strftime(\"%d/%m/%Y-%H:%M\")}%=\ col:%c%V\ ascii:%b\ pos:%o\ lin:%l\,%L\ %P
" set statusline=%{strftime(\"%c\",getftime(expand(\"%:p\")))}
"set statusline=%<%F%h%m%r%h%w%y\ %{&ff}\ %{strftime(\"%c\",getftime(expand(\"%:p\")))}%=\ lin:%l\,%L\ col:%c%V\ pos:%o\ ascii:%b\ %P

function! FixBindings()
   let curdir = substitute(getcwd(), '/', "::", "g")
endfunction

" SuperPaste
" noremap <m-v> <esc>:set paste<cr>mui<C-R>+<esc>mv'uV'v=:set nopaste<cr>


" Multi-Buffer and Multi-File Text Searching
" file:///home/jeffjose/Desktop/kiosks/justArrived/vim/multibuffer.html
"
function! QFixToggle(forced)
    if exists("g:qfix_win") && a:forced == 0
        cclose
    else
        execute "copen"
    endif
endfunction

" Used to track the quickfix window.
augroup QFixToggle
    autocmd!
    autocmd BufWinEnter quickfix let g:qfix_win = bufnr("$")
    autocmd BufWinLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | endif
augroup END
" '\g' : grep all open buffers
:noremap <Leader>g <Esc>:GrepBuffer <CR>

" '\gg' : grep all open buffers for word under cursor
:noremap <Leader>gg <Esc>:GrepBuffer <C-R><C-W><CR>

" '\G' : recursively grep through filesystem
:noremap <Leader>G <Esc>:Rgrep<CR>

" '\qq' : toggle QuickFix window (errors and vimgrep results here)
noremap <silent><leader>qq <Esc>:call QFixToggle(0)<CR>

" '[q' previous quickfix entry
map [q :cprev<CR>

" ']q' next quickfix entry
map ]q :cnext<CR>

" '\q*' : search for occurrences of word under cursor, and write to QuickFix
noremap <silent><leader>q*  <Esc>:execute 'vimgrep '.expand('<cword>').' '.expand('%') <CR> :copen <CR> :cc

" Remove trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

"
" End of multi-buffer and multi-file text searching
"
"
" Go
    au BufWritePost *.go silent !gofmt -w %
    au BufReadPost *.go set autoread

" CoffeScript
    au BufWritePost *.coffee silent !coffee -bc %
    au BufWritePost *.cjsx silent !cjsx -bc %
    "au BufWritePost *.coffee silent !coffee -bc | cwindow | redraw!

    au BufReadPost *.js set autoread
    "au BufWritePost *.html silent !prettier --no-semi --write %
    au BufWritePost *.json silent !prettier --write %
    au BufWritePost *.vue silent !prettier --write %
    "au BufWritePost *.svelte silent !prettier --write %
    au BufWritePost *.js silent !prettier --write %
    au BufWritePost *.py silent !yapf --in-place %

" LESS files
    au! BufRead,BufNewFile *.less set filetype=less
    au BufWritePost *.less :silent !lessc <afile> <afile>:p:r.css

    " Less compile
    autocmd FileWritePost,BufWritePost *.less :call LessCSSCompress()
    function! LessCSSCompress()
      let cwd = expand('<afile>:p:h')
      let name = expand('<afile>:t:r')
      if (executable('lessc'))
        cal system('lessc '.cwd.'/'.name.'.less > '.cwd.'/'.name.'.css &')
      endif
    endfunction

" Protocol Buffers
augroup filetype
    au! BufRead,BufNewFile *.proto setfiletype proto
augroup end

" BUILD Files
    au BufWritePost BUILD silent !buildifier %

nnoremap <expr> gb '`[' . strpart(getregtype(), 0, 1) . '`]'

" Save registers here like so
let @j = "iJeffrey"
let @x = "ddGwwwwwwwwwhhhhxjk"

" Markdown folding
" https://github.com/plasticboy/vim-markdown
let g:vim_markdown_folding_disabled=1

"set t_Co=256


set rtp+=~/.vim/bundle/Vundle.vim

" let Vundle manage Vundle, required
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
Plugin 'groenewege/vim-less'
Plugin 'leafoftree/vim-svelte-plugin'

call vundle#end() " required

call pathogen#infect()
