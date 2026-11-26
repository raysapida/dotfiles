local last_bg = nil
local function sync_macos_appearance()
  if vim.fn.has('macunix') ~= 1 then return end
  local appearance = vim.fn.system({ 'defaults', 'read', '-g', 'AppleInterfaceStyle' }):gsub("%s+", "")
  local bg = appearance == "Dark" and "dark" or "light"
  if bg == last_bg then return end
  last_bg = bg
  vim.o.background = bg
  vim.cmd.colorscheme("gruvbox")
  local sync_theme = vim.fn.expand('~/.dotfiles/bin/sync-theme')
  if vim.fn.executable(sync_theme) == 1 then
    vim.fn.jobstart({ sync_theme })
  end
end

sync_macos_appearance()

vim.api.nvim_create_autocmd("FocusGained", {
  callback = sync_macos_appearance,
})
