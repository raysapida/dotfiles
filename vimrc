set nocompatible
filetype off
let &t_Co=256

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')


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

" Code completion using tab key
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif

" Allows vim to make dir when creating a new file
Plug 'pbrisbin/vim-mkdir'

" Displays indent levels
Plug 'nathanaelkane/vim-indent-guides'

" Full path fuzzy file, buffer, mru, tag, ... finder
Plug 'ctrlpvim/ctrlp.vim'

" Navigation inside a file
Plug 'easymotion/vim-easymotion'

" Allow multiple cursors using ctrl n, ctrl p , ctrl x
Plug 'terryma/vim-multiple-cursors'

" Creates a closing pairing for parentheses, brackets, etc
Plug 'Townk/vim-autoclose'

" linter
Plug 'scrooloose/syntastic'

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
Plug 'flazz/vim-colorschemes'
Plug 'morhetz/gruvbox'
Plug 'jacoborus/tender.vim'

Plug 'yuttie/comfortable-motion.vim'

" Ctags plugin to show all tags in a file
Plug 'majutsushi/tagbar'

" ========================================================================================
" Language specific plugins

" Ruby / Rails specific plugins
Plug 'thoughtbot/vim-rspec'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-bundler'

" Javascript related Plugins
Plug 'pangloss/vim-javascript', { 'for': 'javascript' }
Plug 'othree/yajs.vim', { 'for': 'javascript' }
Plug 'isRuslan/vim-es6', { 'for': 'javascript' }
Plug 'mustache/vim-mustache-handlebars', { 'for': 'javascript' }
Plug 'kchmck/vim-coffee-script', { 'for': 'javascript' }
Plug 'moll/vim-node', { 'for': 'javascript' }
Plug 'mxw/vim-jsx', { 'for': 'javascript' }
Plug 'justinj/vim-react-snippets', { 'for': 'javascript' }
Plug 'nikvdp/ejs-syntax', { 'for': 'javascript' }
Plug 'prettier/vim-prettier', { 'for': 'javascript' }
Plug 'tellijo/vim-react-native-snippets', { 'for': 'javascript' }
Plug 'grvcoelho/vim-javascript-snippets', { 'for': 'javascript' }

" Markdown specific plugins
Plug 'godlygeek/tabular', { 'for': 'markdown' }
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }

" CSS specific Plugins
Plug 'ap/vim-css-color'

" Docker specific Plugins
Plug 'ekalinin/Dockerfile.vim'

" Python specific plugins
Plug 'klen/python-mode'

" Templating specific plugins
Plug 'tpope/vim-haml'
Plug 'digitaltoad/vim-pug'

" Elixir specific plugins
Plug 'elixir-lang/vim-elixir'

" Solidity / Ethereum specific plugins
Plug 'tomlion/vim-solidity'

" C Specific Plugins
Plug 'justinmk/vim-syntax-extra'

" Writing specific plugins
Plug 'reedes/vim-pencil'
Plug 'reedes/vim-lexical'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

call plug#end()

filetype plugin indent on

filetype indent on

autocmd BufNewFile,BufReadPost *.md set filetype=markdown

" Leader
let mapleader = " "

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
set background=dark

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

" Color scheme
" colorscheme Tomorrow-Night
" colorscheme distinguished
" colorscheme gruvbox
colorscheme tender
" highlight NonText guibg=#060606
" highlight Folded  guibg=#0A0A0A guifg=#9090D0
" let g:gruvbox_contrast_dark=medium

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
  set clipboard+=unnamed
endif

" OSX specific
if has("unix")
  let s:uname = system("uname")
  if s:uname == "Darwin\n"
    set clipboard=unnamed
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

" let g:rspec_command = "call VtrSendCommand('rspec {spec}')"
" let g:rspec_command = "VtrSendCommandToRunner! rspec {spec}"
let g:rspec_command = "VtrSendCommandToRunner! be rspec {spec}"

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

" Syntastic settings
" set statusline+=%#warningmsg#
" set statusline+=%{SyntasticStatuslineFlag()}
" set statusline+=%*

" Syntastic settings
" let g:syntastic_always_populate_loc_list = 1
" let g:syntastic_auto_loc_list = 1
" let g:syntastic_check_on_open = 1
" let g:syntastic_check_on_wq = 0
" let g:syntastic_javascript_checkers = ['eslint']

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

" Disable syntastic check by default
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes':   [],'passive_filetypes': [] }

" Relative / Absolute line numbers toggle
function! NumberToggle()
  if(&relativenumber == 1)
    set number
  else
    set relativenumber
  endif
endfunc
nnoremap <C-i> :call NumberToggle()<cr>

" Turn off multi cursor default mappings
let g:multi_cursor_use_default_mapping=0

" Same as default for now but config is now explicit
let g:multi_cursor_next_key='<C-n>'
let g:multi_cursor_prev_key='<C-p>'
let g:multi_cursor_skip_key='<C-x>'
let g:multi_cursor_quit_key='<C-q>'

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
  autocmd FileType markdown call pencil#init({'wrap': 'hard', 'autoformat': 1})
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
autocmd FileType javascript.jsx,javascript setlocal formatprg=prettier\ --stdin

" Use deoplete.
let g:deoplete#enable_at_startup = 1

" search first in current directory then file directory for tag file
set tags=tags,./tags
nmap <F8> :TagbarToggle<CR>

if (has("termguicolors"))
 set termguicolors
endif
