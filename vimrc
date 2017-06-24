set nocompatible
filetype off
let &t_Co=256

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Plugin Manager
Plugin 'gmarik/Vundle.vim'
" Used for Vundle and offers utility functions
Plugin 'L9'

" ========================================================================================
" General VIM plugins

" Start screen plugins showing recent buffers
Plugin 'mhinz/vim-startify'

" Wrapper for UNIX command
Plugin 'tpope/vim-eunuch'

" Wrapper to allow git commands in vim
Plugin 'tpope/vim-fugitive'

" Using . command with Plugins
Plugin 'tpope/vim-repeat'

" Mappings to easily delete, change and add such surroundings in pairs.
Plugin 'tpope/vim-surround'

" netrw enhancement
Plugin 'tpope/vim-vinegar'

" Code completion using tab key
" Plugin 'Shougo/neocomplete.vim'
Plugin 'Valloric/YouCompleteMe'

" Allows vim to make dir when creating a new file
Plugin 'pbrisbin/vim-mkdir'

" Displays indent levels
Plugin 'nathanaelkane/vim-indent-guides'

" Full path fuzzy file, buffer, mru, tag, ... finder
Plugin 'ctrlpvim/ctrlp.vim'

" Navigation inside a file
Plugin 'easymotion/vim-easymotion'

" Allow multiple cursors using ctrl n, ctrl p , ctrl x
Plugin 'terryma/vim-multiple-cursors'

" Creates a closing pairing for parentheses, brackets, etc
Plugin 'Townk/vim-autoclose'

" linter
Plugin 'scrooloose/syntastic'

" sort with gs
Plugin 'christoomey/vim-sort-motion'

" Copy to system clipboard using cp
Plugin 'christoomey/vim-system-copy'

" Commenting using gcc
Plugin 'tpope/vim-commentary'

" Wrapper for the silver searcher
Plugin 'rking/ag.vim'

" Continuously update session files
Plugin 'tpope/vim-obsession'

" Easy to use alignment
" https://github.com/junegunn/vim-easy-align
Plugin 'junegunn/vim-easy-align'

" Plugin to view the values of the registers
Plugin 'junegunn/vim-peekaboo'

" Vim/tmux integration
Plugin 'christoomey/vim-tmux-navigator'
Plugin 'christoomey/vim-tmux-runner'
Plugin 'keith/tmux.vim'

" Plugins to allow snippets
" Plugin 'MarcWeber/vim-addon-mw-utils'
" Plugin 'tomtom/tlib_vim'
" Plugin 'garbas/vim-snipmate'
Plugin 'honza/vim-snippets'
Plugin 'SirVer/ultisnips'


" Plugins for changing the themes
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'edkolev/tmuxline.vim'
Plugin 'flazz/vim-colorschemes'
Plugin 'morhetz/gruvbox'

Plugin 'yuttie/comfortable-motion.vim'

" ========================================================================================
" Language specific plugins

" Ruby / Rails specific plugins
Plugin 'thoughtbot/vim-rspec'
Plugin 'tpope/vim-rails'
Plugin 'tpope/vim-bundler'

" Javascript related Plugins
Plugin 'pangloss/vim-javascript'
" Plugin 'jelera/vim-javascript-syntax'
Plugin 'othree/yajs.vim'
Plugin 'isRuslan/vim-es6'
Plugin 'mustache/vim-mustache-handlebars'
Plugin 'kchmck/vim-coffee-script'
Plugin 'moll/vim-node'
Plugin 'mxw/vim-jsx'
Plugin 'justinj/vim-react-snippets'
Plugin 'nikvdp/ejs-syntax'

" CSS specific Plugins
Plugin 'ap/vim-css-color'

" Docker specific Plugins
Plugin 'ekalinin/Dockerfile.vim'

" Python specific plugins
Plugin 'klen/python-mode'

" Templating specific plugins
Plugin 'tpope/vim-haml'
Plugin 'digitaltoad/vim-pug'

" Elixir specific plugins
Plugin 'elixir-lang/vim-elixir'

" Solidity / Ethereum specific plugins
Plugin 'tomlion/vim-solidity'

" C Specific Plugins
Plugin 'justinmk/vim-syntax-extra'

" Writing specific plugins
Plugin 'reedes/vim-pencil'
Plugin 'reedes/vim-lexical'
Plugin 'junegunn/goyo.vim'
Plugin 'junegunn/limelight.vim'

call vundle#end()

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
colorscheme gruvbox
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

set tags=./tags;

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
let g:multi_cursor_quit_key='<Esc>'

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



""""""""""Start
" " Neocomplete vim settings that I don't understand yet
" " Note: This option must be set in .vimrc(_vimrc).  NOT IN .gvimrc(_gvimrc)!
" " Disable AutoComplPop.
" let g:acp_enableAtStartup = 0
" " Use neocomplete.
" let g:neocomplete#enable_at_startup = 1
" " Use smartcase.
" let g:neocomplete#enable_smart_case = 1
" " Set minimum syntax keyword length.
" let g:neocomplete#sources#syntax#min_keyword_length = 3
" let g:neocomplete#lock_buffer_name_pattern = '\*ku\*'

" " Define dictionary.
" let g:neocomplete#sources#dictionary#dictionaries = {
"     \ 'default' : '',
"     \ 'vimshell' : $HOME.'/.vimshell_hist',
"     \ 'scheme' : $HOME.'/.gosh_completions'
"         \ }

" " Define keyword.
" if !exists('g:neocomplete#keyword_patterns')
"   let g:neocomplete#keyword_patterns = {}
" endif
" let g:neocomplete#keyword_patterns['default'] = '\h\w*'

" " Plugin key-mappings.
" inoremap <expr><C-g>     neocomplete#undo_completion()
" inoremap <expr><C-l>     neocomplete#complete_common_string()

" " Recommended key-mappings.
" " <CR>: close popup and save indent.
" inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
" function! s:my_cr_function()
"   return (pumvisible() ? "\<C-y>" : "" ) . "\<CR>"
"   " For no inserting <CR> key.
"   "return pumvisible() ? "\<C-y>" : "\<CR>"
" endfunction
" " <TAB>: completion.
" inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" " <C-h>, <BS>: close popup and delete backword char.
" inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
" inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
" " Close popup by <Space>.
" "inoremap <expr><Space> pumvisible() ? "\<C-y>" : "\<Space>"

" " AutoComplPop like behavior.
" "let g:neocomplete#enable_auto_select = 1

" " Shell like behavior(not recommended).
" "set completeopt+=longest
" "let g:neocomplete#enable_auto_select = 1
" "let g:neocomplete#disable_auto_complete = 1
" "inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

" " Enable omni completion.
" autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
" autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
" autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
" autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
" autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

" " Enable heavy omni completion.
" if !exists('g:neocomplete#sources#omni#input_patterns')
"   let g:neocomplete#sources#omni#input_patterns = {}
" endif
" "let g:neocomplete#sources#omni#input_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
" "let g:neocomplete#sources#omni#input_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
" "let g:neocomplete#sources#omni#input_patterns.cpp = '[^.[:digit:]
" "*\t]\%(\.\|->\)\|\h\w*::'

" " For perlomni.vim setting.
" " https://github.com/c9s/perlomni.vim
" let g:neocomplete#sources#omni#input_patterns.perl = '\h\w*->\h\w*\|\h\w*::'
""""""" END


" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
" let g:UltiSnipsExpandTrigger="<S-tab>"
" let g:UltiSnipsJumpForwardTrigger="<c-b>"
" let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

let g:ycm_key_list_select_completion=[]
let g:ycm_key_list_previous_completion=[]

" Uses the prettier js library to format js and jsx files
autocmd FileType javascript.jsx,javascript setlocal formatprg=prettier\ --stdin
