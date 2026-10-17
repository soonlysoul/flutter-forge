#!/usr/bin/env bash
# plugin.json and marketplace.json: valid JSON, required fields, kebab-case name shared by both,
# SemVer version, entry pointing at the plugin root.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_manifest
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
MARKET_JSON="$PLUGIN_ROOT/.claude-plugin/marketplace.json"

# check <label> <jq filter returning true> <file>
check() {
  if jq -e "$2" "$3" >/dev/null 2>&1; then pass "$1"; else fail "$1" "$(jq -c "$2" "$3" 2>&1 | head -c 200)"; fi
}

echo "# plugin.json"
if jq -e . "$PLUGIN_JSON" >/dev/null 2>&1; then
  pass "plugin.json is valid JSON"
  check "name is kebab-case" '.name | type == "string" and test("^[a-z0-9]+(-[a-z0-9]+)*$")' "$PLUGIN_JSON"
  check "version is SemVer" '.version | type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")' "$PLUGIN_JSON"
  check "description is not empty" '.description | type == "string" and length > 0' "$PLUGIN_JSON"
  check "author.name is not empty" '.author.name | type == "string" and length > 0' "$PLUGIN_JSON"
  check "license is MIT" '.license == "MIT"' "$PLUGIN_JSON"
  check "only known fields" '(keys - ["name", "version", "description", "author", "license", "keywords"]) == []' "$PLUGIN_JSON"
else
  fail "plugin.json is valid JSON" "$PLUGIN_JSON"
fi

echo "# marketplace.json"
if jq -e . "$MARKET_JSON" >/dev/null 2>&1; then
  pass "marketplace.json is valid JSON"
  check "name, owner.name, description and plugins present" \
    '(.name | type == "string") and (.owner.name | type == "string") and (.description | type == "string") and (.plugins | type == "array")' "$MARKET_JSON"
  check "exactly one plugin entry" '.plugins | length == 1' "$MARKET_JSON"
  check "the entry points at the plugin root" '.plugins[0].source == "./"' "$MARKET_JSON"
  check "the entry does not repeat version" '.plugins[0] | has("version") | not' "$MARKET_JSON"
  plugin_name=$(jq -r '.name // empty' "$PLUGIN_JSON" 2>/dev/null)
  entry_name=$(jq -r '.plugins[0].name // empty' "$MARKET_JSON")
  [[ -n $plugin_name && $plugin_name == "$entry_name" ]] && pass "entry name matches plugin.json ($entry_name)" \
    || fail "entry name matches plugin.json" "plugin.json: $plugin_name, entry: $entry_name"
else
  fail "marketplace.json is valid JSON" "$MARKET_JSON"
fi

[[ ! -e $PLUGIN_ROOT/CLAUDE.md ]] && pass "no CLAUDE.md at the plugin root (not loaded, warned)" \
  || fail "no CLAUDE.md at the plugin root (not loaded, warned)"

finish
