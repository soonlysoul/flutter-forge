# Architecture — Dart Multiplatform Forge

Oct 17, 2026 · @Allosun

## Vue d'ensemble

`dart-multiplatform-forge` est un plugin Claude Code qui encadre la création et la maintenance d'applications Flutter/Dart : il apporte des workflows (skills), des spécialistes (agents) et des garde-fous déterministes (hooks). Il ne contient aucune dépendance propre à une application et sert à plusieurs projets.

**Statut du document : DRAFT.** Il passe en REVIEW après la phase A (vérification de la documentation officielle), puis en APPROVED sur validation explicite de l'utilisateur.

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
| v0.1 | bootstrap-project, create-feature (TDD intégré), git-workflow, recover-session | flutter-architect, test-engineer, code-reviewer | guard-destructive, format-dart, checkpoint-reminder ; template settings.json | Projet démo créé + 1 feature en TDD + commit sur branche + reprise réussie |
| v0.2 | github-workflow, debug-project | devops-engineer | secret-scan avant commit ; template CI Flutter | PR ouverte sur dépôt de test avec CI verte |
| v0.3 | update-project, adopt-existing-project | product-architect | détection de divergences docs/code | Mise à jour d'un lot de dépendances avec rapport avant/après |
| v0.4 | release-project, optimize-usage | ui-ux-engineer | matrice plateformes en CI | Build de release Android + Web vérifié |

`implementation-engineer` n'est pas prévu comme agent séparé : l'implémentation reste dans la session principale pour éviter des transferts de contexte coûteux pendant le cycle rouge-vert. À réévaluer en v0.3.

## Arborescence du plugin

Les composants sont à la racine du plugin ; seul le manifeste vit dans `.claude-plugin/`. Les éléments marqués (v0.2+) ne sont créés qu'à leur version.

```
dart-multiplatform-forge/
├── .claude-plugin/
│   ├── plugin.json              # manifeste (nom, version, description, auteur, licence)
│   └── marketplace.json         # marketplace locale pour installer/mettre à jour
├── agents/
│   ├── flutter-architect.md
│   ├── test-engineer.md
│   ├── code-reviewer.md
│   ├── devops-engineer.md       # (v0.2)
│   ├── product-architect.md     # (v0.3)
│   └── ui-ux-engineer.md        # (v0.4)
├── skills/
│   ├── bootstrap-project/
│   │   ├── SKILL.md
│   │   └── reference/doc-templates/   # gabarits PRD, TRD, PLAN, DECISIONS
│   ├── create-feature/SKILL.md
│   ├── git-workflow/SKILL.md
│   ├── recover-session/SKILL.md
│   ├── github-workflow/SKILL.md      # (v0.2)
│   ├── debug-project/SKILL.md        # (v0.2)
│   ├── update-project/SKILL.md       # (v0.3)
│   ├── adopt-existing-project/SKILL.md # (v0.3)
│   ├── release-project/SKILL.md      # (v0.4)
│   └── optimize-usage/SKILL.md       # (v0.4)
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── guard-destructive.sh
│       ├── format-dart.sh
│       ├── checkpoint-reminder.sh
│       └── secret-scan.sh            # (v0.2)
├── templates/
│   ├── project-settings.json     # permissions proposées au projet
│   ├── forge-config.yaml         # préautorisations par défaut (tout à false)
│   ├── checkpoint.md
│   └── github-workflows/flutter-ci.yml  # (v0.2)
├── tests/
│   ├── run-all.sh
│   ├── static/                  # manifeste, frontmatter, chemins
│   ├── hooks/                   # tests des scripts avec entrées JSON simulées
│   └── scenarios/               # scénarios comportementaux pas à pas
├── docs/
│   ├── INSTALLATION.md
│   ├── USER_GUIDE.md
│   ├── SECURITY.md
│   └── TROUBLESHOOTING.md
├── README.md
├── CHANGELOG.md
└── LICENSE                      # MIT par défaut
```

Les skills et hooks référencent les fichiers du plugin via la variable `${CLAUDE_PLUGIN_ROOT}`, jamais par chemin absolu.

## Manifeste et distribution

Le plugin est distribué par une marketplace locale (le dossier lui-même), puis par un dépôt GitHub une fois stable. Les champs exacts sont à confirmer en phase A contre la doc officielle de la version installée.

`.claude-plugin/plugin.json` (forme attendue) :

```json
{
  "name": "dart-multiplatform-forge",
  "version": "0.1.0",
  "description": "Flutter/Dart project workflows: bootstrap, TDD features, Git hygiene, session recovery.",
  "author": { "name": "<your-name>" },
  "license": "MIT",
  "keywords": ["flutter", "dart", "tdd", "git"]
}
```

`.claude-plugin/marketplace.json` déclare une marketplace contenant ce seul plugin, avec `source` pointant vers la racine.

Cycle de vie (commandes à vérifier en phase A) :

| Étape | Commande dans Claude Code |
| --- | --- |
| Test sans installation | `claude --plugin-dir ./dart-multiplatform-forge` |
| Ajouter la marketplace | `/plugin marketplace add ./dart-multiplatform-forge` |
| Installer | `/plugin install dart-multiplatform-forge@<marketplace-name>` |
| Mettre à jour | `/plugin marketplace update <marketplace-name>` puis réinstaller |
| Désinstaller | `/plugin uninstall dart-multiplatform-forge` |
| Valider le manifeste | `claude plugin validate <chemin>` si disponible |

Versionnage SemVer : patch pour une correction de consigne, minor pour un skill ou agent ajouté, major pour un changement de format de `.forge/` qui casse la reprise.

## Orchestration

La session principale est le seul chef d'orchestre : elle charge les skills, délègue des tâches bornées aux agents, et porte toutes les validations, car un agent ne peut ni dialoguer avec l'utilisateur ni lancer d'autres agents.

&#91;embedded content: orchestration · 6 composants, 3 couches\]

Règles de délégation :

- Un agent n'est lancé que si sa tâche est autonome et que son rapport évite au moins autant de lectures qu'il en coûte ; sinon la session principale fait le travail.
- Les agents s'exécutent l'un après l'autre sur un même dépôt. Un parallélisme éventuel passe par des worktrees Git séparés, jamais sur les mêmes fichiers.
- Le code-reviewer ne reçoit que le diff et les exigences, pas le raisonnement de l'implémentation, pour que sa relecture reste indépendante.
- Chaque rapport d'agent est vérifié par la session principale (commandes relancées si besoin) avant d'être présenté comme un fait.

## Agents

Chaque agent est un fichier Markdown avec frontmatter (`name`, `description`, `tools`, `model`) et un corps d'instructions en anglais. La restriction d'outils dans le frontmatter est ce qui rend un agent réellement « lecture seule » ; une consigne seule ne suffit pas.

| Agent | Version | Outils autorisés | Reçoit | Rend |
| --- | --- | --- | --- | --- |
| flutter-architect | v0.1 | Read, Grep, Glob, Bash (lecture : `flutter --version`, `dart pub deps`), Write limité à `docs/` | Besoin, code existant, PRD | TRD, décisions ADR dans DECISIONS.md, liste de dépendances justifiées |
| test-engineer | v0.1 | Read, Grep, Glob, Write/Edit limités à `test/` et `integration_test/`, Bash (`flutter test`) | Critères d'acceptation, plan de la feature | Tests écrits, sortie brute de l'exécution ROUGE, liste des cas limites |
| code-reviewer | v0.1 | Read, Grep, Glob, Bash (`git diff`, `git log`, `flutter analyze`) — aucune écriture | Diff de la branche, exigences liées | Constats priorisés (bloquant / important / mineur) avec fichier:ligne |
| devops-engineer | v0.2 | Read, Grep, Glob, Write limité à `.github/`, Bash (`gh`, `git`, `flutter build`) | Plateformes cibles, état CI | Workflow CI, rapport de build par plateforme |
| product-architect | v0.3 | Read, Write limité à `docs/product/` | Description du besoin | PRD, critères d'acceptation numérotés (AC-xxx) |
| ui-ux-engineer | v0.4 | Read, Write limité à `docs/design/` et `lib/ui/` | PRD, APPFLOW | Spécification UI, états d'erreur, points d'accessibilité |

Les limites d'écriture « par dossier » ne sont pas exprimables dans le frontmatter : elles sont portées par la consigne de l'agent et vérifiées par le reviewer. À vérifier en phase A si une restriction plus fine existe.

Chaque agent termine par un rapport au format fixe : `STATUS` (done / blocked / partial), `FILES_CHANGED`, `COMMANDS_RUN` avec code de sortie, `OPEN_QUESTIONS`.

## Skills

Un skill est un dossier `skills/<nom>/SKILL.md` invoqué par `/dart-multiplatform-forge:<nom>` ou chargé automatiquement quand sa `description` correspond à la demande. La description doit donc dire précisément quand l'utiliser. Chaque skill écrit le checkpoint à chaque étape terminée.

| Skill | Version | Déclencheur | Points de validation obligatoires | Produit |
| --- | --- | --- | --- | --- |
| bootstrap-project | v0.1 | Créer une nouvelle app | Nom, package id, plateformes, périmètre ; approbation du PRD/TRD avant le code | Squelette `flutter create`, Git initialisé, docs socle, test de base vert, `.forge/` |
| create-feature | v0.1 | Ajouter une fonctionnalité | Plan de la feature si périmètre, architecture ou dépendance nouvelle | Branche, tests, code, revue, docs mises à jour, commit préparé |
| git-workflow | v0.1 | Brancher, committer, vérifier un diff | Toute opération hors liste blanche | Branche nommée, commits atomiques, rapport de diff |
| recover-session | v0.1 | Reprendre un travail | Aucune (lecture seule jusqu'au résumé) | Résumé de reprise + prochaine étape proposée |
| github-workflow | v0.2 | Dépôt distant, issue, PR, CI | Création de dépôt, visibilité, fusion, push si non préautorisé | PR avec résumé, risques, tests exécutés |
| debug-project | v0.2 | Erreur de build ou test rouge inattendu | Modification hors du périmètre de l'erreur | Cause identifiée, correctif minimal, test de non-régression |
| update-project | v0.3 | Mettre à jour Flutter ou dépendances | Toute mise à jour majeure ; plan de lots | Branche `chore/deps-*`, rapport avant/après, lockfile |
| adopt-existing-project | v0.3 | Prendre en main un projet existant | Plan de mise en conformité | `.forge/`, docs reconstruites depuis le code, liste des divergences |
| release-project | v0.4 | Préparer une release | Toute publication, tag poussé, signature | Notes de version, builds vérifiés par plateforme |
| optimize-usage | v0.4 | Session longue ou coûteuse | Aucune | Recommandations ; résumé de contexte compact |

Règle commune : un skill ne déclare jamais une étape réussie sans la sortie de la commande correspondante. Après deux échecs identiques d'une même commande, il s'arrête, écrit le checkpoint et expose le blocage au lieu de réessayer.

## Hooks et garde-fous

Les hooks sont déclarés dans `hooks/hooks.json` et exécutent des scripts bash courts, testables avec une entrée JSON simulée. Un hook ne lance jamais la suite de tests complète et n'accorde jamais une permission : il peut seulement bloquer ou compléter.

| Hook | Événement | Filtre | Comportement | En cas d'erreur du script |
| --- | --- | --- | --- | --- |
| guard-destructive | PreToolUse | Bash | Bloque `git reset --hard`, `git clean -f*`, `git push --force` / `-f` / `--force-with-lease`, `git branch -D`, `git checkout -- .`, `rm -rf` hors `build/`, `gh repo delete`, `gh repo edit --visibility`, `gh pr merge`, `flutter pub publish` ; renvoie la raison à Claude | Bloque (fail-closed) |
| format-dart | PostToolUse | Edit, Write | Si le fichier finit par `.dart` et que `dart` est dans le PATH : `dart format <fichier>` | Ignore silencieusement (fail-open) |
| checkpoint-reminder | Stop | — | Si `.forge/checkpoint.md` est plus ancien que le dernier commit ou les fichiers modifiés, rappelle de le mettre à jour | Ignore |
| secret-scan (v0.2) | PreToolUse | Bash contenant `git commit` | `gitleaks protect --staged` si installé, sinon regex sur `git diff --cached` (clés AWS, `-----BEGIN`, `ghp_`, `sk-`, `AIza`, fichiers `.env`, `*.jks`, `key.properties`) | Bloque |
| protect-sensitive (v0.2) | PreToolUse | Edit, Write | Demande confirmation avant modification de `android/key.properties`, `*.keystore`, `ios/Runner/*.entitlements`, `.github/workflows/*`, `.forge/config.yaml` | Bloque |

Le guard-destructive analyse la commande par motifs : il peut être contourné par une formulation exotique. C'est un filet de sécurité, pas une garantie ; les règles `deny` du `settings.json` de projet forment la seconde couche. Toute levée ponctuelle se fait par l'utilisateur, jamais par Claude qui réécrirait la commande.

## Sécurité et permissions

La sécurité repose sur trois couches indépendantes : les règles de permission de Claude Code, les hooks du plugin, et les préautorisations du projet. Un plugin ne peut pas, à ma connaissance, imposer de règles `allow`/`deny` ; il les propose et l'utilisateur les installe (à confirmer en phase A).

**Couche 1 — `templates/project-settings.json`**, copié dans `<projet>/.claude/settings.json` par bootstrap-project après accord :

```json
{
  "permissions": {
    "allow": [
      "Bash(flutter test:*)", "Bash(flutter analyze:*)", "Bash(dart format:*)",
      "Bash(flutter pub get)", "Bash(git status)", "Bash(git diff:*)",
      "Bash(git log:*)", "Bash(git add:*)", "Bash(git switch:*)"
    ],
    "ask": [
      "Bash(git commit:*)", "Bash(git push:*)", "Bash(gh pr create:*)",
      "Bash(flutter pub upgrade:*)"
    ],
    "deny": [
      "Bash(git reset --hard:*)", "Bash(git clean:*)", "Bash(git push --force:*)",
      "Bash(gh repo delete:*)", "Bash(gh pr merge:*)", "Read(./.env)", "Read(./**/key.properties)"
    ]
  }
}
```

**Couche 2 — hooks** (section précédente), actifs dès l'installation du plugin.

**Couche 3 — `<projet>/.forge/config.yaml`**, lu par chaque skill avant une action externe. Toute clé absente vaut `false`. Seul l'utilisateur la modifie ; le hook protect-sensitive bloque son édition par Claude.

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
├── .github/workflows/ci.yml     # (v0.2) format + analyze + test
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
2. **Contexte** : lire PRD, TRD et l'entrée du plan pour la feature ; lister les critères d'acceptation (AC-xxx) visés.
3. **Risques et dépendances** : nouveau package, impact plateforme, migration de données.
4. **Plan** : fichiers touchés, tests prévus, dépendances. **Validation utilisateur** si le périmètre, l'architecture ou une dépendance change.
5. **Branche** : `feature/<ac-id>-<slug>` via git-workflow.
6. **Tests d'abord** : le test-engineer écrit les tests liés aux AC.
7. **ROUGE** : `flutter test <fichiers ciblés>`. L'échec doit porter sur l'assertion attendue, pas sur une erreur de compilation sans rapport. Sortie consignée.
8. **Implémentation minimale** dans la session principale.
9. **VERT** : mêmes tests ciblés, tous passent. Sinon retour à 8, au plus trois itérations avant d'exposer le blocage.
10. **Refactor** sans changement de comportement.
11. **Re-test ciblé** puis, à ce jalon seulement, `flutter test` complet.
12. **Qualité** : `dart format --set-exit-if-changed .` et `flutter analyze` ; zéro erreur, avertissements listés.
13. **Revue** : code-reviewer sur `git diff <base>...HEAD` ; les constats bloquants sont corrigés et relus.
14. **Docs** : plan, DECISIONS et traçabilité mis à jour ; signalement de toute divergence avec le code.
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
| Création de dépôt distant | Accord, toujours re-confirmé | Nom, visibilité, propriétaire affichés avant |
| Fusion, changement de visibilité, suppression, release, tag poussé | Accord explicite à chaque fois | Bloqué aussi par hook |
| `reset --hard`, `clean`, `push --force`, `branch -D` | Interdit sans demande explicite de l'utilisateur | Bloqué par hook et `deny` |

Conventions : branches `feature/`, `fix/`, `chore/deps-`, `docs/` ; commits atomiques (un changement logique, tests compris) ; `.gitignore` Flutter standard plus `.env*`, `*.jks`, `*.keystore`, `key.properties`.

Corps de PR généré par github-workflow : résumé, AC couverts, risques, tests exécutés avec résultats (quatre catégories), plateformes vérifiées, captures si disponibles. Avant toute action GitHub : `gh auth status` ; en cas d'échec, on s'arrête et on explique `gh auth login` sans jamais demander ni afficher de jeton.

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

Coût CI à signaler à l'utilisateur : les minutes GitHub Actions sont gratuites pour les dépôts publics ; pour les dépôts privés, le quota gratuit est limité et les minutes macOS sont décomptées avec un multiplicateur élevé (chiffres exacts à vérifier en phase A).

Règles :

- Aucune annonce de build iOS ou de publication iOS réussie sans log de build, signature et contrôle vérifiés.
- Chaque dépendance ajoutée est vérifiée contre les plateformes activées (onglet « Platform » sur pub.dev) et le résultat noté dans DECISIONS.md.
- Sans KVM, les tests d'intégration se replient sur Linux desktop, et le rapport le dit.

## Stratégie de test du plugin

Les tests se répartissent en deux familles qui ne se mélangent pas : les tests déterministes, qui tournent sans Claude et sans quota, et les scénarios comportementaux, qui nécessitent une session Claude Code et consomment le quota Max.

**Tests déterministes** (`tests/run-all.sh`, bash + `jq`, aucun réseau) :

| Fichier | Vérifie |
| --- | --- |
| static/test\_manifest.sh | `plugin.json` est du JSON valide, champs requis présents, `name` en kebab-case, version SemVer |
| static/test\_frontmatter.sh | Chaque agent et skill a un frontmatter lisible, `name` et `description` non vides ; le reviewer n'a ni Write ni Edit |
| static/test\_paths.sh | Tout chemin cité dans `hooks.json` et les skills existe et passe par `${CLAUDE_PLUGIN_ROOT}` |
| static/test\_settings\_template.sh | Aucune règle `allow` ne couvre push, merge, reset, clean ou suppression |
| hooks/test\_guard\_destructive.sh | \~30 commandes dangereuses bloquées, \~30 commandes sûres autorisées, entrée JSON malformée bloquée |
| hooks/test\_format\_dart.sh | `.dart` formaté, autre fichier ignoré, absence de `dart` sans erreur |
| hooks/test\_checkpoint\_reminder.sh | Rappel émis quand le checkpoint est plus ancien que les fichiers modifiés |
| static/test\_tdd\_skill.sh | `create-feature/SKILL.md` contient les étapes ROUGE et VERT, chacune avec une commande et la consigne de consigner sa sortie |

La CLI fournit peut-être un validateur de plugin intégré ; s'il existe, il est ajouté à `run-all.sh` (phase A).

**Scénarios comportementaux** (`tests/scenarios/*.md`, exécutés en mode headless avec le plugin chargé depuis son dossier, ou à la main) :

1. **Bootstrap** dans un dossier temporaire : projet créé, `flutter test` vert, docs socle en DRAFT, `.forge/` présent.
2. **Feature TDD** : checkpoint montrant ROUGE puis VERT avec sorties de commande.
3. **Préservation** : un fichier modifié non commité avant le lancement est intact après.
4. **Blocage** : demande explicite de `git reset --hard` refusée par le hook avec message clair.
5. **Reprise** : session interrompue après l'étape 7, recover-session propose l'étape 8 sans refaire 1 à 7.
6. **Dépôt existant** : aucun fichier réécrit sans plan validé.

Le rapport de test du plugin sépare trois colonnes : exécuté automatiquement, vérifié manuellement, bloqué (raison). Les scénarios GitHub utilisent un dépôt de test privé jetable, créé uniquement avec accord.

## Points à vérifier en phase A et risques

Ce document a été rédigé sans consulter la documentation de la version installée ; les points ci-dessous doivent être confirmés avant toute implémentation, et le document corrigé en conséquence.

À vérifier contre la doc officielle Claude Code :

- [ ] Champs exacts et obligatoires de `plugin.json` et `marketplace.json`
- [ ] Commandes `/plugin …`, option `--plugin-dir`, existence de `claude plugin validate`
- [ ] Frontmatter des agents : champs supportés, syntaxe de `tools`, possibilité de restreindre Bash par motif
- [ ] Frontmatter des skills et règles de chargement automatique
- [ ] Format de `hooks.json`, noms d'événements, format d'entrée JSON et codes de sortie pour bloquer
- [ ] Disponibilité de `${CLAUDE_PLUGIN_ROOT}` dans les hooks et les skills
- [ ] Un plugin peut-il fournir des règles de permission ? (hypothèse retenue : non)
- [ ] Exécution headless avec un plugin chargé, pour les scénarios

À vérifier côté outils : version Flutter stable courante, sous-commandes `gh` utilisées, quotas GitHub Actions et multiplicateur macOS.

| Risque | Effet | Parade |
| --- | --- | --- |
| Le guard-destructive est contourné par une syntaxe imprévue | Commande destructive exécutée | Deuxième couche `deny` ; tests à motifs larges ; revue du hook à chaque version |
| Les consignes d'écriture « par dossier » des agents ne sont pas respectées | Fichiers modifiés hors périmètre | Le reviewer compare `git diff --name-only` au périmètre déclaré |
| Checkpoint non mis à jour | Reprise sur un état faux | Hook checkpoint-reminder ; recover-session croise avec Git |
| Documentation trop lourde pour un débutant | Abandon du workflow | Socle de quatre documents, optionnels à la demande |
| Coût en quota des agents | Session coupée en plein cycle | TDD en session principale ; agents aux jalons seulement |
| Évolution du format des plugins | Plugin non chargé après mise à jour de Claude Code | Tests statiques en CI ; version minimale documentée dans INSTALLATION.md |
