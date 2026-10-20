#!/usr/bin/env bash
# Paths cited by hooks.json exist and go through ${CLAUDE_PLUGIN_ROOT}; hooks use exec form.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_paths
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"

echo "# hooks/hooks.json"
if ! jq -e '.hooks | type == "object"' "$HOOKS_JSON" >/dev/null 2>&1; then
  fail "hooks.json is JSON with a top-level \"hooks\" object" "missing or invalid: $HOOKS_JSON"
  finish
  exit
fi
pass "hooks.json is JSON with a top-level \"hooks\" object"

# One line per command hook: event, matcher, type, command, first arg, onFailure, arg count.
# Fields are joined by \x1f, not tabs: read merges consecutive tabs and would drop an empty matcher.
hooks=$(jq -r '.hooks | to_entries[] | .key as $event | .value[] | (.matcher // "") as $m
               | .hooks[] | [$event, $m, (.type // ""), (.command // ""), (.args[0] // ""),
                             (.onFailure // ""), ((.args // []) | length)] | map(tostring) | join("\u001f")' "$HOOKS_JSON")

while IFS=$'\x1f' read -r event matcher type command arg0 on_failure argc; do
  label="$event ${arg0##*/}"
  [[ $type == command ]] && pass "$label: command hook" || fail "$label: command hook" "type: $type"
  [[ $command == bash && $argc == 1 ]] && pass "$label: exec form (bash + script)" \
    || fail "$label: exec form (bash + script)" "command: $command, args: $argc"
  if [[ $arg0 == '${CLAUDE_PLUGIN_ROOT}/'* ]]; then
    pass "$label: path goes through \${CLAUDE_PLUGIN_ROOT}"
    script="$PLUGIN_ROOT/${arg0#'${CLAUDE_PLUGIN_ROOT}/'}"
    [[ -f $script ]] && pass "$label: script exists" || fail "$label: script exists" "$script"
  else
    fail "$label: path goes through \${CLAUDE_PLUGIN_ROOT}" "$arg0"
  fi
done <<<"$hooks"

# expect_hook <event> <matcher> <script> <onFailure or "">
expect_hook() {
  local sep=$'\x1f'
  if grep -qxF "$1$sep$2${sep}command${sep}bash$sep\${CLAUDE_PLUGIN_ROOT}/hooks/scripts/$3$sep$4${sep}1" <<<"$hooks"; then
    pass "wired: $1 [$2] $3 onFailure=${4:-unset}"
  else
    fail "wired: $1 [$2] $3 onFailure=${4:-unset}" "hooks: $hooks"
  fi
}
expect_hook PreToolUse 'Bash|PowerShell|Monitor' guard-destructive.sh block
expect_hook PreToolUse 'Edit|Write|NotebookEdit|Bash|PowerShell|Monitor' agent-scope-guard.sh block
expect_hook PreToolUse 'Bash|PowerShell|Monitor' secret-scan.sh block
expect_hook PreToolUse 'Edit|Write|NotebookEdit' protect-sensitive.sh block
expect_hook PostToolUse 'Edit|Write' format-dart.sh continue
expect_hook Stop '' checkpoint-reminder.sh ''

for script in "$PLUGIN_ROOT"/hooks/scripts/*.sh; do
  name=${script##*/}
  grep -qF "hooks/scripts/$name" "$HOOKS_JSON" && pass "$name is referenced by hooks.json" \
    || fail "$name is referenced by hooks.json"
  [[ $(head -n 1 "$script") == '#!/usr/bin/env bash' ]] && pass "$name: #!/usr/bin/env bash" \
    || fail "$name: #!/usr/bin/env bash" "$(head -n 1 "$script")"
done
for script in "$PLUGIN_ROOT"/hooks/scripts/*.sh "$PLUGIN_ROOT"/hooks/scripts/lib/*.sh; do
  bash -n "$script" 2>/dev/null && pass "${script#"$PLUGIN_ROOT"/}: bash -n" || fail "${script#"$PLUGIN_ROOT"/}: bash -n"
done
[[ -f $PLUGIN_ROOT/hooks/scripts/lib/shell-lexer.sh ]] && pass "shell lexer library exists" || fail "shell lexer library exists"
if grep -rn '/bin/bash' "$PLUGIN_ROOT/hooks" >/dev/null; then
  fail "no /bin/bash under hooks/ (absent on NixOS)" "$(grep -rn '/bin/bash' "$PLUGIN_ROOT/hooks")"
else
  pass "no /bin/bash under hooks/ (absent on NixOS)"
fi

echo "# skills, agents and templates"
shopt -s nullglob
substituted=("$PLUGIN_ROOT"/skills/*/SKILL.md "$PLUGIN_ROOT"/agents/*.md)
annexes=()
while IFS= read -r -d '' file; do annexes+=("$file"); done \
  < <(find "$PLUGIN_ROOT/templates" "$PLUGIN_ROOT/skills" -type f ! -name SKILL.md -print0 2>/dev/null)

((${#substituted[@]} > 0)) && pass "skills and agents found (${#substituted[@]})" || fail "skills and agents found"

cited=$(cat "${substituted[@]}" /dev/null | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]*[A-Za-z0-9_/-]' | sort -u)
while IFS= read -r ref; do
  [[ -n $ref ]] || continue
  [[ -e $PLUGIN_ROOT/${ref#'${CLAUDE_PLUGIN_ROOT}/'} ]] && pass "cited path exists: $ref" || fail "cited path exists: $ref"
done <<<"$cited"

for file in "$PLUGIN_ROOT"/skills/bootstrap-project/reference/doc-templates/{PRD,TRD,IMPLEMENTATION_PLAN,DECISIONS}.md \
  "$PLUGIN_ROOT"/templates/{project-settings.json,forge-config.yaml,checkpoint.md} \
  "$PLUGIN_ROOT"/skills/update-project/reference/deps-report.md; do
  rel=${file#"$PLUGIN_ROOT"/}
  [[ -f $file ]] && pass "$rel exists" || fail "$rel exists"
done

for file in ${annexes[@]+"${annexes[@]}"}; do
  rel=${file#"$PLUGIN_ROOT"/}
  grep -qF "\${CLAUDE_PLUGIN_ROOT}/$rel" "${substituted[@]}" /dev/null \
    && pass "$rel is cited through \${CLAUDE_PLUGIN_ROOT}" || fail "$rel is cited through \${CLAUDE_PLUGIN_ROOT}"
  grep -qF '${CLAUDE_PLUGIN_ROOT}' "$file" \
    && fail "$rel does not contain \${CLAUDE_PLUGIN_ROOT} (annexes are not substituted)" \
    || pass "$rel does not contain \${CLAUDE_PLUGIN_ROOT} (annexes are not substituted)"
done

# /nix/store/ alone is allowed: update-project detects a Flutter from Nix by that prefix.
personal=$(grep -rnE '/home/|/Users/|/nix/store/[a-z0-9]{32}-' "$PLUGIN_ROOT"/{agents,skills,templates,hooks} 2>/dev/null)
[[ -z $personal ]] && pass "no absolute personal or store path in the plugin" || fail "no absolute personal or store path in the plugin" "$personal"
shopt -u nullglob

finish
