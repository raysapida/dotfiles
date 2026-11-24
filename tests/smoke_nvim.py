"""Load the real Neovim configuration with installed plugins in a temporary home.

Does not install/update plugins or run theme automation. Additional preinstalled
plugins can be supplied with --extra-plugin-root DIR. Plugin sources are copied
from the existing lazy directory; configuration, lockfiles and state are isolated.
"""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugins-dir", type=Path,
                        default=Path.home() / ".local/share/nvim/lazy")
    parser.add_argument("--extra-plugin-root", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    nvim = shutil.which("nvim")
    if not nvim:
        parser.error("nvim is required")
    plugins = {}
    for source in [args.plugins_dir, args.extra_plugin_root]:
        if source and source.is_dir():
            plugins.update({p.name: p.resolve() for p in source.iterdir() if p.is_dir()})
    required = {name.split("/")[-1] for name in re.findall(
        r'''["']([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)["']''', (repo / "config/nvim/lua/dotfiles/plugins.lua").read_text())}
    pinned = json.loads((repo / "config/nvim/lazy-lock.json").read_text())
    expected = required | {"lazy.nvim"}
    if pinned.keys() != expected:
        parser.error("Neovim lockfile and plugin specs differ: "
                     + ", ".join(sorted(pinned.keys() ^ expected)))
    missing = sorted(expected - plugins.keys())
    if missing:
        parser.error("Install these plugins in a staging directory first: " + ", ".join(missing))

    with tempfile.TemporaryDirectory(prefix="dotfiles-nvim-") as temp:
        work = Path(temp).resolve()
        home = work / "home"
        config = home / ".config/nvim"
        data = home / ".local/share/nvim/lazy"
        config.mkdir(parents=True)
        data.mkdir(parents=True)
        (home / ".dotfiles").symlink_to(repo, target_is_directory=True)
        (home / ".vimrc").symlink_to(repo / "vimrc")
        (config / "init.lua").symlink_to(repo / "config/nvim/init.lua")
        for name in expected:
            shutil.copytree(plugins[name], data / name,
                            ignore=shutil.ignore_patterns(".git", ".DS_Store"))
        commands = work / "commands"
        commands.mkdir()
        for name, script in {"defaults": "echo Dark", "git": "exit 99",
                             "osascript": "exit 99", "tmux": "exit 99"}.items():
            path = commands / name
            path.write_text("#!/bin/sh\n" + script + "\n")
            path.chmod(0o755)
        check = work / "check.lua"
        check.write_text('''
vim.o.loadplugins = true
local errors = {}
local notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then table.insert(errors, tostring(message)) end
  notify(message, level, opts)
end
local sync_calls = 0
local jobstart = vim.fn.jobstart
vim.fn.jobstart = function(command, opts)
  local executable = type(command) == 'table' and command[1] or command
  if executable:match('/sync%-theme$') then
    sync_calls = sync_calls + 1
    return 1
  end
  return jobstart(command, opts)
end
local lazy = require('lazy')
local setup = lazy.setup
lazy.setup = function(spec, opts)
  opts = vim.tbl_deep_extend('force', opts or {}, {
    install = { missing = false }, checker = { enabled = false },
    change_detection = { enabled = false }, rocks = { enabled = false },
  })
  return setup(spec, opts)
end
local ok, err = xpcall(function()
  dofile(vim.fn.stdpath('config') .. '/init.lua')
  assert(type(vim.lsp.config.ruby_lsp.cmd) == 'function', 'project Ruby LSP command missing')
  assert(vim.lsp.config.ts_ls, 'TypeScript LSP config missing')
  assert(vim.fn.exists(':ClaudeCode') == 2, 'ClaudeCode command missing')
  assert(vim.fn.maparg('<leader>cc', 'n') ~= '', 'ClaudeCode mapping missing')
  assert(vim.o.number and vim.o.relativenumber, 'line numbers missing')
  assert(vim.o.expandtab and vim.o.shiftwidth == 2, 'indentation options changed')
  assert(vim.o.splitbelow and vim.o.splitright, 'split options changed')
  assert(vim.fn.maparg('jk', 'i') == '<Esc>', 'insert escape mapping changed')
  assert(vim.fn.maparg(';', 'n') == ':Telescope buffers<CR>', 'Telescope mapping changed')
  assert(#vim.api.nvim_get_autocmds({ group = 'DotfilesEditor', event = 'VimResized' }) == 1,
    'resize autocommand missing')
  -- Observe real attachment decisions without launching the language server.
  local ruby_starts = 0
  local lsp_start = vim.lsp.start
  vim.lsp.start = function(config, opts)
    if config.name == 'ruby_lsp' then
      ruby_starts = ruby_starts + 1
      return
    end
    return lsp_start(config, opts)
  end
  vim.cmd.edit('Brewfile')
  assert(vim.bo.filetype == 'ruby', 'Brewfile Ruby highlighting missing')
  assert(not vim.wait(200, function() return ruby_starts > 0 end),
    'Ruby LSP tried to start for Brewfile')
  vim.cmd.edit('Podfile')
  assert(vim.bo.filetype == 'ruby', 'Podfile Ruby filetype missing')
  assert(not vim.bo.formatoptions:match('[cro]'), 'comment continuation was enabled')
  assert(vim.wait(1000, function() return ruby_starts > 0 end),
    'Ruby LSP did not start for Podfile')
  vim.lsp.start = lsp_start
  local plugins = require('lazy.core.config').plugins
  for _, name in ipairs({ 'lean.nvim', 'vim-gutentags', 'snacks.nvim', 'claudecode.nvim' }) do
    assert(plugins[name], name .. ' missing from plugin specification')
  end
  if vim.fn.has('macunix') == 1 then
    assert(sync_calls == 1, 'startup should sync the theme once')
    vim.api.nvim_exec_autocmds('FocusGained', {})
    assert(sync_calls == 1, 'unchanged appearance should not sync again')
  end
  assert(vim.v.errmsg == '', vim.v.errmsg)
  assert(#errors == 0, table.concat(errors, '\\n'))
end, debug.traceback)
if not ok then
  io.stderr:write(err .. '\\n')
  vim.cmd('cquit 1')
else
  print('Neovim startup, plugin registration, LSP configs, mappings and theme debounce passed')
  vim.cmd('qa!')
end
''')
        env = {
            "HOME": str(home), "PATH": str(commands) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_STATE_HOME": str(home / ".local/state"),
            "XDG_CACHE_HOME": str(home / ".cache"),
        }
        result = subprocess.run([nvim, "--headless", "-i", "NONE", "-n", "-u", "NONE",
                                 "--cmd", "lua vim.opt.rtp:prepend(" + json.dumps(str(data / "lazy.nvim")) + ")",
                                 "-l", str(check)], cwd=work, env=env,
                                text=True, capture_output=True, timeout=45)
        print(result.stdout + result.stderr, end="")
        if result.returncode == 0:
            local_lockfile = config / "lazy-lock.json"
            if local_lockfile.is_symlink() or json.loads(local_lockfile.read_text()) != pinned:
                raise AssertionError("Neovim did not seed an independent copy of the shared lockfile")
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
