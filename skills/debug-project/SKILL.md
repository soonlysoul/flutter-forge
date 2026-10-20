---
name: debug-project
description: Diagnose and fix an unexpected failure in a plugin-flutter project — a build error, an analyzer error, a failing test or a red CI — by reproducing it, finding the root cause with evidence, writing a regression test RED then GREEN, and committing a minimal fix. Use when something fails that should pass, in a project that has a .forge/ directory; not for the expected RED step of create-feature.
argument-hint: "[failing command or error]"
---

# Debug a project

Address the user in French unless they write in another language. Code, identifiers and file contents stay in English.

Failure reported: $ARGUMENTS

## Rules

- **No fix before a root cause.** A fix is written only after the cause is stated with its evidence: the log line, the stack frame, the diff that introduced it. Guessing and changing code until the error goes away is not debugging.
- **No result without its command.** Never report a step as done without the output of its command.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection, no `| tail` to shorten the output: the project's permission rules allow plain commands such as `flutter test <file>`, and a compound command asks for permission, or is refused in a non-interactive run.
- **Two identical failures stop.** If a command fails twice with the same error after a change meant to fix it, stop, write the checkpoint and expose the blocker: the hypothesis was wrong.
- **Checkpoint after every completed step**, with `skill: debug-project`, the command and its exit code (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`). Under "Next action", the current hypothesis. A commit that carries the checkpoint follows git-workflow: the checkpoint is written before it, and not changed again for that commit.
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion.
- **Configuration.** Read `.forge/config.yaml` before any external action; a missing key counts as false. Never edit that file.
- Never `git stash`, reset or discard anything to make a failure disappear.

## Step 1 — Repository state

`git status` and `git branch --show-current`. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state. For any other uncommitted change, preserve it: list it, and say whether it may be part of the failure. Never stash it silently.

## Step 2 — Reproduce

Run the exact failing command (for a red CI, the command of the failed step, locally). Record the command, its exit code and the first error lines in the checkpoint.

- It fails the same way: go on.
- It does not fail: say so. Compare the environment (`flutter --version` here and in the CI log, `flutter pub deps`, the platform), and stop with what differs: a failure that does not reproduce cannot be fixed with evidence.
- A test that fails once and passes on one rerun is flaky: report it as such; the fix is then the test's isolation, timing or shared state.

## Step 3 — Classify

Name the class, with the line of output that shows it:

- compilation or analysis error (`flutter analyze`, a build): the file, line and message;
- test assertion: expected and actual values, the test name;
- exception in a test or at runtime: the first stack frame inside the project's code;
- dependency resolution (`flutter pub get`): the package and the conflicting constraints;
- platform toolchain (a build only): `flutter doctor -v` for that platform;
- CI only: what differs between CI and this machine.

## Step 4 — Root cause

Read the code at the failing frame or line, then its recent history: `git log --oneline -10 -- <file>`, and `git diff <last known good commit> -- <file>` when one is known (the last green CI run, a tag, the checkpoint). Write one hypothesis at a time, with the evidence for it, and test it by reading or by running a narrower command (a single test with `--plain-name`, a single file). State the root cause in one sentence before writing any fix.

`git bisect` moves HEAD: propose it only with a clean working tree, and only with the user's agreement.

## Step 5 — Scope of the fix

List the files the fix touches. The scope of the error is the failing file and the code it calls directly. **Validation point** when the fix goes outside the scope: another feature, `pubspec.yaml` (a dependency, a version), a platform folder (`android/`, `ios/`, …), `analysis_options.yaml`, the CI workflow, or a change of behaviour that the PRD does not describe. Present the cause, the fix and the files, then wait. Otherwise say that the fix stays within the scope, and continue.

## Step 6 — Branch

On the default branch, create `fix/<slug>` through the git-workflow skill. On a work branch whose own changes caused the failure, fix it there. On a work branch that inherited the failure from the default branch, ask which branch takes the fix.

## Step 7 — Regression test, RED

When the failure is an existing test that fails, that test already reproduces it: it is the regression test, do not duplicate it, and record its RED run from step 2. Otherwise, write a test that reproduces the failure through the public API, next to the existing tests (`test/` mirrors `lib/`). Name it after the bug: `test('regression: <what failed>', ...)`, or with the acceptance criterion id when the bug breaks one. Run it: `flutter test <test file> --plain-name "regression: <what failed>"`. It must fail for the reason found at step 4; record the output in the checkpoint.

When no test can capture the failure (a build or toolchain configuration, for example), say so: the reproduction command of step 2 is then the regression check.

## Step 8 — Minimal fix, GREEN

Change the minimum, in the files of step 5, to remove the root cause — not its symptom. Run the regression test again: it must pass (exit code 0). Record it. Otherwise go back to step 4: at most three iterations, and the two-identical-failures rule applies.

## Step 9 — Full check

Run the original failing command again, then the full suite `flutter test`, then `dart format --set-exit-if-changed .` and `flutter analyze`, which must exit 0: infos and warnings are fatal by default, as in CI. Record each one in the checkpoint.

## Step 10 — Review

Stage the fix and its test explicitly through the git-workflow skill (not `.forge/`). Delegate to the code-reviewer agent: the diff `git diff --cached <base>`, the root cause in one sentence, and the declared scope. Give it nothing else of your reasoning. Fix the blocking findings, then rerun step 9 and have the fixes reviewed once more; a blocking finding that remains stops the workflow. List the DIVERGENCES it reports in the final report; fix only those within the scope of step 5.

## Step 11 — Commit and report

Update `docs/engineering/DECISIONS.md` only if the fix changes a recorded choice. Prepare the commit through the git-workflow skill: the staged fix and its test, the updated `.forge/checkpoint.md`, and a Conventional Commit whose body states the root cause:

```
fix(<scope>): <what is fixed>

Root cause: <one sentence>.
Regression test: <test file and name>.
```

The commit asks for confirmation. For a red CI, the next step is to push the branch and follow the checks with the github-workflow skill.

## Final report

- Failure, class, root cause with its evidence.
- Fix: files changed, branch, commit (hash and message).
- Regression test: file and name, RED then GREEN with their commands.
- Tests in four categories, each with its command; write "none" for an empty category:
  - **passed**;
  - **failed**;
  - **blocked**, with the reason;
  - **not run**.
- Review findings and what was done about them; what remains, and the next step.
