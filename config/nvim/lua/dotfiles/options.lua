local opt = vim.opt

opt.foldlevel = 99
opt.foldmethod = 'indent'
opt.backspace = 'indent,eol,start'
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.history = 50
opt.ruler = true
opt.showcmd = true
opt.incsearch = true
opt.laststatus = 2
opt.autowrite = true
opt.relativenumber = true
opt.background = 'dark'

opt.textwidth = 90
opt.colorcolumn = '+1'
opt.number = true
opt.numberwidth = 5
opt.splitbelow = true
opt.splitright = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.shiftround = true
opt.expandtab = true
opt.autoindent = true

opt.list = true
opt.listchars = { tab = '»·', trail = '·', nbsp = '·' }
opt.diffopt:append('vertical')

if vim.fn.has('macunix') == 1 then
  opt.clipboard = 'unnamedplus'
elseif not vim.env.TMUX or vim.env.TMUX == '' then
  opt.clipboard:append('unnamedplus')
end

opt.wildmenu = true
opt.wildmode = 'full'
opt.spell = true
opt.complete:append('kspell')
opt.completeopt = { 'menu', 'menuone', 'noselect' }
opt.tags = { 'tags', './tags' }
opt.termguicolors = true
opt.conceallevel = 0
