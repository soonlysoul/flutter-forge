#!/usr/bin/env bash
# guard-destructive: PreToolUse hook on Bash|PowerShell|Monitor, fail-closed.
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
SUITE=test_guard_destructive
GUARD="$SCRIPTS/guard-destructive.sh"

echo "# input contract and fail-closed behaviour"

run_hook "$GUARD" '{"tool_name": "Bash", "tool_input": {"command": "ls"'
expect_blocked "malformed JSON is blocked"

run_hook "$GUARD" ''
expect_blocked "empty input is blocked"

run_hook "$GUARD" '{"tool_input": {"command": "ls"}}'
expect_blocked "input without tool_name is blocked"

run_hook "$GUARD" '{"tool_name": "Bash", "tool_input": {"command": 42}}'
expect_blocked "non-string command is blocked"

nojq=$(restricted_path)
run_hook "$GUARD" "$(bash_input 'git status')" PATH="$nojq"
expect_blocked "missing jq blocks every command"
[[ $HOOK_STDERR == *jq* ]] && pass "missing jq is named in the reason" || fail "missing jq is named in the reason" "$HOOK_STDERR"
rm -r "$nojq"

run_hook "$GUARD" '{"tool_name": "Read", "tool_input": {"file_path": "/work/proj/a.txt"}}'
expect_silent_allow "non-shell tool passes"

run_hook "$GUARD" '{"tool_name": "Monitor", "tool_input": {"ws": {"url": "wss://example.test/feed"}}}'
expect_silent_allow "Monitor WebSocket call without command passes"

run_hook "$GUARD" "$(bash_input 'git status')"
expect_silent_allow "safe Bash command passes"

run_hook "$GUARD" "$(bash_input 'git reset --hard')"
expect_blocked "git reset --hard is blocked"
[[ $HOOK_STDERR == *guard-destructive* && $HOOK_STDERR == *reset* ]] \
  && pass "reason names the hook and the command" || fail "reason names the hook and the command" "$HOOK_STDERR"

run_hook "$GUARD" "$(bash_input 'git reset --hard' Monitor)"
expect_blocked "Monitor command is checked like Bash"

run_hook "$GUARD" "$(bash_input 'git reset --hard' PowerShell)"
expect_blocked "PowerShell command is checked like Bash"

echo "# command structure (probe: git reset --hard)"

# Each of these runs git reset --hard somewhere.
structure_blocked=(
  'cd sub && git reset --hard'
  'git status; git reset --hard'
  'true || git reset --hard'
  'git fetch | git reset --hard'
  'sleep 1 & git reset --hard'
  $'git status\ngit reset --hard'
  '(git reset --hard)'
  '{ git reset --hard; }'
  'if true; then git reset --hard; fi'
  '! git reset --hard'
  'FOO=1 git reset --hard'
  'sudo git reset --hard'
  'sudo -u bob git reset --hard'
  'env -i GIT_DIR=.git git reset --hard'
  'command git reset --hard'
  'nohup git reset --hard'
  'timeout 5 git reset --hard'
  'nice -n 5 git reset --hard'
  '/usr/bin/git reset --hard'
  '\git reset --hard'
  '"git" reset --hard'
  "g'i't reset \"--hard\""
  'git -C sub reset --hard'
  'git -c core.pager=cat reset --hard'
  'git --no-pager reset --hard'
  'bash -c "git reset --hard"'
  "sh -c 'cd x; git reset --hard'"
  'bash -lc "git reset --hard"'
  'eval "git reset --hard"'
  'eval git reset --hard'
  'echo $(git reset --hard)'
  'echo "$(git reset --hard)"'
  'echo `git reset --hard`'
  'x=$(git reset --hard)'
  'echo $(git reset --hard'
  $'bash <<EOF\ngit reset --hard\nEOF'
  $'cat <<EOF\n$(git reset --hard)\nEOF'
  $'cat <<EOF\nnote: `git reset --hard`\nEOF'
  $'git commit -F - <<EOF\nfix: $(git reset --hard)\nEOF'
  $'git reset \\\n  --hard'
  'git reset --hard # comment'
  $'ls # comment\ngit reset --hard'
)
for c in "${structure_blocked[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_blocked "blocked: ${c//$'\n'/\\n}"
done

# None of these runs git reset --hard: it only appears as data.
structure_allowed=(
  'git commit -m "docs: never run git reset --hard"'
  "git commit -m 'git reset --hard; rm -rf /'"
  'echo "git reset --hard"'
  'grep -rn "git reset --hard" docs/'
  "printf '%s\\n' 'git reset --hard'"
  $'git commit -F - <<\'EOF\'\nfeat: block git reset --hard\nEOF'
  $'cat > notes.md <<EOF\ngit reset --hard\nEOF'
  $'cat <<\'EOF\'\n$(git reset --hard)\nEOF'
  $'cat <<"EOF"\n`git reset --hard`\nEOF'
  $'cat <<\\EOF\n$(git reset --hard)\nEOF'
  $'cat <<-EOF\n\tgit reset --hard\n\tEOF\ngit status'
  'ls # git reset --hard'
  'git status && git log --oneline'
  'git commit -m "unterminated'
)
for c in "${structure_allowed[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_silent_allow "allowed: ${c//$'\n'/\\n}"
done

echo "# git rules"

git_blocked=(
  'git reset --hard HEAD~1'
  'git clean -f'
  'git clean -fd'
  'git clean -xdf'
  'git clean --force'
  'git push --force'
  'git push origin main --force'
  'git push -f origin main'
  'git push -uf origin feature/x'
  'git push --force-with-lease'
  'git push --force-with-lease=main:abc123 origin main'
  'git push --force-if-includes origin main'
  'git push origin +main'
  'git push origin +HEAD:main'
  'git push --delete origin feature/x'
  'git push -d origin feature/x'
  'git push origin :feature/x'
  'git push --mirror'
  'git push --tags'
  'git push --follow-tags origin main'
  'git push origin refs/tags/v1.0.0'
  'git push origin HEAD:refs/tags/v1'
  'git branch -D feature/x'
  'git branch --delete --force feature/x'
  'git branch -d -f feature/x'
  'git branch -df feature/x'
  'git checkout -- .'
  'git checkout -- lib/main.dart'
  'git checkout .'
  'git checkout HEAD -- lib'
  'git checkout -f main'
  'git restore lib/main.dart'
  'git restore .'
  'git restore --worktree lib/main.dart'
  'git restore --staged --worktree lib/main.dart'
  'git restore -SW lib/main.dart'
  'git restore --source=HEAD~1 lib/main.dart'
  'git stash drop'
  'git stash drop stash@{0}'
  'git stash clear'
  'git switch --discard-changes main'
  'git switch -f main'
)
for c in "${git_blocked[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_blocked "blocked: $c"
done

git_allowed=(
  'git status'
  'git diff --staged'
  'git log --oneline -10'
  'git add lib/main.dart test/main_test.dart'
  'git commit -m "feat(notes): list notes offline (AC-012)"'
  'git commit --amend --no-edit'
  'git push origin feature/x'
  'git push -u origin feature/x'
  'git push --dry-run origin feature/x'
  'git push --no-force-with-lease origin feature/x'
  'git switch -c feature/x'
  'git switch main'
  'git checkout -b feature/x'
  'git checkout main'
  'git restore --staged lib/main.dart'
  'git restore -S lib/main.dart'
  'git stash list'
  'git stash push -m "wip"'
  'git stash pop'
  'git branch -d merged-feature'
  'git branch --show-current'
  'git clean -n'
  'git clean --dry-run -d'
  'git reset --soft HEAD~1'
  'git reset HEAD lib/main.dart'
)
for c in "${git_allowed[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_silent_allow "allowed: $c"
done

echo "# rm, gh, pub, find and xargs rules (cwd: /work/proj)"

other_blocked=(
  'rm -rf lib'
  'rm -fr lib'
  'rm -Rf lib'
  'rm -r -f lib'
  'rm --recursive --force lib'
  'rm -rfv lib'
  'rm -rf /'
  'rm -rf ~'
  'rm -rf *'
  'rm -rf .'
  'rm -rf build/../lib'
  'rm -rf build lib'
  'rm -rf "$HOME/project"'
  'rm -rf /work/proj/lib'
  'rm -rf /other/build'
  'rm -rf -- lib'
  '/bin/rm -rf lib'
  'sudo rm -rf lib'
  'ls | xargs rm -rf'
  "find . -name '*.g.dart' -exec rm -rf {} \\;"
  'find . -execdir rm -rf {} +'
  'gh repo delete owner/repo --yes'
  'gh repo edit --visibility public'
  'gh repo edit owner/repo --visibility=private --accept-visibility-change-consequences'
  'gh pr merge 12 --squash'
  'gh release create v1.0.0'
  'gh release delete v1.0.0'
  'gh release upload v1.0.0 app.apk'
  'gh api -X DELETE repos/owner/repo'
  'gh api --method=DELETE repos/owner/repo'
  'gh api repos/owner/repo -XDELETE'
  'gh api --method delete repos/owner/repo'
  'flutter pub publish'
  'flutter pub publish --force'
  'dart pub publish'
  'dart pub publish -f'
  'flutter --suppress-analytics pub publish'
)
for c in "${other_blocked[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_blocked "blocked: $c"
done

other_allowed=(
  'rm -rf build'
  'rm -rf build/'
  'rm -rf ./build/app'
  'rm -rf build/*'
  'rm -rf /work/proj/build'
  'rm -rf /work/proj/build/app/outputs'
  'rm file.txt'
  'rm -f lib/old.dart'
  'rm -r tmpdir'
  'flutter clean'
  'gh pr create --title "Add notes" --body "AC-012"'
  'gh pr view 12'
  'gh pr list'
  'gh repo view'
  'gh repo edit --description "Notes app"'
  'gh release list'
  'gh release view v1.0.0'
  'gh api repos/owner/repo'
  'gh api -X GET repos/owner/repo'
  'flutter pub publish --dry-run'
  'dart pub publish -n'
  'flutter pub get'
  'dart pub deps'
  "find . -name '*.dart'"
  "find build -name '*.so'"
  'echo "rm -rf /"'
  'grep -r "rm -rf" docs/'
  'flutter test test/notes'
  'dart format lib test'
  'flutter analyze'
)
for c in "${other_allowed[@]}"; do
  run_hook "$GUARD" "$(bash_input "$c")"
  expect_silent_allow "allowed: $c"
done

nolib=$(mktemp -d)
cp "$GUARD" "$nolib/"
run_hook "$nolib/guard-destructive.sh" "$(bash_input 'git status')"
expect_blocked "missing shell lexer library blocks (fail-closed)"
rm -r "$nolib"

message=$'git commit -F - <<\'EOF\'\nfeat: long message\n'
for i in $(seq 1 400); do message+="line $i: mention git reset --hard and rm -rf / as plain text"$'\n'; done
message+=$'EOF'
start=$(date +%s%N)
run_hook "$GUARD" "$(bash_input "$message")"
elapsed_ms=$(( ($(date +%s%N) - start) / 1000000 ))
expect_silent_allow "long heredoc commit message passes"
(( elapsed_ms < 3000 )) && pass "long message analysed in ${elapsed_ms} ms (< 3000)" \
  || fail "long message analysed in under 3000 ms" "took ${elapsed_ms} ms"

finish
