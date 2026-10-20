---
name: update-project
description: Update the dependencies or the Flutter SDK of a plugin-flutter project in validated batches — read-only inventory, plan of batches approved by the user, one batch at a time on a chore/deps branch with analysis and tests after each, one commit per batch with its lockfile, and a before/after report. Use when the user asks to update, upgrade or check outdated packages or Flutter in a project that has a .forge/ directory.
argument-hint: "[packages | flutter | <package>]"
---

# Update a project

Address the user in French unless they write in another language. Code, identifiers, commit messages and file contents stay in English.

Request: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of its command.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection: the project's permission rules allow plain commands such as `flutter pub outdated --json`, and a compound command asks for permission, or is refused in a non-interactive run.
- **Two identical failures stop.** If a command fails twice with the same error, stop, write the checkpoint and expose the blocker.
- **Checkpoint after every completed step and every batch**, with `skill: update-project`, the command and its exit code (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`).
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion.
- **Configuration.** Read `.forge/config.yaml` before any external action; a missing key counts as false. Never edit that file.
- **`flutter pub`, never `dart pub`.** In a Flutter project, `dart pub` fails with exit 69 when the `dart` on the PATH is not the Flutter one, as on NixOS.
- **The SDK belongs to the machine.** Never run `flutter upgrade`, `flutter downgrade` or `flutter channel <name>`: they change Flutter for every project on this machine. The user changes it (section "Flutter SDK").
- Never edit `pubspec.lock` by hand, and never add `dependency_overrides` to force a resolution: a conflict goes to the user.
- Never `git stash`, reset or discard anything.

## Step 1 — Repository state

`git status` and `git branch --show-current`. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state. For any other uncommitted change, stop and ask: commit it, move it to a branch, or stop. An update starts from the default branch (`project.default_branch`), or resumes on its own `chore/deps-<slug>` branch.

## Step 2 — Toolchain

`flutter --version --machine`: record `frameworkVersion`, `dartSdkVersion`, `channel` and `flutterRoot`. A `flutterRoot` under `/nix/store/` means Flutter is provided by Nix: say so, since the SDK then changes only through the user's Nix configuration.

If `.github/workflows/ci.yml` exists, read its `flutter-version:` line. A version that differs from the local one is a divergence: CI does not test what runs here. Report it now.

## Step 3 — Baseline

1. `flutter pub get --enforce-lockfile`. Exit 0: the lockfile matches `pubspec.yaml`. Exit 65: it does not, and a plain `flutter pub get` would rewrite it — **validation point**: present that first change on its own. On approval, create the branch of step 6 now, run `flutter pub get`, commit the lockfile alone through the git-workflow skill (`chore(deps): sync pubspec.lock with pubspec.yaml`), then take the baseline below. Exit 1 without `pubspec.lock`: say whether `.gitignore` excludes it (a package often does); the before/after report then compares `pubspec.yaml` constraints only.
2. `flutter analyze`, then `flutter test`. Record each exit code, the issue count and the test summary line: this is the baseline every batch is compared with.

**A red baseline stops** the workflow: an update cannot be judged on a base that already fails. Present the failures and offer two choices: fix them first with the debug-project skill, or go on with these known failures recorded, which the user must say explicitly.

## Step 4 — Inventory

`flutter pub outdated --json`. It changes no file and exits 0 even when packages are outdated. Each entry has `package`, `kind` (`direct`, `dev`, `transitive`), `current`, `upgradable`, `resolvable` and `latest` (each `{version}` or `null`), and the flags `isDiscontinued`, `isCurrentRetracted`, `isCurrentAffectedByAdvisory`. Skip the SDK packages (version `0.0.0`).

Classify each direct and dev dependency:

- **compatible**: `upgradable` is newer than `current` — allowed by the current constraint;
- **major**: `resolvable` is newer than `upgradable` and changes the major version (the minor one below 1.0: `0.13` → `0.14` is breaking) — needs `pubspec.yaml` to change;
- **held back**: `latest` is newer than `resolvable` — another constraint holds it back, often the Flutter SDK; reported, not planned. `flutter pub add --dry-run '<package>:^<latest>'` (`'dev:<package>:^<latest>'` for a dev dependency) names what holds it: it changes no file and exits 65;
- **flagged**: `isCurrentAffectedByAdvisory` (a security advisory), `isCurrentRetracted`, `isDiscontinued` — listed first, whatever their class.

Transitive dependencies are not planned one by one: they move with the batches, and the report counts them.

## Step 5 — Plan of batches

When the request names packages, the plan covers only them and the packages released with them; `flutter` goes to the section "Flutter SDK".

**Validation point.** Present the plan of batches and wait:

- toolchain: local Flutter, the CI pin, Nix or not;
- one table: package | kind | current | target | class | batch | changelog (`https://pub.dev/packages/<package>/changelog` for every major);
- the batches, in order:
  1. flagged packages first, each in its own batch: `flutter pub upgrade <package>` when its constraint allows the fix, `flutter pub upgrade --major-versions <package>` otherwise;
  2. batch "compatible": `flutter pub upgrade` — every dependency within its current constraint, transitive ones included;
  3. one batch per major: `flutter pub upgrade --major-versions <package>`. Packages released together go in one batch (`riverpod` with `flutter_riverpod`, a plugin with its `_platform_interface`). Dev dependencies such as lints first: they change the analysis, not the app;
- what each major may require: code changes in the files that import it, done inside its batch;
- the held-back packages and what holds them;
- the branch name, `chore/deps-<slug>`, such as `chore/deps-2026-10` or `chore/deps-go-router-18`.

The user approves all batches, some of them, or none. A major is applied only if its batch is approved.

## Step 6 — Branch

Through the git-workflow skill: `git switch -c chore/deps-<slug>` from the default branch.

## Step 7 — One batch at a time

For each approved batch, in order:

1. Run its command: `flutter pub upgrade`, or `flutter pub upgrade --major-versions <package> [<package>]`. The project rules ask for confirmation. Record the changed lines of its output (`> package new (was old)`).
2. `git status --short`. Expected, besides the workflow state (`.forge/checkpoint.md`, `.forge/reports/`): `pubspec.lock`; `pubspec.yaml` for a major; the generated plugin registrants when the set of plugins changed (`linux/flutter/generated_plugin_registrant.cc`, `linux/flutter/generated_plugins.cmake`, their `windows/` equivalents, `macos/Flutter/GeneratedPluginRegistrant.swift`). Any other file: stop and report it.
3. For a major: find the package's `rootUri` in `.dart_tool/package_config.json` and read the `CHANGELOG.md` there, from the old version to the new one. List the breaking changes. Find the project's uses with Grep (`package:<package>/`) and check each breaking change against them. For a Flutter plugin, read the `flutter: plugin: platforms:` section of its `pubspec.yaml` there and compare it with `platforms.enabled`: a platform that is no longer supported stops the batch — **validation point**.
4. `flutter analyze`, then `flutter test`. Both must exit 0, or be no worse than the baseline the user accepted. Record both results for the report.
   - After a major, migrate the code that uses the package, in the files that import it: fix, then rerun both, at most three iterations. A change outside those files — another feature, a platform folder, `analysis_options.yaml` — is a **validation point**.
   - After any other batch, a new failure is unexpected: find its cause with the method of the debug-project skill before changing anything.
5. A batch that stays red is not committed: report it and ask whether to drop it. Dropping restores every file the batch changed, as `git status --short` lists them apart from the workflow state: `pubspec.yaml`, `pubspec.lock`, the registrants, and the code migrated at sub-step 4. That is a `git restore`, which the guard-destructive hook blocks for Claude: give the user `! git restore pubspec.yaml pubspec.lock <other files the batch changed>`, and `! rm <file>` for a file the batch created. Then check that `git status --short` lists only the workflow state and that `flutter pub get --enforce-lockfile` exits 0, and rerun `flutter analyze` and `flutter test` to compare them with the baseline.
6. For a major, when `docs/engineering/DECISIONS.md` exists: add `ADR-<n> — Upgrade <package> to <version>`, status `proposed`, with the breaking changes that touched the code and the platforms checked.
7. Stage the batch's files explicitly through the git-workflow skill — `pubspec.yaml`, `pubspec.lock`, the registrants, migrated code, the ADR — and commit, one commit per batch:

   ```
   chore(deps): upgrade <package> to <version>

   <package>: <old> -> <new>
   Breaking changes handled: <list, or none>
   ```

   For the compatible batch: `chore(deps): upgrade compatible dependencies`, with the direct dependencies that moved in the body. The commit asks for confirmation.

## Flutter SDK

When the user asks to update Flutter, or when packages are held back by the SDK:

1. **Validation point.** Say what changes and who does it. With Flutter from Nix (`flutterRoot` under `/nix/store/`), the version comes from the user's Nix configuration — a flake input, a Home Manager or NixOS package — and they update it there, outside this project. Otherwise the user runs `! flutter upgrade` themselves, knowing it changes Flutter for every project on this machine. Wait until they say it is done.
2. `flutter --version --machine` again: record the new version. If it did not change, say so and stop.
3. `flutter pub get` (the SDK pins some packages, so the lockfile may change), `flutter analyze`, `flutter test`, and `dart format --output=none --set-exit-if-changed .` (the formatter's style follows the SDK, and CI checks it), compared with the baseline.
4. CI pins Flutter: the `flutter-version:` line of `.github/workflows/ci.yml` must become the new version, or CI keeps testing the old one. Propose that one-line change; the plugin asks the user to confirm writes to `.github/workflows/`. If the write is refused, do not write the file another way: give the user `! sed -i 's/flutter-version: "<old>"/flutter-version: "<new>"/' .github/workflows/ci.yml`.
5. Commit through git-workflow: `chore(deps): build with Flutter <version>`, with `pubspec.lock` and the CI file. Then run `flutter pub outdated --json` again: packages held back by the old SDK may now be resolvable; offer a new plan.

## Step 8 — Before/after report

1. `flutter pub outdated --json --show-all`: its `current` column gives the "after" of every direct and dev dependency, updated ones included (without `--show-all`, an up-to-date package is left out); a newer `latest` marks what was not updated.
2. `git diff <default branch> -- pubspec.lock`: count the changed `version:` lines, the direct dependencies apart, for the transitive changes. `git log --oneline <default branch>..HEAD` for the batch commits.
3. Write `.forge/reports/deps-<YYYY-MM-DD>-<slug>.md` from `${CLAUDE_PLUGIN_ROOT}/skills/update-project/reference/deps-report.md`: toolchain before and after, batches with their commits, versions before and after, packages not updated and why, analysis and tests at the baseline and after the last batch, breaking changes handled.
4. Commit the report with the updated checkpoint through git-workflow: `docs(deps): report the dependency update`.

## Final report

- Branch, batches done (commit, packages before → after), dropped and not planned, with the reason.
- Toolchain: Flutter before and after; the CI pin, and whether it must change.
- Tests in four categories, each with its command; write "none" for an empty category:
  - **passed**;
  - **failed**;
  - **blocked**, with the reason;
  - **not run**.
- Analysis at the baseline and after; the path of the report.
- Next step: push the branch and open the pull request with `/plugin-flutter:github-workflow pr`, so that CI checks the update too.
