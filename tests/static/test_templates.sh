#!/usr/bin/env bash
# The templates: the permission rules proposed to a project and the Flutter fragment of them,
# .forge/config.yaml in the format of plugin-orchestrator (schema 2), the checkpoint, and the
# headers of the documents the plugin writes. ${CLAUDE_PLUGIN_ROOT} does not cross plugins: the
# state files an adoption writes are copies of plugin-orchestrator's formats, checked here.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_templates
SETTINGS="$PLUGIN_ROOT/templates/project-settings.json"
FRAGMENT="$PLUGIN_ROOT/templates/permissions-fragment.json"
CONFIG="$PLUGIN_ROOT/templates/forge-config.yaml"
CHECKPOINT="$PLUGIN_ROOT/templates/checkpoint.md"
DOCS="$PLUGIN_ROOT/templates/doc-templates"

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
  [[ -z $missing ]] && pass "read-only gh, git and flutter commands run without asking" || fail "read-only gh, git and flutter commands run without asking" "missing:$missing"

  missing=""
  for rule in 'Bash(gh repo create *)' 'Bash(gh pr edit *)' 'Bash(gh issue create *)' 'Bash(gh run rerun *)' 'Bash(gh workflow run *)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "gh commands that change GitHub or spend CI minutes ask first" \
    || fail "gh commands that change GitHub or spend CI minutes ask first" "missing:$missing"

  missing=""
  for rule in 'Bash(flutter pub outdated)' 'Bash(flutter pub outdated *)' 'Bash(flutter pub deps)' 'Bash(flutter pub deps *)' \
    'Bash(flutter pub get --enforce-lockfile)' 'Bash(flutter --version --machine)' 'Bash(flutter pub add --dry-run *)' \
    'Bash(git status *)'; do
    grep -qxF "$rule" <<<"$allow" || missing+=" $rule"
  done
  # flutter pub deps, like flutter test, resolves first: it rewrites a stale lockfile.
  [[ -z $missing ]] && pass "commands of the v0.3 skills that change no file on a matching lockfile run without asking" \
    || fail "commands of the v0.3 skills that change no file on a matching lockfile run without asking" "missing:$missing"

  missing=""
  for rule in 'Bash(flutter upgrade*)' 'Bash(flutter downgrade*)' 'Bash(flutter channel *)' 'Bash(flutter pub upgrade)'; do
    grep -qxF "$rule" <<<"$ask" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "changing the machine's Flutter SDK, or every dependency at once, asks first" || fail "changing the machine's Flutter SDK, or every dependency at once, asks first" "missing:$missing"

  # The one dry-run rule is removed first; any other pub add would change pubspec.yaml.
  risky=$(grep -vxF 'Bash(flutter pub add --dry-run *)' <<<"$allow" | grep -nE 'upgrade|downgrade|channel|pub add')
  [[ -z $risky ]] && pass "no allow rule upgrades a dependency or the SDK" || fail "no allow rule upgrades a dependency or the SDK" "$risky"

  risky=$(grep -nE 'gh (pr (create|edit)|repo create|issue create|workflow run|run (rerun|cancel|download)|api|auth token)|show-token|^Bash\(gh \*\)$' <<<"$allow")
  [[ -z $risky ]] && pass "no allow rule changes GitHub or shows a token" || fail "no allow rule changes GitHub or shows a token" "$risky"

  grep -q '^Write(' <<<"$all" && fail "no Write() rule (only Edit() rules protect files)" "$(grep '^Write(' <<<"$all")" \
    || pass "no Write() rule (only Edit() rules protect files)"
  grep -qF ':*' <<<"$all" && fail "space form Bash(x *), not the legacy :*" "$(grep -F ':*' <<<"$all")" \
    || pass "space form Bash(x *), not the legacy :*"

  # The generic rules of plugin-orchestrator 0.1.0 (templates/project-settings.json there), which an
  # adoption installs with the Flutter fragment: the session cannot read the orchestrator's file.
  missing=""
  for rule in 'Bash(git --version)' 'Bash(jq --version)' 'Bash(git ls-files)' 'Bash(git ls-files *)' 'Bash(git show *)'; do
    grep -qxF "$rule" <<<"$allow" || missing+=" $rule"
  done
  for rule in 'Read(./**/*.jks)' 'Read(./**/*.keystore)' 'Read(./**/*.p12)' 'Read(./**/*.pfx)'; do
    grep -qxF "$rule" <<<"$deny" || missing+=" $rule"
  done
  [[ -z $missing ]] && pass "the generic rules of plugin-orchestrator 0.1.0 are there" || fail "the generic rules of plugin-orchestrator 0.1.0 are there" "missing:$missing"
fi

echo "# permissions-fragment.json"
if ! jq -e '.permissions | (.allow, .ask, .deny) | type == "array"' "$FRAGMENT" >/dev/null 2>&1; then
  fail "valid JSON with permissions.allow, ask and deny arrays" "missing or invalid: $FRAGMENT"
else
  pass "valid JSON with permissions.allow, ask and deny arrays"
  generic=$(jq -r '.permissions[][]' "$FRAGMENT" | grep -vE '^Bash\((flutter|dart) ')
  [[ -z $generic ]] && pass "every rule of the fragment is a flutter or dart command" || fail "every rule of the fragment is a flutter or dart command" "$generic"
  # The fragment is the scaffold's PERMISSIONS block: project-settings.json is the generic rules plus it.
  for kind in allow ask deny; do
    expected=$(jq -r --arg k "$kind" '.permissions[$k][] | select(test("^Bash\\((flutter|dart) "))' "$SETTINGS" | LC_ALL=C sort)
    actual=$(jq -r --arg k "$kind" '.permissions[$k][]' "$FRAGMENT" | LC_ALL=C sort)
    [[ -n $actual && $actual == "$expected" ]] && pass "$kind: the fragment is the flutter and dart rules of project-settings.json" \
      || fail "$kind: the fragment is the flutter and dart rules of project-settings.json" "$(diff <(echo "$expected") <(echo "$actual"))"
  done
  risky=$(jq -r '.permissions.allow[]' "$FRAGMENT" | grep -vxF 'Bash(flutter pub add --dry-run *)' | grep -nE 'publish|upgrade|downgrade|channel|pub add|config')
  [[ -z $risky ]] && pass "no allow rule of the fragment publishes, upgrades or changes the machine" || fail "no allow rule of the fragment publishes, upgrades or changes the machine" "$risky"
fi

echo "# forge-config.yaml"
if [[ -f $CONFIG ]]; then
  pass "templates/forge-config.yaml exists"
  grep -qx 'schema_version: 2' "$CONFIG" && pass "schema_version: 2, the format of plugin-orchestrator" || fail "schema_version: 2, the format of plugin-orchestrator"
  grep -qE '^platforms:' "$CONFIG" && fail "no top-level platforms (schema 1)" || pass "no top-level platforms (schema 1)"
  # One part, the root, run by this plugin at interface 1, with the Flutter toolchain filled in:
  # the same lines the scaffold-engineer returns in its TOOLCHAIN block.
  parts=$(awk '/^parts:/ { inside = 1; next } /^[^ #]/ { inside = 0 } inside && !/^ *#/ { print }' "$CONFIG")
  missing=""
  for line in '  app:' '    path: .' '    plugin: plugin-flutter' '    interface: 1' '    toolchain:' \
    '      test: flutter test' '      format: dart format --output=none --set-exit-if-changed .' \
    '      analyze: flutter analyze' '      add_dep: flutter pub add' \
    '      manifests: [pubspec.yaml, pubspec.lock]'; do
    grep -qxF -- "$line" <<<"$parts" || missing+=" [$line]"
  done
  [[ -z $missing ]] && pass "parts: the root, plugin-flutter, interface 1 and the Flutter toolchain" \
    || fail "parts: the root, plugin-flutter, interface 1 and the Flutter toolchain" "missing:$missing"
  grep -qE '^    platforms: \[[a-z, ]+\]$' <<<"$parts" && pass "the part declares its platforms" || fail "the part declares its platforms" "$parts"
  # Review of v1.0 (I2): the orchestrator copies these lines as plain commands; a <device>
  # placeholder blocks every integration test. The line stays a comment until a device is known.
  grep -q '<device>' <<<"$parts" && fail "no active toolchain line holds a placeholder" "$(grep '<device>' <<<"$parts")" \
    || pass "no active toolchain line holds a placeholder"
  grep -qxF '      # integration_test: flutter test integration_test -d <device id from flutter devices>   # optional' "$CONFIG" \
    && pass "integration_test is a comment, to fill with a device of flutter devices" || fail "integration_test is a comment, to fill with a device of flutter devices"
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

echo "# checkpoint.md"
if [[ -f $CHECKPOINT ]]; then
  pass "templates/checkpoint.md exists"
  missing=""
  for needle in "updated:" "skill:" "branch:" "last_commit:" "## Steps" "## Test results" "## Next action" "## Blockers"; do
    grep -qF -- "$needle" "$CHECKPOINT" || missing+=" [$needle]"
  done
  [[ -z $missing ]] && pass "checkpoint has the fields plugin-orchestrator's recover-session reads" || fail "checkpoint fields" "missing:$missing"
else
  fail "templates/checkpoint.md exists"
fi

echo "# document templates"
# doc-status-guard (plugin-orchestrator) reads the Status row; a changed APPROVED document goes back to REVIEW.
for doc in TRD IMPLEMENTATION_PLAN DECISIONS; do
  file="$DOCS/$doc.md"
  if [[ ! -f $file ]]; then fail "doc-templates/$doc.md exists"; continue; fi
  grep -qxF '| Status | DRAFT |' "$file" && pass "$doc: starts in DRAFT" || fail "$doc: starts in DRAFT"
  grep -qE '^\| Approved \|.*goes back to REVIEW' "$file" && pass "$doc: an approved document that changes goes back to REVIEW" \
    || fail "$doc: an approved document that changes goes back to REVIEW" "$(grep '^| Approved' "$file")"
done
if [[ -f $DOCS/CLAUDE.md ]]; then
  for workflow in create-feature git-workflow github-workflow recover-session debug-project; do
    grep -qF "/plugin-orchestrator:$workflow" "$DOCS/CLAUDE.md" && pass "CLAUDE.md names /plugin-orchestrator:$workflow" \
      || fail "CLAUDE.md names /plugin-orchestrator:$workflow"
  done
  grep -qF '/plugin-flutter:update-project' "$DOCS/CLAUDE.md" && pass "CLAUDE.md names /plugin-flutter:update-project" \
    || fail "CLAUDE.md names /plugin-flutter:update-project"
  grep -qF 'lib/features/<feature>/{data,domain,presentation}' "$DOCS/CLAUDE.md" && pass "CLAUDE.md keeps the Flutter layout" \
    || fail "CLAUDE.md keeps the Flutter layout"
else
  fail "doc-templates/CLAUDE.md exists"
fi

finish
