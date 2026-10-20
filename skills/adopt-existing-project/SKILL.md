---
name: adopt-existing-project
description: Take over an existing Flutter app with plugin-flutter — read-only analysis first, then a compliance plan the user approves item by item, and only then the .forge/ state directory, documents rebuilt from the code in DRAFT, and the list of divergences between the documents and the code. Use when the user wants plugin-flutter on a Flutter app that already exists and has no .forge/ directory yet; not for a new app, which is bootstrap-project.
---

# Adopt an existing project

Address the user in French unless they write in another language. Code, identifiers and file contents stay in English.

## Rules

- **Nothing existing is rewritten without an approved plan.** Steps 1 to 4 are read-only: no file is created, changed or deleted, no branch, no commit. There is no checkpoint before step 5, since `.forge/` does not exist yet: the analysis presented at step 4 is the state.
- **No pub get during the analysis.** Before the plan is approved, never run `flutter pub get`, `flutter analyze` or `flutter test` without `--enforce-lockfile` or `--no-pub`: a plain one runs `pub get`, which rewrites a `pubspec.lock` that does not match `pubspec.yaml`.
- **Never move code.** No file of the app is moved, renamed, reformatted or fixed by this skill: those are later, separate changes.
- **No result without its command.** Never report a step as done without the output of its command.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection.
- **Two identical failures stop.** If a command fails twice with the same error, stop and expose the blocker.
- **Validation points.** Ask in plain text, end your turn and wait; from step 5 on, write the checkpoint first. Do not use AskUserQuestion.
- **`flutter pub`, never `dart pub`**, which fails with exit 69 when the `dart` on the PATH is not the Flutter one.
- Never display a secret: a file that holds one is named, never read out. Never `git stash`, reset or discard anything.

## Step 1 — Prerequisites

1. Read `pubspec.yaml` at the project root, `${CLAUDE_PROJECT_DIR}`. Without it, or when it does not depend on `flutter` (`sdk: flutter`), stop: this is not a Flutter app at the root. If the app is in a subdirectory, stop and ask the user to start Claude Code again in that directory: the hooks and the agents' write limits use the launch directory as the project root.
2. If `.forge/` exists, the project is already adopted: stop and offer the recover-session or create-feature skill.
3. `git rev-parse --show-toplevel`. Outside a Git repository, note it: the plan will start with `git init -b main`.
4. `flutter --version --machine`: record `frameworkVersion` and `flutterRoot` (a root under `/nix/store/` means Flutter comes from Nix).

## Step 2 — Read-only analysis

Run `git status --porcelain` first and keep its output: it is the reference that proves, at the end of this step, that nothing changed.

- **Git**: `git branch --show-current`, `git log --oneline -20`, `git remote -v`. Uncommitted changes belong to the user: list them; the plan touches none of their files.
- **Identity and dependencies**: from `pubspec.yaml`, the name, description, version, `environment` constraints, dependencies and dev dependencies. `git ls-files pubspec.lock` says whether the lockfile is versioned.
- **Platforms**: which of `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` exist (Glob).
- **Code**: Glob `lib/**/*.dart`. The layout (feature-first `lib/features/<feature>/{data,domain,presentation}`, or another one), and the state management and navigation from the imports (Grep `package:flutter_riverpod`, `package:provider`, `package:flutter_bloc`, `package:go_router`, …).
- **Tests**: Glob `test/**/*_test.dart` and `integration_test/`; count them; Grep the acceptance criterion ids they cite (`AC-[0-9]+`).
- **Documents**: README, CHANGELOG, `CLAUDE.md`, everything under `docs/`, and any specification found elsewhere.
- **Configuration**: `analysis_options.yaml` (lints, strict modes), `.gitignore` (`.env*`, `*.jks`, `*.keystore`, `key.properties`), `.github/workflows/` (the `flutter-version` pinned), `.claude/settings.json`.
- **Secrets**: `git ls-files` for tracked `.env*`, `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.pfx`. Name them; never open them.
- **Baseline**:
  1. `flutter pub get --enforce-lockfile`. Exit 0: the dependencies resolve exactly as locked, and only ignored files are written (`.dart_tool/`, `.flutter-plugins-dependencies`, `*/flutter/ephemeral/`). Exit 65: the lockfile is stale. Exit 1 without `pubspec.lock`: nothing to enforce. In both cases, the analysis and the tests below are **not run**, with that reason, and resolving becomes a plan item.
  2. `flutter analyze --no-pub`: exit code and issue count.
  3. `flutter test --no-pub`, with a Bash timeout of 600000 ms: exit code and summary line.

Then `git status --porcelain` again: it must be identical to the reference. Resolution can regenerate a tracked plugin registrant (`linux/flutter/generated_plugin_registrant.cc`, …) when it was out of date: if any tracked file changed, stop, name it, and let the user decide — keep it, or `! git restore <file>`.

## Step 3 — Divergences

Compare what the documents say with what the code does, with the checklist in `${CLAUDE_PLUGIN_ROOT}/skills/adopt-existing-project/reference/divergences.md`. Each divergence has its category, the evidence on both sides (document and line, code file and line, or command output), a severity and a proposed action. Report them; fix none. Without any document, the divergences are measured against the plugin's conventions only.

## Step 4 — Compliance plan

**Validation point.** Present the analysis in at most fifteen lines — toolchain, platforms, layout, dependencies, tests and analysis at the baseline, documents found, divergences by category — then the compliance plan as numbered items. Each item names its file, its action (create, modify with the diff shown, keep) and why:

1. Branch `chore/adopt-plugin-flutter` from the current branch (after `git init -b main` when there is no repository).
2. `.forge/config.yaml` from `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml`, with `project.default_branch` set to the current default branch and `platforms.enabled` to the platform folders found; `.forge/reports/.gitkeep`; `.forge/checkpoint.md`.
3. Documents, at the plugin's paths, only where absent, all DRAFT:
   - `docs/product/PRD.md`, rebuilt from the code by the product-architect agent;
   - `docs/technical/TRD.md` and `docs/engineering/DECISIONS.md`, rebuilt by the flutter-architect agent: the stack as it is, one ADR per direct dependency, status `proposed`;
   - `docs/engineering/IMPLEMENTATION_PLAN.md`: the features found, "done (pre-existing)" with their tests, or "untested".
   An existing document is kept, never replaced, and the new one links to it under "Related documents".
4. Existing files to modify, each with its diff, **approved separately**: `CLAUDE.md` (a plugin-flutter section appended from `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/CLAUDE.md`; created only when absent), `.gitignore` (the missing secret patterns appended), `analysis_options.yaml` (the strict modes of bootstrap-project; say they may surface many new issues, and recommend a later, separate change).
5. `.claude/settings.json`: the rules of `${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json`, summarized; an existing file is merged, with the merge shown.
6. The divergence list: `.forge/reports/divergences-<YYYY-MM-DD>.md`.
7. Not in this plan, and the skill for each: resolving a stale lockfile and updating dependencies (update-project), failing tests (debug-project), CI (github-workflow `ci`), code layout (create-feature, one feature at a time).

The user approves all items, some of them, or none. An approval covers exactly what its item says.

## Step 5 — Apply the approved items

In this order, and only the approved items:

1. The branch, through the git-workflow skill.
2. `.forge/config.yaml` first: once `.claude/settings.json` exists, its deny rule `Edit(./.forge/config.yaml)` stops Claude from writing it. Then `.forge/reports/.gitkeep`, and `.forge/checkpoint.md` from `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`, with `skill: adopt-existing-project` and steps 1 to 5 recorded. From here on, update the checkpoint after every completed step.
3. The documents. Record `git status --porcelain`, then delegate to the product-architect agent: task `reconstruct`, with the paths to read (`lib/`, `test/`, the README, the existing documents) and the analysis of step 2. Wait for its report, and check that it changed only files under `docs/product/`. Then delegate the TRD and DECISIONS.md to the flutter-architect agent, with the same paths, the dependency list and `platforms.enabled`; wait, and check that it changed only files under `docs/`. Agents run one after the other. Then write IMPLEMENTATION_PLAN.md yourself, from the reconstructed criteria and the tests found.
4. Each approved modification of an existing file: exactly the diff shown, nothing more.
5. `.claude/settings.json`, if approved. Claude Code protects its configuration files, and a non-interactive run denies the write: do not work around it; give the user `! mkdir -p .claude && cp ${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json .claude/settings.json`, or the merged file to write.
6. `.forge/reports/divergences-<YYYY-MM-DD>.md`, in the format of the checklist.
7. Checks: `git status --porcelain` lists only the new files and the approved modifications. When the baseline ran, `flutter analyze --no-pub` and `flutter test --no-pub` give the same results as at step 2, except for the analysis issues the strict modes add when that item was approved; any other difference stops the workflow.

No document is approved by this skill: create-feature needs the PRD and the TRD APPROVED, which the user does later, explicitly.

## Step 6 — Commit and report

Stage the files explicitly through the git-workflow skill — never `git add -A` — and commit `chore: adopt plugin-flutter`, with the created and modified files in the body. The commit asks for confirmation.

Final report:

- What was created, modified (with its approval) and kept; the branch and the commit.
- The divergences by category, and the path of the list.
- Baseline tests and analysis, in four categories, each with its command; write "none" for an empty category:
  - **passed**;
  - **failed**;
  - **blocked**, with the reason;
  - **not run**, with the reason (stale or missing lockfile).
- Next steps: review and approve the PRD and the TRD; then the skills named by the plan's item 7.
