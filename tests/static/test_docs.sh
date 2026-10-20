#!/usr/bin/env bash
# User docs against the plugin: the version, the counts and the components they name, and the
# permission rules SECURITY.md lists. The validation reports (docs/V0.*_REPORT.md,
# docs/PHASE_A_REPORT.md) and the CHANGELOG describe their own version and are left out.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_docs
README="$PLUGIN_ROOT/README.md"
CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"
GUIDE="$PLUGIN_ROOT/docs/USER_GUIDE.md"
SECURITY="$PLUGIN_ROOT/docs/SECURITY.md"
INSTALL="$PLUGIN_ROOT/docs/INSTALLATION.md"
TROUBLE="$PLUGIN_ROOT/docs/TROUBLESHOOTING.md"
SETTINGS="$PLUGIN_ROOT/templates/project-settings.json"
USER_DOCS=("$README" "$GUIDE" "$SECURITY" "$INSTALL" "$TROUBLE")
WORDS=(zéro un deux trois quatre cinq six sept huit neuf dix)

skills=() agents=()
for f in "$PLUGIN_ROOT"/skills/*/SKILL.md; do d=${f%/SKILL.md}; skills+=("${d##*/}"); done
for f in "$PLUGIN_ROOT"/agents/*.md; do f=${f##*/}; agents+=("${f%.md}"); done

echo "# version"
version=$(jq -r '.version // empty' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
readme_version=$(sed -nE 's/^Version \*\*([^*]+)\*\*.*/\1/p' "$README" | head -1)
changelog_version=$(sed -nE 's/^## \[([^]]+)\].*/\1/p' "$CHANGELOG" | head -1)
[[ -n $version && $readme_version == "$version" ]] && pass "README gives the version of plugin.json ($version)" \
  || fail "README gives the version of plugin.json" "plugin.json: $version, README: $readme_version"
[[ -n $version && $changelog_version == "$version" ]] && pass "the latest CHANGELOG entry is the version of plugin.json" \
  || fail "the latest CHANGELOG entry is the version of plugin.json" "plugin.json: $version, CHANGELOG: $changelog_version"

echo "# counts"
grep -qF "Attendu : ${#skills[@]} skills, ${#agents[@]} agents" "$INSTALL" \
  && pass "INSTALLATION expects ${#skills[@]} skills and ${#agents[@]} agents" \
  || fail "INSTALLATION expects ${#skills[@]} skills and ${#agents[@]} agents" "$(grep -n 'Attendu :' "$INSTALL")"

# count_of <noun> <count>: every "<n> <noun>" of the user docs, in digits or in words, says <count>.
count_of() {
  local noun=$1 n=$2 bad
  bad=$(grep -noiE "\b([0-9]+|un|deux|trois|quatre|cinq|six|sept|huit|neuf|dix) $noun\b" "${USER_DOCS[@]}" \
    | grep -viE ":($n|${WORDS[n]}) $noun\$")
  [[ -z $bad ]] && pass "every count of $noun in the user docs is $n" || fail "every count of $noun in the user docs is $n" "$bad"
}
count_of skills "${#skills[@]}"
count_of agents "${#agents[@]}"

echo "# components"
for s in "${skills[@]}"; do
  grep -qF "| Skill \`$s\` |" "$README" && pass "README lists the skill $s" || fail "README lists the skill $s"
  grep -qE "^## .* — \`$s\`\$" "$GUIDE" && pass "the guide has a section for $s" || fail "the guide has a section for $s"
done
for a in "${agents[@]}"; do
  grep -qF "| Agent \`$a\` |" "$README" && pass "README lists the agent $a" || fail "README lists the agent $a"
  grep -qE "^\| $a \|" "$GUIDE" && pass "the guide's agent table has $a" || fail "the guide's agent table has $a"
done

echo "# permission rules in SECURITY.md"
# rule_commands <allow|ask|deny>: the Bash rules of the template as the command they cover, without
# the trailing wildcard. A rule with an inner wildcard (git push * -f*) is described in words: skipped.
rule_commands() {
  jq -r --arg k "$1" '.permissions[$k][] | select(startswith("Bash(")) | .[5:-1]' "$SETTINGS" \
    | sed -E 's/ ?\*$//' | grep -vF '*' | sort -u
}
for kind in "allow:Sans demander" "ask:Demandent d'abord" "deny:Refusées"; do
  key=${kind%%:*} heading=${kind#*:}
  line=$(grep -m1 -F -- "- **$heading** :" "$SECURITY")
  missing=""
  while IFS= read -r cmd; do
    [[ $line == *"\`$cmd"* ]] || missing+=" [$cmd]"
  done < <(rule_commands "$key")
  [[ -n $line && -z $missing ]] && pass "SECURITY.md lists every $key rule under « $heading »" \
    || fail "SECURITY.md lists every $key rule under « $heading »" "missing:${missing:- the line itself}"
done

finish
