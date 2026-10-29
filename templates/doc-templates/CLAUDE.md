# <App name> — conventions for Claude

This project uses plugin-orchestrator for its workflows, and plugin-flutter for its Flutter part, the part named in `.forge/config.yaml`.

- Talk to the user in <language>. Code, identifiers and file contents stay in English.
- Workflows: `/plugin-orchestrator:create-feature` for any feature (TDD), `/plugin-orchestrator:git-workflow` for branches and commits, `/plugin-orchestrator:github-workflow` for the remote repository, pull requests and CI, `/plugin-orchestrator:recover-session` to resume interrupted work, `/plugin-orchestrator:debug-project` for an unexpected failure; `/plugin-flutter:update-project` for the dependencies and the Flutter SDK.
- State lives on disk: `.forge/checkpoint.md`, updated after each completed step, and the Git history. Never rely on what a previous session remembers.
- `.forge/config.yaml` is edited by the user only: the part, its language plugin and its toolchain.
- Layout: feature-first under `lib/features/<feature>/{data,domain,presentation}`; tests mirror `lib/` under `test/`.
- While developing, run targeted tests: `flutter test <files>`. At milestones only: full `flutter test`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`.
- Never report a test as passed without running it. Classify every result as passed, failed, blocked (reason) or not run.
- Git: branches `feature/`, `fix/`, `chore/deps-`, `docs/`; Conventional Commits; no `git add -A` without reviewing the diff; never a silent `git stash`.
- Documents move to APPROVED only on the user's explicit message, recorded with its date; an approved document that changes goes back to REVIEW.
