#!/usr/bin/env bash
# create-feature implements the 15 steps of the TDD workflow; RED and GREEN each name their
# command and require recording its output; the checkpoint template has what recovery reads.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_tdd_skill
SKILL="$PLUGIN_ROOT/skills/create-feature/SKILL.md"
CHECKPOINT="$PLUGIN_ROOT/templates/checkpoint.md"

if [[ ! -f $SKILL ]]; then
  fail "create-feature/SKILL.md exists"
  finish
  exit
fi
pass "create-feature/SKILL.md exists"

# step <n>: the text of "### Step <n> — ..." up to the next step heading.
step() {
  awk -v n="$1" '/^### Step [0-9]+ / { inside = ($3 == n) } inside { print }' "$SKILL"
}

order=$(grep -oE '^### Step [0-9]+ ' "$SKILL" | awk '{ print $3 }' | tr '\n' ' ')
[[ $order == "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 " ]] && pass "steps 1 to 15, in order, once each" \
  || fail "steps 1 to 15, in order, once each" "found: $order"

# expect_step <n> <label> <needle...>: every needle appears in step n, ignoring case
# (the needles are prose: "wait" must match "Wait for its report").
expect_step() {
  local n=$1 label=$2 text needle missing=""
  shift 2
  text=$(step "$n" | tr '[:upper:]' '[:lower:]')
  for needle in "$@"; do
    needle=$(tr '[:upper:]' '[:lower:]' <<<"$needle")
    [[ $text == *"$needle"* ]] || missing+=" [$needle]"
  done
  [[ -z $missing ]] && pass "step $n: $label" || fail "step $n: $label" "missing:$missing"
}

expect_step 1 "repo state, no silent stash" "git status" "stash"
expect_step 1 "the checkpoint itself is not a reason to stop" ".forge/checkpoint.md"
expect_step 2 "context and acceptance criteria" "PRD" "TRD" "AC-"
expect_step 2 "PRD and TRD must be APPROVED" "APPROVED"
expect_step 4 "an approved dependency is added and its platforms checked" "flutter pub add" "platforms"
expect_step 6 "integration tests get a device or are blocked" "-d " "blocked"
expect_step 7 "tests that already pass stop the workflow" "already pass" "stop"
expect_step 13 "review of the staged diff (nothing is committed yet)" "git diff --cached"
expect_step 13 "checks rerun after fixes, stop if still blocking" "step 11" "step 12" "stop"
expect_step 4 "plan validated by the user when scope changes" "validation" "stop"
expect_step 5 "branch through git-workflow" "feature/" "git-workflow"
expect_step 6 "test-engineer, wait for its report" "test-engineer" "wait"
expect_step 7 "RED: command, output recorded" "RED" "flutter test" "checkpoint" "exit code"
expect_step 7 "RED fails on the expected assertion" "assertion" "compil"
expect_step 9 "GREEN: command, output recorded" "GREEN" "flutter test" "checkpoint" "exit code"
expect_step 9 "GREEN: at most three iterations" "three"
expect_step 11 "full test run at this milestone" "flutter test"
expect_step 12 "format and analyze" "dart format --set-exit-if-changed" "flutter analyze"
expect_step 13 "code-reviewer on the branch diff" "code-reviewer" "git diff"
expect_step 15 "commit through git-workflow, final report" "git-workflow" "report"

text=$(<"$SKILL")
missing=""
for category in passed failed blocked "not run"; do [[ $text == *"$category"* ]] || missing+=" [$category]"; done
[[ -z $missing ]] && pass "final report uses the four categories" || fail "final report uses the four categories" "missing:$missing"

echo "# checkpoint template"
if [[ -f $CHECKPOINT ]]; then
  pass "templates/checkpoint.md exists"
  missing=""
  for needle in "updated:" "skill:" "branch:" "last_commit:" "## Steps" "## Test results" "## Next action" "## Blockers"; do
    grep -qF -- "$needle" "$CHECKPOINT" || missing+=" [$needle]"
  done
  [[ -z $missing ]] && pass "checkpoint has the fields recover-session reads" || fail "checkpoint fields" "missing:$missing"
else
  fail "templates/checkpoint.md exists"
fi

finish
