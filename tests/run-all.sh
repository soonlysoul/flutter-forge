#!/usr/bin/env bash
# Deterministic test suite of dart-multiplatform-forge: bash + jq, no network, no Claude session,
# no quota. Usage, from anywhere: bash tests/run-all.sh
# Exit codes: 0 every suite passed, 1 a suite failed, 2 a prerequisite is missing.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

command -v jq >/dev/null 2>&1 || { echo "blocked: jq is required by the test suite and was not found in PATH." >&2; exit 2; }

passed=() failed=() blocked=()

for suite in tests/static/test_*.sh tests/hooks/test_*.sh; do
  printf '\n== %s\n' "$suite"
  if bash "$suite"; then passed+=("$suite"); else failed+=("$suite"); fi
done

# The official validator only checks what its target names: the root is the marketplace
# manifest, plugin.json is the plugin manifest, agents/ and skills/ are the components.
printf '\n== claude plugin validate --strict\n'
if command -v claude >/dev/null 2>&1; then
  for target in . .claude-plugin/plugin.json agents skills; do
    if output=$(claude plugin validate "$target" --strict 2>&1); then
      printf '  ok    %s\n' "$target"
      passed+=("claude plugin validate $target --strict")
    else
      printf '  FAIL  %s\n%s\n' "$target" "$output"
      failed+=("claude plugin validate $target --strict")
    fi
  done
else
  printf '  skip  claude not in PATH\n'
  blocked+=("claude plugin validate (claude not in PATH)")
fi

printf '\n== summary\n'
printf 'passed:  %d\n' "${#passed[@]}"
printf 'failed:  %d\n' "${#failed[@]}"
for item in ${failed[@]+"${failed[@]}"}; do printf '  - %s\n' "$item"; done
printf 'blocked: %d\n' "${#blocked[@]}"
for item in ${blocked[@]+"${blocked[@]}"}; do printf '  - %s\n' "$item"; done
((${#failed[@]} == 0))
