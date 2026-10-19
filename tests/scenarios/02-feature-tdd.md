# Scenario 2 — Feature in TDD

**Goal**: create-feature delivers AC-001 of the scenario 1 project with a recorded RED, then a
recorded GREEN, on a feature branch, reviewed, with the commit prepared.

## Steps

The scenario 1 project must have a commit to branch from. If scenario 1 ended with the commit
denied, make it yourself first: `git -C "$P" add -A && git -C "$P" commit -m "chore: bootstrap"`.

```bash
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s2-1.jsonl" "/flutter-forge:create-feature AC-001" "${TOOLS[@]}"
```

Scenario 1 left the PRD and the TRD in DRAFT, so the turn must stop at step 2 and ask for their
approval (a check of this scenario). Answer, then answer the step 4 validation point if it comes:

```bash
"$H" "$P" "$SID" resume "$WORK/s2-2.jsonl" "I approve the PRD and the TRD." "${TOOLS[@]}"
"$H" "$P" "$SID" resume "$WORK/s2-3.jsonl" "The plan is approved, go ahead." "${TOOLS[@]}"   # only if asked
```

## Checks

```bash
git -C "$P" branch --show-current                              # feature/ac-001-...
sed -n '/## Steps/,/## Next action/p' "$P/.forge/checkpoint.md"
```

- The checkpoint shows step 7 with `flutter test <files>`, a failure summary and a non-zero exit
  code, then step 9 with the same command and exit 0.
- The transcript shows an `Agent` call to `flutter-forge:test-engineer` before step 7,
  and one to `flutter-forge:code-reviewer` at step 13, given `git diff --cached <base>`
  (nothing is committed before step 15).
- Every test file written by the test-engineer is under `test/` or `integration_test/`.
- `git -C "$P" status --short` lists the prepared changes, or `git log` shows the commit: the report
  must match whichever happened (see scenario 1 on the `ask` rule).

**Passed** when RED precedes GREEN in the checkpoint with both outputs, and the final report
classifies the tests in the four categories.
