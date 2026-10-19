# Installation

## Prérequis

| Outil | Version | Pourquoi |
| --- | --- | --- |
| Claude Code | **2.1.295 ou plus** | Les hooks déclarent `onFailure`, apparu en 2.1.295. Une version antérieure ne garantit pas le blocage en cas d'erreur d'un hook |
| `jq` | toute version récente | Les hooks lisent leur entrée JSON avec `jq`. **Sans lui, guard-destructive bloque toutes les commandes shell** (fail-closed) |
| `git` | 2.x | Workflows, checkpoint-reminder |
| Flutter et Dart | canal stable | Projets générés, `format-dart` |
| `bash` | 5.x vérifié | Les hooks s'appellent par `bash` sur le `PATH`. bash 3.2 (macOS par défaut) : non vérifié |

Vérifier : `claude --version`, `jq --version`, `git --version`, `flutter --version`.

**NixOS** : `/bin/bash` n'existe pas. Le plugin n'en dépend pas : ses hooks sont lancés en forme exec (`"command": "bash"`), résolue par le `PATH`.

## Essayer sans installer

```bash
claude --plugin-dir /chemin/vers/dart-multiplatform-forge
```

Le plugin vaut pour cette session seulement et apparaît comme `dart-multiplatform-forge@inline`. Après une modification de ses fichiers : `/reload-plugins`.

## Installer depuis la marketplace locale

Le dossier du plugin est aussi une marketplace, nommée `dart-multiplatform-forge`.

En shell :

```bash
claude plugin marketplace add /chemin/vers/dart-multiplatform-forge
claude plugin install dart-multiplatform-forge@dart-multiplatform-forge --scope user
```

En session : `/plugin marketplace add /chemin/vers/dart-multiplatform-forge`, puis `/plugin install dart-multiplatform-forge@dart-multiplatform-forge`, et confirmer dans le panneau.

### Choisir la portée

| Portée | Effet |
| --- | --- |
| `user` | Le plugin est actif dans **toutes** vos sessions. Ses hooks protègent donc tous vos projets, pas seulement les projets Flutter |
| `project` | Actif pour ce projet, pour tous ceux qui l'ouvrent ; déclaré dans le `.claude/settings.json` du projet |
| `local` | Actif pour ce projet, pour vous seul |

Les hooks restent inertes hors de leur contexte : `format-dart` ne touche que les `.dart`, `checkpoint-reminder` ne parle qu'en présence de `.forge/checkpoint.md`, `agent-scope-guard` ne vise que les trois agents du plugin. Seul `guard-destructive` agit partout, et c'est voulu.

## Vérifier l'installation

```bash
claude plugin details dart-multiplatform-forge
```

Attendu : 4 skills, 3 agents, des hooks sur `PreToolUse`, `PostToolUse` et `Stop`, environ 850 jetons ajoutés à chaque session.

Depuis le dossier du plugin, la suite de tests déterministes :

```bash
bash tests/run-all.sh
```

## La première ouverture d'un projet généré

bootstrap-project propose d'installer des règles de permission dans `<projet>/.claude/settings.json`. Trois points à connaître :

- les règles `allow` du projet ne s'appliquent **qu'après acceptation de la confiance du workspace**, à la première session interactive ouverte dans ce dossier ; `deny` et `ask` s'appliquent toujours ;
- ouvrez la session **à la racine du projet** : c'est elle qui fixe `CLAUDE_PROJECT_DIR`, que les hooks utilisent comme racine ;
- en mode non interactif (`claude -p`), Claude Code refuse l'écriture de `.claude/settings.json`, qu'il protège. bootstrap-project donne alors la commande de copie à lancer vous-même : `! mkdir -p .claude && cp <plugin>/templates/project-settings.json .claude/settings.json`.

## Mettre à jour

- **Marketplace locale** : le plugin est lu sur place. Une modification de ses fichiers s'applique à la session suivante, ou tout de suite par `/reload-plugins`. Rien à réinstaller, et `version` n'y change rien.
- **Marketplace GitHub** (plus tard) : `claude plugin marketplace update dart-multiplatform-forge`, puis `claude plugin update dart-multiplatform-forge@dart-multiplatform-forge`.

## Désinstaller

```bash
claude plugin uninstall dart-multiplatform-forge@dart-multiplatform-forge --scope user
claude plugin marketplace remove dart-multiplatform-forge     # retire aussi la marketplace et ses plugins
```

En session : `/plugin uninstall dart-multiplatform-forge`.

Les projets générés gardent leurs fichiers (`.forge/`, `.claude/settings.json`, docs) : ils vous appartiennent.
