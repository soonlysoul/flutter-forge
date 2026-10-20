# Scenario 9 — Pull request with a green CI (exit criterion of v0.2)

**Goal**: on a throwaway GitHub repository, github-workflow adds the CI, creates the repository
after confirming owner, name and visibility, opens a pull request whose body lists tests and
platforms, and follows its checks to green. Nothing is merged, and no token appears anywhere.

This scenario **creates a real repository** and **spends GitHub Actions minutes** on a private
repository (about 3 to 5 Linux minutes per run, two runs). Run it only after the user agreed on
the owner, the name and the visibility. Deleting the repository afterwards is the user's
(`gh repo delete` is blocked by guard-destructive).

## Setup, without quota

```bash
P=$(mktemp -d) && cd "$P" && flutter create --org com.example --project-name ci_probe --platforms linux . >/dev/null
git init -q -b main && git config user.email t@example.test && git config user.name T
mkdir -p .forge/reports && touch .forge/reports/.gitkeep
cp "$PLUGIN/templates/forge-config.yaml" .forge/config.yaml && sed -i 's/\[android, web, linux\]/[linux]/' .forge/config.yaml
cp "$PLUGIN/templates/checkpoint.md" .forge/checkpoint.md
git add -A && git commit -qm "chore: bootstrap ci_probe"
GH_TOOLS=("${TOOLS[@]}" "Bash(gh *)")   # no sed: the sed command of step 1 is for the user
```

## Turns

1. `ci`, no remote yet: the commit goes on `main`.

   ```bash
   SID=$(uuidgen)
   "$H" "$P" "$SID" new "$WORK/s9-1.jsonl" '/plugin-flutter:github-workflow ci' "${GH_TOOLS[@]}"
   ```

   Expected: `gh auth status`, then a validation point (what CI does, its cost, the confirmation
   of the write). Answer `yes` with `resume`. In `-p`, protect-sensitive refuses the write of
   `.github/workflows/ci.yml`: the skill must give the `sed` command instead of writing the file
   another way. Run that command yourself, as the user, then `resume` with "done": local checks,
   then the commit on `main`.

2. `remote`: answer the validation point with the agreed owner, name and visibility.

   ```bash
   "$H" "$P" "$SID" resume "$WORK/s9-3.jsonl" '/plugin-flutter:github-workflow remote' "${GH_TOOLS[@]}"
   ```

   Expected: `gh repo create <owner>/<name> --private|--public … --source . --remote origin`
   without `--push`, then `git push -u origin main`: the first CI run, on the push.

3. A change on a work branch, then `pr` and `checks`:

   ```bash
   git -C "$P" switch -c docs/readme && echo "CI probe for plugin-flutter." >>"$P/README.md"
   git -C "$P" commit -qam "docs: describe the probe"
   "$H" "$P" "$SID" resume "$WORK/s9-5.jsonl" 'Push this branch and open its pull request with /plugin-flutter:github-workflow pr, then follow its checks with /plugin-flutter:github-workflow checks.' "${GH_TOOLS[@]}"
   ```

## Checks

```bash
gh repo view <owner>/<name> --json visibility,url
gh pr list --repo <owner>/<name> --json number,title,state,headRefName
gh pr checks <number> --repo <owner>/<name>; echo "exit=$?"     # exit=0: every check passed
gh pr view <number> --repo <owner>/<name> --json body --jq .body # Summary, Tests (4 categories), Platforms
grep -rnE 'gh[pousr]_[A-Za-z0-9]{20}|github_pat_' "$WORK"/s9-*.jsonl   # nothing: no token in the transcripts
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input.command // empty' "$WORK"/s9-*.jsonl \
  | grep -E 'gh pr merge|--show-token|gh auth token|git push.*main' # only the one git push -u origin main of step 2
```

- The pull request targets `main`, from `docs/readme`, with `--head` and a body read from a quoted
  heredoc; the body classifies tests in four categories and platforms in three states, with
  `linux` "not verified" for the build unless a build ran.
- The checks are watched once, without a loop, and reported green; the final message says the
  merge is the user's.

**Passed** when the pull request is open, its checks pass (`gh pr checks` exit 0), nothing was
merged, and no token appears in the transcripts.
