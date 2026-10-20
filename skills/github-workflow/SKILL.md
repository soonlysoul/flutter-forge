---
name: github-workflow
description: Connect a plugin-flutter project to GitHub — check gh authentication, create the remote repository after confirmation, add the Flutter CI workflow, open or update a pull request with its tests and platforms, follow its checks and diagnose a red CI. Use when the user wants a remote repository, a CI, a pull request, an issue or the CI status in a project that has a .forge/ directory.
argument-hint: "[remote | ci | pr | checks | issue]"
---

# GitHub workflow

Address the user in French unless they write in another language. Titles, bodies, branch names and file contents stay in English.

Request: $ARGUMENTS

## Rules

- **No result without its command.** Never report a step as done without the output of its command. If one command fails twice with the same error, stop, write the checkpoint and explain the blocker.
- **Validation points.** Ask in plain text, write the checkpoint, end your turn and wait. Do not use AskUserQuestion: the same flow works in headless mode.
- **One command per call.** Run each command alone — no pipe, `;`, `&&` or redirection: the project's permission rules allow plain commands such as `gh pr checks <number>`, and a compound command asks for permission, or is refused in a non-interactive run. The heredoc that feeds `--body-file -` is the one exception.
- **Configuration.** Read `.forge/config.yaml` first; a missing key counts as false. Never edit that file.
- **Checkpoint.** After every completed step, update `.forge/checkpoint.md` (format: `${CLAUDE_PLUGIN_ROOT}/templates/checkpoint.md`) with `skill: github-workflow`, the command and its exit code. Record the pull request URL and the CI conclusion in the test results table.
- **Tokens.** Never ask for, print or pass a token. Never run `gh auth status --show-token` or `gh auth token`.
- **Cost.** GitHub Actions minutes are free for public repositories on standard runners. A private repository spends the account's monthly quota: 2,000 minutes on GitHub Free, 3,000 on Pro and Team; a macOS minute costs about ten Linux minutes. Say it before anything that starts a run on a private repository.

## Before anything

1. `gh --version` and `gh auth status`. If gh is missing or not logged in, stop: the user runs `! gh auth login` themselves (in the session with the `!` prefix, or in a terminal). No token goes through the conversation.
2. `git status`, `git branch --show-current`, `git remote -v`.

| Action | Class |
| --- | --- |
| `gh auth status`, `gh repo view`, `gh pr view`, `gh pr checks`, `gh run list`, `gh run view`, `gh issue list`, `gh issue view` | free |
| push of a work branch | `authorizations.push_feature_branches: true`, or the user's explicit request in this conversation; through the git-workflow skill |
| open a pull request | `authorizations.open_pull_requests: true`, or the user's explicit request |
| update a pull request the current account opened | `authorizations.update_own_pull_requests: true`, or the user's explicit request; never a pull request of someone else |
| create the remote repository | confirmed every time — owner, name, visibility — even with `authorizations.create_remote_repo: true` |
| add or change the CI workflow; rerun or start a workflow on a private repository | the user's explicit approval, with the cost |
| create an issue | the user's explicit request, title and body shown first |
| merge, change the visibility, delete, release, push a tag | never done by Claude: the user does it; the guard-destructive hook blocks these commands |

## remote — create the GitHub repository

1. If `git remote -v` already lists `origin`, say so and stop: there is nothing to create.
2. **Validation point.** Propose the owner (the account shown by `gh auth status`), the name (the app name), the visibility — **private** by default; public makes CI free and the code visible to everyone — and a one-line description. Say that the default branch will be pushed once the repository exists. Wait.
3. After the answer: `gh repo create <owner>/<name> --private --description "<one line>" --source . --remote origin` (`--public` if chosen). No `--push`: the push is the next step, and only the default branch.
4. `git push -u origin <default branch>`. The approval of step 2 covered this first publication; it is the only push of the default branch this skill makes. A project rule may ask to confirm it.
5. `gh repo view <owner>/<name> --json url,visibility,defaultBranchRef`: report the URL and the visibility.

## ci — add the Flutter CI

1. If `.github/workflows/ci.yml` exists, read it, compare it with the template, and propose the differences instead of overwriting it.
   Where the commit goes: without a remote, on the default branch, which `remote` publishes later. With a remote, on a work branch, because this skill never pushes the default branch after its first publication: create `chore/ci` from the default branch through the git-workflow skill, and the pull request of that branch runs the new CI for the first time.
2. **Validation point.** Explain what the CI does: on every pull request and every push to the default branch, `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze` and `flutter test`, on one Linux runner, with a 20-minute cap. Give its cost for this repository's visibility (`gh repo view --json visibility`; "no remote yet" otherwise), and say that the plugin will ask to confirm the file write. Wait.
3. Read `${CLAUDE_PLUGIN_ROOT}/templates/github-workflows/flutter-ci.yml`. Replace `__FLUTTER_VERSION__` with the version printed by `flutter --version` (such as `3.44.3`), so that CI runs the local Flutter, and `__DEFAULT_BRANCH__` with `project.default_branch`. Keep the pinned commit SHAs. Write the result to `.github/workflows/ci.yml` with the Write tool.
4. The protect-sensitive hook asks the user to confirm that write. If it is refused — a non-interactive run cannot ask — do not write the file another way: give the user the command to run themselves, with the two values filled in:
   `! mkdir -p .github/workflows && sed -e 's|__FLUTTER_VERSION__|<version>|' -e 's|__DEFAULT_BRANCH__|<branch>|' ${CLAUDE_PLUGIN_ROOT}/templates/github-workflows/flutter-ci.yml > .github/workflows/ci.yml`
5. Run locally what CI will run: `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Each must exit 0; for `flutter analyze`, infos and warnings are fatal by default, in CI as here. A check that fails here fails on GitHub: fix it first, with the debug-project skill.
6. Commit through the git-workflow skill: `ci: add Flutter CI (format, analyze, test)`. With a remote, the next step is `pr` for the `chore/ci` branch.
7. If the user wants the enabled platforms built locally, delegate a `build` task to the devops-engineer agent with `platforms.enabled`, wait for its report, and present its BUILDS table. A platform is "built" only with its command and exit code.

## pr — open or update the pull request

1. Preconditions: the current branch is a work branch, not the default branch; nothing is uncommitted except `.forge/checkpoint.md` and `.forge/reports/`; the branch's tests have recorded results (checkpoint), or run `flutter test` now and record it; `dart format --output=none --set-exit-if-changed .` and `flutter analyze` exit 0, since infos and warnings are fatal by default in CI.
2. The branch must be on GitHub: push it through the git-workflow skill, which checks `push_feature_branches`. Without a push, stop: a pull request needs the branch on the remote.
3. `gh pr view <branch> --json number,url,state,author`: if a pull request is open for this branch, go to step 6.
4. Fill `${CLAUDE_PLUGIN_ROOT}/skills/github-workflow/reference/pr-body.md` from the checkpoint, the targeted acceptance criteria of the PRD, `git log --oneline <default branch>..HEAD` and `git diff --stat <default branch>...HEAD`. Tests in four categories, each with its command; platforms in three states (enabled, built, tested). Never call a platform built or tested without the command that proves it; write "none" for an empty category. `flutter test` runs on the host Dart VM and marks no platform as tested: a platform is tested only by integration tests run on it (`flutter test integration_test -d <device>`), otherwise its tested column says "no".
5. **Validation point**, unless `open_pull_requests: true` or the user asked for the pull request in this conversation: show the title and the body, then wait. On a private repository, say that opening the pull request starts a CI run, and that each push to its branch starts another. Then create it, with the body in a quoted heredoc so that nothing in it runs:

   ```bash
   gh pr create --base <default branch> --head <branch> --title "<type(scope): summary>" --body-file - <<'EOF'
   <body>
   EOF
   ```

   Never `--fill`, `--web`, or a pull request into another repository. Then `gh pr view <branch> --json number,url` and report the URL.
6. Update: only if `gh pr view <number> --json author --jq .author.login` is the active account (`gh auth status --json hosts --jq '.hosts["github.com"][] | select(.active) | .login'`), and with `update_own_pull_requests: true` or the user's explicit request. `gh pr edit <number> --body-file - <<'EOF'` with the refreshed body.

## checks — follow the CI

1. `gh pr checks <number>`: exit 0 means every check passed, 8 means some are still pending, another non-zero code means a failure. While pending, run `gh pr checks <number> --watch --fail-fast` once, with a Bash timeout of 600000 ms. If checks are still pending after that, report it and stop; do not loop.
2. Green: record `gh pr checks <number>` → passed in the checkpoint and report it.
3. Red: delegate a `ci-diagnosis` task to the devops-engineer agent, with the branch and the pull request number. Wait for its report, and verify its main claim yourself (`gh run view <run id> --log-failed`, read the lines it cites). Then:
   - format, analysis, tests or dependencies: reproduce locally and fix with the debug-project skill, then commit and push through git-workflow; on a private repository, each push starts a CI run, so group the fixes into one push;
   - the workflow itself: delegate a `workflow-change` task to the devops-engineer agent, check its diff, then commit and push through git-workflow;
   - infrastructure (runner, network): propose `gh run rerun <run id> --failed`. On a private repository it spends minutes: validation point.
4. Never merge. When the checks are green, tell the user the pull request is ready and that the merge is theirs.

## issue

`gh issue list` and `gh issue view <number>` are free. `gh issue create --title "<title>" --body-file - <<'EOF'` only on the user's explicit request, after showing the title and the body.

## Report

- Repository (URL, visibility), branch, pull request (number, URL, state).
- CI: run, conclusion; for a failure, its class, the evidence and the next step.
- Tests in four categories, each with its command; platforms in three states.
- What was not done, and why: missing authorization, refused write, pending checks.
