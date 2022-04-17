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
"Plug 'chriskempson/base16-vim'

" Lightline
Plug 'itchyny/lightline.vim'

" Make yanked portion apparent
Plug 'machakann/vim-highlightedyank'

" VIM rooter
Plug 'airblade/vim-rooter'


" SCRATCH PAD
" Collection of common configurations for the Nvim LSP client
Plug 'neovim/nvim-lspconfig'

" Completion framework
Plug 'hrsh7th/nvim-cmp'

" LSP completion source for nvim-cmp
Plug 'hrsh7th/cmp-nvim-lsp'

" Snippet completion source for nvim-cmp
Plug 'hrsh7th/cmp-vsnip'

" Other usefull completion sources
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-buffer'

" See hrsh7th's other plugins for more completion sources!

" To enable more of the features of rust-analyzer, such as inlay hints and more!
Plug 'simrat39/rust-tools.nvim'

" Snippet engine
Plug 'hrsh7th/vim-vsnip'

" Fuzzy finder
" Optional
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

" Color scheme used in the GIFs!
Plug 'arcticicestudio/nord-vim'

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

