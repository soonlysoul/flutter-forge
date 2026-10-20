---
name: git-workflow
description: Branch, stage, commit and inspect diffs safely in a plugin-flutter project — named branches, explicit staging, atomic Conventional Commits, diff summaries, push of a work branch only when preauthorized. Use when the user or another workflow needs a branch, a commit, a diff summary or a push in a project that has a .forge/ directory.
argument-hint: "[branch | commit | diff | push]"
---

# Git workflow

Address the user in French unless they write in another language. Commit messages, branch names and file contents stay in English.

Request: $ARGUMENTS

## Before anything

Read `.forge/config.yaml`; a missing key counts as false. Run `git status` and `git branch --show-current`.

Every Git or GitHub action falls into one of three classes:

| Action | Class |
| --- | --- |
| `git status`, `git diff`, `git log`, `git switch -c` | free |
| `git add <explicit files>` | free, after reviewing the diff |
| `git commit` | asks for confirmation (project rule) |
| `git push` of a work branch | only if `authorizations.push_feature_branches: true`, or on the user's explicit request in this conversation; never the default branch |
| creating a remote repository, opening a pull request | the github-workflow skill, with its validation points |
| merging, changing visibility, deleting, releasing, pushing a tag | never done by Claude: the user does it; the guard-destructive hook blocks them |
| `reset --hard`, `clean -f`, `push --force`, `branch -D`, `checkout -- <path>`, `restore` (except `restore --staged`), `stash drop`, `stash clear` | forbidden: the guard-destructive hook and the project's deny rules block them |

When a blocked command is really needed, explain why it is blocked and what it would destroy. The user can run it themselves with the `!` prefix; never rephrase it to get around the hook.

## Branch

Names: `feature/<ac-id>-<slug>`, `fix/<slug>`, `chore/deps-<slug>` (update-project), `docs/<slug>`, `chore/ci` (github-workflow) and `chore/adopt-plugin-flutter` (adopt-existing-project); the prefix of features comes from `project.branch_prefix`. Start from the default branch (`project.default_branch`): `git switch <default branch>`, then `git switch -c <name>`. Changes to `.forge/checkpoint.md` and `.forge/reports/` are workflow state: carry them along. With any other uncommitted change, stop and ask: commit it, carry it to the new branch, or stop. Never `git stash` silently.

## Diff report

`git status --short`, `git diff --stat`, then `git diff` and `git diff --cached`. Report the files by kind (code, tests, docs, generated) and flag what should not be committed: build outputs, `.env*`, keystores, `key.properties`, editor files.

## Stage

`git add <file> <file> …`, listing the files. `git add -A`, `git add .` and `git add --all` only after the whole diff has been reviewed with the user; the project rules make them ask. Before committing, read `git diff --cached` for secrets (AWS keys, `-----BEGIN`, `ghp_`, `sk-`, `AIza`); if one appears, unstage the file (`git restore --staged <file>`, or `git rm --cached <file>` before the first commit, when there is no HEAD yet), never print the secret, and tell the user which file holds it. The secret-scan hook checks every commit the same way and blocks it; when it does, follow its reason, never rephrase the commit to get past it.

## Commit

- One logical change per commit, with its tests.
- Conventional Commits: `type(scope): summary`, with the acceptance criterion in parentheses when there is one: `feat(notes): list notes offline (AC-012)`. Types: feat, fix, test, refactor, docs, chore.
- Show the message and the file list, then run `git commit -m "<message>"`. For a message with a body, use `git commit -F -` with a quoted heredoc (`<<'EOF'`), so that nothing in the message is expanded or run.
- After the commit, `git log --oneline -1`; once `.forge/checkpoint.md` is updated, its `last_commit` matches that hash.

## Push

Only a work branch, never the default branch, never with force. One exception, owned by the github-workflow skill: the first publication of the default branch to a repository it has just created, which the user approved with the creation. Check the class above first. Run `git remote -v`: without a remote, stop; creating one is an explicit decision of the user, through the github-workflow skill (`remote`). Then `git push -u origin <branch>`, and report the output.

## Report

Branch, commits (hash and message), files staged or committed, and what was not done with the reason.
