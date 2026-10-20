#!/usr/bin/env bash
# protect-sensitive: PreToolUse hook on Edit|Write|NotebookEdit. In a project that has .forge/,
# asks the user before a write to signing material, entitlements, CI workflows or the plugin's
# configuration; .forge/config.yaml is protected everywhere. Fail-closed when it must decide.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_protect_sensitive
PROTECT="$SCRIPTS/protect-sensitive.sh"

work=$(mktemp -d)
trap 'rm -r "$work"' EXIT
forge="$work/forge_app"
plain="$work/plain_app"
mkdir -p "$forge/.forge" "$plain"

# write_input <file_path> [tool] [content] [cwd]
write_input() {
  local key=file_path
  [[ ${2:-Write} == NotebookEdit ]] && key=notebook_path
  jq -nc --arg p "$1" --arg t "${2:-Write}" --arg c "${3:-x}" --arg d "${4:-$forge}" --arg k "$key" \
    '{session_id: "test", cwd: $d, hook_event_name: "PreToolUse", tool_name: $t,
      tool_input: ({($k): $p} + (if $t == "Write" then {content: $c} else {old_string: "a", new_string: $c} end))}'
}

# expect_ask <label> <needle>: exit 0 and a PreToolUse "ask" decision whose reason holds the needle.
expect_ask() {
  local reason
  reason=$(jq -r 'select(.hookSpecificOutput.hookEventName == "PreToolUse"
                         and .hookSpecificOutput.permissionDecision == "ask")
                  | .hookSpecificOutput.permissionDecisionReason // empty' <<<"$HOOK_STDOUT" 2>/dev/null)
  if [[ $HOOK_STATUS == 0 && $reason == *plugin-flutter* && $reason == *"$2"* ]]; then
    pass "$1"
  else
    fail "$1" "exit $HOOK_STATUS; stdout: ${HOOK_STDOUT:0:300}; stderr: ${HOOK_STDERR:0:200}"
  fi
}

# check <ask|allow> <label> <input> [needle] [env...]
check() {
  local expected=$1 label=$2 input=$3 needle=${4-}
  shift 4 2>/dev/null || shift $#
  run_hook "$PROTECT" "$input" CLAUDE_PROJECT_DIR="$forge" "$@"
  if [[ $expected == ask ]]; then expect_ask "$label" "$needle"; else expect_silent_allow "$label"; fi
}

echo "# sensitive files of a forge project ask first"
check ask "android/key.properties" "$(write_input "$forge/android/key.properties")" android/key.properties
check ask "an upload keystore (.jks)" "$(write_input "$forge/android/app/upload.jks")" upload.jks
check ask "a .keystore edited" "$(write_input "$forge/android/release.keystore" Edit)" release.keystore
check ask "iOS entitlements" "$(write_input "$forge/ios/Runner/Runner.entitlements")" Runner.entitlements
check ask "macOS entitlements" "$(write_input "$forge/macos/Runner/Release.entitlements" Edit)" Release.entitlements
check ask "a CI workflow" "$(write_input "$forge/.github/workflows/ci.yml")" .github/workflows/ci.yml
check ask "a CI workflow through NotebookEdit" "$(write_input "$forge/.github/workflows/x.ipynb" NotebookEdit)" .github/workflows
check ask ".forge/config.yaml" "$(write_input "$forge/.forge/config.yaml" Edit)" .forge/config.yaml
check ask "a relative path is matched too" "$(write_input android/key.properties)" key.properties
run_hook "$PROTECT" "$(write_input "$forge/.github/workflows/ci.yml")" CLAUDE_PROJECT_DIR="$forge"
reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$HOOK_STDOUT" 2>/dev/null)
[[ $reason == *"workflow"* && $reason == *"another way"* ]] && pass "the reason says what the file is and not to work around a refusal" \
  || fail "the reason says what the file is and not to work around a refusal" "$reason"
[[ -z $HOOK_STDERR ]] && pass "an ask decision writes nothing on stderr" || fail "an ask decision writes nothing on stderr" "$HOOK_STDERR"

echo "# other files of a forge project"
check allow "lib/ is not sensitive" "$(write_input "$forge/lib/main.dart")"
check allow ".forge/checkpoint.md is workflow state" "$(write_input "$forge/.forge/checkpoint.md")"
check allow "a document that mentions key.properties" "$(write_input "$forge/docs/SIGNING.md" Write 'Keep android/key.properties out of Git.')"
check allow ".github/ outside workflows/" "$(write_input "$forge/.github/dependabot.yml")"
check allow "a Read is not this hook's business" '{"tool_name": "Read", "tool_input": {"file_path": "/x/android/key.properties"}, "cwd": "/x"}'

echo "# outside a forge project"
run_hook "$PROTECT" "$(write_input "$plain/.github/workflows/ci.yml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_silent_allow "a workflow of a project without .forge/ passes"
run_hook "$PROTECT" "$(write_input "$plain/android/key.properties" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_silent_allow "signing files of a project without .forge/ pass"
run_hook "$PROTECT" "$(write_input "$plain/sub/.forge/config.yaml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain"
expect_ask "a .forge/config.yaml is protected everywhere" .forge/config.yaml
run_hook "$PROTECT" "$(write_input "$forge/.github/workflows/ci.yml" Write x "$forge")"
expect_ask "without CLAUDE_PROJECT_DIR, the input cwd is the root" ci.yml
nojq=$(restricted_path)
run_hook "$PROTECT" "$(write_input "$plain/.github/workflows/ci.yml" Write x "$plain")" CLAUDE_PROJECT_DIR="$plain" PATH="$nojq"
expect_silent_allow "outside a forge project, a missing jq changes nothing"
run_hook "$PROTECT" "$(write_input "$forge/lib/main.dart")" CLAUDE_PROJECT_DIR="$forge" PATH="$nojq"
expect_silent_allow "an ordinary file passes without jq"

echo "# a forge app below the session root, and other CI or signing files"
parent="$work/parent"
mkdir -p "$parent/app/.forge"
run_hook "$PROTECT" "$(write_input "$parent/app/.github/workflows/ci.yml" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_ask "the forge project is found from the file, not from the session root" app/.github/workflows/ci.yml
run_hook "$PROTECT" "$(write_input "$parent/app/android/key.properties" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_ask "signing files of a forge app below the session root" key.properties
run_hook "$PROTECT" "$(write_input "$parent/other/.github/workflows/ci.yml" Write x "$parent")" CLAUDE_PROJECT_DIR="$parent"
expect_silent_allow "a sibling project without .forge/ is not protected"
check ask "a composite action under .github/actions/" "$(write_input "$forge/.github/actions/setup/action.yml")" .github/actions/setup/action.yml
check ask "an iOS distribution certificate (.p12)" "$(write_input "$forge/ios/dist.p12")" dist.p12
check ask "a .pfx certificate" "$(write_input "$forge/windows/sign.pfx")" sign.pfx

echo "# fail-closed"
run_hook "$PROTECT" "$(write_input "$forge/android/key.properties")" CLAUDE_PROJECT_DIR="$forge" PATH="$nojq"
expect_blocked "missing jq blocks a write that may be sensitive"
[[ $HOOK_STDERR == *jq* ]] && pass "missing jq is named in the reason" || fail "missing jq is named in the reason" "$HOOK_STDERR"
rm -r "$nojq"
run_hook "$PROTECT" '{"tool_name": "Write", "tool_input": {"file_path": "/x/android/key.properties"' CLAUDE_PROJECT_DIR="$forge"
expect_blocked "malformed input that may be sensitive is blocked"
run_hook "$PROTECT" '{"tool_name": "Write", "tool_input": {"file_path": 7, "content": "key.properties"}}' CLAUDE_PROJECT_DIR="$forge"
expect_blocked "a non-string path is blocked"

finish
