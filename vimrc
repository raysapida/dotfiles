set nocompatible
let &t_Co=256

lua << EOF
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "

require("lazy").setup({
  -- ======================================================================
  -- General
  "mhinz/vim-startify",
  "tpope/vim-eunuch",
  "tpope/vim-fugitive",
  "tpope/vim-repeat",
  "tpope/vim-surround",
  "tpope/vim-vinegar",
  "tpope/vim-commentary",
  "tpope/vim-obsession",
  "pbrisbin/vim-mkdir",
  "wellle/targets.vim",
  "christoomey/vim-sort-motion",
  "christoomey/vim-system-copy",
  "christoomey/vim-tmux-navigator",
  "christoomey/vim-tmux-runner",
  "keith/tmux.vim",
  "rking/ag.vim",
  "junegunn/vim-easy-align",
  "junegunn/vim-peekaboo",
  "yuttie/comfortable-motion.vim",
  "Townk/vim-autoclose",
  "easymotion/vim-easymotion",
  { "mg979/vim-visual-multi", branch = "master" },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
  },

  -- Fuzzy finding
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- LSP + DAP
  "neovim/nvim-lspconfig",
  "mfussenegger/nvim-dap",
  { "mfussenegger/nvim-dap-python", ft = "python" },

  -- Themes + statusline
  "vim-airline/vim-airline",
  "vim-airline/vim-airline-themes",
  "reedes/vim-thematic",
  "flazz/vim-colorschemes",
  "jacoborus/tender.vim",
  "daylerees/colour-schemes",
  {
    "morhetz/gruvbox",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Tags
  { "majutsushi/tagbar", cmd = "TagbarToggle" },

  -- Writing / focus
  { "reedes/vim-pencil", ft = { "markdown", "text" } },
  { "reedes/vim-lexical", ft = { "markdown", "text" } },
  { "junegunn/goyo.vim", cmd = "Goyo" },
  { "junegunn/limelight.vim", cmd = "Limelight" },

  -- CSV
  { "hat0uma/csvview.nvim", ft = "csv" },

  -- ======================================================================
  -- Language specific

  -- Ruby / Rails
  { "thoughtbot/vim-rspec", ft = "ruby" },
  { "tpope/vim-rails", ft = "ruby" },
  { "slim-template/vim-slim", ft = "slim" },
  { "kchmck/vim-coffee-script", ft = "coffee" },

  -- JavaScript / TypeScript
  { "pangloss/vim-javascript", ft = { "javascript", "javascriptreact" } },
  { "othree/yajs.vim", ft = { "javascript", "javascriptreact" } },
  { "isRuslan/vim-es6", ft = { "javascript", "javascriptreact" } },
  { "mustache/vim-mustache-handlebars", ft = { "html", "mustache", "handlebars" } },
  { "moll/vim-node", ft = { "javascript", "javascriptreact" } },
  { "MaxMEllon/vim-jsx-pretty", ft = { "javascript", "javascriptreact" } },
  { "nikvdp/ejs-syntax", ft = "ejs" },
  { "prettier/vim-prettier", ft = { "javascript", "javascriptreact", "typescript", "typescriptreact", "css", "json" } },
  { "leafgarland/typescript-vim", ft = { "typescript", "typescriptreact" } },

  -- Templates
  { "lumiliet/vim-twig", ft = "twig" },
  { "mattn/emmet-vim", ft = { "html", "css", "javascript", "javascriptreact", "typescriptreact" } },
  { "tpope/vim-haml", ft = { "haml", "sass" } },
  { "digitaltoad/vim-pug", ft = "pug" },

  -- CSS
  { "ap/vim-css-color", ft = { "css", "scss", "sass", "html" } },

  -- Docker
  { "ekalinin/Dockerfile.vim", ft = "dockerfile" },

  -- Other languages
  { "elixir-lang/vim-elixir", ft = "elixir" },
  { "tomlion/vim-solidity", ft = "solidity" },
  { "justinmk/vim-syntax-extra", ft = { "c", "cpp" } },
  { "udalov/kotlin-vim", ft = "kotlin" },
  { "hashivim/vim-terraform", ft = { "terraform", "tf", "hcl" } },

  -- Markdown
  { "godlygeek/tabular", ft = "markdown" },
  { "plasticboy/vim-markdown", ft = "markdown" },
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },
}, {
  ui = { border = "rounded" },
})
EOF

lua << EOF
local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.lsp.config('pyright', { capabilities = capabilities })
vim.lsp.enable('pyright')

require("dap-python").setup("/opt/homebrew/bin/python3")

vim.lsp.config('ruby_lsp', {
  capabilities = capabilities,
  init_options = {
    formatter = 'standard',
    linters = { 'standard' },
  },
})
vim.lsp.enable('ruby_lsp')

require('telescope').setup({
  defaults = {
    layout_strategy = 'horizontal',
    file_ignore_patterns = { 'node_modules', '.git/' },
  },
})

local cmp = require('cmp')
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_next_item() else fallback() end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_prev_item() else fallback() end
    end, { 'i', 's' }),
    ['<CR>'] = cmp.mapping.confirm({ select = false }),
    ['<C-Space>'] = cmp.mapping.complete(),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
  }, {
    { name = 'buffer' },
    { name = 'path' },
  }),
})
EOF

lua require('csvview').setup()

filetype plugin indent on

autocmd BufNewFile,BufReadPost *.md set filetype=markdown


set foldlevel=99
set foldmethod=indent
set backspace=2   " Backspace deletes like most programs in insert mode
set nobackup
set nowritebackup
set noswapfile    " http://robots.thoughtbot.com/post/18739402579/global-gitignore#comment-458413287
set history=50
set ruler         " show the cursor position all the time
set showcmd       " display incomplete commands
set incsearch     " do incremental searching
set laststatus=2  " Always display the status line
set autowrite     " Automatically :write before running commands
set relativenumber
set background=dark

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

let g:thematic#theme_name = 'gruvbox'
let g:thematic#defaults = {
\ 'airline-theme': 'serene',
\ 'background': 'dark',
\ 'laststatus': 2,
\ 'theme': 'gruvbox',
\ }

let g:thematic#themes = {
\ 'gruvbox'  : {
\                },
\ 'Tomorrow-Night'  : {
\                },
\ 'bubblegum'  : { 'typeface': 'Menlo',
\                  'font-size': 18,
\                     'background': 'light',
\                  'transparency': 10,
\                  'linespace': 2,
\                },
\ 'distinguished'  : {
\                },
\ 'tender'  : {
\                  'typeface': 'Fira Mono Medium for Powerline Medium',
\                  'font-size': 30,
\                },
\ }

" highlight NonText guibg=#060606
" highlight Folded  guibg=#0A0A0A guifg=#9090D0

" Make it obvious where 80 characters is
set textwidth=90
set colorcolumn=+1

" Numbers
set number
set numberwidth=5

" Open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" Softtabs, 2 spaces
set tabstop=2
set shiftwidth=2
set shiftround
set expandtab

" Display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" Always use vertical diffs
set diffopt+=vertical

" Shortcut for creating a new tab
nnoremap <silent> <S-t> :tabnew %<CR>

if $TMUX == ''
  " set clipboard+=unnamed
  set clipboard+=unnamedplus
endif

" OSX specific
if has("unix")
  let s:uname = system("uname")
  if s:uname == "Darwin\n"
    " set clipboard=unnamed
    set clipboard=unnamedplus
  endif
endif

" Limelight specific configurations
let g:limelight_conceal_ctermfg = 240
" let g:limelight_default_coefficient = 0.7

" Automatically start limelight when using goyo
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

" tab next and tab previous
nnoremap <S-j> gT
nnoremap <S-k> gt

" let g:tmux_navigator_no_mappings = 1

" nnoremap <silent> <ctrl-h> :TmuxNavigateLeft<cr>
" nnoremap <silent> <ctrl-j> :TmuxNavigateDown<cr>
" nnoremap <silent> <ctrl-k> :TmuxNavigateUp<cr>
" nnoremap <silent> <ctrl-l> :TmuxNavigateRight<cr>
" nnoremap <silent> <ctrl-\> :TmuxNavigatePrevious<cr>

" let g:tmux_navigator_save_on_switch = 1

syntax enable

" automatically rebalance windows on vim resize
autocmd VimResized * :wincmd =

lua << EOF
local function sync_macos_appearance()
  local appearance = vim.fn.system("defaults read -g AppleInterfaceStyle 2>/dev/null"):gsub("%s+", "")
  vim.o.background = appearance == "Dark" and "dark" or "light"
  if vim.env.TMUX then
    vim.fn.jobstart("sync-theme")
  end
end

sync_macos_appearance()

vim.api.nvim_create_autocmd("FocusGained", {
  callback = sync_macos_appearance,
})
EOF

" zoom a vim pane, <C-w>= to re-balance
nnoremap <leader>- :wincmd _<cr>:wincmd \|<cr>
nnoremap <leader>= :wincmd =<cr>

" RSpec.vim mappings
map <Leader>t :call RunCurrentSpecFile()<CR>
map <Leader>s :call RunNearestSpec()<CR>
map <Leader>l :call RunLastSpec()<CR>
map <Leader>a :call RunAllSpecs()<CR>

" TODO: Dynamically use a specific rspec command or point to a script/alias that does
" let g:rspec_command = "call VtrSendCommand('rspec {spec}')"
" let g:rspec_command = "VtrSendCommandToRunner! rspec {spec}"
" let g:rspec_command = "VtrSendCommandToRunner! be rspec {spec}"
let g:rspec_command = "VtrSendCommandToRunner! ./scripts/run_tests.sh {spec}"
" let g:rspec_command = "VtrSendCommandToRunner! ./scripts/run_local_rspec.sh {spec}"
" let g:rspec_command = "VtrSendCommandToRunner! ./scripts/rspec.sh {spec}"

" fix for extra indents when pasting from clipboard
nnoremap <leader>q :r!pbpaste<cr>

" Indents whole file
noremap <leader>i mmgg=G`m<cr>

" Remove trailing whitespace
nnoremap <Leader>tw :%s/\s\+$//e<CR>

" hotkey for Goyo mode
nnoremap <Leader>0 :Goyo<CR>
nnoremap <Leader>9 :Limelight!!<CR>
let g:goyo_width = 90

" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
if executable('ag')
  set grepprg=ag\ --nogroup\ --nocolor
  if !exists(":Ag")
    command -nargs=+ -complete=file -bar Ag silent! grep! <args>|cwindow|redraw!
    nnoremap \ :Ag<SPACE>
  endif
endif

" Set a graphical menu for tab completed commands
set wildmenu
set wildmode=full

" Spell completion
set spell
set complete+=kspell

map <silent> <Leader>rt :!bundle list --paths=true \| xargs ctags --extra=+f --exclude=.git --exclude=log -R *<CR><CR>

" ag.vim configuration to start the search from the project root
let g:ag_working_path_mode="r"


" vim-javascripy features
let g:javascript_enable_domhtmlcss = 1

" hotkeys for buffers
map <leader>n :bn<cr>
map <leader>p :bp<cr>
map <leader>d :bd<cr>

" vim-jsx settings
let g:jsx_ext_required = 0

" Use jk to esc from insert mode
ino jk <esc>
cno jk <c-c>
vno v <esc>

" <Leader>f{char} to move to {char}
map  <Leader>f <Plug>(easymotion-bd-f)
nmap <Leader>f <Plug>(easymotion-overwin-f)

" s{char}{char} to move to {char}{char}
nmap s <Plug>(easymotion-overwin-f2)

" Move to line
map <Leader>L <Plug>(easymotion-bd-jk)
nmap <Leader>L <Plug>(easymotion-overwin-line)

" Move to word
map  <Leader>w <Plug>(easymotion-bd-w)
nmap <Leader>w <Plug>(easymotion-overwin-w)

autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

" repeat last command
map <leader>r :!!<cr>

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

let g:airline_theme = 'gruvbox'
let g:airline_powerline_fonts = 1
" let g:airline_left_sep = '»'
" let g:airline_left_sep = '▶'
" let g:airline_right_sep = '«'
" let g:airline_right_sep = '◀'
" if !exists('g:airline_symbols')
"   let g:airline_symbols = {}
" endif
" let g:airline_symbols.crypt = '🔒 '
" " let g:airline_symbols.linenr = '␊'
" " let g:airline_symbols.linenr = '␤'
" let g:airline_symbols.linenr = '¶'
" let g:airline_symbols.maxlinenr = '☰'
" " let g:airline_symbols.maxlinenr = ''
" let g:airline_symbols.branch = '⎇'
" " let g:airline_symbols.paste = 'ρ'
" let g:airline_symbols.paste = 'Þ'
" " let g:airline_symbols.paste = '∥'
" let g:airline_symbols.spell = 'Ꞩ'
" let g:airline_symbols.notexists = '∄'
" let g:airline_symbols.whitespace = 'Ξ'


" Relative / Absolute line numbers toggle
nnoremap <Leader>bg :lua vim.o.background = vim.o.background == "dark" and "light" or "dark"<CR>

function! NumberToggle()
  if(&relativenumber == 1)
    set number
  else
    set relativenumber
  endif
endfunc
nnoremap <C-i> :call NumberToggle()<cr>


" Vim pencil specifc plugins
augroup pencil
  autocmd!
  autocmd FileType markdown call pencil#init({'wrap': 'hard', 'autoformat': 0})
        \ | call lexical#init()
  autocmd FileType text     call pencil#init({'wrap': 'hard', 'autoformat': 0})
        \ | call lexical#init()
augroup END

nnoremap <silent> Q gqip

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"


set completeopt=menu,menuone,noselect



" search first in current directory then file directory for tag file
set tags=tags,./tags
nmap <F8> :TagbarToggle<CR>

if (has("termguicolors"))
 set termguicolors
endif

" Set Podfile and .podspec files as ruby
autocmd BufNewFile,BufRead Podfile,*.podspec set filetype=ruby


let g:user_emmet_leader_key='<C-Z>'
let g:user_emmet_settings = {
      \  'javascript.jsx' : {
      \      'extends' : 'jsx',
      \  },
      \}



" Exit terminal mode
tnoremap <Esc> <C-\><C-n>
tnoremap jk <C-\><C-n>

" === Telescope shortcuts === "
"   ;         - Browse open buffers
"   <leader>r - Browse files in current directory
"   <leader>g - Search for string in current directory
"   <leader>j - Search for word under cursor
nmap ; :Telescope buffers<CR>
nmap <leader>ff :Telescope find_files<CR>
nnoremap <leader>g :Telescope live_grep<CR>
nnoremap <leader>j :Telescope grep_string<CR>


let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal_code_blocks = 0
set conceallevel=0

