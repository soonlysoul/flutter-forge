#!/usr/bin/env bash
# guard-destructive — PreToolUse hook for Bash, PowerShell and Monitor.
# Blocks destructive git, gh, rm and publish commands; the reason goes to Claude on stderr.
# Fail-closed: every internal error exits 2, and hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C

_decided=0
trap '[[ $_decided == 1 ]] || { echo "dart-multiplatform-forge guard-destructive: internal error, command blocked (fail-closed)." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Blocked by dart-multiplatform-forge (guard-destructive): %s\n' "$1" >&2
  printf 'Do not retry or rephrase this command. Explain the risk to the user; if they want it, they can run it themselves.\n' >&2
  exit 2
}

here=${BASH_SOURCE[0]%/*}
[[ $here != "${BASH_SOURCE[0]}" ]] || here=.
source "$here/lib/shell-lexer.sh" || block "shell lexer library not found."
command -v jq >/dev/null 2>&1 || block "jq is required to inspect commands and was not found in PATH. Install jq."

MAX_DEPTH=4

# has_option <short letters> <long options...> -- <words...>
# True if, before a "--" word, a word is one of the long options (alone or --opt=value)
# or a cluster of short options (-xyz) containing one of the letters.
has_option() {
  local shorts=$1 word long
  local -a longs=()
  shift
  while (($#)) && [[ $1 != -- ]]; do longs+=("$1"); shift; done
  if (($#)); then shift; fi
  for word in "$@"; do
    case $word in
      --) return 1 ;;
      --*)
        for long in ${longs[@]+"${longs[@]}"}; do
          if [[ $word == "$long" || $word == "$long="* ]]; then return 0; fi
        done
        ;;
      -*)
        if [[ -n $shorts && $word =~ ^-[A-Za-z]+$ && $word == *["$shorts"]* ]]; then return 0; fi
        ;;
    esac
  done
  return 1
}

# check_code <code> <depth>: check every simple command, then the nested code.
check_code() {
  local depth=$2 segment nested
  ((depth <= MAX_DEPTH)) || block "command nesting is too deep to analyse."
  sw_lex "$1"
  local -a segments=(${SW_SEGMENTS[@]+"${SW_SEGMENTS[@]}"})
  local -a nested_code=(${SW_NESTED[@]+"${SW_NESTED[@]}"})
  for segment in ${segments[@]+"${segments[@]}"}; do
    sw_words "$segment"
    check_simple_command "$depth" "${SW_WORDS[@]}"
  done
  for nested in ${nested_code[@]+"${nested_code[@]}"}; do
    check_code "$nested" $((depth + 1))
  done
}

# skip_options <options taking a value>: advance i past option words of a wrapper.
# Works on check_simple_command's w, i and n (bash scoping is dynamic).
skip_options() {
  while ((i < n)) && [[ ${w[i]} == -* ]]; do
    if [[ " $1 " == *" ${w[i]} "* ]]; then i=$((i + 2)); else i=$((i + 1)); fi
  done
}

check_simple_command() {
  local depth=$1
  shift
  local -a w=("$@")
  local i=0 n=$#
  # Skip what comes before the program: assignments, keywords, wrapper commands.
  while ((i < n)); do
    case ${w[i]} in
      '{' | '}' | '!' | if | then | else | elif | do | while | until | time) i=$((i + 1)); continue ;;
    esac
    if [[ ${w[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi
    case ${w[i]##*/} in
      sudo | doas) i=$((i + 1)); skip_options "-u -g -h -p -C -D -r -t -U -T" ;;
      env) i=$((i + 1)); skip_options "-u -C -S --unset --chdir --split-string" ;;
      command | builtin | nohup) i=$((i + 1)); skip_options "" ;;
      exec) i=$((i + 1)); skip_options "-a" ;;
      nice) i=$((i + 1)); skip_options "-n --adjustment" ;;
      timeout) i=$((i + 1)); skip_options "-s -k --signal --kill-after"; i=$((i + 1)) ;;
      xargs) i=$((i + 1)); skip_options "-I -L -n -P -s -d -E -a --max-args --max-procs --delimiter --arg-file --max-lines --replace" ;;
      *) break ;;
    esac
  done
  ((i < n)) || return 0
  local -a cmd=("${w[@]:i}")
  local -a args=("${cmd[@]:1}")
  case ${cmd[0]##*/} in
    git) check_git ${args[@]+"${args[@]}"} ;;
    rm) check_rm ${args[@]+"${args[@]}"} ;;
    gh) check_gh ${args[@]+"${args[@]}"} ;;
    flutter | dart) check_pub ${args[@]+"${args[@]}"} ;;
    find) check_find "$depth" ${args[@]+"${args[@]}"} ;;
    eval) check_code "${args[*]-}" $((depth + 1)) ;;
    bash | sh | zsh | dash | ksh | ash) check_shell "$depth" ${args[@]+"${args[@]}"} ;;
  esac
}

# find -exec / -execdir / -ok / -okdir run a command: check it like any other.
check_find() {
  local depth=$1 word collecting=0
  local -a sub=()
  shift
  for word in "$@"; do
    if ((collecting)); then
      if [[ $word == ';' || $word == + ]]; then
        if ((${#sub[@]})); then check_simple_command "$depth" "${sub[@]}"; fi
        sub=() collecting=0
      else
        sub+=("$word")
      fi
    else
      case $word in
        -exec | -execdir | -ok | -okdir) collecting=1 ;;
      esac
    fi
  done
  if ((${#sub[@]})); then check_simple_command "$depth" "${sub[@]}"; fi
}

# rm -rf is allowed only on build/ (relative to the session cwd).
check_rm() {
  local target
  { has_option rR --recursive -- "$@" && has_option f --force -- "$@"; } || return 0
  positionals "$@"
  ((${#POS[@]})) || block "rm -rf without visible targets (for example through xargs) cannot be checked."
  for target in "${POS[@]}"; do
    in_build_dir "$target" || block "rm -rf outside build/ deletes files for good: $target"
  done
}

in_build_dir() {
  local path=$1
  [[ $path != *..* ]] || return 1
  if [[ $path == /* ]]; then
    [[ -n $HOOK_CWD && $path == "$HOOK_CWD"/* ]] || return 1
    path=${path#"$HOOK_CWD"/}
  fi
  path=${path#./}
  [[ $path == build || $path == build/* ]]
}

check_gh() {
  local group=${1-} action=${2-}
  if (($# >= 2)); then shift 2; else shift $#; fi
  case $group/$action in
    repo/delete) block "gh repo delete deletes a repository." ;;
    repo/edit)
      if has_option "" --visibility -- "$@"; then block "changing a repository's visibility needs the user's explicit approval."; fi
      ;;
    pr/merge) block "merging a pull request needs the user's explicit approval." ;;
    release/create | release/delete | release/delete-asset | release/edit | release/upload)
      block "creating or changing a release needs the user's explicit approval."
      ;;
    api/*) check_gh_api "$action" "$@" ;;
  esac
}

check_gh_api() {
  local word previous="" method=""
  for word in "$@"; do
    case $previous in
      -X | --method) method=$word ;;
    esac
    case $word in
      -X?*) method=${word#-X} ;;
      --method=*) method=${word#--method=} ;;
    esac
    previous=$word
  done
  if [[ $method == [Dd][Ee][Ll][Ee][Tt][Ee] ]]; then block "gh api -X DELETE deletes a GitHub resource."; fi
}

# flutter pub publish / dart pub publish, except --dry-run.
check_pub() {
  while [[ ${1-} == -* ]]; do shift; done
  [[ ${1-} == pub ]] || return 0
  shift
  while [[ ${1-} == -* ]]; do shift; done
  [[ ${1-} == publish ]] || return 0
  shift
  has_option n --dry-run -- "$@" || block "publishing a package to pub.dev needs the user's explicit approval."
}

# A shell given -c runs its next argument as code; a script file is not analysed.
check_shell() {
  local depth=$1 word
  shift
  while (($#)); do
    word=$1
    shift
    case $word in
      --*) ;;
      -o | +o) if (($#)); then shift; fi ;;
      -*c*) if (($#)); then check_code "$1" $((depth + 1)); fi; return 0 ;;
      -*) ;;
      *) return 0 ;;
    esac
  done
}

# positionals <words...>: set POS to the words that are not options (every word after "--").
positionals() {
  local word past=0
  POS=()
  for word in "$@"; do
    if ((!past)); then
      if [[ $word == -- ]]; then past=1; continue; fi
      if [[ $word == -?* ]]; then continue; fi
    fi
    POS+=("$word")
  done
}

check_git() {
  while (($#)); do
    case $1 in
      -C | -c | --git-dir | --work-tree | --namespace | --super-prefix | --config-env) shift; if (($#)); then shift; fi ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  (($#)) || return 0
  local sub=$1 word after_separator=0
  shift
  positionals "$@"
  case $sub in
    reset)
      if has_option "" --hard -- "$@"; then block "git reset --hard discards uncommitted work."; fi
      ;;
    clean)
      if has_option f --force -- "$@"; then block "git clean --force deletes untracked files."; fi
      ;;
    push) check_git_push "$@" ;;
    branch)
      if has_option D -- "$@" || { has_option d --delete -- "$@" && has_option f --force -- "$@"; }; then
        block "git branch -D deletes a branch even when it is not merged."
      fi
      ;;
    checkout)
      if has_option f --force -- "$@"; then block "git checkout --force discards uncommitted changes."; fi
      for word in "$@"; do
        if ((after_separator)); then block "git checkout -- <path> discards uncommitted changes to those paths."; fi
        if [[ $word == -- ]]; then after_separator=1; fi
      done
      for word in ${POS[@]+"${POS[@]}"}; do
        if [[ $word == . || $word == ./ ]]; then block "git checkout . discards every uncommitted change."; fi
      done
      ;;
    restore)
      if ! has_option S --staged -- "$@" || has_option W --worktree -- "$@"; then
        block "git restore without --staged alone discards uncommitted changes."
      fi
      ;;
    stash)
      case ${POS[0]-} in
        drop | clear) block "git stash ${POS[0]} deletes stashed work for good." ;;
      esac
      ;;
    switch)
      if has_option f --discard-changes --force -- "$@"; then block "git switch --discard-changes discards uncommitted changes."; fi
      ;;
  esac
}

check_git_push() {
  local word tags_reason="pushing tags publishes release points and needs the user's explicit approval."
  if has_option f --force --force-with-lease --force-if-includes -- "$@"; then block "a force push rewrites the remote history."; fi
  if has_option d --delete -- "$@"; then block "git push --delete deletes a remote branch."; fi
  if has_option "" --mirror -- "$@"; then block "git push --mirror overwrites every ref of the remote."; fi
  if has_option "" --tags --follow-tags -- "$@"; then block "$tags_reason"; fi
  positionals "$@"
  for word in ${POS[@]+"${POS[@]}"}; do
    case $word in
      +*) block "a +refspec is a force push." ;;
      :*) block "a :refspec deletes a remote branch." ;;
      refs/tags/* | *:refs/tags/*) block "$tags_reason" ;;
    esac
  done
}

IFS= read -r -d '' input || true
jq -e 'type == "object" and (.tool_name | type == "string")' >/dev/null 2>&1 <<<"$input" \
  || block "unreadable hook input."
tool=$(jq -r '.tool_name' <<<"$input")

case $tool in
  Bash | PowerShell | Monitor) ;;
  *) allow ;;
esac

command=$(jq -er '.tool_input.command // "" | strings' <<<"$input") \
  || block "tool_input.command is not a string."
[[ -n $command ]] || allow
HOOK_CWD=$(jq -r '.cwd // "" | strings' <<<"$input")
HOOK_CWD=${HOOK_CWD%/}

check_code "$command" 0
allow
