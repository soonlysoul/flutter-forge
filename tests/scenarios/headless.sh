#!/usr/bin/env bash
# headless.sh — one headless Claude Code turn with the plugin loaded from this checkout, for the
# behavioural scenarios. It CONSUMES THE SUBSCRIPTION QUOTA, so it refuses to run unless
# FORGE_ALLOW_QUOTA=1 is set; run-all.sh never calls it.
# FORGE_ORCHESTRATOR_DIR, when set, is a checkout of plugin-orchestrator loaded beside it (since
# 1.0 the workflows are the orchestrator's); unset, only an installed plugin-orchestrator loads.
#
# Usage: headless.sh <workdir> <session-uuid> <new|resume> <transcript.jsonl> <prompt> <allowed tool>...
#
# No --bare (it would need a paid API key). Permissions: --permission-mode dontAsk plus explicit
# --allowedTools, because -p ignores the allow rules of a project that was never trusted.
set -u
[[ ${FORGE_ALLOW_QUOTA:-} == 1 ]] || {
  echo "refused: a headless session consumes quota; set FORGE_ALLOW_QUOTA=1 once the user agreed." >&2
  exit 2
}
(($# >= 6)) || { echo "usage: headless.sh <workdir> <session-uuid> <new|resume> <transcript.jsonl> <prompt> <allowed tool>..." >&2; exit 2; }

plugin=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
workdir=$(cd "$1" && pwd) || exit 2
session_id=$2 mode=$3 transcript=$4 prompt=$5
shift 5
[[ $workdir != "$plugin" && $workdir != "$plugin"/* ]] || { echo "refused: run scenarios outside the plugin directory." >&2; exit 2; }
plugins=(--plugin-dir "$plugin")
if [[ -n ${FORGE_ORCHESTRATOR_DIR:-} ]]; then
  [[ $(jq -r .name "$FORGE_ORCHESTRATOR_DIR/.claude-plugin/plugin.json" 2>/dev/null) == plugin-orchestrator ]] \
    || { echo "refused: FORGE_ORCHESTRATOR_DIR is not a checkout of plugin-orchestrator." >&2; exit 2; }
  plugins+=(--plugin-dir "$(cd "$FORGE_ORCHESTRATOR_DIR" && pwd)")
fi

case $mode in
  new) session=(--session-id "$session_id") ;;
  resume) session=(--resume "$session_id") ;;
  *) echo "mode must be new or resume" >&2; exit 2 ;;
esac

cd "$workdir" || exit 2
claude -p "$prompt" "${plugins[@]}" --output-format stream-json --verbose --include-hook-events \
  --permission-mode dontAsk "${session[@]}" --allowedTools "$@" >"$transcript"
status=$?

# Proof that the plugin loaded, then the outcome of the turn.
jq -c 'select(.type == "system" and .subtype == "init") | {plugins, plugin_errors}' "$transcript"
jq -c 'select(.type == "result") | {subtype, is_error, num_turns, total_cost_usd}' "$transcript"
echo "exit=$status"
exit "$status"
