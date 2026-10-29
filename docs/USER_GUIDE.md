# Guide d'utilisation

## Principes

- **La session principale orchestre.** Elle seule vous parle et vous demande validation ; les agents exécutent une tâche bornée et rendent un rapport, que la session vérifie avant de vous le présenter.
- **Rien n'est approuvé implicitement.** Un document passe en APPROVED, un commit se fait, une branche se pousse seulement sur votre accord.
- **Aucun résultat sans sa commande.** Chaque test est classé réussi, échoué, bloqué (avec la raison) ou non exécuté, avec la commande lancée.
- **L'état vit sur le disque** : `.forge/checkpoint.md` et l'historique Git. Une session coupée par une limite d'usage se reprend sans dépendre de sa mémoire.

## Les points de validation

Quand un workflow a besoin de vous, il pose sa question **en texte**, écrit le checkpoint et s'arrête. Répondez simplement dans la conversation ; il reprend à l'étape suivante. Le même fonctionnement vaut en mode non interactif (`claude -p`, puis `--resume`).

## Avec plugin-orchestrator

Depuis la 1.0, plugin-flutter est le plugin Flutter de [plugin-orchestrator](https://github.com/soonlysoul/plugin-orchestrator) : installez les deux. Les workflows communs à tous les langages sont les siens, et lui seul les lance :

| Pour | Lancez | Ce que fait plugin-flutter |
| --- | --- | --- |
| Créer une app | `/plugin-orchestrator:bootstrap-project une appli de notes en Flutter` | Le scaffold-engineer reçoit le mandat `scaffold` : `flutter create` dans le dossier de la session, structure `lib/app`, `lib/core`, `lib/features`, modes stricts de l'analyseur, TRD en DRAFT, `flutter test` et `flutter analyze` à 0 ; il rend la toolchain que l'orchestrateur écrit dans `.forge/config.yaml`, les règles de permission Flutter, les versions et les plateformes. Ni CI, ni commit : ils sont à l'orchestrateur |
| Une fonctionnalité en TDD | `/plugin-orchestrator:create-feature AC-001` | Le test-engineer écrit les tests (`write-tests`) et rend la sortie ROUGE ; le flutter-architect vérifie une nouvelle dépendance contre vos plateformes (`check-dependency`) ; le code-reviewer relit le diff indexé (`review`) |
| Corriger une panne | `/plugin-orchestrator:debug-project` | Le flutter-architect confirme ou réfute une hypothèse qui dépend de Flutter, de Dart ou d'une plateforme (`diagnose`) ; le test-engineer écrit le test de non-régression ; le code-reviewer relit le correctif |
| GitHub et la CI | `/plugin-orchestrator:github-workflow ci`, `pr`, `checks` | Le devops-engineer écrit `.github/workflows/ci.yml` depuis le gabarit Flutter, avec votre version de Flutter (`ci-template`), builde vos plateformes (`build`), lit les journaux d'une CI rouge (`ci-diagnosis`), corrige le workflow (`workflow-change`) |
| Branches, commits, reprise | `/plugin-orchestrator:git-workflow`, `/plugin-orchestrator:recover-session` | Rien : ces gestes ne dépendent pas du langage |

Chaque mandat nomme l'interface 1 du contrat de délégation, et chaque agent de plugin-flutter termine son rapport par `INTERFACE: 1`. L'orchestrateur le vérifie avant de se servir du rapport : un plugin-flutter 0.x, qui ne répond pas ainsi, est arrêté en demandant sa mise à jour. Les commandes mécaniques — tests, format, analyse, ajout de dépendance — sont lancées par l'orchestrateur lui-même, depuis la `toolchain` de la partie dans `.forge/config.yaml`.

Ouvrez la session **à la racine du projet** : le scaffold-engineer ne crée l'app que là, et un projet demandé dans un sous-dossier s'arrête au scaffold, repris par une nouvelle session ouverte dans ce sous-dossier.

Trois états distincts par plateforme : activée (dossier présent), compilée (build réussi), testée. Sur Linux, seuls Android, Web et Linux desktop se compilent ; iOS, macOS et Windows restent « non vérifié » en local.

## Mettre à jour les dépendances — `update-project`

Prérequis : plugin-orchestrator dans la session, et un projet qui a `.forge/` au format de l'orchestrateur (une partie `plugin: plugin-flutter`, `interface: 1`), sur sa branche principale, sans modification en cours (le checkpoint et `.forge/reports/` mis à part). Sans l'orchestrateur, ou face à un `.forge/config.yaml` de plugin-flutter 0.x, le skill s'arrête avant tout : il nomme ce qui manque, ou montre le bloc `parts` à ajouter.

```
/plugin-flutter:update-project              # toutes les dépendances
/plugin-flutter:update-project go_router    # ce paquet seulement, et ceux publiés avec lui
/plugin-flutter:update-project flutter      # le SDK Flutter
```

1. plugin-orchestrator, la configuration, l'état du dépôt.
2. Toolchain : `flutter --version --machine`. Un Flutter fourni par Nix (racine sous `/nix/store/`) est signalé, tout comme un écart avec la version épinglée par la CI.
3. **État de référence** : `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`, `dart format`. Un `pubspec.lock` qui ne correspond plus à `pubspec.yaml` est un point de **validation** : sa resynchronisation fait l'objet d'un premier commit, à part. Un état de référence rouge arrête tout, sauf si vous dites explicitement de continuer avec ces échecs connus ; sa correction passe par `/plugin-orchestrator:debug-project`.
4. Inventaire : `flutter pub outdated --json`, qui ne modifie rien. Chaque dépendance est classée compatible, majeure, retenue (une autre contrainte l'empêche de monter, souvent le SDK ; `flutter pub add --dry-run` dit laquelle) ou signalée (avis de sécurité, version retirée, paquet abandonné).
5. **Validation** du plan de lots : les paquets signalés d'abord, puis le lot compatible, puis une majeure par lot, avec le lien vers son changelog. Vous approuvez tous les lots, certains, ou aucun.
6. Branche `chore/deps-<slug>`.
7. Un lot à la fois :
   - sa commande, `flutter pub upgrade`, ou `flutter pub upgrade --major-versions <paquet>` pour une majeure ;
   - les fichiers modifiés vérifiés ;
   - pour une majeure, le changelog lu et ses plateformes comparées aux vôtres ;
   - `flutter analyze` et `flutter test`.

   Le code qui utilise une majeure est migré dans le même lot ; une modification hors de ces fichiers est un point de **validation**. Une majeure ajoute un ADR `proposed` à DECISIONS.md. Un lot qui reste rouge n'est pas commité : si vous l'abandonnez, le skill vous donne la commande `! git restore …` qui l'annule. Un commit par lot, avec son lockfile.
8. Rapport avant/après dans `.forge/reports/deps-<date>-<slug>.md` : lots et commits, versions avant et après, paquets non mis à jour et pourquoi, analyse et tests avant et après. Il a son propre commit.

**Le SDK Flutter appartient à la machine.** Le skill ne lance jamais `flutter upgrade`, `flutter downgrade` ni `flutter channel` : ces commandes changent Flutter pour tous les projets de la machine, et les règles du projet demandent confirmation pour elles. Avec un Flutter fourni par Nix, vous le mettez à jour dans votre configuration Nix ; sinon, vous lancez `! flutter upgrade` vous-même. Le skill reprend ensuite : il relève la nouvelle version, relance `flutter pub get`, l'analyse, les tests et le format, puis vous propose d'aligner la ligne `flutter-version:` de `.github/workflows/ci.yml`, sans quoi la CI teste l'ancienne version.

Les branches et les commits passent par le git-workflow de l'orchestrateur. Ensuite : `/plugin-orchestrator:github-workflow pr`, pour que la CI vérifie aussi la mise à jour.

## Adopter une app existante — `adopt-existing-project`

Pour une app Flutter qui n'a pas encore de `.forge/`. Une nouvelle app passe par `/plugin-orchestrator:bootstrap-project`, qui renvoie ici une app existante.

Prérequis : plugin-orchestrator dans la session — sans lui, le skill s'arrête avant tout — et Claude Code ouvert à la racine de l'app (le dossier de `pubspec.yaml`), dans un dépôt Git, sur la branche principale, sans aucune modification en cours. Hors d'un dépôt Git, le skill s'arrête : le premier commit d'un code existant vous revient, après avoir vérifié qu'il ne contient pas de secret.

```
/plugin-flutter:adopt-existing-project
```

1. Prérequis ci-dessus. Une adoption interrompue reprend où elle s'était arrêtée. Un `.forge/` de plugin-flutter 0.x n'est pas réadopté : le skill montre le bloc `parts` à y ajouter.
2. **Analyse en lecture seule** : historique, `pubspec.yaml`, plateformes, organisation du code, tests, documents, configuration, fichiers de secrets suivis par Git (nommés, jamais ouverts). État de référence : `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub`, `dart format --output=none`. Aucune de ces commandes ne réécrit `pubspec.lock`, et un `git status` final prouve que rien n'a changé.
3. Divergences entre les documents et le code (voir plus bas).
4. **Validation** du plan de mise en conformité, en items numérotés :
   - la branche `chore/adopt-plugin-flutter` ;
   - `.forge/`, au format de l'orchestrateur (schéma 2, une partie Flutter à la racine) ;
   - les documents manquants, reconstruits depuis le code, en DRAFT ;
   - les modifications de fichiers existants (`CLAUDE.md`, `.gitignore`, `analysis_options.yaml`), chacune avec son diff et approuvée à part ;
   - `.claude/settings.json` : les règles génériques de l'orchestrateur et celles de Flutter ;
   - la liste des divergences ;
   - ce qui relève d'un autre skill : lockfile périmé et dépendances, tests rouges, CI, réorganisation du code.

   Vous approuvez tous les items, certains, ou aucun.
5. Seuls les items approuvés sont appliqués :
   - la branche est créée par le skill lui-même : le git-workflow de l'orchestrateur a besoin de `.forge/`, qui n'existe pas encore ;
   - le PRD est reconstruit par le product-architect de l'orchestrateur, sur un mandat à l'interface 1, chaque critère marqué « reconstructed » avec le fichier qui le montre ;
   - le TRD et DECISIONS.md sont reconstruits ensuite par flutter-architect : la pile actuelle, un ADR `proposed` par dépendance directe et un par écart aux choix par défaut du plugin (gestion d'état, navigation, organisation du code) ;
   - un document existant est conservé, jamais remplacé ;
   - la liste des divergences va dans `.forge/reports/divergences-<date>.md`.
6. Commit `chore: adopt plugin-flutter`, par le git-workflow de l'orchestrateur, que vous confirmez.

Le skill ne déplace, ne renomme, ne reformate ni ne corrige aucun fichier de l'app. Il n'approuve aucun document : le `create-feature` de l'orchestrateur attend que vous approuviez le PRD et le TRD, et consigne votre accord. La fusion de la branche vous revient : par pull request (`/plugin-orchestrator:github-workflow pr`) si l'état de référence était propre, sinon par vous-même.

## Divergences entre documents et code

Une divergence est un écart entre ce que disent les documents et ce que fait le code. Exemples :

- une dépendance sans ADR ;
- un critère d'acceptation sans test qui cite son identifiant ;
- un plan d'implémentation contredit par le code ;
- une plateforme annoncée par le README sans son dossier ;
- une version de Flutter différente de celle de la CI.

Ce n'est pas un hook mais un contrôle de jugement, fait à trois moments :

- à l'adoption, sur tout le projet (étape 3 d'`adopt-existing-project`) ;
- à chaque revue, sur ce que le diff touche : le code-reviewer les liste sous `DIVERGENCES`, et l'étape docs du `create-feature` de l'orchestrateur les résout ;
- à la revue du `debug-project` de l'orchestrateur.

Quand le code a raison, le plan ou DECISIONS.md sont mis à jour. Une modification du PRD ou du TRD est un point de **validation**, car vous seul les approuvez. Quand c'est le document qui a raison, l'écart vous est signalé.

## Le dossier `.forge/`

| Fichier | Contenu | Qui l'écrit |
| --- | --- | --- |
| `config.yaml` | Format de l'orchestrateur (`schema_version: 2`) : préautorisations (toutes à `false` par défaut), branche principale, et sous `parts` la partie Flutter — son chemin, son plugin, l'interface 1, sa toolchain, ses plateformes | **Vous seul.** La règle `deny` `Edit(./.forge/config.yaml)` empêche Claude de le modifier |
| `checkpoint.md` | Étapes faites avec commande et code de sortie, résultats de tests, prochaine action, blocages | Les workflows, après chaque étape ; versionné dans Git. Le commit qui le porte l'emporte dans son état final, écrit juste avant : il n'est plus modifié après, et l'arbre reste propre |
| `reports/` | Rapports de revue, de mise à jour des dépendances (`deps-<date>-<slug>.md`), de divergences (`divergences-<date>.md`) | Les workflows |
| `approvals.log` | L'empreinte de chaque document approuvé | L'orchestrateur, à votre approbation ; un document approuvé qui change repasse en REVIEW |

Une clé absente de `config.yaml` vaut `false`. Les clés `merge` et `publish_release` sont ignorées : fusion et publication demandent toujours un accord explicite.

## Les agents

| Agent | Modèle | Mandats | Peut écrire | Peut lancer |
| --- | --- | --- | --- | --- |
| scaffold-engineer | sonnet | `scaffold` | `lib/`, `test/`, `integration_test/`, `docs/technical/`, `analysis_options.yaml` | `flutter create <options> .` (jamais `--overwrite`), `flutter --version`, `flutter devices`, `flutter doctor`, `flutter pub get`, `flutter test`, `flutter analyze`, git en lecture |
| flutter-architect | celui de la session | `check-dependency`, `diagnose`, TRD et ADR | `docs/` (rien sur `check-dependency` ni `diagnose`) | `flutter --version`, `flutter doctor`, `dart --version`, `dart pub deps`, `flutter pub deps`, git en lecture |
| test-engineer | sonnet | `write-tests` | `test/`, `integration_test/` | `flutter test`, `dart test`, git en lecture |
| code-reviewer | sonnet | `review` | rien | `git diff`, `git log`, `git show`, `git status`, `flutter analyze`, `dart analyze` |
| devops-engineer | sonnet | `ci-template`, `build`, `ci-diagnosis`, `workflow-change` | `.github/` | `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status`, `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, `git remote -v`, git en lecture |

Ces limites sont imposées par le hook agent-scope-guard, pas seulement par la consigne ; un agent du plugin sans périmètre déclaré y est bloqué. Une commande à la fois, sans `;`, `&&`, `|` ni redirection. devops-engineer ne pousse rien, n'ouvre pas de PR et ne relance pas de CI : ces actions restent dans la session principale, derrière un point de validation.

## Économiser le quota

- Tests ciblés pendant le développement ; suite complète et analyse aux jalons seulement.
- Les agents ne sont lancés que sur un mandat : le scaffold au démarrage, les tests et la revue d'une fonctionnalité ou d'un correctif, une dépendance ou un diagnostic qui demandent de connaître Flutter, la CI et les builds, et les documents d'une adoption.
- Aucune boucle de nouvelle tentative : après deux échecs identiques d'une commande, le workflow s'arrête et explique.
- Si une limite d'usage tombe, rien n'est perdu : le checkpoint est écrit après chaque étape. Relancez avec `/plugin-orchestrator:recover-session`.
