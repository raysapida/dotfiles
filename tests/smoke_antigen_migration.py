"""Rehearse v1-to-v2 cache migration without changing the installed Antigen cache.

Copies the complete cache, checks every Git checkout before/after native migration,
then verifies cold/warm startup with the pinned loader. Network and Git mutations
are blocked. Existing files are preserved; generated .zwc/.antigen-compat files
may be rebuilt when plugins start. Only the upstream's temporary /tmp log is shared.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
GIT = shutil.which("git")
ZSH = shutil.which("zsh")


def tree_snapshot(root):
    """Record bytes, link targets and modes; never follow links out of a tree."""
    result = {}
    for directory, dirs, files in os.walk(root):
        for name in sorted(dirs + files):
            path = Path(directory) / name
            info = path.lstat()
            entry = {"mode": stat.S_IMODE(info.st_mode)}
            if path.is_symlink():
                entry["link"] = os.readlink(path)
            elif path.is_file():
                entry["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            else:
                entry["directory"] = True
            result[str(path.relative_to(root))] = entry
    return result


def git_head(path):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_CONFIG_GLOBAL=os.devnull,
               GIT_CONFIG_NOSYSTEM="1")
    return subprocess.check_output([GIT, "-C", str(path), "rev-parse", "HEAD"],
                                   env=env, text=True).strip()


def checkouts(root):
    result = []
    for directory, dirs, files in os.walk(root):
        if ".git" in dirs or ".git" in files:
            result.append(Path(directory))
            dirs[:] = []  # Submodules belong to their enclosing plugin snapshot.
    return sorted(result)


def run_shell(home, env, code, automatic_startup=False):
    flags = "-di" if automatic_startup else "-dfi"
    result = subprocess.run([ZSH, flags, "-c", code], cwd=home, env=env,
                            text=True, capture_output=True, timeout=40)
    if result.returncode or result.stderr:
        raise RuntimeError("Isolated shell check failed:\n" + result.stdout + result.stderr)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path, default=Path.home() / ".antigen")
    args = parser.parse_args()
    source = args.cache_dir.resolve()
    installed = Path.home() / "antigen.zsh"
    if not GIT or not ZSH or not (source / "repos").is_dir():
        parser.error("git, zsh and a v1 cache with a repos directory are required")
    # The unmodified upstream helper uses a fixed log filename. Refuse to
    # overwrite an existing log or race another migration rehearsal.
    migration_log = Path("/tmp/antigen-v2-migrate.log")
    if os.path.lexists(migration_log):
        parser.error("An upstream migration log already exists: " + str(migration_log))
    original_cache = tree_snapshot(source)
    original_loader = installed.read_bytes()

    with tempfile.TemporaryDirectory(prefix="dotfiles-migration-") as temp:
        work = Path(temp).resolve()
        home = work / "home"
        home.mkdir()
        checkout = home / "checkout"
        shutil.copytree(REPO, checkout,
                        ignore=shutil.ignore_patterns(".git", ".claude", "__pycache__"),
                        symlinks=True)
        (home / ".dotfiles").symlink_to(checkout, target_is_directory=True)
        (home / ".zshrc").symlink_to(home / ".dotfiles/zshrc")
        (home / "antigen.zsh").symlink_to(home / ".dotfiles/antigen.zsh")
        cache = home / ".antigen"
        shutil.copytree(source, cache, symlinks=True)
        if tree_snapshot(cache) != original_cache:
            raise RuntimeError("The cache copy does not match the original snapshot")

        # Exercise preservation of tracked edits and untracked files as well
        # as the live cache's clean repositories. Only this copy is changed.
        repos = checkouts(cache / "repos")
        if not repos:
            raise RuntimeError("No cached plugin checkouts were found")
        sentinel = repos[0] / ".dotfiles-migration-sentinel"
        sentinel.write_text("Untracked migration preservation probe\n")
        sentinel.chmod(0o640)
        readme = next(iter(sorted(repos[0].glob("README*"))), None)
        if readme and readme.is_file() and not readme.is_symlink():
            with readme.open("a") as stream:
                stream.write("\nTracked migration preservation probe\n")
        before = {git_head(path): (path.name, tree_snapshot(path)) for path in repos}
        if len(before) != len(repos):
            raise RuntimeError("Duplicate checkout HEADs require an unambiguous inventory")
        legacy_files = {name: entry for name, entry in tree_snapshot(cache).items()
                        if name != "repos" and not name.startswith("repos/")}

        commands = work / "commands"
        commands.mkdir()
        command_log = work / "commands.jsonl"
        wrapper_source = "#!" + sys.executable + chr(10) + """import json, os, subprocess, sys
from pathlib import Path
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
rest = list(args)
while rest and rest[0].startswith('-'):
    option = rest.pop(0)
    if option in {'-C', '-c', '--git-dir', '--work-tree'} and rest:
        rest.pop(0)
operation = rest[0] if rest else ''
readonly = {'rev-parse', 'rev-list', 'show', 'log', 'diff', 'status', 'describe'}
allowed = operation in readonly or args in [['--version'], ['version'], ['--exec-path']]
if operation == 'config':
    allowed = any(flag in rest for flag in ['--get', '--get-all', '--get-regexp', '--list', '-l'])
if operation == 'symbolic-ref':
    allowed = (len([arg for arg in rest[1:] if not arg.startswith('-')]) == 1
               and not any(arg in rest for arg in ['--delete', '-d']))
probe = tool == 'brew' and args == ['command', 'command-not-found-init']
allowed = probe or (tool == 'git' and allowed and not any(arg.startswith('--output') for arg in args))
with open(os.environ['DOTFILES_MIGRATION_LOG'], 'a') as stream:
    stream.write(json.dumps({'tool': tool, 'operation': operation, 'args': args, 'allowed': allowed}) + chr(10))
if not allowed:
    sys.exit(99)
if probe:
    sys.exit(1)  # Optional Homebrew command-not-found integration is unavailable here.
sys.exit(subprocess.call([os.environ['DOTFILES_REAL_GIT'], '-c', 'core.fsmonitor=false', *args]))
"""
        for name in ["git", "curl", "wget", "brew", "corepack", "osascript"]:
            path = commands / name
            path.write_text(wrapper_source)
            path.chmod(0o700)
        wrapper = commands / "git"
        env = {
            "HOME": str(home), "ZDOTDIR": str(home), "ADOTDIR": str(cache),
            "PATH": str(commands) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
            "USER": "raysapida", "LOGNAME": "raysapida",
            "GIT_OPTIONAL_LOCKS": "0", "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1", "DOTFILES_REAL_GIT": GIT,
            "DOTFILES_MIGRATION_LOG": str(command_log),
        }
        # Verify the blockers before trusting them to police plugin startup.
        allowed = subprocess.run([str(wrapper), "--version"], cwd=home, env=env, capture_output=True)
        denied = subprocess.run([str(wrapper), "clone", "https://example.invalid/blocked.git"],
                                cwd=home, env=env, capture_output=True)
        calls = [json.loads(line) for line in command_log.read_text().splitlines()]
        if allowed.returncode or denied.returncode != 99 or [c["allowed"] for c in calls] != [True, False]:
            raise RuntimeError("Read-only Git wrapper did not enforce its policy")
        for name in ["curl", "wget", "brew", "corepack", "osascript"]:
            result = subprocess.run([str(commands / name), "--version"], cwd=home, env=env,
                                    capture_output=True)
            if result.returncode != 99:
                raise RuntimeError("Command blocker failed: " + name)
        probe = subprocess.run([str(commands / "brew"), "command", "command-not-found-init"],
                               cwd=home, env=env, capture_output=True)
        if probe.returncode != 1 or not json.loads(command_log.read_text().splitlines()[-1])["allowed"]:
            raise RuntimeError("Optional Homebrew availability probe was not simulated correctly")
        command_log.write_text("")
        # Loading only Antigen runs its native layout migration, before plugins
        # can create any generated bytecode. All original bytes must match here.
        output = run_shell(home, env, 'source "$HOME/antigen.zsh" || exit; '
                           '[[ -d "$ADOTDIR/bundles" ]] || exit 2; print MIGRATION_OK')
        if "MIGRATION_OK" not in output:
            raise RuntimeError("Native migration did not complete")
        migrated = checkouts(cache / "bundles")
        if checkouts(cache / "repos") or len(migrated) != len(repos):
            raise RuntimeError("Migration lost or failed to move a plugin checkout")

        def verify_plugins(ignore_generated=False):
            for path in migrated:
                head = git_head(path)
                if head not in before:
                    raise RuntimeError("Migration changed a plugin commit: " + str(path))
                expected = before[head][1]
                actual = tree_snapshot(path)
                if ignore_generated:
                    suffixes = (".zwc", ".antigen-compat")
                    expected = {k: v for k, v in expected.items() if not k.endswith(suffixes)}
                    actual = {k: v for k, v in actual.items() if not k.endswith(suffixes)}
                if actual != expected:
                    changed = sorted(k for k in expected.keys() | actual.keys()
                                     if expected.get(k) != actual.get(k))
                    raise RuntimeError("Plugin files changed: " + before[head][0]
                                       + " " + ", ".join(changed[:8]))

        verify_plugins()
        print("Native migration: " + str(len(migrated)) + "/" + str(len(repos))
              + " checkouts moved; commits, Git metadata, tracked edits and untracked files preserved")
        leftovers = sorted(p.name for p in (cache / "repos").iterdir())
        print("Legacy repos leftovers: " + (", ".join(leftovers) or "none"))
        (home / ".zshrc.local").write_text(
            "SPACESHIP_PROMPT_ASYNC=false\nSPACESHIP_PROMPT_ORDER=(dir char)\n")
        probe = r'''
[[ "$_ANTIGEN_CACHE_LOADED" == true && "$_ANTIGEN_CACHE_VERSION" == v2.2.3 ]] || exit 1
[[ "$SPACESHIP_ROOT" == "$HOME/.antigen/bundles/"* ]] || exit 2
[[ "${precmd_functions[*]}" == *prompt_spaceship_precmd* ]] || exit 3
prompt_spaceship_precmd
[[ "$PROMPT" == '$(spaceship::prompt)' ]] || exit 4
rendered=$(print -P -- "$PROMPT")
[[ "$rendered" == *"$SPACESHIP_CHAR_SYMBOL"* ]] || exit 5
print -rl -- "${_ANTIGEN_BUNDLE_RECORD[@]}" > "$HOME/registered-bundles.txt"
print MIGRATED_PROMPT_OK
'''
        registered = None
        for label in ["cold", "warm"]:
            output = run_shell(home, env, probe, automatic_startup=True)
            if "MIGRATED_PROMPT_OK" not in output or "Moving bundles" in output:
                raise RuntimeError("Migrated cache was not reused cleanly")
            records = (home / "registered-bundles.txt").read_text()
            if registered is not None and registered != records:
                raise RuntimeError("Warm startup changed the registered plugin set")
            registered = records
            if len(checkouts(cache / "bundles")) != len(repos):
                raise RuntimeError("Startup created or removed a plugin checkout")
            verify_plugins(ignore_generated=True)
            print(label + " startup: migrated cache reused, Spaceship loaded, plugin commits and files preserved")
        calls = [json.loads(line) for line in command_log.read_text().splitlines()] if command_log.exists() else []
        denied = [call for call in calls if not call["allowed"]]
        if denied:
            descriptions = [call["tool"] + " " + call["operation"] + " "
                            + " ".join(arg for arg in call["args"] if arg.startswith("-"))
                            for call in denied]
            raise RuntimeError("Startup attempted blocked command(s): " + "; ".join(descriptions))
        if not (cache / "init.zsh").is_file():
            raise RuntimeError("Antigen did not generate its v2 startup cache")
        final_cache = tree_snapshot(cache)
        if any(final_cache.get(name) != entry for name, entry in legacy_files.items()):
            raise RuntimeError("Migration changed existing legacy cache files")
        if tree_snapshot(source) != original_cache or installed.read_bytes() != original_loader:
            raise RuntimeError("Live cache or loader changed during the rehearsal")
        if os.path.lexists(migration_log):
            raise RuntimeError("The upstream migrator left a temporary error log: " + str(migration_log))
        print("No downloads or Git mutations; optional Homebrew lookup simulated unavailable")
        print("Legacy cache files and live loader/cache unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
