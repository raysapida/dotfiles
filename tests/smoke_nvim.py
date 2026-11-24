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
        r'''["']([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)["']''', (repo / "vimrc").read_text())}
    missing = sorted((required | {"lazy.nvim"}) - plugins.keys())
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
        for name in required | {"lazy.nvim"}:
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
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
