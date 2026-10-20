# Behavioural scenarios — v0.1 and v0.2

These scenarios need a Claude Code session and **consume the subscription quota**. They are never
run by `tests/run-all.sh`. Run them only after the user agreed, with an estimate of the sessions
and turns, and record each result as passed, failed, blocked (reason) or not run.

| # | Scenario | Sessions | Depends on |
| --- | --- | --- | --- |
| 1 | [Bootstrap](01-bootstrap.md) | 3 headless turns | — |
| 2 | [Feature in TDD](02-feature-tdd.md) | 2–3 turns | the project of scenario 1 |
| 3 | [Preservation of uncommitted work](03-preservation.md) | 1 turn | the project of scenario 1 |
| 4 | [Blocking `git reset --hard`](04-blocking.md) | 1 turn | — |
| 5 | [Recovery after an interruption](05-recovery.md) | 1 turn | the project of scenario 2 |
| 7 | [A commit holding a secret is blocked](07-secret-scan.md) | 1 turn | — |
| 8 | [Debug a failing test](08-debug.md) | 1–2 turns | — |
| 9 | [Pull request with a green CI](09-github-pr.md) | 5–6 turns, a GitHub repository and CI minutes | the user's approval of owner, name, visibility |

Scenario 6 of ARCHITECTURE.md (existing repository) belongs to adopt-existing-project, v0.3.

## Common setup

```bash
PLUGIN=<absolute path of this plugin checkout>
WORK=$(mktemp -d)            # always outside the plugin directory
export FORGE_ALLOW_QUOTA=1   # only after the user agreed
H="$PLUGIN/tests/scenarios/headless.sh"
```

`headless.sh <workdir> <session-uuid> <new|resume> <transcript.jsonl> <prompt> <allowed tool>...`
runs one turn with `claude -p --plugin-dir "$PLUGIN" --output-format stream-json --verbose
--include-hook-events --permission-mode dontAsk`, then prints:

- the `system/init` event's `plugins` and `plugin_errors`: the proof that the plugin is loaded;
- the `result` event (field names not verified on 2.1.296: an absent field prints `null`).

A multi-turn scenario reuses one session: the first turn uses `new` with a fresh `uuidgen`, the
next ones `resume` with the same id.

Allowed tools used by the scenarios (`$TOOLS`):

```bash
TOOLS=(Read Write Edit Glob Grep Skill Agent "Bash(flutter *)" "Bash(dart *)" "Bash(git *)" "Bash(jq *)" "Bash(ls *)" "Bash(mkdir *)" "Bash(touch *)")
```

`Bash(git *)` deliberately allows every git command at the permission layer, so that scenario 4
proves the hook blocks on its own.

## Evidence to keep

For every turn: the transcript (`.jsonl`), and after the scenario `git status --short`,
`git log --oneline`, `.forge/checkpoint.md`. Useful queries:

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // .input.skill // .input.subagent_type // "")"' run.jsonl
jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result" and (.content | tostring | test("plugin-flutter"))) | .content' run.jsonl
```

## Observed on Claude Code 2.1.296 (2026-10-19)

- A plugin skill is invoked in a `-p` prompt as `/plugin-flutter:<skill> <args>`.
- `system/init` lists `plugin-flutter@inline` under `plugins`, with `plugin_errors: null`.
- In `--permission-mode dontAsk`:
  - a compound command (`a; b`) is denied unless every part is allowed;
  - the write of `.claude/settings.json` is denied even with `Write` allowed, because Claude Code protects its configuration files;
  - the project's `ask` rule on `git commit` becomes a denial.
- In a folder that was never trusted, stderr says `Ignoring N permissions.allow entries from .claude/settings.json: this workspace has not been trusted`.
- Still not verified: whether `stream-json` requires `--verbose` (always passed); `--max-turns` (never used); the `!` prefix against `PreToolUse` (interactive only).
