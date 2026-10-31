# Journal des versions

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ; versionnage [SemVer](https://semver.org/lang/fr/) : correctif pour une consigne, mineure pour un skill ou un agent ajouté, majeure pour un changement de format de `.forge/` qui casse la reprise.

## [1.0.0] — 2026-10-31

plugin-flutter devient le plugin Flutter de plugin-orchestrator 0.1.0 : les workflows communs à tous les langages et les garde-fous communs passent à l'orchestrateur, qui confie à plugin-flutter, par des mandats à l'interface 1 de son contrat de délégation, tout ce qui demande de comprendre Flutter. Les deux plugins s'installent ensemble ; démarrer un nouveau projet demande plugin-orchestrator 0.1.1 ou plus. Majeure : des skills, un agent et des hooks partent, et `.forge/config.yaml` passe au format de l'orchestrateur (schéma 2) — un projet 0.x se migre en ajoutant le bloc `parts` à la main ([Installation](docs/INSTALLATION.md#migrer-un-projet-de-plugin-flutter-0x)).

### Ajouté

- Agent `scaffold-engineer` (sonnet) : reçoit le mandat `scaffold` du `bootstrap-project` de l'orchestrateur — `flutter create … .` dans le dossier de la session, jamais `--overwrite`, structure `lib/app`, `lib/core`, `lib/features` et `integration_test/`, modes stricts de l'analyseur, TRD en DRAFT, `flutter test` et `flutter analyze` à 0 — et rend `SCAFFOLD`, `TOOLCHAIN` (les lignes que l'orchestrateur écrit dans `.forge/config.yaml`, dont `integration_test` sur un appareil que `flutter devices` trouve, ou `none`), `PERMISSIONS` (le fragment Flutter, jamais écrit par lui), `VERSIONS` et `TARGETS`. Ni CI ni commit. Un projet hors du dossier de la session le fait s'arrêter en `blocked`. Sa portée dans agent-scope-guard : `lib/`, `test/`, `integration_test/`, `docs/technical/` et le seul fichier racine `analysis_options.yaml` ; `flutter create` avec ses quatre options seulement (`--org`, `--project-name`, `--platforms`, `--description`) et la cible `.`.
- Écho `INTERFACE: 1` à la fin du rapport des cinq agents, juste avant `STATUS`, que l'orchestrateur vérifie avant de se servir d'un rapport ; un mandat d'une autre interface n'est pas exécuté (`STATUS: blocked`, rien d'écrit).
- Les mandats de l'orchestrateur, nommés par chaque agent : `write-tests` (test-engineer, dont un test de non-régression unique pour debug-project), `review` (code-reviewer, avec la cause racine pour debug-project ; un correctif qui masque le symptôme est bloquant), `check-dependency` et `diagnose` (flutter-architect, rapports `DEPENDENCY`/`ADR` et `DIAGNOSIS`/`FIX_DIRECTION`, rien d'écrit), `ci-template` (devops-engineer, nouveau : la CI Flutter depuis le gabarit), `build`, `ci-diagnosis` et `workflow-change`.
- `templates/permissions-fragment.json` : les règles de permission de Flutter, que le scaffold rend à l'orchestrateur.
- Vérification de plugin-orchestrator en tête d'`update-project` et d'`adopt-existing-project` : sans lui (0.1.0 ou plus), elles s'arrêtent avant tout, sans rien changer, et donnent sa commande d'installation.
- Scénarios 13 (sans orchestrateur) et 14 (le critère v0.1 de l'orchestrateur avec plugin-flutter 1.0) ; `tests/scenarios/headless.sh` charge `FORGE_ORCHESTRATOR_DIR` par un second `--plugin-dir`.

### Modifié

- `.forge/config.yaml` au format de l'orchestrateur : `templates/forge-config.yaml` en `schema_version: 2`, une partie à la racine `plugin: plugin-flutter`, `interface: 1`, sa toolchain Flutter et ses `platforms`. `update-project` l'exige et s'arrête sur un fichier 0.x en montrant le bloc `parts` à ajouter ; `adopt-existing-project` l'écrit ; les agents lisent les plateformes de la partie.
- `adopt-existing-project` : le PRD est reconstruit par `plugin-orchestrator:product-architect`, à l'interface 1 ; la branche est créée par le skill lui-même ; le plan, `CLAUDE.md` et `.claude/settings.json` viennent des gabarits du plugin, qui nomment les workflows de l'orchestrateur ; l'approbation des documents est consignée par l'orchestrateur.
- `update-project` et `adopt-existing-project` passent par le `git-workflow`, le `debug-project` et le `github-workflow` de l'orchestrateur.
- `templates/project-settings.json` : les règles génériques de l'orchestrateur 0.1.0 ajoutées (`git --version`, `jq --version`, `git show`, `git ls-files` sans demander ; lecture des keystores et certificats refusée).
- Gabarits de documents (TRD, plan, DECISIONS, CLAUDE) déplacés sous `templates/doc-templates/`, avec l'état REVIEW : un document approuvé qui change repasse en REVIEW (doc-status-guard de l'orchestrateur). `CLAUDE.md` nomme les workflows de l'orchestrateur.
- `flutter-architect` : `flutter doctor` dans sa liste de commandes, pour un diagnostic ; un TRD ou un DECISIONS.md nouveau part de son gabarit.
- `code-reviewer` : le diff indexé se compare à la branche par défaut du projet, plus à `main` en dur.

### Retiré

- Skills `create-feature`, `debug-project`, `github-workflow`, `git-workflow`, `recover-session` et `bootstrap-project`, agent `product-architect`, hooks `guard-destructive`, `secret-scan`, `protect-sensitive` et `checkpoint-reminder` : ce sont ceux de plugin-orchestrator. Leurs tests partent avec eux, après vérification que les 382 cas des quatre suites de hooks donnent les mêmes décisions contre les hooks de l'orchestrateur. Le lexer `hooks/scripts/lib/shell-lexer.sh` reste : agent-scope-guard s'en sert.
- Gabarit `PRD.md` (celui de l'orchestrateur) et `reference/pr-body.md`.
- Scénarios 2 à 5 et 7 à 9, qui testaient les composants retirés.

Coût en contexte permanent : ~1074 tokens — update-project ~160, adopt-existing-project ~180, flutter-architect ~130, code-reviewer ~140, test-engineer ~130, devops-engineer ~170, scaffold-engineer ~160.

## [0.3.0] — 2026-10-20

Mettre à jour les dépendances par lots validés, adopter une app existante sans rien réécrire, repérer les écarts entre les documents et le code. Le format de `.forge/` ne change pas.

### Ajouté

- Skill `update-project` : inventaire en lecture seule (`flutter pub outdated --json`), classement en compatibles, majeures, retenues et signalées, plan de lots que vous validez, puis un lot à la fois sur `chore/deps-<slug>`, avec analyse et tests après chacun, un commit par lot avec son lockfile, un ADR `proposed` par majeure, et un rapport avant/après dans `.forge/reports/deps-<date>-<slug>.md`. Un lockfile périmé est resynchronisé dans un commit à part, après votre accord. Le skill ne lance jamais `flutter upgrade`, `downgrade` ni `channel` : le SDK appartient à la machine, et vous le changez vous-même (configuration Nix, ou `! flutter upgrade`) ; le skill vérifie ensuite et rappelle d'aligner `flutter-version` dans la CI.
- Skill `adopt-existing-project` : analyse en lecture seule d'une app existante, sans `pub get` qui réécrirait `pubspec.lock` (`--enforce-lockfile`, `--no-pub`) ; plan de mise en conformité que vous validez item par item ; puis `.forge/`, documents manquants reconstruits depuis le code en DRAFT, liste des divergences, sur `chore/adopt-plugin-flutter`. Aucun fichier existant n'est réécrit sans son diff approuvé, aucun code n'est déplacé. Une adoption interrompue reprend où elle s'était arrêtée.
- Agent `product-architect` (modèle de la session) : PRD et critères d'acceptation numérotés `AC-xxx`, testables, jamais renumérotés ; tâches `draft` (un besoin) et `reconstruct` (le code d'une app existante, critères marqués « reconstructed »). Écrit seulement sous `docs/product/`, sans shell.
- Détection des divergences entre documents et code : une étape d'`adopt-existing-project`, un bloc `DIVERGENCES` dans le rapport du code-reviewer (dépendance sans ADR, critère sans test, plan contredit), traité à l'étape 14 de `create-feature` et en fin de `debug-project`.
- Scénarios comportementaux 6 (adoption), 10 (mise à jour d'un lot de dépendances, critère de sortie de la v0.3), 11 (tâche `build` de devops-engineer) et 12 (diagnostic d'une CI rouge).

### Modifié

- `templates/project-settings.json` : les commandes de `flutter pub` qui ne modifient rien (`get --enforce-lockfile`, `outdated`, `deps`, `add --dry-run`), `flutter --version --machine` et `git status <options>` passent sans demander ; `flutter pub upgrade` sans argument, `flutter upgrade`, `flutter downgrade` et `flutter channel` demandent d'abord. Un projet créé avec la v0.2 garde ses règles : les ajouter à la main (voir [Installation](docs/INSTALLATION.md#migrer-un-projet-de-plugin-flutter-0x)).
- `agent-scope-guard` : périmètre de product-architect (`docs/product/`, aucune commande) ; un agent sans liste de commandes ne peut plus rien lancer.
- `bootstrap-project` confie le PRD d'un brief long à product-architect. `create-feature` traite les divergences relevées à la revue : une modification du PRD ou du TRD y devient un point de validation.
- `flutter-architect` ne lance `flutter pub deps` que sur un lockfile à jour, puisque la commande réécrit un lockfile périmé ; pour une app adoptée, il décrit la pile existante et propose ses ADR.
- `git-workflow` connaît les branches `chore/deps-<slug>`, `chore/ci` et `chore/adopt-plugin-flutter`.

### Corrigé

- `bootstrap-project` : en mode non interactif, `.forge/config.yaml` n'était jamais créé, puisque protect-sensitive refuse l'écriture sans proposer d'autre voie. Le skill donne désormais la commande à lancer vous-même.
- `github-workflow` : la commande `sed` qui remplit le gabarit de CI cassait sur un nom de branche contenant `/`. Elle utilise désormais `|` comme délimiteur.
- Checkpoint en fin de workflow : il était mis à jour après le dernier commit, à la demande de `git-workflow` comme du hook `checkpoint-reminder`. L'arbre restait donc modifié, et un `git switch` vers la branche principale était refusé. Le dernier commit porte désormais le checkpoint dans son état final, qui n'est plus modifié ensuite ; le hook l'accepte, et `recover-session` ne signale plus ce commit comme une incohérence.
- `checkpoint-reminder` : dans un projet placé dans un sous-dossier du dépôt, un fichier modifié plus récent que le checkpoint ne déclenchait aucun rappel (chemins de `git status` relatifs à la racine du dépôt). Les fichiers hors du dossier du projet sont désormais ignorés.
- `devops-engineer` ne lance plus le build d'une plateforme dont la section de build est marquée `[✗]` par `flutter doctor` (Android toolchain, Linux toolchain, Visual Studio, Xcode) : il la déclare bloquée, avec la ligne de doctor comme raison. Un Chrome absent ne bloque pas `flutter build web`.
- `flutter-architect` ne cite plus de chemin absolu de la machine dans les documents. Pour une app adoptée, le plan d'adoption annonce aussi les ADR des écarts aux choix par défaut (état, navigation, organisation), que l'agent écrivait sans qu'ils aient été approuvés.

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
