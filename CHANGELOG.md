# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne, mineure pour un skill ou un agent ajouté, majeure pour un changement de format de `.forge/` qui casse la reprise.

## [0.3.0] — 2026-10-20

Mettre à jour les dépendances par lots validés, adopter une app existante sans rien réécrire, repérer les écarts entre les documents et le code. Le format de `.forge/` ne change pas.

### Ajouté

- Skill `update-project` : inventaire en lecture seule (`flutter pub outdated --json`), classement en compatibles, majeures, retenues et signalées, plan de lots que vous validez, puis un lot à la fois sur `chore/deps-<slug>`, avec analyse et tests après chacun, un commit par lot avec son lockfile, un ADR `proposed` par majeure, et un rapport avant/après dans `.forge/reports/deps-<date>-<slug>.md`. Un lockfile périmé est resynchronisé dans un commit à part, après votre accord. Le skill ne lance jamais `flutter upgrade`, `downgrade` ni `channel` : le SDK appartient à la machine, et vous le changez vous-même (configuration Nix, ou `! flutter upgrade`) ; le skill vérifie ensuite et rappelle d'aligner `flutter-version` dans la CI.
- Skill `adopt-existing-project` : analyse en lecture seule d'une app existante, sans `pub get` qui réécrirait `pubspec.lock` (`--enforce-lockfile`, `--no-pub`) ; plan de mise en conformité que vous validez item par item ; puis `.forge/`, documents manquants reconstruits depuis le code en DRAFT, liste des divergences, sur `chore/adopt-plugin-flutter`. Aucun fichier existant n'est réécrit sans son diff approuvé, aucun code n'est déplacé. Une adoption interrompue reprend où elle s'était arrêtée.
- Agent `product-architect` (modèle de la session) : PRD et critères d'acceptation numérotés `AC-xxx`, testables, jamais renumérotés ; tâches `draft` (un besoin) et `reconstruct` (le code d'une app existante, critères marqués « reconstructed »). Écrit seulement sous `docs/product/`, sans shell.
- Détection des divergences entre documents et code : une étape d'`adopt-existing-project`, un bloc `DIVERGENCES` dans le rapport du code-reviewer (dépendance sans ADR, critère sans test, plan contredit), traité à l'étape 14 de `create-feature` et en fin de `debug-project`.
- Scénarios comportementaux 6 (adoption), 10 (mise à jour d'un lot de dépendances, critère de sortie de la v0.3), 11 (tâche `build` de devops-engineer) et 12 (diagnostic d'une CI rouge).

### Modifié

- `templates/project-settings.json` : les commandes de `flutter pub` qui ne modifient rien (`get --enforce-lockfile`, `outdated`, `deps`, `add --dry-run`), `flutter --version --machine` et `git status <options>` passent sans demander ; `flutter pub upgrade` sans argument, `flutter upgrade`, `flutter downgrade` et `flutter channel` demandent d'abord. Un projet créé avec la v0.2 garde ses règles : les ajouter à la main (voir [Installation](docs/INSTALLATION.md#mettre-à-jour-un-projet-créé-avec-la-v02)).
- `agent-scope-guard` : périmètre de product-architect (`docs/product/`, aucune commande) ; un agent sans liste de commandes ne peut plus rien lancer.
- `bootstrap-project` confie le PRD d'un brief long à product-architect. `create-feature` traite les divergences relevées à la revue : une modification du PRD ou du TRD y devient un point de validation.
- `flutter-architect` ne lance `flutter pub deps` que sur un lockfile à jour, puisque la commande réécrit un lockfile périmé ; pour une app adoptée, il décrit la pile existante et propose ses ADR.
- `git-workflow` connaît les branches `chore/deps-<slug>`, `chore/ci` et `chore/adopt-plugin-flutter`.

### Corrigé

- `bootstrap-project` : en mode non interactif, `.forge/config.yaml` n'était jamais créé, puisque protect-sensitive refuse l'écriture sans proposer d'autre voie. Le skill donne désormais la commande à lancer vous-même.
- `github-workflow` : la commande `sed` qui remplit le gabarit de CI cassait sur un nom de branche contenant `/`. Elle utilise désormais `|` comme délimiteur.

## [0.2.0] — 2026-10-20

Publier sur GitHub avec une CI, ouvrir une pull request, corriger une erreur avec méthode ; deux garde-fous de plus. Le format de `.forge/` ne change pas.

### Ajouté

- Skill `github-workflow` : `gh auth status` d'abord, sans jamais manipuler de jeton ; création du dépôt distant après confirmation du propriétaire, du nom et de la visibilité ; ajout de la CI avec son coût ; pull request dont le corps classe les tests en quatre catégories et les plateformes en trois états ; suivi des checks et diagnostic d'une CI rouge. Il ne fusionne jamais.
- Skill `debug-project` : reproduire, classer, trouver la cause racine avec preuve, test de non-régression ROUGE puis VERT, correctif minimal sur `fix/<slug>`, revue, commit `fix(…)`.
- Agent `devops-engineer` (`sonnet`) : builds par plateforme et lecture des journaux de CI ; écrit seulement sous `.github/`, n'exécute que des commandes `flutter build`, `gh` et git en lecture ; ne pousse pas, n'ouvre pas de PR, ne relance pas de CI.
- Hook `secret-scan` (fail-closed pour un commit) : bloque un commit qui contient un fichier de secrets (`.env`, keystore, `key.properties`, `.p12`, `.pfx`) ou, dans une ligne ajoutée, une clé privée, une clé AWS, un jeton GitHub, une clé `sk-` ou une clé Google (sauf dans la configuration Firebase) ; ne lit que ce que le commit peut inclure ; refuse `git init`, `git clone`, `git add -f` et `git apply --cached` sur la ligne d'un commit ; lance aussi gitleaks s'il est installé ; n'affiche jamais le secret.
- Hook `protect-sensitive` : dans un projet qui a `.forge/` (cherché depuis le fichier), demande confirmation avant d'écrire un fichier de signature, des entitlements ou du code de CI (`.github/workflows/`, `.github/actions/`) ; `.forge/config.yaml` est protégé partout.
- Gabarit `templates/github-workflows/flutter-ci.yml` : format, analyse et tests sur un runner Linux, actions épinglées par SHA (`actions/checkout` v7.0.1, `subosito/flutter-action` v2.23.0), jeton en lecture seule, version de Flutter fixée sur la version locale.
- Scénarios comportementaux 7 (secret-scan), 8 (debug-project) et 9 (PR avec CI verte, critère de sortie de la v0.2).

### Modifié

- `templates/project-settings.json` : les `gh` en lecture, `git remote -v`, `git rev-parse` et les commandes locales `flutter build`, `flutter doctor`, `flutter devices` passent sans demander ; `gh repo create`, `gh pr edit`, `gh issue create`, `gh run rerun` et `gh workflow run` demandent d'abord. Un projet créé avec la v0.1 garde ses règles : les ajouter à la main (voir [Installation](docs/INSTALLATION.md#mettre-à-jour-un-projet-créé-avec-la-v01)).
- `git-workflow`, `create-feature`, `bootstrap-project` et `recover-session` renvoient vers les nouveaux skills.
- `create-feature`, `bootstrap-project` et `debug-project` exigent `flutter analyze` à exit 0 : infos et avertissements y sont bloquants par défaut, comme dans la CI. En v0.1, les avertissements étaient seulement listés.

### Exigences

- `gh` 2.x connecté pour `github-workflow` ; gitleaks 8.19 ou plus recommandé.

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
