# <App name> — conventions for Claude

This project uses the flutter-forge plugin.

- Talk to the user in <language>. Code, identifiers and file contents stay in English.
- Workflows: `/flutter-forge:create-feature` for any feature (TDD), `/flutter-forge:git-workflow` for branches and commits, `/flutter-forge:recover-session` to resume interrupted work.
- State lives on disk: `.forge/checkpoint.md`, updated after each completed step, and the Git history. Never rely on what a previous session remembers.
- `.forge/config.yaml` is edited by the user only.
- Layout: feature-first under `lib/features/<feature>/{data,domain,presentation}`; tests mirror `lib/` under `test/`.
- While developing, run targeted tests: `flutter test <files>`. At milestones only: full `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`.
- Never report a test as passed without running it. Classify every result as passed, failed, blocked (reason) or not run.
- Git: branches `feature/`, `fix/`, `chore/deps-`, `docs/`; Conventional Commits; no `git add -A` without reviewing the diff; never a silent `git stash`.
- Documents move to APPROVED only on the user's explicit message, with the date.
