# plugin-flutter

Plugin Claude Code pour les applications Flutter et Dart, à utiliser avec [plugin-orchestrator](https://github.com/soonlysoul/plugin-orchestrator). L'orchestrateur mène le projet — démarrage, fonctionnalités en TDD, Git, GitHub, reprise, débogage — et confie à plugin-flutter tout ce qui demande de comprendre Flutter : le squelette de l'app, ses tests, sa revue, son architecture, ses builds et sa CI, la mise à jour de ses dépendances, l'adoption d'une app existante. Il ne contient aucune dépendance propre à une application et sert à plusieurs projets.

Version **1.0.0**. Claude Code **2.1.295 ou plus** et plugin-orchestrator **0.1.0 ou plus** requis.

## Ce que fait le plugin

Depuis la 1.0, les workflows communs à tous les langages sont ceux de plugin-orchestrator (`/plugin-orchestrator:bootstrap-project`, `create-feature`, `git-workflow`, `github-workflow`, `recover-session`, `debug-project`), comme les garde-fous communs (commandes destructives, secrets, fichiers sensibles, rappel du checkpoint). L'orchestrateur envoie un **mandat** à un agent de plugin-flutter, qui rend un rapport terminé par `INTERFACE: 1` : la version du contrat de délégation, vérifiée avant que le rapport serve.

| Composant | Rôle |
| --- | --- |
| Skill `update-project` | Met à jour les dépendances par lots que vous validez, sur une branche `chore/deps-<slug>` : analyse et tests après chaque lot, un commit par lot avec son lockfile, rapport avant/après. Ne change jamais la version de Flutter elle-même |
| Skill `adopt-existing-project` | Prend en charge une app Flutter existante : analyse en lecture seule, plan de mise en conformité que vous validez, puis `.forge/` au format de l'orchestrateur, documents reconstruits depuis le code et liste des divergences |
| Agent `scaffold-engineer` | Crée l'app au démarrage d'un projet (mandat `scaffold` de l'orchestrateur) : `flutter create`, structure, modes stricts de l'analyseur, TRD en DRAFT, test de base vert ; rend la toolchain, les règles de permission Flutter, les versions et les plateformes |
| Agent `flutter-architect` | TRD, décisions (ADR), compatibilité d'une dépendance avec les plateformes (`check-dependency`), diagnostic d'un comportement de Flutter (`diagnose`) ; écrit seulement sous `docs/` |
| Agent `test-engineer` | Écrit les tests d'abord et rapporte la sortie ROUGE (`write-tests`), ou un test de non-régression ; écrit seulement sous `test/` et `integration_test/` |
| Agent `code-reviewer` | Relit le diff sans rien écrire (`review`) ; constats bloquant / important / mineur, et divergences avec les documents |
| Agent `devops-engineer` | Pose la CI Flutter (`ci-template`), builde chaque plateforme (`build`), diagnostique une CI rouge à partir de ses journaux ; écrit seulement sous `.github/`, ne pousse rien |
| Hook `agent-scope-guard` | Impose à chaque agent du plugin ses dossiers d'écriture et sa liste de commandes |
| Hook `format-dart` | `dart format` sur chaque fichier `.dart` modifié |

## Démarrage rapide

Prérequis : Claude Code ≥ 2.1.295, `git`, `jq`, Flutter (canal stable) ; pour GitHub, `gh` connecté ; gitleaks recommandé.

Sur chaque appareil, depuis la marketplace publique `soon`, les deux plugins :

```bash
claude plugin marketplace add soonlysoul/claude-plugins
claude plugin install plugin-orchestrator@soon --scope user
claude plugin install plugin-flutter@soon --scope user
```

Sans clé SSH GitHub sur l'appareil, exportez d'abord `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` (voir [Installation](docs/INSTALLATION.md#installer-sur-un-appareil)).

Puis créez un dossier vide pour le projet, ouvrez Claude Code **dans ce dossier**, et lancez :

```bash
mkdir mon_app && cd mon_app && claude
```

```
/plugin-orchestrator:bootstrap-project une appli de notes en Flutter
```

Le dossier où la session est lancée sert de racine du projet aux hooks et aux règles de permission.

Pour une app Flutter qui existe déjà : ouvrez Claude Code à sa racine, sur sa branche principale, sans modification en cours, et lancez `/plugin-flutter:adopt-existing-project`. Rien n'est écrit avant que vous ayez validé son plan.

Un projet créé avec plugin-flutter 0.x se migre en ajoutant le bloc `parts` à `.forge/config.yaml` : voir [Installation](docs/INSTALLATION.md#migrer-un-projet-de-plugin-flutter-0x).

Pour l'essayer sans l'installer, depuis des copies des deux dépôts : `claude --plugin-dir /chemin/vers/plugin-flutter --plugin-dir /chemin/vers/plugin-orchestrator`.

## Documentation

- [Installation, migration, mise à jour, désinstallation](docs/INSTALLATION.md)
- [Guide d'utilisation](docs/USER_GUIDE.md)
- [Sécurité : les trois couches et leurs limites](docs/SECURITY.md)
- [Dépannage](docs/TROUBLESHOOTING.md)
- [Journal des versions](CHANGELOG.md)
- Rapports de validation de la [v0.1](docs/V0.1_REPORT.md), de la [v0.2](docs/V0.2_REPORT.md) et de la [v0.3](docs/V0.3_REPORT.md)
- [Architecture](ARCHITECTURE.md), pour qui veut faire évoluer le plugin

## Tests du plugin

```bash
bash tests/run-all.sh
```

Tests déterministes en bash + `jq`, sans réseau, sans session Claude, sans quota. Les scénarios comportementaux de `tests/scenarios/` consomment du quota et ne se lancent qu'à la main.

## Licence

MIT — voir [LICENSE](LICENSE).
