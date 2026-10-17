#!/usr/bin/env bash
# format-dart — PostToolUse hook for Edit and Write.
# Runs `dart format` on the edited file when it is a .dart file and dart is installed.
# Fail-open: it always exits 0 and prints nothing; hooks.json sets "onFailure": "continue".

command -v jq >/dev/null 2>&1 || exit 0
IFS= read -r -d '' input || true
file=$(jq -r 'select(.tool_name == "Edit" or .tool_name == "Write") | .tool_input.file_path // empty | strings' \
  <<<"$input" 2>/dev/null) || exit 0
[[ $file == *.dart && -f $file ]] || exit 0
command -v dart >/dev/null 2>&1 || exit 0
dart format "$file" >/dev/null 2>&1
exit 0
