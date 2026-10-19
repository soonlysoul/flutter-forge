# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne, mineure pour un skill ou un agent ajouté, majeure pour un changement de format de `.forge/` qui casse la reprise.

## [0.1.0] — 2026-10-18

Première version : créer un projet, développer une fonctionnalité en TDD, committer proprement, reprendre après une interruption.

### Ajouté

- Skills `bootstrap-project`, `create-feature` (15 étapes TDD), `git-workflow`, `recover-session`.
- Agents `flutter-architect`, `test-engineer`, `code-reviewer`, avec rapport final au format STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS.
- Hooks :
  - `guard-destructive` (fail-closed) ;
  - `agent-scope-guard` (fail-closed pour les agents du plugin, inerte ailleurs) ;
  - `format-dart` (fail-open) ;
  - `checkpoint-reminder`.
- Gabarits : `project-settings.json`, `forge-config.yaml`, `checkpoint.md`, et les documents PRD, TRD, plan d'implémentation, DECISIONS et `CLAUDE.md` de projet.
- Marketplace locale `dart-multiplatform-forge`.
- Tests déterministes `tests/run-all.sh`, sans réseau ni quota : 9 suites et `claude plugin validate --strict` sur le manifeste, la marketplace, les agents et les skills.
- Scénarios comportementaux 1 à 5 dans `tests/scenarios/`, exécutés à la main avec le quota.

### Validé

- Scénarios 1 à 5 exécutés le 2026-10-19 en sessions réelles (Claude Code 2.1.296, Flutter 3.44.3, Linux) : tous réussis, le scénario 1 avec une réserve (`.claude/settings.json` copié à la main en mode `-p`).

### Exigences

- Claude Code 2.1.295 ou plus (`onFailure` des hooks), `jq`, `git`, Flutter stable.
