#!/usr/bin/env bash
# secret-scan — PreToolUse hook for Bash, PowerShell and Monitor.
# Before a git commit, looks for secrets in what the commit can include: secret file names,
# and secret patterns in the added lines (plus gitleaks when it is installed). Never prints
# a secret. Silent for every command that does not commit.
# Fail-closed for commits: every internal error exits 2, and hooks.json sets "onFailure": "block".
set -u
export LC_ALL=C

_decided=0
trap '[[ $_decided == 1 ]] || { echo "plugin-flutter secret-scan: internal error, commit blocked (fail-closed)." >&2; exit 2; }' EXIT

allow() { _decided=1; exit 0; }
block() {
  _decided=1
  printf 'Blocked by plugin-flutter (secret-scan): %s\n' "$1" >&2
  exit 2
}

IFS= read -r -d '' input || true

# A command that does not contain "commit" cannot run git commit: no need for jq.
[[ $input == *commit* ]] || allow

here=${BASH_SOURCE[0]%/*}
[[ $here != "${BASH_SOURCE[0]}" ]] || here=.
source "$here/lib/shell-lexer.sh" || block "shell lexer library not found."
command -v jq >/dev/null 2>&1 || block "jq is required to inspect commits and was not found in PATH. Install jq."
jq -e 'type == "object" and (.tool_name | type == "string")' >/dev/null 2>&1 <<<"$input" \
  || block "unreadable hook input."

case $(jq -r '.tool_name' <<<"$input") in
  Bash | PowerShell | Monitor) ;;
  *) allow ;;
esac
command=$(jq -er '.tool_input.command // "" | strings' <<<"$input") \
  || block "tool_input.command is not a string."
[[ -n $command ]] || allow
cwd=$(jq -r '.cwd // "" | strings' <<<"$input")
cwd=${cwd:-$PWD}

MAX_DEPTH=4

# Commits found in the command line: directory, git location options, "wide" flag.
COMMIT_DIRS=() COMMIT_LOCS=() COMMIT_WIDE=()
# A staging command anywhere on the line can add unstaged or untracked files to the commit.
STAGING=0

# resolve_dir <base> <cd argument>: set DIR, or empty when it cannot be known statically.
resolve_dir() {
  local base=$1 arg=$2
  DIR=""
  case $arg in
    - | *'$'* | *'`'*) ;;
    '~') DIR=${HOME-} ;;
    '~/'*) DIR=${HOME-}/${arg#'~/'} ;;
    '~'*) ;;
    /*) DIR=$arg ;;
    *) if [[ -n $base ]]; then DIR=$base/$arg; fi ;;
  esac
}

# scan_code <code> <depth> <dir>: record the commits of every simple command, then of the nested code.
scan_code() {
  local depth=$2 dir=$3 segment nested
  ((depth <= MAX_DEPTH)) || block "command nesting is too deep to analyse."
  sw_lex "$1"
  local -a segments=(${SW_SEGMENTS[@]+"${SW_SEGMENTS[@]}"})
  local -a nested_code=(${SW_NESTED[@]+"${SW_NESTED[@]}"})
  for segment in ${segments[@]+"${segments[@]}"}; do
    sw_words "$segment"
    sw_program "${SW_WORDS[@]}" || continue
    local -a cmd=("${SW_WORDS[@]:SW_AT}")
    case ${cmd[0]##*/} in
      cd | pushd) cd_target "$dir" "${cmd[@]:1}"; dir=$DIR ;;
      git) git_command "$depth" "$dir" "${cmd[@]:1}" ;;
      eval) scan_code "${cmd[*]:1}" $((depth + 1)) "$dir" ;;
      bash | sh | zsh | dash | ksh | ash) shell_command "$depth" "$dir" "${cmd[@]:1}" ;;
    esac
  done
  for nested in ${nested_code[@]+"${nested_code[@]}"}; do
    scan_code "$nested" $((depth + 1)) "$dir"
  done
}

# cd_target <dir> <cd arguments...>: set DIR to the directory cd moves to.
cd_target() {
  local base=$1
  shift
  while [[ ${1-} == -?* && $1 != -- ]]; do shift; done
  if [[ ${1-} == -- ]]; then shift; fi
  resolve_dir "$base" "${1-~}"
}

# A shell given -c runs its next argument as code.
shell_command() {
  local depth=$1 dir=$2 word
  shift 2
  while (($#)); do
    word=$1
    shift
    case $word in
      --*) ;;
      -o | +o) if (($#)); then shift; fi ;;
      -*c*) if (($#)); then scan_code "$1" $((depth + 1)) "$dir"; fi; return 0 ;;
      -*) ;;
      *) return 0 ;;
    esac
  done
}

git_command() {
  local depth=$1 dir=$2 loc=""
  shift 2
  while (($#)); do
    case $1 in
      -C) resolve_dir "$dir" "${2-}"; dir=$DIR; shift; if (($#)); then shift; fi ;;
      --git-dir | --work-tree) loc+="$1=${2-}$SW_SEP"; shift; if (($#)); then shift; fi ;;
      --git-dir=* | --work-tree=*) loc+="$1$SW_SEP"; shift ;;
      -c | --namespace | --super-prefix | --config-env | --exec-path) shift; if (($#)); then shift; fi ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  (($#)) || return 0
  case $1 in
    add | stage | rm | mv) STAGING=1 ;;
    commit)
      shift
      COMMIT_DIRS+=("$dir")
      COMMIT_LOCS+=("$loc")
      if commit_is_wide "$@"; then COMMIT_WIDE+=(1); else COMMIT_WIDE+=(0); fi
      ;;
  esac
}

# commit_is_wide <commit arguments...>: true when the commit can include more than the index:
# -a, -i, -o, a path, or --pathspec-from-file.
commit_is_wide() {
  local word letters k
  while (($#)); do
    word=$1
    shift
    case $word in
      --) (($#)) && return 0; return 1 ;;
      --all | --include | --only | --pathspec-from-file | --pathspec-from-file=*) return 0 ;;
      --message | --file | --reuse-message | --reedit-message | --template | --author | --date | \
        --cleanup | --fixup | --squash | --trailer)
        if (($#)); then shift; fi
        ;;
      --*) ;;
      -?*)
        letters=${word#-}
        for ((k = 0; k < ${#letters}; k++)); do
          case ${letters:k:1} in
            a | i | o) return 0 ;;
            m | F | C | c | t)
              if ((k == ${#letters} - 1)) && (($#)); then shift; fi
              break
              ;;
            S | u) break ;;
          esac
        done
        ;;
      *) return 0 ;;
    esac
  done
  return 1
}

# Secret patterns, checked on added lines only (POSIX ERE).
RULE_NAMES=("private key" "AWS access key" "GitHub token" "API secret key (sk-)" "Google API key")
RULE_PATTERNS=(
  '-----BEGIN[A-Z ]*PRIVATE KEY'
  '(^|[^A-Za-z0-9])(A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z0-9]{16}([^A-Za-z0-9]|$)'
  'gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}'
  '(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}'
  'AIza[0-9A-Za-z_-]{35}'
)
ANY_RULE=$(IFS='|'; printf '%s' "${RULE_PATTERNS[*]}")

FINDINGS=()

# check_name <path> <note>: secret files are refused whatever their content.
check_name() {
  local base=${1##*/} kind=""
  case $base in
    .env.example | .env.sample | .env.template) ;;
    .env | .env.*) kind="environment file" ;;
    *.jks | *.keystore) kind="keystore" ;;
    key.properties) kind="Android signing properties" ;;
  esac
  if [[ -n $kind ]]; then FINDINGS+=("$1: $kind$2"); fi
}

# check_text <path> <note> <text>: name each secret pattern found in the text.
check_text() {
  local k
  grep -qE -e "$ANY_RULE" <<<"$3" || return 0
  for k in "${!RULE_PATTERNS[@]}"; do
    if grep -qE -e "${RULE_PATTERNS[k]}" <<<"$3"; then FINDINGS+=("$1: ${RULE_NAMES[k]}$2"); fi
  done
}

# added_lines <diff>: the lines a one-file diff adds, without its header.
added_lines() { awk '/^@@/ { hunk = 1; next } hunk && /^\+/ { print substr($0, 2) }' <<<"$1"; }

# git_list <git arguments...>: set LIST to the NUL-separated paths git prints, as \001-separated
# text (command substitution drops NUL bytes). Works on scan_commit's git_cmd.
git_list() {
  LIST=$(set -o pipefail; "${git_cmd[@]}" "$@" | tr '\0' '\001')
}

# scan_diff <mode> <note>: mode is "--cached" for the index, "" for the work tree.
scan_diff() {
  local mode=$1 note=$2 file diff list
  git_list diff $mode --name-only --diff-filter=ACMR -z || block "cannot list the changes to commit."
  list=$LIST
  while [[ -n $list ]]; do
    file=${list%%$'\001'*}
    list=${list#*$'\001'}
    check_name "$file" "$note"
    diff=$("${git_cmd[@]}" diff $mode --no-color --no-ext-diff -U0 -- ":(top,literal)$file") \
      || block "cannot read the changes of $file."
    check_text "$file" "$note" "$(added_lines "$diff")"
  done
}

scan_untracked() {
  local note=$1 top file list
  top=$("${git_cmd[@]}" rev-parse --show-toplevel) || block "cannot find the top of the repository."
  git_list ls-files --others --exclude-standard --full-name -z || block "cannot list the untracked files."
  list=$LIST
  while [[ -n $list ]]; do
    file=${list%%$'\001'*}
    list=${list#*$'\001'}
    check_name "$file" "$note"
    if [[ -f $top/$file ]] && grep -qI '' "$top/$file" 2>/dev/null; then
      check_text "$file" "$note" "$(<"$top/$file")"
    fi
  done
}

# run_gitleaks <top> [--staged]: add gitleaks findings, summarized without the secret.
run_gitleaks() {
  local top=$1 report status
  shift
  report=$(gitleaks git --pre-commit "$@" --redact --no-banner --exit-code 99 \
    --report-format json --report-path - "$top" 2>/dev/null)
  status=$?
  case $status in
    0) ;;
    99)
      local summary
      summary=$(jq -r '.[] | "\(.File):\(.StartLine): gitleaks rule \(.RuleID)"' <<<"$report" 2>/dev/null)
      if [[ -z $summary ]]; then summary="gitleaks reported a secret (no details available)"; fi
      while IFS= read -r line; do FINDINGS+=("$line"); done <<<"$summary"
      ;;
    *) block "gitleaks failed (exit $status), so the commit could not be checked. Fix gitleaks or its configuration (.gitleaks.toml) first." ;;
  esac
}

scan_commit() {
  local dir=$1 loc=$2 wide=$3 top
  local -a loc_opts=() git_cmd
  [[ -n $dir ]] || block "cannot tell which repository this commit runs in (a cd or -C target uses a variable). Run git commit from the project directory."
  while [[ $loc == *"$SW_SEP"* ]]; do loc_opts+=("${loc%%"$SW_SEP"*}"); loc=${loc#*"$SW_SEP"}; done
  git_cmd=(git -C "$dir" ${loc_opts[@]+"${loc_opts[@]}"} -c core.quotePath=false --no-pager)
  # Outside a repository git commit fails on its own: there is nothing to scan.
  [[ -d $dir ]] && "${git_cmd[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  scan_diff --cached ""
  if ((wide)); then
    scan_diff "" " (not staged yet: the commit includes it through -a, a path, or git add on the same line)"
    scan_untracked " (untracked: git add on the same line would include it)"
  fi
  if command -v gitleaks >/dev/null 2>&1; then
    top=$("${git_cmd[@]}" rev-parse --show-toplevel) || block "cannot find the top of the repository."
    run_gitleaks "$top" --staged
    if ((wide)); then run_gitleaks "$top"; fi
  fi
}

scan_code "$command" 0 "$cwd"
((${#COMMIT_DIRS[@]})) || allow

for k in "${!COMMIT_DIRS[@]}"; do
  scan_commit "${COMMIT_DIRS[k]}" "${COMMIT_LOCS[k]}" $((COMMIT_WIDE[k] || STAGING))
done
((${#FINDINGS[@]})) || allow

block "this commit would include secrets:
$(printf '  - %s\n' "${FINDINGS[@]}" | sort -u)
Never print a secret. Unstage each file (git restore --staged <file>, or git rm --cached <file> before the first commit), move the secret out of the code (environment variable, untracked file listed in .gitignore), and tell the user which file held it.
If it is a false positive, such as an example key in a test, only the user can commit it: they run the commit themselves with the ! prefix."
