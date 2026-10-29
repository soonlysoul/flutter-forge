# Scenario 11 — Local builds by the devops-engineer

**Goal**: the `build` mandate of the devops-engineer at interface 1, as plugin-orchestrator's
github-workflow sends it. The agent builds each platform of the part this host can build, classifies the others, keeps the three states
apart (enabled, built, tested), stays inside its allowlist, and the main session checks its main
claim before presenting it.

## Setup, without quota

Three platforms enabled: Linux and web build here; Android needs an SDK this machine may lack.

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name build_app --platforms linux,web,android . >/dev/null
mkdir -p .forge/reports && touch .forge/reports/.gitkeep
cp "$PLUGIN/templates/forge-config.yaml" .forge/config.yaml       # platforms: [android, web, linux]
cp "$PLUGIN/templates/checkpoint.md" .forge/checkpoint.md
```

```bash
git init -q -b main
```

```bash
git -C <P> add -A
git -C <P> -c user.email=t@example.test -c user.name=T commit -qm "chore: build_app"
```

## Turn

```bash
SID=$(uuidgen)
"$H" "$P" "$SID" new "$WORK/s11-1.jsonl" "Envoie à l'agent plugin-flutter:devops-engineer un mandat build à l'interface 1 (interface: 1, task: build, la partie app de .forge/config.yaml avec ses platforms), attends son rapport, vérifie son affirmation principale, puis présente son tableau BUILDS." "${TOOLS[@]}"
```

## Checks

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name) \(.input.subagent_type // .input.command // .input.file_path // "")"' "$WORK/s11-1.jsonl"
jq -r 'select(.type == "user") | .message.content[]? | select(.type == "tool_result" and (.content | tostring | test("agent-scope-guard"))) | .content' "$WORK/s11-1.jsonl"
ls "$P"/build/linux/x64/release/bundle/build_app "$P"/build/web/index.html
git -C "$P" status --porcelain                        # nothing outside build/ (ignored)
```

- One Agent call with `plugin-flutter:devops-engineer`, whose report ends with `INTERFACE: 1`; inside it, `flutter --version`,
  `flutter doctor -v`, then one `flutter build` per platform, each alone.
- BUILDS: `linux` and `web` built with their command and exit 0, web even without Chrome, which
  only runs a web app; `android` built, or, when doctor marks the Android toolchain `[✗]`, blocked
  with that line and its build not run; no platform marked tested.
- The main session checks the artifacts it reports (Glob, Read or `ls`), not only the report.
- No refusal by agent-scope-guard, or a refusal the agent reported without working around it.

**Passed** when the table is true to the commands, the artifacts exist for every platform called
built, and nothing was written outside `build/`.
