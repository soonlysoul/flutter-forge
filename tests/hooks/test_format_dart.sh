#!/usr/bin/env bash
# format-dart: PostToolUse hook on Edit|Write, fail-open — it never reports an error.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_format_dart
FORMAT="$SCRIPTS/format-dart.sh"

work=$(mktemp -d)
trap 'rm -r "$work"' EXIT

# post_input <tool> <file_path>
post_input() {
  jq -nc --arg t "$1" --arg p "$2" \
    '{session_id: "test", cwd: "/work/proj", hook_event_name: "PostToolUse", tool_name: $t,
      tool_input: {file_path: $p}, tool_response: {success: true}}'
}

# A fake dart that logs "<argc>:<args>" and exits with $STUB_EXIT.
stub_bin=$(restricted_path jq)
cat >"$stub_bin/dart" <<EOF
#!$BASH
printf '%s:%s\n' "\$#" "\$*" >>"$work/dart.log"
echo "stub dart output" >&2
exit \${STUB_EXIT:-0}
EOF
chmod +x "$stub_bin/dart"
jq_only=$(restricted_path jq)
no_tools=$(restricted_path)

touch "$work/a.dart" "$work/notes.md" "$work/my file.dart"
dart_calls() { if [[ -f $work/dart.log ]]; then cat "$work/dart.log"; fi; }
reset_log() { rm -f "$work/dart.log"; }

echo "# with a stub dart"
reset_log
run_hook "$FORMAT" "$(post_input Write "$work/a.dart")" PATH="$stub_bin"
expect_silent_allow "Write of a .dart file succeeds silently"
[[ $(dart_calls) == "2:format $work/a.dart" ]] && pass "dart format <file> is called" || fail "dart format <file> is called" "calls: $(dart_calls)"

reset_log
run_hook "$FORMAT" "$(post_input Edit "$work/my file.dart")" PATH="$stub_bin"
expect_silent_allow "Edit of a .dart file succeeds silently"
[[ $(dart_calls) == "2:format $work/my file.dart" ]] && pass "a path with a space stays one argument" || fail "a path with a space stays one argument" "calls: $(dart_calls)"

reset_log
run_hook "$FORMAT" "$(post_input Write "$work/notes.md")" PATH="$stub_bin"
expect_silent_allow "non-Dart file is ignored"
[[ -z $(dart_calls) ]] && pass "dart is not called for a non-Dart file" || fail "dart is not called for a non-Dart file" "calls: $(dart_calls)"

reset_log
run_hook "$FORMAT" "$(post_input Write "$work/missing.dart")" PATH="$stub_bin"
expect_silent_allow "missing file is ignored"
[[ -z $(dart_calls) ]] && pass "dart is not called for a missing file" || fail "dart is not called for a missing file" "calls: $(dart_calls)"

reset_log
run_hook "$FORMAT" "$(jq -nc --arg p "$work/a.dart" '{tool_name: "NotebookEdit", tool_input: {notebook_path: $p}}')" PATH="$stub_bin"
expect_silent_allow "other tool is ignored"

reset_log
run_hook "$FORMAT" "$(post_input Write "$work/a.dart")" PATH="$stub_bin" STUB_EXIT=1
expect_silent_allow "dart format failure is swallowed"

echo "# missing pieces never fail"
run_hook "$FORMAT" "$(post_input Write "$work/a.dart")" PATH="$jq_only"
expect_silent_allow "dart absent from PATH"
run_hook "$FORMAT" "$(post_input Write "$work/a.dart")" PATH="$no_tools"
expect_silent_allow "jq absent from PATH"
run_hook "$FORMAT" '{"tool_name": "Write", "tool_input": ' PATH="$stub_bin"
expect_silent_allow "malformed JSON"
run_hook "$FORMAT" '' PATH="$stub_bin"
expect_silent_allow "empty input"

echo "# with the real dart"
if command -v dart >/dev/null 2>&1; then
  printf "void main(){print('a');}\n" >"$work/real.dart"
  run_hook "$FORMAT" "$(post_input Write "$work/real.dart")"
  expect_silent_allow "real dart format succeeds silently"
  expected=$'void main() {\n  print(\'a\');\n}'
  [[ $(<"$work/real.dart") == "$expected" ]] && pass "file is formatted on disk" || fail "file is formatted on disk" "content: $(<"$work/real.dart")"
else
  skip "real dart format" "dart not in PATH"
fi

rm -r "$stub_bin" "$jq_only" "$no_tools"
finish
