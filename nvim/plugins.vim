call plug#begin()

" Secure modelines
Plug 'ciaranm/securemodelines'

" Editorconfig
Plug 'editorconfig/editorconfig-vim'

" Faster `jk` escape
Plug 'jdhao/better-escape.vim'

" fzf
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" syntax highlighting
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

" Colorscheme
Plug 'chriskempson/base16-vim'

" Lightline
Plug 'itchyny/lightline.vim'

" Make yanked portion apparent
Plug 'machakann/vim-highlightedyank'

" For rust-analyzer
Plug 'neoclide/coc.nvim', {'branch': 'release'}

Plug 'autozimu/LanguageClient-neovim', {  'branch': 'next',  'do': 'bash install.sh' }

Plug 'dense-analysis/ale'


call plug#end()

"""""""""""""""""
" fzf

let g:fzf_action = {
      \ 'ctrl-s': 'split',
      \ 'ctrl-v': 'vsplit'
      \ }
let g:fzf_preview_window = 'right:60%'
nnoremap <c-p> :Files<cr>
augroup fzf
  autocmd!
  autocmd! FileType fzf
  autocmd  FileType fzf set laststatus=0 noshowmode noruler
    \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler
augroup END


"""""""""""""""""
" nvim-treesitter

"
" lua <<EOF
" require'nvim-treesitter.configs'.setup {
"   ensure_installed = "maintained",
"
"   sync_install = false,
"
"   highlight = {
"     enable = true,
"     additional_vim_regex_highlighting = false,
"   },
" }
" EOF


"""""""""""""""""
" better-escape
let g:better_escape_shortcut = ['jk', 'JK']


"""""""""""""""""
" lightline
let g:lightline = {
      \ 'active': {
      \   'right': [ [ 'syntastic', 'mylineinfo' ], [ 'filetype' ] ],
      \ },
      \ 'component_function': {
      \   'mylineinfo': "MyLineinfo",
      \ },
      \ }
function! MyLineinfo()
  return line('.') . '/' . line('$')
endfunction


"""""""""""""""
" Langauge server
let g:LanguageClient_serverCommands = { 'rust': ['rust-analyzer'] }

let g:ale_linters = {'rust': ['analyzer']}

