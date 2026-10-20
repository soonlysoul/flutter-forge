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

echo "# a repository or directory created on the same line"
fresh=$(mktemp -d "$work/fresh.XXXXXX")
printf 'API=%s\n' "$AWS" >"$fresh/.env"
echo "void main() {}" >"$fresh/main.dart"
scan 'git init && git add . && git commit -m "Initial commit"' "$fresh"
expect_blocked "git init && git add . && git commit cannot be checked: blocked"
[[ $HOOK_STDERR == *"separate command"* ]] && pass "the reason asks to create the repository first" \
  || fail "the reason asks to create the repository first" "${HOOK_STDERR:0:300}"
scan 'git clone https://example.test/r.git r && cd r && git commit -m x' "$fresh"
expect_blocked "git clone on the same line as the commit is blocked"
repo=$(make_repo)
stage "$repo" leak.txt "$AWS"
scan 'mkdir -p tools/gen && cd tools/gen && git commit -m x' "$repo"
expect_secret "cd into a directory created on the line scans the enclosing repository" leak.txt
scan "(cd $plain && ls) && git commit -m x" "$repo"
expect_secret "a cd inside a subshell does not hide the starting repository" leak.txt

echo "# staging that the index does not show yet"
repo=$(make_repo)
echo ".env.production" >"$repo/.gitignore"
git -C "$repo" add .gitignore && git -C "$repo" commit -qm ignore
printf 'K=%s\n' "$AWS" >"$repo/.env.production"
scan 'git add -f .env.production && git commit -m x' "$repo"
expect_blocked "git add -f on the same line as the commit is blocked"
[[ $HOOK_STDERR == *"git add -f"* ]] && pass "the reason asks to force-add in a separate command" \
  || fail "the reason asks to force-add in a separate command" "${HOOK_STDERR:0:300}"
scan 'git add -fA && git commit -m x' "$repo"
expect_blocked "a grouped -f is seen"
scan 'git add --force .env.production' "$repo"
expect_silent_allow "git add -f alone does not commit"
printf 'diff --git a/n b/n\n' >"$repo/p.patch"
scan 'git apply --cached p.patch && git commit -m x' "$repo"
expect_blocked "git apply --cached on the same line as the commit is blocked"

echo "# only what the commit can include"
repo=$(make_repo)
printf 'API=%s\n' "$AWS" >"$repo/.env"
printf '%s\n' "$GHP" >"$repo/local-secrets.txt"
echo "more" >>"$repo/notes.txt"
echo "void main() {}" >"$repo/lib.dart"
scan 'git commit -am x' "$repo"
expect_silent_allow "git commit -a does not include untracked files"
scan 'git add lib.dart && git commit -m x' "$repo"
expect_silent_allow "git add <file> && git commit reads only that file"
scan 'git add lib.dart notes.txt && git commit -m x' "$repo"
expect_silent_allow "several named files are read, and only them"
scan 'git add . && git commit -m x' "$repo"
expect_secret "git add . includes every untracked file" .env local-secrets.txt "untracked"
scan 'git add -A && git commit -m x' "$repo"
expect_secret "git add -A includes every untracked file" .env
scan 'git add "$FILES" && git commit -m x' "$repo"
expect_secret "a path that cannot be resolved widens the scan" local-secrets.txt
repo=$(make_repo)
mkdir -p "$repo/sub" "$repo/other"
printf '%s\n' "$AWS" >"$repo/other/key.txt"
echo "x" >"$repo/sub/a.txt"
scan 'git add sub/ && git commit -m x' "$repo"
expect_silent_allow "git add <dir> reads only that directory"
scan 'cd other && git add . && git commit -m x' "$repo"
expect_secret "git add . from a subdirectory reads that directory" other/key.txt
printf '%s\n' "$AWS" >>"$repo/notes.txt"
echo "y" >"$repo/sub/b.txt"
git -C "$repo" add sub/b.txt
echo "z" >>"$repo/sub/b.txt"
scan 'git commit -m x sub/b.txt' "$repo"
expect_silent_allow "git commit <path> reads only that path"
scan 'git commit -m x notes.txt' "$repo"
expect_secret "git commit <path> reads that path" notes.txt
scan 'git commit -i -m x notes.txt' "$repo"
expect_secret "git commit -i <path> reads that path" notes.txt
scan 'git commit -o notes.txt -m x' "$repo"
expect_secret "git commit -o <path> reads that path" notes.txt
scan 'git commit --pathspec-from-file=list.txt -m x' "$repo"
expect_secret "--pathspec-from-file reads every unstaged change" notes.txt
scan 'git stage notes.txt && git commit -m x' "$repo"
expect_secret "git stage counts as git add" notes.txt

echo "# git location options"
inner2=$(make_repo)
stage "$inner2" lib/aws.dart "$AWS"
scan "git --git-dir=$inner2/.git --work-tree=$inner2 commit -m x" "$plain"
expect_secret "--git-dir and --work-tree point at the repository" lib/aws.dart
scan "pushd $inner2 && git commit -m x" "$plain"
expect_secret "pushd changes the directory like cd" lib/aws.dart

echo "# Firebase client configuration"
repo=$(make_repo)
stage "$repo" lib/firebase_options.dart "apiKey: '$GOOG',"
stage "$repo" android/app/google-services.json "\"current_key\": \"$GOOG\""
stage "$repo" ios/Runner/GoogleService-Info.plist "<string>$GOOG</string>"
scan 'git commit -m "chore: configure Firebase"' "$repo"
expect_silent_allow "Firebase client keys in their configuration files pass"
stage "$repo" lib/firebase_options.dart "apiKey: '$GOOG', aws: '$AWS'"
scan 'git commit -m x' "$repo"
expect_secret "another secret in a Firebase file is still blocked" lib/firebase_options.dart AWS
repo=$(make_repo)
stage "$repo" lib/maps.dart "const maps = '$GOOG';"
scan 'git commit -m x' "$repo"
expect_secret "a Google key elsewhere is blocked" lib/maps.dart Google
[[ $HOOK_STDERR == *"ask the user"* ]] && pass "the reason says to ask the user before moving anything" \
  || fail "the reason says to ask the user before moving anything" "${HOOK_STDERR:0:400}"

echo "# Apple signing files and hidden diffs"
repo=$(make_repo)
mkdir -p "$repo/ios"
printf '\x30\x82\x0a\x00' >"$repo/ios/dist.p12"
git -C "$repo" add ios/dist.p12
scan 'git commit -m x' "$repo"
expect_secret ".p12 certificate is blocked" ios/dist.p12
repo=$(make_repo)
stage "$repo" win/sign.pfx "x"
scan 'git commit -m x' "$repo"
expect_secret ".pfx certificate is blocked" win/sign.pfx
repo=$(make_repo)
stage "$repo" .gitattributes "*.json -diff"
git -C "$repo" commit -qm attrs
stage "$repo" config/keys.json "{\"aws\": \"$AWS\"}"
scan 'git commit -m x' "$repo"
expect_secret "a -diff attribute does not hide content" config/keys.json

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
for tool in grep awk; do
  partial=$(mktemp -d "$work/no$tool.XXXXXX")
  cp -P "$base_path"/* "$partial/"
  rm "$partial/$tool"
  run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$inner")" PATH="$partial"
  expect_blocked "missing $tool blocks a commit"
  [[ $HOOK_STDERR == *"$tool is required"* ]] && pass "missing $tool is named in the reason" || fail "missing $tool is named in the reason" "$HOOK_STDERR"
done
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
  firebase) echo '[{"RuleID": "gcp-api-key", "File": "lib/firebase_options.dart", "StartLine": 9, "Secret": "REDACTED"}]'; exit 99 ;;
  maps) echo '[{"RuleID": "gcp-api-key", "File": "lib/maps.dart", "StartLine": 2, "Secret": "REDACTED"}]'; exit 99 ;;
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
[[ $HOOK_STDERR == *gitleaks* && $HOOK_STDERR == *8.19* ]] && pass "the gitleaks error is named, with the minimum version" \
  || fail "the gitleaks error is named, with the minimum version" "$HOOK_STDERR"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=firebase
expect_silent_allow "a gitleaks gcp-api-key finding in firebase_options.dart passes"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake" FAKE_GITLEAKS=maps
expect_secret "a gitleaks gcp-api-key finding elsewhere blocks" lib/maps.dart:2
rm -f "$work/gitleaks.log"
run_hook "$SCAN" "$(bash_input 'git commit -a -m x' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 2 && $(grep -c -- '--staged' <<<"$calls") == 1 ]] \
  && pass "git commit -a also has gitleaks scan the unstaged changes" || fail "git commit -a also has gitleaks scan the unstaged changes" "calls: $calls"
rm -f "$work/gitleaks.log"
run_hook "$SCAN" "$(bash_input 'git commit -m x lib/notes.dart' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 1 ]] \
  && pass "a commit limited to a path does not have gitleaks read every unstaged change" \
  || fail "a commit limited to a path does not have gitleaks read every unstaged change" "calls: $calls"
rm -f "$work/gitleaks.log"
run_hook "$SCAN" "$(bash_input 'git add -A && git commit -m x' Bash "$repo")" PATH="$fake"
calls=$(gitleaks_calls)
[[ $(grep -c -- '--pre-commit' <<<"$calls") == 2 ]] \
  && pass "git add -A on the line has gitleaks read the unstaged changes" \
  || fail "git add -A on the line has gitleaks read the unstaged changes" "calls: $calls"
repo=$(make_repo)
stage "$repo" .env "DEBUG=1"
run_hook "$SCAN" "$(bash_input 'git commit -m x' Bash "$repo")" PATH="$fake"
expect_secret "file names are checked even when gitleaks finds nothing" .env

echo "# speed"
repo=$(make_repo)
for i in $(seq 1 800); do printf 'line %s\n' "$i" >"$repo/file$i.txt"; done
git -C "$repo" add .
start=$(date +%s%N)
scan 'git commit -m "eight hundred files"' "$repo"
elapsed=$((($(date +%s%N) - start) / 1000000))
expect_silent_allow "an 800-file commit passes"
((elapsed < 3000)) && pass "an 800-file commit is scanned in $elapsed ms (< 3000)" || fail "an 800-file commit is scanned in under 3 s" "$elapsed ms"

finish
