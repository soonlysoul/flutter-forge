#!/usr/bin/env bash
# secret-scan: PreToolUse hook on Bash|PowerShell|Monitor. Before a git commit, blocks secret
# file names and secret patterns in the lines the commit can add. Fail-closed for commits,
# silent for every other command. Runs against real throwaway git repositories.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_secret_scan
SCAN="$SCRIPTS/secret-scan.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Fake secrets are assembled at run time, so that this file holds none of the patterns.
AWS="AKIA""IOSFODNN7EXAMPLE"
GHP="ghp""_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"
PAT="github""_pat_11ABCDEFG0123456789_abcdefghijklmnopqrstuvwxyz"
SKA="sk""-ant-api03-AbCdEfGhIjKlMnOpQrStUv"
GOOG="AIza""SyA1234567890abcdefghijklmnopqrstuv"
PEM="-----BEGIN ""RSA PRIVATE KEY-----"
CERT="-----BEGIN ""CERTIFICATE-----"
ALL_SECRETS=("$AWS" "$GHP" "$PAT" "$SKA" "$GOOG")

# The hook runs without gitleaks unless a test puts a fake one first in PATH.
base_path=$(restricted_path jq git grep sed awk cat head tr sort mktemp rm dirname)

# make_repo [nohead]: a repository with one committed file, notes.txt. Prints its path.
make_repo() {
  local repo
  repo=$(mktemp -d "$work/repo.XXXXXX")
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name Test
  git -C "$repo" config commit.gpgsign false
  echo "notes" >"$repo/notes.txt"
  if [[ ${1-} != nohead ]]; then
    git -C "$repo" add notes.txt
    git -C "$repo" commit -qm init
  fi
  printf '%s' "$repo"
}

# stage <repo> <file> <content>
stage() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
  git -C "$1" add -- "$2"
}

# scan <command> <cwd> [env...]
scan() {
  local command=$1 cwd=$2
  shift 2
  run_hook "$SCAN" "$(bash_input "$command" Bash "$cwd")" PATH="$base_path" "$@"
}

# expect_secret <label> <needle...>: blocked, every needle in the reason, no secret printed.
expect_secret() {
  local label=$1 needle secret missing=""
  shift
  if [[ $HOOK_STATUS != 2 || -z $HOOK_STDERR ]]; then
    fail "$label" "expected exit 2 with a reason, got exit $HOOK_STATUS; stderr: ${HOOK_STDERR:0:300}"
    return
  fi
  for needle in "$@"; do [[ $HOOK_STDERR == *"$needle"* ]] || missing+=" [$needle]"; done
  for secret in "${ALL_SECRETS[@]}"; do [[ $HOOK_STDERR != *"$secret"* ]] || missing+=" [secret printed]"; done
  [[ -z $missing ]] && pass "$label" || fail "$label" "missing in the reason:$missing; stderr: ${HOOK_STDERR:0:400}"
}

echo "# commands that do not commit"
repo=$(make_repo)
stage "$repo" leak.txt "key=$AWS"
nojq=$(restricted_path)
run_hook "$SCAN" "$(bash_input 'ls -la' Bash "$repo")" PATH="$nojq"
expect_silent_allow "a command without 'commit' passes, even without jq"
rm -r "$nojq"
scan 'git status' "$repo"
expect_silent_allow "git status passes"
scan 'echo "git commit -m x"' "$repo"
expect_silent_allow "quoted text that mentions git commit passes"
scan 'git log --grep commit' "$repo"
expect_silent_allow "git log --grep commit passes"
run_hook "$SCAN" '{"tool_name": "Read", "tool_input": {"file_path": "/work/commit.txt"}}' PATH="$base_path"
expect_silent_allow "a non-shell tool passes"
run_hook "$SCAN" '{"tool_name": "Monitor", "tool_input": {"ws": {"url": "wss://example.test/commit"}}}' PATH="$base_path"
expect_silent_allow "a Monitor WebSocket call passes"

echo "# clean commits"
repo=$(make_repo)
stage "$repo" lib/notes.dart "final notes = <String>[];"
scan 'git commit -m "feat(notes): add notes"' "$repo"
expect_silent_allow "staged change without secret passes"
stage "$repo" docs/cert.md "$CERT"
scan 'git commit -m x' "$repo"
expect_silent_allow "a public certificate header passes"
stage "$repo" docs/risk.md "see task-abcdefghijklmnopqrstuvwxyz0123 and disk-0123456789abcdefghijk"
scan 'git commit -m x' "$repo"
expect_silent_allow "sk- inside a word (task-, disk-) passes"
stage "$repo" .env.example "API_KEY=changeme"
scan 'git commit -m x' "$repo"
expect_silent_allow ".env.example passes"
repo=$(make_repo nohead)
git -C "$repo" add notes.txt
scan 'git commit -m init' "$repo"
expect_silent_allow "first commit, before any HEAD, passes when clean"
plain=$(mktemp -d "$work/plain.XXXXXX")
scan 'git commit -m x' "$plain"
expect_silent_allow "outside a repository there is nothing to scan"

echo "# secret patterns in staged lines"
repo=$(make_repo)
stage "$repo" lib/aws.dart "const key = '$AWS';"
scan 'git commit -m x' "$repo"
expect_secret "AWS access key is blocked" lib/aws.dart AWS
repo=$(make_repo)
stage "$repo" deploy/id_rsa "$PEM"
scan 'git commit -m x' "$repo"
expect_secret "private key is blocked" deploy/id_rsa "private key"
repo=$(make_repo)
stage "$repo" ci/token.txt "$GHP"
scan 'git commit -m x' "$repo"
expect_secret "GitHub token ghp_ is blocked" ci/token.txt GitHub
repo=$(make_repo)
stage "$repo" ci/pat.txt "token: $PAT"
scan 'git commit -m x' "$repo"
expect_secret "GitHub token github_pat_ is blocked" ci/pat.txt GitHub
repo=$(make_repo)
stage "$repo" lib/llm.dart "final apiKey = \"$SKA\";"
scan 'git commit -m x' "$repo"
expect_secret "sk- API key is blocked" lib/llm.dart sk-
repo=$(make_repo)
stage "$repo" "lib/my config.dart" "const maps = '$GOOG';"
scan 'git commit -m x' "$repo"
expect_secret "Google API key in a path with a space is blocked" "lib/my config.dart" Google
repo=$(make_repo nohead)
stage "$repo" lib/aws.dart "$AWS"
scan 'git commit -m init' "$repo"
expect_secret "first commit with a secret is blocked" lib/aws.dart
[[ $HOOK_STDERR == *"git rm --cached"* ]] && pass "the reason explains how to unstage before the first commit" \
  || fail "the reason explains how to unstage before the first commit" "${HOOK_STDERR:0:300}"
[[ $HOOK_STDERR == *"!"* && $HOOK_STDERR == *"false positive"* ]] && pass "the reason says only the user lifts a false positive" \
  || fail "the reason says only the user lifts a false positive" "${HOOK_STDERR:0:300}"

repo=$(make_repo)
stage "$repo" old.txt "$AWS"
git -C "$repo" commit -qm "old secret"
git -C "$repo" rm -q old.txt
scan 'git commit -m "remove the secret"' "$repo"
expect_silent_allow "removing a line that holds a secret passes"
repo=$(make_repo)
printf '%s\n' "$AWS" >>"$repo/notes.txt"
stage "$repo" lib/clean.dart "void main() {}"
scan 'git commit -m x' "$repo"
expect_silent_allow "an unstaged secret is not part of a plain commit"

echo "# secret file names"
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
scan 'git commit -m x' "$repo"
expect_secret ".env is blocked" .env
repo=$(make_repo)
stage "$repo" config/.env.production "DEBUG=0"
scan 'git commit -m x' "$repo"
expect_secret ".env.production is blocked" config/.env.production
repo=$(make_repo)
mkdir -p "$repo/android/app"
printf '\xfe\xed\xfe\xed\x00\x00\x00\x02' >"$repo/android/app/upload.jks"
git -C "$repo" add android/app/upload.jks
scan 'git commit -m x' "$repo"
expect_secret "binary .jks keystore is blocked" android/app/upload.jks keystore
repo=$(make_repo)
stage "$repo" release.keystore "x"
scan 'git commit -m x' "$repo"
expect_secret ".keystore is blocked" release.keystore
repo=$(make_repo)
stage "$repo" android/key.properties "storePassword=x"
scan 'git commit -m x' "$repo"
expect_secret "key.properties is blocked" android/key.properties
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
git -C "$repo" commit -qm "tracked by mistake"
git -C "$repo" rm -q --cached .env
scan 'git commit -m "untrack .env"' "$repo"
expect_silent_allow "untracking .env passes"

echo "# what the commit can include besides the index"
repo=$(make_repo)
printf '%s\n' "$AWS" >>"$repo/notes.txt"
scan 'git commit -a -m x' "$repo"
expect_secret "git commit -a includes unstaged changes" notes.txt "not staged"
scan 'git commit -am x' "$repo"
expect_secret "git commit -am includes unstaged changes" notes.txt
scan 'git commit --all -m x' "$repo"
expect_secret "git commit --all includes unstaged changes" notes.txt
scan 'git commit -m x notes.txt' "$repo"
expect_secret "git commit <path> includes that path" notes.txt
scan 'git commit -m "msg with notes.txt"' "$repo"
expect_silent_allow "a message is not a path"
scan 'git commit -F msg.txt' "$repo"
expect_silent_allow "the value of -F is not a path"
repo=$(make_repo)
printf '%s\n' "$GHP" >"$repo/new.txt"
scan 'git add new.txt && git commit -m x' "$repo"
expect_secret "git add on the same line includes untracked files" new.txt GitHub
scan 'git commit -m x' "$repo"
expect_silent_allow "an untracked file is not part of a plain commit"
repo=$(make_repo)
printf '%s\n' "$AWS" >"$repo/ignored.txt"
echo "ignored.txt" >"$repo/.gitignore"
stage "$repo" .gitignore "ignored.txt"
scan 'git add -A && git commit -m x' "$repo"
expect_silent_allow "an ignored file is not part of the commit"
scan 'git commit --amend --no-edit' "$repo"
expect_silent_allow "git commit --amend with a clean index passes"

echo "# where the commit runs"
repo=$(make_repo)
mkdir "$repo/sub"
inner=$(make_repo)
stage "$inner" lib/aws.dart "$AWS"
scan "cd $inner && git commit -m x" "$repo"
expect_secret "cd <repo> && git commit scans that repository" lib/aws.dart
scan "git -C $inner commit -m x" "$plain"
expect_secret "git -C <repo> commit scans that repository" lib/aws.dart
scan "bash -c 'git commit -m x'" "$inner"
expect_secret "bash -c 'git commit' is scanned" lib/aws.dart
scan "sudo -u bob git commit -m x" "$inner"
expect_secret "a wrapper before git commit is scanned" lib/aws.dart
scan "FOO=1 git -c user.name=x commit -m x" "$inner"
expect_secret "an assignment and git -c before commit are scanned" lib/aws.dart
scan 'eval "git commit -m x"' "$inner"
expect_secret "eval git commit is scanned" lib/aws.dart
scan 'echo "$(git commit -m x)"' "$inner"
expect_secret "git commit inside \$(...) is scanned" lib/aws.dart
scan "cd sub && git commit -m x" "$repo"
expect_silent_allow "cd into a clean subdirectory scans its clean repository"
stage "$inner" sub/deep.txt "x"
scan 'cd sub && git commit -m x' "$inner"
expect_secret "a commit from a subdirectory scans the whole index" lib/aws.dart
scan 'cd "$PROJECT" && git commit -m x' "$repo"
expect_blocked "a cd target that cannot be resolved blocks the commit"

echo "# fail-closed"
run_hook "$SCAN" '{"tool_name": "Bash", "tool_input": {"command": "git commit -m x"' PATH="$base_path"
expect_blocked "malformed input that mentions commit is blocked"
run_hook "$SCAN" '{"tool_name": "Bash", "tool_input": {"command": 42}, "x": "commit"}' PATH="$base_path"
expect_blocked "a non-string command is blocked"
nojq=$(restricted_path git)
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$inner")" PATH="$nojq"
expect_blocked "missing jq blocks a commit"
[[ $HOOK_STDERR == *jq* ]] && pass "missing jq is named in the reason" || fail "missing jq is named in the reason" "$HOOK_STDERR"
rm -r "$nojq"
nolib=$(mktemp -d "$work/nolib.XXXXXX")
cp "$SCAN" "$nolib/"
run_hook "$nolib/secret-scan.sh" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$base_path"
expect_blocked "missing shell lexer library blocks a commit"

echo "# gitleaks, when installed"
fake=$(mktemp -d "$work/fake.XXXXXX")
cp -P "$base_path"/* "$fake/"
cat >"$fake/gitleaks" <<EOF
#!$BASH
printf '%s\n' "\$*" >>"$work/gitleaks.log"
case \${FAKE_GITLEAKS:-clean} in
  clean) echo '[]'; exit 0 ;;
  leak) echo '[{"RuleID": "generic-api-key", "File": "lib/conf.dart", "StartLine": 3, "Secret": "REDACTED"}]'; exit 99 ;;
  error) echo "gitleaks: broken config" >&2; exit 1 ;;
esac
EOF
chmod +x "$fake/gitleaks"
gitleaks_calls() { if [[ -f $work/gitleaks.log ]]; then cat "$work/gitleaks.log"; fi; }
repo=$(make_repo)
stage "$repo" lib/notes.dart "final notes = 1;"
rm -f "$work/gitleaks.log"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake"
expect_silent_allow "clean gitleaks run passes"
calls=$(gitleaks_calls)
[[ $calls == *"git"*"--pre-commit"*"--staged"* && $calls == *"--redact"* ]] \
  && pass "gitleaks git --pre-commit --staged --redact is called" || fail "gitleaks git --pre-commit --staged --redact is called" "calls: $calls"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=leak
expect_secret "a gitleaks finding blocks the commit" lib/conf.dart:3 generic-api-key
[[ $HOOK_STDERR != *REDACTED* ]] && pass "the gitleaks report is summarized, not copied" || fail "the gitleaks report is summarized, not copied" "$HOOK_STDERR"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=error
expect_blocked "a gitleaks error blocks the commit (fail-closed)"
[[ $HOOK_STDERR == *gitleaks* ]] && pass "the gitleaks error is named" || fail "the gitleaks error is named" "$HOOK_STDERR"
rm -f "$work/gitleaks.log"
run_hook "$SCAN" "$(bash_input 'git commit -a -m x' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 2 && $(grep -c -- '--staged' <<<"$calls") == 1 ]] \
  && pass "git commit -a also has gitleaks scan the unstaged changes" || fail "git commit -a also has gitleaks scan the unstaged changes" "calls: $calls"
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake"
expect_secret "file names are checked even when gitleaks finds nothing" .env

echo "# speed"
repo=$(make_repo)
for i in $(seq 1 40); do printf 'line %s\n' "$i" >"$repo/file$i.txt"; done
git -C "$repo" add .
start=$(date +%s%N)
scan 'git commit -m "forty files"' "$repo"
elapsed=$((($(date +%s%N) - start) / 1000000))
expect_silent_allow "a 40-file commit passes"
((elapsed < 5000)) && pass "a 40-file commit is scanned in $elapsed ms (< 5000)" || fail "a 40-file commit is scanned in under 5 s" "$elapsed ms"

finish
