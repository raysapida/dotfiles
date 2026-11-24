#!/usr/bin/env bash
# Start (or resume) a headless Codex run on a handoff prompt, sandboxed to the project.
#
#   launch.sh --dir <abs project dir> --prompt <abs prompt file> [--resume <thread id>]
#             [--network] [--model <model>|config] [--path <dir>]...
#
# The model defaults to gpt-6-luna; `--model config` uses the Codex config default instead.
#
# Prints the log paths first, then blocks until the run ends.

set -euo pipefail

dir="" prompt="" resume="" network=false model="gpt-6-luna"
extra_paths=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --resume) resume="$2"; shift 2 ;;
    --network) network=true; shift ;;
    --model) model="$2"; shift 2 ;;
    --path) extra_paths+=("$2"); shift 2 ;;
    *) echo "launch.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done

[[ "$dir" == /* && -d "$dir" ]] || { echo "launch.sh: --dir must be an existing absolute path" >&2; exit 2; }
[[ "$prompt" == /* && -f "$prompt" ]] || { echo "launch.sh: --prompt must be an existing absolute file" >&2; exit 2; }
command -v codex >/dev/null || { echo "launch.sh: codex not on PATH" >&2; exit 2; }

cd "$dir"

tmp="$dir/.handoff-tmp"
mkdir -p "$tmp"
if git rev-parse --git-dir >/dev/null 2>&1; then
  exclude="$(git rev-parse --git-common-dir)/info/exclude"
  grep -qx '.handoff-tmp/' "$exclude" 2>/dev/null || echo '.handoff-tmp/' >> "$exclude"
fi

shell_path="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ -f .ruby-version ]]; then
  ruby_bin="$HOME/.local/share/mise/installs/ruby/$(tr -d '[:space:]' < .ruby-version)/bin"
  [[ -d "$ruby_bin" ]] || { echo "launch.sh: .ruby-version wants $ruby_bin, which doesn't exist" >&2; exit 2; }
  shell_path="$ruby_bin:$shell_path"
fi
for p in "${extra_paths[@]+"${extra_paths[@]}"}"; do shell_path="$p:$shell_path"; done

stamp="$(date +%Y%m%d-%H%M%S)"
log="$tmp/codex-$stamp.jsonl"
err="$tmp/codex-$stamp.err"
last="$tmp/codex-$stamp.last.md"
echo "log:  $log"
echo "err:  $err"
echo "last: $last"
echo "model: ${model/#config/(Codex config default)}"

args=(-c 'sandbox_mode="workspace-write"'
      -c "sandbox_workspace_write.network_access=$network"
      -c "shell_environment_policy.set.PATH=\"$shell_path\""
      -c "shell_environment_policy.set.XDG_CACHE_HOME=\"$tmp/cache\""
      -c "shell_environment_policy.set.RUBOCOP_CACHE_ROOT=\"$tmp/cache/rubocop\""
      --json -o "$last")
[[ -n "$model" && "$model" != "config" ]] && args+=(-m "$model")

if [[ -n "$resume" ]]; then
  codex exec resume "${args[@]}" "$resume" "$(cat "$prompt")" < /dev/null > "$log" 2> "$err"
else
  codex exec "${args[@]}" "$(cat "$prompt")" < /dev/null > "$log" 2> "$err"
fi
status=$?
echo "launch.sh: codex exited $status"
exit $status
