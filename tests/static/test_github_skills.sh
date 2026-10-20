#!/usr/bin/env bash
# github-workflow and debug-project: the validation points, commands and limits they must state.
# A content check, like test_tdd_skill: it proves the instruction is written, not that it is followed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_github_skills
GH="$PLUGIN_ROOT/skills/github-workflow/SKILL.md"
DBG="$PLUGIN_ROOT/skills/debug-project/SKILL.md"
BODY="$PLUGIN_ROOT/skills/github-workflow/reference/pr-body.md"

# says <file> <label> <fixed string>
says() { grep -qiF -- "$3" "$1" && pass "$2" || fail "$2" "missing: $3"; }

echo "# github-workflow"
if [[ -f $GH ]]; then
  says "$GH" "checks gh authentication first" "gh auth status"
  says "$GH" "sends the user to gh auth login" "gh auth login"
  bad=$(grep -nE -- '--show-token|gh auth token' "$GH" | grep -viE 'never|not ')
  [[ -z $bad ]] && pass "never shows a token" || fail "never shows a token" "$bad"
  grep -q 'gh pr merge' "$GH" && fail "never instructs gh pr merge" "$(grep -n 'gh pr merge' "$GH")" || pass "never instructs gh pr merge"
  for key in push_feature_branches open_pull_requests update_own_pull_requests create_remote_repo; do
    says "$GH" "reads authorization $key" "$key"
  done
  says "$GH" "remote creation confirms the owner" "owner"
  says "$GH" "remote creation confirms the visibility" "visibility"
  says "$GH" "remote creation does not push everything (--push)" "No \`--push\`"
  says "$GH" "the PR names its head branch" "--head <branch>"
  says "$GH" "the PR body is read from a quoted heredoc" "--body-file - <<'EOF'"
  says "$GH" "flutter test marks no platform as tested" "marks no platform as tested"
  says "$GH" "states the CI cost of a private repository" "2,000 minutes"
  says "$GH" "says public repositories run CI for free" "free for public"
  says "$GH" "fills __FLUTTER_VERSION__ from the local Flutter" "__FLUTTER_VERSION__"
  says "$GH" "delegates a red CI to the devops-engineer" "ci-diagnosis"
  says "$GH" "sends code failures to debug-project" "debug-project"
  says "$GH" "knows the pending exit code of gh pr checks" "8"
  says "$GH" "merging is the user's" "merge is theirs"
  says "$GH" "writes the checkpoint" "skill: github-workflow"
  says "$GH" "runs each command alone, as the permission rules expect" "one command per call"
  says "$GH" "with a remote, the CI goes through a work branch and its pull request" "chore/ci"
  says "$GH" "flutter analyze must exit 0 locally, as in CI" "fatal by default"
  says "$GH" "opening a pull request on a private repository starts a run" "starts a CI run"
  says "$GH" "each push of a fix starts another run" "each push"
else
  fail "skills/github-workflow/SKILL.md exists"
fi

echo "# pull request body"
if [[ -f $BODY ]]; then
  for section in "## Summary" "## Acceptance criteria" "## Risks" "## Tests" "## Platforms" "## Screenshots"; do
    says "$BODY" "PR body has $section" "$section"
  done
  for category in passed failed blocked "not run"; do says "$BODY" "tests category: $category" "| $category |"; done
  says "$BODY" "platforms in three states" "| platform | enabled | built | tested |"
else
  fail "skills/github-workflow/reference/pr-body.md exists"
fi

echo "# debug-project"
if [[ -f $DBG ]]; then
  grep -qiE '^description:.*not .*RED' "$DBG" && pass "description excludes the expected RED of create-feature" \
    || fail "description excludes the expected RED of create-feature" "$(grep '^description:' "$DBG")"
  says "$DBG" "reproduces first" "Reproduce"
  says "$DBG" "states a root cause with evidence before fixing" "root cause"
  says "$DBG" "stops for a change outside the error's scope" "outside the scope"
  says "$DBG" "writes a regression test" "regression test"
  says "$DBG" "an existing failing test is the regression test, not duplicated" "do not duplicate it"
  says "$DBG" "regression test is RED first" "RED"
  says "$DBG" "then GREEN" "GREEN"
  says "$DBG" "two identical failures stop" "fails twice with the same error"
  says "$DBG" "runs the full suite" "flutter test"
  says "$DBG" "checks formatting" "dart format --set-exit-if-changed ."
  says "$DBG" "runs the analyzer" "flutter analyze"
  says "$DBG" "flutter analyze must exit 0, as in CI" "fatal by default"
  says "$DBG" "has the fix reviewed" "code-reviewer"
  says "$DBG" "commits a fix(...) Conventional Commit" "fix("
  says "$DBG" "writes the checkpoint" "skill: debug-project"
  says "$DBG" "runs each command alone, as the permission rules expect" "one command per call"
  says "$DBG" "branch fix/<slug>" "fix/<slug>"
  says "$DBG" "the commit carries the updated checkpoint" "the updated \`.forge/checkpoint.md\`"
  for category in "**passed**" "**failed**" "**blocked**" "**not run**"; do says "$DBG" "report category $category" "$category"; done
else
  fail "skills/debug-project/SKILL.md exists"
fi

echo "# devops-engineer build"
# Scenario 11 (v0.3): doctor showed `[✗] Android toolchain`, the agent built android anyway and
# reported it failed. The step that runs builds must itself leave out a platform doctor rules out.
DEVOPS="$PLUGIN_ROOT/agents/devops-engineer.md"
says "$DEVOPS" "builds only the platforms doctor does not rule out" "whose toolchain \`flutter doctor -v\` does not mark \`[✗]\`"
says "$DEVOPS" "a platform doctor rules out is blocked, its build not run" "is **blocked**, with that line as the reason: do not run its build"

finish
