#!/usr/bin/env bash
# The two skills plugin-flutter keeps in 1.0 — update-project and adopt-existing-project — with
# plugin-orchestrator beside them, and the divergence check of the code-reviewer. A content check,
# like test_agents: it proves the instruction is written, not that it is followed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_maintenance_skills
UP="$PLUGIN_ROOT/skills/update-project/SKILL.md"
REPORT="$PLUGIN_ROOT/skills/update-project/reference/deps-report.md"
AD="$PLUGIN_ROOT/skills/adopt-existing-project/SKILL.md"
DIV="$PLUGIN_ROOT/skills/adopt-existing-project/reference/divergences.md"
CR="$PLUGIN_ROOT/agents/code-reviewer.md"
FA="$PLUGIN_ROOT/agents/flutter-architect.md"

# says <file> <label> <fixed string>
says() { grep -qiF -- "$3" "$1" && pass "$2" || fail "$2" "missing: $3"; }

# only_in <file> <label> <regex> <sentence>...: the regex appears nowhere once the exact sentences
# that forbid the command or hand it to the user are removed. A line merely containing "never"
# proves nothing ("run it yourself, never ask"), so the allowed sentences are pinned word for word.
only_in() {
  local file=$1 label=$2 regex=$3 text sentence bad
  shift 3
  text=$(<"$file")
  for sentence in "$@"; do
    [[ $text == *"$sentence"* ]] || { fail "$label" "allowed sentence missing: $sentence"; return; }
    text=${text//"$sentence"/}
  done
  bad=$(grep -nE -- "$regex" <<<"$text")
  [[ -z $bad ]] && pass "$label" || fail "$label" "$bad"
}

echo "# update-project"
if [[ -f $UP ]]; then
  says "$UP" "reads the inventory as JSON, without changing a file" "flutter pub outdated --json"
  says "$UP" "classifies with the upgradable and resolvable columns" "resolvable"
  says "$UP" "puts advisories first" "isCurrentAffectedByAdvisory"
  says "$UP" "flags discontinued packages" "isDiscontinued"
  says "$UP" "compatible batch: flutter pub upgrade" "\`flutter pub upgrade\`"
  says "$UP" "one batch per major: --major-versions" "flutter pub upgrade --major-versions <package>"
  says "$UP" "validation point: the plan of batches" "plan of batches"
  says "$UP" "every major is validated with its changelog" "pub.dev/packages/<package>/changelog"
  says "$UP" "works on a chore/deps- branch" "chore/deps-<slug>"
  says "$UP" "checks the lockfile matches before anything" "flutter pub get --enforce-lockfile"
  says "$UP" "records a baseline" "baseline"
  says "$UP" "a red baseline stops" "A red baseline stops"
  says "$UP" "runs the analyzer after each batch" "flutter analyze"
  says "$UP" "runs the tests after each batch" "flutter test"
  says "$UP" "commits the lockfile" "pubspec.lock"
  says "$UP" "commits the regenerated plugin registrants" "generated_plugin_registrant"
  says "$UP" "one commit per batch" "chore(deps):"
  says "$UP" "reads the breaking changes in the cached CHANGELOG.md" "CHANGELOG.md"
  says "$UP" "finds the cache through package_config.json" ".dart_tool/package_config.json"
  says "$UP" "checks a plugin's platforms against those of the part" "the \`platforms\` of the part"
  says "$UP" "records an ADR for a major" "ADR"
  says "$UP" "a dropped batch is restored by the user" "! git restore pubspec.yaml pubspec.lock"
  says "$UP" "never forces a resolution with dependency_overrides" "dependency_overrides"
  says "$UP" "detects a Flutter provided by Nix" "/nix/store/"
  says "$UP" "reads flutterRoot from the machine output" "flutter --version --machine"
  says "$UP" "reminds the CI pin after an SDK change" "flutter-version"
  says "$UP" "names the CI workflow file" ".github/workflows/ci.yml"
  says "$UP" "writes the before/after report under .forge/reports/" ".forge/reports/deps-"
  says "$UP" "fills the report template" "skills/update-project/reference/deps-report.md"
  says "$UP" "runs each command alone, as the permission rules expect" "one command per call"
  says "$UP" "two identical failures stop" "fails twice with the same error"
  says "$UP" "writes the checkpoint" "skill: update-project"
  for category in "**passed**" "**failed**" "**blocked**" "**not run**"; do says "$UP" "report category $category" "$category"; done
  only_in "$UP" "never runs flutter upgrade, downgrade or channel itself" 'flutter (upgrade|downgrade|channel)' \
    'Never run `flutter upgrade`, `flutter downgrade` or `flutter channel <name>`: they change Flutter for every project on this machine.' \
    'Otherwise the user runs `! flutter upgrade` themselves, knowing it changes Flutter for every project on this machine.'
  only_in "$UP" "uses flutter pub, never dart pub" 'dart pub' \
    '**`flutter pub`, never `dart pub`.** In a Flutter project, `dart pub` fails with exit 69 when the `dart` on the PATH is not the Flutter one, as on NixOS.'
  only_in "$UP" "never forces a resolution with dependency_overrides (no other mention)" 'dependency_overrides' \
    'Never edit `pubspec.lock` by hand, and never add `dependency_overrides` to force a resolution: a conflict goes to the user.'
  # Review of v0.3 (Important 5, 6; minor items).
  says "$UP" "dropping a batch restores every file it changed" "every file the batch changed"
  says "$UP" "after a drop, analysis and tests are compared with the baseline again" "compare them with the baseline"
  says "$UP" "the after versions include up-to-date packages" "flutter pub outdated --json --show-all"
  says "$UP" "a stale lockfile is synced in its own commit, on the branch" "chore(deps): sync pubspec.lock with pubspec.yaml"
  says "$UP" "a flagged package moves alone" "\`flutter pub upgrade <package>\`"
  step7=$(awk '/^## Step 7 /{f=1; print; next} /^## /{f=0} f' "$UP")
  [[ $step7 == *".forge/checkpoint.md"* ]] && pass "the file check of a batch exempts the checkpoint" \
    || fail "the file check of a batch exempts the checkpoint" "step 7 does not name .forge/checkpoint.md"
  says "$UP" "explains a held-back package without changing a file" "flutter pub add --dry-run"
  says "$UP" "checks formatting after an SDK change" "dart format --output=none --set-exit-if-changed ."
  says "$UP" "a package argument narrows the plan" "When the request names packages"
  # Counter-verification of the v0.3 review.
  says "$UP" "counts transitive changes by package, not by diff line" "packages whose \`version:\` changed"
  says "$UP" "the stale-lock branch is not created twice" "unless step 3 already created it"
  says "$UP" "the sync commit carries the registrants it regenerated" "and the plugin registrants it regenerated"
  says "$UP" "the report starts after the sync commit" "the sync commit"
  step3=$(awk '/^## Step 3 /{f=1; print; next} /^## /{f=0} f' "$UP")
  [[ $step3 == *"dart format --output=none --set-exit-if-changed ."* ]] && pass "the baseline records formatting" \
    || fail "the baseline records formatting" "step 3 has no dart format"
  [[ $step7 == *'`flutter pub upgrade <package> [<package>]`'* ]] && pass "named packages move alone in a batch" \
    || fail "named packages move alone in a batch" "step 7 lacks flutter pub upgrade <package> [<package>]"
else
  fail "skills/update-project/SKILL.md exists"
fi

echo "# dependency report template"
if [[ -f $REPORT ]]; then
  for section in "## Batches" "## Direct and dev dependencies" "## Not updated" "## Checks" "## Breaking changes handled"; do
    says "$REPORT" "report has $section" "$section"
  done
  says "$REPORT" "checks before and after" "| check | before (baseline) | after |"
  says "$REPORT" "versions before and after" "| package | kind | before | after | type | batch |"
  says "$REPORT" "SDK before and after" "| Flutter |"
  says "$REPORT" "says whether the lockfile is committed" "| Lockfile |"
  says "$REPORT" "records the CI pin" "| CI pin |"
  says "$REPORT" "analysis and tests after each batch" "| # | Command | Packages | Commit | analyze | test | Result |"
  says "$REPORT" "counts transitive changes by package, not by diff line" "packages whose \`version:\` changed"
else
  fail "skills/update-project/reference/deps-report.md exists"
fi

echo "# adopt-existing-project"
if [[ -f $AD ]]; then
  grep -qiE '^description:.*not for a new' "$AD" && pass "description excludes a new app (bootstrap-project)" \
    || fail "description excludes a new app (bootstrap-project)" "$(grep '^description:' "$AD")"
  says "$AD" "nothing existing is rewritten without an approved plan" "Nothing existing is rewritten without an approved plan"
  says "$AD" "the analysis is read-only" "read-only"
  says "$AD" "proves nothing changed with git status --porcelain" "git status --porcelain"
  says "$AD" "resolves without rewriting the lockfile" "flutter pub get --enforce-lockfile"
  says "$AD" "analyzes without an implicit pub get" "flutter analyze --no-pub"
  says "$AD" "tests without an implicit pub get" "flutter test --no-pub"
  says "$AD" "stops when .forge/ already exists" "already adopted"
  says "$AD" "an adopted project goes on with plugin-orchestrator" "plugin-orchestrator:recover-session"
  says "$AD" "stops when the app is in a subdirectory" "subdirectory"
  says "$AD" "validation point: the compliance plan" "compliance plan"
  says "$AD" "existing files are modified only on a separate approval each" "approved separately"
  says "$AD" "an existing document is kept, never replaced" "never replaced"
  says "$AD" "never moves code" "Never move"
  says "$AD" "works on chore/adopt-plugin-flutter" "chore/adopt-plugin-flutter"
  says "$AD" "creates .forge/config.yaml from the template" "templates/forge-config.yaml"
  says "$AD" "rebuilds the PRD with the product-architect of plugin-orchestrator" "plugin-orchestrator:product-architect"
  says "$AD" "product-architect task reconstruct" "reconstruct"
  says "$AD" "creates the plan from the template" "templates/doc-templates/IMPLEMENTATION_PLAN.md"
  says "$AD" "creates CLAUDE.md from the template" "templates/doc-templates/CLAUDE.md"
  says "$AD" "proposes the generic rules with the Flutter fragment" "templates/project-settings.json"
  says "$AD" "rebuilds the TRD and the ADRs with the flutter-architect" "flutter-architect"
  says "$AD" "rebuilt documents stay DRAFT" "DRAFT"
  says "$AD" "ADRs of existing dependencies are proposed" "proposed"
  says "$AD" "lists the divergences in .forge/reports/" ".forge/reports/divergences-"
  says "$AD" "uses the divergence checklist" "skills/adopt-existing-project/reference/divergences.md"
  says "$AD" "regenerated plugin registrants are reported" "registrant"
  says "$AD" "writes the checkpoint once .forge/ exists" "skill: adopt-existing-project"
  says "$AD" "runs each command alone, as the permission rules expect" "one command per call"
  says "$AD" "two identical failures stop" "fails twice with the same error"
  for category in "**passed**" "**failed**" "**blocked**" "**not run**"; do says "$AD" "report category $category" "$category"; done
  # Before the plan (steps 1 to 4), every flutter command that could run pub get must not.
  # The one sentence that forbids the plain forms is removed word for word, nothing else.
  rule='Before the plan is approved, never run `flutter pub get` without `--enforce-lockfile`, nor `flutter analyze` or `flutter test` without `--no-pub`: a plain one runs `pub get`, which rewrites a `pubspec.lock` that does not match `pubspec.yaml`.'
  before_plan=$(awk '/^## Step 5 /{exit} {print}' "$AD")
  [[ $before_plan == *"$rule"* ]] && pass "states the no pub get rule" || fail "states the no pub get rule" "missing: $rule"
  before_plan=${before_plan//"$rule"/}
  bad=$(grep -oE '`flutter (analyze|test)[^`]*`' <<<"$before_plan" | grep -v -- '--no-pub')
  [[ -z $bad ]] && pass "before the plan, flutter analyze and test always carry --no-pub" || fail "before the plan, flutter analyze and test always carry --no-pub" "$bad"
  bad=$(grep -oE '`flutter pub get[^`]*`' <<<"$before_plan" | grep -v -- '--enforce-lockfile')
  [[ -z $bad ]] && pass "before the plan, flutter pub get always carries --enforce-lockfile" || fail "before the plan, flutter pub get always carries --enforce-lockfile" "$bad"
  only_in "$AD" "uses flutter pub, never dart pub" 'dart pub' '**`flutter pub`, never `dart pub`**, which fails with exit 69 when the `dart` on the PATH is not the Flutter one.'
  # Review of v0.3 (Important 1 to 4, 7, 8; minor items).
  says "$AD" "flutter pub deps rewrites a stale lockfile too" "\`flutter pub deps\` rewrites it too"
  says "$AD" "tells the flutter-architect whether the lockfile matches" "whether the lockfile matches"
  says "$AD" "gives a command when the .forge/config.yaml write is refused" "templates/forge-config.yaml > .forge/config.yaml"
  says "$AD" "the adoption reaches the default branch by the user's merge" "The merge is the user's"
  says "$AD" "outside a Git repository, stops" "Outside a Git repository, stop"
  says "$AD" "any uncommitted change stops the adoption" "Any uncommitted change stops the adoption"
  says "$AD" "finds the default branch from the remote" "origin/HEAD"
  says "$AD" "resumes an interrupted adoption from its checkpoint" "resume from its next action"
  says "$AD" "lists new untracked files too" "--untracked-files=all"
  # Counter-verification of the v0.3 review.
  says "$AD" "the baseline records formatting" "dart format --output=none --set-exit-if-changed ."
  says "$AD" "github-workflow pr only after a clean baseline" "When the baseline was clean"
  says "$AD" "the checkpoint keeps the step-2 baseline" "baseline of step 2"
  step5=$(awk '/^## Step 5 /{f=1; print; next} /^## /{f=0} f' "$AD")
  checkpoint_at=$(grep -n '^[0-9]\..*`\.forge/checkpoint\.md`' <<<"$step5" | head -1 | cut -d: -f1)
  config_at=$(grep -n '^[0-9]\..*`\.forge/config\.yaml`' <<<"$step5" | head -1 | cut -d: -f1)
  [[ -n $checkpoint_at && -n $config_at ]] && ((checkpoint_at < config_at)) \
    && pass "the checkpoint exists before the .forge/config.yaml wait" \
    || fail "the checkpoint exists before the .forge/config.yaml wait" "checkpoint item line ${checkpoint_at:-none}, config item line ${config_at:-none}"
  says "$AD" "the sed survives a branch with a slash" "s|^  default_branch: .*|"
  says "$AD" "the sed sets the platforms of the part" "s|^    platforms: .*|"
  says "$AD" "creates the branch itself: plugin-orchestrator's git-workflow needs .forge/" "\`git switch -c chore/adopt-plugin-flutter\`"
  says "$AD" "relies on the exit code of git rev-parse origin/HEAD" "only exit 0 counts"
else
  fail "skills/adopt-existing-project/SKILL.md exists"
fi

echo "# divergence checklist"
if [[ -f $DIV ]]; then
  for category in dependencies "acceptance criteria" plan README platforms toolchain lockfile layout analysis tests secrets; do
    says "$DIV" "checks $category" "$category"
  done
  says "$DIV" "one row per divergence, with both sides" "| # | category | documents say | code shows | severity | action |"
else
  fail "skills/adopt-existing-project/reference/divergences.md exists"
fi

echo "# divergences in reviews"
says "$CR" "code-reviewer reports a DIVERGENCES block" "DIVERGENCES:"
says "$CR" "code-reviewer: a dependency without an ADR" "without an ADR"
says "$CR" "code-reviewer: a major version is a dependency change" "major version"
says "$CR" "code-reviewer: a test citing an AC missing from the PRD" "missing from the PRD"
says "$CR" "code-reviewer: the plan contradicted by the diff" "IMPLEMENTATION_PLAN.md"

echo "# flutter pub"
says "$FA" "flutter-architect runs flutter pub deps only on a matching lockfile" "rewrites \`pubspec.lock\`"
says "$FA" "flutter-architect lists resolved packages with flutter pub deps" "\`flutter pub deps\` lists"
says "$FA" "flutter-architect documents the stack of an adopted app as pre-existing" "pre-existing"

echo "# scenario 6 (v0.3): ADRs of an adopted app, and paths in documents"
# The plan announced one ADR per dependency; the agent's defaults made every deviation an ADR too,
# so three ADRs reached the user unapproved. The plan now announces both, and the agent says it.
says "$AD" "the adoption plan announces an ADR per deviation from the defaults" "one per deviation from the plugin's defaults (state management, navigation, layout)"
says "$FA" "flutter-architect records each deviation of an adopted app as an ADR" "and one per deviation from the defaults below (state management, navigation, layout)"
# DECISIONS.md cited /home/<user>/.pub-cache/…: a committed document carried a path of this machine.
says "$FA" "flutter-architect never cites an absolute path of this machine" "never by an absolute path of this machine"

echo "# scenarios 6 and 10 (v0.3): the checkpoint of the last commit (D42)"
# The checkpoint was updated after the last commit: a dirty tree, and the `! git switch main` the
# adoption proposes was refused. Since 1.0 the commit is plugin-orchestrator's git-workflow's.
says "$UP" "update-project: the report commit carries the final checkpoint" "the checkpoint in its final state"
says "$AD" "adopt-existing-project: the adoption commit carries the final checkpoint" "the checkpoint in its final state"
# Review of D42 (I3): every skill that checkpoints after each step defers to git-workflow for the
# commit that carries the checkpoint, or the model ticks the commit step after it.
for skill in update-project adopt-existing-project; do
  says "$PLUGIN_ROOT/skills/$skill/SKILL.md" "$skill defers to plugin-orchestrator:git-workflow for the commit that carries the checkpoint" \
    "A commit that carries the checkpoint follows plugin-orchestrator:git-workflow: the checkpoint is written before it, and not changed again for that commit."
done
# Review (M4, M5): adopted apps get only the announced ADRs; no machine path in any written document.
says "$FA" "flutter-architect: an adopted app's deviations stop at the three announced" "for an adopted app, only the three named above"
says "$UP" "update-project: the upgrade ADR cites the package, not a machine path" "never by an absolute path of this machine"
says "$AD" "adopt-existing-project: the divergence list cites no machine path" "never by an absolute path of this machine"

echo "# plugin-orchestrator beside the skills (1.0)"
for skill in update-project adopt-existing-project; do
  file="$PLUGIN_ROOT/skills/$skill/SKILL.md"
  says "$file" "$skill: needs plugin-orchestrator 0.1.0 or later" "needs plugin-orchestrator 0.1.0 or later in the session"
  says "$file" "$skill: without it, stops before anything and changes nothing" "When none does, stop before anything else and change nothing"
  says "$file" "$skill: names the installation" "claude plugin install plugin-orchestrator@soon --scope user"
  step1=$(awk '/^## Step 1 /{f=1; next} /^## /{f=0} f' "$file")
  [[ $(grep -m1 -E '^1\. ' <<<"$step1") == *plugin-orchestrator* ]] && pass "$skill: the check is the first item of step 1" \
    || fail "$skill: the check is the first item of step 1" "$(grep -m1 -E '^1\. ' <<<"$step1")"
done
# Only the adoption delegates: to plugin-orchestrator's product-architect and to the flutter-architect.
says "$AD" "adopt-existing-project: its mandates name interface 1" "interface 1"
says "$AD" "adopt-existing-project: a report without INTERFACE: 1 stops the workflow" "without \`INTERFACE: 1\`"
# update-project runs in a project that already has .forge/: its configuration is plugin-orchestrator's.
says "$UP" "update-project: the part of plugin-flutter, at interface 1" "\`plugin: plugin-flutter\` and \`interface: 1\`"
says "$UP" "update-project: a schema 1 file stops it" "A file without \`parts\` (\`schema_version: 1\`)"
says "$UP" "update-project: shows the parts block, filled in for Flutter" "the \`parts\` block of \`\${CLAUDE_PLUGIN_ROOT}/templates/forge-config.yaml\`"
says "$UP" "update-project: the user edits the file" "the user edits the file"
says "$UP" "update-project: a red baseline goes to plugin-orchestrator's debug-project" "plugin-orchestrator:debug-project"
says "$UP" "update-project: the pull request is plugin-orchestrator's" "/plugin-orchestrator:github-workflow pr"
says "$AD" "adopt-existing-project: the pull request is plugin-orchestrator's" "/plugin-orchestrator:github-workflow pr"
says "$AD" "adopt-existing-project: approvals are recorded by plugin-orchestrator" "orch.sh approve"

echo "# no reference to a component that left in 1.0"
# Each of these names is plugin-orchestrator's since 1.0, and is cited only with its prefix.
retired='create-feature|debug-project|git-workflow|github-workflow|recover-session|bootstrap-project|product-architect'
bad=$(grep -rnoE "[A-Za-z_./-]*:?\b($retired)\b" "$PLUGIN_ROOT"/{agents,skills,templates,hooks} 2>/dev/null \
  | grep -vE ":/?plugin-orchestrator:($retired)\$")
[[ -z $bad ]] && pass "agents, skills, templates and hooks cite those workflows only as plugin-orchestrator:<name>" \
  || fail "agents, skills, templates and hooks cite those workflows only as plugin-orchestrator:<name>" "$bad"
bad=$(grep -rnE 'skills/(create-feature|debug-project|git-workflow|github-workflow|recover-session|bootstrap-project)/|agents/product-architect' \
  "$PLUGIN_ROOT"/{agents,skills,templates,hooks} 2>/dev/null)
[[ -z $bad ]] && pass "no path of a retired component" || fail "no path of a retired component" "$bad"

finish
