#!/usr/bin/env bash
# agent-scope-guard: per-agent write directories and shell allowlists, fail-closed for the
# plugin's agents, inert for everything else.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agent_scope_guard
SCOPE="$SCRIPTS/agent-scope-guard.sh"
P=dart-multiplatform-forge

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

echo "# project root"
check allow "CLAUDE_PROJECT_DIR is the root when set" \
  "$(agent_input "$T" Write '{"file_path": "/other/root/test/a_test.dart"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root
check block "cwd is not used when CLAUDE_PROJECT_DIR is set" \
  "$(agent_input "$T" Write '{"file_path": "/work/proj/sub/test/a_test.dart"}' /work/proj/sub)" CLAUDE_PROJECT_DIR=/other/root

echo "# errors"
check block "malformed JSON from a plugin agent" '{"agent_type": "dart-multiplatform-forge:test-engineer", "tool_name": '
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
