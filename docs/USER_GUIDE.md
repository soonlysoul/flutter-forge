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
6. Documents de base en DRAFT : PRD (critères d'acceptation `AC-001`…), TRD, plan d'implémentation, DECISIONS (ADR-001).
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
| 13 | Revue | Les fichiers sont indexés, puis le code-reviewer relit `git diff --cached`, sans connaître le raisonnement de l'implémentation. Après correction, les étapes 11 et 12 sont relancées |
| 14 | Docs | Plan, DECISIONS, traçabilité |
| 15 | Commit | Préparé par git-workflow, que vous confirmez ; rapport final |

## Branches et commits — `git-workflow`

- Branches : `feature/`, `fix/`, `chore/deps-`, `docs/`.
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
| `reports/` | Rapports de revue | Les workflows |

Une clé absente de `config.yaml` vaut `false`. Les clés `merge` et `publish_release` sont ignorées : fusion et publication demandent toujours un accord explicite.

## Les agents

| Agent | Modèle | Peut écrire | Peut lancer |
| --- | --- | --- | --- |
| flutter-architect | celui de la session | `docs/` | `flutter --version`, `dart --version`, `dart pub deps`, `flutter pub deps`, git en lecture |
| test-engineer | sonnet | `test/`, `integration_test/` | `flutter test`, `dart test`, git en lecture |
| code-reviewer | sonnet | rien | `git diff`, `git log`, `git show`, `git status`, `flutter analyze`, `dart analyze` |
| devops-engineer | sonnet | `.github/` | `flutter build`, `flutter --version`, `flutter doctor`, `flutter devices`, `gh auth status`, `gh run list\|view\|watch`, `gh pr checks\|view`, `gh workflow list\|view`, `gh repo view`, `git remote -v`, git en lecture |

Ces limites sont imposées par le hook agent-scope-guard, pas seulement par la consigne. Une commande à la fois, sans `;`, `&&`, `|` ni redirection. devops-engineer ne pousse rien, n'ouvre pas de PR et ne relance pas de CI : ces actions restent dans la session principale, derrière un point de validation.

## Économiser le quota

- Tests ciblés pendant le développement ; suite complète et analyse aux jalons seulement.
- Les agents ne sont lancés qu'aux étapes 6 et 13 de `create-feature`, pour une architecture non triviale, pour les builds par plateforme et pour lire les journaux d'une CI rouge.
- Aucune boucle de nouvelle tentative : après deux échecs identiques d'une commande, le workflow s'arrête et explique.
- Si une limite d'usage tombe, rien n'est perdu : le checkpoint est écrit après chaque étape. Relancez avec `recover-session`.
