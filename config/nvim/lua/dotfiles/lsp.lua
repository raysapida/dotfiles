local capabilities = require('cmp_nvim_lsp').default_capabilities()

vim.lsp.config('pyright', { capabilities = capabilities })
vim.lsp.enable('pyright')

require("dap-python").setup("/opt/homebrew/bin/python3")

vim.lsp.config('ruby_lsp', {
  root_dir = function(bufnr, on_dir)
    -- Keep Ruby highlighting for Homebrew's DSL without starting Ruby LSP.
    if vim.fs.basename(vim.api.nvim_buf_get_name(bufnr)) == 'Brewfile' then
      return
    end
    on_dir(vim.fs.root(bufnr, vim.lsp.config.ruby_lsp.root_markers))
  end,
  -- Start through mise from the project root so ruby-lsp runs under the
  -- project's .ruby-version, not whatever ruby nvim's PATH had at launch.
  cmd = function(dispatchers, config)
    return vim.lsp.rpc.start({ 'mise', 'exec', '--', 'ruby-lsp' }, dispatchers, {
      cwd = config.root_dir,
    })
  end,
  capabilities = capabilities,
  init_options = {
    formatter = 'standard',
    linters = { 'standard' },
  },
})
vim.lsp.enable('ruby_lsp')

-- C / C++ (CRuby, and any project with a compile_commands.json)
vim.lsp.config('clangd', {
  capabilities = capabilities,
  cmd = {
    'clangd',
    '--background-index',
    '--header-insertion=never',
    '--completion-style=detailed',
    '--pch-storage=memory',
    '--limit-results=200',
    '-j=4',
  },
})
vim.lsp.enable('clangd')

-- Navigation mappings, active only in buffers with an LSP attached.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local function map(lhs, rhs, desc)
      vim.keymap.set('n', lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
    end
    local tb = require('telescope.builtin')

    map('gd', tb.lsp_definitions, 'Go to definition')
    map('gD', vim.lsp.buf.declaration, 'Go to declaration')

    -- <leader>c... = "code" (also shared by Claude Code below): everything else is
    -- taken by easymotion/rspec/telescope.
    map('<leader>cr', tb.lsp_references, 'References')
    map('<leader>cs', tb.lsp_document_symbols, 'Document symbols')
    map('<leader>cS', tb.lsp_dynamic_workspace_symbols, 'Workspace symbols')
    map('<leader>ci', tb.lsp_incoming_calls, 'Incoming calls (who calls this)')
    map('<leader>co', tb.lsp_outgoing_calls, 'Outgoing calls (what this calls)')
    map('<leader>ce', vim.diagnostic.open_float, 'Show diagnostic')
    map('<leader>ch', function() vim.cmd('LspClangdSwitchSourceHeader') end, 'Switch source/header')
  end,
})

vim.lsp.config('ts_ls', {})
vim.lsp.enable('ts_ls')
