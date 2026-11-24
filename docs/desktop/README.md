# Desktop setup for both Macs

Install the desktop apps you want on each Mac. The terminal baseline is
Gruvbox Dark and Light, FiraCode Nerd Font Mono at 12 pt, and the shared Zsh
and tmux configuration.

## Rectangle

1. On the Mac that already has Rectangle, open **Rectangle → Settings → App Settings**
   and export the configuration as JSON. Transfer the export directly to the other Mac.
2. On the destination Mac, run `brew install --cask rectangle`.
3. Open Rectangle and allow it under **System Settings → Privacy & Security → Accessibility**
   when prompted. That permission is granted separately on each Mac.
4. In **Rectangle → Settings → App Settings**, import the JSON. Test left half,
   right half, and maximize on the laptop display. If you use an external display,
   also test moving a window between displays.

Keep the export local. The app's import preserves the shortcut choices while
each Mac handles its own permissions and display layout.

[Rectangle import and export](https://github.com/rxhanson/Rectangle#import--export-json-config)

## iTerm2

1. Install iTerm2 if needed with `brew install --cask iterm2`. Install the font
   with `brew install --cask font-fira-code-nerd-font` if it is missing.
2. In **Settings → Profiles → Colors → Color Presets**, import both
   [Gruvbox Dark](iterm2/Gruvbox%20Dark.itermcolors) and
   [Gruvbox Light](iterm2/Gruvbox%20Light.itermcolors). Keep those names
   so `bin/sync-theme` can find them.
3. In the profile's **Text** tab, select FiraCode Nerd Font Mono at 12 pt.
   Choose the preset matching the current macOS appearance.
4. Start tmux and press `C-s` then `T` to apply the macOS appearance to tmux
   and the running iTerm2 sessions. Check it once in Light and once in Dark.

The two preset files contain colors exported from the existing setup.
Working directories, login settings, key mappings, and saved sessions are
configured independently on each Mac.

## Ghostty

1. Install Ghostty if needed with `brew install --cask ghostty`. Use the same
   FiraCode Nerd Font as iTerm2.
2. Open Ghostty's configuration and merge the three settings from
   [ghostty.conf](ghostty.conf). Replace any existing value for the same key.
   On macOS, Ghostty can read both `~/.config/ghostty/config.ghostty` and the
   configuration under `~/Library/Application Support/com.mitchellh.ghostty/`.
   The macOS-specific settings take precedence, so check that file for overrides.
3. Reload with `Cmd+Shift+,`. Check the font and switch macOS between Light and
   Dark to check both built-in Gruvbox themes. The tmux key bindings still work
   the same way. Ghostty follows system appearance through its own theme setting.

[Ghostty configuration](https://ghostty.org/docs/config)
