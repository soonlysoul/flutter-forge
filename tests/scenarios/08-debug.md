# Scenario 8 — Debug a failing test

**Goal**: on a test that fails unexpectedly, debug-project reproduces it, states the root cause
with its evidence before any fix, keeps the existing failing test as the regression test, fixes
the minimum on a `fix/` branch, reruns the full checks, has the fix reviewed, and does not touch
files outside the scope.

## Setup, without quota

A small project with `.forge/` and a bug: the discount subtracts the percentage as an amount.

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name shop --platforms linux . >/dev/null
git init -q -b main && git config user.email t@example.test && git config user.name T
mkdir -p .forge/reports lib/core test/core && touch .forge/reports/.gitkeep
cp "$PLUGIN/templates/forge-config.yaml" .forge/config.yaml && sed -i 's/\[android, web, linux\]/[linux]/' .forge/config.yaml
cat >lib/core/pricing.dart <<'EOF'
double applyDiscount(double price, int percent) => price - percent;
EOF
cat >test/core/pricing_test.dart <<'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/core/pricing.dart';

void main() {
  test('no discount keeps the price', () => expect(applyDiscount(80, 0), 80));
  test('10 percent off 200 is 180', () => expect(applyDiscount(200, 10), 180));
}
EOF
git add -A && git commit -qm "chore: shop with pricing"
flutter test test/core/pricing_test.dart; echo "exit=$?"     # exit=1: Expected 180, Actual 190
sha256sum lib/main.dart >"$WORK/s8-main.sha"
```

## Session level

```bash
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s8-1.jsonl" '/plugin-flutter:debug-project "flutter test test/core/pricing_test.dart fails since the last commit"' "${TOOLS[@]}"
```

A second turn (`resume`) only if the skill stopped at a validation point; answer it as a user would.

## Checks

```bash
git -C "$P" branch --show-current                  # fix/<slug>
git -C "$P" log --oneline main..HEAD               # one fix(...) commit, or the commit denied by the ask rule
git -C "$P" diff --name-only main...HEAD           # lib/core/pricing.dart, .forge/checkpoint.md, maybe test/core/pricing_test.dart
sha256sum -c "$WORK/s8-main.sha"                   # lib/main.dart untouched
grep -n 'skill: debug-project' "$P/.forge/checkpoint.md"
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // .input.subagent_type // "")"' "$WORK/s8-1.jsonl"
```

- The failing command runs **before** any edit of `lib/`; the root cause is stated in a message
  before the first edit.
- The existing test `10 percent off 200 is 180` is the regression test: not duplicated.
- After the fix: the targeted test, then `flutter test`, `dart format --set-exit-if-changed .` and
  `flutter analyze`, each with its exit code in the checkpoint.
- The code-reviewer agent is called on `git diff --cached main`.
- The commit message is `fix(...)` and its body states the root cause.

**Passed** when every check holds. A commit denied by the permission layer counts as passed if the
skill prepared it and reported the denial.
