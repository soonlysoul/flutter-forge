#!/usr/bin/env bash
# checkpoint-reminder — Stop hook.
# When <project>/.forge/checkpoint.md is older than the last commit or than an uncommitted
# change, asks Claude once to update it, through hookSpecificOutput.additionalContext.
# Inert without a checkpoint or when stop_hook_active is true. Never fails: every problem
# ends silently with exit 0 (onFailure has no effect on Stop).

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
IFS= read -r -d '' input || true
active=$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null) || exit 0
[[ $active == false ]] || exit 0
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input" 2>/dev/null)}
checkpoint="$root/.forge/checkpoint.md"
[[ -n $root && -f $checkpoint ]] || exit 0
git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

reason=""
commit_time=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
checkpoint_time=$(mtime "$checkpoint")
if [[ -n $commit_time && -n $checkpoint_time ]] && ((commit_time > checkpoint_time)); then
  reason="the last commit ($(git -C "$root" log -1 --format=%h)) is newer than it"
else
  while IFS= read -r -d '' entry; do
    status=${entry:0:2} path=${entry:3}
    # A rename or copy is followed by its original path.
    if [[ $status == R* || $status == C* ]]; then IFS= read -r -d '' _; fi
    [[ $path != .forge/checkpoint.md ]] || continue
    # Files only: a directory's date moves when an entry inside it is renamed (as editors save),
    # so an untracked .forge/ would always look newer than the checkpoint it holds.
    if [[ -f $root/$path && $root/$path -nt $checkpoint ]]; then
      reason="uncommitted changes are newer than it (for example $path)"
      break
    fi
  done < <(git -C "$root" status --porcelain -z --untracked-files=all 2>/dev/null)
fi
[[ -n $reason ]] || exit 0

message="flutter-forge: .forge/checkpoint.md is out of date: $reason. Update it now with the completed steps (command and exit code), the test results, the next action and any blocker. Then stop; do not start new work."
jq -nc --arg m "$message" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
exit 0
