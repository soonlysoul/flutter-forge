#!/usr/bin/env bash
# agent-scope-guard: per-agent write directories and shell allowlists, fail-closed for the
# plugin's agents, inert for everything else.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agent_scope_guard
SCOPE="$SCRIPTS/agent-scope-guard.sh"
P=plugin-flutter

# agent_input <agent_type or ""> <tool> <tool_input JSON> [cwd]
agent_input() {
  jq -nc --arg a "$1" --arg t "$2" --argjson i "$3" --arg d "${4:-/work/proj}" \
    '{session_id: "test", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t, tool_input: $i}
     + (if $a == "" then {} else {agent_id: "agent-1", agent_type: $a} end)'
}
write_input() { agent_input "$1" "${3:-Write}" "$(jq -nc --arg p "$2" '{file_path: $p, content: "x"}')"; }
shell_input() { agent_input "$1" "${3:-Bash}" "$(jq -nc --arg c "$2" '{command: $c}')"; }

# check <expected: allow|block> <label> <input> [env...]
check() {
  local expected=$1 label=$2 input=$3
  shift 3
  run_hook "$SCOPE" "$input" "$@"
  if [[ $expected == allow ]]; then expect_silent_allow "$label"; else expect_blocked "$label"; fi
}

echo "# inert outside the plugin's agents"
check allow "main session may write anywhere" "$(write_input "" /etc/hosts)"
check allow "main session Bash is not this hook's business" "$(shell_input "" 'rm -rf lib')"
check allow "built-in agent is ignored" "$(write_input Explore /work/proj/lib/a.dart)"
check allow "same agent name from another plugin is ignored" "$(write_input other-plugin:test-engineer /work/proj/lib/a.dart)"
check allow "Read is not restricted" "$(agent_input "$P:code-reviewer" Read '{"file_path": "/work/proj/lib/a.dart"}')"
check block "unknown agent of this plugin is blocked" "$(write_input "$P:release-manager" /work/proj/docs/a.md)"

echo "# test-engineer"
T="$P:test-engineer"
check allow "writes under test/" "$(write_input "$T" /work/proj/test/notes/note_test.dart)"
check allow "edits under integration_test/" "$(write_input "$T" /work/proj/integration_test/app_test.dart Edit)"
check block "writes under lib/" "$(write_input "$T" /work/proj/lib/notes.dart)"
check block "climbs out of test/ with .." "$(write_input "$T" /work/proj/test/../lib/notes.dart)"
check block "testing/ is not test/" "$(write_input "$T" /work/proj/testing/x.dart)"
check block "writes outside the project" "$(write_input "$T" /etc/hosts)"
check block "relative path" "$(write_input "$T" test/a_test.dart)"
check block "Write without file_path" "$(agent_input "$T" Write '{"content": "x"}')"
check block "NotebookEdit outside test/" "$(agent_input "$T" NotebookEdit '{"notebook_path": "/work/proj/lib/x.ipynb"}')"
check allow "flutter test on files" "$(shell_input "$T" 'flutter test test/notes/note_test.dart')"
check allow "flutter test" "$(shell_input "$T" 'flutter test')"
check allow "dart test" "$(shell_input "$T" 'dart test')"
check allow "git status" "$(shell_input "$T" 'git status')"
check allow "git diff" "$(shell_input "$T" 'git diff')"
check block "flutter pub add" "$(shell_input "$T" 'flutter pub add mocktail')"
check block "compound command" "$(shell_input "$T" 'flutter test && git add .')"
check block "redirection to a file" "$(shell_input "$T" 'flutter test > out.txt')"
check block "write through echo" "$(shell_input "$T" 'echo x > lib/a.dart')"
check block "write through sed" "$(shell_input "$T" 'sed -i s/a/b/ lib/a.dart')"
check block "git commit" "$(shell_input "$T" 'git commit -m x')"
check block "leading assignment" "$(shell_input "$T" 'FOO=1 flutter test')"
check block "command substitution" "$(shell_input "$T" 'flutter test $(cat list)')"
check block "Monitor outside the allowlist" "$(shell_input "$T" 'tail -f log' Monitor)"
check block "PowerShell outside the allowlist" "$(shell_input "$T" 'Remove-Item lib' PowerShell)"

echo "# code-reviewer"
R="$P:code-reviewer"
check block "Write" "$(write_input "$R" /work/proj/docs/review.md)"
check block "Edit" "$(write_input "$R" /work/proj/test/a_test.dart Edit)"
check allow "git diff of the branch" "$(shell_input "$R" 'git diff main...HEAD')"
check allow "git diff --name-only" "$(shell_input "$R" 'git diff --name-only main...HEAD')"
check allow "git log" "$(shell_input "$R" 'git log --oneline main..HEAD')"
check allow "git show" "$(shell_input "$R" 'git show HEAD:lib/a.dart')"
check allow "git status" "$(shell_input "$R" 'git status --short')"
check allow "git --no-pager diff" "$(shell_input "$R" 'git --no-pager diff')"
check allow "flutter analyze" "$(shell_input "$R" 'flutter analyze')"
check allow "dart analyze" "$(shell_input "$R" 'dart analyze lib')"
check block "git diff --output writes a file" "$(shell_input "$R" 'git diff --output=/tmp/x')"
check block "flutter analyze --write writes a file" "$(shell_input "$R" 'flutter analyze --write=out.txt')"
check block "git push" "$(shell_input "$R" 'git push')"
check block "git checkout" "$(shell_input "$R" 'git checkout main')"
check block "git -C elsewhere" "$(shell_input "$R" 'git -C .. diff')"
check block "flutter test" "$(shell_input "$R" 'flutter test')"
check block "git ls-files is not in its list" "$(shell_input "$R" 'git ls-files')"

echo "# flutter-architect"
A="$P:flutter-architect"
check allow "writes the TRD" "$(write_input "$A" /work/proj/docs/technical/TRD.md)"
check allow "edits DECISIONS.md" "$(write_input "$A" /work/proj/docs/engineering/DECISIONS.md Edit)"
check block "writes lib/" "$(write_input "$A" /work/proj/lib/main.dart)"
check block "docs2/ is not docs/" "$(write_input "$A" /work/proj/docs2/x.md)"
check block "writes pubspec.yaml" "$(write_input "$A" /work/proj/pubspec.yaml)"
check allow "flutter --version" "$(shell_input "$A" 'flutter --version')"
check allow "dart --version" "$(shell_input "$A" 'dart --version')"
check allow "dart pub deps" "$(shell_input "$A" 'dart pub deps')"
check allow "flutter pub deps with options" "$(shell_input "$A" 'flutter pub deps --style=compact')"
check allow "git log" "$(shell_input "$A" 'git log --oneline')"
check allow "git ls-files" "$(shell_input "$A" 'git ls-files')"
check allow "git rev-parse" "$(shell_input "$A" 'git rev-parse HEAD')"
check allow "git branch --show-current" "$(shell_input "$A" 'git branch --show-current')"
check block "git branch <name> creates a branch" "$(shell_input "$A" 'git branch new-branch')"
check block "flutter pub add" "$(shell_input "$A" 'flutter pub add riverpod')"
check block "flutter create" "$(shell_input "$A" 'flutter create .')"
check block "flutter test" "$(shell_input "$A" 'flutter test')"

echo "# devops-engineer"
O="$P:devops-engineer"
check allow "writes the CI workflow" "$(write_input "$O" /work/proj/.github/workflows/ci.yml)"
check allow "edits .github/dependabot.yml" "$(write_input "$O" /work/proj/.github/dependabot.yml Edit)"
check block "writes lib/" "$(write_input "$O" /work/proj/lib/main.dart)"
check block "writes pubspec.yaml" "$(write_input "$O" /work/proj/pubspec.yaml)"
check block ".githubx/ is not .github/" "$(write_input "$O" /work/proj/.githubx/ci.yml)"
check allow "flutter build linux" "$(shell_input "$O" 'flutter build linux')"
check allow "flutter build apk with options" "$(shell_input "$O" 'flutter build apk --debug')"
check allow "flutter build web" "$(shell_input "$O" 'flutter build web --release')"
check allow "flutter --version" "$(shell_input "$O" 'flutter --version')"
check allow "flutter doctor -v" "$(shell_input "$O" 'flutter doctor -v')"
check allow "flutter devices" "$(shell_input "$O" 'flutter devices')"
check allow "gh auth status" "$(shell_input "$O" 'gh auth status')"
check allow "gh run list" "$(shell_input "$O" 'gh run list --branch feature/x --limit 5 --json databaseId,conclusion')"
check allow "gh run view --log-failed" "$(shell_input "$O" 'gh run view 123 --log-failed')"
check allow "gh run watch" "$(shell_input "$O" 'gh run watch 123 --exit-status')"
check allow "gh pr checks" "$(shell_input "$O" 'gh pr checks 12')"
check allow "gh pr view" "$(shell_input "$O" 'gh pr view 12 --json state,url')"
check allow "gh workflow list" "$(shell_input "$O" 'gh workflow list')"
check allow "gh workflow view" "$(shell_input "$O" 'gh workflow view ci.yml')"
check allow "gh repo view" "$(shell_input "$O" 'gh repo view --json visibility')"
check allow "git log" "$(shell_input "$O" 'git log --oneline -5')"
check allow "git remote -v" "$(shell_input "$O" 'git remote -v')"
check allow "git rev-parse HEAD" "$(shell_input "$O" 'git rev-parse HEAD')"
check block "gh auth status --show-token" "$(shell_input "$O" 'gh auth status --show-token')"
check block "gh auth status -t" "$(shell_input "$O" 'gh auth status -t')"
check block "gh auth token" "$(shell_input "$O" 'gh auth token')"
check block "gh pr create" "$(shell_input "$O" 'gh pr create --title x --body y')"
check block "gh pr edit" "$(shell_input "$O" 'gh pr edit 12 --body y')"
check block "gh run rerun spends CI minutes" "$(shell_input "$O" 'gh run rerun 123')"
check block "gh run cancel" "$(shell_input "$O" 'gh run cancel 123')"
check block "gh run download writes files" "$(shell_input "$O" 'gh run download 123')"
check block "gh workflow run spends CI minutes" "$(shell_input "$O" 'gh workflow run ci.yml')"
check block "gh repo create" "$(shell_input "$O" 'gh repo create x --private')"
check block "gh api" "$(shell_input "$O" 'gh api repos/o/r')"
check block "gh secret list" "$(shell_input "$O" 'gh secret list')"
check block "git push" "$(shell_input "$O" 'git push -u origin feature/x')"
check block "git remote add" "$(shell_input "$O" 'git remote add origin https://example.test/r.git')"
check block "git commit" "$(shell_input "$O" 'git commit -m x')"
check block "flutter test is not its job" "$(shell_input "$O" 'flutter test')"
check block "flutter pub add" "$(shell_input "$O" 'flutter pub add http')"
check block "flutter build -o writes elsewhere" "$(shell_input "$O" 'flutter build web -o /tmp/site')"
check block "flutter build --output writes elsewhere" "$(shell_input "$O" 'flutter build web --output=/tmp/site')"
check block "compound build and push" "$(shell_input "$O" 'flutter build linux && git push')"

echo "# project root"
check allow "CLAUDE_PROJECT_DIR is the root when set" \
  "$(agent_input "$T" Write '{"file_path": "/other/root/test/a_test.dart"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check block "cwd is not used when CLAUDE_PROJECT_DIR is set" \
  "$(agent_input "$T" Write '{"file_path": "/work/proj/sub/test/a_test.dart"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root

echo "# errors"
check block "malformed JSON from a plugin agent" '{"agent_type": "plugin-flutter:test-engineer", "tool_name": '
check allow "malformed JSON without the plugin prefix" '{"tool_name": '
nojq=$(restricted_path)
check block "missing jq for a plugin agent" "$(write_input "$T" /work/proj/test/a_test.dart)" PATH="$nojq"
check allow "missing jq elsewhere" "$(write_input "" /work/proj/lib/a.dart)" PATH="$nojq"
rm -r "$nojq"
nolib=$(mktemp -d)
cp "$SCOPE" "$nolib/"
run_hook "$nolib/agent-scope-guard.sh" "$(shell_input "$R" 'git status')"
expect_blocked "missing shell lexer library for a plugin agent"
rm -r "$nolib"

run_hook "$SCOPE" "$(write_input "$T" /work/proj/lib/notes.dart)"
[[ $HOOK_STDERR == *test-engineer* && $HOOK_STDERR == *test/* && $HOOK_STDERR == *integration_test/* ]] \
  && pass "write refusal names the agent and its directories" || fail "write refusal names the agent and its directories" "$HOOK_STDERR"
run_hook "$SCOPE" "$(shell_input "$R" 'git push')"
[[ $HOOK_STDERR == *code-reviewer* && $HOOK_STDERR == *"git diff"* && $HOOK_STDERR == *"flutter analyze"* ]] \
  && pass "command refusal lists the allowed commands" || fail "command refusal lists the allowed commands" "$HOOK_STDERR"

finish
