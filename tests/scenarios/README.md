# Behavioural scenarios — v0.1 to v0.3

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
| 6 | [Adopt an existing app](06-adoption.md) | 2 turns | — |
| 7 | [A commit holding a secret is blocked](07-secret-scan.md) | 1 turn | — |
| 8 | [Debug a failing test](08-debug.md) | 1–2 turns | — |
| 9 | [Pull request with a green CI](09-github-pr.md) | 5–6 turns, a GitHub repository and CI minutes | the user's approval of owner, name, visibility |
| 10 | [Update a batch of dependencies](10-update-deps.md) | 2 turns, pub.dev | — |
| 11 | [Local builds by the devops-engineer](11-devops-build.md) | 1 turn | — |
| 12 | [Diagnose a red CI](12-ci-red.md) | 1 turn, a GitHub repository and CI minutes | the user's approval of owner, name, visibility |

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
