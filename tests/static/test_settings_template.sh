#!/usr/bin/env bash
# Security templates: the permission rules proposed to a project, and .forge/config.yaml.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_settings_template
SETTINGS="$PLUGIN_ROOT/templates/project-settings.json"
CONFIG="$PLUGIN_ROOT/templates/forge-config.yaml"

echo "# project-settings.json"
if ! jq -e '.permissions | (.allow, .ask, .deny) | type == "array"' "$SETTINGS" >/dev/null 2>&1; then
  fail "valid JSON with permissions.allow, ask and deny arrays" "missing or invalid: $SETTINGS"
else
  pass "valid JSON with permissions.allow, ask and deny arrays"
  allow=$(jq -r '.permissions.allow[]' "$SETTINGS")
  ask=$(jq -r '.permissions.ask[]' "$SETTINGS")
  deny=$(jq -r '.permissions.deny[]' "$SETTINGS")
  all=$(jq -r '.permissions[][]' "$SETTINGS")

  risky=$(grep -nE 'push|merge|reset|clean|rm |delete|publish|\bforce|branch -D|checkout|restore|stash|^Bash$|^Bash\(\*\)$' <<<"$allow")
  [[ -z $risky ]] && pass "no allow rule covers push, merge, reset, clean or deletion" \
    || fail "no allow rule covers push, merge, reset, clean or deletion" "$risky"

  missing=""
  for rule in 'Bash(git reset --hard*)' 'Bash(git clean *)' 'Bash(git push --force*)' 'Bash(git push * --force*)' \
    'Bash(git push -f*)' 'Bash(git push * -f*)' 'Bash(git push * +*)' 'Bash(git branch -D *)' \
    'Bash(gh repo delete *)' 'Bash(gh pr merge *)' 'Bash(dart pub publish*)' 'Bash(flutter pub publish*)' \
    'Read(./.env)' 'Read(./.env.*)' 'Read(./**/key.properties)' 'Edit(./.forge/config.yaml)'; do
    grep -qxF "$rule" <<<"$deny" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "every expected deny rule is present" || fail "every expected deny rule is present" "missing:$missing"

  missing=""
  for rule in 'Bash(git commit *)' 'Bash(git push *)' 'Bash(git add -A*)' 'Bash(git add .)' 'Bash(git add --all*)' \
    'Bash(gh pr create *)' 'Bash(flutter pub upgrade *)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "commit, push and git add -A ask first" || fail "commit, push and git add -A ask first" "missing:$missing"

  missing=""
  for rule in 'Bash(gh --version)' 'Bash(gh auth status)' 'Bash(gh pr view *)' 'Bash(gh pr checks *)' 'Bash(gh run list *)' \
    'Bash(gh run view *)' 'Bash(gh run watch *)' 'Bash(gh repo view)' 'Bash(gh repo view *)' 'Bash(gh workflow list)' \
    'Bash(gh workflow view *)' 'Bash(gh issue list *)' 'Bash(gh issue view *)' 'Bash(git remote -v)' 'Bash(git rev-parse *)' \
    'Bash(git branch --show-current)' 'Bash(flutter --version)' 'Bash(flutter doctor)' 'Bash(flutter doctor *)' \
    'Bash(flutter devices)' 'Bash(flutter build *)'; do
    grep -qxF "$rule" <<<"$allow" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "read-only gh, git and flutter commands of the v0.2 workflows run without asking" || fail "read-only gh, git and flutter commands of the v0.2 workflows run without asking" "missing:$missing"

  missing=""
  for rule in 'Bash(gh repo create *)' 'Bash(gh pr edit *)' 'Bash(gh issue create *)' 'Bash(gh run rerun *)' 'Bash(gh workflow run *)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "gh commands that change GitHub or spend CI minutes ask first" \
    || fail "gh commands that change GitHub or spend CI minutes ask first" "missing:$missing"

  missing=""
  for rule in 'Bash(flutter pub outdated)' 'Bash(flutter pub outdated *)' 'Bash(flutter pub deps)' 'Bash(flutter pub deps *)' \
    'Bash(flutter pub get --enforce-lockfile)' 'Bash(flutter --version --machine)'; do
    grep -qxF "$rule" <<<"$allow" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "read-only pub and SDK commands of the v0.3 skills run without asking" \
    || fail "read-only pub and SDK commands of the v0.3 skills run without asking" "missing:$missing"

  missing=""
  for rule in 'Bash(flutter upgrade*)' 'Bash(flutter downgrade*)' 'Bash(flutter channel *)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "changing the machine's Flutter SDK asks first" || fail "changing the machine's Flutter SDK asks first" "missing:$missing"

  risky=$(grep -nE 'upgrade|downgrade|channel' <<<"$allow")
  [[ -z $risky ]] && pass "no allow rule upgrades a dependency or the SDK" || fail "no allow rule upgrades a dependency or the SDK" "$risky"

  risky=$(grep -nE 'gh (pr (create|edit)|repo create|issue create|workflow run|run (rerun|cancel|download)|api|auth token)|show-token|^Bash\(gh \*\)$' <<<"$allow")
  [[ -z $risky ]] && pass "no allow rule changes GitHub or shows a token" || fail "no allow rule changes GitHub or shows a token" "$risky"

  grep -q '^Write(' <<<"$all" && fail "no Write() rule (only Edit() rules protect files)" "$(grep '^Write(' <<<"$all")" \
    || pass "no Write() rule (only Edit() rules protect files)"
  grep -qF ':*' <<<"$all" && fail "space form Bash(x *), not the legacy :*" "$(grep -F ':*' <<<"$all")" \
    || pass "space form Bash(x *), not the legacy :*"
fi

echo "# forge-config.yaml"
if [[ -f $CONFIG ]]; then
  pass "templates/forge-config.yaml exists"
  grep -qx 'schema_version: 1' "$CONFIG" && pass "schema_version: 1" || fail "schema_version: 1"
  auth=$(awk '/^authorizations:/ { inside = 1; next } /^[^ #]/ { inside = 0 } inside && /:/ { print }' "$CONFIG")
  [[ -n $auth ]] && pass "authorizations block present" || fail "authorizations block present"
  not_false=$(grep -vE '^\s+[a-z_]+: false(\s+#.*)?$' <<<"$auth")
  [[ -z $not_false ]] && pass "every authorization is false" || fail "every authorization is false" "$not_false"
  for key in push_feature_branches open_pull_requests update_own_pull_requests create_remote_repo merge publish_release; do
    grep -qE "^\s+$key: false" <<<"$auth" && pass "authorization $key: false" || fail "authorization $key: false"
  done
else
  fail "templates/forge-config.yaml exists"
fi

finish
