# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne, mineure pour un skill ou un agent ajouté, majeure pour un changement de format de `.forge/` qui casse la reprise.

## [0.1.2] — 2026-10-19

### Modifié

- Le plugin s'appelle désormais `plugin-flutter` (ex-`flutter-forge`). Les commandes deviennent `/plugin-flutter:<skill>`, les agents `plugin-flutter:<agent>`. Le format de `.forge/` ne change pas.
- Le dépôt devient `soonlysoul/plugin-flutter` ; GitHub redirige l'ancienne adresse.
- Depuis la 0.1.1, sur chaque appareil : `claude plugin marketplace update soon`, `claude plugin uninstall flutter-forge@soon`, puis `claude plugin install plugin-flutter@soon`. Le `CLAUDE.md` d'un projet déjà créé cite encore `/flutter-forge:…` : à corriger à la main.

## [0.1.1] — 2026-10-19

### Modifié

- Le plugin s'appelle désormais `flutter-forge` (ex-`dart-multiplatform-forge`). Les commandes deviennent `/flutter-forge:<skill>`, les agents `flutter-forge:<agent>`. Le format de `.forge/` ne change pas.
- Auteur et titulaire de la licence MIT : `Soon`.

### Ajouté

- Publication dans le dépôt public `soonlysoul/flutter-forge` ; `homepage` et `repository` dans `plugin.json`.
- Installation sur tout appareil depuis la marketplace `soon` (`soonlysoul/claude-plugins`) : `claude plugin install flutter-forge@soon`.

## [0.1.0] — 2026-10-19

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
