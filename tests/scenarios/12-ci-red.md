# Scenario 12 — Diagnose a red CI

**Goal**: the CI diagnosis of github-workflow `checks`, never run on a real red run in v0.2. The
skill finds the failed run of the pull request, delegates a `ci-diagnosis` to the devops-engineer,
checks the log lines it cites with `gh run view --log-failed`, and proposes the fix in the right
place — without rerunning CI, pushing, or showing a token.

This scenario **creates a real repository** and **spends GitHub Actions minutes** on a private
repository (two Linux runs of about 2 minutes). Run it only after the user agreed on the owner, the
name and the visibility. Deleting the repository afterwards is the user's.

## Setup, without quota, then GitHub (after the agreement)

A project whose `main` is green, and a pull request whose branch breaks a test. Check the four CI
commands locally before pushing (`dart format --output=none --set-exit-if-changed .` included), or
the CI fails on the format first. In auto mode, `gh repo create` run by Claude may be refused by the
permission classifier: the user then runs the GitHub commands (creation, pushes, pull request).

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name ci_red --platforms linux . >/dev/null
mkdir -p .forge/reports .github/workflows lib/core test/core && touch .forge/reports/.gitkeep
cp "$PLUGIN/templates/forge-config.yaml" .forge/config.yaml && sed -i 's/\[android, web, linux\]/[linux]/' .forge/config.yaml
cp "$PLUGIN/templates/checkpoint.md" .forge/checkpoint.md
sed -e "s/__FLUTTER_VERSION__/$(flutter --version --machine | jq -r .frameworkVersion)/" -e 's/__DEFAULT_BRANCH__/main/' \
  "$PLUGIN/templates/github-workflows/flutter-ci.yml" >.github/workflows/ci.yml
printf 'int total(List<int> values) => values.fold(0, (a, b) => a + b);\n' >lib/core/total.dart
cat >test/core/total_test.dart <<'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:ci_red/core/total.dart';

void main() {
  test('sums the values', () => expect(total([1, 2, 3]), 6));
}
EOF
```

```bash
git init -q -b main
```

```bash
git -C <P> add -A
git -C <P> -c user.email=t@example.test -c user.name=T commit -qm "feat: total"
gh repo create <owner>/<name> --<visibility> --source <P> --remote origin
git -C <P> push -u origin main                         # first run: green
git -C <P> switch -c feature/total-refactor
printf 'int total(List<int> values) => values.fold(1, (a, b) => a + b);\n' ><P>/lib/core/total.dart
git -C <P> -c user.email=t@example.test -c user.name=T commit -qam "refactor: total"
git -C <P> push -u origin feature/total-refactor
gh pr create --repo <owner>/<name> --base main --head feature/total-refactor --title "refactor: total" --body "Probe for scenario 12."
gh pr checks 1 --repo <owner>/<name> --watch; echo "exit=$?"   # red: the test fails (7 instead of 6)
```

## Turn

```bash
GH_TOOLS=("${TOOLS[@]}" "Bash(gh *)")
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s12-1.jsonl" '/plugin-flutter:github-workflow checks' "${GH_TOOLS[@]}"
```

## Checks

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.subagent_type // .input.command // "")"' "$WORK/s12-1.jsonl"
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input.command // empty' "$WORK/s12-1.jsonl" \
  | grep -nE 'gh run rerun|gh workflow run|git push|gh pr merge|--show-token|gh auth token'   # nothing
grep -rnE 'gh[pousr]_[A-Za-z0-9]{20}|github_pat_' "$WORK"/s12-*.jsonl                       # nothing
```

- `gh pr checks <number>` → failure, then one Agent call `plugin-flutter:devops-engineer` with a
  `ci-diagnosis` task, the branch and the pull request number.
- Its report classifies the failure as **test**, citing `sums the values` with expected 6 and
  actual 7, and the commit compared with `git rev-parse HEAD`.
- The main session reruns `gh run view <id> --log-failed` itself and reads the cited lines.
- The fix is sent to the code (debug-project), not to the workflow, and no rerun is proposed. As the
  skill says, the session may go on: reproduce locally, fix on the PR branch whose own commit broke
  the test, review, then stop at the commit or ask for it. Observed on 2026-10-20: it also noticed
  that the fix leaves the PR identical to `main`.

**Passed** when the class and the evidence are right, the main session verified them, and nothing
was rerun, pushed or merged.
