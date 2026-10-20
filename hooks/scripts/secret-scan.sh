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

# Scopes: "" for nothing beyond the index, ALL for the whole work tree, or P followed by
# $SW_SEP-separated pathspecs, relative to the directory of the command that names them.
# Commits: directory, git location options, scope of the work tree changes they include.
COMMIT_DIRS=() COMMIT_LOCS=() COMMIT_SCOPES=()
# Staging commands on the same line (git add, git stage): directory, location, scope, and
# whether untracked files are included (not with -u).
STAGE_DIRS=() STAGE_LOCS=() STAGE_SCOPES=() STAGE_UNTRACKED=()
# Set when the line does something the hook cannot see before it runs.
REFUSE=""

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

# scan_code <code> <depth> <dir>: record the git commands of every simple command, then of the nested code.
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
  local sub=$1
  shift
  case $sub in
    init | clone)
      REFUSE="the repository is created on the same line as the commit, so its content cannot be checked. Run git $sub in a separate command, then stage and commit in another one."
      ;;
    apply)
      if has_word --cached "$@" || has_word --index "$@"; then
        REFUSE="git apply --cached writes the index on the same line as the commit, so the patch cannot be checked. Apply it in a separate command, then commit."
      fi
      ;;
    add | stage) add_command "$dir" "$loc" "$@" ;;
    commit)
      commit_scope "$@"
      COMMIT_DIRS+=("$dir") COMMIT_LOCS+=("$loc") COMMIT_SCOPES+=("$SCOPE")
      ;;
  esac
}

has_word() {
  local needle=$1 word
  shift
  for word in "$@"; do [[ $word == "$needle" ]] && return 0; done
  return 1
}

# add_scope_path <path>: append a pathspec to SCOPE; a path that cannot be resolved widens it.
add_scope_path() {
  [[ $SCOPE == ALL ]] && return 0
  case $1 in
    *'$'* | *'`'*) SCOPE=ALL ;;
    *) SCOPE=${SCOPE:-P}$SW_SEP$1 ;;
  esac
}

# add_command <dir> <loc> <git add arguments...>
add_command() {
  local dir=$1 loc=$2 word past=0 all=0 untracked=1
  shift 2
  SCOPE=""
  for word in "$@"; do
    if ((past)); then add_scope_path "$word"; continue; fi
    case $word in
      --) past=1 ;;
      --force) REFUSE="git add -f stages an ignored file on the same line as the commit, which the index does not show yet. Run git add -f in a separate command, then commit." ;;
      --all | --no-ignore-removal) all=1 ;;
      --update) untracked=0 all=1 ;;
      --pathspec-from-file | --pathspec-from-file=*) SCOPE=ALL ;;
      --*) ;;
      -?*)
        if [[ $word == *f* ]]; then
          REFUSE="git add -f stages an ignored file on the same line as the commit, which the index does not show yet. Run git add -f in a separate command, then commit."
        fi
        if [[ $word == *A* ]]; then all=1; fi
        if [[ $word == *u* ]]; then untracked=0 all=1; fi
        ;;
      *) add_scope_path "$word" ;;
    esac
  done
  if [[ -z $SCOPE ]]; then
    ((all)) || return 0
    SCOPE=ALL
  fi
  STAGE_DIRS+=("$dir") STAGE_LOCS+=("$loc") STAGE_SCOPES+=("$SCOPE") STAGE_UNTRACKED+=("$untracked")
}

# commit_scope <commit arguments...>: set SCOPE to the work tree changes the commit includes
# besides the index: ALL for -a or --pathspec-from-file, the named paths, or nothing.
commit_scope() {
  local word letters k all=0
  SCOPE=""
  while (($#)); do
    word=$1
    shift
    case $word in
      --) for word in "$@"; do add_scope_path "$word"; done; break ;;
      --all | --pathspec-from-file | --pathspec-from-file=*) all=1 ;;
      --message | --file | --reuse-message | --reedit-message | --template | --author | --date | \
        --cleanup | --fixup | --squash | --trailer)
        if (($#)); then shift; fi
        ;;
      --*) ;;
      -?*)
        letters=${word#-}
        for ((k = 0; k < ${#letters}; k++)); do
          case ${letters:k:1} in
            a) all=1 ;;
            m | F | C | c | t)
              if ((k == ${#letters} - 1)) && (($#)); then shift; fi
              break
              ;;
            S | u) break ;;
          esac
        done
        ;;
      *) add_scope_path "$word" ;;
    esac
  done
  if ((all)); then SCOPE=ALL; fi
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
GOOGLE_RULE=4
ANY_RULE=$(IFS='|'; printf '%s' "${RULE_PATTERNS[*]}")

# Firebase client configuration holds Google API keys that are meant to ship with the app.
firebase_config() {
  case ${1##*/} in
    firebase_options.dart | google-services.json | GoogleService-Info.plist) return 0 ;;
  esac
  return 1
}

FINDINGS=()

# check_name <path> <note>: secret files are refused whatever their content.
check_name() {
  local base=${1##*/} kind=""
  case $base in
    .env.example | .env.sample | .env.template) ;;
    .env | .env.*) kind="environment file" ;;
    *.jks | *.keystore) kind="Android keystore" ;;
    key.properties) kind="Android signing properties" ;;
    *.p12 | *.pfx) kind="signing certificate with its private key" ;;
  esac
  if [[ -n $kind ]]; then FINDINGS+=("$1: $kind$2"); fi
}

# matches <pattern> <text>: grep -E, where an error is not a "no match".
matches() {
  local status
  grep -qE -e "$1" <<<"$2"
  status=$?
  ((status <= 1)) || block "grep failed (exit $status)."
  return "$status"
}

# check_text <path> <note> <text>: name each secret pattern found in the text.
check_text() {
  local k
  matches "$ANY_RULE" "$3" || return 0
  for k in "${!RULE_PATTERNS[@]}"; do
    if ((k == GOOGLE_RULE)) && firebase_config "$1"; then continue; fi
    if matches "${RULE_PATTERNS[k]}" "$3"; then FINDINGS+=("$1: ${RULE_NAMES[k]}$2"); fi
  done
}

# added_lines: the lines a diff adds, without the file headers.
added_lines() { awk '/^diff --git / { hunk = 0; next } /^@@/ { hunk = 1; next } hunk && /^\+/ { print substr($0, 2) }'; }

# git_list <git arguments...>: set LIST to the NUL-separated paths git prints, as \001-separated
# text (command substitution drops NUL bytes). Works on scan_repo's git_cmd.
git_list() {
  LIST=$(set -o pipefail; "${git_cmd[@]}" "$@" | tr '\0' '\001')
}

# pathspecs <scope>: set PATHS to the git arguments that limit a scan to the scope.
pathspecs() {
  local rest
  PATHS=()
  [[ $1 == P* ]] || return 0
  PATHS=(--)
  rest=${1#P"$SW_SEP"}
  while [[ $rest == *"$SW_SEP"* ]]; do PATHS+=("${rest%%"$SW_SEP"*}"); rest=${rest#*"$SW_SEP"}; done
  PATHS+=("$rest")
}

DIFF_OPTS=(--no-color --no-ext-diff --no-textconv --text -U0 --diff-filter=ACMR)

# scan_diff <mode> <note> <pathspec arguments...>: mode is "--cached" for the index, "" for the work tree.
# One diff for every file; the files are read one by one only when it holds a pattern.
scan_diff() {
  local mode=$1 note=$2 file list diff
  shift 2
  git_list diff $mode --name-only --diff-filter=ACMR -z "$@" || block "cannot list the changes to commit."
  list=$LIST
  [[ -n $list ]] || return 0
  while [[ -n $list ]]; do
    file=${list%%$'\001'*}
    list=${list#*$'\001'}
    check_name "$file" "$note"
  done
  diff=$(set -o pipefail; "${git_cmd[@]}" diff $mode "${DIFF_OPTS[@]}" "$@" | added_lines) \
    || block "cannot read the changes to commit."
  matches "$ANY_RULE" "$diff" || return 0
  list=$LIST
  while [[ -n $list ]]; do
    file=${list%%$'\001'*}
    list=${list#*$'\001'}
    diff=$(set -o pipefail; "${git_cmd[@]}" diff $mode "${DIFF_OPTS[@]}" -- ":(top,literal)$file" | added_lines) \
      || block "cannot read the changes of $file."
    check_text "$file" "$note" "$diff"
  done
}

# scan_untracked <note> <pathspec arguments...>
scan_untracked() {
  local note=$1 top file list hits status
  local -a files=()
  shift
  top=$("${git_cmd[@]}" rev-parse --show-toplevel) || block "cannot find the top of the repository."
  git_list ls-files --others --exclude-standard --full-name -z "$@" || block "cannot list the untracked files."
  list=$LIST
  while [[ -n $list ]]; do
    file=${list%%$'\001'*}
    list=${list#*$'\001'}
    check_name "$file" "$note"
    if [[ -f $top/$file ]]; then files+=("$top/$file"); fi
  done
  ((${#files[@]})) || return 0
  hits=$(grep -lIE -e "$ANY_RULE" -- "${files[@]}" 2>/dev/null)
  status=$?
  ((status <= 1)) || block "grep failed (exit $status)."
  while IFS= read -r file; do
    [[ -n $file ]] || continue
    check_text "${file#"$top"/}" "$note" "$(<"$file")"
  done <<<"$hits"
}

# run_gitleaks <top> [--staged]: add gitleaks findings, summarized without the secret.
run_gitleaks() {
  local top=$1 report status summary line
  shift
  report=$(gitleaks git --pre-commit "$@" --redact --no-banner --exit-code 99 \
    --report-format json --report-path - "$top" 2>/dev/null)
  status=$?
  case $status in
    0) ;;
    99)
      summary=$(jq -r '.[]
        | select((.RuleID == "gcp-api-key"
                  and ((.File | split("/") | last) as $b
                       | ["firebase_options.dart", "google-services.json", "GoogleService-Info.plist"] | index($b))) | not)
        | "\(.File):\(.StartLine): gitleaks rule \(.RuleID)"' <<<"$report" 2>/dev/null) \
        || summary="gitleaks reported a secret (no details available)"
      while IFS= read -r line; do
        if [[ -n $line ]]; then FINDINGS+=("$line"); fi
      done <<<"$summary"
      ;;
    *) block "gitleaks failed (exit $status), so the commit could not be checked. plugin-flutter needs gitleaks 8.19 or later (gitleaks version); fix gitleaks or its configuration (.gitleaks.toml) first." ;;
  esac
}

# repo_cmd <dir> <loc>: set git_cmd for that location, or return 1 outside a work tree.
repo_cmd() {
  local dir=$1 loc=$2
  local -a loc_opts=()
  [[ -n $dir ]] || block "cannot tell which repository this commit runs in (a cd or -C target uses a variable). Run git commit from the project directory."
  # A directory created on the same line belongs to the repository of its nearest existing parent.
  while [[ -n $dir && ! -d $dir ]]; do dir=${dir%/*}; done
  dir=${dir:-/}
  while [[ $loc == *"$SW_SEP"* ]]; do loc_opts+=("${loc%%"$SW_SEP"*}"); loc=${loc#*"$SW_SEP"}; done
  git_cmd=(git -C "$dir" ${loc_opts[@]+"${loc_opts[@]}"} -c core.quotePath=false --no-pager)
  # Outside a repository git commit fails on its own: there is nothing to scan.
  "${git_cmd[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

TRACKED_NOTE=" (not staged yet: the commit includes it through -a, a path, or git add on the same line)"
UNTRACKED_NOTE=" (untracked: the git add on the same line includes it)"
SCANNED=$SW_SEP

# once <key>: true the first time a key is seen.
once() {
  [[ $SCANNED != *"$SW_SEP$1$SW_SEP"* ]] || return 1
  SCANNED+=$1$SW_SEP
}

scan_commit() {
  local dir=$1 loc=$2 scope=$3 top
  local -a git_cmd
  repo_cmd "$dir" "$loc" || return 0
  top=$("${git_cmd[@]}" rev-parse --show-toplevel) || block "cannot find the top of the repository."
  if once "index$SW_SEP$top"; then
    scan_diff --cached ""
    if command -v gitleaks >/dev/null 2>&1; then run_gitleaks "$top" --staged; fi
  fi
  if [[ -n $scope ]] && once "tree$SW_SEP$dir$SW_SEP$scope"; then
    pathspecs "$scope"
    scan_diff "" "$TRACKED_NOTE" ${PATHS[@]+"${PATHS[@]}"}
    tree_gitleaks "$top" "$scope"
  fi
}

# tree_gitleaks <top> <scope>: gitleaks reads the whole work tree diff, so only for a whole-tree scope.
tree_gitleaks() {
  if [[ $2 == ALL ]] && command -v gitleaks >/dev/null 2>&1 && once "gitleaks-tree$SW_SEP$1"; then run_gitleaks "$1"; fi
}

scan_stage() {
  local dir=$1 loc=$2 scope=$3 untracked=$4 top
  local -a git_cmd
  repo_cmd "$dir" "$loc" || return 0
  once "stage$SW_SEP$dir$SW_SEP$scope$SW_SEP$untracked" || return 0
  pathspecs "$scope"
  scan_diff "" "$TRACKED_NOTE" ${PATHS[@]+"${PATHS[@]}"}
  if ((untracked)); then scan_untracked "$UNTRACKED_NOTE" ${PATHS[@]+"${PATHS[@]}"}; fi
  top=$("${git_cmd[@]}" rev-parse --show-toplevel) || block "cannot find the top of the repository."
  tree_gitleaks "$top" "$scope"
}

scan_code "$command" 0 "$cwd"
((${#COMMIT_DIRS[@]})) || allow
[[ -z $REFUSE ]] || block "$REFUSE"
for tool in git grep awk tr sort; do
  command -v "$tool" >/dev/null 2>&1 || block "$tool is required to inspect commits and was not found in PATH."
done

# A cd inside a subshell, ( ... ), does not move the commands after it: scan the starting
# directory too when a commit seems to run elsewhere.
subshell=0
if [[ ${command//'$('/} == *'('* ]]; then subshell=1; fi

for k in "${!COMMIT_DIRS[@]}"; do
  scan_commit "${COMMIT_DIRS[k]}" "${COMMIT_LOCS[k]}" "${COMMIT_SCOPES[k]}"
  if ((subshell)) && [[ ${COMMIT_DIRS[k]} != "$cwd" ]]; then scan_commit "$cwd" "" "${COMMIT_SCOPES[k]}"; fi
done
for k in "${!STAGE_DIRS[@]}"; do
  scan_stage "${STAGE_DIRS[k]}" "${STAGE_LOCS[k]}" "${STAGE_SCOPES[k]}" "${STAGE_UNTRACKED[k]}"
done
((${#FINDINGS[@]})) || allow

block "this commit would include secrets:
$(printf '  - %s\n' "${FINDINGS[@]}" | sort -u)
Never print a secret, and do not move or rewrite anything before you ask the user: tell them which file holds what. Then propose to unstage the file (git restore --staged <file>, or git rm --cached <file> before the first commit; an untracked file only needs to stay out of git add) and to move the secret out of the code (environment variable, untracked file listed in .gitignore).
If it is a false positive, such as an example key in a test, only the user can commit it: they run the commit themselves with the ! prefix."
