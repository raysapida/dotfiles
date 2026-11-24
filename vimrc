set nocompatible
let &t_Co=256

let mapleader = " "
let s:nvim_config = fnamemodify(resolve(expand('<sfile>:p')), ':h') . '/config/nvim'
lua << EOF
local config = vim.fn.eval('s:nvim_config')
vim.opt.rtp:prepend(config)
require('dotfiles.plugins')
-- lazy.nvim resets runtimepath during setup.
vim.opt.rtp:prepend(config)
EOF

lua require('dotfiles.lsp')

lua << EOF
-- Claude Code (coder/claudecode.nvim) -- shares the <leader>c "code" prefix above.
-- 'cs' is reused for visual mode only (send selection); normal-mode 'cs' stays
-- document symbols since Vim keeps mode keymaps separate.
require('claudecode').setup()

vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<cr>', { silent = true, desc = 'Claude: toggle' })
vim.keymap.set('n', '<leader>cu', '<cmd>ClaudeCode --resume<cr>', { silent = true, desc = 'Claude: resume session (picker)' })
vim.keymap.set('n', '<leader>ct', '<cmd>ClaudeCode --continue<cr>', { silent = true, desc = 'Claude: continue last session' })
vim.keymap.set('n', '<leader>cf', '<cmd>ClaudeCodeFocus<cr>', { silent = true, desc = 'Claude: focus' })
vim.keymap.set('n', '<leader>ca', '<cmd>ClaudeCodeAdd %<cr>', { silent = true, desc = 'Claude: add current file' })
vim.keymap.set('n', '<leader>cy', '<cmd>ClaudeCodeDiffAccept<cr>', { silent = true, desc = 'Claude: accept diff' })
vim.keymap.set('n', '<leader>cn', '<cmd>ClaudeCodeDiffDeny<cr>', { silent = true, desc = 'Claude: reject diff' })
vim.keymap.set('v', '<leader>cs', '<cmd>ClaudeCodeSend<cr>', { silent = true, desc = 'Claude: send selection' })

-- C is not prose: the global 'spell' turns every identifier into a typo.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp', 'rust' },
  callback = function() vim.opt_local.spell = false end,
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

lua require('dotfiles.options')

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

" Limelight specific configurations
let g:limelight_conceal_ctermfg = 240
" let g:limelight_default_coefficient = 0.7

" Automatically start limelight when using goyo
autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

" let g:tmux_navigator_no_mappings = 1

" nnoremap <silent> <ctrl-h> :TmuxNavigateLeft<cr>
" nnoremap <silent> <ctrl-j> :TmuxNavigateDown<cr>
" nnoremap <silent> <ctrl-k> :TmuxNavigateUp<cr>
" nnoremap <silent> <ctrl-l> :TmuxNavigateRight<cr>
" nnoremap <silent> <ctrl-\> :TmuxNavigatePrevious<cr>

" let g:tmux_navigator_save_on_switch = 1

syntax enable

lua require('dotfiles.autocmds')
lua require('dotfiles.theme')

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


" Vim pencil specifc plugins
augroup pencil
  autocmd!
  autocmd FileType markdown call pencil#init({'wrap': 'soft', 'autoformat': 0})
        \ | call lexical#init()
  autocmd FileType text     call pencil#init({'wrap': 'soft', 'autoformat': 0})
        \ | call lexical#init()
augroup END

nnoremap <silent> Q gqip

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"


nmap <F8> :TagbarToggle<CR>

let g:user_emmet_leader_key='<C-Z>'
let g:user_emmet_settings = {
      \  'javascript.jsx' : {
      \      'extends' : 'jsx',
      \  },
      \}



lua require('dotfiles.keymaps')

let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_conceal_code_blocks = 0
