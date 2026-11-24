local group = vim.api.nvim_create_augroup('DotfilesEditor', { clear = true })

vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufReadPost' }, {
  group = group,
  pattern = '*.md',
  callback = function(args)
    vim.bo[args.buf].filetype = 'markdown'
  end,
})

vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufReadPost' }, {
  group = group,
  pattern = { 'Podfile', '*.podspec' },
  callback = function(args)
    vim.bo[args.buf].filetype = 'ruby'
  end,
})

vim.api.nvim_create_autocmd('VimResized', {
  group = group,
  command = 'wincmd =',
})

vim.api.nvim_create_autocmd('FileType', {
  group = group,
  callback = function()
    vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
  end,
})
