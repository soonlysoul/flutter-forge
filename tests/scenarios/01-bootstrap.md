# Scenario 1 — Bootstrap through plugin-orchestrator

**Goal**: in an empty directory where the session is launched, `plugin-orchestrator:bootstrap-project`
mandates `scaffold` to `plugin-flutter:scaffold-engineer`, which creates the Flutter app, its layout,
its TRD in DRAFT and a green base test, and reports at interface 1; the orchestrator writes
`.forge/config.yaml` from the `TOOLCHAIN` block, its root documents and the first commit. Since
1.0, plugin-flutter has no bootstrap of its own. Needs `FORGE_ORCHESTRATOR_DIR` (see README) and
plugin-orchestrator 0.1.1 or later, whose scaffold mandate allows the root `.gitignore` that
`flutter create` writes.

## Steps

The session is launched inside the empty project directory, which becomes the project root of
the hooks and the permission rules (`CLAUDE_PROJECT_DIR`):

```bash
P="$WORK/demo_notes" && mkdir "$P"
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s1-1.jsonl" "/plugin-orchestrator:bootstrap-project une appli de notes en Flutter, demo_notes" "${TOOLS[@]}"
```

Expected: git and jq checked, plugin-flutter named as the part's plugin and found in the session,
then the questions of the orchestrator's step 1 (name, part, package name, organization, platforms,
scope, directory); the turn ends without creating anything.

```bash
"$H" "$P" "$SID" resume "$WORK/s1-2.jsonl" "Projet demo-notes, paquet demo_notes, organisation com.example, plateforme linux seulement, périmètre : un seul écran qui liste des notes stockées localement. Crée-le dans le dossier courant." "${TOOLS[@]}"
```

Expected: `git init`, `orch.sh init`, then one Agent call with `plugin-flutter:scaffold-engineer`
on a mandate that names `interface: 1` and `task: scaffold`. Inside it: `flutter --version`,
`flutter devices`, `flutter create --org com.example --project-name demo_notes --platforms linux
--description "…" .`, the layout, the strict modes, `docs/technical/TRD.md`, `flutter test` and
`flutter analyze`, each alone, no refusal by agent-scope-guard. Its report ends with `SCAFFOLD`,
`TOOLCHAIN`, `PERMISSIONS`, `VERSIONS`, `TARGETS`, then `INTERFACE: 1`. The orchestrator checks it,
writes `.forge/config.yaml` with the toolchain lines as they are, its PRD, DECISIONS (ADR-001 with
the versions) and CLAUDE.md, and ends on its two questions: documents and permissions.

```bash
"$H" "$P" "$SID" resume "$WORK/s1-3.jsonl" "Garde le PRD et le TRD en DRAFT pour l'instant. Oui, installe les règles de permission." "${TOOLS[@]}"
```

Expected: `.claude/settings.json` refused in `dontAsk` (Claude Code protects it) and the command
given instead; `toolchain.test` and `toolchain.analyze` run; the first commit proposed. Copy the
rules yourself before scenario 14: the generic rules of the orchestrator with the Flutter fragment
are `"$PLUGIN/templates/project-settings.json"`.

## Checks

```bash
(cd "$P" && flutter test)                                          # exit 0
grep -x '    plugin: plugin-flutter' "$P/.forge/config.yaml"
grep -x '    interface: 1' "$P/.forge/config.yaml"
grep -x '      test: flutter test' "$P/.forge/config.yaml"
grep -h '^| Status' "$P"/docs/product/PRD.md "$P"/docs/technical/TRD.md "$P"/docs/engineering/DECISIONS.md   # DRAFT x3
ls "$P"/lib/app/.gitkeep "$P"/lib/features/.gitkeep "$P"/integration_test/.gitkeep
grep -q 'strict-casts: true' "$P/analysis_options.yaml"
ls "$P/.github" 2>/dev/null                                         # absent: the CI is a later mandate
jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result") | .content | tostring' "$WORK/s1-2.jsonl" | grep -c '^INTERFACE: 1'
```

**Passed** when every check holds, the scaffold went through the mandate and its report carried
`INTERFACE: 1`, the turns stopped at the orchestrator's validation points, and no step was
reported without its command.
