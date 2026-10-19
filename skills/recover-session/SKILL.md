---
name: recover-session
description: Resume interrupted work in a plugin-flutter project from what is on disk — .forge/checkpoint.md, the Git history and the repository state — without changing anything before the user agrees. Use when the user asks to resume, continue or see where the work stopped, after a usage limit, a crash or an interruption, in a project that has .forge/checkpoint.md.
---

# Recover a session

Address the user in French unless they write in another language.

The work is resumed from disk, never from what a previous session remembers. Until the summary is accepted, this skill is read-only: no stash, no checkout, no commit, no edit of the code.

## Step 1 — Read the checkpoint

Read `.forge/checkpoint.md`: skill, feature, branch, `last_commit`, ticked steps, test results, next action, blockers. If it is missing, rebuild the state from `git log --oneline -20`, `git branch --show-current` and the branch name, and say that there was no checkpoint.

## Step 2 — Compare with the repository

Run `git rev-parse --short HEAD`, `git branch --show-current` and `git status --porcelain`. Compare `last_commit` with `HEAD`, and list the uncommitted files. Touch nothing.

## Step 3 — Report inconsistencies

Flag each one:

- commits newer than `last_commit` (`git log --oneline <last_commit>..HEAD`);
- a current branch different from the checkpoint's;
- uncommitted changes that the checkpoint does not mention;
- a step ticked without its command or exit code.

## Step 4 — Confirm the real state

Rerun only the targeted test of the last completed step, the command recorded in the test results table (for example `flutter test test/features/notes`). What to expect depends on the last ticked step: after RED (step 7) the tests still fail; from GREEN (step 9) on they pass; after step 8 alone, either outcome is possible, so report it without judging. If the table has no test line, say so and run nothing. Do not run the full suite.

## Step 5 — Summary, then wait

Present at most ten lines:

- skill, feature and branch;
- last completed step, with its recorded result;
- the real state confirmed at step 4 (command, exit code);
- the inconsistencies, or "none";
- the next action: the first unticked step, without redoing the completed ones.

Ask whether to resume from that step, then stop and wait.

When the checkpoint-reminder hook asks for a checkpoint update during recovery, change only `updated:` and add a line under "Blockers / open questions" that records the recovery and its inconsistencies; change nothing else before the user agrees.

After the agreement, continue with the skill named in the checkpoint, from the next action.
