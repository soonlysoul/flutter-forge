#!/usr/bin/env bash
# v0.3 components: product-architect, update-project, adopt-existing-project, and the divergence
# check of the code-reviewer. A content check, like test_github_skills: it proves the instruction
# is written, not that it is followed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_maintenance_skills
PA="$PLUGIN_ROOT/agents/product-architect.md"

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

finish
