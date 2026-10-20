# Architecture — plugin-flutter

Oct 17, 2026 · @Soon

## Vue d'ensemble

`plugin-flutter` est un plugin Claude Code qui encadre la création et la maintenance d'applications Flutter/Dart : il apporte des workflows (skills), des spécialistes (agents) et des garde-fous déterministes (hooks). Il ne contient aucune dépendance propre à une application et sert à plusieurs projets.

**Statut du document : REVIEW** depuis le 2026-10-20, pendant la v0.3 : les composants de la v0.3 y sont ajoutés au fil des phases, avec les décisions D27 et suivantes de `PROGRESS.md`. Il repasse en APPROVED à la clôture, sur l'accord explicite de l'utilisateur. Version précédente : APPROVED le 2026-10-20 (« clôture et publie »), à la clôture de la v0.2.0, avec les décisions D12 à D26. Version précédente : APPROVED le 2026-10-19 (« clôture la v1 »), à la clôture de la v0.1.0, avec les corrections de la phase A (`docs/PHASE_A_REPORT.md`, §5, écarts E1 à E19) et les recommandations du §7 (D1 à D9).

Version minimale de Claude Code : **2.1.295** (champ `onFailure` des hooks). Version vérifiée : 2.1.296.

Principes directeurs :

- **Petit d'abord.** Une v0.1 éprouvée vaut mieux que dix skills non testés.
- **La session principale orchestre.** Elle seule dialogue avec l'utilisateur et valide ; les agents exécutent une tâche bornée et rendent un rapport.
- **Déterministe = hook, jugement = skill ou agent.** Tout ce qui doit toujours se produire (formatage, blocage d'une commande destructive) est un hook, pas une consigne.
- **Rien n'est approuvé implicitement.** Documents, push, PR, fusion et release exigent une trace d'accord.
- **Honnêteté des résultats.** Chaque test est rapporté comme réussi, échoué, bloqué ou non exécuté, avec la commande lancée.
- **État sur disque, pas en mémoire.** Le travail est repris depuis Git et un fichier de checkpoint, jamais depuis le souvenir d'une session.
- **Langues.** Code, identifiants et fichiers du plugin en anglais ; messages à l'utilisateur en français.

## Périmètre v0.1 et feuille de route

La v0.1 couvre le cycle minimal : créer un projet, développer une fonctionnalité en TDD, committer proprement, reprendre après interruption. Chaque version n'est lancée qu'après validation de la précédente sur un vrai projet.

| Version | Skills | Agents | Hooks / autres | Critère de sortie |
| --- | --- | --- | --- | --- |
| v0.1 | bootstrap-project, create-feature (TDD intégré), git-workflow, recover-session | flutter-architect, test-engineer, code-reviewer | guard-destructive, agent-scope-guard, format-dart, checkpoint-reminder ; template settings.json | Projet démo créé + 1 feature en TDD + commit sur branche + reprise réussie |
| v0.2 | github-workflow, debug-project | devops-engineer | secret-scan avant commit, protect-sensitive ; template CI Flutter | PR ouverte sur dépôt de test avec CI verte |
| v0.3 | update-project, adopt-existing-project | product-architect | détection de divergences docs/code | Mise à jour d'un lot de dépendances avec rapport avant/après |
| v0.4 | release-project, optimize-usage | ui-ux-engineer | matrice plateformes en CI | Build de release Android + Web vérifié |

`implementation-engineer` n'est pas prévu comme agent séparé : l'implémentation reste dans la session principale pour éviter des transferts de contexte coûteux pendant le cycle rouge-vert. Réévalué en v0.3 et maintenu ainsi (D29).

## Arborescence du plugin

Les composants sont à la racine du plugin ; seul le manifeste vit dans `.claude-plugin/`. Les éléments marqués (v0.3+) ne sont créés qu'à leur version.

```
plugin-flutter/
├── .claude-plugin/
│   ├── plugin.json              # manifeste (nom, version, description, auteur, licence)
│   └── marketplace.json         # marketplace locale pour installer/mettre à jour
├── agents/
│   ├── flutter-architect.md
│   ├── test-engineer.md
│   ├── code-reviewer.md
│   ├── devops-engineer.md
│   ├── product-architect.md
│   └── ui-ux-engineer.md        # (v0.4)
├── skills/
│   ├── bootstrap-project/
│   │   ├── SKILL.md
│   │   └── reference/doc-templates/   # gabarits PRD, TRD, PLAN, DECISIONS
│   ├── create-feature/SKILL.md
│   ├── git-workflow/SKILL.md
│   ├── recover-session/SKILL.md
│   ├── github-workflow/
│   │   ├── SKILL.md
│   │   └── reference/pr-body.md      # gabarit du corps de PR
│   ├── debug-project/SKILL.md
│   ├── update-project/
│   │   ├── SKILL.md
│   │   └── reference/deps-report.md  # gabarit du rapport avant/après
│   ├── adopt-existing-project/
│   │   ├── SKILL.md
│   │   └── reference/divergences.md  # grille et format des divergences
│   ├── release-project/SKILL.md      # (v0.4)
│   └── optimize-usage/SKILL.md       # (v0.4)
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── guard-destructive.sh
│       ├── agent-scope-guard.sh
│       ├── format-dart.sh
│       ├── checkpoint-reminder.sh
│       ├── secret-scan.sh
│       ├── protect-sensitive.sh
│       └── lib/shell-lexer.sh        # analyseur partagé par les gardes
├── templates/
│   ├── project-settings.json     # permissions proposées au projet
│   ├── forge-config.yaml         # préautorisations par défaut (tout à false)
│   ├── checkpoint.md
│   └── github-workflows/flutter-ci.yml  # CI copiée par github-workflow
├── tests/
│   ├── run-all.sh
│   ├── static/                  # manifeste, frontmatter, chemins
│   ├── hooks/                   # tests des scripts avec entrées JSON simulées
│   └── scenarios/               # scénarios comportementaux pas à pas
├── docs/
│   ├── INSTALLATION.md
│   ├── USER_GUIDE.md
│   ├── SECURITY.md
│   ├── TROUBLESHOOTING.md
│   └── PHASE_A_REPORT.md        # audit de la doc officielle (phase A)
├── ARCHITECTURE.md              # ce document
├── PROGRESS.md                  # suivi de développement du plugin
├── README.md
├── CHANGELOG.md
└── LICENSE                      # MIT
```

Les skills et hooks référencent les fichiers du plugin via la variable `${CLAUDE_PLUGIN_ROOT}`, jamais par chemin absolu :

- dans `hooks.json`, elle est substituée dans `command` et `args`, et exportée dans l'environnement du script ;
- dans un `SKILL.md` ou un agent, elle est substituée dans le corps Markdown au chargement, si bien que Claude reçoit un chemin absolu ;
- elle n'existe **pas** dans l'environnement des commandes Bash de Claude, ni dans les fichiers annexes lus par `Read` : ces fichiers (gabarits de `reference/doc-templates/`) ne la contiennent donc pas.

La racine du plugin change à chaque mise à jour d'une installation distante : aucun état n'y est écrit. L'état vit dans `<projet>/.forge/`.

Pas de `CLAUDE.md` à la racine du plugin : il ne serait pas chargé, et déclenche un avertissement du validateur.

## Manifeste et distribution

Le plugin est publié dans le dépôt public `soonlysoul/plugin-flutter` et distribué par la marketplace `soon` (dépôt public `soonlysoul/claude-plugins`), qui le référence en source `github`. Le dossier du plugin reste aussi une marketplace locale, `plugin-flutter`, pour le développement. Champs vérifiés en phase A (rapport, §3.1).

`.claude-plugin/plugin.json` :

```json
{
  "name": "plugin-flutter",
  "version": "0.2.0",
  "description": "Flutter/Dart project workflows: bootstrap, TDD features, Git hygiene, session recovery, GitHub pull requests and CI, debugging.",
  "author": { "name": "Soon" },
  "homepage": "https://github.com/soonlysoul/plugin-flutter",
  "repository": "https://github.com/soonlysoul/plugin-flutter",
  "license": "MIT",
  "keywords": ["flutter", "dart", "tdd", "git", "github", "ci"]
}
```

- Seul `name` est obligatoire, mais l'absence de `version`, `description` ou `author` produit un avertissement, donc un échec de `claude plugin validate --strict`.
- Un champ inconnu est retiré au chargement et signalé.
- `homepage` et `repository` pointent vers le dépôt GitHub, qui doit exister : une URL invalide empêche le chargement du plugin.
- `version` est ignorée pour une marketplace locale, dont le plugin est lu sur place. Depuis la marketplace `soon`, elle décide des mises à jour : un appareil ne reçoit une nouvelle copie que si `version` change. Elle est donc augmentée à chaque release, et ne figure pas dans l'entrée de la marketplace.

`.claude-plugin/marketplace.json` déclare la marketplace locale `plugin-flutter` (propriétaire `Soon`), qui contient ce seul plugin. L'entrée s'écrit `"source": "./"`, avec le même `name` que `plugin.json`, sans répéter `version`.

Cycle de vie (vérifié en phase A, rapport §3.2). `/plugin` n'existe qu'en session interactive ; les commandes `claude plugin …` sont leurs équivalents scriptables.

| Étape | En session | En shell |
| --- | --- | --- |
| Test sans installation | — | `claude --plugin-dir <chemin>` (plugin `@inline`, pour la session seule) |
| Ajouter la marketplace | `/plugin marketplace add soonlysoul/claude-plugins` (locale : `<chemin>`) | `claude plugin marketplace add soonlysoul/claude-plugins [--scope user\|project\|local]` |
| Installer | `/plugin install plugin-flutter@soon` (locale : `plugin-flutter@plugin-flutter`) | `claude plugin install plugin-flutter@soon [-s user\|project\|local]` |
| Mettre à jour (marketplace locale) | `/reload-plugins` : le plugin est lu sur place, rien à réinstaller | redémarrer la session |
| Mettre à jour (marketplace `soon`) | `/plugin marketplace update soon` | `claude plugin marketplace update soon`, puis `claude plugin update plugin-flutter@soon` |
| Désinstaller | `/plugin uninstall plugin-flutter` | `claude plugin uninstall plugin-flutter@soon [-s …]` ; `claude plugin marketplace remove soon` retire aussi la marketplace |
| Valider | — | `claude plugin validate . --strict` (0 réussi, 1 échec, 2 erreur du validateur) |
| Inventaire et coût | — | `claude plugin details plugin-flutter` |

Versionnage SemVer : patch pour une correction de consigne, minor pour un skill ou agent ajouté, major pour un changement de format de `.forge/` qui casse la reprise.

## Orchestration

La session principale est le seul chef d'orchestre : elle charge les skills, délègue des tâches bornées aux agents, et porte toutes les validations, car un agent ne peut ni dialoguer avec l'utilisateur ni lancer d'autres agents.

&#91;embedded content: orchestration · 6 composants, 3 couches\]

Règles de délégation :

- Un agent n'est lancé que si sa tâche est autonome et que son rapport évite au moins autant de lectures qu'il en coûte ; sinon la session principale fait le travail.
- Les agents s'exécutent l'un après l'autre sur un même dépôt. Un parallélisme éventuel passe par des worktrees Git séparés, jamais sur les mêmes fichiers.
- En session interactive, un sous-agent tourne en arrière-plan par défaut : son rapport arrive par notification, au tour suivant. La session principale attend ce rapport avant l'étape qui en dépend, et n'écrit rien en parallèle.
- Un agent ne liste jamais `Agent` dans ses outils : il ne peut donc pas lancer d'autre agent. `AskUserQuestion` ne lui est jamais offert.
- La racine du projet, pour les hooks comme pour les règles de permission, est le dossier où la session a été lancée (`CLAUDE_PROJECT_DIR`). bootstrap-project crée donc de préférence le projet dans le dossier courant, s'il est vide. S'il le crée dans un sous-dossier, il rédige lui-même le TRD, et create-feature exige une nouvelle session ouverte à la racine du projet.
- Le code-reviewer ne reçoit que le diff et les exigences, pas le raisonnement de l'implémentation, pour que sa relecture reste indépendante.
- Chaque rapport d'agent est vérifié par la session principale (commandes relancées si besoin) avant d'être présenté comme un fait.

## Agents

Chaque agent est un fichier Markdown avec frontmatter (`name`, `description`, `tools`, `model`) et un corps d'instructions en anglais. La restriction d'outils dans le frontmatter est ce qui rend un agent réellement « lecture seule » ; une consigne seule ne suffit pas.

Ce que le frontmatter peut et ne peut pas exprimer (vérifié en phase A, rapport §3.3) :

- `tools` est une liste de noms d'outils ; omis, l'agent hérite de **tous** les outils. Un motif du type `Bash(git diff *)` n'y est pas documenté, et `disallowedTools: Bash(…)` retire Bash en entier : la liste blanche Bash par agent ne s'exprime donc pas ici.
- `permissionMode`, `hooks` et `mcpServers` sont ignorés pour un agent de plugin.
- Un frontmatter illisible se charge « avec tous les champs ignorés », donc avec tous les outils, sans message. Le test statique du frontmatter est strict pour cette raison.

Les limites fines (dossiers d'écriture, liste blanche Bash) sont imposées par le hook **agent-scope-guard**, qui reçoit `agent_type` (`plugin-flutter:<agent>`).

« Git en lecture » désigne `git status`, `git log`, `git diff`, `git show`, `git ls-files`, `git rev-parse` et `git branch --show-current`.

| Agent | Version | `tools` (frontmatter) | Limites imposées par agent-scope-guard | `model` | Reçoit | Rend |
| --- | --- | --- | --- | --- | --- | --- |
| flutter-architect | v0.1 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `docs/` ; Bash limité à `flutter --version`, `dart --version`, `dart pub deps`, `flutter pub deps`, et git en lecture | `inherit` | Besoin, code existant, PRD | TRD, décisions ADR dans DECISIONS.md, liste de dépendances justifiées |
| test-engineer | v0.1 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `test/` et `integration_test/` ; Bash limité à `flutter test`, `dart test`, et git en lecture | `sonnet` | Critères d'acceptation, plan de la feature | Tests écrits, sortie brute de l'exécution ROUGE, liste des cas limites |
| code-reviewer | v0.1 | Read, Grep, Glob, Bash — aucune écriture | Aucune écriture ; Bash limité à `git diff`, `git log`, `git show`, `git status`, `flutter analyze`, `dart analyze` | `sonnet` | Diff de la branche, exigences liées | Constats priorisés (bloquant / important / mineur) avec fichier:ligne ; DOCS_TO_UPDATE ; DIVERGENCES entre docs et diff (D40) |
| product-architect | v0.3 | Read, Grep, Glob, Write, Edit — pas de Bash | Écriture limitée à `docs/product/` ; aucune commande | `inherit` | Description du besoin (tâche `draft`), ou code d'une app adoptée (tâche `reconstruct`) | `docs/product/PRD.md` en DRAFT, critères AC-xxx numérotés, testables, jamais renumérotés ; bloc ACCEPTANCE_CRITERIA |
| devops-engineer | v0.2 | Read, Grep, Glob, Bash, Write, Edit | Écriture limitée à `.github/` ; Bash limité à `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status` (sans `--show-token`), `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, `git remote -v` et git en lecture ; option `-o`/`--output` refusée | `sonnet` | Tâche `build`, `ci-diagnosis` ou `workflow-change` ; plateformes activées ; branche, PR ou run | Tableau BUILDS par plateforme ; classe d'un échec de CI avec ses lignes de journal et le correctif à faire |

devops-engineer ne pousse pas, n'ouvre ni ne modifie de PR, ne relance ni ne démarre de workflow, ne télécharge pas d'artefact et n'appelle pas `gh api` : ces actions changent le dépôt distant ou consomment des minutes, et restent dans la session principale, derrière un point de validation (D16). Le fichier CI initial est écrit par la session principale depuis le gabarit, une copie courte ; l'agent sert aux journaux longs (D17).

product-architect ne décide ni l'architecture, ni les dépendances, ni les plateformes, qui restent au flutter-architect. Il est délégué par adopt-existing-project, et par bootstrap-project quand le besoin fourni est long ; create-feature écrit lui-même un AC isolé (D39).

Les agents v0.4 du tableau ci-dessous suivront la même règle : `tools` dans le frontmatter, limites fines dans agent-scope-guard.

| Agent | Version | Outils autorisés | Reçoit | Rend |
| --- | --- | --- | --- | --- |
| ui-ux-engineer | v0.4 | Read, Write limité à `docs/design/` et `lib/ui/` | PRD, APPFLOW | Spécification UI, états d'erreur, points d'accessibilité |

Deux couches se complètent : agent-scope-guard refuse l'appel d'outil hors périmètre ; le code-reviewer compare ensuite `git diff --name-only` au périmètre déclaré, car une commande Bash autorisée (`flutter test`) peut encore produire des fichiers.

Chaque agent termine par un rapport au format fixe : `STATUS` (done / blocked / partial), `FILES_CHANGED`, `COMMANDS_RUN` avec code de sortie, `OPEN_QUESTIONS`.

## Skills

Un skill est un dossier `skills/<nom>/SKILL.md` invoqué par `/plugin-flutter:<nom>` ou chargé automatiquement quand sa `description` correspond à la demande. La description doit donc dire précisément quand l'utiliser. Chaque skill écrit le checkpoint à chaque étape terminée.

| Skill | Version | Déclencheur | Points de validation obligatoires | Produit |
| --- | --- | --- | --- | --- |
| bootstrap-project | v0.1 | Créer une nouvelle app | Nom, package id, plateformes, périmètre ; approbation du PRD/TRD avant le code | Squelette `flutter create`, Git initialisé, docs socle, test de base vert, `.forge/` |
| create-feature | v0.1 | Ajouter une fonctionnalité | Plan de la feature si périmètre, architecture ou dépendance nouvelle | Branche, tests, code, revue, docs mises à jour, commit préparé |
| git-workflow | v0.1 | Brancher, committer, vérifier un diff | Toute opération hors liste blanche | Branche nommée, commits atomiques, rapport de diff |
| recover-session | v0.1 | Reprendre un travail | Aucune (lecture seule jusqu'au résumé) | Résumé de reprise + prochaine étape proposée |
| github-workflow | v0.2 | Dépôt distant, issue, PR, CI | Création de dépôt (propriétaire, nom, visibilité, à chaque fois), ajout de la CI (avec son coût), PR et push si non préautorisés, relance de CI sur dépôt privé ; jamais de fusion | PR avec résumé, AC, risques, tests en quatre catégories, plateformes en trois états ; état des checks |
| debug-project | v0.2 | Erreur de build, d'analyse ou test rouge inattendu, CI rouge | Modification hors du périmètre de l'erreur | Cause racine prouvée, test de non-régression ROUGE puis VERT, correctif minimal, commit `fix(…)` |
| update-project | v0.3 | Mettre à jour Flutter ou dépendances | Plan de lots, toujours, avec chaque majeure et son changelog ; référence rouge ; lock périmé ; plateforme perdue par un plugin ; migration hors des fichiers qui importent le paquet ; abandon d'un lot ; changement de SDK (fait par l'utilisateur) | Branche `chore/deps-<slug>`, un commit par lot avec `pubspec.yaml`, `pubspec.lock` et registres de plugins, ADR par majeure, rapport `.forge/reports/deps-<date>-<slug>.md` |
| adopt-existing-project | v0.3 | Prendre en main un projet Flutter existant, sans `.forge/` | Plan de mise en conformité, approuvé item par item ; chaque fichier existant modifié, approuvé séparément ; fichier suivi changé par la résolution | Branche `chore/adopt-plugin-flutter`, `.forge/`, PRD, TRD, DECISIONS et plan reconstruits en DRAFT, `.forge/reports/divergences-<date>.md` |
| release-project | v0.4 | Préparer une release | Toute publication, tag poussé, signature | Notes de version, builds vérifiés par plateforme |
| optimize-usage | v0.4 | Session longue ou coûteuse | Aucune | Recommandations ; résumé de contexte compact |

update-project (D31 à D35) part d'une référence : `flutter pub get --enforce-lockfile`, puis `flutter analyze` et `flutter test`. L'inventaire vient de `flutter pub outdated --json`, qui ne modifie aucun fichier et sort en 0 même avec des paquets en retard. Chaque dépendance directe est classée compatible (`upgradable` plus récente), majeure (`resolvable` change la version majeure, ou la mineure sous 1.0), retenue (`latest` hors d'atteinte, souvent à cause du SDK) ou signalée (avis de sécurité, version retirée, paquet abandonné). Lots : les paquets signalés, puis `flutter pub upgrade` pour tout le compatible, puis un lot par majeure avec `flutter pub upgrade --major-versions <paquet>`. Après chaque lot : fichiers attendus seulement, `CHANGELOG.md` lu dans le cache pub pour une majeure, plateformes d'un plugin comparées à `platforms.enabled`, analyse et tests, commit. Le SDK n'est jamais changé par Claude : `flutter upgrade`, `downgrade` et `channel` demandent confirmation dans les règles du projet, et sous Nix (`flutterRoot` dans `/nix/store/`) la version vient de la configuration Nix de l'utilisateur. Après un changement de SDK, le skill rappelle la ligne `flutter-version` de `.github/workflows/ci.yml`.

adopt-existing-project (D37, D38) ne modifie rien avant l'accord : ses étapes 1 à 4 sont en lecture seule, prouvée par un `git status --porcelain` identique avant et après. La phase A a montré qu'un `flutter analyze` nu, qui lance `pub get`, réécrit un `pubspec.lock` périmé : la référence passe donc par `flutter pub get --enforce-lockfile` (exit 65 sur un lock périmé, 1 sans lock, sans rien écrire), puis `flutter analyze --no-pub` et `flutter test --no-pub`. Après accord, product-architect reconstruit le PRD (tâche `reconstruct`) et flutter-architect le TRD et les ADR, l'un après l'autre ; un document existant est gardé et référencé, jamais remplacé, et aucun code n'est déplacé.

La détection des divergences docs/code est un contrôle de jugement, pas un hook (D28) : une étape d'adopt-existing-project, guidée par `reference/divergences.md` (dépendances, critères, plan, README, plateformes, toolchain, lockfile, structure, analyse, tests, secrets), et le bloc DIVERGENCES du code-reviewer à chaque revue (D40) : dépendance ajoutée ou passée à une majeure sans ADR, critère visé sans test ou test citant un AC absent du PRD, plan contredit par le diff. create-feature le traite à l'étape 14 ; debug-project le reporte.

Règle commune : un skill ne déclare jamais une étape réussie sans la sortie de la commande correspondante. Après deux échecs identiques d'une même commande, il s'arrête, écrit le checkpoint et expose le blocage au lieu de réessayer.

Points de validation : le skill pose sa question **en texte**, écrit le checkpoint, puis termine son tour et attend la réponse. `AskUserQuestion` n'est pas offert en mode `-p` sans hôte de permission ; poser la question en texte donne le même comportement en interactif et en headless.

Frontmatter retenu : `name`, `description` (qui dit précisément quand charger le skill), et `argument-hint` quand le skill prend un argument. `allowed-tools` n'est pas utilisé : il accorde des outils sans invite et ne restreint rien ; les permissions restent dans le `settings.json` du projet, seule source. Un `SKILL.md` reste sous 500 lignes, car son contenu reste en contexte aux tours suivants.

## Hooks et garde-fous

Les hooks sont déclarés dans `hooks/hooks.json` et exécutent des scripts bash courts, testables avec une entrée JSON simulée. Un hook ne lance jamais la suite de tests complète et n'accorde jamais une permission : il peut seulement bloquer ou compléter.

Règles de mise en œuvre (vérifiées en phase A, rapport §3.5) :

- **Bloquer** : `exit 2`, la raison sur stderr, transmise à Claude. Un `exit 1` est une erreur **non bloquante** : la commande passe.
- **Fail-closed** : le script sort en 2 sur toute erreur interne (`jq` absent, JSON illisible), **et** le hook déclare `"onFailure": "block"`, qui couvre aussi un script introuvable, un plantage et un dépassement de délai. Ce champ exige Claude Code 2.1.295 ou plus.
- **Fail-open** : le script sort toujours en 0, et le hook déclare `"onFailure": "continue"`.
- **Forme exec** : `"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/<script>.sh"]`. Sans shell, ni guillemets, ni bit exécutable, ni shebang ne comptent ; cela règle aussi l'absence de `/bin/bash` sous NixOS. Les scripts gardent `#!/usr/bin/env bash` pour être lancés directement par les tests.
- **Portée** : les hooks d'un plugin se déclenchent dans **toutes** les sessions où il est activé, sous-agents compris. Chaque hook reste donc inerte hors de son contexte : fichier `.dart`, présence de `.forge/`, agent du plugin.
- **Entrée** : `tool_input.command` pour Bash, PowerShell et Monitor (un appel Monitor en mode WebSocket porte `ws` à la place, et passe) ; `tool_input.file_path`, toujours absolu, pour Write et Edit ; `tool_input.notebook_path` pour NotebookEdit.

| Hook | Événement | Filtre | Comportement | En cas d'erreur du script |
| --- | --- | --- | --- | --- |
| guard-destructive | PreToolUse | `Bash\|PowerShell\|Monitor` | Bloque : `git reset --hard` ; `git clean` avec `-f`/`--force` ; `git push` avec `-f`, `--force`, `--force-with-lease` ou `--force-if-includes` à n'importe quelle position, une refspec `+ref`, `--delete`/`-d` ou une refspec `:ref`, `--mirror`, `--tags`/`--follow-tags` ou une refspec `refs/tags/…` ; `git branch -D` et `--delete --force` ; `git checkout -- <chemin>`, `git checkout .` et `--force` ; `git restore` hors `--staged` seul ; `git stash drop` et `git stash clear` ; `git switch --discard-changes`/`-f` ; `rm` récursif et forcé (`-rf`, `-fr`, `-Rf`, `-r -f`, `--recursive --force`) hors `build/`, ou sans cible visible (`xargs`) ; `gh repo delete` ; `gh repo edit` avec `--visibility` ; `gh pr merge` ; `gh release create\|edit\|upload\|delete\|delete-asset` ; `gh api -X DELETE` ; `flutter pub publish` et `dart pub publish`, sauf `--dry-run`. L'analyse découpe la commande (`;`, `&&`, `\|`, sauts de ligne), ignore le texte cité, passe les préfixes (`VAR=…`, `sudo`, `env`, `command`, `nohup`, `timeout`, `nice`, `xargs`) et descend dans `bash -c`, `eval`, `$(…)`, les accents graves, `find -exec`, les heredocs donnés à un shell et les substitutions des heredocs non cités. Renvoie la raison à Claude | Bloque (fail-closed) |
| agent-scope-guard | PreToolUse | `Edit\|Write\|NotebookEdit\|Bash\|PowerShell\|Monitor` | Inerte hors des cinq agents du plugin. Pour eux, refuse toute écriture hors des dossiers de l'agent, et toute commande hors de sa liste blanche (section « Agents ») ; une commande composée (`;`, `&&`, `\|`, `$(…)`, redirection) est refusée ; un agent sans liste blanche (product-architect) n'en lance aucune | Bloque (fail-closed) |
| format-dart | PostToolUse | `Edit\|Write` | Si le fichier finit par `.dart` et que `dart` est dans le PATH : `dart format <fichier>` | Ignore silencieusement (fail-open) |
| checkpoint-reminder | Stop | — | Inerte sans `.forge/checkpoint.md`, ou si `stop_hook_active` est vrai. Si le checkpoint est plus ancien que le dernier commit ou qu'un fichier modifié non commité, renvoie `hookSpecificOutput.additionalContext` : Claude reprend une fois pour le mettre à jour | Ignore (`onFailure` est sans effet sur `Stop`) |
| secret-scan | PreToolUse | `Bash\|PowerShell\|Monitor` | Écarte sans `jq` une entrée sans le mot `commit`. Trouve chaque `git commit` comme guard-destructive (préfixes, `bash -c`, `eval`, `$(…)`), suit `cd`, `pushd`, `git -C`, `--git-dir`. Lit l'index (`git diff --cached`, valable avant le premier commit) et ce que le commit peut prendre d'autre : modifications non indexées pour `-a` ou un chemin nommé ; modifications et fichiers non suivis des chemins d'un `git add` de la même ligne (D13). Refuse `git init`, `git clone`, `git add -f`, `git apply --cached` sur la ligne d'un commit (D25). Bloque les noms `.env`, `.env.*` (sauf `.example`, `.sample`, `.template`), `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.pfx`, et dans les lignes **ajoutées** : clé privée, clé AWS, `gh[pousr]_…`, `github_pat_…`, `sk-…`, `AIza…` (sauf dans la configuration Firebase, D24). Si gitleaks est installé, lance aussi `gitleaks git --pre-commit --staged`, et sans `--staged` pour tout l'arbre. Le secret n'est jamais affiché. Actif dans tout dépôt (D22) | Bloque le commit (fail-closed, y compris sans `grep` ou `awk`) |
| protect-sensitive | PreToolUse | `Edit\|Write\|NotebookEdit` | Écarte sans `jq` une entrée sans nom sensible. Pour un fichier dont un dossier parent contient `.forge/`, répond `permissionDecision: "ask"` avant d'écrire `key.properties`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`, `*.entitlements`, `.github/workflows/*`, `.github/actions/*` ; `.forge/config.yaml` partout. En `-p`, l'appel est refusé et Claude lit la raison | Bloque (fail-closed) |

Le guard-destructive analyse la commande par motifs : il peut être contourné par une formulation exotique. C'est un filet de sécurité, pas une garantie ; les règles `deny` du `settings.json` de projet forment la seconde couche. Toute levée ponctuelle se fait par l'utilisateur, jamais par Claude qui réécrirait la commande : une commande tapée par l'utilisateur avec le préfixe `!` s'exécute sans appel d'outil, donc sans passer par `PreToolUse` (déduit de la doc, à confirmer en phase F).

En portée d'installation `user`, les hooks protègent tous les projets de l'utilisateur, pas seulement les projets générés.

## Sécurité et permissions

La sécurité repose sur trois couches indépendantes : les règles de permission de Claude Code, les hooks du plugin, et les préautorisations du projet. Un plugin ne peut pas imposer de règles `allow`/`deny` (vérifié en phase A, rapport §3.7) : le `settings.json` d'un plugin n'applique que `agent` et `subagentStatusLine`. Le plugin propose donc les règles, et l'utilisateur les installe.

**Couche 1 — `templates/project-settings.json`**, copié dans `<projet>/.claude/settings.json` par bootstrap-project après accord :

```json
{
  "permissions": {
    "allow": [
      "Bash(flutter test *)", "Bash(flutter analyze *)", "Bash(dart format *)",
      "Bash(flutter pub get)", "Bash(flutter pub get --enforce-lockfile)",
      "Bash(flutter pub outdated)", "Bash(flutter pub outdated *)", "Bash(flutter pub deps)", "Bash(flutter pub deps *)",
      "Bash(git status)", "Bash(git diff *)",
      "Bash(git log *)", "Bash(git add *)", "Bash(git switch *)",
      "Bash(gh --version)", "Bash(gh auth status)", "Bash(gh repo view)", "Bash(gh repo view *)",
      "Bash(gh pr view *)", "Bash(gh pr checks *)", "Bash(gh run list *)", "Bash(gh run view *)",
      "Bash(gh run watch *)", "Bash(gh workflow list)", "Bash(gh workflow view *)",
      "Bash(gh issue list *)", "Bash(gh issue view *)", "Bash(git remote -v)", "Bash(git rev-parse *)",
      "Bash(git branch --show-current)", "Bash(flutter --version)", "Bash(flutter --version --machine)", "Bash(flutter doctor)",
      "Bash(flutter doctor *)", "Bash(flutter devices)", "Bash(flutter build *)"
    ],
    "ask": [
      "Bash(git add -A*)", "Bash(git add .)", "Bash(git add --all*)",
      "Bash(git commit *)", "Bash(git push *)", "Bash(gh pr create *)",
      "Bash(flutter pub upgrade *)", "Bash(gh repo create *)", "Bash(gh pr edit *)",
      "Bash(gh issue create *)", "Bash(gh run rerun *)", "Bash(gh workflow run *)",
      "Bash(flutter upgrade*)", "Bash(flutter downgrade*)", "Bash(flutter channel *)"
    ],
    "deny": [
      "Bash(git reset --hard*)", "Bash(git clean *)",
      "Bash(git push --force*)", "Bash(git push * --force*)",
      "Bash(git push -f*)", "Bash(git push * -f*)", "Bash(git push * +*)",
      "Bash(git branch -D *)", "Bash(gh repo delete *)", "Bash(gh pr merge *)",
      "Bash(dart pub publish*)", "Bash(flutter pub publish*)",
      "Read(./.env)", "Read(./.env.*)", "Read(./**/key.properties)",
      "Edit(./.forge/config.yaml)"
    ]
  }
}
```

- La forme `Bash(x *)`, avec espace, est celle de la doc et de la boîte de dialogue ; `Bash(x:*)` en est l'équivalent ancien.
- L'ordre d'évaluation est `deny`, puis `ask`, puis `allow`, la première règle qui correspond l'emporte : les `ask` sur `git add -A` priment donc sur `allow` `git add *`.
- Les règles de fichiers s'écrivent `Edit(…)`, qui couvre tous les outils d'écriture ; une règle `Write(…)` ne protège rien.
- Les `allow` d'un projet ne s'appliquent qu'**après acceptation de la confiance du workspace** ; `deny` et `ask` s'appliquent toujours.
- Une règle Bash ne couvre que la forme écrite (`git -C . push` échappe à `Bash(git push *)`) : le hook reste la couche qui analyse la commande.

**Couche 2 — hooks** (section précédente), actifs dès l'installation du plugin.

**Couche 3 — `<projet>/.forge/config.yaml`**, lu par chaque skill avant une action externe. Toute clé absente vaut `false`. Seul l'utilisateur la modifie : la règle `deny` `Edit(./.forge/config.yaml)` de la couche 1 en bloque l'édition par Claude, et le hook protect-sensitive demande confirmation pour toute écriture d'un `.forge/config.yaml`, y compris dans un projet où `.claude/settings.json` n'est pas installé. bootstrap-project crée le fichier une seule fois, avant d'installer `.claude/settings.json`.

```yaml
schema_version: 1
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
platforms:
  enabled: [android, web, linux]
```

Actions toujours soumises à un accord dans la conversation, quelle que soit la config : fusion dans la branche principale, changement de visibilité, suppression, release publique, toute dépense, tout changement de fournisseur ou de mode d'authentification. Aucun jeton ni secret n'est affiché, écrit dans un fichier de `.forge/` ou passé en argument de commande visible.

## État persistant, reprise et quotas

Le checkpoint est écrit après chaque étape terminée, pas au moment d'une coupure : quand la limite d'usage tombe, la session s'arrête et plus rien ne peut être sauvegardé. La reprise croise donc trois sources : `.forge/checkpoint.md`, l'historique Git et l'état du dépôt.

`<projet>/.forge/checkpoint.md` (versionné dans Git) :

```markdown
# Checkpoint
updated: 2026-10-17T18:40+02:00
skill: create-feature
feature: AC-012 offline note list
branch: feature/offline-note-list
last_commit: 3f2a9c1

## Steps
- [x] 1 Repo state checked (clean)
- [x] 6 Tests written: test/notes/note_repository_test.dart
- [x] 7 RED confirmed: flutter test test/notes → 3 failed (exit 1)
- [ ] 8 Implement minimum
- [ ] 9 GREEN

## Test results
| command | result | when |
| flutter test test/notes | FAILED 3 (expected RED) | 18:38 |

## Next action
Implement NoteRepository.listOffline() in lib/features/notes/data/.

## Blockers / open questions
- none
```

`.forge/` contient aussi `config.yaml` et un dossier `reports/` (rapports de revue et de mise à jour). Rien de secret n'y est écrit.

Algorithme de recover-session :

1. Lire `.forge/checkpoint.md` ; s'il est absent, reconstituer depuis `git log` et la branche courante.
2. Comparer `last_commit` au `HEAD` réel et lister les fichiers modifiés non commités ; ne rien toucher.
3. Signaler toute incohérence (commit plus récent que le checkpoint, branche différente).
4. Relancer uniquement le test ciblé de la dernière étape pour confirmer l'état réel.
5. Présenter un résumé de 10 lignes maximum et la prochaine action, puis attendre l'accord pour reprendre.

Comportement face aux limites : aucune boucle de nouvelle tentative, aucun changement de compte ou de fournisseur, aucune bascule vers une API payante. Si un message de limite ou de blocage apparaît, Claude cesse les appels, s'assure que le checkpoint est à jour et indique ce qui reste. Les économies de quota viennent du travail lui-même : tests ciblés pendant le développement, analyse complète aux jalons, agents seulement quand leur apport justifie leur coût.

## Structure d'un projet généré

bootstrap-project produit un projet Flutter organisé par fonctionnalité, avec un socle documentaire de quatre fichiers et des documents optionnels créés quand le besoin apparaît.

```
my_app/
├── .claude/settings.json        # permissions (copie du template, après accord)
├── .forge/
│   ├── config.yaml
│   ├── checkpoint.md
│   └── reports/
├── .github/workflows/ci.yml     # format + analyze + test (github-workflow ci)
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
│   ├── product/PRD.md
│   ├── technical/TRD.md
│   ├── engineering/IMPLEMENTATION_PLAN.md
│   └── engineering/DECISIONS.md
├── analysis_options.yaml        # flutter_lints + règles strictes
└── CLAUDE.md                    # conventions du projet pour Claude
```

| Document | Socle ou optionnel | Créé quand |
| --- | --- | --- |
| PRD.md | Socle | Bootstrap |
| TRD.md | Socle | Bootstrap |
| IMPLEMENTATION\_PLAN.md | Socle | Bootstrap, mis à jour à chaque feature |
| DECISIONS.md | Socle | Bootstrap, une entrée par choix technique |
| TEST\_STRATEGY.md | Optionnel | Premier test d'intégration ou de golden |
| TRACEABILITY.md | Optionnel | Plus de 10 critères d'acceptation |
| APPFLOW.md | Optionnel | Plus de 3 écrans |
| UI\_UX\_DESIGN.md | Optionnel | Maquettes ou charte fournies |
| BACKEND\_SCHEMA.md | Optionnel | Données persistantes, locales ou distantes |

Chaque document commence par un en-tête fixe : objectif, statut (DRAFT / REVIEW / APPROVED), date et auteur de l'approbation, hypothèses, décisions confirmées, documents liés, critères de vérification. Un document ne passe en APPROVED que sur un message explicite de l'utilisateur ; le skill y inscrit alors la date.

Choix techniques par défaut, révisables par le flutter-architect avec une entrée dans DECISIONS.md : canal Flutter stable, `flutter_lints`, gestion d'état Riverpod, navigation `go_router`, persistance locale avant tout backend distant. BACKEND\_SCHEMA sépare toujours trois parties : données locales, besoins réels d'un backend, évolutions futures.

## Workflow TDD (create-feature)

Le cycle rouge-vert-refactor reste dans la session principale ; le test-engineer conçoit les tests et le code-reviewer relit à la fin. Chaque étape cochée dans le checkpoint s'accompagne de la commande lancée et de son code de sortie.

1. **État du dépôt** : `git status`, branche courante, changements non commités. S'il y en a, les préserver et demander s'il faut les committer, les mettre de côté sur une branche ou s'arrêter. Pas de `git stash` silencieux.
2. **Contexte** : lire PRD, TRD et l'entrée du plan pour la feature ; lister les critères d'acceptation (AC-xxx) visés. Si le PRD ou le TRD n'est pas APPROVED, s'arrêter et demander l'approbation.
3. **Risques et dépendances** : nouveau package, impact plateforme, migration de données.
4. **Plan** : fichiers touchés, tests prévus, dépendances. **Validation utilisateur** si le périmètre, l'architecture ou une dépendance change. Après validation, un nouvel AC est écrit dans le PRD, et une dépendance approuvée est ajoutée (`flutter pub add`) avant tout test qui l'importe, puis ses plateformes sont vérifiées dans son `pubspec.yaml` résolu.
5. **Branche** : `feature/<ac-id>-<slug>` via git-workflow.
6. **Tests d'abord** : le test-engineer écrit les tests liés aux AC, les lance, et rapporte la sortie ROUGE brute. La session principale **attend son rapport** (il arrive par notification en session interactive) et n'écrit rien en parallèle.
7. **ROUGE** : la session principale relance elle-même `flutter test <fichiers ciblés>` pour consigner la preuve, selon la règle du rapport vérifié. L'échec doit porter sur l'assertion attendue, pas sur une erreur de compilation sans rapport. Sortie consignée. Des tests qui passent déjà arrêtent le workflow : le comportement existe peut-être, ou les tests ne le testent pas.
8. **Implémentation minimale** dans la session principale.
9. **VERT** : mêmes tests ciblés, tous passent. Sinon retour à 8, au plus trois itérations avant d'exposer le blocage.
10. **Refactor** sans changement de comportement.
11. **Re-test ciblé** puis, à ce jalon seulement, `flutter test` complet.
12. **Qualité** : `dart format --set-exit-if-changed .` et `flutter analyze` à exit 0 : infos et avertissements sont bloquants par défaut, comme dans la CI.
13. **Revue** : rien n'est encore commité, donc les fichiers de la feature sont indexés, puis le code-reviewer relit `git diff --cached <base>`. Les constats bloquants sont corrigés, les étapes 11 et 12 relancées, et les corrections relues une fois ; un constat bloquant qui subsiste arrête le workflow. Le reviewer liste aussi les mises à jour de docs attendues, traitées à l'étape 14.
14. **Docs** : plan, DECISIONS et traçabilité mis à jour, à partir des DOCS_TO_UPDATE et DIVERGENCES du code-reviewer ; une divergence se résout en corrigeant le document quand le code a raison, sinon elle est signalée à l'utilisateur.
15. **Commit** préparé par git-workflow, puis rapport final.

Le rapport final classe chaque test en quatre catégories : réussi, échoué, bloqué (raison : appareil absent, compte manquant, plateforme non disponible) et non exécuté. Une catégorie vide est indiquée comme telle.

## Git et GitHub

Toute action Git ou GitHub entre dans l'une de trois classes : libre, préautorisable par `.forge/config.yaml`, ou toujours soumise à un accord dans la conversation.

| Action | Classe | Détail |
| --- | --- | --- |
| `git status`, `diff`, `log`, `switch -c` | Libre | Lecture ou création de branche locale |
| `git add <fichiers>` | Libre | Jamais `git add -A` sans relecture du diff ; fichiers générés et `.env` exclus |
| `git commit` | Accord par défaut (`ask`) | Message Conventional Commits : `feat(notes): list notes offline (AC-012)` |
| `git push` d'une branche de travail | Préautorisable | `push_feature_branches: true` ; jamais vers `main` |
| `gh pr create` / mise à jour | Préautorisable | `open_pull_requests`, `update_own_pull_requests` ; jamais de force-push sur une PR d'autrui |
| Création de dépôt distant | Accord, toujours re-confirmé | Nom, visibilité, propriétaire affichés avant ; `gh repo create` sans `--push`, puis publication de la branche principale, seul push de cette branche fait par Claude |
| Ajout ou modification de la CI ; relance ou lancement d'un workflow sur dépôt privé | Accord explicite, avec le coût | Avec un dépôt distant, la CI passe par une branche `chore/ci` et sa PR ; protect-sensitive demande confirmation de l'écriture |
| Fusion, changement de visibilité, suppression, release, tag poussé | Accord explicite à chaque fois | Bloqué aussi par hook |
| `reset --hard`, `clean`, `push --force`, `branch -D` | Interdit sans demande explicite de l'utilisateur | Bloqué par hook et `deny` |

Conventions : branches `feature/`, `fix/`, `chore/deps-`, `docs/` ; commits atomiques (un changement logique, tests compris) ; `.gitignore` Flutter standard plus `.env*`, `*.jks`, `*.keystore`, `key.properties`.

Corps de PR généré par github-workflow (`skills/github-workflow/reference/pr-body.md`) : résumé, AC couverts, risques, tests exécutés avec résultats (quatre catégories), plateformes en trois états, captures si disponibles. `gh pr create --base <principale> --head <branche> --body-file -` avec un heredoc cité, après le push de la branche. Avant toute action GitHub : `gh auth status` ; en cas d'échec, on s'arrête et on explique `gh auth login` sans jamais demander ni afficher de jeton.

Gabarit CI (`templates/github-workflows/flutter-ci.yml`) : sur chaque PR et chaque push vers la branche principale, `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, sur un runner `ubuntu-latest` plafonné à 20 minutes ; `permissions: contents: read`, `persist-credentials: false`, aucun secret ; actions épinglées par SHA de commit (`actions/checkout` v7.0.1, `subosito/flutter-action` v2.23.0) ; `flutter-version` remplacée par la version locale, pour que la CI reproduise la machine.

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

Sur la machine de développement du plugin, seul Linux desktop est vérifiable (Chrome absent, SDK Android incomplet) : `platforms.enabled` garde `[android, web, linux]` par défaut, mais la démo de validation se fait en `linux` seul.

Règles :

- Aucune annonce de build iOS ou de publication iOS réussie sans log de build, signature et contrôle vérifiés.
- Chaque dépendance ajoutée est vérifiée contre les plateformes activées (onglet « Platform » sur pub.dev) et le résultat noté dans DECISIONS.md.
- Sans KVM, les tests d'intégration se replient sur Linux desktop, et le rapport le dit.

## Stratégie de test du plugin

Les tests se répartissent en deux familles qui ne se mélangent pas : les tests déterministes, qui tournent sans Claude et sans quota, et les scénarios comportementaux, qui nécessitent une session Claude Code et consomment le quota Max.

**Tests déterministes** (`tests/run-all.sh`, bash + `jq`, aucun réseau) :

| Fichier | Vérifie |
| --- | --- |
| static/test\_manifest.sh | `plugin.json` et `marketplace.json` sont du JSON valide, champs requis présents, `name` en kebab-case et identique dans les deux, version SemVer, `homepage` et `repository` pointent vers `soonlysoul/plugin-flutter`, `source` vaut `./` |
| static/test\_frontmatter.sh | Chaque agent et skill a un frontmatter lisible par un analyseur **strict** (lignes `clé: valeur` seulement), `name` et `description` non vides ; chaque agent déclare `tools` et `model` ; le reviewer n'a ni Write ni Edit ; product-architect n'a pas Bash ; aucun agent ne liste `Agent` |
| static/test\_paths.sh | Tout chemin cité dans `hooks.json` et les skills existe et passe par `${CLAUDE_PLUGIN_ROOT}` ; aucun fichier annexe ne contient la variable ; hooks en forme exec ; aucun chemin personnel ni chemin réel du store Nix (`/nix/store/<hash>-…`) |
| static/test\_settings\_template.sh | Aucune règle `allow` ne couvre push, merge, reset, clean, suppression, ni mise à jour d'une dépendance ou du SDK ; les `deny` attendus sont présents ; `flutter upgrade`, `downgrade` et `channel` demandent confirmation ; aucune règle `Write(…)` |
| static/test\_maintenance\_skills.sh | product-architect, update-project et son gabarit de rapport, adopt-existing-project et sa grille de divergences énoncent leurs points de validation, commandes et limites ; update-project ne lance jamais `flutter upgrade` ni `dart pub` ; avant le plan, adopt-existing-project ne cite `flutter analyze`, `test` et `pub get` qu'avec `--no-pub` ou `--enforce-lockfile` ; le code-reviewer rend ses DIVERGENCES, que create-feature et debug-project traitent |
| hooks/test\_guard\_destructive.sh | \~30 commandes dangereuses bloquées, \~30 commandes sûres autorisées, entrée JSON malformée bloquée, `jq` absent bloqué, appel `Monitor` couvert |
| hooks/test\_agent\_scope\_guard.sh | Inerte hors agent du plugin ; écritures et commandes hors périmètre refusées pour chacun des cinq agents ; commandes composées refusées ; un agent sans branche de liste blanche refusé ; erreurs internes bloquantes |
| hooks/test\_format\_dart.sh | `.dart` formaté, autre fichier ignoré, absence de `dart` sans erreur |
| hooks/test\_checkpoint\_reminder.sh | Rappel émis quand le checkpoint est plus ancien que les fichiers modifiés ; silence si `stop_hook_active`, sans `.forge/`, ou checkpoint à jour |
| static/test\_tdd\_skill.sh | `create-feature/SKILL.md` contient les 15 étapes, dont ROUGE et VERT, chacune avec une commande et la consigne de consigner sa sortie |
| static/test\_ci\_template.sh | Gabarit CI : déclencheurs, jeton en lecture, pas de `pull_request_target` ni de secret, actions épinglées par SHA avec leur version, les quatre commandes, les deux marqueurs |
| static/test\_github\_skills.sh | github-workflow et debug-project énoncent leurs points de validation, commandes et limites ; corps de PR complet |
| hooks/test\_secret\_scan.sh | Sur de vrais dépôts git jetables : commandes sans commit silencieuses (sans `jq`), chaque motif et chaque nom bloqués sans afficher le secret, faux positifs écartés (`task-`, certificat, `.env.example`, retrait d'un secret), portée (`-a`, chemin, `git add` sur la ligne, fichier ignoré), emplacement (`cd`, `-C`, `bash -c`, `eval`, `$(…)`), fail-closed, gitleaks simulé, durée |
| hooks/test\_protect\_sensitive.sh | `ask` pour chaque fichier sensible d'un projet `.forge/`, silence ailleurs et sans `jq`, `.forge/config.yaml` partout, fail-closed |

`run-all.sh` lance aussi `claude plugin validate . --strict` : local, déterministe, sans quota. Comme ce validateur ne voit ni un script de hook absent ni, de façon fiable, un frontmatter d'agent cassé, les tests statiques ci-dessus restent nécessaires.

Outillage de développement : les skills de `plugin-dev` (installé depuis `claude-plugins-official`, antérieur à la doc courante) servent d'aide-mémoire ; en cas de conflit, la doc officielle et `claude plugin validate` priment. Les agents sont rédigés directement, puis relus une fois par l'agent `skill-reviewer`.

**Scénarios comportementaux** (`tests/scenarios/*.md`, exécutés en mode headless avec le plugin chargé depuis son dossier, ou à la main). Mode d'exécution, vérifié en phase A (rapport §3.8) :

- `claude -p --plugin-dir <plugin> --output-format stream-json`, **sans `--bare`**, qui exigerait une clé API payante ; l'événement `system/init` liste `plugins` et `plugin_errors`, ce qui prouve le chargement. L'éventuelle obligation d'ajouter `--verbose` et l'existence de `--max-turns` en 2.1.296 sont à confirmer en phase F ;
- `--permission-mode dontAsk` avec `--allowedTools` explicite, car `-p` ignore les `allow` d'un projet non approuvé ;
- points de validation sur plusieurs tours : `--session-id <uuid>`, puis `--resume <uuid> "<réponse>"` ;
- pas de `claude plugin eval` en v0.1 : coût multiplié, et bac à sable incompatible avec Flutter sur cette machine.

1. **Bootstrap** dans un dossier temporaire : projet créé, `flutter test` vert, docs socle en DRAFT, `.forge/` présent.
2. **Feature TDD** : checkpoint montrant ROUGE puis VERT avec sorties de commande.
3. **Préservation** : un fichier modifié non commité avant le lancement est intact après.
4. **Blocage** : demande explicite de `git reset --hard` refusée par le hook avec message clair.
5. **Reprise** : session interrompue après l'étape 7, recover-session propose l'étape 8 sans refaire 1 à 7.
6. **Dépôt existant** : l'analyse ne modifie aucun fichier, et après un accord partiel seuls les items approuvés sont appliqués ; README et `CLAUDE.md` existants intacts.
7. **Secret** : un commit qui contient une clé AWS est refusé par secret-scan ; le secret n'apparaît dans aucun message.
8. **Débogage** : un test rouge inattendu est reproduit, sa cause prouvée avant le correctif, le correctif commité sur `fix/…` après revue.
9. **PR et CI** : sur un dépôt de test jetable, CI ajoutée, dépôt créé, PR ouverte, checks verts ; rien de fusionné.
10. **Mise à jour de dépendances** (critère de sortie v0.3) : inventaire sans modification, plan de lots, seuls les lots approuvés appliqués et commités avec leur lockfile, tests verts après chacun, rapport avant/après ; ni `flutter upgrade` ni `dart pub`.
11. **Builds locaux** : tâche `build` de devops-engineer ; trois états par plateforme, artefacts vérifiés par la session principale.
12. **CI rouge** : diagnostic `ci-diagnosis` sur une vraie PR rouge, lignes de journal revérifiées, correctif orienté vers le code ; ni relance ni push.

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

Vérifiés le 2026-10-20 pour la v0.2 (détail : `PROGRESS.md`, phase A v0.2) :

- [x] `permissionDecision: "ask"` d'un PreToolUse : invite étiquetée `[plugin:<nom>]`, y compris pour un sous-agent en arrière-plan ; refus en `-p`, raison lue par Claude ; précédence `deny` > `defer` > `ask` > `allow`
- [x] gitleaks 8.30.1 : `git --pre-commit --staged`, `--redact`, `--exit-code`, rapport JSON sur la sortie standard ; `protect` est dépréciée
- [x] `actions/checkout` v7.0.1 et `subosito/flutter-action` v2.23.0, par leur SHA de commit ; le gabarit passe `actionlint` 1.7.12 et ses commandes réussissent sur un projet `flutter create`
- [x] `gh` 2.101.0 : `pr create --head`, `pr checks` (exit 8 en attente), `run view --log-failed`, `repo create --source --remote`, `auth status --json hosts`
- [x] `git diff --cached` avant le premier commit (exit 0) ; un chemin avec espace suivi d'une tabulation dans l'en-tête `+++` du diff

| Risque | Effet | Parade |
| --- | --- | --- |
| Le guard-destructive est contourné par une syntaxe imprévue | Commande destructive exécutée | Deuxième couche `deny` ; tests à motifs larges ; revue du hook à chaque version |
| Les consignes d'écriture « par dossier » des agents ne sont pas respectées | Fichiers modifiés hors périmètre | agent-scope-guard refuse l'appel d'outil ; le reviewer compare `git diff --name-only` au périmètre déclaré |
| Un frontmatter d'agent illisible | L'agent reçoit tous les outils, sans message | Test statique strict du frontmatter dans `run-all.sh` |
| Un hook qui plante laisse passer | Garde-fou inopérant | `exit 2` sur erreur interne et `onFailure: "block"` ; tests d'erreur interne |
| Checkpoint non mis à jour | Reprise sur un état faux | Hook checkpoint-reminder ; recover-session croise avec Git |
| Documentation trop lourde pour un débutant | Abandon du workflow | Socle de quatre documents, optionnels à la demande |
| Coût en quota des agents | Session coupée en plein cycle | TDD en session principale ; agents aux jalons seulement |
| Évolution du format des plugins | Plugin non chargé après mise à jour de Claude Code | Tests statiques en CI ; version minimale documentée dans INSTALLATION.md |
