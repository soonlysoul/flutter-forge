# Scenario 6 — Adopt an existing app without rewriting anything

**Goal**: on an existing Flutter app without `.forge/`, adopt-existing-project analyzes in
read-only mode, stops at the compliance plan without having changed a single file, and after a
partial approval applies only the approved items: `.forge/`, documents rebuilt from the code in
DRAFT, the list of divergences. The README and the existing `CLAUDE.md` stay byte for byte the
same.

## Setup, without quota

An app whose README contradicts the code: it claims Android and iOS (only `linux/` exists) and
Flutter 3.30 (the machine has another version). It has a dependency that no document mentions,
and an existing `CLAUDE.md`. Run the blocks one by one, with `$P` replaced by its literal path
when Claude runs them (secret-scan cannot resolve a directory held in a variable, and refuses
`git init` on the line of a commit).

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name notes_app --platforms linux . >/dev/null
flutter pub add http >/dev/null
mkdir -p lib/core test/core
cat >lib/core/greeting.dart <<'EOF'
String greet(String name) => 'Hello, $name!';
EOF
cat >test/core/greeting_test.dart <<'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/core/greeting.dart';

void main() {
  test('greets by name', () => expect(greet('Ada'), 'Hello, Ada!'));
}
EOF
printf '# notes_app\n\nA notes app for Android, iOS and Linux. Requires Flutter 3.30.\n' >README.md
printf '# Conventions\n\nKeep widgets small.\n' >CLAUDE.md
```

```bash
git init -q -b main
```

```bash
git -C <P> add -A
git -C <P> -c user.email=t@example.test -c user.name=T commit -qm "feat: notes app"
git -C <P> ls-files -z | (cd <P> && xargs -0 sha256sum) >"$WORK/s6-tracked.sha"
```

## Turns

1. Analysis and plan.

   ```bash
   SID=$(uuidgen)
   "$H" "$P" "$SID" new "$WORK/s6-1.jsonl" '/plugin-flutter:adopt-existing-project' "${TOOLS[@]}"
   ```

   Expected: a stop at step 4, with the analysis and a numbered plan. Before answering, check that
   nothing changed:

   ```bash
   git -C "$P" status --porcelain --untracked-files=all   # empty
   (cd "$P" && sha256sum --quiet -c "$WORK/s6-tracked.sha") && echo unchanged
   test ! -e "$P/.forge" && echo "no .forge yet"
   jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // "")"' "$WORK/s6-1.jsonl"
   ```

   No Write, Edit or Agent call; `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`
   and `flutter test --no-pub`, never their plain forms.

2. Partial approval.

   ```bash
   "$H" "$P" "$SID" resume "$WORK/s6-2.jsonl" "J'approuve les items 1, 2, 3 et 6 du plan. Je refuse les items 4 et 5 : ne touche ni à CLAUDE.md, ni à .gitignore, ni à analysis_options.yaml, ni à .claude/. main est bien la branche par défaut." "${TOOLS[@]}"
   ```

   The project has no remote: the plan asks to confirm the default branch, so the answer does.

   In `-p`, protect-sensitive refuses the write of `.forge/config.yaml`: the skill must stop and
   give a `! mkdir -p .forge && sed … > .forge/config.yaml` command instead of writing the file
   another way. Run it yourself, as the user, then go on:

   ```bash
   "$H" "$P" "$SID" resume "$WORK/s6-3.jsonl" "C'est fait, .forge/config.yaml existe. Continue." "${TOOLS[@]}"
   ```

## Checks

```bash
git -C "$P" branch --show-current                              # chore/adopt-plugin-flutter
git -C "$P" log --oneline main..HEAD                           # chore: adopt plugin-flutter (or the commit prepared)
git -C "$P" diff --name-status main...HEAD; git -C "$P" status --porcelain   # only added files (A or ??)
(cd "$P" && sha256sum --quiet -c "$WORK/s6-tracked.sha") && echo "every pre-existing file unchanged"
grep -n 'enabled' "$P/.forge/config.yaml"                      # [linux]
grep -n 'Status' "$P"/docs/product/PRD.md "$P"/docs/technical/TRD.md   # DRAFT
grep -n 'reconstructed' "$P/docs/product/PRD.md"
grep -n 'http' "$P/docs/engineering/DECISIONS.md"              # an ADR, status proposed
ls "$P"/.forge/reports/divergences-*.md && grep -niE 'android|ios|3\.30' "$P"/.forge/reports/divergences-*.md
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Agent") | .input.subagent_type' "$WORK/s6-2.jsonl"
```

- The product-architect (task `reconstruct`) and the flutter-architect run one after the other.
- `README.md` and `CLAUDE.md` are unchanged; no `.claude/settings.json`, no change to `.gitignore`
  or `analysis_options.yaml`.
- The divergences list at least: platforms (Android and iOS claimed, only `linux/`), toolchain
  (3.30 claimed), and the missing documentation of `http`.

**Passed** when turn 1 changed nothing and turn 2 added only the approved files. A commit denied by
the permission layer counts as passed if the skill prepared it and reported the denial.
