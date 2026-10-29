#!/usr/bin/env bash
# The agents at interface 1 of plugin-orchestrator's delegation contract: the INTERFACE: 1 echo the
# orchestrator checks before using a report, the mandates each agent takes and the sections of its
# report. A content check, like test_maintenance_skills: it proves the instruction is written, not
# that it is followed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_agents
AGENTS="$PLUGIN_ROOT/agents"
TE="$AGENTS/test-engineer.md"
CR="$AGENTS/code-reviewer.md"
FA="$AGENTS/flutter-architect.md"
DEVOPS="$AGENTS/devops-engineer.md"
SC="$AGENTS/scaffold-engineer.md"

# says <file> <label> <fixed string>
says() { grep -qiF -- "$3" "$1" && pass "$2" || fail "$2" "missing: $3"; }

# report_block <file>: the fenced block of the "## Report" section.
report_block() { awk '/^## Report/{r=1; next} r && /^```/{if (f) exit; f=1; next} f' "$1"; }

# sections <file>: the upper-case section names of its report block, in order.
sections() { report_block "$1" | grep -oE '^[A-Z_]+:' | tr -d : | tr '\n' ' '; }

echo "# the common tail, INTERFACE: 1 first"
TAIL="INTERFACE STATUS FILES_CHANGED COMMANDS_RUN OPEN_QUESTIONS "
for file in "$AGENTS"/*.md; do
  agent=${file##*/} agent=${agent%.md}
  block=$(report_block "$file")
  if [[ -z $block ]]; then
    fail "$agent: report block under ## Report"
    continue
  fi
  pass "$agent: report block under ## Report"
  [[ $(sections "$file") == *"$TAIL" ]] && pass "$agent: the report ends with INTERFACE, STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS" \
    || fail "$agent: the report ends with INTERFACE, STATUS, FILES_CHANGED, COMMANDS_RUN, OPEN_QUESTIONS" "sections: $(sections "$file")"
  grep -qx 'INTERFACE: 1' <<<"$block" && pass "$agent: the echo is exactly INTERFACE: 1" \
    || fail "$agent: the echo is exactly INTERFACE: 1" "$(grep '^INTERFACE' <<<"$block")"
  (($(grep -c '^INTERFACE:' <<<"$block") == 1)) && pass "$agent: one INTERFACE line" || fail "$agent: one INTERFACE line"
  [[ $(tail -n 2 <<<"$block" | head -n 1) == OPEN_QUESTIONS: ]] && pass "$agent: nothing after the OPEN_QUESTIONS item" \
    || fail "$agent: nothing after the OPEN_QUESTIONS item" "$(tail -n 3 <<<"$block")"
  says "$file" "$agent: speaks interface 1 of plugin-orchestrator's delegation contract" "interface 1 of the delegation contract of plugin-orchestrator"
  says "$file" "$agent: does not carry out a mandate of another interface" "A mandate that names another interface is not carried out"
  says "$file" "$agent: says which interface it was asked" "saying which interface was asked"
  grep -qE '^description:.*plugin-orchestrator' "$file" && pass "$agent: its description names the mandates of plugin-orchestrator" \
    || fail "$agent: its description names the mandates of plugin-orchestrator" "$(grep '^description:' "$file")"
done

echo "# test-engineer"
says "$TE" "takes the write-tests mandate" "\`write-tests\`"
[[ $(sections "$TE") == "TESTS_WRITTEN EDGE_CASES RED_OUTPUT $TAIL" ]] && pass "test-engineer: TESTS_WRITTEN, EDGE_CASES, RED_OUTPUT, then the tail" \
  || fail "test-engineer: TESTS_WRITTEN, EDGE_CASES, RED_OUTPUT, then the tail" "$(sections "$TE")"
says "$TE" "a debug-project mandate asks one regression test" "one regression test"
says "$TE" "names the regression test after what failed" "regression: <what failed>"
says "$TE" "the regression test fails for the root cause given" "for the root cause"
says "$TE" "integration tests take the device of toolchain.integration_test" "toolchain.integration_test"
says "$TE" "reports a test that already passes" "already pass"

echo "# code-reviewer"
says "$CR" "takes the review mandate" "\`review\`"
[[ $(sections "$CR") == "FINDINGS DOCS_TO_UPDATE DIVERGENCES $TAIL" ]] && pass "code-reviewer: FINDINGS, DOCS_TO_UPDATE, DIVERGENCES, then the tail" \
  || fail "code-reviewer: FINDINGS, DOCS_TO_UPDATE, DIVERGENCES, then the tail" "$(sections "$CR")"
says "$CR" "the staged diff is against the default branch" "--cached <default branch>"
grep -qF -- '--cached main' "$CR" && fail "no --cached main left" "$(grep -nF -- '--cached main' "$CR")" || pass "no --cached main left"
says "$CR" "a debug-project review gets the root cause" "root cause"
says "$CR" "a fix that hides the symptom is blocking" "hides the symptom"

echo "# flutter-architect"
says "$FA" "takes the check-dependency mandate" "\`check-dependency\`"
says "$FA" "takes the diagnose mandate" "\`diagnose\`"
[[ $(sections "$FA") == "DEPENDENCY ADR DIAGNOSIS FIX_DIRECTION $TAIL" ]] && pass "flutter-architect: DEPENDENCY, ADR, DIAGNOSIS, FIX_DIRECTION, then the tail" \
  || fail "flutter-architect: DEPENDENCY, ADR, DIAGNOSIS, FIX_DIRECTION, then the tail" "$(sections "$FA")"
says "$FA" "only the sections of the task asked" "leave out the sections of the other tasks"
says "$FA" "writes nothing on a check-dependency or a diagnose mandate" "Nothing is written on a \`check-dependency\` or a \`diagnose\` mandate"
says "$FA" "a verdict without evidence is not verified" "a verdict without its evidence"
says "$FA" "starts a new TRD from the template" "templates/doc-templates/TRD.md"
says "$FA" "starts a new DECISIONS.md from the template" "templates/doc-templates/DECISIONS.md"
says "$FA" "reads the platforms of the part" "\`platforms\` of the part"

echo "# devops-engineer"
for task in ci-template build ci-diagnosis workflow-change; do says "$DEVOPS" "takes the $task mandate" "\`$task\`"; done
[[ $(sections "$DEVOPS") == "BUILDS CI $TAIL" ]] && pass "devops-engineer: BUILDS, CI, then the tail" \
  || fail "devops-engineer: BUILDS, CI, then the tail" "$(sections "$DEVOPS")"
says "$DEVOPS" "ci-template fills the plugin's CI template" "templates/github-workflows/flutter-ci.yml"
says "$DEVOPS" "ci-template pins the local Flutter version" "__FLUTTER_VERSION__"
says "$DEVOPS" "ci-template sets the default branch" "__DEFAULT_BRANCH__"
says "$DEVOPS" "ci-template writes the file the mandate names" "the file the mandate names"
says "$DEVOPS" "reads the platforms of the part" "\`platforms\` of the part"
grep -qF 'platforms.enabled' "$DEVOPS" && fail "no platforms.enabled left (schema 1)" "$(grep -nF 'platforms.enabled' "$DEVOPS")" \
  || pass "no platforms.enabled left (schema 1)"
# Scenario 11 (v0.3): doctor showed `[✗] Android toolchain`, the agent built android anyway and
# reported it failed. The step that runs builds must itself leave out a platform doctor rules out.
# The rerun then blocked web on `[✗] Chrome`, which only runs a web app: each platform is tied to
# the doctor section its build needs.
says "$DEVOPS" "builds only the platforms doctor does not rule out" "whose build section in \`flutter doctor -v\` is not marked \`[✗]\`"
says "$DEVOPS" "a platform doctor rules out is blocked, its build not run" "is **blocked**, with that line as the reason: do not run its build"
says "$DEVOPS" "names the doctor section each platform's build needs" "| android | \`flutter build apk --debug\` | Linux, macOS, Windows | Android toolchain |"
says "$DEVOPS" "a missing Chrome does not block the web build" "a missing Chrome does not block \`flutter build web\`"
# Review of v0.3 (M6): the warning rule, the other platforms, and the old contradictory sentence gone.
says "$DEVOPS" "a [!] warning does not block a build" "A \`[!]\` warning does not block either"
says "$DEVOPS" "linux needs the Linux toolchain section" "| linux | \`flutter build linux\` | Linux | Linux toolchain |"
says "$DEVOPS" "ios needs Xcode" "| ios | \`flutter build ios --no-codesign\` | macOS | Xcode |"
grep -qiF "run it once anyway" "$DEVOPS" && fail "the old 'run it once anyway' sentence is gone" "still there" \
  || pass "the old 'run it once anyway' sentence is gone"

echo "# scaffold-engineer"
if [[ -f $SC ]]; then
  says "$SC" "takes the scaffold mandate" "\`scaffold\`"
  [[ $(sections "$SC") == "SCAFFOLD TOOLCHAIN PERMISSIONS VERSIONS TARGETS $TAIL" ]] \
    && pass "scaffold-engineer: SCAFFOLD, TOOLCHAIN, PERMISSIONS, VERSIONS, TARGETS, then the tail" \
    || fail "scaffold-engineer: SCAFFOLD, TOOLCHAIN, PERMISSIONS, VERSIONS, TARGETS, then the tail" "$(sections "$SC")"
  says "$SC" "creates the app with flutter create in the project root" "flutter create --org <org> --project-name <name> --platforms <platforms> --description"
  says "$SC" "never overwrites an existing file" "--overwrite"
  says "$SC" "scaffolds only the project at the session root" ".forge/\` at the session root"
  says "$SC" "the toolchain lines come from the plugin's config template" "templates/forge-config.yaml"
  says "$SC" "the permission fragment comes from the plugin's template" "templates/permissions-fragment.json"
  says "$SC" "the permission fragment is returned, never written" "never written to \`.claude/settings.json\`"
  says "$SC" "the TRD starts from the template, in DRAFT" "templates/doc-templates/TRD.md"
  says "$SC" "adds the strict analyzer modes" "strict-casts: true"
  says "$SC" "creates the feature-first layout" "lib/features/"
  says "$SC" "leaves the root documents to the orchestrator" "docs/engineering/"
  says "$SC" "leaves the CI to the ci-template mandate" "\`ci-template\`"
  says "$SC" "runs the base test" "\`flutter test\`"
  says "$SC" "runs the analyzer" "\`flutter analyze\`"
  says "$SC" "never commits" "no commit"
  says "$SC" "a target is built only with its command" "built only with"
  says "$SC" "a disabled desktop platform is the user's decision" "flutter config --enable-"
else
  fail "agents/scaffold-engineer.md exists"
fi

finish
