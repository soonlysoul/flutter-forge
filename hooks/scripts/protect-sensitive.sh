#!/usr/bin/env bash
# protect-sensitive — PreToolUse hook for Edit, Write and NotebookEdit.
# In a project that has .forge/, asks the user to confirm a write to signing material,
# entitlements, CI workflows or .forge/config.yaml; .forge/config.yaml is protected everywhere.
# The decision is a JSON "ask" on stdout (in -p runs, Claude Code refuses the call and Claude
# reads the reason). Fail-closed when it must decide: every internal error exits 2, and
# hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C

_decided=0
trap '[[ $_decided == 1 ]] || { echo "plugin-flutter protect-sensitive: internal error, write blocked (fail-closed)." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Blocked by plugin-flutter (protect-sensitive): %s\n' "$1" >&2
  exit 2
}

IFS= read -r -d '' input || true

# Without one of these names in the input, the write cannot be sensitive: no need for jq.
case $input in
  *key.properties* | *.keystore* | *.jks* | *.p12* | *.pfx* | *.entitlements* | *.github/workflows/* | \
    *.github/actions/* | *.forge/config.yaml*) ;;
  *) allow ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the file path is unknown: a session root without .forge/ is the best guess left.
  if [[ -n ${CLAUDE_PROJECT_DIR-} && ! -d ${CLAUDE_PROJECT_DIR%/}/.forge && $input != *.forge/config.yaml* ]]; then allow; fi
  block "jq is required to check sensitive files and was not found in PATH. Install jq."
fi
jq -e 'type == "object" and (.tool_name | type == "string")' >/dev/null 2>&1 <<<"$input" \
  || block "unreadable hook input."
case $(jq -r '.tool_name' <<<"$input") in
  Edit | Write | NotebookEdit) ;;
  *) allow ;;
esac
path=$(jq -er '.tool_input.file_path // .tool_input.notebook_path // "" | strings' <<<"$input") \
  || block "the file path is not a string."
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input")}
root=${root%/}

abs=$path
if [[ $abs != /* && -n $root ]]; then abs=$root/$abs; fi
# The forge project of a file is the nearest parent holding .forge/, whatever the session root.
project=""
dir=${abs%/*}
while [[ -n $dir ]]; do
  if [[ -d $dir/.forge ]]; then project=$dir; break; fi
  dir=${dir%/*}
done

kind=""
case /$path in
  */.forge/config.yaml) kind="the plugin's preauthorizations, which only the user edits" ;;
esac
if [[ -z $kind && -n $project ]]; then
  case /$path in
    */key.properties | *.keystore | *.jks) kind="Android signing material" ;;
    *.p12 | *.pfx) kind="a signing certificate with its private key" ;;
    *.entitlements) kind="an Apple entitlements file: it grants the app capabilities" ;;
    */.github/workflows/* | */.github/actions/*) kind="CI code: it runs with the repository's tokens and secrets" ;;
  esac
fi
[[ -n $kind ]] || allow

shown=$path
base=${root:-$project}
if [[ -n $base && $abs == "$base"/* ]]; then shown=${abs#"$base"/}; fi
reason="plugin-flutter protect-sensitive: $shown is $kind. Approve only if this change was requested. If it is refused, Claude must not write the file another way, and tells the user what it wanted to change."
jq -nc --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}' \
  || block "cannot write the decision."
allow
