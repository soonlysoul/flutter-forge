---
name: bootstrap-project
description: Create a new Flutter app with plugin-flutter — validated name, package id and platforms, flutter create, Git, the four base documents in DRAFT, the .forge/ state directory, proposed permission rules and a green base test. Use when the user wants to start a new Flutter application from scratch; not for a project that already exists.
argument-hint: "[app-name]"
---

# Bootstrap a Flutter project

Address the user in French unless they write in another language. Code, identifiers and file contents stay in English.

App requested: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of its command. If one command fails twice the same way, stop, write the checkpoint (once it exists) and explain the blocker.
- **Validation points.** Ask in plain text, write the checkpoint once it exists (from step 4 on), end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **Nothing is approved implicitly.** A document becomes APPROVED only on the user's explicit message; then write the date and "approved by the user in conversation" in its header.
- **No application code before the PRD and the TRD are approved.**
- **Checkpoint.** From step 4 on, update `.forge/checkpoint.md` after every completed step (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`), with `skill: bootstrap-project`, the command and its exit code.
- **Project root.** The plugin's hooks and the project's permission rules take the directory where Claude Code was launched as the project root (`${CLAUDE_PROJECT_DIR}`). The project is best created right there, in an empty directory.
- Never display or write a token or a secret.

## Step 1 — Prerequisites

Run `flutter --version`, `git --version` and `jq --version`, and record the versions. Without flutter or git, stop and explain what is missing. If a shell command is blocked because jq is missing, stop: the plugin's guard hooks block every shell command until jq is installed; tell the user.

Run `flutter devices` to see which targets this machine can run. Keep three states apart for every platform: enabled (its folder exists), built (a build succeeded, with the command), tested (tests ran on that target). A Linux host builds Android, web and Linux; iOS, macOS and Windows need a CI runner of that system and stay "not verified" locally.

## Step 2 — Validation point: identity and scope

Propose values and ask the user to confirm or correct them, then stop:

- app name: a valid Dart package name in snake_case, such as `my_notes`;
- organization, in reverse domain notation, such as `com.example`; the application id becomes `com.example.my_notes`;
- platforms among android, ios, web, linux, macos, windows, saying which ones this machine can build;
- the scope of the first version, in one paragraph;
- the target directory. Recommend the current directory `${CLAUDE_PROJECT_DIR}` when it is empty, so that this session can go on with create-feature. Otherwise propose `<current directory>/<app name>`, which must not exist or must be empty, and warn that create-feature will then need a new Claude Code session started in that directory.

## Step 3 — Create the project

After the answer, run `flutter create --org <org> --project-name <name> --platforms <comma-separated list> --description "<one line>" <directory>` (`.` for the current directory). If a desktop platform is refused because its support is disabled, report it: enabling it (`flutter config --enable-linux-desktop`) changes the user's global Flutter configuration, so it needs their approval.

In the project directory, run `git init -b main`, unless it is already inside a repository.

## Step 4 — State directory

Create, in this order:

1. `.forge/config.yaml` from `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml`, with `platforms.enabled` set to the validated platforms. Every authorization stays false: only the user changes them, by editing the file. Create it now: once `.claude/settings.json` is installed (step 7), its deny rule `Edit(./.forge/config.yaml)` stops Claude from writing it. The protect-sensitive hook asks the user to confirm this write. If it is refused — a non-interactive run cannot ask — do not write the file another way: give the user `! mkdir -p .forge && sed -e 's/^  enabled: .*/  enabled: [<platforms>]/' ${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml > .forge/config.yaml`, with the platforms filled in, and wait.
2. `.forge/reports/.gitkeep`.
3. `.forge/checkpoint.md` from `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`, with steps 1 to 4 ticked.

## Step 5 — Layout and quality settings

- Create `lib/app/`, `lib/core/`, `lib/features/` and `integration_test/`, each with a `.gitkeep`.
- In `analysis_options.yaml`, keep `include: package:flutter_lints/flutter.yaml` and add the strict modes:

  ```yaml
  analyzer:
    language:
      strict-casts: true
      strict-inference: true
      strict-raw-types: true
  ```

- Append to `.gitignore`, if absent: `.env*`, `*.jks`, `*.keystore`, `key.properties`.
- Write `CLAUDE.md` from `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/CLAUDE.md`, with the app name and the user's language.

## Step 6 — Base documents, in DRAFT

Create them from the templates, keeping their fixed header:

| Document | Template |
| --- | --- |
| `docs/product/PRD.md` | `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/PRD.md` |
| `docs/technical/TRD.md` | `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/TRD.md` |
| `docs/engineering/IMPLEMENTATION_PLAN.md` | `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/IMPLEMENTATION_PLAN.md` |
| `docs/engineering/DECISIONS.md` | `${CLAUDE_PLUGIN_ROOT}/skills/bootstrap-project/reference/doc-templates/DECISIONS.md` |

- Fill the PRD from the validated scope, with numbered acceptance criteria `AC-001`, `AC-002`, … When the user gave a long brief (a document, several features) and the project was created in the current directory, delegate the PRD to the product-architect agent instead (task `draft`, with the brief and the validated scope), wait for its report, and check with `git status --porcelain --untracked-files=all` that it changed only files under `docs/product/`.
- Fill the TRD with the defaults. When the architecture is not trivial and the project was created in the current directory, delegate the TRD to the flutter-architect agent, wait for its report, and check the files it changed. When the project is in a subdirectory, write the TRD yourself: the agent's write limits are relative to the session root.
- DECISIONS.md starts with `ADR-001 — Initial stack`: the output of `flutter --version`, the default choices and the platforms.
- The plan lists the acceptance criteria in delivery order.
- The optional documents (TEST_STRATEGY, TRACEABILITY, APPFLOW, UI_UX_DESIGN, BACKEND_SCHEMA) are created later, when their need appears.

## Step 7 — Validation point: documents and permissions

Ask both questions, then stop:

1. Do you approve the PRD and the TRD as they are, or what should change? No application code is written before this approval.
2. May I install the proposed permission rules in `.claude/settings.json`? Summarize `${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json`: what runs without asking, what asks first, what is denied. Explain that the `allow` rules apply only after the user accepts the workspace trust prompt, while `deny` and `ask` always apply.

On approval of a document, set its status to APPROVED with the date. On approval of the rules, copy the template to `.claude/settings.json`; if that file exists, show the merge and wait for agreement before writing. Claude Code protects its own configuration files: in a non-interactive run the write is denied. Do not work around it; give the user the exact command to run themselves, `! mkdir -p .claude && cp ${CLAUDE_PLUGIN_ROOT}/templates/project-settings.json .claude/settings.json`, and say that no project rule applies until then.

## Step 8 — Base test, green

Run `flutter pub get`, then `flutter test`: exit code 0 is required. Then `flutter analyze`: exit 0 (infos and warnings are fatal by default, as in CI). If the generated test fails, report it as it is, do not edit around it, and stop before the commit. `flutter test` runs on the host Dart VM: it marks no platform as tested.

## Step 9 — First commit

Through the git-workflow skill: show `git status`, stage the files explicitly, and propose the message `chore: bootstrap <name> with plugin-flutter`. The commit asks for confirmation.

## Step 10 — Report

- Path of the project, platforms enabled, built and tested.
- Documents and their status.
- Tests in four categories, each with its command: passed, failed, blocked (reason), not run; "none" for an empty category.
- Next step: `/plugin-flutter:create-feature AC-001`. To publish the project on GitHub and add the CI: `/plugin-flutter:github-workflow remote`, then `/plugin-flutter:github-workflow ci`. If the project is in a subdirectory, first start a new Claude Code session in it (`cd <directory> && claude`): the hooks and the permission rules use the session's launch directory as the project root.
