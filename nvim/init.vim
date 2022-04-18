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


"""""""""""""""""""""""""""'
"" Color stuff
"
"" Adapted from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
""
"set t_Co=256
"
"if (match($TERM, "-256color") != -1) && (match($TERM, "screen-256color") == -1)
"  " screen does not (yet) support truecolor
"  " set termguicolors
"endif
"
"set background=dark
"" let base16colorspace=256 " Unset this because of the blue bar at the bottom
"let g:base16_shell_path="~/base16/templates/shell/scripts/"
"colorscheme base16-onedark
"syntax on
"hi Normal ctermbg=NONE
"
"" Customize colors
"" Make comments more prominent
"call Base16hi("Comment", g:base16_gui08, "", g:base16_cterm08, "", "", "")


""""""""""""""""""""""""""'
" Language settings

" Rust settings
" Set completeopt to have a better completion experience
" :help completeopt
" menuone: popup even when there's only one match
" noinsert: Do not insert text until a selection is made
" noselect: Do not select, force user to select one from the menu
set completeopt=menuone,noinsert,noselect

" Avoid showing extra messages when using completion
set shortmess+=c

" Configure LSP through rust-tools.nvim plugin.
" rust-tools will configure and enable certain LSP features for us.
" See https://github.com/simrat39/rust-tools.nvim#configuration
lua <<EOF
local nvim_lsp = require'lspconfig'

local opts = {
    tools = { -- rust-tools options
        autoSetHints = true,
        hover_with_actions = true,
        inlay_hints = {
            show_parameter_hints = false,
            parameter_hints_prefix = "",
            other_hints_prefix = "",
        },
    },

    -- all the opts to send to nvim-lspconfig
    -- these override the defaults set by rust-tools.nvim
    -- see https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
    server = {
        -- on_attach is a callback called when the language server attachs to the buffer
        -- on_attach = on_attach,
        settings = {
            -- to enable rust-analyzer settings visit:
            -- https://github.com/rust-analyzer/rust-analyzer/blob/master/docs/user/generated_config.adoc
            ["rust-analyzer"] = {
                -- enable clippy on save
                checkOnSave = {
                    command = "clippy"
                },
            }
        }
    },
}

require('rust-tools').setup(opts)
EOF

" Setup Completion
" See https://github.com/hrsh7th/nvim-cmp#basic-configuration
lua <<EOF
local cmp = require'cmp'
cmp.setup({
  -- Enable LSP snippets
  snippet = {
    expand = function(args)
        vim.fn["vsnip#anonymous"](args.body)
    end,
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    -- Add tab support
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    })
  },

  -- Installed sources
  sources = {
    { name = 'nvim_lsp' },
    { name = 'vsnip' },
    { name = 'path' },
    { name = 'buffer' },
  },
})
EOF

" have a fixed column for the diagnostics to appear in
" this removes the jitter when warnings/errors flow in
"set signcolumn=yes
set signcolumn=no

" And clear the signcolumn bg color
highlight clear signcolumn

autocmd BufWritePre *.rs lua vim.lsp.buf.formatting_sync(nil, 200)
