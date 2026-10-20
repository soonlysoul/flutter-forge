# Installation

## Prérequis

| Outil | Version | Pourquoi |
| --- | --- | --- |
| Claude Code | **2.1.295 ou plus** | Les hooks déclarent `onFailure`, apparu en 2.1.295. Une version antérieure ne garantit pas le blocage en cas d'erreur d'un hook |
| `jq` | toute version récente | Les hooks lisent leur entrée JSON avec `jq`. **Sans lui, guard-destructive bloque toutes les commandes shell** (fail-closed) |
| `git` | 2.x | Workflows, checkpoint-reminder |
| Flutter et Dart | canal stable | Projets générés, `format-dart` |
| `bash` | 5.x vérifié | Les hooks s'appellent par `bash` sur le `PATH`. bash 3.2 (macOS par défaut) : non vérifié |
| `gh` | 2.x, connecté (`gh auth login`) | Skill `github-workflow` et agent devops-engineer seulement. Vérifié avec 2.101.0 |
| gitleaks | 8.19 ou plus, **facultatif, recommandé** | Lancé par `secret-scan` s'il est sur le `PATH` ; sans lui, seuls quelques motifs sont détectés. Vérifié avec 8.30.1. Sous NixOS : `home.packages = [ pkgs.gitleaks ];` |

Vérifier : `claude --version`, `jq --version`, `git --version`, `flutter --version`, `gh auth status`, `gitleaks version`.

**NixOS** : `/bin/bash` n'existe pas. Le plugin n'en dépend pas : ses hooks sont lancés en forme exec (`"command": "bash"`), résolue par le `PATH`.

## Essayer sans installer

```bash
claude --plugin-dir /chemin/vers/plugin-flutter
```

Le plugin vaut pour cette session seulement et apparaît comme `plugin-flutter@inline`. Après une modification de ses fichiers : `/reload-plugins`.

## Installer sur un appareil

Le plugin est publié dans le dépôt public [`soonlysoul/plugin-flutter`](https://github.com/soonlysoul/plugin-flutter) et proposé par la marketplace `soon`, elle-même dans le dépôt public [`soonlysoul/claude-plugins`](https://github.com/soonlysoul/claude-plugins). Aucun compte GitHub n'est nécessaire.

En shell :

```bash
claude plugin marketplace add soonlysoul/claude-plugins
claude plugin install plugin-flutter@soon --scope user
```

En session : `/plugin marketplace add soonlysoul/claude-plugins`, puis `/plugin install plugin-flutter@soon`, et confirmer dans le panneau.

**Appareil sans clé SSH GitHub.** Claude Code essaie d'abord SSH pour un dépôt GitHub. Exportez `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` (par exemple dans le profil du shell) pour passer directement par HTTPS : sans cette variable, l'installation depuis `/plugin` et les mises à jour échouent sur un tel appareil, même si `claude plugin install` en shell réussit.

## Installer depuis la marketplace locale (développement)

Le dossier du plugin est aussi une marketplace, nommée `plugin-flutter`. Le plugin y est lu sur place : chaque modification s'applique sans réinstaller.

```bash
claude plugin marketplace add /chemin/vers/plugin-flutter
claude plugin install plugin-flutter@plugin-flutter --scope user
```

N'ajoutez pas les deux marketplaces, `soon` et `plugin-flutter`, sur la même machine : le plugin y serait installé deux fois, avec ses hooks en double.

### Choisir la portée

| Portée | Effet |
| --- | --- |
| `user` | Le plugin est actif dans **toutes** vos sessions. Ses hooks protègent donc tous vos projets, pas seulement les projets Flutter |
| `project` | Actif pour ce projet, pour tous ceux qui l'ouvrent ; déclaré dans le `.claude/settings.json` du projet |
| `local` | Actif pour ce projet, pour vous seul |

Les hooks restent inertes hors de leur contexte : `format-dart` ne touche que les `.dart`, `checkpoint-reminder` ne parle qu'en présence de `.forge/checkpoint.md`, `agent-scope-guard` ne vise que les cinq agents du plugin, `protect-sensitive` n'agit que dans un projet qui a `.forge/` (sauf pour `.forge/config.yaml`). `guard-destructive` et `secret-scan` agissent partout, et c'est voulu : une commande destructive ou un secret commité sont un problème dans n'importe quel dépôt.

## Vérifier l'installation

```bash
claude plugin details plugin-flutter
```

Attendu : 8 skills, 5 agents, des hooks sur `PreToolUse`, `PostToolUse` et `Stop`, environ 1 650 jetons ajoutés à chaque session. Un skill ne charge son contenu qu'à son invocation : environ 4 700 jetons pour update-project ou adopt-existing-project.

Depuis le dossier du plugin, la suite de tests déterministes :

```bash
bash tests/run-all.sh
```

## La première ouverture d'un projet généré

bootstrap-project propose d'installer des règles de permission dans `<projet>/.claude/settings.json`. Trois points à connaître :

- les règles `allow` du projet ne s'appliquent **qu'après acceptation de la confiance du workspace**, à la première session interactive ouverte dans ce dossier ; `deny` et `ask` s'appliquent toujours ;
- ouvrez la session **à la racine du projet** : c'est elle qui fixe `CLAUDE_PROJECT_DIR`, que les hooks utilisent comme racine ;
- en mode non interactif (`claude -p`), Claude Code refuse l'écriture de `.claude/settings.json`, qu'il protège. bootstrap-project donne alors la commande de copie à lancer vous-même : `! mkdir -p <projet>/.claude && cp <plugin>/templates/project-settings.json <projet>/.claude/settings.json`, avec `.` pour le dossier courant. De même pour `.forge/config.yaml`, que le hook protect-sensitive protège : le skill donne la commande `! … sed … > <projet>/.forge/config.yaml` qui le crée.

## Mettre à jour un projet créé avec la v0.2

Les fichiers d'un projet vous appartiennent : une mise à jour du plugin ne les touche pas. Pour profiter des règles de la v0.3, qui servent à `update-project`, ajoutez à la main dans `<projet>/.claude/settings.json` :

- en `allow` : `Bash(flutter pub get --enforce-lockfile)`, `Bash(flutter pub outdated)`, `Bash(flutter pub outdated *)`, `Bash(flutter pub deps)`, `Bash(flutter pub deps *)`, `Bash(flutter pub add --dry-run *)`, `Bash(git status *)`, `Bash(flutter --version --machine)` ;
- en `ask` : `Bash(flutter pub upgrade)`, `Bash(flutter upgrade*)`, `Bash(flutter downgrade*)`, `Bash(flutter channel *)`.

Sans elles, le skill fonctionne, mais Claude demande la permission pour chaque commande d'inventaire. Le format de `.forge/` ne change pas.

Une app Flutter qui n'a jamais eu de `.forge/` s'adopte par `/plugin-flutter:adopt-existing-project` (voir le [guide](USER_GUIDE.md#adopter-une-app-existante--adopt-existing-project)).

## Mettre à jour un projet créé avec la v0.1

Ajoutez à la main dans `<projet>/.claude/settings.json` les règles de la v0.2, puis celles de la v0.3 (section précédente) :

- en `allow` : `Bash(gh --version)`, `Bash(gh auth status)`, `Bash(gh repo view)`, `Bash(gh repo view *)`, `Bash(gh pr view *)`, `Bash(gh pr checks *)`, `Bash(gh run list *)`, `Bash(gh run view *)`, `Bash(gh run watch *)`, `Bash(gh workflow list)`, `Bash(gh workflow view *)`, `Bash(gh issue list *)`, `Bash(gh issue view *)`, `Bash(git remote -v)`, `Bash(git rev-parse *)`, `Bash(git branch --show-current)`, `Bash(flutter --version)`, `Bash(flutter doctor)`, `Bash(flutter doctor *)`, `Bash(flutter devices)`, `Bash(flutter build *)` ;
- en `ask` : `Bash(gh repo create *)`, `Bash(gh pr edit *)`, `Bash(gh issue create *)`, `Bash(gh run rerun *)`, `Bash(gh workflow run *)`.

Le format de `.forge/` ne change pas. La CI s'ajoute par `/plugin-flutter:github-workflow ci`.

## Mettre à jour

- **Marketplace locale** : le plugin est lu sur place. Une modification de ses fichiers s'applique à la session suivante, ou tout de suite par `/reload-plugins`. Rien à réinstaller, et `version` n'y change rien.
- **Marketplace `soon`** : `claude plugin marketplace update soon`, puis `claude plugin update plugin-flutter@soon`. Un appareil ne reçoit une nouvelle copie que si la `version` du plugin a changé. Pour ne plus y penser : `/plugin` → Marketplaces → `soon` → *Enable auto-update*.

## Désinstaller

```bash
claude plugin uninstall plugin-flutter@soon --scope user
claude plugin marketplace remove soon     # retire aussi la marketplace et ses plugins
```

En session : `/plugin uninstall plugin-flutter`.

Les projets générés gardent leurs fichiers (`.forge/`, `.claude/settings.json`, docs) : ils vous appartiennent.
