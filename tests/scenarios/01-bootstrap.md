# Scenario 1 — Bootstrap

**Goal**: in an empty directory where the session is launched, bootstrap-project creates a Flutter project with a green
base test, the four base documents in DRAFT and the `.forge/` directory, stopping at each
validation point.

## Steps

The session is launched inside the empty project directory, which becomes the project root of
the hooks and the permission rules (`CLAUDE_PROJECT_DIR`):

```bash
P="$WORK/demo_notes" && mkdir "$P"
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s1-1.jsonl" "/dart-multiplatform-forge:bootstrap-project demo_notes" "${TOOLS[@]}"
```

Expected: prerequisites checked with their commands, then the questions of step 2 (name, org,
platforms, scope, directory, with the current directory recommended), and the turn ends without
creating anything.

```bash
"$H" "$P" "$SID" resume "$WORK/s1-2.jsonl" "Name demo_notes, organization com.example, platform linux only, scope: a single screen listing notes stored locally. Create it in the current directory." "${TOOLS[@]}"
```

Expected: `flutter create`, `git init`, `.forge/`, layout, the four documents; the turn ends on
the two questions of step 7.

```bash
"$H" "$P" "$SID" resume "$WORK/s1-3.jsonl" "Keep the PRD and the TRD in DRAFT for now. Yes, install the permission rules." "${TOOLS[@]}"
```

Expected: `flutter test` and `flutter analyze` run, commit proposed. Observed on 2.1.296: in
`-p --permission-mode dontAsk`, Claude Code denies the write of `.claude/settings.json` even with
`Write` allowed (it protects its configuration files); the skill must not work around it and must
give the copy command instead. Copy the template yourself before scenario 2:
`mkdir -p "$P/.claude" && cp "$PLUGIN/templates/project-settings.json" "$P/.claude/settings.json"`.
Whether the session applies a `.claude/settings.json` written during the session is not verified:
the commit is denied if the project's `ask` rule on `git commit` applies (nobody can answer it in
`-p`), and made otherwise, since `Bash(git *)` is allowed. Either way, the report must match
`git -C "$P" log --oneline`; record which case happened.

## Checks

```bash
(cd "$P" && flutter test)                                   # exit 0
ls "$P/.forge/config.yaml" "$P/.forge/checkpoint.md"
grep -h '^| Status' "$P"/docs/product/PRD.md "$P"/docs/technical/TRD.md \
  "$P"/docs/engineering/IMPLEMENTATION_PLAN.md "$P"/docs/engineering/DECISIONS.md   # DRAFT x4
grep -c ': false' "$P/.forge/config.yaml"                     # 6
jq -e '.permissions.deny | index("Edit(./.forge/config.yaml)")' "$P/.claude/settings.json"
```

**Passed** when every check holds, the turns stopped at both validation points, and no step was
reported without its command.
