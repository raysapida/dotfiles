"""Exercise real terminal completion, suggestions, Conda and mise before activation.

Uses a temporary home and plugin cache. Installed runtimes and Conda are reused;
mise state/config and Conda user directories stay in the temporary home. No
package installation or loader activation is performed in the real home.
"""

import argparse
import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import time

from smoke_antigen_migration import tree_snapshot


REPO = Path(__file__).resolve().parents[1]


class Terminal:
    def __init__(self, home, env, zsh):
        self.pending = b""
        self.transcript = bytearray()
        self.counter = 0
        self.capture_counter = 0
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))
            os.chdir(home / "workspace")
            os.execve(zsh, [zsh, "-di"], env)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))

    def expect(self, pattern, timeout=20):
        pattern = re.compile(pattern)
        deadline = time.monotonic() + timeout
        while True:
            match = pattern.search(self.pending)
            if match:
                self.pending = self.pending[match.end():]
                return match
            if time.monotonic() >= deadline:
                raise RuntimeError("Timed out waiting for terminal response: " + repr(pattern.pattern))
            ready, _, _ = select.select([self.fd], [], [], 0.1)
            if not ready:
                continue
            try:
                chunk = os.read(self.fd, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    raise RuntimeError("Test terminal exited before responding") from error
                raise
            if not chunk:
                raise RuntimeError("Test terminal closed before responding")
            self.pending += chunk
            self.transcript.extend(chunk)

    def ready(self):
        self.expect(rb"__DOTFILES_TERMINAL_READY__\r?\n")

    def check(self, code, label):
        self.counter += 1
        prefix = "__DOTFILES_CHECK_" + str(self.counter) + ":"
        # The echoed input contains quotes between the marker and status; only
        # the command's actual output matches the response expression.
        command = "{ " + code + "; }; _dotfiles_test_status=$?; print -r -- '" + prefix + "'$_dotfiles_test_status'__'\n"
        os.write(self.fd, command.encode())
        match = self.expect(re.escape(prefix.encode()) + rb"([0-9]+)__\r?\n")
        if int(match[1]):
            raise RuntimeError(label + " failed with status " + match[1].decode())
        self.ready()
        print(label + ": passed", flush=True)

    def capture(self, keys=b"", wait_for=None):
        os.write(self.fd, keys)
        if wait_for:
            self.expect(re.escape(wait_for.encode()))
        self.capture_counter += 1
        os.write(self.fd, b"\x18\x14")  # Ctrl-X Ctrl-T invokes the inspection widget.
        prefix = "__DOTFILES_BUFFER_" + str(self.capture_counter) + "__"
        buffer = self.expect(re.escape(prefix.encode()) + rb"(.*?)__END_BUFFER__\r?\n")[1].decode()
        suggestion = self.expect(rb"__DOTFILES_SUGGESTION__(.*?)__END_SUGGESTION__\r?\n")[1].decode()
        return buffer, suggestion

    def close(self):
        # Let Zsh close its suggestion workers and finish history/cache writes.
        # Killing the shell immediately can race temporary-home cleanup.
        try:
            os.write(self.fd, b"\x15if (( ${+functions[async_stop_worker]} )); then async_stop_worker spaceship; fi; exit\n")
        except OSError:
            pass
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            exited, _ = os.waitpid(self.pid, os.WNOHANG)
            if exited:
                os.close(self.fd)
                return
            ready, _, _ = select.select([self.fd], [], [], 0.05)
            if ready:
                try:
                    os.read(self.fd, 65536)
                except OSError:
                    pass
        try:
            os.kill(self.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)
        os.close(self.fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    host_home = Path.home()
    parser.add_argument("--antigen-script", type=Path, default=REPO / "antigen.zsh")
    parser.add_argument("--conda-bin", type=Path, default=host_home / "opt/miniconda3/bin/conda")
    parser.add_argument("--mise-bin", type=Path, default=host_home / ".local/bin/mise")
    parser.add_argument("--repos-dir", type=Path, default=host_home / ".antigen/repos")
    args = parser.parse_args()
    for path in [args.antigen_script, args.conda_bin, args.mise_bin]:
        if not path.is_file():
            parser.error("Required installed tool or loader is missing: " + str(path))
    source_repos = args.repos_dir.resolve()
    if not source_repos.is_dir() or not any((p / ".git").exists() for p in source_repos.iterdir()):
        parser.error("A v1 plugin-cache copy is required; pass --repos-dir /path/to/v1-backup/repos")
    zsh = "/bin/zsh" if Path("/bin/zsh").exists() else shutil.which("zsh")
    if not zsh:
        parser.error("zsh is required")
    if Path("/tmp/antigen-v2-migrate.log").exists():
        parser.error("Another Antigen migration log exists; run these checks sequentially")
    mise_config = (host_home / ".config/mise/config.toml").read_text()
    versions = {}
    for name in ["ruby", "node"]:
        match = re.search(r'^' + name + r'\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', mise_config, re.MULTILINE)
        if not match:
            parser.error("This check requires an exact installed global " + name + " version")
        versions[name] = match[1]
    installs = host_home / ".local/share/mise/installs"
    alternatives = sorted((p.name for p in (installs / "ruby").iterdir()
                           if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", p.name)
                           and p.name != versions["ruby"] and (p / "bin/ruby").is_file()),
                          key=lambda name: tuple(map(int, name.split("."))))
    if not alternatives:
        parser.error("A second installed Ruby version is needed to verify project selection")
    project_ruby = alternatives[-1]
    source_cache = host_home / ".antigen"
    before_cache = tree_snapshot(source_cache)
    before_repos = tree_snapshot(source_repos)
    before_loader = (host_home / "antigen.zsh").read_bytes()

    with tempfile.TemporaryDirectory(prefix="dotfiles-terminal-") as temp:
        work = Path(temp).resolve()
        home = work / "home"
        home.mkdir()
        checkout = home / "checkout"
        shutil.copytree(REPO, checkout, symlinks=True,
                        ignore=shutil.ignore_patterns(".git", ".claude", "__pycache__"))
        (home / ".dotfiles").symlink_to(checkout, target_is_directory=True)
        (home / ".zshrc").symlink_to(home / ".dotfiles/zshrc")
        shutil.copy2(args.antigen_script, home / "antigen.zsh")
        shutil.copytree(source_repos, home / ".antigen/repos", symlinks=True)
        if (host_home / ".spaceshiprc.zsh").is_file():
            shutil.copy2(host_home / ".spaceshiprc.zsh", home / ".spaceshiprc.zsh")
        config = home / ".config/mise/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text(mise_config)
        data = home / ".local/share/mise"
        data.mkdir(parents=True)
        (data / "installs").symlink_to(installs, target_is_directory=True)
        binary = home / ".local/bin/mise"
        binary.parent.mkdir(parents=True)
        binary.symlink_to(args.mise_bin.resolve())
        for cache_source in [host_home / ".cache/mise", host_home / "Library/Caches/mise"]:
            if cache_source.is_dir():
                shutil.copytree(cache_source, home / ".cache/mise", dirs_exist_ok=True)
                break
        workspace = home / "workspace"
        workspace.mkdir()
        (workspace / "completion-fixture.txt").write_text("terminal completion fixture\n")
        project = home / "project"
        project.mkdir()
        (project / ".ruby-version").write_text(project_ruby + "\n")
        (home / ".zsh_history").write_text(": 1699990000:0;echo DOTFILES_AUTOSUGGESTION_SENTINEL\n")
        (home / ".zshrc.local").write_text(r'''
eval "$("$DOTFILES_TEST_CONDA" shell.zsh hook)"
conda activate base
if (( ! ${+functions[_dotfiles_test_capture]} )); then
  _dotfiles_test_capture() {
    (( ++_dotfiles_test_captures ))
    print -r -- "__DOTFILES_BUFFER_${_dotfiles_test_captures}__${BUFFER}__END_BUFFER__"
    print -r -- "__DOTFILES_SUGGESTION__${POSTDISPLAY}__END_SUGGESTION__"
    BUFFER=''
    POSTDISPLAY=''
    zle .reset-prompt
  }
  ZSH_AUTOSUGGEST_IGNORE_WIDGETS+=(_dotfiles_test_capture)
  zle -N _dotfiles_test_capture
  bindkey '^X^T' _dotfiles_test_capture
  if (( ${+widgets[zle-line-init]} )); then
    zle -A zle-line-init _dotfiles_test_previous_init
  fi
  _dotfiles_test_ready() {
    # Antigen v1's existing line-init widget can return 1 once its cache is
    # loaded. Preserve that widget and still signal that input is safe.
    if (( ${+widgets[_dotfiles_test_previous_init]} )); then
      zle _dotfiles_test_previous_init || true
    fi
    print -r -- __DOTFILES_TERMINAL_READY__
  }
  zle -N zle-line-init _dotfiles_test_ready
fi
''')
        env = {
            "HOME": str(home), "ZDOTDIR": str(home), "USER": "raysapida", "LOGNAME": "raysapida",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
            "XDG_CONFIG_HOME": str(home / ".config"), "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_CACHE_HOME": str(home / ".cache"), "XDG_STATE_HOME": str(home / ".local/state"),
            "MISE_DATA_DIR": str(data), "MISE_CACHE_DIR": str(home / ".cache/mise"),
            "MISE_OFFLINE": "1", "MISE_NOT_FOUND_AUTO_INSTALL": "0", "MISE_HIDE_UPDATE_WARNING": "1",
            "PYTHONDONTWRITEBYTECODE": "1", "CONDA_PKGS_DIRS": str(home / ".conda/pkgs"),
            "CONDA_ENVS_PATH": str(home / ".conda/envs"), "GIT_OPTIONAL_LOCKS": "0",
            "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "protocol.allow",
            "GIT_CONFIG_VALUE_0": "never", "GIT_TERMINAL_PROMPT": "0",
            "DOTFILES_TEST_CONDA": str(args.conda_bin.resolve()),
        }
        policy = subprocess.run([shutil.which("git", path=env["PATH"]), "config", "--get", "protocol.allow"],
                                env=env, text=True, capture_output=True)
        if policy.returncode or policy.stdout.strip() != "never":
            raise RuntimeError("Git network protocols were not disabled in the test environment")
        for cache_state in ["cold", "warm"]:
            print(cache_state + " cache terminal:", flush=True)
            terminal = Terminal(home, env, zsh)
            try:
                terminal.ready()
                terminal.check('[[ "${_ANTIGEN_CACHE_LOADED:-${_ZCACHE_CACHE_LOADED:-false}}" == true ]] && '
                               '[[ "$PROMPT" == *\'spaceship::prompt\'* && "${_comps[git]}" == _git ]]'
                               ' && (( ${+functions[_zsh_highlight]} && ${+functions[_zsh_autosuggest_start]} ))',
                               "Prompt, completions and highlighting registration")
                buffer, _ = terminal.capture(b"git statu\t")
                if buffer.strip() != "git status":
                    raise RuntimeError("Git Tab completion failed: " + repr(buffer))
                print("Git Tab completion: passed", flush=True)
                buffer, _ = terminal.capture(b"cat completion-fi\t")
                if buffer.strip() != "cat completion-fixture.txt":
                    raise RuntimeError("File Tab completion failed: " + repr(buffer))
                print("File Tab completion: passed", flush=True)
                buffer, suggestion = terminal.capture(b"echo DOTFILES_AUTO", wait_for="SUGGESTION_SENTINEL")
                if buffer != "echo DOTFILES_AUTO" or suggestion != "SUGGESTION_SENTINEL":
                    raise RuntimeError("History autosuggestion did not match the seeded command")
                print("Visible history autosuggestion: passed", flush=True)
                runtime_check = ('[[ "$(ruby --version)" == "ruby ' + versions["ruby"] + ' "* ]]'
                                 ' && [[ "$(node --version)" == v' + versions["node"] + ' ]]')
                terminal.check('[[ "$CONDA_DEFAULT_ENV" == base ]] && ' + runtime_check,
                               "Conda base with global mise Ruby/Node")
                terminal.check('[[ "$(command -v python)" == "$CONDA_PREFIX/bin/python" ]]',
                               "Conda base interpreter selection")
                terminal.check('cd "$HOME/project"; _mise_hook; [[ "$(ruby --version)" == "ruby '
                               + project_ruby + ' "* ]]', "Project .ruby-version selection")
                terminal.check('cd "$HOME/workspace"; _mise_hook; ' + runtime_check,
                               "Return to global mise versions")
                terminal.check('conda deactivate', "Conda deactivate")
                terminal.check('[[ ${CONDA_SHLVL:-0} == 0 ]] && ' + runtime_check,
                               "mise versions after Conda deactivate")
                terminal.check('conda activate base', "Conda reactivate")
                terminal.check('[[ "$CONDA_DEFAULT_ENV" == base ]] && ' + runtime_check,
                               "mise versions after Conda reactivate")
                terminal.check('for i in 1 2 3; do source "$HOME/.zshrc" || exit; done; '
                               'hooks=(${(M)precmd_functions:#prompt_spaceship_precmd}); '
                               '(( ${#hooks} == 1 )) && [[ ${_comps[git]} == _git ]]',
                               "Three reloads with Conda/mise and unique prompt hook")
                terminal.check(runtime_check, "mise versions after three reloads")
                buffer, _ = terminal.capture(b"git statu\t")
                if buffer.strip() != "git status":
                    raise RuntimeError("Git Tab completion failed after reloads")
                buffer, suggestion = terminal.capture(b"echo DOTFILES_AUTO", wait_for="SUGGESTION_SENTINEL")
                if buffer != "echo DOTFILES_AUTO" or suggestion != "SUGGESTION_SENTINEL":
                    raise RuntimeError("History autosuggestion failed after reloads")
                print("Tab completion and visible suggestions after reloads: passed", flush=True)
                if not any((home / ".antigen" / path).is_file()
                           for path in ["init.zsh", ".cache/.zcache-payload"]):
                    raise RuntimeError("Terminal startup did not generate an Antigen cache")
            except BaseException:
                artifact = Path(tempfile.mkdtemp(prefix="dotfiles-terminal-failure-"))
                artifact.chmod(0o700)
                log = artifact / "transcript.log"
                log.write_bytes(terminal.transcript)
                log.chmod(0o600)
                print("Private terminal diagnostics: " + str(log), flush=True)
                raise
            finally:
                terminal.close()
    if (tree_snapshot(source_cache) != before_cache or tree_snapshot(source_repos) != before_repos
            or (host_home / "antigen.zsh").read_bytes() != before_loader):
        raise RuntimeError("Live Antigen cache or loader changed during integration checks")
    print("Integration checks passed; live Antigen loader/cache unchanged", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
