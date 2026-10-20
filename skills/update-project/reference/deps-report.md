# Dependency update — <YYYY-MM-DD>

| | |
| --- | --- |
| Branch | chore/deps-<slug> |
| Base | <default branch> at <short hash> |
| Flutter | before <version> (<channel>, Nix: yes/no) → after <version> |
| Dart | before <version> → after <version> |
| CI pin | `flutter-version` in .github/workflows/ci.yml: <version>, must change: yes/no — or "no CI" |
| Lockfile | pubspec.lock committed: yes / no (ignored by .gitignore) |

## Batches

| # | Command | Packages | Commit | analyze | test | Result |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `flutter pub upgrade` | compatible updates | <short hash> | exit <code>, <n> issues | exit <code>, <summary> | done / dropped (reason) |
| 2 | `flutter pub upgrade --major-versions <package>` | <package> | <short hash> | exit <code>, <n> issues | exit <code>, <summary> | done / dropped (reason) |

## Direct and dev dependencies

| package | kind | before | after | type | batch |
| --- | --- | --- | --- | --- | --- |
| <package> | direct / dev | <version> | <version> | patch / minor / major / unchanged | <n> |

Transitive dependencies changed: <n> (changed `version:` lines of `git diff <default branch> -- pubspec.lock`, direct dependencies excluded).

## Not updated

| package | current | latest | why |
| --- | --- | --- | --- |
| <package> | <version> | <version> | held back by <constraint or SDK> / not approved / dropped (reason) |

## Checks

| check | before (baseline) | after |
| --- | --- | --- |
| `flutter pub get --enforce-lockfile` | exit <code> | exit <code> |
| `flutter analyze` | exit <code>, <n> issues | exit <code>, <n> issues |
| `flutter test` | exit <code>, <summary line> | exit <code>, <summary line> |

## Breaking changes handled

- <package> <version>: <change> — <file changed, or "no use in this project">

## Flags

- <package>: advisory / retracted / discontinued — <action taken>, or "none"
