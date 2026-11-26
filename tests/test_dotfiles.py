"""Portable configuration checks. All homes, sockets and command logs are temporary.

Run: python3 -m unittest discover -s tests -v
Requires zsh and rcm; tmux integration is skipped when tmux is unavailable.
"""

import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")
RCUP = shutil.which("rcup")
TMUX = shutil.which("tmux")


class DotfilesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name).resolve()
        self.checkout = self.work / "elsewhere" / "dotfiles"
        shutil.copytree(REPO, self.checkout, ignore=shutil.ignore_patterns(
            ".git", ".claude", "__pycache__"))
        self.home = self.work / "raysapida"
        self.home.mkdir()
        (self.home / ".dotfiles").symlink_to(self.checkout, target_is_directory=True)
        self.stubs = self.work / "commands"
        self.stubs.mkdir()
        self.log = self.work / "commands.jsonl"
        # Do not inherit real HOME, XDG paths, TMUX, tokens or startup settings.
        self.env = {
            "HOME": str(self.home), "USER": "raysapida", "LOGNAME": "raysapida",
            "PATH": str(self.stubs) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM": "xterm-256color", "LANG": "en_US.UTF-8",
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "DOTFILES_TEST_LOG": str(self.log),
        }

    def run_command(self, args, *, check=True, cwd=None, env=None):
        result = subprocess.run(args, env=env or self.env, cwd=cwd or self.work,
                                text=True, capture_output=True, timeout=30)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def write(self, path, text, executable=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)

    def stub(self, name, body=""):
        self.write(self.stubs / name, "#!" + sys.executable + "\n"
                   "import json, os, sys\n"
                   "from pathlib import Path\n"
                   "with open(os.environ['DOTFILES_TEST_LOG'], 'a') as stream:\n"
                   "    stream.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + '\\n')\n"
                   + body + "\n", executable=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def shell(self, command, **kwargs):
        if not ZSH:
            self.skipTest("zsh is required")
        return self.run_command([ZSH, "-dfi", "-c",
                                 'source "$HOME/.dotfiles/zshrc"; ' + command], **kwargs)

    def test_syntax_and_no_home_usernames(self):
        if ZSH:
            self.run_command([ZSH, "-n", str(self.checkout / "zshrc")])
            self.run_command([ZSH, "-n", str(self.checkout / "antigen.zsh")])
        for name in ["mac_setup.sh", "bin/sync-theme", "bin/install-ruby-lsp", "bin/pull-all",
                     "bin/link-skills", "bin/dotfiles-doctor"]:
            self.run_command(["/bin/bash", "-n", str(self.checkout / name)])
        for name in ["bin/tat", "bin/tmux-spotify"]:
            self.run_command(["/bin/sh", "-n", str(self.checkout / name)])
        for name in ["zshrc", "vimrc", "tmux.conf", "mac_setup.sh", "bin/sync-theme"]:
            self.assertIsNone(re.search(r"/Users/[^/\s]+/", (self.checkout / name).read_text()), name)

    def test_vendored_antigen_matches_release_pin(self):
        metadata = json.loads((self.checkout / "docs/antigen.json").read_text())
        script = (self.checkout / "antigen.zsh").read_bytes()
        self.assertEqual(hashlib.sha256(script).hexdigest(), metadata["sha256"])
        self.assertIn(('"v' + metadata["version"] + '"').encode(), script)
        self.assertEqual(metadata["source"], "https://raw.githubusercontent.com/zsh-users/antigen/v"
                         + metadata["version"] + "/bin/antigen.zsh")

    def test_link_skills_creates_relative_links_and_preserves_existing(self):
        skills = sorted(p.parent.name for p in (self.checkout / "skills").glob("*/SKILL.md"))
        self.assertTrue(skills)
        kept = self.home / ".agents/skills" / skills[0]
        kept.mkdir(parents=True)
        result = self.run_command([str(self.checkout / "bin/link-skills")], check=False)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("skipped", result.stderr)
        self.assertTrue(kept.is_dir() and not kept.is_symlink())
        for dest in [".claude/skills", ".agents/skills"]:
            for name in skills:
                link = self.home / dest / name
                if link == kept:
                    continue
                self.assertEqual(str(link.readlink()), "../../.dotfiles/skills/" + name)
                self.assertTrue((link / "SKILL.md").is_file())
        kept.rmdir()
        self.run_command([str(self.checkout / "bin/link-skills")])
        again = self.run_command([str(self.checkout / "bin/link-skills")])
        self.assertEqual(again.stdout, "")

    def test_link_skills_backup_migration_preserves_files_and_symlinks(self):
        names = sorted(p.parent.name for p in (self.checkout / "skills").glob("*/SKILL.md"))
        agents = self.home / ".agents/skills"
        agents.mkdir(parents=True)
        directory, file, relative, dangling = [agents / name for name in names[:4]]
        directory.mkdir()
        (directory / "local-notes").write_text("keep this local version")
        file.write_text("existing file")
        relative.symlink_to(directory.name, target_is_directory=True)
        dangling.symlink_to("missing-local-skill")
        unrelated = agents / "installer-managed"
        unrelated.mkdir()

        result = self.run_command([str(self.checkout / "bin/link-skills"), "--backup-existing"])
        self.assertIn("backed up", result.stdout)
        backups = list((self.home / ".local/state/dotfiles/skill-backups").iterdir())
        self.assertEqual(len(backups), 1)
        saved = backups[0] / ".agents/skills"
        self.assertEqual((saved / directory.name / "local-notes").read_text(), "keep this local version")
        self.assertEqual((saved / file.name).read_text(), "existing file")
        self.assertEqual(str((saved / relative.name).readlink()), directory.name)
        self.assertEqual(str((saved / dangling.name).readlink()), "missing-local-skill")
        self.assertFalse(unrelated.is_symlink())
        for dest in [".agents/skills", ".claude/skills"]:
            for name in names:
                self.assertEqual((self.home / dest / name).resolve(), self.checkout / "skills" / name)
        again = self.run_command([str(self.checkout / "bin/link-skills"), "--backup-existing"])
        self.assertEqual(again.stdout, "")
        self.assertEqual(list(backups[0].parent.iterdir()), backups)

    def test_rcm_links_for_both_usernames_and_second_install(self):
        if not RCUP:
            self.skipTest("rcm is required")
        for username in ["raymond", "raysapida"]:
            with self.subTest(username=username):
                home = self.work / username
                home.mkdir(exist_ok=True)
                if not (home / ".dotfiles").exists():
                    (home / ".dotfiles").symlink_to(self.checkout, target_is_directory=True)
                env = dict(self.env, HOME=str(home), USER=username, LOGNAME=username,
                           RCRC=str(self.checkout / "rcrc"),
                           PATH=self.env["PATH"] + ":" + str(Path(RCUP).parent))
                for _ in range(2):
                    result = self.run_command([RCUP, "-K", "-d", str(home / ".dotfiles")], env=env)
                    self.assertEqual(result.stderr, "")
                for name, source in [(".zshrc", "zshrc"), (".vimrc", "vimrc"),
                                     (".tmux.conf", "tmux.conf"), ("antigen.zsh", "antigen.zsh"),
                                     (".config/nvim/init.lua", "config/nvim/init.lua"),
                                     (".config/mise/config.toml", "config/mise/config.toml")]:
                    self.assertTrue((home / name).is_symlink(), name)
                    self.assertEqual((home / name).resolve(), self.checkout / source)
                for name in [".tests", ".docs", ".README.md", ".mac_setup.sh", ".antigen.zsh"]:
                    self.assertFalse((home / name).exists(), name)

    def test_doctor_inspects_local_state_without_running_startup(self):
        for name, source in [(".rcrc", "rcrc"), (".zshrc", "zshrc"), (".vimrc", "vimrc"),
                             (".tmux.conf", "tmux.conf"), (".config/nvim/init.lua", "config/nvim/init.lua"),
                             ("antigen.zsh", "antigen.zsh")]:
            link = self.home / name
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(self.home / ".dotfiles" / source)
        self.write(self.home / ".zshenv", 'touch "$HOME/startup-ran"\n')
        cache = self.home / "custom antigen"
        (cache / "bundles").mkdir(parents=True)
        self.write(cache / "startup.zsh", 'touch "$HOME/startup-ran"\n')
        self.write(cache / ".zcompdump", 'touch "$HOME/startup-ran"\n')
        self.stub("defaults", "assert sys.argv[1] == 'read'\n"
                  "if sys.argv[2] == '-g':\n"
                  "    print('1')\n"
                  "elif os.environ.get('GHOSTTY_OVERRIDE') == '1':\n"
                  "    print('0')\n"
                  "else:\n"
                  "    sys.exit(1)\n")

        command = [str(self.checkout / "bin/dotfiles-doctor")]
        env = dict(self.env, ADOTDIR=str(cache), ANTIGEN_CACHE=str(cache / "startup.zsh"),
                   GHOSTTY_OVERRIDE="1")
        healthy = self.run_command(command, env=env, check=False)
        # A real system audit can flag host-specific paths even with an isolated home.
        warnings = [line for line in healthy.stdout.splitlines() if line.startswith("WARN")]
        self.assertTrue(all("Zsh completion audit" in line for line in warnings), healthy.stdout)
        self.assertEqual(healthy.returncode, int(bool(warnings)), healthy.stdout + healthy.stderr)
        for message in ["~/.tmux.conf links to ~/.dotfiles/tmux.conf",
                        "~/antigen.zsh links to the shared loader",
                        f"Antigen startup cache exists at {cache / 'startup.zsh'}",
                        "Ghostty appearance preference allows the system appearance"]:
            self.assertIn("OK   " + message, healthy.stdout)

        tmux_link = self.home / ".tmux.conf"
        tmux_link.unlink()
        tmux_link.symlink_to("missing-tmux.conf")
        local_loader = self.home / "antigen.zsh"
        local_loader.unlink()
        self.write(local_loader, 'touch "$HOME/startup-ran"\n')
        (cache / "bundles").rename(cache / "repos")
        completions = self.home / "writable completions"
        self.write(completions / "compaudit", 'touch "$HOME/startup-ran"\n')
        completions.chmod(0o775)
        problems = self.run_command(command, check=False,
                                    env=dict(env, FPATH=str(completions), GHOSTTY_OVERRIDE="0"))
        self.assertEqual(problems.returncode, 1, problems.stdout + problems.stderr)
        for message in ["~/.tmux.conf links to missing-tmux.conf", "~/antigen.zsh differs",
                        "Antigen has a legacy repos directory",
                        "Ghostty is forced to Light by the global"]:
            self.assertIn("WARN " + message, problems.stdout)
        if Path("/bin/zsh").is_file() and sys.platform == "darwin":
            self.assertIn(str(completions), problems.stdout)
        self.assertFalse((self.home / "startup-ran").exists())
        self.assertEqual(tmux_link.readlink(), Path("missing-tmux.conf"))
        self.assertEqual(completions.stat().st_mode & 0o777, 0o775)

    def test_shell_without_optional_dependencies_and_local_overrides(self):
        # Fail loudly if startup ever attempts installations or macOS automation.
        for name in ["corepack", "curl", "git", "osascript"]:
            self.stub(name, "sys.exit(90)")
        result = self.shell('print -r -- "READY:$BUN_INSTALL:$OPENCODE_DISABLE_CLAUDE_CODE"')
        self.assertEqual(result.stderr, "")
        self.assertIn("READY:" + str(self.home / ".bun") + ":1", result.stdout)
        self.assertEqual(self.calls(), [])
        self.stub("mise", "print('export DOTFILES_MISE_ACTIVATED=yes')")
        self.write(self.home / ".bun/_bun", "export DOTFILES_BUN_COMPLETION=yes\n")
        self.write(self.home / ".zshrc.local", "export OPENCODE_DISABLE_CLAUDE_CODE=local\n"
                   "export BUN_INSTALL=local-bun\nalias oc='local-opencode'\n")
        result = self.shell('print -r -- "$DOTFILES_MISE_ACTIVATED:$DOTFILES_BUN_COMPLETION:'
                            '$OPENCODE_DISABLE_CLAUDE_CODE:$BUN_INSTALL"; alias oc')
        self.assertEqual(result.stderr, "")
        self.assertIn("yes:yes:local:local-bun", result.stdout)
        self.assertIn("local-opencode", result.stdout)
        self.assertEqual(self.calls(), [["mise", "activate", "zsh"]])

    def test_unison_nearest_profile_argument_quoting_and_failure_status(self):
        self.stub("unison", "sys.exit(int(os.environ.get('UNISON_STATUS', '0')))")
        workspace = self.home / "work" / "outer" / "inner project" / "src"
        workspace.mkdir(parents=True)
        for name in ["outer", "inner project"]:
            self.write(self.home / ".unison" / (name + ".prf"), "")
        self.shell('ub -prefer "a path with spaces"', cwd=workspace)
        self.assertEqual(self.calls(), [["unison", "inner project", "-batch", "-prefer", "a path with spaces"]])
        result = self.shell('ub; exit $?', cwd=workspace,
                            env=dict(self.env, UNISON_STATUS="7"), check=False)
        self.assertEqual(result.returncode, 7)
        result = self.shell('ub; exit $?', check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("no Unison profile", result.stderr)

    def test_shell_uses_original_username_home(self):
        home = self.work / "raymond"
        home.mkdir()
        (home / ".dotfiles").symlink_to(self.checkout, target_is_directory=True)
        self.write(home / ".bun/_bun", "export DOTFILES_BUN_COMPLETION=yes\n")
        result = self.shell('print -r -- "$BUN_INSTALL:$DOTFILES_BUN_COMPLETION:$PATH"',
                            env=dict(self.env, HOME=str(home), USER="raymond", LOGNAME="raymond"))
        self.assertEqual(result.stderr, "")
        self.assertIn(str(home / ".bun") + ":yes:", result.stdout)
        self.assertIn(str(home / ".dotfiles/bin"), result.stdout)
        self.assertNotIn(str(self.home), result.stdout)

    def test_theme_selects_appearance_and_current_socket(self):
        self.stub("defaults", "print(os.environ.get('APPEARANCE', 'Dark'))")
        self.stub("tmux")
        self.stub("pgrep")
        self.stub("osascript", "sys.stdin.read()")
        plugin = self.home / ".tmux/plugins/tmux-gruvbox/gruvbox-tpm.tmux"
        self.write(plugin, "#!/bin/sh\nexit 0\n", executable=True)
        battery = self.home / ".tmux/plugins/tmux-battery/battery.tmux"
        self.write(battery, "#!/bin/sh\nexit 0\n", executable=True)
        for appearance, theme in [("Dark", "dark"), ("", "light")]:
            with self.subTest(theme=theme):
                self.log.unlink(missing_ok=True)
                env = dict(self.env, APPEARANCE=appearance,
                           TMUX="/tmp/dotfiles-custom.sock,123,0")
                self.run_command(["/bin/bash", str(self.checkout / "bin/sync-theme")], env=env)
                calls = self.calls()
                prefix = ["tmux", "-S", "/tmp/dotfiles-custom.sock"]
                self.assertIn(prefix + ["set", "-g", "@tmux-gruvbox", theme], calls)
                self.assertIn(prefix + ["run-shell", '"' + str(plugin) + '"'], calls)
                self.assertIn(prefix + ["run-shell", '"' + str(battery) + '"'], calls)
                self.assertIn(["osascript", "-", "Gruvbox " + theme.title()], calls)
                self.assertTrue(all(call[1:3] == prefix[1:3] for call in calls if call[0] == "tmux"))

    def test_theme_does_not_start_missing_server_or_iterm(self):
        self.stub("defaults", "sys.exit(1)")  # Light appearance has no defaults key.
        self.stub("tmux", "sys.exit(1)")
        self.stub("pgrep", "sys.exit(1)")
        self.stub("osascript", "sys.exit(90)")
        self.run_command(["/bin/bash", str(self.checkout / "bin/sync-theme")])
        self.assertEqual([call for call in self.calls() if call[0] == "tmux"], [["tmux", "list-sessions"]])
        self.assertFalse(any(call[0] == "osascript" for call in self.calls()))

    def test_bootstrap_refuses_existing_checkout_before_installing(self):
        (self.home / ".dotfiles").unlink()
        (self.home / ".dotfiles").mkdir()
        self.write(self.home / ".dotfiles/keep", "original checkout")
        for name in ["brew", "curl", "git"]:
            self.stub(name, "sys.exit(90)")
        result = self.run_command(["/bin/bash", str(self.checkout / "mac_setup.sh")], check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("another checkout", result.stderr)
        self.assertEqual((self.home / ".dotfiles/keep").read_text(), "original checkout")
        self.assertEqual(self.calls(), [])

    def test_tmux_loads_on_a_separate_socket(self):
        if not TMUX:
            self.skipTest("tmux is required")
        # Stub TPM so restore/background plugins cannot touch real sessions.
        self.write(self.home / ".tmux/plugins/tpm/tpm", "#!/bin/sh\nexit 0\n", executable=True)
        socket = str(self.work / "test.sock")
        command = [TMUX, "-S", socket]
        self.addCleanup(lambda: subprocess.run(command + ["kill-server"],
                        env=self.env, capture_output=True, timeout=10))
        self.run_command(command + ["-f", str(self.checkout / "tmux.conf"),
                                    "new-session", "-d", "-s", "dotfiles-test", "/bin/sleep 120"])
        for option, expected in [("prefix", "C-s"), ("mouse", "on"), ("focus-events", "on"),
                                 ("allow-passthrough", "on")]:
            self.assertEqual(self.run_command(command + ["show-options", "-gv", option]).stdout.strip(), expected)
        self.assertIn("sync-theme", self.run_command(command + ["list-keys", "-T", "prefix", "T"]).stdout)
        # A real plugin command must inherit this server's socket as well.
        self.stub("defaults", "print('Dark')")
        self.stub("pgrep", "sys.exit(1)")
        plugin = self.home / ".tmux/plugins/tmux-gruvbox/gruvbox-tpm.tmux"
        self.write(plugin, '#!/bin/sh\nsocket=$("' + TMUX + '" display-message -p "#{socket_path}")\n'
                   '"' + TMUX + '" set -g @dotfiles-test-socket "$socket"\n', executable=True)
        env = dict(self.env, TMUX=socket + ",123,0", PATH=self.env["PATH"] + ":" + str(Path(TMUX).parent))
        self.run_command(["/bin/bash", str(self.checkout / "bin/sync-theme")], env=env)
        # The option is written by the plugin to whichever server it inherited.
        self.assertEqual(self.run_command(command + ["show-options", "-gv", "@dotfiles-test-socket"]).stdout.strip(), socket)
        self.assertEqual(self.run_command(command + ["show-options", "-gv", "@tmux-gruvbox"]).stdout.strip(), "dark")


if __name__ == "__main__":
    unittest.main()
