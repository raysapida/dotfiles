local map = vim.keymap.set

map('n', '<S-t>', ':tabnew %<CR>', { silent = true })
map('n', '<S-j>', 'gT')
map('n', '<S-k>', 'gt')

map('i', 'jk', '<Esc>')
map('c', 'jk', '<C-c>')
map('v', 'v', '<Esc>')
map('t', '<Esc>', '<C-\\><C-n>')
map('t', 'jk', '<C-\\><C-n>')

map('n', ';', ':Telescope buffers<CR>', { remap = true })
map('n', '<leader>ff', ':Telescope find_files<CR>', { remap = true })
map('n', '<leader>g', ':Telescope live_grep<CR>')
map('n', '<leader>j', ':Telescope grep_string<CR>')

map('n', '<leader>bg', function()
  vim.o.background = vim.o.background == 'dark' and 'light' or 'dark'
  vim.cmd.colorscheme('gruvbox')
end)

map('n', '<C-i>', function()
  if vim.wo.relativenumber then
    vim.wo.number = true
  else
    vim.wo.relativenumber = true
  end
end)
