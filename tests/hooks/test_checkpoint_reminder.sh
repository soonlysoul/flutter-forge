#!/usr/bin/env bash
# checkpoint-reminder: Stop hook. Resumes Claude once, through additionalContext, when
# .forge/checkpoint.md is older than the last commit or an uncommitted change. Never fails.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_checkpoint_reminder
REMIND="$SCRIPTS/checkpoint-reminder.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# stop_input <cwd> [stop_hook_active]
stop_input() {
  jq -nc --arg d "$1" --argjson a "${2:-false}" \
    '{session_id: "test", cwd: $d, hook_event_name: "Stop", permission_mode: "default",
      stop_hook_active: $a, last_assistant_message: "Done."}'
}

# make_repo: a project committed on 2026-01-10 with a tracked checkpoint. Prints its path.
make_repo() {
  local repo
  repo=$(mktemp -d "$work/repo.XXXXXX")
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name Test
  git -C "$repo" config commit.gpgsign false
  mkdir -p "$repo/lib" "$repo/.forge"
  echo "void main() {}" >"$repo/lib/main.dart"
  echo "# Checkpoint" >"$repo/.forge/checkpoint.md"
  git -C "$repo" add -A
  GIT_AUTHOR_DATE="2026-01-10T12:00:00" GIT_COMMITTER_DATE="2026-01-10T12:00:00" \
    git -C "$repo" commit -qm init
  touch -t 202601100000 "$repo/lib/main.dart"
  touch -t 202601150000 "$repo/.forge/checkpoint.md"
  printf '%s' "$repo"
}

expect_reminder() {
  local label=$1 needle=$2 context
  context=$(jq -r 'select(.hookSpecificOutput.hookEventName == "Stop" and (has("decision") | not))
                   | .hookSpecificOutput.additionalContext // empty' <<<"$HOOK_STDOUT" 2>/dev/null)
  if [[ $HOOK_STATUS == 0 && -n $context && $context == *"$needle"* ]]; then
    pass "$label"
  else
    fail "$label" "exit $HOOK_STATUS; stdout: ${HOOK_STDOUT:0:300}; stderr: ${HOOK_STDERR:0:200}"
  fi
}

echo "# reminders"
repo=$(make_repo)
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "checkpoint newer than the commit and no changes: silent"

repo=$(make_repo)
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "checkpoint older than the last commit" "last commit"

repo=$(make_repo)
echo "// changed" >>"$repo/lib/main.dart"
touch -t 202601200000 "$repo/lib/main.dart"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "checkpoint older than a modified file" "lib/main.dart"

repo=$(make_repo)
echo "class Note {}" >"$repo/lib/note.dart"
touch -t 202601200000 "$repo/lib/note.dart"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "checkpoint older than an untracked file" "lib/note.dart"

repo=$(make_repo)
echo "// changed" >>"$repo/lib/main.dart"
touch -t 202601120000 "$repo/lib/main.dart"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "modified file older than the checkpoint: silent"

repo=$(make_repo)
echo "- [x] 1 Repo state checked" >>"$repo/.forge/checkpoint.md"
touch -t 202601200000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "only the checkpoint itself changed: silent"

repo=$(make_repo)
rm "$repo/lib/main.dart"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "deleted file does not break the hook"

echo "# stays silent"
repo=$(make_repo)
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo" true)"
expect_silent_allow "stop_hook_active: no second reminder"

plain=$(mktemp -d "$work/plain.XXXXXX")
run_hook "$REMIND" "$(stop_input "$plain")"
expect_silent_allow "no .forge/ directory"

nogit=$(mktemp -d "$work/nogit.XXXXXX")
mkdir -p "$nogit/.forge"
echo "# Checkpoint" >"$nogit/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$nogit")"
expect_silent_allow "checkpoint outside a git repository"

fresh=$(mktemp -d "$work/fresh.XXXXXX")
git -C "$fresh" init -q
mkdir -p "$fresh/.forge"
echo "# Checkpoint" >"$fresh/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$fresh")"
expect_silent_allow "repository without commits"

repo=$(make_repo)
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$plain")" CLAUDE_PROJECT_DIR="$repo"
expect_reminder "CLAUDE_PROJECT_DIR is used before cwd" "last commit"

echo "# never fails"
run_hook "$REMIND" '{"hook_event_name": "Stop", '
expect_silent_allow "malformed JSON"
jq_only=$(restricted_path jq)
run_hook "$REMIND" "$(stop_input "$repo")" PATH="$jq_only"
expect_silent_allow "git absent from PATH"
rm -r "$jq_only"
no_tools=$(restricted_path)
run_hook "$REMIND" "$(stop_input "$repo")" PATH="$no_tools"
expect_silent_allow "jq absent from PATH"
rm -r "$no_tools"

finish
