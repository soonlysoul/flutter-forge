# dart-multiplatform-forge

Plugin Claude Code qui encadre la création et la maintenance d'applications Flutter et Dart : des workflows (skills), des spécialistes (agents) et des garde-fous déterministes (hooks). Il ne contient aucune dépendance propre à une application et sert à plusieurs projets.

Version **0.1.0**. Claude Code **2.1.295 ou plus** requis.

## Ce que fait la v0.1

Le cycle minimal : créer un projet, développer une fonctionnalité en TDD, committer proprement, reprendre après une interruption.

| Composant | Rôle |
| --- | --- |
| Skill `bootstrap-project` | Crée l'app : nom, package id et plateformes validés, `flutter create`, Git, documents de base en DRAFT, dossier `.forge/`, test de base vert |
| Skill `create-feature` | Une fonctionnalité en 15 étapes TDD : tests d'abord, ROUGE puis VERT consignés, revue indépendante, commit préparé |
| Skill `git-workflow` | Branches nommées, ajout explicite des fichiers, commits Conventional Commits, push d'une branche de travail seulement si préautorisé |
| Skill `recover-session` | Reprend un travail interrompu depuis le disque (checkpoint, Git), sans rien modifier avant votre accord |
| Agent `flutter-architect` | TRD, décisions (ADR), dépendances justifiées ; écrit seulement sous `docs/` |
| Agent `test-engineer` | Écrit les tests d'abord et rapporte la sortie ROUGE ; écrit seulement sous `test/` et `integration_test/` |
| Agent `code-reviewer` | Relit le diff sans rien écrire ; constats bloquant / important / mineur |
| Hook `guard-destructive` | Bloque `git reset --hard`, `push --force`, `rm -rf` hors `build/`, `gh repo delete`, `pub publish`… |
| Hook `agent-scope-guard` | Impose à chaque agent ses dossiers d'écriture et sa liste de commandes |
| Hook `format-dart` | `dart format` sur chaque fichier `.dart` modifié |
| Hook `checkpoint-reminder` | Rappelle une fois de mettre à jour `.forge/checkpoint.md` quand il est périmé |

## Démarrage rapide

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`, Flutter (canal stable).

```bash
claude plugin marketplace add /chemin/vers/dart-multiplatform-forge
claude plugin install dart-multiplatform-forge@dart-multiplatform-forge
```

Puis créez un dossier vide pour le projet, ouvrez Claude Code **dans ce dossier**, et lancez :

```bash
mkdir mon_app && cd mon_app && claude
```

```
/dart-multiplatform-forge:bootstrap-project mon_app
```

Le dossier où la session est lancée sert de racine du projet aux hooks et aux règles de permission.

Pour l'essayer sans l'installer : `claude --plugin-dir /chemin/vers/dart-multiplatform-forge`.

## Documentation

- [Installation, mise à jour, désinstallation](docs/INSTALLATION.md)
- [Guide d'utilisation](docs/USER_GUIDE.md)
- [Sécurité : les trois couches et leurs limites](docs/SECURITY.md)
- [Dépannage](docs/TROUBLESHOOTING.md)
- [Journal des versions](CHANGELOG.md)
- [Rapport de validation de la v0.1](docs/V0.1_REPORT.md)
- [Architecture](ARCHITECTURE.md), pour qui veut faire évoluer le plugin

## Tests du plugin

```bash
bash tests/run-all.sh
```

Tests déterministes en bash + `jq`, sans réseau, sans session Claude, sans quota. Les scénarios comportementaux de `tests/scenarios/` consomment du quota et ne se lancent qu'à la main.

## Licence

MIT — voir [LICENSE](LICENSE).
