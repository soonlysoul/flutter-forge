#!/usr/bin/env bash
# checkpoint-reminder: Stop hook. Resumes Claude once, through additionalContext, when
# .forge/checkpoint.md is older than the last commit or an uncommitted change, unless that last
# commit carries the checkpoint, unchanged since (D42). Never fails.
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

# commit_later <repo>: a commit on 2026-01-20 that leaves the checkpoint out, as a commit made
# outside the workflow would.
commit_later() {
  echo "// later" >>"$1/lib/main.dart"
  git -C "$1" add lib/main.dart
  GIT_AUTHOR_DATE="2026-01-20T12:00:00" GIT_COMMITTER_DATE="2026-01-20T12:00:00" \
    git -C "$1" commit -qm later
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
commit_later "$repo"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "checkpoint older than a last commit that leaves it out" "last commit"

# Scenarios 6 and 10 (v0.3): the last commit of a workflow carries the checkpoint, written just
# before it, so the commit is always newer; reminding then dirtied the tree after every workflow.
repo=$(make_repo)
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "the last commit carries the checkpoint, unchanged since: silent"

repo=$(make_repo)
echo "- [x] 2 something else" >>"$repo/.forge/checkpoint.md"
touch -t 202601050000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "the last commit carries the checkpoint, changed since but older" "last commit"

# Review of D42: a carrying commit that is not the root one, then work left uncommitted.
repo=$(make_repo)
echo "- [x] 2 done" >>"$repo/.forge/checkpoint.md"
git -C "$repo" add .forge/checkpoint.md
GIT_AUTHOR_DATE="2026-01-20T12:00:00" GIT_COMMITTER_DATE="2026-01-20T12:00:00" git -C "$repo" commit -qm step
touch -t 202601150000 "$repo/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_silent_allow "a later commit carries the checkpoint, unchanged since: silent"
echo "// changed" >>"$repo/lib/main.dart"
touch -t 202601250000 "$repo/lib/main.dart"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "after the carrying commit, a modified file newer than the checkpoint" "lib/main.dart"

# Review of D42: the project is a subdirectory of the repository, whose status paths start at
# the repository root.
mono=$(mktemp -d "$work/mono.XXXXXX")
git -C "$mono" init -q
git -C "$mono" config user.email test@example.test
git -C "$mono" config user.name Test
git -C "$mono" config commit.gpgsign false
mkdir -p "$mono/app/lib" "$mono/app/.forge"
echo "void main() {}" >"$mono/app/lib/main.dart"
echo "# Checkpoint" >"$mono/app/.forge/checkpoint.md"
git -C "$mono" add -A
GIT_AUTHOR_DATE="2026-01-10T12:00:00" GIT_COMMITTER_DATE="2026-01-10T12:00:00" git -C "$mono" commit -qm init
touch -t 202601050000 "$mono/app/.forge/checkpoint.md"
run_hook "$REMIND" "$(stop_input "$mono/app")"
expect_silent_allow "project in a subdirectory, last commit carries the checkpoint: silent"
mkdir -p "$mono/other"
echo "notes" >"$mono/other/notes.txt"
touch -t 202601200000 "$mono/other/notes.txt"
run_hook "$REMIND" "$(stop_input "$mono/app")"
expect_silent_allow "a newer file outside the project's directory: silent"
rm "$mono/other/notes.txt"
echo "class Note {}" >"$mono/app/lib/note.dart"
touch -t 202601200000 "$mono/app/lib/note.dart"
run_hook "$REMIND" "$(stop_input "$mono/app")"
expect_reminder "project in a subdirectory, a new file newer than the checkpoint" "lib/note.dart"
echo "// changed" >>"$mono/app/lib/main.dart"
rm "$mono/app/lib/note.dart"
touch -t 202601200000 "$mono/app/lib/main.dart"
run_hook "$REMIND" "$(stop_input "$mono/app")"
expect_reminder "project in a subdirectory, a modified file newer than the checkpoint" "lib/main.dart"

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
mkdir -p "$repo/lib/notes"
echo "class Note {}" >"$repo/lib/notes/note.dart"
touch -t 202601200000 "$repo/lib/notes/note.dart"
touch -t 202601120000 "$repo/lib/notes"
run_hook "$REMIND" "$(stop_input "$repo")"
expect_reminder "newer file inside a new untracked directory whose own date is older" "lib/notes/note.dart"

# Found in a real session: before the first commit, git reports the untracked .forge/ directory,
# and an edit through rename leaves the directory newer than the checkpoint it holds.
early=$(mktemp -d "$work/early.XXXXXX")
git -C "$early" init -q
mkdir -p "$early/.forge"
echo "# Checkpoint" >"$early/.forge/checkpoint.md"
touch -t 202601150000 "$early/.forge/checkpoint.md"
touch -t 202601150100 "$early/.forge"
run_hook "$REMIND" "$(stop_input "$early")"
expect_silent_allow "untracked .forge/ newer than its checkpoint before the first commit: silent"

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
commit_later "$repo"
run_hook "$REMIND" "$(stop_input "$repo" true)"
expect_silent_allow "stop_hook_active: no second reminder, on a state that would remind"

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
commit_later "$repo"
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
