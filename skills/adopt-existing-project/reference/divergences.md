# Divergences — <App name> — <YYYY-MM-DD>

Read-only comparison of the documents with the code, made when plugin-flutter adopted the app.
Nothing listed here was fixed by the adoption.

## Checklist

| Category | Documents say | Code shows |
| --- | --- | --- |
| dependencies | a package named in the README, the TRD or DECISIONS.md | `pubspec.yaml`: a direct dependency without an ADR, or a documented package that is absent |
| acceptance criteria | a criterion in a specification or the PRD | no test cites its id; or a test cites an id that no document defines |
| plan | a feature marked done or planned | no code for it; or code for a feature that no plan lists |
| README | the features, commands, platforms or setup it describes | what `lib/`, the platform folders and `pubspec.yaml` contain |
| platforms | the platforms the documents or the CI claim | the platform folders present |
| toolchain | the Flutter version in the README, the CI (`flutter-version`) or the `environment` constraints | the local `flutter --version` |
| lockfile | an app is expected to version `pubspec.lock` | not versioned, or stale (`flutter pub get --enforce-lockfile` → exit 65) |
| layout | plugin-flutter's feature-first layout | the actual layout of `lib/` (a note, never a reason to move code) |
| analysis | `analysis_options.yaml` | issues at the baseline (`flutter analyze --no-pub`); strict modes missing |
| tests | tests are expected for each feature | no tests, or tests failing at the baseline (`flutter test --no-pub`) |
| secrets | `.gitignore` excludes secrets | `.env*`, keystores or `key.properties` tracked, or patterns missing from `.gitignore` |

Severity: **blocking** (a workflow of plugin-orchestrator or plugin-flutter cannot run until it is resolved), **to fix** (wrong or misleading), **note** (a difference of convention).

## Divergences

| # | category | documents say | code shows | severity | action |
| --- | --- | --- | --- | --- | --- |
| 1 | <category> | <document:line — claim, or "no document"> | <file:line or command — fact> | blocking / to fix / note | <skill or change proposed> |

## Not checked

- <what could not be checked, and why — for example "tests: not run, stale lockfile">
