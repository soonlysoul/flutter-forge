# Behavioural scenarios — v1.0

These scenarios need a Claude Code session and **consume the subscription quota**. They are never
run by `tests/run-all.sh`. Run them only after the user agreed, with an estimate of the sessions
and turns, and record each result as passed, failed, blocked (reason) or not run.

| # | Scenario | Sessions | Depends on |
| --- | --- | --- | --- |
| 1 | [Bootstrap through plugin-orchestrator](01-bootstrap.md) | 3 headless turns | plugin-orchestrator 0.1.1 |
| 6 | [Adopt an existing app](06-adoption.md) | 2 turns | — |
| 10 | [Update a batch of dependencies](10-update-deps.md) | 2 turns, pub.dev | — |
| 11 | [Local builds by the devops-engineer](11-devops-build.md) | 1 turn | — |
| 12 | [Diagnose a red CI](12-ci-red.md) | 1 turn, a GitHub repository and CI minutes | the user's approval of owner, name, visibility |
| 13 | [Without plugin-orchestrator](13-orchestrator-absent.md) | 2 turns | the installed plugin-orchestrator disabled for the session (`FORGE_SESSION_SETTINGS`) |
| 14 | [The v0.1 criterion of plugin-orchestrator](14-v0.1-criterion.md) | 2–4 turns | the project of scenario 1 |

Since 1.0 the workflows are plugin-orchestrator's, with their own evaluations in that repository:
scenarios 2 (feature in TDD), 3 (preservation), 4 (blocking `git reset --hard`), 5 (recovery),
7 (secret scan), 8 (debug) and 9 (pull request) left with them. Numbers are kept for history.

Every scenario but 13 needs plugin-orchestrator beside this checkout: set `FORGE_ORCHESTRATOR_DIR`
to a checkout of it, which `headless.sh` loads with a second `--plugin-dir` (repeatable, per
`claude --help` on 2.1.309; both load as `@inline`, shadowing the installed copies).

## Common setup

```bash
PLUGIN=<absolute path of this plugin checkout>
WORK=$(mktemp -d)            # always outside the plugin directory
export FORGE_ALLOW_QUOTA=1   # only after the user agreed
export FORGE_ORCHESTRATOR_DIR=<absolute path of a plugin-orchestrator checkout>
H="$PLUGIN/tests/scenarios/headless.sh"
```

`headless.sh <workdir> <session-uuid> <new|resume> <transcript.jsonl> <prompt> <allowed tool>...`
runs one turn with `claude -p --plugin-dir "$PLUGIN" [--plugin-dir "$FORGE_ORCHESTRATOR_DIR"] --output-format stream-json --verbose
--include-hook-events --permission-mode dontAsk`, then prints:

- the `system/init` event's `plugins` and `plugin_errors`: the proof that the plugin is loaded;
- the `result` event (field names not verified on 2.1.296: an absent field prints `null`).

A multi-turn scenario reuses one session: the first turn uses `new` with a fresh `uuidgen`, the
next ones `resume` with the same id.

Allowed tools used by the scenarios (`$TOOLS`):

```bash
TOOLS=(Read Write Edit Glob Grep Skill Agent "Bash(flutter *)" "Bash(dart *)" "Bash(git *)" "Bash(jq *)" "Bash(ls *)" "Bash(mkdir *)" "Bash(touch *)" "Bash(bash *)")
```

`Bash(bash *)` lets the orchestrator's skills run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/orch.sh …`
(`init`, `checkpoint`, `status`, `approve`): in `dontAsk`, a command outside `--allowedTools` is
denied, and scenarios 1 and 14 would stop at their first state write.

`Bash(git *)` deliberately allows every git command at the permission layer: the guard hooks of
plugin-orchestrator block on their own.

## Evidence to keep

For every turn: the transcript (`.jsonl`), and after the scenario `git status --short`,
`git log --oneline`, `.forge/checkpoint.md`. Useful queries:

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.command // .input.file_path // .input.skill // .input.subagent_type // "")"' run.jsonl
jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result" and (.content | tostring | test("plugin-flutter"))) | .content' run.jsonl
jq -rs -f "$PLUGIN/tests/scenarios/interface-reports.jq" run.jsonl   # one line per Agent call: INTERFACE: 1 or MISSING
```

## Observed on Claude Code 2.1.296 (2026-10-19)

- A plugin skill is invoked in a `-p` prompt as `/plugin-flutter:<skill> <args>`.
- `system/init` lists `plugin-flutter@inline` under `plugins`, with `plugin_errors: null`.
- In `--permission-mode dontAsk`:
  - a compound command (`a; b`) is denied unless every part is allowed;
  - the write of `.claude/settings.json` is denied even with `Write` allowed, because Claude Code protects its configuration files;
  - the project's `ask` rule on `git commit` becomes a denial.
- In a folder that was never trusted, stderr says `Ignoring N permissions.allow entries from .claude/settings.json: this workspace has not been trusted`.
- 2026-10-20 (scenarios 7 to 9): the user's own `~/.claude/settings.json` rule `ask` on `git push` becomes a denial in `dontAsk`, so the user pushes; a `PreToolUse` hook `ask` (protect-sensitive) becomes a denial whose reason Claude reads; a command piped to a tool outside `--allowedTools` (`| tail`) is denied. Already installed plugins load too (here `flutter-forge` 0.1.1).
- 2026-10-20 (v0.3 setup): the installed secret-scan refuses `git init` on the line of a `git commit`, and a commit whose directory is held in a variable (`cd "$P"`, `git -C "$P"`). The setups of scenarios 6 and 10 to 12 therefore split `git init` into its own block, and write the project path literally (`<P>`) when Claude runs them.
- 2026-10-20 (v0.3, scenarios 6, 10 to 12): with `--plugin-dir`, `system/init` lists only
  `plugin-flutter@inline` 0.3.0, the installed `plugin-flutter@soon` 0.2.0 being shadowed: the
  scenarios test this checkout's hooks and agents. The `result` of a turn is its last message: when
  the Stop hook resumes Claude, it holds only the checkpoint update. Each turn reports its own
  `total_cost_usd`; a long resumed session costs more per turn (scenario 6: 0.79, 1.15, 3.73 and
  4.51 $). In auto mode, the permission classifier refused `gh repo create` to the operating
  session: the user ran the GitHub setup of scenario 12.
- Still not verified: whether `stream-json` requires `--verbose` (always passed); `--max-turns` (never used); the `!` prefix against `PreToolUse` (interactive only).

## Observed on Claude Code 2.1.312 (2026-10-29, v1.0)

- An Agent call may run in the background even in `-p`: its `tool_result` only says the agent was
  launched, and the report arrives as the subagent's messages (`parent_tool_use_id`) followed by a
  `system/task_notification`. A synchronous call returns the report framed as a "[Subagent
  hand-back]", every line indented by two spaces. A check on `^INTERFACE: 1` in `tool_result`
  misses both: `interface-reports.jq` reads both forms.
- In `dontAsk`, a Bash command is also denied when it sets or expands a variable (`D=…; cd "$D"`),
  reads `$?` or `PIPESTATUS`, or pipes into a tool outside `--allowedTools` (`| tail`). The
  orchestrator's skills stop on such a denial without working around it; one turn answering "one
  command at a time, paths written out, no `$?`" lets them go on.
- `--settings '<json>'` applies to that session only: `{"enabledPlugins":{"plugin-orchestrator@soon":false}}`
  removes the installed orchestrator from `system/init`, `claude plugin list` unchanged
  (scenario 13, `FORGE_SESSION_SETTINGS`).
- Flutter 3.44.4 of nixpkgs: its launcher sets `FLUTTER_ROOT` to the unwrapped SDK, which has no
  `bin/cache/pkg/sky_engine`, and every `pub get` fails. Exporting `FLUTTER_ROOT` to the
  `flutter-wrapped-3.44.4-sdk-links` path of the store, with the wrapped `flutter` on the `PATH`,
  makes `flutter create`, `test`, `analyze` and `build linux|web` work. Machine setup only.
