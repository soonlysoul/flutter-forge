# Architecture — plugin-flutter

Oct 17, 2026 · @Soon

## Vue d'ensemble

`plugin-flutter` est un plugin Claude Code pour les applications Flutter/Dart. Depuis la 1.0, c'est le **plugin de langage Flutter de [plugin-orchestrator](https://github.com/soonlysoul/plugin-orchestrator)** : l'orchestrateur porte les workflows communs à tous les langages (démarrage, fonctionnalité en TDD, Git, GitHub, reprise, débogage) et les garde-fous communs ; plugin-flutter lui apporte, par des mandats à l'interface 1 de son contrat de délégation, tout ce qui demande de comprendre Flutter — le squelette d'une app, ses tests, sa revue, son architecture, ses builds et sa CI — et garde les deux workflows dont la matière est l'outillage de Flutter : la mise à jour des dépendances et l'adoption d'une app existante. Il ne contient aucune dépendance propre à une application et sert à plusieurs projets.

**Statut du document : REVIEW** depuis le 2026-10-29, pendant la v1.0 (décisions D43 à D52 de `PROGRESS.md`). Version précédente : APPROVED le 2026-10-20 (« je valide »), à la clôture de la v0.3.0, avec les décisions D27 à D42 et les corrections des phases E et F.2 (`docs/V0.3_REPORT.md`) ; avant elle, APPROVED à la clôture de la v0.2.0 (D12 à D26) et de la v0.1.0 (phase A, D1 à D9).

Version minimale de Claude Code : **2.1.295** (champ `onFailure` des hooks). Version vérifiée : 2.1.309. Dépendance : **plugin-orchestrator 0.1.0 ou plus**, installé avec lui. Le modèle de plugin ne déclare pas de dépendance entre plugins : tout se vérifie à l'exécution, dans les deux sens (l'écho `INTERFACE: 1` côté orchestrateur, la présence de l'orchestrateur côté skills de plugin-flutter).

Principes directeurs :

- **Petit d'abord.** Une v0.1 éprouvée vaut mieux que dix skills non testés.
- **La session principale orchestre.** Elle seule dialogue avec l'utilisateur et valide ; les agents exécutent une tâche bornée et rendent un rapport.
- **Mécanique = clé de toolchain, jugement = mandat.** Ce que l'orchestrateur lance lui-même (tests, format, analyse, ajout de dépendance) est une ligne de `toolchain` ; ce qui demande de comprendre Flutter est un mandat à un agent de plugin-flutter.
- **Déterministe = hook, jugement = skill ou agent.** Tout ce qui doit toujours se produire (formatage, limite d'un agent) est un hook, pas une consigne.
- **Rien n'est approuvé implicitement.** Documents, push, PR, fusion et release exigent une trace d'accord.
- **Honnêteté des résultats.** Chaque test est rapporté comme réussi, échoué, bloqué ou non exécuté, avec la commande lancée.
- **État sur disque, pas en mémoire.** Le travail est repris depuis Git et un fichier de checkpoint, jamais depuis le souvenir d'une session.
- **Langues.** Code, identifiants et fichiers du plugin en anglais ; messages à l'utilisateur en français.

## Périmètre et feuille de route

Chaque version n'est lancée qu'après validation de la précédente sur un vrai projet.

| Version | Skills | Agents | Hooks / autres | Critère de sortie |
| --- | --- | --- | --- | --- |
| v0.1 | bootstrap-project, create-feature (TDD intégré), git-workflow, recover-session | flutter-architect, test-engineer, code-reviewer | guard-destructive, agent-scope-guard, format-dart, checkpoint-reminder ; template settings.json | Projet démo créé + 1 feature en TDD + commit sur branche + reprise |
| v0.2 | github-workflow, debug-project | devops-engineer | secret-scan avant commit, protect-sensitive ; template CI Flutter | PR ouverte sur dépôt de test avec CI verte |
| v0.3 | update-project, adopt-existing-project | product-architect | détection de divergences docs/code | Mise à jour d'un lot de dépendances avec rapport avant/après |
| **v1.0** | update-project, adopt-existing-project ; les six workflows transversaux passent à plugin-orchestrator | flutter-architect, test-engineer, code-reviewer, devops-engineer, **scaffold-engineer** ; product-architect passe à l'orchestrateur | agent-scope-guard, format-dart ; les quatre gardes communs passent à l'orchestrateur ; `INTERFACE: 1`, `.forge/` au schéma 2 | Critère v0.1 de l'orchestrateur : un projet mono-partie Flutter mené de bout en bout avec les deux plugins publiés |
| à réévaluer | optimize-usage ; la release passe à l'orchestrateur (sa v0.3, `release`) | ui-ux-engineer | matrice plateformes en CI | Build de release Android + Web vérifié |

`implementation-engineer` n'est pas prévu comme agent séparé : l'implémentation reste dans la session principale pour éviter des transferts de contexte coûteux pendant le cycle rouge-vert (D29), ce que l'orchestrateur reprend.

## Arborescence du plugin

Les composants sont à la racine du plugin ; seul le manifeste vit dans `.claude-plugin/`.

```
plugin-flutter/
├── .claude-plugin/
│   ├── plugin.json              # manifeste (nom, version, description, auteur, licence)
│   └── marketplace.json         # marketplace locale pour installer/mettre à jour
├── agents/
│   ├── scaffold-engineer.md     # mandat scaffold
│   ├── flutter-architect.md     # check-dependency, diagnose, TRD et ADR
│   ├── test-engineer.md         # write-tests
│   ├── code-reviewer.md         # review
│   └── devops-engineer.md       # ci-template, build, ci-diagnosis, workflow-change
├── skills/
│   ├── update-project/
│   │   ├── SKILL.md
│   │   └── reference/deps-report.md  # gabarit du rapport avant/après
│   └── adopt-existing-project/
│       ├── SKILL.md
│       └── reference/divergences.md  # grille et format des divergences
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── agent-scope-guard.sh
│       ├── format-dart.sh
│       └── lib/shell-lexer.sh        # analyseur de commandes d'agent-scope-guard
├── templates/
│   ├── forge-config.yaml         # .forge/config.yaml au schéma 2 de l'orchestrateur, partie Flutter remplie
│   ├── checkpoint.md             # copie du format de l'orchestrateur
│   ├── project-settings.json     # règles génériques de l'orchestrateur + règles Flutter
│   ├── permissions-fragment.json # règles Flutter seules, rendues par le scaffold
│   ├── doc-templates/            # TRD, IMPLEMENTATION_PLAN, DECISIONS, CLAUDE
│   └── github-workflows/flutter-ci.yml  # CI posée sur le mandat ci-template
├── tests/
│   ├── run-all.sh
│   ├── static/                  # manifeste, frontmatter, chemins, agents, skills, gabarits, docs
│   ├── hooks/                   # tests des scripts avec entrées JSON simulées
│   └── scenarios/               # scénarios comportementaux pas à pas, avec l'orchestrateur
├── docs/
│   ├── INSTALLATION.md
│   ├── USER_GUIDE.md
│   ├── SECURITY.md
│   ├── TROUBLESHOOTING.md
│   ├── PHASE_A_REPORT.md        # audit de la doc officielle (phase A)
│   └── V0.1_REPORT.md … V0.3_REPORT.md  # rapports de validation
├── ARCHITECTURE.md              # ce document
├── PROGRESS.md                  # suivi de développement du plugin
├── README.md
├── CHANGELOG.md
└── LICENSE                      # MIT
```

Les skills, les agents et les hooks référencent les fichiers du plugin via la variable `${CLAUDE_PLUGIN_ROOT}`, jamais par chemin absolu :

- dans `hooks.json`, elle est substituée dans `command` et `args`, et exportée dans l'environnement du script ;
- dans un `SKILL.md` ou un agent, elle est substituée dans le corps Markdown au chargement, si bien que Claude reçoit un chemin absolu ;
- elle n'existe **pas** dans l'environnement des commandes Bash de Claude, ni dans les fichiers annexes lus par `Read` : ces fichiers (gabarits) ne la contiennent donc pas ;
- elle ne désigne que **ce** plugin : un skill de plugin-flutter ne peut pas lire un gabarit de l'orchestrateur, ni l'inverse. D'où les copies de `templates/` (D47) et le lexer gardé (D45).

La racine du plugin change à chaque mise à jour d'une installation distante : aucun état n'y est écrit. L'état vit dans `<projet>/.forge/`.

Pas de `CLAUDE.md` à la racine du plugin : il ne serait pas chargé, et déclenche un avertissement du validateur.

## Manifeste et distribution

Le plugin est publié dans le dépôt public `soonlysoul/plugin-flutter` et distribué par la marketplace `soon` (dépôt public `soonlysoul/claude-plugins`), qui le référence en source `github`, comme plugin-orchestrator. Le dossier du plugin reste aussi une marketplace locale, `plugin-flutter`, pour le développement. Champs vérifiés en phase A (rapport, §3.1).

`.claude-plugin/plugin.json` :

```json
{
  "name": "plugin-flutter",
  "version": "1.0.0",
  "description": "Flutter/Dart language plugin of plugin-orchestrator: scaffold of a Flutter app, tests, review, architecture, builds and CI by mandate at interface 1, dependency updates, adoption of an existing app.",
  "author": { "name": "Soon" },
  "homepage": "https://github.com/soonlysoul/plugin-flutter",
  "repository": "https://github.com/soonlysoul/plugin-flutter",
  "license": "MIT",
  "keywords": ["flutter", "dart", "tdd", "ci", "dependencies", "plugin-orchestrator"]
}
```

- Seul `name` est obligatoire, mais l'absence de `version`, `description` ou `author` produit un avertissement, donc un échec de `claude plugin validate --strict`.
- Un champ inconnu est retiré au chargement et signalé.
- `homepage` et `repository` pointent vers le dépôt GitHub, qui doit exister : une URL invalide empêche le chargement du plugin.
- `version` est ignorée pour une marketplace locale, dont le plugin est lu sur place. Depuis la marketplace `soon`, elle décide des mises à jour : un appareil ne reçoit une nouvelle copie que si `version` change. Elle est donc augmentée à chaque release, et ne figure pas dans l'entrée de la marketplace.
- Aucun champ ne déclare la dépendance à plugin-orchestrator : le modèle les exclut (Claude Code 2.1.309 connaît des « dépendances auto-installées », `claude plugin prune`, non retenues). L'installation des deux est une consigne des docs, et chaque côté vérifie l'autre à l'exécution.

`.claude-plugin/marketplace.json` déclare la marketplace locale `plugin-flutter` (propriétaire `Soon`), qui contient ce seul plugin. L'entrée s'écrit `"source": "./"`, avec le même `name` que `plugin.json`, sans répéter `version`.

Cycle de vie (vérifié en phase A, rapport §3.2). `/plugin` n'existe qu'en session interactive ; les commandes `claude plugin …` sont leurs équivalents scriptables.

| Étape | En session | En shell |
| --- | --- | --- |
| Test sans installation | — | `claude --plugin-dir <plugin-flutter> --plugin-dir <plugin-orchestrator>` (plugins `@inline`, pour la session seule ; l'option se répète) |
| Ajouter la marketplace | `/plugin marketplace add soonlysoul/claude-plugins` (locale : `<chemin>`) | `claude plugin marketplace add soonlysoul/claude-plugins [--scope user\|project\|local]` |
| Installer | `/plugin install plugin-orchestrator@soon`, puis `plugin-flutter@soon` (locale : `plugin-flutter@plugin-flutter`) | `claude plugin install plugin-orchestrator@soon` et `plugin-flutter@soon` `[-s user\|project\|local]` |
| Mettre à jour (marketplace locale) | `/reload-plugins` : le plugin est lu sur place, rien à réinstaller | redémarrer la session |
| Mettre à jour (marketplace `soon`) | `/plugin marketplace update soon` | `claude plugin marketplace update soon`, puis `claude plugin update plugin-flutter@soon` |
| Désinstaller | `/plugin uninstall plugin-flutter` | `claude plugin uninstall plugin-flutter@soon [-s …]` ; `claude plugin marketplace remove soon` retire aussi la marketplace |
| Valider | — | `claude plugin validate . --strict` (0 réussi, 1 échec, 2 erreur du validateur) |
| Inventaire et coût | — | `claude plugin details plugin-flutter` |

Versionnage SemVer : patch pour une correction de consigne, minor pour un skill ou agent ajouté, major pour un changement de format de `.forge/` qui casse la reprise ou d'interface de délégation — la 1.0 change les deux.

## Orchestration

La session principale est le seul chef d'orchestre : elle charge les skills — ceux de l'orchestrateur pour les workflows transversaux, ceux de plugin-flutter pour les dépendances et l'adoption —, envoie des mandats aux agents, et porte toutes les validations, car un agent ne peut ni dialoguer avec l'utilisateur ni lancer d'autres agents.

Contrat de délégation, interface 1 (spécification : `docs/ARCHITECTURE.md` de plugin-orchestrator, « Contrat de délégation », et les `reference/` de ses skills) :

- **Mandat entrant** : `interface: 1`, la tâche, la partie (`path`, `plugin`), les critères visés, le périmètre déclaré, puis les entrées propres à la tâche.
- **Rapport sortant** : les sections propres à la tâche, puis la queue commune `INTERFACE: 1`, `STATUS`, `FILES_CHANGED`, `COMMANDS_RUN`, `OPEN_QUESTIONS`. L'orchestrateur arrête le workflow sur une ligne `INTERFACE` absente ou différente, en nommant le plugin à mettre à jour.
- **Autre interface** : un agent de plugin-flutter qui reçoit un mandat d'une autre interface ne l'exécute pas, rend `STATUS: blocked` et le dit, sans rien écrire (D48).

| Workflow de l'orchestrateur | Mandat | Agent de plugin-flutter |
| --- | --- | --- |
| `bootstrap-project` | `scaffold` | scaffold-engineer |
| `create-feature` | `write-tests`, `check-dependency`, `review` | test-engineer, flutter-architect, code-reviewer |
| `debug-project` | `diagnose`, `write-tests` (un test de non-régression), `review` | flutter-architect, test-engineer, code-reviewer |
| `github-workflow` | `ci-template`, `build`, `ci-diagnosis`, `workflow-change` | devops-engineer |

`adopt-existing-project` mandate, dans l'autre sens, `plugin-orchestrator:product-architect` (task `reconstruct`) puis le flutter-architect, chacun à l'interface 1 : la dépendance est bidirectionnelle.

Règles de délégation :

- Un agent n'est lancé que si sa tâche est autonome et que son rapport évite au moins autant de lectures qu'il en coûte ; sinon la session principale fait le travail.
- Les agents s'exécutent l'un après l'autre sur un même dépôt. Un parallélisme éventuel passe par des worktrees Git séparés, jamais sur les mêmes fichiers.
- En session interactive, un sous-agent tourne en arrière-plan par défaut : son rapport arrive par notification, au tour suivant. La session principale attend ce rapport avant l'étape qui en dépend, et n'écrit rien en parallèle.
- Un agent ne liste jamais `Agent` dans ses outils : il ne peut donc pas lancer d'autre agent. `AskUserQuestion` ne lui est jamais offert.
- La racine du projet, pour les hooks comme pour les règles de permission, est le dossier où la session a été lancée (`CLAUDE_PROJECT_DIR`). Le scaffold-engineer ne crée donc l'app que dans ce dossier ; un projet demandé dans un sous-dossier le fait rendre `blocked`, repris par une nouvelle session ouverte dans ce dossier.
- Le code-reviewer ne reçoit que le diff et les exigences, pas le raisonnement de l'implémentation, pour que sa relecture reste indépendante.
- Chaque rapport d'agent est vérifié par la session principale (commandes relancées si besoin) avant d'être présenté comme un fait.

## Agents

Chaque agent est un fichier Markdown avec frontmatter (`name`, `description`, `tools`, `model`) et un corps d'instructions en anglais. La restriction d'outils dans le frontmatter est ce qui rend un agent réellement « lecture seule » ; une consigne seule ne suffit pas.

Ce que le frontmatter peut et ne peut pas exprimer (vérifié en phase A, rapport §3.3) :

- `tools` est une liste de noms d'outils ; omis, l'agent hérite de **tous** les outils. Un motif du type `Bash(git diff *)` n'y est pas documenté, et `disallowedTools: Bash(…)` retire Bash en entier : la liste blanche Bash par agent ne s'exprime donc pas ici.
- `permissionMode`, `hooks` et `mcpServers` sont ignorés pour un agent de plugin.
- Un frontmatter illisible se charge « avec tous les champs ignorés », donc avec tous les outils, sans message. Le test statique du frontmatter est strict pour cette raison.

Les limites fines (dossiers et fichiers d'écriture, liste blanche Bash) sont imposées par le hook **agent-scope-guard**, qui reçoit `agent_type` (`plugin-flutter:<agent>`).

« Git en lecture » désigne `git status`, `git log`, `git diff`, `git show`, `git ls-files`, `git rev-parse` et `git branch --show-current`.

| Agent | Version | `tools` (frontmatter) | Limites imposées par agent-scope-guard | `model` | Mandats (interface 1) | Rend, avant la queue commune |
| --- | --- | --- | --- | --- | --- | --- |
| scaffold-engineer | v1.0 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `lib/`, `test/`, `integration_test/`, `docs/technical/` et au fichier racine `analysis_options.yaml` ; Bash limité à `flutter create <options> .` (dernier mot `.`, jamais `--overwrite`), `flutter --version`, `flutter devices`, `flutter doctor`, `flutter pub get`, `flutter test`, `flutter analyze`, et git en lecture | `sonnet` | `scaffold` (bootstrap-project de l'orchestrateur) | SCAFFOLD, TOOLCHAIN (lignes de `templates/forge-config.yaml`), PERMISSIONS (`templates/permissions-fragment.json`), VERSIONS, TARGETS |
| flutter-architect | v0.1 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `docs/` ; Bash limité à `flutter --version`, `flutter doctor`, `dart --version`, `dart pub deps`, `flutter pub deps`, et git en lecture | `inherit` | `check-dependency` (create-feature), `diagnose` (debug-project), tâche d'architecture (adoption, ou à la demande) | DEPENDENCY et ADR, ou DIAGNOSIS et FIX_DIRECTION (rien d'écrit) ; TRD et ADR dans DECISIONS.md pour l'architecture |
| test-engineer | v0.1 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `test/` et `integration_test/` ; Bash limité à `flutter test`, `dart test`, et git en lecture | `sonnet` | `write-tests` (create-feature ; un test `regression: …` pour debug-project) | TESTS_WRITTEN, EDGE_CASES, RED_OUTPUT |
| code-reviewer | v0.1 | Read, Grep, Glob, Bash — aucune écriture | Aucune écriture ; Bash limité à `git diff`, `git log`, `git show`, `git status`, `flutter analyze`, `dart analyze` | `sonnet` | `review` (create-feature ; debug-project, avec la cause racine) | FINDINGS (bloquant / important / mineur, fichier:ligne), DOCS_TO_UPDATE, DIVERGENCES (D40) |
| devops-engineer | v0.2 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `.github/` ; Bash limité à `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status` (sans `--show-token`), `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, `git remote -v` et git en lecture ; option `-o`/`--output` refusée | `sonnet` | `ci-template`, `build`, `ci-diagnosis`, `workflow-change` (github-workflow) | BUILDS par plateforme ; CI : run, classe d'un échec avec ses lignes de journal, correctif |

Chaque rapport finit par la queue commune du contrat : `INTERFACE: 1`, `STATUS` (done / blocked / partial), `FILES_CHANGED`, `COMMANDS_RUN` avec code de sortie, `OPEN_QUESTIONS` (D48). Les plateformes viennent de `parts.<partie>.platforms` de `.forge/config.yaml`.

scaffold-engineer (D46) crée l'app dans le dossier de la session seulement : ses limites d'écriture comptent depuis là, et un projet demandé ailleurs le fait rendre `blocked`. Il écrit le TRD de la partie depuis `templates/doc-templates/TRD.md`, jamais ce que l'orchestrateur garde à la racine (`.forge/`, `docs/product/`, `docs/engineering/`, `CLAUDE.md`, les motifs de secret de `.gitignore`) ; `flutter create .` écrit lui-même le `.gitignore`, `README.md` et `pubspec.yaml` racine, que le rapport liste et que l'orchestrateur 0.1.1 accepte. Il ne pose pas de CI (le mandat `ci-template` vient après le point de validation de github-workflow, avec son coût) et ne builde rien : ses cibles sont `enabled`.

devops-engineer ne pousse pas, n'ouvre ni ne modifie de PR, ne relance ni ne démarre de workflow, ne télécharge pas d'artefact et n'appelle pas `gh api` : ces actions changent le dépôt distant ou consomment des minutes, et restent dans la session principale, derrière un point de validation (D16). Sur `ci-template`, il remplit `templates/github-workflows/flutter-ci.yml` (version locale de Flutter, branche par défaut) et l'écrit au fichier que le mandat nomme ; l'écriture demande confirmation (protect-sensitive de l'orchestrateur), et un refus lui fait rendre la commande à lancer par l'utilisateur.

Les agents à venir suivront la même règle : `tools` dans le frontmatter, limites fines dans agent-scope-guard.

| Agent | Version | Outils autorisés | Reçoit | Rend |
| --- | --- | --- | --- | --- |
| ui-ux-engineer | à réévaluer | Read, Write limité à `docs/design/` et `lib/ui/` | PRD, APPFLOW | Spécification UI, états d'erreur, points d'accessibilité |

Deux couches se complètent : agent-scope-guard refuse l'appel d'outil hors périmètre ; la session principale compare ensuite `FILES_CHANGED` à `git status --porcelain`, et le code-reviewer `git diff --name-only` au périmètre déclaré, car une commande Bash autorisée (`flutter test`, `flutter create`) peut encore produire des fichiers.

## Skills

Un skill est un dossier `skills/<nom>/SKILL.md` invoqué par `/plugin-flutter:<nom>` ou chargé automatiquement quand sa `description` correspond à la demande. La description doit donc dire précisément quand l'utiliser. Chaque skill écrit le checkpoint à chaque étape terminée, au format de l'orchestrateur (`templates/checkpoint.md`, copie).

| Skill | Version | Déclencheur | Points de validation obligatoires | Produit |
| --- | --- | --- | --- | --- |
| update-project | v0.3 | Mettre à jour Flutter ou dépendances | Plan de lots, toujours, avec chaque majeure et son changelog ; référence rouge ; lock périmé ; plateforme perdue par un plugin ; migration hors des fichiers qui importent le paquet ; abandon d'un lot ; changement de SDK (fait par l'utilisateur) | Branche `chore/deps-<slug>`, un commit par lot avec `pubspec.yaml`, `pubspec.lock` et registres de plugins, ADR par majeure, rapport `.forge/reports/deps-<date>-<slug>.md` |
| adopt-existing-project | v0.3 | Prendre en main un projet Flutter existant, sans `.forge/` | Plan de mise en conformité, approuvé item par item ; chaque fichier existant modifié, approuvé séparément ; fichier suivi changé par la résolution | Branche `chore/adopt-plugin-flutter`, `.forge/` au schéma 2, PRD, TRD, DECISIONS et plan reconstruits en DRAFT, `.forge/reports/divergences-<date>.md` |

Les six workflows transversaux de la v0.3 (bootstrap-project, create-feature, git-workflow, recover-session, github-workflow, debug-project) sont ceux de plugin-orchestrator depuis la 1.0 (D44) : le squelette d'une app y devient le mandat `scaffold`, les tests, la revue, la dépendance et le diagnostic des mandats aux agents ci-dessus, les commandes mécaniques des clés de `toolchain`.

**Vérification de l'orchestrateur** (D50), première étape des deux skills : sans skill `plugin-orchestrator:…` dans la session, arrêt avant tout, rien changé, plugin-orchestrator 0.1.0 ou plus nommé avec sa commande d'installation. update-project exige ensuite `.forge/config.yaml` au schéma 2, avec une partie `plugin: plugin-flutter` en `interface: 1` et `path: .` ; un fichier sans `parts` (plugin-flutter 0.x) l'arrête sur le bloc `parts` de `templates/forge-config.yaml` à ajouter, que l'utilisateur édite. Les deux renvoient au `git-workflow`, au `debug-project` et au `github-workflow` de l'orchestrateur, écrits `plugin-orchestrator:<nom>`.

update-project (D31 à D35) part d'une référence : `flutter pub get --enforce-lockfile`, puis `flutter analyze` et `flutter test`. L'inventaire vient de `flutter pub outdated --json`, qui ne modifie aucun fichier et sort en 0 même avec des paquets en retard. Chaque dépendance directe est classée compatible (`upgradable` plus récente), majeure (`resolvable` change la version majeure, ou la mineure sous 1.0), retenue (`latest` hors d'atteinte, souvent à cause du SDK ; `flutter pub add --dry-run '<paquet>:^<latest>'` nomme ce qui la retient, sans rien modifier) ou signalée (avis de sécurité, version retirée, paquet abandonné). Un lock périmé est d'abord resynchronisé dans son propre commit (lock et registres de plugins régénérés), sur la branche, après accord ; le rapport part de ce commit. Quand la demande nomme des paquets, les lots ne déplacent qu'eux (`flutter pub upgrade <paquet>`). Lots : les paquets signalés, puis `flutter pub upgrade` pour tout le compatible, puis un lot par majeure avec `flutter pub upgrade --major-versions <paquet>`. Après chaque lot : fichiers attendus seulement, `CHANGELOG.md` lu dans le cache pub pour une majeure, plateformes d'un plugin comparées aux `platforms` de la partie, analyse et tests, commit. Un lot abandonné est restauré en entier, code migré compris, par l'utilisateur (`! git restore …`), puis l'analyse et les tests sont comparés à la référence. Le « après » du rapport vient de `flutter pub outdated --json --show-all`, sans quoi les paquets mis à jour, désormais à jour, disparaîtraient. Le SDK n'est jamais changé par Claude : `flutter upgrade`, `downgrade` et `channel` demandent confirmation dans les règles du projet, et sous Nix (`flutterRoot` dans `/nix/store/`) la version vient de la configuration Nix de l'utilisateur. Après un changement de SDK, le skill rappelle la ligne `flutter-version` de `.github/workflows/ci.yml`.

adopt-existing-project (D37, D38) ne modifie rien avant l'accord : ses étapes 1 à 4 sont en lecture seule, prouvée par un `git status --porcelain --untracked-files=all` vide avant et après. Il s'arrête hors d'un dépôt Git (le premier commit d'un arbre existant appartient à l'utilisateur), sur toute modification non commitée, et hors de la branche principale ; une adoption interrompue reprend depuis son checkpoint. La phase A a montré qu'un `flutter analyze` nu, qui lance `pub get`, réécrit un `pubspec.lock` périmé, et la revue que `flutter pub deps` fait de même : la référence passe donc par `flutter pub get --enforce-lockfile` (exit 65 sur un lock périmé, 1 sans lock, sans rien écrire), puis `flutter analyze --no-pub` et `flutter test --no-pub`, et `flutter pub deps` n'est lancé, par la session ou par flutter-architect, que sur un lock à jour. Après accord, la branche est créée par le skill lui-même (le git-workflow de l'orchestrateur lit `.forge/config.yaml`, absent à ce moment) ; `plugin-orchestrator:product-architect` reconstruit le PRD (tâche `reconstruct`) et flutter-architect le TRD et les ADR (une par dépendance directe, une par écart aux choix par défaut : état, navigation, organisation, toutes annoncées par le plan), l'un après l'autre, chacun à l'interface 1 ; un document existant est gardé et référencé, jamais remplacé, et aucun code n'est déplacé. Le checkpoint est écrit avant `.forge/config.yaml`, avec la référence de l'étape 2, pour qu'une adoption interrompue reprenne avec ce qu'il lui faut. L'écriture de `.forge/config.yaml` demande confirmation (protect-sensitive) : refusée, elle devient une commande à lancer par l'utilisateur. L'adoption vit sur sa branche jusqu'à la fusion, qui revient à l'utilisateur : par une PR du github-workflow de l'orchestrateur si la référence était propre (lock, format, analyse, tests), sinon par une PR ou une fusion locale qu'il fait lui-même. Aucun document n'est approuvé par le skill : l'approbation passe par l'orchestrateur (`orch.sh approve`), qui en consigne l'empreinte.

La détection des divergences docs/code est un contrôle de jugement, pas un hook (D28) : une étape d'adopt-existing-project, guidée par `reference/divergences.md` (dépendances, critères, plan, README, plateformes, toolchain, lockfile, structure, analyse, tests, secrets), et le bloc DIVERGENCES du code-reviewer à chaque revue (D40) : dépendance ajoutée ou passée à une majeure sans ADR, critère visé sans test ou test citant un AC absent du PRD, plan contredit par le diff. L'étape docs du create-feature de l'orchestrateur le traite.

Règle commune : un skill ne déclare jamais une étape réussie sans la sortie de la commande correspondante. Après deux échecs identiques d'une même commande, il s'arrête, écrit le checkpoint et expose le blocage au lieu de réessayer.

Points de validation : le skill pose sa question **en texte**, écrit le checkpoint, puis termine son tour et attend la réponse. `AskUserQuestion` n'est pas offert en mode `-p` sans hôte de permission ; poser la question en texte donne le même comportement en interactif et en headless.

Frontmatter retenu : `name`, `description` (qui dit précisément quand charger le skill), et `argument-hint` quand le skill prend un argument. `allowed-tools` n'est pas utilisé : il accorde des outils sans invite et ne restreint rien ; les permissions restent dans le `settings.json` du projet, seule source. Un `SKILL.md` reste sous 500 lignes, car son contenu reste en contexte aux tours suivants.

## Hooks et garde-fous

Les hooks sont déclarés dans `hooks/hooks.json` et exécutent des scripts bash courts, testables avec une entrée JSON simulée. Un hook ne lance jamais la suite de tests complète et n'accorde jamais une permission : il peut seulement bloquer ou compléter.

Règles de mise en œuvre (vérifiées en phase A, rapport §3.5) :

- **Bloquer** : `exit 2`, la raison sur stderr, transmise à Claude. Un `exit 1` est une erreur **non bloquante** : la commande passe.
- **Fail-closed** : le script sort en 2 sur toute erreur interne (`jq` absent, JSON illisible, lexer manquant), **et** le hook déclare `"onFailure": "block"`, qui couvre aussi un script introuvable, un plantage et un dépassement de délai. Ce champ exige Claude Code 2.1.295 ou plus.
- **Fail-open** : le script sort toujours en 0, et le hook déclare `"onFailure": "continue"`.
- **Forme exec** : `"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<script>.sh"]`. Sans shell, ni guillemets, ni bit exécutable, ni shebang ne comptent ; cela règle aussi l'absence de `/bin/bash` sous NixOS. Les scripts gardent `#!/usr/bin/env bash` pour être lancés directement par les tests.
- **Portée** : les hooks d'un plugin se déclenchent dans **toutes** les sessions où il est activé, sous-agents compris. Chaque hook reste donc inerte hors de son contexte : fichier `.dart`, agent du plugin.
- **Entrée** : `tool_input.command` pour Bash, PowerShell et Monitor (un appel Monitor en mode WebSocket porte `ws` à la place, et passe) ; `tool_input.file_path`, toujours absolu, pour Write et Edit ; `tool_input.notebook_path` pour NotebookEdit.

| Hook | Événement | Filtre | Comportement | En cas d'erreur du script |
| --- | --- | --- | --- | --- |
| agent-scope-guard | PreToolUse | `Edit\|Write\|NotebookEdit\|Bash\|PowerShell\|Monitor` | Inerte hors des cinq agents du plugin (préfixe `plugin-flutter:` de `agent_type`). Pour eux, refuse toute écriture hors des dossiers et fichiers de l'agent, et toute commande hors de sa liste blanche (section « Agents ») ; une commande composée (`;`, `&&`, `\|`, `$(…)`, redirection) est refusée, grâce au lexer `hooks/scripts/lib/shell-lexer.sh` | Bloque (fail-closed) |
| format-dart | PostToolUse | `Edit\|Write` | Si le fichier finit par `.dart` et que `dart` est dans le PATH : `dart format <fichier>` | Ignore silencieusement (fail-open) |

Les quatre gardes communs de la v0.3 — guard-destructive, secret-scan, protect-sensitive, checkpoint-reminder — sont ceux de plugin-orchestrator depuis la 1.0 (D44), avec ses motifs des écosystèmes connus (pub.dev compris) et son doc-status-guard : les 382 cas de leurs suites de plugin-flutter donnent les mêmes décisions contre ses hooks (phase A de la v1.0). Garder une copie ici les ferait tourner en double. Le lexer, qu'ils partageaient, reste pour agent-scope-guard (D45).

## Sécurité et permissions

La sécurité repose sur trois couches indépendantes : les règles de permission de Claude Code, les hooks, et les préautorisations du projet. Un plugin ne peut pas imposer de règles `allow`/`deny` (vérifié en phase A, rapport §3.7) : le `settings.json` d'un plugin n'applique que `agent` et `subagentStatusLine`. Les plugins proposent donc les règles, et l'utilisateur les installe.

**Couche 1 — les règles de permission.** Deux gabarits, parce que `${CLAUDE_PLUGIN_ROOT}` ne traverse pas les plugins (D47) :

- `templates/permissions-fragment.json` : les 23 règles propres à Flutter et Dart — en `allow` les commandes qui ne modifient rien ou que les workflows lancent sans cesse (`flutter test`, `flutter analyze`, `dart format`, `flutter pub get`, `flutter pub get --enforce-lockfile`, `flutter pub outdated`, `flutter pub deps`, `flutter pub add --dry-run`, `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`), en `ask` `flutter pub upgrade`, `flutter upgrade`, `flutter downgrade` et `flutter channel`, en `deny` `flutter pub publish` et `dart pub publish`. Le scaffold-engineer le rend tel quel dans son bloc `PERMISSIONS`, et l'orchestrateur le fusionne avec ses règles génériques avant de vous les proposer ;
- `templates/project-settings.json` : ces règles et les règles génériques de plugin-orchestrator 0.1.0 (git, gh, lecture des secrets et des keystores refusée, `Edit(./.forge/config.yaml)` refusé), pour `adopt-existing-project`, qui ne peut pas lire celles de l'orchestrateur. `tests/static/test_templates.sh` vérifie que le fragment est exactement la part Flutter du fichier complet.

- La forme `Bash(x *)`, avec espace, est celle de la doc et de la boîte de dialogue ; `Bash(x:*)` en est l'équivalent ancien.
- L'ordre d'évaluation est `deny`, puis `ask`, puis `allow`, la première règle qui correspond l'emporte : les `ask` sur `git add -A` priment donc sur `allow` `git add *`.
- Les règles de fichiers s'écrivent `Edit(…)`, qui couvre tous les outils d'écriture ; une règle `Write(…)` ne protège rien.
- Les `allow` d'un projet ne s'appliquent qu'**après acceptation de la confiance du workspace** ; `deny` et `ask` s'appliquent toujours.
- Une règle Bash ne couvre que la forme écrite (`git -C . push` échappe à `Bash(git push *)`) : les hooks restent la couche qui analyse la commande.

**Couche 2 — hooks** : agent-scope-guard et format-dart ici (section précédente), les gardes communs dans plugin-orchestrator, actifs dès l'installation des deux.

**Couche 3 — `<projet>/.forge/config.yaml`**, au format de l'orchestrateur, lu par chaque skill avant une action externe. Toute clé absente vaut `false`. Seul l'utilisateur la modifie : la règle `deny` `Edit(./.forge/config.yaml)` de la couche 1 en bloque l'édition par Claude, et le protect-sensitive de l'orchestrateur demande confirmation pour toute écriture d'un `.forge/config.yaml`. Il est écrit une seule fois — par le bootstrap de l'orchestrateur, ou par adopt-existing-project depuis `templates/forge-config.yaml` — avant `.claude/settings.json`.

```yaml
schema_version: 2
project:
  default_branch: main
  branch_prefix: feature/
authorizations:
  push_feature_branches: false
  open_pull_requests: false
  update_own_pull_requests: false
  create_remote_repo: false     # toujours re-confirmé : nom, visibilité, propriétaire
  merge: false                  # ignoré : la fusion demande toujours un accord explicite
  publish_release: false        # ignoré : idem
parts:
  app:
    path: .
    plugin: plugin-flutter
    interface: 1
    toolchain:
      test: flutter test
      format: dart format --output=none --set-exit-if-changed .
      analyze: flutter analyze
      add_dep: flutter pub add
      manifests: [pubspec.yaml, pubspec.lock]
      integration_test: flutter test integration_test -d <device>
    platforms: [android, web, linux]
```

Les lignes de `toolchain` sont celles que le scaffold-engineer rend dans `TOOLCHAIN`, et que l'orchestrateur lance lui-même aux étapes mécaniques (règle « mécanique = clé, jugement = mandat »). Un fichier en `schema_version: 1` (plugin-flutter 0.x, `platforms.enabled` au premier niveau) arrête les skills des deux plugins, qui montrent le bloc `parts` à ajouter.

Actions toujours soumises à un accord dans la conversation, quelle que soit la config : fusion dans la branche principale, changement de visibilité, suppression, release publique, toute dépense, tout changement de fournisseur ou de mode d'authentification. Aucun jeton ni secret n'est affiché, écrit dans un fichier de `.forge/` ou passé en argument de commande visible.

## État persistant, reprise et quotas

Le format de `.forge/` appartient à plugin-orchestrator : `config.yaml` (ci-dessus), `checkpoint.md`, `reports/`, `approvals.log` (l'empreinte de chaque document approuvé, que son doc-status-guard compare). Les skills de plugin-flutter écrivent le checkpoint au même format, depuis la copie `templates/checkpoint.md`, et la reprise est le `recover-session` de l'orchestrateur.

Le checkpoint est écrit après chaque étape terminée, pas au moment d'une coupure ; seul le commit qui le porte fait exception : il est écrit juste avant, l'étape du commit cochée `carried by this commit`, et n'est plus modifié pour ce commit (D42). Écrit à chaque étape plutôt qu'à la coupure, car quand la limite d'usage tombe, la session s'arrête et plus rien ne peut être sauvegardé. La reprise croise donc trois sources : `.forge/checkpoint.md`, l'historique Git et l'état du dépôt.

`<projet>/.forge/checkpoint.md` (versionné dans Git) :

```markdown
# Checkpoint
updated: 2026-10-17T18:40+02:00
skill: update-project
feature: deps 2026-10
branch: chore/deps-2026-10
last_commit: 3f2a9c1

## Steps
- [x] 1 plugin-orchestrator, configuration, repository state
- [x] 3 Baseline: flutter test → passed (exit 0)
- [ ] 7 Batch 2: flutter pub upgrade --major-versions go_router

## Test results
| command | result | when |
| flutter test | passed (exit 0) | 18:38 |

## Next action
Run batch 2 and migrate the files that import go_router.

## Blockers / open questions
- none
```

Rien de secret n'y est écrit. Un document approuvé sous plugin-flutter 0.x n'a pas d'empreinte dans `approvals.log` : il repasse en REVIEW à sa première modification (vérifié en phase A de la v1.0).

Comportement face aux limites : aucune boucle de nouvelle tentative, aucun changement de compte ou de fournisseur, aucune bascule vers une API payante. Si un message de limite ou de blocage apparaît, Claude cesse les appels, s'assure que le checkpoint est à jour et indique ce qui reste. Les économies de quota viennent du travail lui-même : tests ciblés pendant le développement, analyse complète aux jalons, agents seulement quand leur apport justifie leur coût.

## Structure d'un projet généré

Le bootstrap de l'orchestrateur, avec le scaffold-engineer, produit un projet Flutter organisé par fonctionnalité, avec un socle documentaire et des documents optionnels créés quand le besoin apparaît. Pour un projet mono-partie (`path: .`), les documents de la partie et ceux de la racine coïncident.

```
my_app/
├── .claude/settings.json        # règles génériques + fragment Flutter, après accord (orchestrateur)
├── .forge/                      # format de l'orchestrateur
│   ├── config.yaml              # schéma 2, la partie Flutter et sa toolchain
│   ├── checkpoint.md
│   ├── approvals.log
│   └── reports/
├── .github/workflows/ci.yml     # format + analyze + test (mandat ci-template au devops-engineer)
├── lib/
│   ├── main.dart
│   ├── app/                     # MaterialApp, routing, thème
│   ├── core/                    # utilitaires transverses, erreurs
│   └── features/<feature>/
│       ├── data/                # sources, repositories
│       ├── domain/              # modèles, logique pure
│       └── presentation/        # widgets, état
├── test/                        # miroir de lib/
├── integration_test/
├── docs/
│   ├── product/PRD.md           # orchestrateur (product-architect)
│   ├── technical/TRD.md         # scaffold-engineer, puis flutter-architect
│   ├── engineering/IMPLEMENTATION_PLAN.md   # à la première fonctionnalité (create-feature)
│   └── engineering/DECISIONS.md # orchestrateur (ADR-001), puis les ADR de Flutter
├── analysis_options.yaml        # flutter_lints + règles strictes (scaffold-engineer)
└── CLAUDE.md                    # conventions du projet pour Claude (orchestrateur)
```

| Document | Socle ou optionnel | Créé quand |
| --- | --- | --- |
| PRD.md | Socle | Bootstrap (orchestrateur) |
| TRD.md | Socle | Bootstrap (scaffold-engineer) |
| IMPLEMENTATION\_PLAN.md | Socle | Première fonctionnalité, mis à jour à chaque feature ; à l'adoption |
| DECISIONS.md | Socle | Bootstrap (orchestrateur), une entrée par choix technique |
| TEST\_STRATEGY.md | Optionnel | Premier test d'intégration ou de golden |
| TRACEABILITY.md | Optionnel | Plus de 10 critères d'acceptation |
| APPFLOW.md | Optionnel | Plus de 3 écrans |
| UI\_UX\_DESIGN.md | Optionnel | Maquettes ou charte fournies |
| BACKEND\_SCHEMA.md | Optionnel | Données persistantes, locales ou distantes |

Chaque document commence par un en-tête fixe : objectif, statut (DRAFT / REVIEW / APPROVED), date et auteur de l'approbation, hypothèses, décisions confirmées, documents liés, critères de vérification. Un document ne passe en APPROVED que sur un message explicite de l'utilisateur ; l'orchestrateur y inscrit alors la date et consigne son empreinte (`orch.sh approve`), et un document approuvé qui change repasse en REVIEW.

Choix techniques par défaut, révisables par le flutter-architect avec une entrée dans DECISIONS.md : canal Flutter stable, `flutter_lints`, gestion d'état Riverpod, navigation `go_router`, persistance locale avant tout backend distant. BACKEND\_SCHEMA sépare toujours trois parties : données locales, besoins réels d'un backend, évolutions futures.

## Workflow TDD et GitHub

Le cycle TDD (create-feature, quinze étapes) et les gestes Git et GitHub (git-workflow, github-workflow) sont ceux de plugin-orchestrator depuis la 1.0, qui en reprend les règles de plugin-flutter 0.3 : classes d'actions, Conventional Commits, PR en quatre catégories de tests, jamais de fusion par Claude. Ce que plugin-flutter y fait, par mandat :

- **tests d'abord** : le test-engineer écrit les tests liés aux AC dans `test/` ou `integration_test/`, les lance et rend la sortie ROUGE ; la session la relance avec `toolchain.test` ;
- **dépendance nouvelle** : après `toolchain.add_dep` (`flutter pub add`), le flutter-architect rend sa compatibilité avec les `platforms` de la partie, et l'ADR qu'elle demande ;
- **revue** : le code-reviewer relit `git diff --cached <branche par défaut>` sans le raisonnement de l'implémentation, et rend FINDINGS, DOCS_TO_UPDATE et DIVERGENCES ;
- **CI** : le devops-engineer écrit `.github/workflows/ci.yml` depuis `templates/github-workflows/flutter-ci.yml` — sur chaque PR et chaque push vers la branche principale, `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, sur un runner `ubuntu-latest` plafonné à 20 minutes ; `permissions: contents: read`, `persist-credentials: false`, aucun secret ; actions épinglées par SHA de commit (`actions/checkout` v7.0.1, `subosito/flutter-action` v2.23.0) ; `flutter-version` remplacée par la version locale, pour que la CI reproduise la machine. Il builde aussi les plateformes et lit les journaux d'une CI rouge.

Conventions de branches que les skills de plugin-flutter emploient : `chore/deps-<slug>` (update-project), `chore/adopt-plugin-flutter` (adopt-existing-project). `.gitignore` : celui de `flutter create`, plus `.env*`, `*.jks`, `*.keystore`, `key.properties`.

## Multiplateforme

Sur une machine Linux, seuls Android, Web et Linux desktop se compilent localement ; iOS, macOS et Windows exigent un runner CI du système correspondant. Le plugin distingue toujours trois états par plateforme : activée (dossier présent), compilée (build réussi, commande à l'appui) et testée (tests exécutés sur cette cible).

| Plateforme | Build sur Linux | Tests sur Linux | Voie alternative gratuite | Prérequis à détecter |
| --- | --- | --- | --- | --- |
| Android | Oui | Unitaires et widgets oui ; intégration avec émulateur si KVM | — | Android SDK, `flutter doctor`, `/dev/kvm` |
| Web | Oui | Oui (Chrome ou Chromium) | — | Navigateur détecté par `flutter devices` |
| Linux desktop | Oui | Oui, y compris `integration_test` | — | clang, cmake, ninja, GTK dev |
| iOS | Non | Non | Runner macOS GitHub Actions ; la signature exige un compte Apple Developer payant | Toujours signalé « non vérifié » localement |
| macOS | Non | Non | Runner macOS GitHub Actions | idem |
| Windows | Non | Non | Runner Windows GitHub Actions | idem |

Coût CI à signaler à l'utilisateur (vérifié le 2026-10-17, rapport §4) : les minutes GitHub Actions sont gratuites pour les dépôts publics sur runners standard. Pour les dépôts privés, le quota inclus est de 2 000 min/mois (Free), 3 000 (Pro, Team), 50 000 (Enterprise Cloud). Tarifs au-delà : Linux 2 cœurs 0,006 $/min, Windows 0,010 $, macOS 0,062 $, soit environ 10 fois Linux. La doc ne publie plus de table de multiplicateurs : le décompte exact du quota inclus pour macOS reste **non vérifié**.

Sur la machine de développement du plugin, seul Linux desktop est vérifiable (Chrome absent, SDK Android incomplet) : les `platforms` de la partie gardent `[android, web, linux]` par défaut, mais la démo de validation se fait en `linux` seul.

Règles :

- Aucune annonce de build iOS ou de publication iOS réussie sans log de build, signature et contrôle vérifiés.
- Chaque dépendance ajoutée est vérifiée contre les plateformes de la partie (mandat `check-dependency`, ou onglet « Platform » sur pub.dev) et le résultat noté dans DECISIONS.md.
- Sans KVM, les tests d'intégration se replient sur Linux desktop, et le rapport le dit.

## Stratégie de test du plugin

Les tests se répartissent en deux familles qui ne se mélangent pas : les tests déterministes, qui tournent sans Claude et sans quota, et les scénarios comportementaux, qui nécessitent une session Claude Code et consomment le quota Max.

**Tests déterministes** (`tests/run-all.sh`, bash + `jq`, aucun réseau). Les suites des quatre hooks retirés et de create-feature, debug-project et github-workflow sont parties avec eux en 1.0 : ces composants sont testés dans plugin-orchestrator.

| Fichier | Vérifie |
| --- | --- |
| static/test\_manifest.sh | `plugin.json` et `marketplace.json` sont du JSON valide, champs requis présents, `name` en kebab-case et identique dans les deux, version SemVer, `homepage` et `repository` pointent vers `soonlysoul/plugin-flutter`, `source` vaut `./` |
| static/test\_frontmatter.sh | Chaque agent et skill a un frontmatter lisible par un analyseur **strict** (lignes `clé: valeur` seulement), `name` et `description` non vides ; exactement les cinq agents et les deux skills de la 1.0 ; chaque agent déclare `tools` et `model` ; le reviewer n'a ni Write ni Edit ; aucun agent ne liste `Agent` ; chaque skill limitée aux projets `.forge/` et liée à plugin-orchestrator |
| static/test\_agents.sh | Le rapport de chaque agent finit par `INTERFACE: 1`, `STATUS`, `FILES_CHANGED`, `COMMANDS_RUN`, `OPEN_QUESTIONS`, rien après ; chaque agent refuse un mandat d'une autre interface ; chacun nomme ses mandats et rend leurs sections dans l'ordre du contrat ; le devops-engineer garde ses règles de build par section de `flutter doctor -v` ; le scaffold-engineer cite ses gabarits et ses limites |
| static/test\_paths.sh | Tout chemin cité dans `hooks.json`, les skills et les agents existe et passe par `${CLAUDE_PLUGIN_ROOT}` ; chaque gabarit est cité ; aucun fichier annexe ne contient la variable ; hooks en forme exec ; exactement deux hooks, aucun des gardes retirés ni câblé ni présent ; le lexer présent ; aucun chemin personnel ni chemin réel du store Nix |
| static/test\_templates.sh | Aucune règle `allow` ne couvre push, merge, reset, clean, suppression, ni mise à jour d'une dépendance ou du SDK ; les `deny` attendus et les règles génériques de l'orchestrateur 0.1.0 sont présents ; le fragment est exactement la part flutter/dart des règles complètes ; `forge-config.yaml` au schéma 2 avec la partie Flutter et sa toolchain ; champs du checkpoint ; en-têtes DRAFT et REVIEW des documents ; `CLAUDE.md` nomme les workflows de l'orchestrateur |
| static/test\_docs.sh | La documentation utilisateur suit le plugin : README et dernière entrée du CHANGELOG à la version de `plugin.json` ; nombre de skills et d'agents exact partout où il est écrit ; chaque skill a sa ligne dans le README et sa section dans le guide, chaque agent sa ligne dans les deux ; chaque règle Bash du gabarit est citée par SECURITY.md sous son niveau (`allow`, `ask`, `deny`) |
| static/test\_maintenance\_skills.sh | update-project et son gabarit de rapport, adopt-existing-project et sa grille de divergences énoncent leurs points de validation, commandes et limites ; update-project ne lance jamais `flutter upgrade` ni `dart pub` ; avant le plan, adopt-existing-project ne cite `flutter analyze`, `test` et `pub get` qu'avec `--no-pub` ou `--enforce-lockfile` ; les deux vérifient plugin-orchestrator en premier, et update-project le schéma 2 ; aucun renvoi à un composant retiré qui ne soit `plugin-orchestrator:<nom>` ; le code-reviewer rend ses DIVERGENCES |
| static/test\_ci\_template.sh | Gabarit CI : déclencheurs, jeton en lecture, pas de `pull_request_target` ni de secret, actions épinglées par SHA avec leur version, les quatre commandes, les deux marqueurs |
| hooks/test\_agent\_scope\_guard.sh | Inerte hors agent du plugin ; écritures et commandes hors périmètre refusées pour chacun des cinq agents ; `flutter create` du scaffold-engineer limité au dossier courant, sans `--overwrite` ; fichier racine autorisé comparé exactement ; commandes composées refusées ; un agent sans branche de liste blanche refusé ; erreurs internes bloquantes |
| hooks/test\_format\_dart.sh | `.dart` formaté, autre fichier ignoré, absence de `dart` sans erreur |

`run-all.sh` lance aussi `claude plugin validate . --strict` : local, déterministe, sans quota. Comme ce validateur ne voit ni un script de hook absent ni, de façon fiable, un frontmatter d'agent cassé, les tests statiques ci-dessus restent nécessaires.

Outillage de développement : les skills de `plugin-dev` (installé depuis `claude-plugins-official`, antérieur à la doc courante) servent d'aide-mémoire ; en cas de conflit, la doc officielle et `claude plugin validate` priment. Les agents sont rédigés directement, puis relus une fois par l'agent `skill-reviewer`.

**Scénarios comportementaux** (`tests/scenarios/*.md`, exécutés en mode headless avec le plugin chargé depuis son dossier et, depuis la 1.0, plugin-orchestrator par un second `--plugin-dir` — variable `FORGE_ORCHESTRATOR_DIR` de `headless.sh` —, ou à la main). Mode d'exécution, vérifié en phase A (rapport §3.8) :

- `claude -p --plugin-dir <plugin> --output-format stream-json`, **sans `--bare`**, qui exigerait une clé API payante ; l'événement `system/init` liste `plugins` et `plugin_errors`, ce qui prouve le chargement. L'éventuelle obligation d'ajouter `--verbose` et l'existence de `--max-turns` en 2.1.296 sont à confirmer en phase F ;
- `--permission-mode dontAsk` avec `--allowedTools` explicite, car `-p` ignore les `allow` d'un projet non approuvé ;
- points de validation sur plusieurs tours : `--session-id <uuid>`, puis `--resume <uuid> "<réponse>"` ;
- pas de `claude plugin eval` en v0.1 : coût multiplié, et bac à sable incompatible avec Flutter sur cette machine.

1. **Bootstrap par l'orchestrateur** dans un dossier vide : mandat `scaffold` au scaffold-engineer, rapport à `INTERFACE: 1`, `.forge/config.yaml` écrit depuis son `TOOLCHAIN`, `flutter test` vert, TRD en DRAFT, aucune CI.
6. **Dépôt existant** : l'analyse ne modifie aucun fichier, et après un accord partiel seuls les items approuvés sont appliqués ; README et `CLAUDE.md` existants intacts ; mandats à l'interface 1 au product-architect de l'orchestrateur puis au flutter-architect ; `.forge/config.yaml` au schéma 2.
10. **Mise à jour de dépendances** (critère de sortie v0.3) : inventaire sans modification, plan de lots, seuls les lots approuvés appliqués et commités avec leur lockfile, tests verts après chacun, rapport avant/après ; ni `flutter upgrade` ni `dart pub`.
11. **Builds locaux** : mandat `build` au devops-engineer ; trois états par plateforme, artefacts vérifiés par la session principale.
12. **CI rouge** : mandat `ci-diagnosis` depuis le github-workflow de l'orchestrateur, sur une vraie PR rouge, lignes de journal revérifiées, correctif orienté vers le code ; ni relance ni push.
13. **Sans orchestrateur** : adopt-existing-project et update-project s'arrêtent sur la vérification, rien changé.
14. **Critère v0.1 de l'orchestrateur** : bootstrap, une fonctionnalité en TDD (ROUGE puis VERT consignés, mandats à l'interface 1), commit propre, reprise après interruption ; aucun garde en double.

Les scénarios 2 à 5 et 7 à 9 de la v0.3 sont partis avec les composants qu'ils testaient ; les numéros restent pour l'historique.

Le rapport de test du plugin sépare trois colonnes : exécuté automatiquement, vérifié manuellement, bloqué (raison). Les scénarios GitHub utilisent un dépôt de test privé jetable, créé uniquement avec accord.

## Points vérifiés en phase A et risques

Ces points ont été vérifiés en phase A contre la documentation officielle (2026-10-17, Claude Code 2.1.296) ; le détail et les sources sont dans `docs/PHASE_A_REPORT.md`, §3 et §4.

- [x] Champs exacts et obligatoires de `plugin.json` et `marketplace.json` — confirmé, avec précisions
- [x] Commandes `/plugin …`, option `--plugin-dir`, existence de `claude plugin validate` — confirmé ; « mettre à jour » infirmé pour une marketplace locale (lue sur place)
- [x] Frontmatter des agents — champs et syntaxe de `tools` confirmés ; restriction de Bash par motif **infirmée**, remplacée par agent-scope-guard
- [x] Frontmatter des skills et règles de chargement automatique — confirmé
- [x] Format de `hooks.json`, événements, entrée JSON, codes de sortie — confirmé ; seul l'exit 2 bloque, fail-closed par `onFailure: "block"`
- [x] Disponibilité de `${CLAUDE_PLUGIN_ROOT}` dans les hooks et les skills — confirmé, absente des commandes Bash de Claude et des fichiers annexes
- [x] Un plugin peut-il fournir des règles de permission ? — confirmé : non
- [x] Exécution headless avec un plugin chargé — confirmé par la doc ; exécution en phase F

Côté outils : Flutter stable courant 3.47.7 (installé : 3.44.3) ; sous-commandes `gh` vérifiées par `--help` ; quotas GitHub Actions ci-dessus, multiplicateur macOS non vérifié.

Vérifiés le 2026-10-29 pour la v1.0 (détail : `PROGRESS.md`, phase A v1.0) :

- [x] Les 382 cas des suites de guard-destructive, secret-scan, protect-sensitive et checkpoint-reminder, rejoués contre les hooks de plugin-orchestrator 0.1.0 : mêmes décisions, seuls les textes diffèrent
- [x] `flutter create .` dans un dossier qui contient `.forge/` : `.forge/` intact, `.gitignore`, `README.md`, `analysis_options.yaml`, `pubspec.yaml` écrits à la racine
- [x] `orch.sh approve` sans `approvals.log` : le journal est créé ; un APPROVED sans empreinte repasse en REVIEW à sa première modification
- [x] `--plugin-dir` répétable (Claude Code 2.1.309) : les deux plugins chargés `@inline`

Vérifiés le 2026-10-20 pour la v0.2 (détail : `PROGRESS.md`, phase A v0.2) :

- [x] `permissionDecision: "ask"` d'un PreToolUse : invite étiquetée `[plugin:<nom>]`, y compris pour un sous-agent en arrière-plan ; refus en `-p`, raison lue par Claude ; précédence `deny` > `defer` > `ask` > `allow`
- [x] gitleaks 8.30.1 : `git --pre-commit --staged`, `--redact`, `--exit-code`, rapport JSON sur la sortie standard ; `protect` est dépréciée
- [x] `actions/checkout` v7.0.1 et `subosito/flutter-action` v2.23.0, par leur SHA de commit ; le gabarit passe `actionlint` 1.7.12 et ses commandes réussissent sur un projet `flutter create`
- [x] `gh` 2.101.0 : `pr create --head`, `pr checks` (exit 8 en attente), `run view --log-failed`, `repo create --source --remote`, `auth status --json hosts`
- [x] `git diff --cached` avant le premier commit (exit 0) ; un chemin avec espace suivi d'une tabulation dans l'en-tête `+++` du diff

| Risque | Effet | Parade |
| --- | --- | --- |
| Les gardes communs (orchestrateur) sont contournés par une syntaxe imprévue | Commande destructive exécutée | Deuxième couche `deny` ; tests à motifs larges dans plugin-orchestrator ; revue de ses hooks à chaque version |
| Les deux plugins divergent sur le contrat de délégation | Un mandat ou un rapport mal lu, un workflow arrêté | Interface versionnée (`interface: 1`, écho `INTERFACE: 1`) ; `test_agents.sh` fige les sections des rapports ; scénarios 1 et 14 avec les deux plugins ; copies de gabarits vérifiées par `test_templates.sh` |
| plugin-flutter 0.x installé à côté de l'orchestrateur | Hooks en double, délégation refusée | Documenté (INSTALLATION, TROUBLESHOOTING) ; résolu par la mise à jour vers la 1.0 |
| Les consignes d'écriture « par dossier » des agents ne sont pas respectées | Fichiers modifiés hors périmètre | agent-scope-guard refuse l'appel d'outil ; le reviewer compare `git diff --name-only` au périmètre déclaré |
| Un frontmatter d'agent illisible | L'agent reçoit tous les outils, sans message | Test statique strict du frontmatter dans `run-all.sh` |
| Un hook qui plante laisse passer | Garde-fou inopérant | `exit 2` sur erreur interne et `onFailure: "block"` ; tests d'erreur interne |
| Checkpoint non mis à jour | Reprise sur un état faux | checkpoint-reminder et recover-session de l'orchestrateur, qui croise avec Git |
| Documentation trop lourde pour un débutant | Abandon du workflow | Socle de quatre documents, optionnels à la demande |
| Coût en quota des agents | Session coupée en plein cycle | TDD en session principale ; agents sur mandat, aux jalons seulement |
| Évolution du format des plugins | Plugin non chargé après mise à jour de Claude Code | Tests statiques en CI ; version minimale documentée dans INSTALLATION.md |
