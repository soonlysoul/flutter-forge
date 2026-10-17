# Shared helpers for the deterministic test suite: bash + jq, no network, no Claude session.
# Source it from a test file, set SUITE, call the assertions, end with `finish`.

# FORGE_PLUGIN_ROOT points a test at a mutated copy of the plugin, to prove it fails there.
PLUGIN_ROOT=${FORGE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
SCRIPTS="$PLUGIN_ROOT/hooks/scripts"
PASS=0 FAIL=0 SKIP=0

# The suite must not depend on the session it runs from.
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT CLAUDE_PLUGIN_DATA

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"
  if [[ -n ${2:-} ]]; then printf '        %s\n' "$2"; fi
}
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s (%s)\n' "$1" "$2"; }

# run_hook <script> <stdin> [env assignments...]
# Sets HOOK_STATUS, HOOK_STDOUT and HOOK_STDERR.
run_hook() {
  local script=$1 input=$2 out err
  shift 2
  out=$(mktemp) err=$(mktemp)
  printf '%s' "$input" | env "$@" "$BASH" "$script" >"$out" 2>"$err"
  HOOK_STATUS=$?
  HOOK_STDOUT=$(<"$out") HOOK_STDERR=$(<"$err")
  rm -f "$out" "$err"
}

# expect_status <label> <expected exit code>
expect_status() {
  if [[ $HOOK_STATUS == "$2" ]]; then
    pass "$1"
  else
    fail "$1" "expected exit $2, got $HOOK_STATUS; stderr: ${HOOK_STDERR:0:300}"
  fi
}

# expect_blocked <label>: exit 2 with a reason on stderr.
expect_blocked() {
  if [[ $HOOK_STATUS == 2 && -n $HOOK_STDERR ]]; then
    pass "$1"
  else
    fail "$1" "expected exit 2 with a reason, got exit $HOOK_STATUS; stderr: ${HOOK_STDERR:0:300}"
  fi
}

# expect_silent_allow <label>: exit 0, nothing on stdout or stderr.
expect_silent_allow() {
  if [[ $HOOK_STATUS == 0 && -z $HOOK_STDOUT && -z $HOOK_STDERR ]]; then
    pass "$1"
  else
    fail "$1" "expected silent exit 0, got exit $HOOK_STATUS; stdout: ${HOOK_STDOUT:0:200}; stderr: ${HOOK_STDERR:0:200}"
  fi
}

# bash_input <command> [tool] [cwd]: PreToolUse input for a shell tool.
bash_input() {
  jq -nc --arg c "$1" --arg t "${2:-Bash}" --arg d "${3:-/work/proj}" \
    '{session_id: "test", cwd: $d, hook_event_name: "PreToolUse", permission_mode: "default",
      tool_name: $t, tool_input: {command: $c}, tool_use_id: "toolu_test"}'
}

# A PATH holding only the named tools, to simulate a missing dependency.
# Prints the directory; the caller removes it.
restricted_path() {
  local dir tool
  dir=$(mktemp -d)
  for tool in "$@"; do
    ln -s "$(command -v "$tool")" "$dir/$tool"
  done
  printf '%s' "$dir"
}

finish() {
  printf '%s: %d passed, %d failed, %d skipped\n' "$SUITE" "$PASS" "$FAIL" "$SKIP"
  [[ $FAIL == 0 ]]
}
