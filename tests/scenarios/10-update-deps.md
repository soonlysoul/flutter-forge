# Scenario 10 — Update a batch of dependencies (exit criterion of v0.3)

**Goal**: update-project inventories the outdated dependencies without changing a file, stops at
the plan of batches, then applies only the approved batches on a `chore/deps-` branch — analysis
and tests after each, one commit per batch with its lockfile — and writes the before/after report.
It never runs `flutter upgrade` nor `dart pub`, and says that Flutter comes from Nix.

This scenario downloads packages from pub.dev.

## Setup, without quota

The versions of phase A: pinned old, then constraints relaxed, so that `flutter pub get` keeps
them locked. `http` 0.13 → 1.x is a real major; the code uses its testing client. Run the blocks
one by one, `<P>` being the literal path.

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name deps_app --platforms linux . >/dev/null
sed -i 's/^  cupertino_icons: \^1.0.8$/  cupertino_icons: ^1.0.8\n  http: 0.13.6\n  equatable: 2.0.5\n  shared_preferences: 2.2.0\n  go_router: 12.0.0/' pubspec.yaml
flutter pub get >/dev/null
sed -i -e 's/^  http: 0.13.6$/  http: ^0.13.6/' -e 's/^  equatable: 2.0.5$/  equatable: ^2.0.5/' \
  -e 's/^  shared_preferences: 2.2.0$/  shared_preferences: ^2.2.0/' -e 's/^  go_router: 12.0.0$/  go_router: ^12.0.0/' pubspec.yaml
flutter pub get >/dev/null
mkdir -p lib/core test/core .forge/reports docs/engineering && touch .forge/reports/.gitkeep
cat >lib/core/title_client.dart <<'EOF'
import 'package:http/http.dart' as http;

Future<String> fetchTitle(http.Client client, Uri uri) async => (await client.get(uri)).body.trim();
EOF
cat >test/core/title_client_test.dart <<'EOF'
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:deps_app/core/title_client.dart';

void main() {
  test('reads the title from the body', () async {
    final client = MockClient((_) async => http.Response(' Notes \n', 200));
    expect(await fetchTitle(client, Uri.parse('https://example.test')), 'Notes');
  });
}
EOF
cp "$PLUGIN/templates/forge-config.yaml" .forge/config.yaml && sed -i 's/\[android, web, linux\]/[linux]/' .forge/config.yaml
cp "$PLUGIN/templates/checkpoint.md" .forge/checkpoint.md
cp "$PLUGIN/skills/bootstrap-project/reference/doc-templates/DECISIONS.md" docs/engineering/DECISIONS.md
dart format lib test >/dev/null                                 # the baseline checks the format too
flutter test; echo "exit=$?"                                    # exit=0
dart format --output=none --set-exit-if-changed .; echo "exit=$?"   # exit=0
```

```bash
git init -q -b main
```

```bash
git -C <P> add -A
git -C <P> -c user.email=t@example.test -c user.name=T commit -qm "chore: deps_app with old dependencies"
sha256sum <P>/pubspec.yaml <P>/pubspec.lock >"$WORK/s10-pub.sha"
```

## Turns

1. Inventory and plan.

   ```bash
   SID=$(uuidgen)
   "$H" "$P" "$SID" new "$WORK/s10-1.jsonl" '/plugin-flutter:update-project' "${TOOLS[@]}"
   ```

   Expected: `flutter --version --machine` (Nix said), `flutter pub get --enforce-lockfile`,
   baseline `flutter analyze` and `flutter test`, `flutter pub outdated --json`, then the plan:
   the compatible batch (`equatable` 2.1.x, `go_router` 12.1.x, `shared_preferences` 2.5.x), and a
   batch per major (`http` 1.x, `go_router`, `equatable`, `cupertino_icons`), each with its
   changelog link. Before answering:

   ```bash
   sha256sum -c "$WORK/s10-pub.sha"; git -C "$P" status --porcelain; git -C "$P" branch --show-current   # OK, only ` M .forge/checkpoint.md`, main
   ```

2. Approve two batches only.

   ```bash
   "$H" "$P" "$SID" resume "$WORK/s10-2.jsonl" "J'approuve le lot compatible et la majeure http. Pas les autres majeures." "${TOOLS[@]}"
   ```

   A third turn only if the skill stops at a validation point it did not announce; answer it as a
   user would.

## Checks

```bash
git -C "$P" branch --show-current                      # chore/deps-<slug>
git -C "$P" log --oneline main..HEAD                   # chore(deps): compatible, chore(deps): http, docs(deps): report
git -C "$P" show --stat HEAD~2 HEAD~1                  # pubspec.lock (and pubspec.yaml for http)
grep -nE '^  (http|go_router|equatable):' "$P/pubspec.yaml"   # http: ^1.x ; go_router ^12 ; equatable ^2
grep -n -A1 '^  go_router:' "$P/pubspec.lock"          # 12.1.x, not a new major
ls "$P"/.forge/reports/deps-*.md && grep -n '| http |' "$P"/.forge/reports/deps-*.md
grep -n 'Upgrade http' "$P/docs/engineering/DECISIONS.md"
git -C "$P" status --porcelain                        # empty: the report commit carries the final checkpoint (D42)
grep -rn '/home/' "$P"/docs "$P"/.forge             # nothing: no path of this machine
(cd "$P" && flutter test); echo "exit=$?"              # exit=0
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input.command // empty' "$WORK"/s10-*.jsonl \
  | grep -nE 'flutter upgrade|flutter downgrade|flutter channel|dart pub|dependency_overrides'   # nothing
```

**Passed**, and exit criterion of v0.3 met, when the two approved batches are committed with their
lockfile, the tests pass after each, the unapproved majors are untouched, and the report gives the
versions, the analysis and the tests before and after. A commit denied by the permission layer
counts as passed if the skill prepared it and reported the denial.
