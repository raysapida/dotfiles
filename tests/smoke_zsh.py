"""Check real Spaceship loading and prompt rendering in an isolated Zsh home.

Uses the existing Antigen script and cached repositories without downloads.
Checks cold/warm caches, repeated reloads and refreshed local prompt settings.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--antigen-script", type=Path, default=Path.home() / "antigen.zsh")
    parser.add_argument("--repos-dir", type=Path, default=Path.home() / ".antigen/repos")
    args = parser.parse_args()
    if not args.antigen_script.is_file() or not args.repos_dir.is_dir():
        parser.error("An installed Antigen script and cached plugin repositories are required")
    zsh = shutil.which("zsh")
    if not zsh:
        parser.error("zsh is required")
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="dotfiles-zsh-") as temp:
        home = Path(temp).resolve()
        checkout = home / "checkout"
        shutil.copytree(repo, checkout,
                        ignore=shutil.ignore_patterns(".git", ".claude", "__pycache__"))
        (home / ".dotfiles").symlink_to(checkout, target_is_directory=True)
        (home / ".zshrc").symlink_to(home / ".dotfiles/zshrc")
        # Count real loader executions without changing the installed script.
        (home / "antigen.zsh").write_text(
            'typeset -gi DOTFILES_TEST_ANTIGEN_LOADS=$(( ${DOTFILES_TEST_ANTIGEN_LOADS:-0} + 1 ))\n'
            + args.antigen_script.read_text())
        shutil.copytree(args.repos_dir, home / ".antigen/repos")
        # Spaceship trusts an inherited root when the directory still exists,
        # even if it belongs to an incompatible, older theme installation.
        (home / "previous-installation/spaceship").mkdir(parents=True)
        # Reproduce Conda adding its prefix after Antigen has been configured.
        # Real credentials, SDK scripts and runtimes are never sourced here.
        local_settings = (
            'PROMPT="(base) $PROMPT"\n'
            'SPACESHIP_PROMPT_ASYNC=false\n'
            'SPACESHIP_PROMPT_ORDER=(dir char)\n'
            'export DOTFILES_TEST_LOCAL_RELOADED=first\n')
        commands = home / "commands"
        commands.mkdir()
        for name in ["git", "curl", "brew", "corepack", "osascript"]:
            path = commands / name
            path.write_text("#!/bin/sh\nexit 99\n")
            path.chmod(0o700)
        env = {
            "HOME": str(home), "ZDOTDIR": str(home), "ADOTDIR": str(home / ".antigen"),
            "USER": "raysapida", "LOGNAME": "raysapida",
            "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
            "PATH": str(commands) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            # Nested shells can inherit this exported runtime value from a
            # different Spaceship installation or an older terminal session.
            "SPACESHIP_ROOT": str(home / "previous-installation/spaceship"),
        }
        probe = r'''
zmodload zsh/datetime
for startup in first reload_1 reload_2 reload_3; do
if [[ "$startup" != first ]]; then
print -r -- "SPACESHIP_CHAR_PREFIX='prompt-$startup'" > "$HOME/.spaceshiprc.zsh"
# Rapid synthetic edits must be newer than Spaceship's compiled preferences.
# Advance only this fixture's timestamp instead of sleeping between edits.
strftime -s preference_mtime '%Y%m%d%H%M.%S' $(( EPOCHSECONDS + 60 ))
touch -t "$preference_mtime" "$HOME/.spaceshiprc.zsh"
print -r -- "export DOTFILES_TEST_LOCAL_RELOADED='$startup'" >> "$HOME/.zshrc.local"
source "$HOME/.dotfiles/zshrc" || exit 1
fi
if [[ "${_ANTIGEN_CACHE_LOADED:-${_ZCACHE_CACHE_LOADED:-false}}" != true ]]; then
  print -u2 -- 'Antigen did not load its generated startup cache'
  exit 9
fi
if (( ! ${+functions[prompt_spaceship_precmd]} )); then
  print -u2 -r -- "Spaceship was not loaded; fallback prompt: $PROMPT"
  exit 2
fi
if [[ "${precmd_functions[*]}" != *prompt_spaceship_precmd* ]]; then
  print -u2 -- 'Spaceship prompt hook is missing'
  exit 3
fi
prompt_hooks=(${(M)precmd_functions:#prompt_spaceship_precmd})
if (( DOTFILES_TEST_ANTIGEN_LOADS != 1 || ${#prompt_hooks} != 1 )); then
  print -u2 -- 'Reload reinitialized Antigen or duplicated the prompt hook'
  exit 6
fi
if [[ "$SPACESHIP_CHAR_PREFIX" != "prompt-$startup" || "$DOTFILES_TEST_LOCAL_RELOADED" != "$startup" ]]; then
  print -u2 -- 'Reload did not refresh prompt preferences and local overrides'
  exit 7
fi
if [[ "$startup" == first ]]; then
  initial_bundles=$(typeset -p _ANTIGEN_BUNDLE_RECORD)
elif [[ "$(typeset -p _ANTIGEN_BUNDLE_RECORD)" != "$initial_bundles" ]]; then
  print -u2 -- 'Reload changed the registered plugin set'
  exit 8
fi
# Execute the actual hook that runs just before Zsh displays its prompt.
prompt_spaceship_precmd
if [[ "$PROMPT" != '$(spaceship::prompt)' ]]; then
  print -u2 -- 'Spaceship did not replace the fallback prompt'
  exit 4
fi
rendered=$(print -P -- "$PROMPT")
if [[ "$rendered" == *'$(spaceship::prompt)'* || "$rendered" != *"$SPACESHIP_CHAR_SYMBOL"* || "$rendered" != *"prompt-$startup"* ]]; then
  print -u2 -- 'Spaceship prompt did not render'
  exit 5
fi
print -r -- SPACESHIP_PROMPT_OK
done
'''
        for cache in ["cold", "warm"]:
            (home / ".zshrc.local").write_text(local_settings)
            preferences = home / ".spaceshiprc.zsh"
            preferences.write_text("SPACESHIP_CHAR_PREFIX='prompt-first'\n")
            timestamp = time.time() + 60
            os.utime(preferences, (timestamp, timestamp))
            # Automatic .zshrc loading has a different ZSH_EVAL_CONTEXT from
            # an interactive source command; Antigen enables caching here.
            result = subprocess.run([zsh, "-di", "-c", probe], cwd=home, env=env,
                                    text=True, capture_output=True, timeout=30)
            if result.returncode or result.stderr or "SPACESHIP_PROMPT_OK" not in result.stdout:
                print(cache + " cache prompt check failed:")
                print(result.stdout + result.stderr, end="")
                return result.returncode or 1
            if not any((home / ".antigen" / path).is_file()
                       for path in ["init.zsh", ".cache/.zcache-payload"]):
                print("Antigen did not generate a startup cache")
                return 1
            print(cache + " cache: startup and three reloads passed; one loader, one prompt hook, local settings refreshed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
