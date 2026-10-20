#!/usr/bin/env bash
# templates/github-workflows/flutter-ci.yml: the CI copied into projects by github-workflow.
# Pinned actions, read-only token, the four quality commands, the two placeholders.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_ci_template
CI="$PLUGIN_ROOT/templates/github-workflows/flutter-ci.yml"

if [[ ! -f $CI ]]; then
  fail "templates/github-workflows/flutter-ci.yml exists"
  finish
  exit
fi
pass "templates/github-workflows/flutter-ci.yml exists"
yaml=$(grep -v '^\s*#' "$CI")

# has <label> <fixed string>
has() { grep -qF -- "$2" <<<"$yaml" && pass "$1" || fail "$1" "missing: $2"; }

echo "# triggers and token"
has "runs on pull requests" "pull_request:"
has "runs on pushes to the default branch" "branches: [__DEFAULT_BRANCH__]"
grep -q 'pull_request_target' "$CI" && fail "no pull_request_target (it runs untrusted code with secrets)" \
  || pass "no pull_request_target (it runs untrusted code with secrets)"
has "token is read-only" "contents: read"
grep -qE ':\s*write' <<<"$yaml" && fail "no write permission" "$(grep -nE ':\s*write' "$CI")" || pass "no write permission"
grep -qF 'secrets.' "$CI" && fail "no secret used" "$(grep -nF 'secrets.' "$CI")" || pass "no secret used"
has "checkout does not keep the token in .git/config" "persist-credentials: false"
has "a job timeout caps the minutes spent" "timeout-minutes:"
has "runs on a Linux runner, the cheapest" "runs-on: ubuntu-latest"

echo "# pinned actions"
uses=$(grep -E '^\s*-?\s*uses:' "$CI")
[[ -n $uses ]] && pass "the workflow uses actions" || fail "the workflow uses actions"
while IFS= read -r line; do
  [[ -n $line ]] || continue
  if [[ $line =~ uses:\ [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}\ \#\ v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    pass "pinned by commit SHA with its version: ${line##*uses: }"
  else
    fail "pinned by commit SHA with its version" "$line"
  fi
done <<<"$uses"
has "actions/checkout v7.0.1" "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1"
has "subosito/flutter-action v2.23.0" "subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0"

echo "# Flutter and the quality commands"
has "Flutter version comes from the local one" 'flutter-version: "__FLUTTER_VERSION__"'
has "stable channel" "channel: stable"
for step in "flutter pub get" "dart format --output=none --set-exit-if-changed ." "flutter analyze" "flutter test"; do
  has "step: $step" "run: $step"
done
[[ $(grep -c '__FLUTTER_VERSION__' <<<"$yaml") == 1 ]] && pass "one __FLUTTER_VERSION__ placeholder outside comments" \
  || fail "one __FLUTTER_VERSION__ placeholder outside comments" "$(grep -c '__FLUTTER_VERSION__' <<<"$yaml")"
comments=$(grep '^\s*#' "$CI")
grep -qE '__(FLUTTER_VERSION|DEFAULT_BRANCH)__' <<<"$comments" \
  && fail "comments do not spell the placeholders (the copy would rewrite them)" "$(grep -nE '^\s*#.*__[A-Z_]+__' "$CI")" \
  || pass "comments do not spell the placeholders (the copy would rewrite them)"
grep -q $'\t' "$CI" && fail "no tab (YAML forbids them for indentation)" || pass "no tab (YAML forbids them for indentation)"

finish
