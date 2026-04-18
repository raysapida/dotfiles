set nocompatible
filetype off
let &t_Co=256

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" VIM related
"if empty(glob('~/.vim/autoload/plug.vim'))
"  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
"        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
"  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
"endif
" call plug#begin('~/.vim/plugged')

" NVIM related
"if empty(glob('~/.config/nvim/autoload/plug.vim'))
"  silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs
"    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
"  "autocmd VimEnter * PlugInstall
"  "autocmd VimEnter * PlugInstall | source $MYVIMRC
"endif

" call plug#begin('~/.config/nvim/autoload/plug.vim')
call plug#begin()
" call plug#begin('~/.config/nvim/plugged')


" ========================================================================================
" General VIM plugins

" Start screen plugins showing recent buffers
Plug 'mhinz/vim-startify'

" Wrapper for UNIX command
Plug 'tpope/vim-eunuch'

" Wrapper to allow git commands in vim
Plug 'tpope/vim-fugitive'

" Using . command with Plugins
Plug 'tpope/vim-repeat'

" Mappings to easily delete, change and add such surroundings in pairs.
Plug 'tpope/vim-surround'

" netrw enhancement
Plug 'tpope/vim-vinegar'

" Plug 'github/copilot.vim'

" Completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'

" Plug 'autozimu/LanguageClient-neovim', {
"     \ 'branch': 'next',
"     \ 'do': 'bash install.sh',
"     \ }

" Fuzzy finding
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
" Full path fuzzy file, buffer, mru, tag, ... finder
Plug 'ctrlpvim/ctrlp.vim'

" Allows vim to make dir when creating a new file
Plug 'pbrisbin/vim-mkdir'

" Displays indent levels
Plug 'nathanaelkane/vim-indent-guides'

" Navigation inside a file
Plug 'easymotion/vim-easymotion'

" Allow multiple cursors using ctrl n, ctrl p , ctrl x
Plug 'mg979/vim-visual-multi', {'branch': 'master'}

" Creates a closing pairing for parentheses, brackets, etc
Plug 'Townk/vim-autoclose'

" sort with gs
Plug 'christoomey/vim-sort-motion'

" Copy to system clipboard using cp
Plug 'christoomey/vim-system-copy'

" Commenting using gcc
Plug 'tpope/vim-commentary'

" Wrapper for the silver searcher
Plug 'rking/ag.vim'

" Continuously update session files
Plug 'tpope/vim-obsession'

" Add additional targets for motions
Plug 'wellle/targets.vim'

" Easy to use alignment
" https://github.com/junegunn/vim-easy-align
Plug 'junegunn/vim-easy-align'

" Plugin to view the values of the registers
Plug 'junegunn/vim-peekaboo'

" Vim/tmux integration
Plug 'christoomey/vim-tmux-navigator'
Plug 'christoomey/vim-tmux-runner'
Plug 'keith/tmux.vim'

" Plugins to allow snippets
" Plugin 'MarcWeber/vim-addon-mw-utils'
" Plugin 'tomtom/tlib_vim'
" Plugin 'garbas/vim-snipmate'
Plug 'honza/vim-snippets'
Plug 'SirVer/ultisnips'


" Plugins for changing the themes
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'edkolev/tmuxline.vim'
Plug 'reedes/vim-thematic'
Plug 'flazz/vim-colorschemes'
Plug 'morhetz/gruvbox'
Plug 'jacoborus/tender.vim'
Plug 'daylerees/colour-schemes'

Plug 'yuttie/comfortable-motion.vim'

" Ctags plugin to show all tags in a file
Plug 'majutsushi/tagbar'

Plug 'Yggdroot/indentLine'

Plug 'chrisbra/csv.vim'

" ========================================================================================
" Language specific plugins

" Ruby / Rails specific plugins
Plug 'thoughtbot/vim-rspec', { 'for': 'ruby' }
Plug 'tpope/vim-rails', { 'for': 'ruby' }
" Plug 'tpope/vim-bundler', { 'for': 'ruby' }
Plug 'slim-template/vim-slim'
Plug 'kchmck/vim-coffee-script'

" Javascript related Plugins
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'othree/yajs.vim', { 'for': 'javascript' }
Plug 'isRuslan/vim-es6', { 'for': 'javascript' }
Plug 'mustache/vim-mustache-handlebars', { 'for': 'javascript' }
" Plug 'kchmck/vim-coffee-script', { 'for': 'javascript' }
Plug 'moll/vim-node', { 'for': 'javascript' }
Plug 'MaxMEllon/vim-jsx-pretty', { 'for': 'javascript' }

Plug 'justinj/vim-react-snippets', { 'for': 'javascript' }
Plug 'nikvdp/ejs-syntax', { 'for': 'javascript' }
Plug 'prettier/vim-prettier', { 'for': 'javascript' }
Plug 'tellijo/vim-react-native-snippets', { 'for': 'javascript' }
Plug 'grvcoelho/vim-javascript-snippets', { 'for': 'javascript' }
Plug 'leafgarland/typescript-vim'

Plug 'lumiliet/vim-twig'

Plug 'mattn/emmet-vim'

" Markdown specific plugins
Plug 'godlygeek/tabular', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" CSS specific Plugins
Plug 'ap/vim-css-color'

" Docker specific Plugins
Plug 'ekalinin/Dockerfile.vim'

" Python specific plugins
" Plug 'klen/python-mode', { 'for': 'python' }
" Plug 'python-mode/python-mode', { 'for': 'python', 'branch': 'develop' }
" Plug 'jupyter-vim/jupyter-vim'

" Templating specific plugins
Plug 'tpope/vim-haml'
Plug 'digitaltoad/vim-pug'

" Elixir specific plugins
Plug 'elixir-lang/vim-elixir'

" Solidity / Ethereum specific plugins
Plug 'tomlion/vim-solidity'

" C Specific Plugins
Plug 'justinmk/vim-syntax-extra'

" Kotlin Specific Plugins
Plug 'udalov/kotlin-vim'

" Writing specific plugins
Plug 'reedes/vim-pencil'
Plug 'reedes/vim-lexical'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

" Plug 'glacambre/firenvim', { 'do': { _ -> firenvim#install(0) } }

" Plug 'w0rp/ale'
" Plug 'skywind3000/asyncrun.vim'

" Plug 'neoclide/coc.nvim', {'do': { -> coc#util#install()}}

Plug 'hashivim/vim-terraform'

Plug 'hat0uma/csvview.nvim'

Plug 'neovim/nvim-lspconfig'

Plug 'mfussenegger/nvim-dap'
Plug 'mfussenegger/nvim-dap-python'

Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}



call plug#end()

lua << EOF
local capabilities = require('cmp_nvim_lsp').default_capabilities()

require('lspconfig').pyright.setup({ capabilities = capabilities })
require("dap-python").setup("/opt/homebrew/bin/python3")
require('lspconfig').ruby_lsp.setup({
  capabilities = capabilities,
  init_options = {
    formatter = 'standard',
    linters = { 'standard' },
  },
})

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

filetype indent on

autocmd BufNewFile,BufReadPost *.md set filetype=markdown

" Leader
let mapleader = " "

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
" set background=light
set background=light

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
let g:limelight_conceal_ctermfg = 'gray'
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

" ctrlp vim
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'


" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
if executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag -Q -l --nocolor --hidden -g "" %s'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0


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

let g:airline_theme = 'tender'
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

" Manage tmux line so that the windows dont overflow to each other
let g:tmuxline_powerline_separators = 1
" let g:tmuxline_separators = {
"     \ 'left' : '▶',
"     \ 'left_alt': '>',
"     \ 'right' : '◀',
"     \ 'right_alt' : '<',
"     \ 'space' : ' '}

let g:tmuxline_preset = {
      \'a'    : '#S',
      \'b'    : ['#(tmux-spotify-info)'],
      \'win'  : '#I #W',
      \'cwin' : '#I #W',
      \'x'    : '%a %b %d',
      \'y'    : '%I:%M %p',
      \'z'    : '#(~/bin/battery Discharging) - #h'}

" Relative / Absolute line numbers toggle
function! NumberToggle()
  if(&relativenumber == 1)
    set number
  else
    set relativenumber
  endif
endfunc
nnoremap <C-i> :call NumberToggle()<cr>

" Indent settings
set ts=2 sw=2 et
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=white   ctermbg=white
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=lightgrey ctermbg=lightgrey

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

let g:ycm_key_list_select_completion=[]
let g:ycm_key_list_previous_completion=[]

" Uses the prettier js library to format js and jsx files
" autocmd FileType javascript.jsx,javascript setlocal formatprg=prettier\ --stdin

let g:UltiSnipsExpandTrigger       = '<c-t>'
let g:UltiSnipsJumpForwardTrigger  = '<c-j>'
let g:UltiSnipsJumpBackwardTrigger = '<c-a>'

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

