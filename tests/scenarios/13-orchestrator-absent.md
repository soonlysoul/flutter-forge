# Scenario 13 — Without plugin-orchestrator

**Goal**: the two skills of plugin-flutter stop cleanly when plugin-orchestrator is not in the
session: nothing created, changed or committed, plugin-orchestrator named with its installation.

## Setup, without quota

plugin-orchestrator must be absent from the session: `FORGE_ORCHESTRATOR_DIR` unset, and an
installed copy disabled for these sessions only by `FORGE_SESSION_SETTINGS`, which headless.sh
passes as `--settings` (2.1.312, 2026-10-29: `system/init` without plugin-orchestrator, while
`claude plugin list` still shows it enabled). The `system/init` line that headless.sh prints must
not list plugin-orchestrator: otherwise the scenario proves nothing.

```bash
unset FORGE_ORCHESTRATOR_DIR
export FORGE_SESSION_SETTINGS='{"enabledPlugins":{"plugin-orchestrator@soon":false}}'
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name lone_app --platforms linux . >/dev/null
```

```bash
git init -q -b main
```

```bash
git -C <P> add -A
git -C <P> -c user.email=t@example.test -c user.name=T commit -qm "chore: lone_app"
```

## Turns

```bash
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s13-1.jsonl" '/plugin-flutter:adopt-existing-project' "${TOOLS[@]}"
mkdir -p "$P/.forge" && cp "$PLUGIN/templates/forge-config.yaml" "$P/.forge/config.yaml"
"$H" "$P" "$(uuidgen)" new "$WORK/s13-2.jsonl" '/plugin-flutter:update-project' "${TOOLS[@]}"
unset FORGE_SESSION_SETTINGS
```

## Checks

```bash
jq -c 'select(.type == "system" and .subtype == "init") | .plugins' "$WORK"/s13-*.jsonl   # no plugin-orchestrator
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // .input.skill // "")"' "$WORK"/s13-*.jsonl
git -C "$P" status --porcelain                  # only the .forge/ copied before the second turn
git -C "$P" log --oneline                       # one commit
```

- Each skill is invoked, says that it needs plugin-orchestrator 0.1.0 or later, gives
  `claude plugin install plugin-orchestrator@soon --scope user` and a new session, and stops.
- No `flutter pub get`, no branch, no write: the check is the first thing each skill does.

**Passed** when both turns stop on the check with nothing changed.
