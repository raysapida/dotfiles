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

  -- AI
  { "folke/snacks.nvim", opts = {} },
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeAdd",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny",
    },
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
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Tags
  { "majutsushi/tagbar", cmd = "TagbarToggle" },
  {
    "ludovicchabant/vim-gutentags",
    init = function()
      vim.g.gutentags_ctags_executable = "ctags"
      vim.g.gutentags_project_root = { ".git", "Gemfile", "Rakefile" }
      vim.g.gutentags_ctags_extra_args = { "--tag-relative=yes", "--fields=+ailmnS" }
      -- Index only git-tracked files (skips gitignored node_modules, venvs, Pods...).
      -- Non-git roots (Gemfile/Rakefile only) fall back to ctags -R + ~/.ctags.d excludes.
      vim.g.gutentags_file_list_command = { markers = { [".git"] = "git ls-files" } }
    end,
  },

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
  { "Julian/lean.nvim", ft = "lean" },

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
