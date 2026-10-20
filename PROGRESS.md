# PROGRESS — plugin-flutter

Dernière mise à jour : 2026-10-20
Reprise : « Reprends depuis PROGRESS.md » → lire ce fichier, puis `git log --oneline`.

## v0.3 — en cours

Démarrée le 2026-10-20 sur votre demande (« Démarre la v0.3 de plugin-flutter »). Périmètre fixé par ARCHITECTURE.md (feuille de route) : skills update-project et adopt-existing-project, agent product-architect, détection des divergences docs/code. Critère de sortie : la mise à jour réelle d'un lot de dépendances, avec son rapport avant/après. ARCHITECTURE.md repasse en REVIEW pendant le travail.

Point de départ : `main` à `1d8085e`, en avance de 2 commits de suivi sur `origin/main` (`4765671`, `1d8085e`), qui partiront avec la prochaine publication.

Comme pour les versions précédentes, les décisions ci-dessous sont appliquées **par défaut** et restent révisables. D27 à D32 sont vos valeurs par défaut ; D33 et suivantes sont mes recommandations, tirées de la phase A. Seules les actions qui coûtent, touchent un compte ou sortent de la machine attendent votre accord : scénarios headless (F.2), dépôt GitHub et minutes de CI du scénario 12 (F.2), publication de la 0.3.0 (G).

| # | Retenu par défaut |
| --- | --- |
| D27 | Travail sur la branche locale `feat/v0.3`, un commit local par phase ; rien n'est poussé |
| D28 | La détection des divergences est un contrôle de jugement, pas un hook : une étape d'adopt-existing-project, plus une vérification du code-reviewer (dépendance absente de DECISIONS.md, AC sans test, plan périmé) |
| D29 | Pas d'agent implementation-engineer : l'implémentation reste dans la session principale (clôt le « à réévaluer en v0.3 » d'ARCHITECTURE.md) |
| D30 | product-architect : modèle `inherit`, comme flutter-architect ; outils Read, Grep, Glob, Write, Edit, sans Bash ; écriture limitée à `docs/product/` par agent-scope-guard, qui lui refuse aussi toute commande |
| D31 | Sous NixOS, Flutter est fourni par Nix : update-project ne lance jamais `flutter upgrade`. Il le détecte (`flutterRoot` sous `/nix/store/`), le signale, et rappelle de mettre à jour `flutter-version` dans `.github/workflows/ci.yml` après un changement de SDK |
| D32 | Version 0.3.0 (mineure, format de `.forge/` inchangé : la phase A n'a rien trouvé qui l'oblige à changer) |
| D33 | *(extension de D31)* update-project ne lance `flutter upgrade`, `downgrade` ou `channel` **nulle part**, Nix ou non : le SDK est partagé par tous les projets de la machine. L'utilisateur le change lui-même (Nix : sa configuration ; sinon `! flutter upgrade`), puis le skill vérifie. Le gabarit de permissions passe ces trois commandes en `ask` |
| D34 | Lots : le lot 1 réunit les mises à jour compatibles (`flutter pub upgrade`, sans argument : contraintes inchangées, transitives comprises) ; puis un lot par mise à jour majeure (`flutter pub upgrade --major-versions <paquet>`), une famille de paquets ensemble (`riverpod` et `flutter_riverpod`). Chaque lot : `flutter analyze` et `flutter test`, puis un commit `chore(deps): …` avec `pubspec.yaml`, `pubspec.lock` et les registres de plugins régénérés. Point de validation : le plan de lots, toujours, et chaque majeure (lien vers son changelog). Un lot rouge n'est pas commité ; l'abandonner passe par `! git restore pubspec.yaml pubspec.lock`, que guard-destructive refuse à Claude |
| D35 | Rapport avant/après dans `.forge/reports/deps-<date>-<slug>.md`, commité à part après le dernier lot (`docs(deps): …`), puisque ce lot peut être abandonné : versions avant (`flutter pub outdated --json`) et après (`pubspec.lock`), SDK (`flutter --version --machine`), tests et analyse avant (référence) et après chaque lot. Une référence rouge arrête le skill : sans votre accord, on ne met pas à jour sur une base qui échoue déjà |
| D36 | Dans un projet Flutter, les skills et agents citent `flutter pub …`, jamais `dart pub …`, qui échoue sous Nix (exit 69). flutter-architect garde `dart pub deps` dans sa liste blanche, pour un paquet Dart pur |
| D37 | adopt-existing-project, analyse en lecture seule : jamais `flutter analyze`, `flutter test` ou `flutter pub get` nus, qui lancent `pub get` et peuvent réécrire `pubspec.lock`. D'abord `flutter pub get --enforce-lockfile` (refuse sans rien écrire si le lock est périmé ou absent), puis `flutter analyze --no-pub` et `flutter test --no-pub`. `git status --porcelain` identique avant et après, sinon arrêt |
| D38 | adopt-existing-project, mise en conformité : branche `chore/adopt-plugin-flutter` ; un document existant est gardé et référencé, jamais remplacé ; `CLAUDE.md`, `.gitignore`, `analysis_options.yaml` existants : modification proposée en diff, approuvée fichier par fichier ; aucun code déplacé. Documents reconstruits en DRAFT, AC marqués « reconstructed », ADR des dépendances existantes en `proposed`. Divergences dans `.forge/reports/divergences-<date>.md` |
| D39 | product-architect est délégué par adopt-existing-project (PRD reconstruit depuis le code) et par bootstrap-project quand le besoin fourni est long ; create-feature écrit lui-même un AC isolé, moins coûteux |
| D40 | Le code-reviewer rend un bloc `DIVERGENCES` : dépendance ajoutée ou passée à une majeure sans ADR, AC visé sans test ou test citant un AC absent du PRD, entrée du plan contredite par le diff. create-feature (étape 14) le traite avec les mises à jour de docs |
| D41 | Scénarios v0.3 : 6 adoption, 10 mise à jour de dépendances (critère de sortie), 11 tâche `build` de devops-engineer, 12 diagnostic d'une CI rouge (dépôt GitHub et minutes de CI : accord séparé) |
| D42 | *(phase F.2, scénarios 6 et 10)* Le checkpoint est écrit **avant** le commit qui le porte (étapes faites, ce commit annoncé, prochaine action ; `last_commit` nomme le commit précédent) et n'est plus modifié après : l'arbre reste propre et `git switch` fonctionne. checkpoint-reminder se tait quand le dernier commit contient le checkpoint, inchangé depuis ; recover-session ne compte pas ce commit comme une incohérence |

### Phases v0.3

- [x] A — Vérifications (2026-10-20), détail ci-dessous
- [x] B — Agent product-architect et son périmètre dans agent-scope-guard, en TDD
- [x] C — Skill update-project ; règles de permission
- [x] D — Skill adopt-existing-project ; divergences (code-reviewer, create-feature) ; délégation de bootstrap-project ; scénarios 6, 10 à 12
- [x] E — `tests/run-all.sh` vert ; revue indépendante du diff, puis contre-vérification
- [x] F.1 — Validation sans quota (`claude plugin details`, commandes du skill sur projets jetables)
- [ ] F.2 — Scénarios headless, sur accord (coût estimé, compte Claude confirmé)
- [ ] G — Docs, CHANGELOG 0.3.0, `docs/V0.3_REPORT.md` ; ARCHITECTURE.md APPROVED sur votre accord explicite. *Fait avant F.2 : docs, CHANGELOG, 0.3.0, rapport (F.2 en attente).*

### Phase A v0.3 — Vérifications

Projet jetable `flutter create` (Linux) dans le scratchpad, dépendances anciennes figées puis contraintes relâchées : `http 0.13.6`, `equatable 2.0.5`, `shared_preferences 2.2.0`, `go_router 12.0.0`. Rien n'a été lancé dans un vrai projet.

| Point | Résultat | Source |
| --- | --- | --- |
| Suite déterministe avant tout changement | exit 0 — 17 réussis (13 suites, 848 assertions, 4 validations), 0 échoué | `bash tests/run-all.sh` |
| Outils | Claude Code 2.1.296, Flutter 3.44.3 (Dart 3.12.2), gh 2.101.0, jq 1.8.2, bash 5.2.37 | `--version` |
| Flutter fourni par Nix | `flutter --version --machine` : `flutterRoot` = `/nix/store/…-flutter-wrapped-3.44.3-sdk-links`, `frameworkRevision` = `nixpkgs000…`, `frameworkCommitDate` = 1970 ; `flutter` résolu vers le store | `--machine`, `readlink -f` |
| `flutter upgrade` | options `--force`, `--verify-only` ; **non lancé** | `--help` |
| `flutter pub outdated` | exit 0, même avec des paquets en retard. Texte et `--json` ne modifient ni `pubspec.yaml` ni `pubspec.lock` (sha256). Sans `pubspec.yaml` : exit 1 | sonde |
| `flutter pub outdated --json` | `{packages: [{package, kind, isDiscontinued, isCurrentRetracted, isCurrentAffectedByAdvisory, current, upgradable, resolvable, latest}]}`, chaque version `{version}` ou `null` ; `kind` : `direct`, `dev`, `transitive` ; sans `--show-all`, seuls les paquets en retard ; paquets du SDK en `0.0.0` | sonde |
| `flutter pub upgrade` | `-n/--dry-run` : rien de modifié, exit 0. `upgrade <paquet>` ne déplace que lui (ses implémentations fédérées restent verrouillées, sauf `--unlock-transitive`). `--major-versions <paquet>` réécrit sa contrainte dans `pubspec.yaml` (`http: ^0.13.6 -> ^1.6.0`) et le lock. `--tighten` relève les bornes basses. Exit 0 partout | `--help`, sonde |
| `flutter pub deps --json` | exit 0 ; `{root, packages: [{name, version, kind, source, dependencies, directDependencies}], sdks: [{name, version}], executables}` ; `kind` : `root`, `direct`, `dev`, `transitive`. *(Corrigé après la revue : mesuré ici sur un lock à jour seulement. Sur un lock périmé, il **réécrit `pubspec.lock`**, comme `pub get` ; `pub outdated` ne le fait pas.)* | sonde, revue |
| `dart pub …` dans un projet Flutter | **exit 69** : « the Flutter SDK is not available », y compris avec le `dart` du SDK Flutter de Nix | sonde |
| `pubspec.lock` | `packages: <nom>: {dependency: "direct main" \| "direct dev" \| transitive, description: {name, sha256, url}, source, version}`, puis `sdks: {dart, flutter}`. Versionné par `flutter create`, comme `linux/flutter/generated_plugin_registrant.{cc,h}` et `generated_plugins.cmake` | sonde, `git ls-files` |
| Lecture seule d'un dépôt existant | Lock périmé : `flutter analyze`, qui lance `pub get`, **réécrit `pubspec.lock`**. `flutter pub get --enforce-lockfile` : lock périmé → exit 65, rien modifié ; pas de lock → exit 1, rien créé ; lock valide → exit 0, seuls des fichiers ignorés écrits (`.dart_tool/`, `.flutter-plugins-dependencies`, `linux/flutter/ephemeral/`). Ensuite `flutter analyze --no-pub` et `flutter test --no-pub` : exit 0. Sans résolution préalable, `analyze --no-pub` : exit 1 et 55 faux constats | 3 clones jetables |
| Cache pub | `.dart_tool/package_config.json` (`configVersion` 2) : `rootUri` = `file:///…/.pub-cache/hosted/pub.dev/<paquet>-<version>`, où se lisent `CHANGELOG.md` (« **Breaking** » pour http 1.6.0) et `flutter: plugin: platforms:` | sonde |
| Gabarit CI | la version épinglée est la ligne `flutter-version: "<version>"` du job | `templates/github-workflows/flutter-ci.yml` |

Incidents : le secret-scan installé (0.2.0) a refusé `git init … && git commit` sur une même ligne (D25), puis un `cd "$P"` à variable. Non contourné : commandes séparées, chemin écrit en clair.

### Phases B à D v0.3 — TDD

Chaque composant a vu son test échouer pour la bonne raison avant d'exister, puis passer.

| Cycle | ROUGE | VERT |
| --- | --- | --- |
| B1 — périmètre de product-architect (agent-scope-guard) | 4 échecs : agent inconnu, tout refusé, y compris `docs/product/PRD.md` | 148/148 |
| B2 — frontmatter (5 agents) | 2 échecs (agent absent) | 99/99 |
| B3 — contenu de product-architect (`test_maintenance_skills.sh`, nouvelle suite) | 1 échec (fichier absent) | 14/14 |
| B4 — agent doté de commandes mais sans branche de liste blanche | 1 échec : **exit 0**, la commande passait | 149/149 |

B4 vient de la relecture du hook : en bash, un `case` sans branche correspondante renvoie 0, si bien que `command_allowed` autorisait toute commande d'un agent qui n'aurait pas sa branche. Aucun agent existant n'était concerné ; un futur agent l'aurait été. La branche par défaut `*) return 1` avait d'abord été écrite sans test : retirée, test écrit et vu ROUGE sur une copie du hook dotée d'un agent orphelin, puis remise.

Mutations (une règle désactivée dans une copie du plugin, la suite doit échouer) : 7 sur 7 détectées. agent-scope-guard : `docs/product` élargi à `docs` (5 échecs), refus « no shell » retiré (1), branche product-architect retirée (5), branche par défaut retirée (1), `git status` accordé (1), `docs/technical` ajouté (2). Frontmatter : Bash ajouté (1), modèle `sonnet` (1). Une mutation visait par erreur le `*) return 1` de `git_read_only` (même texte) : détectée aussi (4), puis refaite sur la bonne ligne.

Suite complète : exit 0 — 18 réussis (14 suites, 888 assertions, 4 validations).

| Cycle | ROUGE | VERT |
| --- | --- | --- |
| C1 — contenu d'update-project et de son gabarit de rapport | 2 échecs (fichiers absents) | 62/62 |
| C2 — frontmatter (7 skills) | 2 échecs | 107/107 |
| C3 — gabarit de rapport cité et présent (`test_paths`) | 1 échec | 95/95 |
| C4 — règles : `pub outdated`, `pub deps`, `pub get --enforce-lockfile`, `--version --machine` en `allow` ; `flutter upgrade`, `downgrade`, `channel` en `ask` | 2 échecs | 22/22 |

Deux tests existants ont accroché à tort, et ont été resserrés plutôt que contournés :

- `test_paths` refusait toute chaîne `/nix/store/`, que le skill cite comme motif de détection. Il vise désormais un vrai chemin du store, `/nix/store/<hash de 32 caractères>-`. Mutation : un chemin réel ajouté au skill → 1 échec.
- `test_settings_template` lisait `force` dans `--enforce-lockfile`. Motif `\bforce`. Mutations : `allow` sur `git push --force-with-lease *`, `flutter pub upgrade --force *`, `git checkout --force *` → 1, 2 et 1 échecs.

Suite complète : exit 0 — 18 réussis (14 suites, 951 assertions, 4 validations).

| Cycle | ROUGE | VERT |
| --- | --- | --- |
| D1 — contenu d'adopt-existing-project et de sa grille de divergences | 2 échecs (fichiers absents) | 117/117 |
| D2 — DIVERGENCES : code-reviewer (5 assertions), create-feature étape 14, debug-project | 7 échecs | idem |
| D3 — délégation de bootstrap-project à product-architect ; flutter-architect : `flutter pub deps`, stack « pre-existing » (D36, D39) | 3 échecs | idem |
| D4 — frontmatter (8 skills) ; grille citée et présente (`test_paths`) | 2 + 1 échecs | 115/115, 99/99 |

Le contrôle « avant le plan, `flutter analyze`, `test` et `pub get` seulement avec `--no-pub` ou `--enforce-lockfile` » a d'abord attrapé la consigne qui les interdit (« never run `flutter pub get` … without … ») : les lignes « never » sont écartées, comme dans les contrôles `dart pub` et `flutter upgrade`. Mutations : chacune des trois commandes de référence rendue nue → 1, 1 et 2 échecs.

Scénarios ajoutés : 6 (adoption), 10 (mise à jour, critère de sortie), 11 (builds), 12 (CI rouge). Leurs préparations séparent `git init` et écrivent le chemin en clair, à cause de secret-scan (README des scénarios, « Observed »).

Suite complète : exit 0 — 18 réussis (14 suites, 1 018 assertions, 4 validations).

### Phase E v0.3 — Revue indépendante

Un sous-agent relecteur, sans l'historique de cette session, a relu `main..50ccdb3` avec le périmètre et D27–D41 pour exigences. Il a rejoué les commandes des skills sur des projets Flutter jetables et le hook sur des entrées non testées. Verdict : « avec corrections », aucun constat critique, 10 importants, 12 mineurs. Chaque constat retenu a d'abord été reproduit par un test ROUGE (31 échecs dans `test_maintenance_skills` et `test_settings_template`), puis corrigé.

| Constat | Vérification | Traitement |
| --- | --- | --- |
| **I1** `flutter pub deps`, cité à flutter-architect pendant l'adoption, réécrit un lock périmé | reproduit : exit 0, `sha256sum -c` → FAILED, ` M pubspec.lock` | La règle « pas de pub get » le nomme ; flutter-architect ne le lance que sur un lock à jour, ce que la session lui dit ; ligne de phase A corrigée |
| **I2** `.forge/config.yaml` : protect-sensitive demande confirmation, refusée en `-p`, sans repli | lu dans le hook | Commande `! mkdir -p .forge && sed … > .forge/config.yaml` donnée à l'utilisateur, dans adopt **et** bootstrap (trou présent depuis la v0.2) ; scénario 6 complété |
| **I3** l'adoption reste sur sa branche ; les autres skills partent de la branche principale | lu | Prochaine étape : PR (`github-workflow pr`) ou fusion locale par l'utilisateur ; « The merge is the user's » |
| **I4** chemin « pas de dépôt » cassé (`git status` exit 128, `main` jamais né) | reproduit par le relecteur | Arrêt : le premier commit d'un arbre existant revient à l'utilisateur |
| **I5** un lot majeur abandonné laissait le code migré | lu | Tous les fichiers du lot sont restaurés, puis analyse et tests comparés à la référence |
| **I6** le « après » du rapport venait de `pub outdated --json`, qui omet les paquets à jour ; `--stat` comptait des lignes | reproduit par le relecteur | `--json --show-all` ; transitifs comptés par lignes `version:` |
| **I7** adoption contraire à git-workflow (branche de départ, modifications non commitées, nom de branche) | lu | Arrêt sur toute modification ; branche principale par `origin/HEAD`, confirmée dans le plan ; `chore/adopt-plugin-flutter` et `chore/ci` ajoutées à git-workflow |
| **I8** adoption interrompue impossible à reprendre | lu | Reprise depuis le checkpoint, qui liste les items approuvés |
| **I9** trois contrôles négatifs contournables | reproduit : 3 mutations du relecteur, 0 échec | Phrases d'interdiction retirées mot pour mot (`only_in`), puis plus rien ne doit rester. Mutations : 5 sur 5 détectées |
| **I10** version, docs utilisateur, scénario 10 non faits | — | Prévu en F.2 et G : non traité ici |

Mineurs traités : resynchronisation d'un lock périmé (commit à part, sur la branche) ; commande du lot « signalé » ; checkpoint exempté du contrôle des fichiers d'un lot ; `Bash(git status *)` en `allow` ; `Bash(flutter pub upgrade)` en `ask` ; fichiers non suivis (golden en échec) détectés par `--untracked-files=all`, aussi pour vérifier le travail d'un agent ; create-feature : un changement du PRD ou du TRD est un point de validation ; résultats d'analyse et de tests par lot dans le rapport ; méthode pour un paquet retenu (`flutter pub add --dry-run '<paquet>:^<latest>'`, exit 65, aucun fichier modifié, vérifié) ; `dart format` après un changement de SDK ; scénario 10 (le checkpoint change au tour 1) ; argument « paquets » du skill.

Écarté par le relecteur, et maintenu hors périmètre : le comportement réel du modèle (F.2), la sémantique de `Bash(x *)` sur un `x` nu en 2.1.296 (non vérifiable sans session ; les deux formes sont désormais listées pour `flutter pub upgrade`), le contournement par lien symbolique d'agent-scope-guard (antérieur, dans SECURITY.md).

Suite complète : exit 0 — 18 réussis (14 suites, 1 046 assertions, 4 validations).

**Contre-vérification** de `d799064` par le même relecteur : 8 constats sur 9 résolus (I1 à I7, I9, plusieurs revérifiés par rejeu), I8 en partie, I10 ouvert comme prévu ; aucune régression des hooks ni du gabarit. Elle trouve 2 importants et 9 mineurs. Les deux trous de tests ont été reproduits avant correction (mutations M4, M5 et `allow` sur `flutter pub add --dev *` : 0 échec), le `sed` aussi (branche `release/2.x` : exit 1 et un `.forge/config.yaml` de 0 octet). 17 tests ROUGES, puis corrections :

| Constat | Traitement |
| --- | --- |
| **Important** : après une adoption, `github-workflow pr` exige format et analyse à exit 0 et lance un `flutter analyze` nu, qui réécrirait un lock périmé | La référence d'adoption mesure aussi `dart format --output=none`. La PR par github-workflow seulement « when the baseline was clean » ; sinon PR ou fusion locale par l'utilisateur |
| **Important** : une adoption reprise n'a plus la référence de l'étape 2, et l'attente sur `.forge/config.yaml` précédait le checkpoint | Le checkpoint est écrit avant `.forge/config.yaml`, avec la référence (dont l'exit de `--enforce-lockfile`) |
| `sed` cassé par une branche contenant `/` | Délimiteur `\|` dans adopt, bootstrap **et** le `sed` du CI de github-workflow (même défaut depuis la v0.2) |
| Commandes de bootstrap relatives au dossier de session, fausses pour un projet en sous-dossier | `<directory>/.forge/…` et `<directory>/.claude/…` (le second date de la v0.1) |
| Lock resynchronisé : branche recréée à l'étape 6, registres oubliés, commit compté dans le rapport | « unless step 3 already created it » ; registres dans le commit de synchro ; rapport à partir de ce commit |
| Paquets nommés : le lot compatible les déplaçait tous | `flutter pub upgrade <package> [<package>]` |
| Transitifs comptés par ligne (`-`/`+` doublés) | Par paquet dont la `version:` change |
| Test : `pub add --dev` passait ; exclusion morte (préfixe `12:` de `grep -n`) | La règle exacte du dry-run est retirée d'abord, tout autre `pub add` est refusé |
| Test : phrases épinglées réduites à des fragments, fin de phrase inversable | Phrases entières, jusqu'au point |
| `git rev-parse --abbrev-ref origin/HEAD` imprime `origin/HEAD` en échec | « only exit 0 counts » |
| SDK comparé au format de la référence, jamais mesuré | `dart format --output=none --set-exit-if-changed .` dans la référence d'update-project |

Mutations après correction : 5 sur 5 détectées (M4, M5, délimiteur `sed` remis à `/`, config écrite avant le checkpoint, `allow` sur `pub add --dev`). Écarté par le relecteur : `flutter pub deps` à l'étape 2 de debug-project (antérieur à la v0.3, hors adoption). Pas de troisième passe de revue, comme pour la v0.2. `docs/TROUBLESHOOTING.md` et `docs/INSTALLATION.md` citent encore l'ancienne commande `.claude/` : phase G.

Suite complète : exit 0 — 18 réussis (14 suites, 1 061 assertions, 4 validations).

### Phase F.1 v0.3 — Validation sans quota

| Commande | Résultat |
| --- | --- |
| `bash tests/run-all.sh` | exit 0 — 18 réussis (14 suites, 1 061 assertions, 4 validations), 0 échoué |
| `claude --plugin-dir . plugin details plugin-flutter` | exit 0 — 8 skills, 5 agents, hooks sur 3 événements ; ~1 651 jetons permanents (v0.2 : ~1 236) ; à l'invocation, update-project et adopt-existing-project ~4,7 k chacun |
| Préparations des scénarios 6 et 10, telles qu'écrites, sur Flutter 3.44.3 | `flutter create`, `pub add`/`pub get`, commit : exit 0 ; `flutter test` exit 0 (2 tests) et `flutter analyze` exit 0 pour le 10 |
| Référence d'adopt-existing-project sur un clone neuf du projet du scénario 6 | `flutter --version --machine`, `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub` : exit 0 ×4 ; `git status --porcelain` vide avant et après ; seuls `.dart_tool/` et `build/`, ignorés, apparaissent |
| Commandes d'update-project (phase A, puis rejouées par le relecteur) | classes du scénario 10 conformes ; `pub upgrade` ne change que le lock ; `--major-versions http` que sa contrainte et le lock ; abandon d'un lot (restauration puis `--enforce-lockfile`) → exit 0 ; `pub add --dry-run` sur un paquet retenu → exit 65, cause nommée, aucun fichier modifié |
| `sed` donnés à l'utilisateur pour `.forge/config.yaml` | délimiteur `\|` : seules les lignes `default_branch` et `enabled` changent, y compris avec `release/2.x` |

Non vérifiable sans session : le comportement du modèle face aux nouveaux skills, et la correspondance de `Bash(x *)` avec un `x` nu en 2.1.296 : phase F.2.

### Phase G v0.3 — Docs (avant F.2)

Faite sur « continue » sans réponse aux questions de F.2 : la partie locale et gratuite, sans quota ni compte. F.2 reste en attente.

TDD : `tests/static/test_docs.sh` écrit d'abord. Il vérifie que la version de README et la dernière entrée du CHANGELOG sont celles de `plugin.json`. Il vérifie aussi que les nombres de skills et d'agents sont exacts partout où ils sont écrits (en chiffres ou en lettres), que chaque skill a sa ligne dans le README et sa section dans le guide, que chaque agent a sa ligne dans les deux, et que chaque règle Bash du gabarit est citée par SECURITY.md sous son niveau.

| Étape | Résultat |
| --- | --- |
| ROUGE, docs v0.2 | 12 échecs : composants v0.3 absents, « quatre agents » ×3, « 6 skills, 4 agents », 5 règles `allow` et 3 `ask` non documentées, et `git push -f` refusé sans être nommé (défaut antérieur) |
| ROUGE, `plugin.json` en 0.3.0 | 2 échecs de plus (README, CHANGELOG) |
| VERT | 34 sur 34 après README, USER_GUIDE (update-project, adopt-existing-project, divergences, product-architect), SECURITY, INSTALLATION (règles à ajouter à un projet v0.2, commandes de repli `<projet>/…`), TROUBLESHOOTING (5 entrées), CHANGELOG 0.3.0 |
| Mutations sur copies | 8 sur 8 détectées, témoin vert : ligne d'agent retirée du README, « quatre agents », « 6 skills », `flutter channel` retiré de SECURITY, règle `allow` ajoutée au gabarit, neuvième skill, section du guide renommée, entrée CHANGELOG retirée |
| `bash tests/run-all.sh` | exit 0 — 19 réussis (15 suites, 1 095 assertions, 4 validations), 0 échoué |

`plugin.json` passe en 0.3.0 (description : adoption, mises à jour ; mot-clé `dependencies`). `docs/V0.3_REPORT.md` est écrit, ses lignes F.2 « en attente ». Restent pour la clôture : F.2, le rapport complété, ARCHITECTURE.md en APPROVED sur accord explicite, la publication.

## v0.2 — clôturée et publiée le 2026-10-20

**v0.2.0 clôturée le 2026-10-20** (« clôture et publie ») : phases A à G faites, rapport dans `docs/V0.2_REPORT.md`, ARCHITECTURE.md en APPROVED, tag local `v0.2.0`. `feat/v0.2` est fusionnée en avance rapide dans `main` et publiée sur `soonlysoul/plugin-flutter` : un appareil la reçoit par `claude plugin marketplace update soon`, puis `claude plugin update plugin-flutter@soon`. Le tag `v0.2.0` est poussé, et cette machine a remplacé `flutter-forge@soon` 0.1.1 par `plugin-flutter@soon` 0.2.0 (portée `user`). Le dépôt de test `soonlysoul/plugin-flutter-ci-probe` a été supprimé par l'utilisateur le 2026-10-20 (guard-destructive bloque `gh repo delete` pour Claude) ; le jeton de `gh` porte depuis le scope `delete_repo`. Plus rien n'est en attente pour la v0.2. Prochaine étape : la v0.3 (update-project, adopt-existing-project, product-architect), qui ne démarre que sur votre demande.

Démarrée le 2026-10-20 sur « continue V2 ». Périmètre fixé par ARCHITECTURE.md (feuille de route) : skills github-workflow et debug-project, agent devops-engineer, hooks secret-scan et protect-sensitive, gabarit CI Flutter. Critère de sortie : une PR ouverte sur un dépôt de test, avec une CI verte.

Comme pour la v0.1, les décisions ci-dessous sont appliquées **par défaut** et restent révisables. Seules les actions qui sortent de la machine ou consomment du quota attendent votre accord : création du dépôt de test GitHub (phase F.2), scénarios headless (F.2), publication de la 0.2.0 (G).

| # | Retenu par défaut |
| --- | --- |
| D12 | Travail sur la branche locale `feat/v0.2`, un commit local par phase ; rien n'est poussé avant la publication |
| D13 | *(corrigée après la revue, I2)* secret-scan lit toujours l'index (`git diff --cached`, valable avant le premier commit). Il lit aussi ce que le commit peut prendre d'autre, et seulement cela : les modifications non indexées pour `-a` (tout l'arbre), pour un chemin nommé ou `-i`/`-o` (ce chemin) ; les modifications et les fichiers non suivis désignés par un `git add`/`git stage` de la même ligne (ses chemins, résolus depuis son dossier ; tout l'arbre pour `-A`, `--pathspec-from-file` ou un chemin à variable). Un fichier non suivi n'est jamais lu pour `-a`. Un seul diff global, puis lecture fichier par fichier seulement s'il contient un motif (800 fichiers : 0,1 s) |
| D14 | Détection : noms de fichiers (`.env`, `.env.*` sauf `.example`/`.sample`/`.template`, `*.jks`, `*.keystore`, `key.properties`) et motifs sur les **lignes ajoutées** seulement : `-----BEGIN … PRIVATE KEY` (un certificat public passe), clés AWS, `gh[pousr]_…` et `github_pat_…`, `sk-` précédé d'une frontière et suivi d'au moins 20 caractères (`task-…` passe), `AIza…`. Le secret n'est jamais affiché. gitleaks, s'il est installé, s'ajoute aux motifs (`gitleaks git --pre-commit --staged`, forme 8.19+ ; `protect` est dépréciée) sans les remplacer : il ne regarde pas les noms de fichiers. Le plugin ne l'installe pas. Un faux positif se lève par l'utilisateur (`! git commit …`) |
| D15 | protect-sensitive répond `ask` (JSON, exit 0), pas exit 2 : l'utilisateur confirme dans l'invite ; en `-p`, l'appel est refusé et Claude lit la raison (doc vérifiée). Inerte hors d'un projet ayant `.forge/`, sauf pour un `.forge/config.yaml`, protégé partout. Liste : celle d'ARCHITECTURE.md, élargie à tout `key.properties`, `*.jks` et tout `*.entitlements` (iOS comme macOS) |
| D16 | devops-engineer : `sonnet` ; écriture sous `.github/` seulement ; Bash en lecture : `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status`, `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, git en lecture et `git remote -v`. Il ne pousse pas, n'ouvre pas de PR, ne relance pas de CI : ces actions restent dans la session principale, derrière un point de validation |
| D17 | Le fichier CI est écrit par la session principale depuis le gabarit (copie courte, protect-sensitive demande confirmation). devops-engineer sert aux builds par plateforme et au diagnostic d'une CI rouge, dont les journaux sont longs. Actions épinglées par SHA : `actions/checkout` v7.0.1, `subosito/flutter-action` v2.23.0 ; `flutter-version` fixée à la version locale |
| D18 | `project-settings.json` : `allow` pour les `gh` en lecture (`auth status`, `pr view`, `pr checks`, `run list`, `run view`) ; `ask` pour `gh repo create`, `gh pr edit`, `gh issue create`, `gh run rerun`, `gh workflow run` |
| D19 | debug-project écrit lui-même le test de non-régression (le contexte du bug est dans la session) ; le code-reviewer relit le correctif |
| D20 | Pas de champ `if` dans `hooks.json` : `Bash(git commit *)` ne voit pas `git -C x commit`, et le script écarte une commande sans `commit` avant même de lancer `jq` |
| D21 | Version 0.2.0 (mineure : skills et agent ajoutés, format de `.forge/` inchangé) |
| D22 | secret-scan agit dans **tout** dépôt, comme guard-destructive : un secret commité est un problème partout. Un faux positif ailleurs se lève de la même façon (`! git commit …`) |
| D23 | Avec un dépôt distant, la CI s'ajoute sur une branche `chore/ci` et passe par sa PR, puisque Claude ne pousse jamais la branche principale après sa publication initiale ; sans dépôt distant, elle se commite sur la branche principale, publiée ensuite par `remote`. Trou trouvé en écrivant le scénario 9 |
| D24 | *(revue, I3)* Les clés Google des fichiers de configuration Firebase (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) passent : elles sont faites pour être livrées avec l'app. Seule la règle Google est levée pour ces trois noms, y compris la règle `gcp-api-key` de gitleaks ; les autres motifs s'y appliquent. Le message de blocage demande de consulter l'utilisateur avant de déplacer quoi que ce soit |
| D25 | *(revue, C1 et I1)* secret-scan refuse ce qu'il ne peut pas vérifier avant son exécution : `git init` ou `git clone`, `git add -f` et `git apply --cached`/`--index` sur la même ligne qu'un commit. Le message demande de lancer ces commandes à part. Un dossier créé sur la ligne (`mkdir x && cd x && git commit`) est rattaché au dépôt de son plus proche parent existant ; un `cd` dans un sous-shell `( … )` fait aussi lire le dépôt de départ |
| D26 | *(contre-vérification)* Ce que le hook ne peut pas résoudre élargit la lecture au lieu de la restreindre : `git add` sans chemin (fourni par `xargs`), chemin à variable, à accolades. Le texte même de la commande est analysé |

### Phases v0.2

- [x] A — Vérifications (2026-10-20), détail ci-dessous
- [x] B — Refactor : préfixes de commande partagés par les gardes (`shell-lexer.sh`), à tests verts (`31d8d51`)
- [x] C — Hooks secret-scan et protect-sensitive, en TDD (`5c589a3`)
- [x] D — Agent devops-engineer et son périmètre ; skills github-workflow et debug-project ; gabarits CI et corps de PR ; règles de permission (`d518169`, `7eebd3d`)
- [x] E — `tests/run-all.sh` vert ; revue indépendante du diff, constats traités
- [x] F.1 — Validation sans quota (gitleaks réel par `nix shell`, `plugin details`, CI rejouée localement)
- [x] F.2 — Dépôt de test GitHub, PR et CI verte ; scénarios headless (accord du 2026-10-20 : dépôt de test, compte Claude demeusy.vincent) — **critère de sortie atteint**
- [x] G — Docs, CHANGELOG 0.2.0, ARCHITECTURE.md APPROVED, rapport `docs/V0.2_REPORT.md` ; publication sur votre accord du 2026-10-20

### Phase A v0.2 — Vérifications

| Point | Résultat | Source |
| --- | --- | --- |
| Suite déterministe avant tout changement | exit 0 — 13 réussis (9 suites, 4 validations), 0 échoué | `bash tests/run-all.sh` |
| Outils | Claude Code 2.1.296, gh 2.101.0 (compte `soonlysoul`, scopes `repo`, `workflow`), Flutter 3.44.3, jq 1.8.2, bash 5.2.37 ; gitleaks absent | `--version`, `gh auth status` |
| `permissionDecision: "ask"` d'un PreToolUse | invite l'utilisateur, étiquetée `[plugin:<nom>]`, y compris en mode auto ; en `-p`, refus et raison transmise à Claude ; précédence `deny` > `defer` > `ask` > `allow` ; un exit 2 l'emporte sur tout JSON | doc Hooks, « PreToolUse decision control » |
| Sous-agent en arrière-plan | ses invites de permission remontent dans la session principale | doc Subagents |
| Champ `if` des hooks | une seule règle de permission ; chaque sous-commande est testée | doc Hooks |
| gitleaks | 8.30.1 dans nixpkgs ; sous-commandes `git`, `dir`, `stdin` ; `git --pre-commit --staged` ; `--redact`, `--exit-code`, `--report-format json --report-path -` | `nix shell nixpkgs#gitleaks -c gitleaks …` (non installé) |
| Actions GitHub | `actions/checkout` v7.0.1 = `3d3c42e5aac5ba805825da76410c181273ba90b1` ; `subosito/flutter-action` v2.23.0 = `1a449444c387b1966244ae4d4f8c696479add0b2` ; entrées `channel`, `flutter-version`, `cache` | `gh api repos/…/releases/latest`, `…/git/ref/tags/…` |
| `gh` | `pr create --base --head --title --body-file -` ; sans `--head`, `pr create` veut pousser la branche ; `pr checks` sort en 8 si des checks sont en attente ; `run view --log-failed` ; `repo create --private\|--public --source --remote` | `gh … --help` |
| git avant le premier commit | `git diff --cached` exit 0 ; `git diff HEAD` exit 128 | sonde dans le scratchpad |

Incident : le garde-fou du plugin installé ici (`flutter-forge` 0.1.1, ancien nom) a bloqué un `rm -rf` sur le dossier de sonde. Non contourné : un dossier neuf (`mktemp -d`) a suffi.

### Phases B à D — TDD

Chaque composant a vu son test échouer pour la bonne raison avant d'exister, puis passer.

| Cycle | ROUGE | VERT |
| --- | --- | --- |
| B — `sw_program` dans `shell-lexer.sh` | (refactor) 206 assertions du guard vertes avant et après | 206/206 |
| C1 — secret-scan | 62 échecs, script absent (exit 127) | 64/64 |
| C2 — protect-sensitive, câblage `hooks.json` | 26 + 3 échecs | 26/26, 85/85 |
| D1 — périmètre devops-engineer | 20 échecs (agent inconnu, tout refusé) | 116/116 |
| D2 — frontmatter (4 agents, 6 skills) | 5 échecs | 90/90 |
| D3 — gabarit CI, règles `gh`, contenu des skills | 1 + 2 + 3 échecs (fichiers absents) | 23, 19, 51 |

Mutations (une règle désactivée dans une copie du plugin, la suite doit échouer) : secret-scan, 4 mutations détectées sur 4 (5, 16, 6, 2 échecs) ; protect-sensitive, 3 sur 3 (3, 11, 2).

Deux tests corrigés, pas le code : le marqueur `__FLUTTER_VERSION__` compté aussi dans un commentaire ; l'ordre de tri des skills, qui dépendait de la locale (`LC_ALL=C sort`).

### Phase E — Revue indépendante

Un sous-agent relecteur, sans l'historique de cette session, a relu `55df72c..7eebd3d` et rejoué lui-même les hooks sur des dépôts jetables et le vrai gitleaks. Verdict : « avec corrections ». Chaque constat de comportement a d'abord été reproduit par un test ROUGE sur le code d'alors (24 échecs pour secret-scan, 9 pour agent-scope-guard, 5 pour protect-sensitive), puis corrigé.

| Constat | Traitement |
| --- | --- |
| **C1** fail-open : `git init && git add . && git commit` ; `mkdir x && cd x && git commit` ; `cd` dans un sous-shell | Corrigé (D25) |
| **I1** `git add -f <ignoré> && git commit` non vu | Corrigé : refusé, à lancer à part (D25) |
| **I2** faux positifs : fichiers non suivis lus pour `-a`, tout l'arbre lu pour `git add <un fichier>` ; D13 elle-même était fausse | Corrigé, D13 réécrite |
| **I3** configuration Firebase bloquée (`AIza`), y compris par gitleaks | Corrigé (D24) |
| **I4** devops-engineer pouvait afficher le jeton : `gh auth status -at`, `--show-token=true` | Corrigé : seules les formes exactes passent |
| M1 durée : 3 processus par fichier, ~3 000 fichiers dépassaient le délai | Corrigé : un diff global ; 800 fichiers en 0,1 s |
| M2 `grep`/`awk` absents : fail-open | Corrigé, testé ; le test vise le message propre, après une mutation non détectée |
| M3 attribut `-diff` qui masquait un contenu | Corrigé : `--text --no-textconv` |
| M4 `git apply --cached` sur la ligne | Corrigé : refusé |
| M5 protect-sensitive prenait la racine de session ; `.github/actions/` absent | Corrigé : racine cherchée depuis le fichier ; actions couvertes |
| M6 `flutter build -o/x`, `--split-debug-info`, `--web` | Corrigé. `git remote -v` qui afficherait un jeton dans l'URL : non traité, l'agent peut lire `.git/config` de toute façon |
| M7 `flutter analyze` bloquant par défaut en CI, « avertissements listés » en local | Corrigé : exit 0 exigé dans create-feature, bootstrap-project, debug-project, github-workflow |
| M8 commandes des nouveaux workflows absentes du gabarit de permissions | Corrigé : 16 règles `allow` en lecture ou locales |
| M9 flux : branche du commit CI, coût de chaque PR et de chaque push, exception de git-workflow | Corrigé (D23, textes) |
| M10 `*.p12`, `*.pfx` | Ajoutés aux deux hooks |
| M11 gitleaks antérieur à 8.19 | Le message nomme la version minimale |
| M12 tests manquants | Ajoutés (`--git-dir`, `pushd`, `-i`, `-o`, `--pathspec-from-file`, `git stage`, durée) |

Écarté par le relecteur, et maintenu hors périmètre : Windows et PowerShell natif, alias git, commits faits sans `git commit` (merge, rebase, am…), secrets dans le message de commit, écritures sensibles par Bash, lenteur de l'analyseur v0.1 sur des heredocs de plus de 300 Ko.

Mutations après correction : 7 sur 7 détectées (refus, portée, Firebase, sous-shell, dossier parent, outils requis, gitleaks sur l'arbre).

**Contre-vérification** de `4e66ad9` par le même relecteur : tous les constats initiaux tiennent, les commits ordinaires passent en silence (heredoc de message, `-am` avec un `.env` non suivi, sous-dossier, `git -C`). Elle trouve 5 défauts importants, dont 3 régressions de la réécriture, reproduits par 11 tests ROUGE puis corrigés :

| Constat | Traitement |
| --- | --- |
| Régression : `… \| xargs git add && git commit` (pas de chemin visible) | Un `git add` sans chemin vaut tout l'arbre |
| Régression : accolades `git add lib/{a,b}.dart` | Un chemin à accolades élargit à tout l'arbre |
| `cd sub && git add -A` ne lisait pas les fichiers non suivis hors de `sub` | Portée « tout l'arbre » = pathspec `:/` |
| Régression : gitleaks ne lisait plus `git add <fichier> && git commit` | gitleaks relancé sur l'arbre, ses constats filtrés sur les fichiers de la portée |
| Sous-shell : l'indexation n'était pas relue dans le dossier de départ | Chaque dossier visité par la ligne est relu, pour les commits comme pour l'indexation |
| Mineur : secret écrit par la ligne elle-même (`printf … > f && git add f && git commit`) | Le texte de la commande est lui aussi analysé |
| Mineur : avertissement « ignored null byte » sur un binaire | Octets NUL retirés du diff |
| Mineur : une clé parmi 3 000 fichiers relisait tout (14,9 s) | `git grep` restreint les fichiers à relire : 1,7 s |
| Mineur : `-w` (= `--web`), `--code-size-directory` | Refusés pour devops-engineer (`-w` reste permis pour `gh run list`, où il vaut `--workflow`) |
| Mineur : boucle infinie sur un dossier relatif | Corrigée |

Non traité : avec `--text`, une chaîne d'un binaire commité (bibliothèque native embarquée) peut ressembler à une clé ; c'est écrit dans SECURITY.md, et le blocage se lève par `!`. Mutations : 7 sur 7 détectées. Pas de troisième passe de revue.

### Phase F.1 — Validation sans quota

| Commande | Résultat |
| --- | --- |
| `bash tests/run-all.sh` | exit 0 — 17 réussis (13 suites, 843 assertions après la contre-vérification, 4 validations), 0 échoué |
| secret-scan avec le vrai gitleaks 8.30.1 (`nix shell nixpkgs#gitleaks`) | jeton Slack bloqué : `slack.dart:1: gitleaks rule slack-bot-token`, secret non affiché ; index propre accepté. Sans gitleaks, ce jeton passe : limite écrite dans SECURITY.md |
| `claude --plugin-dir . plugin details plugin-flutter` | 6 skills, 4 agents, hooks sur 3 événements ; ~1 236 jetons permanents (v0.1 : ~848) |
| Gabarit CI sur un projet `flutter create` jetable, Flutter 3.44.3 | `pub get`, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` : exit 0 ×4 |
| `actionlint` 1.7.12 (`nix shell nixpkgs#actionlint`) sur le workflow rempli | exit 0, aucune remarque |
| Flutter 3.44.3 parmi les versions stables publiées | oui (`releases_linux.json`) : la CI peut l'épingler |

### Phase F.2 — Scénarios réels (accord du 2026-10-20)

Accord : « continue dépôt github test sur compte demeusy.vincent ». Sessions headless sur `~/.claude` (compte Claude demeusy.vincent, celui de l'accord) ; dépôt de test sur le seul compte GitHub connecté à `gh`, `soonlysoul`, en **privé** (recommandation appliquée, aucune visibilité précisée). `~/.claude.json` copié avant : 36 projets avant comme après.

| Scénario | Tours | Résultat | Coût (API) |
| --- | --- | --- | --- |
| 7 Secret | 1 | **réussi** : un seul `git commit`, refusé par secret-scan ; aucune nouvelle tentative ; la clé n'apparaît dans aucun texte de Claude ; fichier nommé, désindexation proposée, choix laissé à l'utilisateur | 0,21 $ |
| 8 Débogage | 3 (dont un essai à vide) | **réussi après correction** : 1er essai arrêté proprement — `flutter test … \| tail -40` refusé en `dontAsk`, sans contournement ni correctif. Consigne « une commande par appel » ajoutée aux deux skills (TDD), puis session neuve : ROUGE, cause à l'étape 4 du checkpoint avant toute modification, test existant gardé comme test de non-régression, branche `fix/discount-percentage`, VERT, suite complète, format, analyse, code-reviewer (0 bloquant), commit `fix(pricing): …` avec cause racine ; `lib/main.dart` intact | 1,40 $ |
| 9 PR et CI | 7 | **réussi, critère de sortie de la v0.2 atteint** : `ci` sans dépôt distant → validation avec coût → écriture du workflow refusée par protect-sensitive en `-p`, commande `sed` donnée sans contournement, lancée par l'utilisateur → vérifications locales, commit sur `main`. `remote` → validation (propriétaire, nom, visibilité) → `gh repo create … --private --source . --remote origin` sans `--push`. Les `git push` de Claude sont refusés par la règle `ask` de `~/.claude/settings.json`, sans contournement : poussés par l'utilisateur. CI sur `main` verte en 1 min 56 ; PR #1 `docs/readme` → `main` ouverte avec `--head` et un heredoc cité ; checks verts en 51 s (`gh pr checks 1` exit 0) ; rien de fusionné ; aucun jeton dans les transcriptions | 2,81 $ |

Total : environ 4,42 $ en équivalent API, sur le quota de l'abonnement. Dépôt de test : https://github.com/soonlysoul/plugin-flutter-ci-probe (privé), **à supprimer par vous** (`gh repo delete` est bloqué par guard-destructive).

Défauts trouvés par F.2 et corrigés (tests ROUGE puis VERT) :

- **Commande composée** (`… | tail`) : refusée en `-p`, et soumise à invite en interactif par les règles du projet. Consigne « une commande par appel » dans debug-project et github-workflow.
- **Checkpoint hors du commit de debug-project** : l'étape 11 l'inclut désormais, comme create-feature.
- **Commentaire du gabarit CI** : il citait les marqueurs, que la copie remplaçait aussi ; il ne les cite plus.
- **Plateforme dite « testée » par `flutter test`** dans le corps de PR : github-workflow précise que `flutter test` tourne sur la VM Dart de l'hôte et ne teste aucune plateforme.

Constats sur la 2.1.296 : les sessions chargent aussi l'ancien `flutter-forge` 0.1.1 installé sur cette machine, et `plugin-dev`, `superpowers` ; le modèle des sessions headless était Sonnet 5.5. GitHub annonce la migration de `ubuntu-latest` vers Ubuntu 26 depuis le 2026-10-19 : le gabarit garde `ubuntu-latest`.

## v0.1 — État à la clôture

**v0.1.0 clôturée le 2026-10-19** (« clôture la v1 ») : phases A à G faites, rapport final dans `docs/V0.1_REPORT.md`, ARCHITECTURE.md en APPROVED, tag local `v0.1.0`. Suite déterministe verte à la clôture : 502 assertions, 4 validations. Prochaine étape : la v0.2 (github-workflow, debug-project, devops-engineer, secret-scan), qui ne démarre que sur votre demande.

**v0.1.1 publiée le 2026-10-19** : le plugin s'appelle désormais `flutter-forge` (ex-`dart-multiplatform-forge`), auteur `Soon`. Il est publié dans le dépôt public `soonlysoul/flutter-forge` et s'installe sur tout appareil depuis la marketplace `soon` (dépôt public `soonlysoul/claude-plugins`) : `claude plugin install flutter-forge@soon`. Voir D10.

**v0.1.2 publiée le 2026-10-19** : le plugin s'appelle désormais `plugin-flutter` (ex-`flutter-forge`), dans le dépôt public `soonlysoul/plugin-flutter` : `claude plugin install plugin-flutter@soon`. Voir D11.

Décisions D1 à D9 (`docs/PHASE_A_REPORT.md` §7) : le questionnaire a été refusé, puis la consigne « continue » donnée. Les recommandations du §7 sont donc appliquées **par défaut**, et chacune reste révisable :

| # | Retenu |
| --- | --- |
| D1 | Corrections E1–E19 reportées dans ARCHITECTURE.md ; REVIEW, puis APPROVED à la clôture du 2026-10-19 |
| D2 | `agent-scope-guard` ajouté à la v0.1 |
| D3 | checkpoint-reminder fait reprendre Claude une fois (`additionalContext`) |
| D4 | guard étendu à `git restore` (hors `--staged`), `git stash drop`/`clear` |
| D5 | *(remplacée par D10)* Auteur et titulaire MIT : `Allosun` ; propriétaire de la marketplace : `Soon` (votre modification du 2026-10-19) ; marketplace `dart-multiplatform-forge` |
| D6 | Dépôt initialisé sur place, `~/Documents/claude-plugin/App` (rien déplacé) |
| D7 | `inherit` pour flutter-architect, `sonnet` pour test-engineer et code-reviewer |
| D8 | Profil `~/.claude`, celui de cette session : vous avez validé la phase F.2 le 2026-10-19 sans désigner d'autre compte |
| D9 | Rédaction directe des agents, puis `skill-reviewer` en fin de phase D |
| D10 | *(nom et dépôt remplacés par D11)* 2026-10-19, à votre demande : nom `flutter-forge` ; auteur et titulaire MIT `Soon` ; dépôts **publics** ; catalogue séparé `soonlysoul/claude-plugins` (marketplace `soon`) qui référence `soonlysoul/flutter-forge` en source `github` ; `version` dans `plugin.json` seulement, augmentée à chaque release. Les rapports datés (`PHASE_A_REPORT`, `V0.1_REPORT`) gardent l'ancien nom. |
| D11 | 2026-10-19, à votre demande : nom `plugin-flutter`, dépôt `soonlysoul/plugin-flutter`, à l'image de `plugin-nixos`. Version 0.1.2, un correctif comme le renommage précédent : la 0.2 reste celle des skills et agents prévus. Le CHANGELOG 0.1.1 et D10 gardent l'ancien nom. |

## Phase A — Audit et vérification — terminée

Rapport : `docs/PHASE_A_REPORT.md`. Détail des commandes de la phase A : historique git de ce fichier (commit `70895b6`).

## Phase B — Squelette — terminée

- [x] B.1 `git init -b main` ; commit de l'état audité (`70895b6`)
- [x] B.2 Corrections E1–E19 dans ARCHITECTURE.md, statut → REVIEW (`036a162`)
- [x] B.3 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `LICENSE`, `.gitignore`
- [x] B.4 Validation stricte
- [x] B.5 Commit `chore: scaffold plugin skeleton`

| Commande | Résultat |
| --- | --- |
| `git init -b main` | exit 0 |
| `claude plugin validate . --strict` | exit 0 — ne valide **que** `marketplace.json` |
| `claude plugin validate . --strict --json` | exit 0, `success: true`, `contents: []` |
| `claude plugin validate .claude-plugin/plugin.json --strict` | exit 0 |

Correction du rapport de phase A, §3.2 : avec la racine `.`, le validateur ne contrôle que la marketplace. `plugin.json` doit être visé explicitement, d'où deux validations dans `run-all.sh`.

## Phase C — Hooks et leurs tests — terminée

TDD : chaque cycle a vu son test échouer pour la bonne raison (script vide ou règle absente), puis passer.

| Cycle | Objet | ROUGE | VERT |
| --- | --- | --- | --- |
| C1 | guard : contrat d'entrée, fail-closed | 10 échecs | 13/13 |
| C2 | guard : analyseur (composition, préfixes, citations, heredocs, `bash -c`, `eval`, `$(…)`) | 39 échecs | 66/66 |
| C3 | guard : règles git | 41 échecs | 133/133 |
| C4 | guard : rm, gh, pub, find, xargs | 37 échecs | 200/200 |
| C5 | agent-scope-guard | 40 échecs | 73/73 |
| C6 | format-dart | 3 échecs | 16/16 (dont le vrai `dart format`) |
| C7 | checkpoint-reminder | 4 échecs | 15/15 |
| C8 | `hooks/hooks.json` (test_paths, volet hooks) | 1 échec (fichier absent) | 36/36 |
| C2b | revue : substitutions des heredocs non cités | 3 échecs | 206/206 |

Deux échecs inattendus, débogués :

- **`missing jq is named in the reason`** : sans PATH, `dirname` était introuvable, et le script bloquait sur « bibliothèque absente » au lieu de nommer `jq`. Corrigé par une expansion bash.
- **Champs décalés dans test_paths** : `read` fusionne des tabulations consécutives, ce qui perdait le `matcher` vide de `Stop`. Corrigé par le séparateur `\x1f`.

Fichiers :

- `hooks/hooks.json`
- `hooks/scripts/{guard-destructive,agent-scope-guard,format-dart,checkpoint-reminder}.sh`
- `hooks/scripts/lib/shell-lexer.sh`
- `tests/lib.sh`
- `tests/hooks/test_{guard_destructive,agent_scope_guard,format_dart,checkpoint_reminder}.sh`
- `tests/static/test_paths.sh` (volet hooks)

| Commande | Résultat |
| --- | --- |
| `bash tests/hooks/test_guard_destructive.sh` | exit 0 — 206 réussis |
| `bash tests/hooks/test_agent_scope_guard.sh` | exit 0 — 73 réussis |
| `bash tests/hooks/test_format_dart.sh` | exit 0 — 16 réussis |
| `bash tests/hooks/test_checkpoint_reminder.sh` | exit 0 — 15 réussis |
| `bash tests/static/test_paths.sh` | exit 0 — 36 réussis |
| `claude plugin validate .claude-plugin/plugin.json --strict` | exit 0 ; `--json` : `contents: []`, donc les hooks ne sont **pas** inspectés par le validateur |
| `claude plugin validate . --strict` | exit 0 |

Limites relevées en revue, à documenter dans SECURITY.md (phase G) :

- commande désignée par une variable ;
- alias git ;
- citation `$'…'` ;
- `pwsh -Command` et `Remove-Item` ;
- `find -delete` ;
- `rm -r` sans `-f` ;
- tag poussé par son seul nom ;
- `git checkout <fichier>` sans `--` ;
- liens symboliques (agent-scope-guard) ;
- racine = `CLAUDE_PROJECT_DIR`, donc le dossier de lancement.

Testé sous bash 5.2 seulement ; bash 3.2 (macOS) non vérifié.

## Phase D — Agents, skills, gabarits — terminée

TDD : les tests statiques ont été écrits d'abord, et ont échoué sur l'absence des fichiers. L'auto-test de l'analyseur strict passait déjà : 7 frontmatters cassés rejetés.

Fichiers :

- `agents/{flutter-architect,test-engineer,code-reviewer}.md`
- `skills/{bootstrap-project,create-feature,git-workflow,recover-session}/SKILL.md`
- `skills/bootstrap-project/reference/doc-templates/{PRD,TRD,IMPLEMENTATION_PLAN,DECISIONS,CLAUDE}.md`
- `templates/{project-settings.json,forge-config.yaml,checkpoint.md}`
- `tests/static/test_{frontmatter,tdd_skill,settings_template}.sh`
- volet skills de `tests/static/test_paths.sh`

Constats :

- **`argument-hint: [app-name]` est une liste YAML**, pas une chaîne : le test strict l'a refusé, et les trois valeurs sont désormais citées.
- **Validateur officiel** : même en `--strict` sur `agents/`, il **accepte** un frontmatter invalide (`description: Use when: …`, `[unclosed`, `---` jamais refermé). Sonde : exit 0 dans les trois cas. `test_frontmatter.sh` est donc la seule barrière.
- **Un premier essai de sonde était faux** : un dossier qui ne s'appelle pas `agents/` est validé comme un plugin, et échoue faute de manifeste. Il a été refait avec des dossiers `agents/`.
- **`test_tdd_skill`** comparait en tenant compte de la casse (« Wait » ≠ « wait ») : le test a été corrigé, pas le contenu.

Revue `plugin-dev:skill-reviewer` (une passe, lecture seule) : 2 constats bloquants, 10 importants et 8 mineurs. Chacun a été vérifié sur les fichiers avant correction.

- **B1** : un projet créé dans un sous-dossier a pour racine de hooks le dossier parent, si bien que les agents ne peuvent ni écrire ni lancer `flutter test`. Correctif : bootstrap crée de préférence dans le dossier courant, rédige lui-même le TRD sinon, et demande une nouvelle session à la racine. create-feature vérifie `${CLAUDE_PROJECT_DIR}`.
- **B2** : rien n'est commité avant l'étape 15, donc la revue portait sur un diff vide. Correctif : indexation explicite, puis revue de `git diff --cached <base>`.
- **Importants** :
  - descriptions limitées aux projets ayant `.forge/` ;
  - checkpoint ignoré à l'étape 1 et à la création de branche ;
  - tests ROUGE déjà verts : arrêt ;
  - PRD et TRD doivent être APPROVED ;
  - dépendance ajoutée et plateformes vérifiées dès l'étape 4 ;
  - étapes 11 et 12 relancées après les corrections de revue, arrêt si un constat bloquant subsiste ;
  - `restore --staged` autorisé, et `git rm --cached` prévu avant le premier commit ;
  - un TRD APPROVED modifié repasse en DRAFT, et un nouvel ADR est `proposed` ;
  - appareil fourni pour `integration_test/`, sinon tests classés bloqués.
- **Écart assumé** (constat 5) : l'ordre des étapes 13 et 14 d'ARCHITECTURE.md est gardé. Le reviewer liste désormais les docs à mettre à jour (`DOCS_TO_UPDATE`), au lieu de les signaler comme constats.
- **Tests** : 9 assertions ajoutées d'abord (ROUGE : 9 échecs), puis corrections (VERT).

## Phase E — Tests déterministes — terminée

- `tests/static/test_manifest.sh`. ROUGE par mutation : une copie aux manifestes faussés échoue sur exactement les 6 propriétés mutées. Puis 14/14 sur le vrai plugin.
- `tests/run-all.sh` : 9 suites, puis `claude plugin validate --strict` sur `.`, `.claude-plugin/plugin.json`, `agents` et `skills`.
- `tests/scenarios/` : README, scénarios 01 à 05, et `headless.sh`, qui refuse de tourner sans `FORGE_ALLOW_QUOTA=1` ou depuis le dossier du plugin. Les deux refus ont été vérifiés, exit 2.

| Commande | Résultat |
| --- | --- |
| `bash tests/run-all.sh` | exit 0 — 13 réussis (9 suites, 500 assertions, 4 validations), 0 échoué, 0 bloqué ; après F.2 : 502 assertions |

## Phase F.1 — Validation sans quota — faite

| Commande | Résultat |
| --- | --- |
| `flutter create --org com.example --project-name demo_probe --platforms linux …` (scratchpad) | exit 0 |
| `flutter test` (projet jetable) | exit 0 — 1 test réussi |
| `flutter analyze` (projet jetable) | exit 0 — aucun problème |
| guard-destructive sur `git reset --hard` dans ce dépôt réel, fichier modifié non commité | exit 2, raison claire ; empreinte du fichier inchangée |
| `claude --plugin-dir . plugin details dart-multiplatform-forge` | exit 0 — `@inline`, 4 skills, 3 agents, hooks sur 3 événements ; ~848 jetons permanents |
| Projets de `~/.claude.json` avant / après | 36 / 36 |

## Phase F.2 — Scénarios réels — terminée (accord donné le 2026-10-19)

Profil `~/.claude`, celui de cette session (D8 : aucun autre compte désigné). Avant de commencer, copie de `~/.claude.json` dans le scratchpad. Scénarios lancés un par un. Résultat : 36 projets avant comme après, aucun perdu.

| Scénario | Tours | Résultat | Coût estimé (API) |
| --- | --- | --- | --- |
| 4 Blocage | 1 | **réussi** : un seul appel `git reset --hard`, refusé par guard-destructive (exit 2) avec sa raison ; aucune reformulation ; fichier intact | 0,25 $ |
| 1 Bootstrap | 3 | **réussi avec réserve** : arrêts aux étapes 2 et 7 ; création dans le dossier courant ; `.forge/`, 4 docs en DRAFT, 6 autorisations à `false` ; `flutter test` exit 0 (revérifié). Réserve : `.claude/settings.json` refusé par Claude Code en `-p`, non contourné, copié à la main | 3,27 $ |
| 2 Feature TDD | 2 | **réussi** : arrêt à l'étape 2 (DRAFT) ; puis étapes 3 à 14. Tests écrits par le test-engineer, sous `test/` seulement ; ROUGE exit 1 puis VERT exit 0 consignés ; revue de `git diff --cached main` ; commit refusé (règle `ask`), puis fait à la main | 3,54 $ |
| 3 Préservation | 1 | **réussi** : arrêt à l'étape 1 avec 3 options ; `lib/main.dart` identique (sha256), aucun stash | 0,52 $ |
| 5 Reprise | 1 | **réussi** : un seul `flutter test` ciblé (ROUGE confirmé) ; aucun agent, aucune écriture ; étape 8 proposée ; 3 vraies incohérences du jeu d'essai relevées | 0,44 $ |

Total : environ 8,02 $ en équivalent API, sur le quota de l'abonnement.

Défauts trouvés et corrigés pendant F.2 :

- **checkpoint-reminder** se déclenchait à tort sur le dossier `.forge/` non suivi (`0da9906`, TDD : 2 tests ROUGE puis VERT) ;
- **bootstrap-project** donne désormais la commande de copie de `.claude/settings.json` quand l'écriture est refusée.

Constats sur la 2.1.296 : voir `tests/scenarios/README.md`, section « Observed ».

## Phase G — Documentation et rapport — terminée

- `README.md`, `docs/{INSTALLATION,USER_GUIDE,SECURITY,TROUBLESHOOTING}.md`, `CHANGELOG.md` (0.1.0), en français.
- Commandes vérifiées par `--help` avant d'être citées : `plugin install|uninstall -s/--scope`, `marketplace add --scope`, `marketplace remove`, `plugin disable|enable`, `plugin details`.
- Liens relatifs des docs : vérifiés, aucun cassé.

## Phases suivantes
- [x] D — Agents, skills, gabarits, revue `skill-reviewer`, commit (`f1f3e2b`)
- [x] E — `tests/run-all.sh` au vert, commit (`5e3fe7f`)
- [x] F.1 — Validation sans quota (`flutter create`/`test` jetable, `plugin details`, scénario 4 au niveau du hook)
- [x] F.2 — Scénarios headless 1 à 5 : tous réussis (1 avec réserve)
- [x] G — Docs complétées avec F.2, rapport `docs/V0.1_REPORT.md`, commit final
