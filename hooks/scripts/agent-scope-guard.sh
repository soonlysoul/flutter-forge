#!/usr/bin/env bash
# agent-scope-guard — PreToolUse hook for Edit, Write, NotebookEdit, Bash, PowerShell and Monitor.
# Enforces what an agent frontmatter cannot express for the plugin's own subagents: the
# directories and root files each one may write, and an allowlist of single shell commands.
# Inert outside the plugin's agents. Fail-closed for them: every internal error exits 2, and
# hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C
PLUGIN=plugin-flutter

_decided=0
trap '[[ $_decided == 1 ]] || { echo "plugin-flutter agent-scope-guard: internal error, tool call blocked (fail-closed)." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Blocked by plugin-flutter (agent-scope-guard): %s\n' "$1" >&2
  printf 'Use Read, Grep and Glob to inspect files. Do not work around this limit: report what you could not do under OPEN_QUESTIONS.\n' >&2
  exit 2
}

IFS= read -r -d '' input || true

# An input without the plugin prefix cannot come from one of the plugin's agents.
[[ $input == *"$PLUGIN:"* ]] || allow

here=${BASH_SOURCE[0]%/*}
[[ $here != "${BASH_SOURCE[0]}" ]] || here=.
source "$here/lib/shell-lexer.sh" || block "shell lexer library not found."
command -v jq >/dev/null 2>&1 || block "jq is required to check the agent's scope and was not found in PATH. Install jq."
jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input" || block "unreadable hook input."

agent=$(jq -r '.agent_type // "" | strings' <<<"$input")
[[ $agent == "$PLUGIN:"* ]] || allow
agent=${agent#"$PLUGIN:"}

GIT_READ="git status, git log, git diff, git show, git ls-files, git rev-parse, git branch --show-current"
write_files=""
case $agent in
  flutter-architect)
    write_dirs="docs"
    allowed_commands="flutter --version, flutter doctor, dart --version, dart pub deps, flutter pub deps, $GIT_READ"
    ;;
  test-engineer)
    write_dirs="test integration_test"
    allowed_commands="flutter test, dart test, $GIT_READ"
    ;;
  code-reviewer)
    write_dirs=""
    allowed_commands="git diff, git log, git show, git status, flutter analyze, dart analyze"
    ;;
  devops-engineer)
    write_dirs=".github"
    allowed_commands="flutter build, flutter --version, flutter doctor, flutter devices, gh auth status, gh run list|view|watch, gh pr checks|view, gh workflow list|view, gh repo view, git remote -v, $GIT_READ"
    ;;
  scaffold-engineer)
    write_dirs="lib test integration_test docs/technical"
    write_files="analysis_options.yaml"
    allowed_commands="flutter create [--org|--project-name|--platforms|--description <value>] ., flutter --version, flutter devices, flutter doctor, flutter pub get, flutter test, flutter analyze, $GIT_READ"
    ;;
  *) block "no scope is defined for agent $agent." ;;
esac

# git_read_only <words after git>: the read-only git commands of every agent but code-reviewer.
git_read_only() {
  if [[ ${1-} == --no-pager ]]; then shift; fi
  case ${1-} in
    status | log | diff | show | ls-files | rev-parse) return 0 ;;
    branch) [[ $# == 2 && $2 == --show-current ]] ;;
    *) return 1 ;;
  esac
}

# command_allowed <words>: the allowlist of the current agent.
command_allowed() {
  case $agent in
    flutter-architect)
      case "$*" in
        'flutter --version' | 'dart --version' | 'flutter doctor' | 'flutter doctor -v') return 0 ;;
      esac
      [[ ($1 == dart || $1 == flutter) && ${2-} == pub && ${3-} == deps ]] && return 0
      [[ $1 == git ]] && git_read_only "${@:2}"
      ;;
    test-engineer)
      [[ ($1 == flutter || $1 == dart) && ${2-} == test ]] && return 0
      [[ $1 == git ]] && git_read_only "${@:2}"
      ;;
    code-reviewer)
      [[ ($1 == flutter || $1 == dart) && ${2-} == analyze ]] && return 0
      if [[ $1 == git ]]; then
        shift
        if [[ ${1-} == --no-pager ]]; then shift; fi
        case ${1-} in diff | log | show | status) return 0 ;; esac
      fi
      return 1
      ;;
    devops-engineer)
      case "$*" in
        'flutter --version' | 'flutter devices' | 'flutter doctor' | 'flutter doctor -v' | 'git remote -v') return 0 ;;
      esac
      local word
      if [[ $1 == flutter && ${2-} == build ]]; then
        for word in "${@:3}"; do
          case $word in -o* | --split-debug-info* | --code-size-directory*) return 1 ;; esac
        done
        return 0
      fi
      if [[ $1 == gh ]]; then
        for word in "${@:4}"; do
          [[ $word != --web ]] || return 1
          # -w is --web everywhere except gh run list, where it is --workflow.
          [[ $word != -w || ${2-}/${3-} == run/list ]] || return 1
        done
        case ${2-}/${3-} in
          auth/status)
            # Only the exact forms: gh groups short flags (-at) and accepts --flag=value,
            # so a deny list could not keep --show-token out.
            shift 3
            while (($#)); do
              case $1 in
                -a | --active) shift ;;
                -h | --hostname) (($# >= 2)) || return 1; shift 2 ;;
                *) return 1 ;;
              esac
            done
            return 0
            ;;
          run/list | run/view | run/watch | pr/checks | pr/view | workflow/list | workflow/view | repo/view) return 0 ;;
        esac
        return 1
      fi
      [[ $1 == git ]] && git_read_only "${@:2}"
      ;;
    scaffold-engineer)
      case "$*" in
        'flutter --version' | 'flutter devices' | 'flutter doctor' | 'flutter doctor -v' | 'flutter pub get' | 'flutter test' | 'flutter analyze') return 0 ;;
      esac
      local word
      if [[ $1 == flutter && ${2-} == create ]]; then
        # Only into the project root, the session's: the last word is the target. Only the four
        # options of the scaffold, each with its value: --overwrite would replace existing files,
        # and --list-samples writes a file wherever it is told, before the target is checked.
        (($# >= 3)) && [[ ${!#} == . ]] || return 1
        local options=("${@:3:$#-3}") i=0
        while ((i < ${#options[@]})); do
          case ${options[i]} in
            --org=?* | --project-name=?* | --platforms=?* | --description=?*) i=$((i + 1)) ;;
            --org | --project-name | --platforms | --description)
              ((i + 1 < ${#options[@]})) && [[ ${options[i + 1]} != -* ]] || return 1
              i=$((i + 2))
              ;;
            *) return 1 ;;
          esac
        done
        return 0
      fi
      [[ $1 == git ]] && git_read_only "${@:2}"
      ;;
    # A case without a matching branch returns 0: an agent without a branch must not pass.
    *) return 1 ;;
  esac
}

check_write() {
  local path root rel dir file listed=""
  path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // "" | strings' <<<"$input")
  [[ -n $write_dirs$write_files ]] || block "$agent may not write files."
  for dir in $write_dirs; do listed+="${listed:+, }$dir/"; done
  for file in $write_files; do listed+="${listed:+, }$file"; done
  [[ $path == /* ]] || block "$agent may only write files given by an absolute path under: $listed."
  case /$path/ in
    */../* | */./*) block "$agent may not use . or .. in a path: $path" ;;
  esac
  root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input")}
  root=${root%/}
  [[ -n $root ]] || block "the project root is unknown."
  [[ $path == "$root"/* ]] || block "$agent may only write inside the project, under: $listed. Refused: $path"
  rel=${path#"$root"/}
  for dir in $write_dirs; do
    if [[ $rel == "$dir"/* ]]; then allow; fi
  done
  for file in $write_files; do
    if [[ $rel == "$file" ]]; then allow; fi
  done
  block "$agent may only write under: $listed. Refused: $rel"
}

check_command() {
  local command word
  [[ -n $allowed_commands ]] || block "$agent may not run shell commands."
  command=$(jq -er '.tool_input.command // "" | strings' <<<"$input") || block "tool_input.command is not a string."
  [[ -n $command ]] || block "$agent may only run: $allowed_commands."
  sw_lex "$command"
  if ((SW_COMPOUND || ${#SW_SEGMENTS[@]} != 1)); then
    block "$agent may run one plain command at a time, without ;, &&, |, redirections or substitutions. Allowed: $allowed_commands."
  fi
  sw_words "${SW_SEGMENTS[0]}"
  for word in "${SW_WORDS[@]}"; do
    case $word in
      --output | --output=* | --write | --write=*) block "$agent may not use options that write files ($word)." ;;
    esac
  done
  if command_allowed "${SW_WORDS[@]}"; then allow; fi
  block "$agent may only run: $allowed_commands."
}

case $(jq -r '.tool_name // "" | strings' <<<"$input") in
  Edit | Write | NotebookEdit) check_write ;;
  Bash | PowerShell | Monitor) check_command ;;
esac
allow
