---
name: create-feature
description: Develop one feature of a plugin-flutter Flutter project in strict TDD — repo check, plan, branch, failing tests by the test-engineer, RED then GREEN with recorded output, refactor, format and analyze, independent review, docs, commit. Use when the user asks to implement an acceptance criterion (AC-xxx) or to add or change a feature in a project that has a .forge/ directory; not for other projects.
argument-hint: "[AC-id or feature description]"
---

# Create a feature in TDD

Address the user in French unless they write in another language. Code, identifiers and file contents stay in English.

Feature requested: $ARGUMENTS

## Rules for every step

- **Checkpoint after every completed step.** Update `.forge/checkpoint.md` (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`): tick the step with its command and exit code, update the test results table and the next action. Set `skill: create-feature`, the feature and the branch. The checkpoint is workflow state: it is often modified, and that is never a reason to stop. A commit that carries the checkpoint follows git-workflow: the checkpoint is written before it, and not changed again for that commit.
- **No result without its command.** Never report a step as done without the output of the command that proves it.
- **Two identical failures stop the workflow.** If one command fails twice with the same error, stop, write the checkpoint and explain the blocker instead of retrying. This rule also applies inside the three iterations of step 9: the iteration limit is a ceiling, not a licence to repeat a failure.
- **Validation points.** Ask the question in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **Delegation.** Agents run one after the other, never in parallel on the same files. In an interactive session a subagent runs in the background and its report arrives as a notification on a later turn: wait for it. Verify every agent claim (rerun the command when it matters) before presenting it as a fact.
- **Configuration.** Read `.forge/config.yaml` before any external action; a missing key counts as false. Never edit that file.
- **Project root.** The hooks and the permission rules take the directory where Claude Code was launched as the project root: `${CLAUDE_PROJECT_DIR}`. `.forge/` must be there. If the Flutter project is in a subdirectory, stop and ask the user to start Claude Code again in that directory.
- **Prerequisite.** Without `.forge/`, stop and offer to create `.forge/config.yaml` and `.forge/checkpoint.md` from `${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml` and `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`, after the user agrees.

## The 15 steps

### Step 1 — Repository state

Run `git status` and `git branch --show-current`. Ignore changes to `.forge/checkpoint.md` and `.forge/reports/`: they are workflow state and travel with the feature. For any other uncommitted change, preserve it: list it and ask whether to commit it, move it to a branch, or stop. Never `git stash` silently, never discard anything.

### Step 2 — Context

Read `docs/product/PRD.md`, `docs/technical/TRD.md` and the entry of `docs/engineering/IMPLEMENTATION_PLAN.md` for this feature. If the PRD or the TRD is not APPROVED, stop: no application code is written before the user approves them; ask for that approval. List the acceptance criteria targeted (AC-xxx). If the request matches no criterion, propose a new numbered AC and treat it as a scope change at step 4.

### Step 3 — Risks and dependencies

List what the feature implies: a new package (it needs an ADR in DECISIONS.md and a platform check), an impact on a platform, a data migration.

### Step 4 — Plan

Write the plan: files touched, public API (signatures), planned tests with their AC ids, dependencies. **Validation point**: if the scope, the architecture or a dependency changes, present the plan, ask for validation and stop. Otherwise say that no validation is needed, and why, and continue.

After the validation:

- a new acceptance criterion is written into the PRD, and its header records under "Confirmed decisions" the date and that the user approved it in conversation;
- an approved dependency is added now, before any test imports it: `flutter pub add <package>`. Then check its platforms: find the package's root in `.dart_tool/package_config.json`, read the `flutter: plugin: platforms:` section of its `pubspec.yaml`, and compare with `platforms.enabled`. Record the result in its ADR. A package without that section is pure Dart: say so. If you cannot read it, write "platform support: not verified" and tell the user.

### Step 5 — Branch

Create the branch `feature/<ac-id>-<slug>` (prefix from `project.branch_prefix` in `.forge/config.yaml`) through the git-workflow skill: `git switch -c feature/<ac-id>-<slug>` from the default branch.

### Step 6 — Tests first

Record `git status --porcelain`. Delegate to the test-engineer agent: the acceptance criteria, the plan, the public API and the test file paths. For tests under `integration_test/`, give it the device to use (`-d linux`, for example, from `flutter devices`); without a device, those tests are classified as blocked, with the reason. Wait for its report before doing anything else, and write nothing in parallel. Then compare `git status --porcelain` with the recorded one: the agent must have changed files only under `test/` and `integration_test/`.

### Step 7 — RED

Run the targeted tests yourself: `flutter test <targeted test files>`. Record the result in the checkpoint: the command, its exit code and the summary line (for example `FAILED 3 (expected RED)`). The failure must be on the expected assertion, or a compilation error naming the missing API under test. Any other failure (unrelated compilation error, wrong import) means the tests are wrong: fix them, or send them back to the test-engineer, and run RED again. If the tests already pass, stop: the behaviour may exist already, or the tests do not test it. Report it and ask the user how to continue.

### Step 8 — Minimal implementation

Implement, in the main session, the minimum that makes these tests pass, in the files of the plan. No dependency that step 4 did not validate.

### Step 9 — GREEN

Run the same targeted command: `flutter test <targeted test files>`. Every test must pass (exit code 0). Record the command, its exit code and the summary line in the checkpoint. Otherwise go back to step 8, at most three iterations; after the third, stop, write the checkpoint and expose the blocker.

### Step 10 — Refactor

Clean up without changing behaviour: naming, duplication, layout. No new behaviour, no new test.

### Step 11 — Re-test

Run the targeted tests again, then, at this milestone only, the full suite: `flutter test`. Record both in the checkpoint. A failure outside the targeted tests is unexpected: diagnose it with the debug-project skill before going on.

### Step 12 — Quality

Run `dart format --set-exit-if-changed .` and `flutter analyze`. `flutter analyze` must exit 0: infos and warnings are fatal by default, exactly as in the CI of the github-workflow skill. Fix them; one that cannot be fixed is listed with its reason, and the user decides. The format-dart hook formats the files Claude edits, so a format failure points at a file changed another way: format it and say which.

### Step 13 — Review

Nothing is committed yet, so the review covers the staged changes. Stage the files of the feature explicitly through the git-workflow skill (code, tests, the PRD if an AC was added, `pubspec.yaml` and `pubspec.lock` if a dependency was added; not `.forge/`). Then delegate to the code-reviewer agent: the diff to review, `git diff --cached <default branch>`, the targeted acceptance criteria and the declared scope. Give it nothing of your reasoning. Wait for its report.

Fix every blocking finding, stage the fixes, then run the commands of step 11 and step 12 again: their earlier results no longer hold. Have the fixes reviewed once more. If a blocking finding remains after that second review, stop, write the checkpoint and expose it. List the important and minor findings for the user, with what you did about them.

### Step 14 — Documentation

Update `docs/engineering/IMPLEMENTATION_PLAN.md` (status, branch, tests) and `docs/engineering/DECISIONS.md` for any new choice, starting from the DOCS_TO_UPDATE and the DIVERGENCES the code-reviewer listed. A divergence in the plan or DECISIONS.md is resolved by updating the document when the code is right. A change to the PRD or the TRD — a criterion added because a test cites it, for example — is a validation point, since only the user approves them. A divergence where the document is right is reported to the user. Create `docs/engineering/TRACEABILITY.md` once the PRD has more than ten acceptance criteria. Report any divergence between the documents and the code. Stage the updated documents.

### Step 15 — Commit and report

Prepare the commit through the git-workflow skill: the staged files, the updated checkpoint, and a Conventional Commit message such as `feat(notes): list notes offline (AC-012)`. The commit itself asks for confirmation. Then write the final report.

## Final report

- Feature, acceptance criteria covered, branch, commit (hash and message).
- Tests, in four categories, each with its command; write "none" for an empty category:
  - **passed**;
  - **failed**;
  - **blocked**, with the reason (missing device, missing account, platform not available on this machine);
  - **not run**.
- Review findings and what was done about them.
- What was not done, and the next step: usually pushing the branch and opening the pull request with `/plugin-flutter:github-workflow pr`.
