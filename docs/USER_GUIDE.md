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

Ces limites sont imposées par le hook agent-scope-guard, pas seulement par la consigne. Une commande à la fois, sans `;`, `&&`, `|` ni redirection.

## Économiser le quota

- Tests ciblés pendant le développement ; suite complète et analyse aux jalons seulement.
- Les agents ne sont lancés qu'aux étapes 6 et 13, et pour une architecture non triviale.
- Aucune boucle de nouvelle tentative : après deux échecs identiques d'une commande, le workflow s'arrête et explique.
- Si une limite d'usage tombe, rien n'est perdu : le checkpoint est écrit après chaque étape. Relancez avec `recover-session`.
