#!/usr/bin/env bash
# v0.3 components: product-architect, update-project, adopt-existing-project, and the divergence
# check of the code-reviewer. A content check, like test_github_skills: it proves the instruction
# is written, not that it is followed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_maintenance_skills
PA="$PLUGIN_ROOT/agents/product-architect.md"
UP="$PLUGIN_ROOT/skills/update-project/SKILL.md"
REPORT="$PLUGIN_ROOT/skills/update-project/reference/deps-report.md"

# says <file> <label> <fixed string>
says() { grep -qiF -- "$3" "$1" && pass "$2" || fail "$2" "missing: $3"; }

echo "# product-architect"
if [[ -f $PA ]]; then
  says "$PA" "writes the PRD" "docs/product/PRD.md"
  says "$PA" "writes only under docs/product/" "only under \`docs/product/\`"
  says "$PA" "has no shell" "no shell"
  says "$PA" "numbers criteria AC-xxx" "AC-"
  says "$PA" "continues the numbering from the highest existing id" "highest existing"
  says "$PA" "never renumbers an existing criterion" "never renumber"
  says "$PA" "criteria are observable and testable" "testable"
  says "$PA" "criteria use Given, when, then" "Given"
  says "$PA" "a new PRD is DRAFT" "DRAFT"
  says "$PA" "a changed APPROVED PRD goes back to DRAFT" "back to DRAFT"
  says "$PA" "criteria rebuilt from code are marked reconstructed" "reconstructed"
  says "$PA" "keeps the fixed header of the template" "fixed header"
  says "$PA" "does not decide the architecture (flutter-architect's)" "flutter-architect"
  says "$PA" "reports its criteria" "ACCEPTANCE_CRITERIA:"
else
  fail "agents/product-architect.md exists"
fi

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
  says "$UP" "checks a plugin's platforms against the enabled ones" "platforms.enabled"
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
  bad=$(grep -n 'flutter upgrade\|flutter downgrade' "$UP" | grep -viE 'never|! flutter upgrade')
  [[ -z $bad ]] && pass "never runs flutter upgrade or downgrade itself" || fail "never runs flutter upgrade or downgrade itself" "$bad"
  bad=$(grep -n 'dart pub' "$UP" | grep -viE 'never|exit 69')
  [[ -z $bad ]] && pass "uses flutter pub, never dart pub" || fail "uses flutter pub, never dart pub" "$bad"
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
else
  fail "skills/update-project/reference/deps-report.md exists"
fi

finish
