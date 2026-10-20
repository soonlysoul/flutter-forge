# Guide d'utilisation

## Principes

- **La session principale orchestre.** Elle seule vous parle et vous demande validation ; les agents exécutent une tâche bornée et rendent un rapport, que la session vérifie avant de vous le présenter.
- **Rien n'est approuvé implicitement.** Un document passe en APPROVED, un commit se fait, une branche se pousse seulement sur votre accord.
- **Aucun résultat sans sa commande.** Chaque test est classé réussi, échoué, bloqué (avec la raison) ou non exécuté, avec la commande lancée.
- **L'état vit sur le disque** : `.forge/checkpoint.md` et l'historique Git. Une session coupée par une limite d'usage se reprend sans dépendre de sa mémoire.

## Les points de validation

Quand un workflow a besoin de vous, il pose sa question **en texte**, écrit le checkpoint et s'arrête. Répondez simplement dans la conversation ; il reprend à l'étape suivante. Le même fonctionnement vaut en mode non interactif (`claude -p`, puis `--resume`).

## Créer un projet — `bootstrap-project`

Lancez Claude Code **dans un dossier vide** destiné au projet : ce dossier sert de racine aux hooks et aux règles de permission (`CLAUDE_PROJECT_DIR`). Si le projet est créé dans un sous-dossier, il faudra ouvrir une nouvelle session dans ce sous-dossier avant `create-feature`.

```
/plugin-flutter:bootstrap-project mon_app
```

1. Vérifie `flutter`, `git` et `jq`, et ce que la machine peut compiler.
2. **Validation** : nom, organisation (package id), plateformes, périmètre, dossier (le dossier courant est recommandé).
3. `flutter create`, `git init`.
4. Crée `.forge/` : `config.yaml` (toutes les autorisations à `false`), `checkpoint.md`, `reports/`.
5. Arborescence par fonctionnalité, `analysis_options.yaml` strict, `.gitignore` complété, `CLAUDE.md`.
6. Documents de base en DRAFT : PRD (critères d'acceptation `AC-001`…), TRD, plan d'implémentation, DECISIONS (ADR-001). Pour un brief long (un document, plusieurs fonctionnalités), le PRD est confié à l'agent product-architect.
7. **Validation** : approbation du PRD et du TRD ; installation des règles de permission dans `.claude/settings.json`.
8. `flutter test` doit être vert, `flutter analyze` sans erreur.
9. Premier commit, que vous confirmez.

Trois états distincts par plateforme : activée (dossier présent), compilée (build réussi), testée. Sur Linux, seuls Android, Web et Linux desktop se compilent ; iOS, macOS et Windows restent « non vérifié » en local.

## Développer une fonctionnalité — `create-feature`

```
/plugin-flutter:create-feature AC-001
```

| # | Étape | Ce qui se passe |
| --- | --- | --- |
| 1 | État du dépôt | `git status` ; des modifications non commitées sont préservées, et vous choisissez quoi en faire. Jamais de `git stash` silencieux |
| 2 | Contexte | PRD, TRD, plan ; critères d'acceptation visés. Arrêt si le PRD ou le TRD n'est pas APPROVED |
| 3 | Risques | Nouveau package, impact plateforme, migration |
| 4 | Plan | Fichiers, API publique, tests prévus. **Validation** si le périmètre, l'architecture ou une dépendance change ; une dépendance approuvée est ajoutée et ses plateformes vérifiées |
| 5 | Branche | `feature/<ac-id>-<slug>` |
| 6 | Tests d'abord | Le test-engineer écrit les tests ; la session attend son rapport |
| 7 | ROUGE | `flutter test <fichiers>` doit échouer sur l'assertion attendue ; sortie consignée. Des tests déjà verts arrêtent le workflow |
| 8 | Implémentation minimale | Dans la session principale |
| 9 | VERT | Mêmes tests, tous verts ; au plus trois itérations avant d'exposer le blocage |
| 10 | Refactor | Sans changement de comportement |
| 11 | Re-test | Tests ciblés, puis `flutter test` complet |
| 12 | Qualité | `dart format --set-exit-if-changed .`, `flutter analyze` |
| 13 | Revue | Les fichiers sont indexés, puis le code-reviewer relit `git diff --cached`, sans connaître le raisonnement de l'implémentation, et relève les divergences avec les documents. Après correction, les étapes 11 et 12 sont relancées |
| 14 | Docs | Plan, DECISIONS, traçabilité, à partir des mises à jour et des divergences relevées à la revue. Une modification du PRD ou du TRD est un point de **validation** |
| 15 | Commit | Préparé par git-workflow, que vous confirmez ; rapport final |

## Branches et commits — `git-workflow`

- Branches : `feature/`, `fix/`, `docs/`, `chore/deps-` (update-project), `chore/ci` (github-workflow), `chore/adopt-plugin-flutter` (adopt-existing-project).
- Fichiers ajoutés un par un ; `git add -A` seulement après relecture du diff avec vous.
- Messages Conventional Commits : `feat(notes): list notes offline (AC-012)`.
- Push d'une branche de travail seulement si `.forge/config.yaml` l'autorise (`push_feature_branches: true`) ou si vous le demandez ; jamais la branche principale, jamais en force.

## Publier sur GitHub — `github-workflow`

Prérequis : `gh` installé et connecté. Le skill commence toujours par `gh auth status` ; s'il échoue, il s'arrête, et c'est vous qui lancez `! gh auth login`. Aucun jeton ne passe par la conversation.

```
/plugin-flutter:github-workflow remote    # créer le dépôt GitHub
/plugin-flutter:github-workflow ci        # ajouter la CI
/plugin-flutter:github-workflow pr        # ouvrir la pull request de la branche courante
/plugin-flutter:github-workflow checks    # suivre la CI, diagnostiquer un échec
```

| Action | Ce qui se passe |
| --- | --- |
| `remote` | **Validation** à chaque fois : propriétaire, nom, visibilité (privé par défaut). Puis `gh repo create --source . --remote origin`, sans `--push`, et la publication de la branche principale, qui faisait partie de votre accord |
| `ci` | **Validation** avec le coût : gratuit pour un dépôt public ; pour un dépôt privé, des minutes de votre quota mensuel (2 000 sur GitHub Free). Copie de `templates/github-workflows/flutter-ci.yml` avec votre version locale de Flutter ; le hook protect-sensitive vous demande de confirmer l'écriture. Les quatre vérifications de la CI sont d'abord lancées en local |
| `pr` | Pousse la branche si `push_feature_branches` l'autorise ou si vous le demandez. Corps de PR : résumé, critères d'acceptation, risques, tests en quatre catégories, plateformes en trois états. **Validation** du titre et du corps, sauf si `open_pull_requests: true` |
| `checks` | `gh pr checks` ; si la CI échoue, l'agent devops-engineer lit les journaux et classe l'échec (format, analyse, tests, dépendances, version de Flutter, workflow, infrastructure). Un échec du code part vers `debug-project` ; une relance sur dépôt privé demande votre accord |

Le skill ne fusionne jamais : quand la CI est verte, il vous dit que la PR est prête, et la fusion vous revient.

## Corriger une erreur — `debug-project`

Pour ce qui échoue alors que cela devrait passer : build, analyse, test, CI rouge. Pas pour l'étape ROUGE attendue de `create-feature`.

```
/plugin-flutter:debug-project "flutter test test/notes échoue depuis le dernier commit"
```

1. État du dépôt, sans rien mettre de côté.
2. **Reproduire** la commande exacte. Un échec qui ne se reproduit pas s'arrête là, avec ce qui diffère (version de Flutter, plateforme).
3. Classer l'échec, avec la ligne qui le prouve.
4. **Cause racine** : une hypothèse à la fois, avec sa preuve, avant tout correctif.
5. **Validation** si le correctif sort du périmètre de l'erreur : autre fonctionnalité, `pubspec.yaml`, dossier de plateforme, CI.
6. Branche `fix/<slug>` depuis la branche principale.
7. Test de non-régression, ROUGE.
8. Correctif minimal, VERT ; au plus trois itérations.
9. Commande d'origine, `flutter test` complet, format, analyse.
10. Revue du code-reviewer.
11. Commit `fix(<scope>): …`, avec la cause racine dans le corps.

## Mettre à jour les dépendances — `update-project`

Prérequis : un projet qui a `.forge/`, sur sa branche principale, sans modification en cours (le checkpoint et `.forge/reports/` mis à part).

```
/plugin-flutter:update-project              # toutes les dépendances
/plugin-flutter:update-project go_router    # ce paquet seulement, et ceux publiés avec lui
/plugin-flutter:update-project flutter      # le SDK Flutter
```

1. État du dépôt.
2. Toolchain : `flutter --version --machine`. Un Flutter fourni par Nix (racine sous `/nix/store/`) est signalé, tout comme un écart avec la version épinglée par la CI.
3. **État de référence** : `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`, `dart format`. Un `pubspec.lock` qui ne correspond plus à `pubspec.yaml` est un point de **validation** : sa resynchronisation fait l'objet d'un premier commit, à part. Un état de référence rouge arrête tout, sauf si vous dites explicitement de continuer avec ces échecs connus.
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

Ensuite : `/plugin-flutter:github-workflow pr`, pour que la CI vérifie aussi la mise à jour.

## Adopter une app existante — `adopt-existing-project`

Pour une app Flutter qui n'a pas encore de `.forge/`. Une nouvelle app passe par `bootstrap-project`.

Prérequis : ouvrir Claude Code à la racine de l'app (le dossier de `pubspec.yaml`), dans un dépôt Git, sur la branche principale, sans aucune modification en cours. Hors d'un dépôt Git, le skill s'arrête : le premier commit d'un code existant vous revient, après avoir vérifié qu'il ne contient pas de secret.

```
/plugin-flutter:adopt-existing-project
```

1. Prérequis ci-dessus. Une adoption interrompue reprend où elle s'était arrêtée.
2. **Analyse en lecture seule** : historique, `pubspec.yaml`, plateformes, organisation du code, tests, documents, configuration, fichiers de secrets suivis par Git (nommés, jamais ouverts). État de référence : `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub`, `dart format --output=none`. Aucune de ces commandes ne réécrit `pubspec.lock`, et un `git status` final prouve que rien n'a changé.
3. Divergences entre les documents et le code (voir plus bas).
4. **Validation** du plan de mise en conformité, en items numérotés :
   - la branche `chore/adopt-plugin-flutter` ;
   - `.forge/` ;
   - les documents manquants, reconstruits depuis le code, en DRAFT ;
   - les modifications de fichiers existants (`CLAUDE.md`, `.gitignore`, `analysis_options.yaml`), chacune avec son diff et approuvée à part ;
   - `.claude/settings.json` ;
   - la liste des divergences ;
   - ce qui relève d'un autre skill : lockfile périmé et dépendances, tests rouges, CI, réorganisation du code.

   Vous approuvez tous les items, certains, ou aucun.
5. Seuls les items approuvés sont appliqués :
   - le PRD est reconstruit par l'agent product-architect, chaque critère marqué « reconstructed » avec le fichier qui le montre ;
   - le TRD et DECISIONS.md sont reconstruits ensuite par flutter-architect : la pile actuelle, et un ADR `proposed` par dépendance directe ;
   - un document existant est conservé, jamais remplacé ;
   - la liste des divergences va dans `.forge/reports/divergences-<date>.md`.
6. Commit `chore: adopt plugin-flutter`, que vous confirmez.

Le skill ne déplace, ne renomme, ne reformate ni ne corrige aucun fichier de l'app. Il n'approuve aucun document : `create-feature` attend que vous approuviez le PRD et le TRD. La fusion de la branche vous revient : par pull request (`/plugin-flutter:github-workflow pr`) si l'état de référence était propre, sinon par vous-même.

## Divergences entre documents et code

Une divergence est un écart entre ce que disent les documents et ce que fait le code. Exemples :

- une dépendance sans ADR ;
- un critère d'acceptation sans test qui cite son identifiant ;
- un plan d'implémentation contredit par le code ;
- une plateforme annoncée par le README sans son dossier ;
- une version de Flutter différente de celle de la CI.

Ce n'est pas un hook mais un contrôle de jugement, fait à trois moments :

- à l'adoption, sur tout le projet (étape 3 d'`adopt-existing-project`) ;
- à chaque revue, sur ce que le diff touche : le code-reviewer les liste sous `DIVERGENCES`, et l'étape 14 de `create-feature` les résout ;
- à la fin de `debug-project`.

Quand le code a raison, le plan ou DECISIONS.md sont mis à jour. Une modification du PRD ou du TRD est un point de **validation**, car vous seul les approuvez. Quand c'est le document qui a raison, l'écart vous est signalé.

## Reprendre — `recover-session`

```
/plugin-flutter:recover-session
```

Lit le checkpoint, le compare au dépôt (`HEAD`, branche, fichiers modifiés), signale les incohérences, relance seulement le test de la dernière étape, puis présente un résumé de dix lignes au plus et la prochaine étape. Il ne modifie rien avant votre accord.

## Le dossier `.forge/`

| Fichier | Contenu | Qui l'écrit |
| --- | --- | --- |
| `config.yaml` | Préautorisations (toutes à `false` par défaut), branche principale, plateformes | **Vous seul.** La règle `deny` `Edit(./.forge/config.yaml)` empêche Claude de le modifier |
| `checkpoint.md` | Étapes faites avec commande et code de sortie, résultats de tests, prochaine action, blocages | Les workflows, après chaque étape ; versionné dans Git |
| `reports/` | Rapports de revue, de mise à jour des dépendances (`deps-<date>-<slug>.md`), de divergences (`divergences-<date>.md`) | Les workflows |

Une clé absente de `config.yaml` vaut `false`. Les clés `merge` et `publish_release` sont ignorées : fusion et publication demandent toujours un accord explicite.

## Les agents

| Agent | Modèle | Peut écrire | Peut lancer |
| --- | --- | --- | --- |
| product-architect | celui de la session | `docs/product/` | aucune commande : il lit les fichiers sans shell |
| flutter-architect | celui de la session | `docs/` | `flutter --version`, `dart --version`, `dart pub deps`, `flutter pub deps`, git en lecture |
| test-engineer | sonnet | `test/`, `integration_test/` | `flutter test`, `dart test`, git en lecture |
| code-reviewer | sonnet | rien | `git diff`, `git log`, `git show`, `git status`, `flutter analyze`, `dart analyze` |
| devops-engineer | sonnet | `.github/` | `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status`, `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, `git remote -v`, git en lecture |

Ces limites sont imposées par le hook agent-scope-guard, pas seulement par la consigne ; un agent du plugin sans périmètre déclaré y est bloqué. Une commande à la fois, sans `;`, `&&`, `|` ni redirection. devops-engineer ne pousse rien, n'ouvre pas de PR et ne relance pas de CI : ces actions restent dans la session principale, derrière un point de validation.

## Économiser le quota

- Tests ciblés pendant le développement ; suite complète et analyse aux jalons seulement.
- Les agents ne sont lancés qu'aux étapes 6 et 13 de `create-feature`, pour une architecture non triviale, pour le PRD d'un brief long, pour les documents d'une adoption, pour les builds par plateforme et pour lire les journaux d'une CI rouge.
- Aucune boucle de nouvelle tentative : après deux échecs identiques d'une commande, le workflow s'arrête et explique.
- Si une limite d'usage tombe, rien n'est perdu : le checkpoint est écrit après chaque étape. Relancez avec `recover-session`.
