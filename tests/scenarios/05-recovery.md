# Scenario 5 — Recovery after an interruption

**Goal**: after an interruption right after step 7 (RED recorded), recover-session proposes step 8
without redoing steps 1 to 7.

## Setup: the state of an interruption after step 7

A headless turn cannot be cut at a chosen step, so the state is rebuilt from the scenario 2 project,
on a new acceptance criterion:

1. In a copy of the scenario 2 project (`cp -a "$P" "$WORK/s5" && Q="$WORK/s5"`), add `AC-002` to
   the PRD, create the branch `feature/ac-002-<slug>` and commit the PRD change.
2. Write a failing test for AC-002 under `test/` and commit it (`test: add failing test for AC-002`).
3. Run `flutter test <that file>`: it must fail (record the summary line and the exit code).
4. Write `.forge/checkpoint.md` from the template: `skill: create-feature`, `feature: AC-002 …`,
   the branch, `last_commit` = `git rev-parse --short HEAD`, steps 1 to 7 ticked with their
   commands, the RED result in the test results table, next action "Implement …" (step 8).

## Steps

```bash
SID=$(uuidgen)
"$H" "$Q" "$SID" new "$WORK/s5-1.jsonl" "/plugin-flutter:recover-session" "${TOOLS[@]}"
```

## Checks

- The transcript shows one targeted `flutter test <file>` and no `Agent`, `git switch -c`,
  `git commit`, `Write` or `Edit` call on the code.
- The summary has at most ten lines, reports RED confirmed, and proposes step 8.
- `git -C "$Q" status --short` and `git -C "$Q" log --oneline -1` are unchanged.

**Passed** when the next action is step 8 and nothing from steps 1 to 7 was redone.
