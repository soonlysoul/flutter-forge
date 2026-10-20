#!/usr/bin/env bash
# Agent and skill frontmatter, read by a deliberately strict parser.
# A plugin agent whose frontmatter does not parse loads with every field ignored, hence with
# every tool and no message (phase A, report 3.3): this test is the only guard against that.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_frontmatter

# read_frontmatter <file>: fills FM (key -> value) or sets FM_ERROR.
# Accepted: line 1 is ---, then single-line `key: value` lines, then ---. An unquoted value
# contains neither ": " nor " #" and does not start with a YAML indicator; a quoted value is
# enclosed in matching quotes. Keys are unique.
read_frontmatter() {
  local file=$1 line key value closed=0 n=0
  declare -gA FM=()
  FM_ERROR=""
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    if ((n == 1)); then
      [[ $line == --- ]] || { FM_ERROR="line 1 is not ---"; return 1; }
      continue
    fi
    if [[ $line == --- ]]; then closed=1; break; fi
    if [[ ! $line =~ ^([a-z][a-z0-9_-]*):\ (.+)$ ]]; then
      FM_ERROR="line $n is not a single-line 'key: value': $line"; return 1
    fi
    key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}
    [[ -z ${FM[$key]+set} ]] || { FM_ERROR="duplicate key $key"; return 1; }
    case $value in
      \"*) [[ $value =~ ^\"[^\"]*\"$ ]] || { FM_ERROR="unbalanced double quotes in $key"; return 1; }; value=${value:1:-1} ;;
      \'*) [[ $value =~ ^\'[^\']*\'$ ]] || { FM_ERROR="unbalanced single quotes in $key"; return 1; }; value=${value:1:-1} ;;
      [\[\]\{\}\&\*\!\|\>%@\`]*) FM_ERROR="$key starts with a YAML indicator: $value"; return 1 ;;
      *': '* | *' #'*) FM_ERROR="unquoted $key contains ': ' or ' #': $value"; return 1 ;;
    esac
    FM[$key]=$value
  done <"$file"
  ((closed)) || { FM_ERROR="frontmatter is not closed by ---"; return 1; }
}

body_of() { awk 'n >= 2 { print } /^---$/ { n++ }' "$1"; }

echo "# the strict parser rejects broken frontmatter"
fixtures=$(mktemp -d)
printf -- '---\nname: ok\ndescription: A valid one.\ntools: Read, Grep\n---\nBody\n' >"$fixtures/valid.md"
printf -- '---\nname: x\ndescription: [unclosed\n---\n' >"$fixtures/bracket.md"
printf -- '---\nname: x\ndescription: Use when: anything\n---\n' >"$fixtures/colon.md"
printf -- '---\nname: x\ntools:\n  - Read\n---\n' >"$fixtures/list.md"
printf -- '---\nname: x\nname: y\n---\n' >"$fixtures/duplicate.md"
printf -- '---\nname: x\ndescription: "unbalanced\n---\n' >"$fixtures/quote.md"
printf -- '---\nname: x\ndescription: no end\n' >"$fixtures/unclosed.md"
printf -- 'name: x\n---\n' >"$fixtures/noopen.md"
read_frontmatter "$fixtures/valid.md" && [[ ${FM[tools]} == "Read, Grep" ]] \
  && pass "valid frontmatter is read" || fail "valid frontmatter is read" "$FM_ERROR"
for broken in bracket colon list duplicate quote unclosed noopen; do
  if read_frontmatter "$fixtures/$broken.md"; then fail "rejects $broken"; else pass "rejects $broken ($FM_ERROR)"; fi
done
rm -r "$fixtures"

echo "# agents"
declare -A expected_model=([flutter-architect]=inherit [test-engineer]=sonnet [code-reviewer]=sonnet [devops-engineer]=sonnet [product-architect]=inherit)
known_tools=" Read Grep Glob Bash Write Edit "
agents=$(cd "$PLUGIN_ROOT/agents" 2>/dev/null && ls *.md 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')
[[ $agents == "code-reviewer.md devops-engineer.md flutter-architect.md product-architect.md test-engineer.md " ]] \
  && pass "exactly the five v0.3 agents" || fail "exactly the five v0.3 agents" "found: ${agents:-none}"

for agent in flutter-architect test-engineer code-reviewer devops-engineer product-architect; do
  file="$PLUGIN_ROOT/agents/$agent.md"
  if [[ ! -f $file ]] || ! read_frontmatter "$file"; then
    fail "$agent: readable frontmatter" "${FM_ERROR:-missing file}"
    continue
  fi
  pass "$agent: readable frontmatter"
  bad_keys=""
  for key in "${!FM[@]}"; do
    case $key in name | description | tools | model | color) ;; *) bad_keys+=" $key" ;; esac
  done
  [[ -z $bad_keys ]] && pass "$agent: only name, description, tools, model, color" || fail "$agent: only known keys" "unexpected:$bad_keys"
  [[ ${FM[name]-} == "$agent" ]] && pass "$agent: name matches the file" || fail "$agent: name matches the file" "name: ${FM[name]-}"
  [[ -n ${FM[description]-} ]] && pass "$agent: description" || fail "$agent: description"
  [[ ${FM[model]-} == "${expected_model[$agent]}" ]] && pass "$agent: model ${expected_model[$agent]}" \
    || fail "$agent: model ${expected_model[$agent]}" "model: ${FM[model]-unset}"
  if [[ -z ${FM[tools]-} ]]; then
    fail "$agent: tools declared (omitted means every tool)"
  else
    pass "$agent: tools declared (omitted means every tool)"
    unknown="" tools=" "
    IFS=',' read -r -a list <<<"${FM[tools]}"
    for tool in "${list[@]}"; do
      tool=${tool// /}
      tools+="$tool "
      [[ $known_tools == *" $tool "* ]] || unknown+=" $tool"
    done
    [[ -z $unknown ]] && pass "$agent: only known tools, no Agent" || fail "$agent: only known tools, no Agent" "unexpected:$unknown"
    if [[ $agent == code-reviewer ]]; then
      [[ $tools != *" Write "* && $tools != *" Edit "* ]] && pass "code-reviewer: neither Write nor Edit" \
        || fail "code-reviewer: neither Write nor Edit" "tools: ${FM[tools]}"
    fi
    if [[ $agent == product-architect ]]; then
      [[ $tools != *" Bash "* ]] && pass "product-architect: no Bash" || fail "product-architect: no Bash" "tools: ${FM[tools]}"
    fi
  fi
  body=$(body_of "$file")
  missing=""
  for field in STATUS FILES_CHANGED COMMANDS_RUN OPEN_QUESTIONS; do [[ $body == *"$field"* ]] || missing+=" $field"; done
  [[ -z $missing ]] && pass "$agent: report format STATUS/FILES_CHANGED/COMMANDS_RUN/OPEN_QUESTIONS" \
    || fail "$agent: report format" "missing:$missing"
done

echo "# skills"
skills=$(cd "$PLUGIN_ROOT/skills" 2>/dev/null && ls -d */ 2>/dev/null | tr -d / | LC_ALL=C sort | tr '\n' ' ')
[[ $skills == "adopt-existing-project bootstrap-project create-feature debug-project git-workflow github-workflow recover-session update-project " ]] \
  && pass "exactly the eight v0.3 skills" || fail "exactly the eight v0.3 skills" "found: ${skills:-none}"

for skill in bootstrap-project create-feature git-workflow recover-session github-workflow debug-project update-project adopt-existing-project; do
  file="$PLUGIN_ROOT/skills/$skill/SKILL.md"
  if [[ ! -f $file ]] || ! read_frontmatter "$file"; then
    fail "$skill: readable frontmatter" "${FM_ERROR:-missing file}"
    continue
  fi
  pass "$skill: readable frontmatter"
  bad_keys=""
  for key in "${!FM[@]}"; do
    case $key in name | description | argument-hint | when_to_use) ;; *) bad_keys+=" $key" ;; esac
  done
  [[ -z $bad_keys ]] && pass "$skill: only name, description, argument-hint, when_to_use" || fail "$skill: only known keys" "unexpected:$bad_keys"
  [[ ${FM[name]-} == "$skill" ]] && pass "$skill: name matches the directory" || fail "$skill: name matches the directory" "name: ${FM[name]-}"
  [[ -n ${FM[description]-} ]] && pass "$skill: description" || fail "$skill: description"
  # With the plugin installed for every project, only bootstrap may trigger outside a forge project.
  if [[ $skill != bootstrap-project ]]; then
    [[ ${FM[description]-} == *".forge/"* ]] && pass "$skill: description limits it to projects with .forge/" \
      || fail "$skill: description limits it to projects with .forge/" "${FM[description]-}"
  fi
  listing="${FM[description]-}${FM[when_to_use]-}"
  ((${#listing} <= 1536)) && pass "$skill: description + when_to_use <= 1536 chars (${#listing})" \
    || fail "$skill: description + when_to_use <= 1536 chars" "${#listing}"
  lines=$(wc -l <"$file")
  ((lines < 500)) && pass "$skill: under 500 lines ($lines)" || fail "$skill: under 500 lines" "$lines"
  if grep -nE '\$[0-9]' "$file" >/dev/null; then
    fail "$skill: no \$0-\$9 (substituted as skill arguments)" "$(grep -nE '\$[0-9]' "$file" | head -3)"
  else
    pass "$skill: no \$0-\$9 (substituted as skill arguments)"
  fi
done

finish
