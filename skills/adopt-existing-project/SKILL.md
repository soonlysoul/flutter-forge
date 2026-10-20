---
name: adopt-existing-project
description: Take over an existing Flutter app with plugin-flutter — read-only analysis first, then a compliance plan the user approves item by item, and only then the .forge/ state directory, documents rebuilt from the code in DRAFT, and the list of divergences between the documents and the code. Use when the user wants plugin-flutter on a Flutter app that already exists and has no .forge/ directory yet; not for a new app, which is bootstrap-project.
---

# Adopt an existing project

Address the user in French unless they write in another language. Code, identifiers and file contents stay in English.

## Rules

- **Nothing existing is rewritten without an approved plan.** Steps 1 to 4 are read-only: no file is created, changed or deleted, no branch, no commit. There is no checkpoint before step 5, since `.forge/` does not exist yet: the analysis presented at step 4 is the state.
- **No pub get during the analysis.** Before the plan is approved, never run `flutter pub get` without `--enforce-lockfile`, nor `flutter analyze` or `flutter test` without `--no-pub`: a plain one runs `pub get`, which rewrites a `pubspec.lock` that does not match `pubspec.yaml`. `flutter pub deps` rewrites it too: it runs, here or in an agent, only once `flutter pub get --enforce-lockfile` has exited 0.
- **Never move code.** No file of the app is moved, renamed, reformatted or fixed by this skill: those are later, separate changes.
- **No result without its command.** Never report a step as done without the output of its command.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection.
- **Two identical failures stop.** If a command fails twice with the same error, stop and expose the blocker.
- **Validation points.** Ask in plain text, end your turn and wait; from step 5 on, write the checkpoint first. Do not use AskUserQuestion.
- **`flutter pub`, never `dart pub`**, which fails with exit 69 when the `dart` on the PATH is not the Flutter one.
- Never display a secret: a file that holds one is named, never read out. Never `git stash`, reset or discard anything.

## Step 1 — Prerequisites

1. Read `pubspec.yaml` at the project root, `${CLAUDE_PROJECT_DIR}`. Without it, or when it does not depend on `flutter` (`sdk: flutter`), stop: this is not a Flutter app at the root. If the app is in a subdirectory, stop and ask the user to start Claude Code again in that directory: the hooks and the agents' write limits use the launch directory as the project root.
2. If `.forge/` exists and `.forge/checkpoint.md` names `skill: adopt-existing-project` with steps left, the adoption was interrupted: resume from its next action, with the plan items approved and the baseline of step 2 recorded there; change nothing else. If `.forge/` exists otherwise, the project is already adopted: stop and offer the recover-session or create-feature skill.
3. `git rev-parse --show-toplevel`. Outside a Git repository, stop: the first commit of an existing tree is the user's. They check it for secrets, run `git init -b main` and commit it themselves; then this skill runs again.
4. `git status --porcelain --untracked-files=all`. Any uncommitted change stops the adoption: the user commits it or sets it aside themselves, so that the adoption never mixes with their work.
5. The default branch: `git rev-parse --abbrev-ref origin/HEAD` names the remote's (`origin/main`), and only exit 0 counts: on failure it still prints `origin/HEAD`. Without a remote, or when it fails, propose the current branch, which the plan asks the user to confirm. If the current branch is not the default branch, stop and ask the user to switch to it: the adoption describes the default branch.
6. `flutter --version --machine`: record `frameworkVersion` and `flutterRoot` (a root under `/nix/store/` means Flutter comes from Nix).

## Step 2 — Read-only analysis

The clean `git status --porcelain --untracked-files=all` of step 1 is the reference that proves, at the end of this step, that nothing changed.

- **Git**: `git log --oneline -20`, `git remote -v`.
- **Identity and dependencies**: from `pubspec.yaml`, the name, description, version, `environment` constraints, dependencies and dev dependencies. `git ls-files pubspec.lock` says whether the lockfile is versioned.
- **Platforms**: which of `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` exist (Glob).
- **Code**: Glob `lib/**/*.dart`. The layout (feature-first `lib/features/<feature>/{data,domain,presentation}`, or another one), and the state management and navigation from the imports (Grep `package:flutter_riverpod`, `package:provider`, `package:flutter_bloc`, `package:go_router`, …).
- **Tests**: Glob `test/**/*_test.dart` and `integration_test/`; count them; Grep the acceptance criterion ids they cite (`AC-[0-9]+`).
- **Documents**: README, CHANGELOG, `CLAUDE.md`, everything under `docs/`, and any specification found elsewhere.
- **Configuration**: `analysis_options.yaml` (lints, strict modes), `.gitignore` (`.env*`, `*.jks`, `*.keystore`, `key.properties`), `.github/workflows/` (the `flutter-version` pinned), `.claude/settings.json`.
- **Secrets**: `git ls-files` for tracked `.env*`, `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.pfx`. Name them; never open them.
- **Baseline**:
  1. `flutter pub get --enforce-lockfile`. Exit 0: the dependencies resolve exactly as locked, and only ignored files are written (`.dart_tool/`, `.flutter-plugins-dependencies`, `*/flutter/ephemeral/`). Exit 65: the lockfile is stale. Exit 1 without `pubspec.lock`: nothing to enforce. In both cases, the analysis and the tests below are **not run**, with that reason, and resolving is left to the update-project skill (plan item 7).
  2. `flutter analyze --no-pub`: exit code and issue count.
  3. `flutter test --no-pub`, with a Bash timeout of 600000 ms: exit code and summary line.
  4. `dart format --output=none --set-exit-if-changed .`: exit code, and the files it would change; it writes nothing.

Then `git status --porcelain --untracked-files=all` again: it must still be empty. Resolution can regenerate a tracked plugin registrant (`linux/flutter/generated_plugin_registrant.cc`, …) when it was out of date, and a failing golden test writes a `failures/` directory next to it: if any file changed or appeared, stop, name it, and let the user decide — keep it, `! git restore <file>`, or `! rm -r <directory>`.

## Step 3 — Divergences

Compare what the documents say with what the code does, with the checklist in `${CLAUDE_PLUGIN_ROOT}/skills/adopt-existing-project/reference/divergences.md`. Each divergence has its category, the evidence on both sides (document and line, code file and line, or command output), a severity and a proposed action. Report them; fix none. Without any document, the divergences are measured against the plugin's conventions only.

## Step 4 — Compliance plan

**Validation point.** Present the analysis in at most fifteen lines — toolchain, platforms, layout, dependencies, tests and analysis at the baseline, documents found, divergences by category — then the compliance plan as numbered items. Each item names its file, its action (create, modify with the diff shown, keep) and why:

1. Branch `chore/adopt-plugin-flutter` from the default branch, named here for the user to confirm.
2. `.forge/config.yaml` from `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml`, with `project.default_branch` set to the current default branch and `platforms.enabled` to the platform folders found; `.forge/reports/.gitkeep`; `.forge/checkpoint.md`.
3. Documents, at the plugin's paths, only where absent, all DRAFT:
   - `docs/product/PRD.md`, rebuilt from the code by the product-architect agent;
   - `docs/technical/TRD.md` and `docs/engineering/DECISIONS.md`, rebuilt by the flutter-architect agent: the stack as it is; one ADR per direct dependency and one per deviation from the plugin's defaults (state management, navigation, layout), status `proposed`;
   - `docs/engineering/IMPLEMENTATION_PLAN.md`: the features found, "done (pre-existing)" with their tests, or "untested".
   An existing document is kept, never replaced, and the new one links to it under "Related documents".
4. Existing files to modify, each with its diff, **approved separately**: `CLAUDE.md` (a plugin-flutter section appended from `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/CLAUDE.md`; created only when absent), `.gitignore` (the missing secret patterns appended), `analysis_options.yaml` (the strict modes of bootstrap-project; say they may surface many new issues, and recommend a later, separate change).
5. `.claude/settings.json`: the rules of `${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json`, summarized; an existing file is merged, with the merge shown.
6. The divergence list: `.forge/reports/divergences-<YYYY-MM-DD>.md`.
7. Not in this plan, and the skill for each: resolving a stale lockfile and updating dependencies (update-project), failing tests (debug-project), CI (github-workflow `ci`), code layout (create-feature, one feature at a time).

The user approves all items, some of them, or none. An approval covers exactly what its item says.

## Step 5 — Apply the approved items

In this order, and only the approved items:

1. The branch, through the git-workflow skill, from the default branch.
2. `.forge/checkpoint.md` from `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`, with `skill: adopt-existing-project`, one step line per approved plan item, and the baseline of step 2 in its test results table — the `flutter pub get --enforce-lockfile` exit code included — so that an interrupted adoption resumes there with what it needs. Then `.forge/reports/.gitkeep`. From here on, update the checkpoint after every completed step.
3. `.forge/config.yaml`, before `.claude/settings.json`: once that file exists, its deny rule `Edit(./.forge/config.yaml)` stops Claude from writing it. The protect-sensitive hook asks the user to confirm this write. If it is refused — a non-interactive run cannot ask — do not write the file another way: give the user `! sed -e 's|^  default_branch: .*|  default_branch: <branch>|' -e 's|^  enabled: .*|  enabled: [<platforms>]|' ${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml > .forge/config.yaml`, with the values filled in, and wait.
4. The documents. Record `git status --porcelain --untracked-files=all`, then delegate to the product-architect agent: task `reconstruct`, with the paths to read (`lib/`, `test/`, the README, the existing documents) and the analysis of step 2. Wait for its report, and check that it changed only files under `docs/product/`. Then delegate the TRD and DECISIONS.md to the flutter-architect agent, with the same paths, the dependency list, `platforms.enabled`, and whether the lockfile matches (`flutter pub get --enforce-lockfile` exited 0 at step 2): when it does not, the agent must not run `flutter pub deps`, which would rewrite it. Wait, and check that it changed only files under `docs/`. Agents run one after the other. Then write IMPLEMENTATION_PLAN.md yourself, from the reconstructed criteria and the tests found.
5. Each approved modification of an existing file: exactly the diff shown, nothing more.
6. `.claude/settings.json`, if approved. Claude Code protects its configuration files, and a non-interactive run denies the write: do not work around it; give the user `! mkdir -p .claude && cp ${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json .claude/settings.json`, or the merged file to write.
7. `.forge/reports/divergences-<YYYY-MM-DD>.md`, in the format of the checklist.
8. Checks: `git status --porcelain --untracked-files=all` lists only the new files and the approved modifications. When the baseline ran, `flutter analyze --no-pub` and `flutter test --no-pub` give the same results as at step 2, except for the analysis issues the strict modes add when that item was approved; any other difference stops the workflow.

No document is approved by this skill: create-feature needs the PRD and the TRD APPROVED, which the user does later, explicitly.

## Step 6 — Commit and report

Stage the files explicitly through the git-workflow skill — never `git add -A` — and commit `chore: adopt plugin-flutter`, with the created and modified files in the body, and the checkpoint in its final state: write it before staging it — every approved item done, this commit announced, the next action — and do not change it after the commit, or `git switch <default branch>` would refuse to leave the branch. The commit asks for confirmation.

Final report:

- What was created, modified (with its approval) and kept; the branch and the commit.
- The divergences by category, and the path of the list.
- Baseline tests and analysis, in four categories, each with its command; write "none" for an empty category:
  - **passed**;
  - **failed**;
  - **blocked**, with the reason;
  - **not run**, with the reason (stale or missing lockfile).
- Next steps. The adoption lives on `chore/adopt-plugin-flutter`, and the other skills start from the default branch, where `.forge/` does not exist yet. When the baseline was clean — a matching lockfile, and `dart format`, `flutter analyze` and `flutter test` at exit 0 — push the branch and open its pull request with `/plugin-flutter:github-workflow pr`. Otherwise that skill stops on its preconditions, which require them: the user opens the pull request themselves, or merges locally (`! git switch <default branch>`, then `! git merge --ff-only chore/adopt-plugin-flutter`). The merge is the user's. Then review and approve the PRD and the TRD, and use the skills named by the plan's item 7.
