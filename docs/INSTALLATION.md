# Installation

## Prérequis

| Outil | Version | Pourquoi |
| --- | --- | --- |
| Claude Code | **2.1.295 ou plus** | Les hooks déclarent `onFailure`, apparu en 2.1.295. Une version antérieure ne garantit pas le blocage en cas d'erreur d'un hook |
| plugin-orchestrator | **0.1.0 ou plus**, installé avec plugin-flutter ; **0.1.1 ou plus** pour démarrer un nouveau projet, dont le mandat `scaffold` accepte le `.gitignore` qu'écrit `flutter create` | Les workflows (démarrage, fonctionnalités, Git, GitHub, reprise, débogage) et les garde-fous communs sont les siens. Sans lui, les skills de plugin-flutter s'arrêtent d'abord en le nommant, et ses agents n'ont personne pour les mandater |
| `jq` | toute version récente | Les hooks lisent leur entrée JSON avec `jq`. Sans lui, agent-scope-guard bloque tous les appels des agents du plugin, et le guard-destructive de l'orchestrateur toutes les commandes shell (fail-closed) |
| `git` | 2.x | Workflows de l'orchestrateur, mise à jour des dépendances, adoption |
| Flutter et Dart | canal stable | Projets générés, `format-dart` |
| `bash` | 5.x vérifié | Les hooks s'appellent par `bash` sur le `PATH`. bash 3.2 (macOS par défaut) : non vérifié |
| `gh` | 2.x, connecté (`gh auth login`) | Agent devops-engineer, sur les mandats du github-workflow de l'orchestrateur. Vérifié avec 2.101.0 |
| gitleaks | 8.19 ou plus, **facultatif, recommandé** | Lancé par le secret-scan de l'orchestrateur s'il est sur le `PATH`. Sous NixOS : `home.packages = [ pkgs.gitleaks ];` |

Vérifier : `claude --version`, `jq --version`, `git --version`, `flutter --version`, `gh auth status`, `gitleaks version`.

**NixOS** : `/bin/bash` n'existe pas. Le plugin n'en dépend pas : ses hooks sont lancés en forme exec (`"command": "bash"`), résolue par le `PATH`.

## Essayer sans installer

```bash
claude --plugin-dir /chemin/vers/plugin-flutter --plugin-dir /chemin/vers/plugin-orchestrator
```

Les deux plugins valent pour cette session seulement et apparaissent comme `plugin-flutter@inline` et `plugin-orchestrator@inline`, à la place d'une copie installée du même nom. Après une modification de leurs fichiers : `/reload-plugins`.

## Installer sur un appareil

Les deux plugins sont publiés dans les dépôts publics [`soonlysoul/plugin-flutter`](https://github.com/soonlysoul/plugin-flutter) et [`soonlysoul/plugin-orchestrator`](https://github.com/soonlysoul/plugin-orchestrator), et proposés par la marketplace `soon`, elle-même dans le dépôt public [`soonlysoul/claude-plugins`](https://github.com/soonlysoul/claude-plugins). Aucun compte GitHub n'est nécessaire. Installez-les **ensemble** : l'un sans l'autre, les skills concernées s'arrêtent en nommant le plugin manquant.

En shell :

```bash
claude plugin marketplace add soonlysoul/claude-plugins
claude plugin install plugin-orchestrator@soon --scope user
claude plugin install plugin-flutter@soon --scope user
```

En session : `/plugin marketplace add soonlysoul/claude-plugins`, puis `/plugin install plugin-orchestrator@soon` et `/plugin install plugin-flutter@soon`, et confirmer dans le panneau.

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
| `user` | Le plugin est actif dans **toutes** vos sessions |
| `project` | Actif pour ce projet, pour tous ceux qui l'ouvrent ; déclaré dans le `.claude/settings.json` du projet |
| `local` | Actif pour ce projet, pour vous seul |

Donnez la même portée aux deux plugins. Les hooks de plugin-flutter restent inertes hors de leur contexte : `format-dart` ne touche que les `.dart`, `agent-scope-guard` ne vise que les cinq agents du plugin. Les garde-fous qui agissent partout — commandes destructives, secrets — sont ceux de l'orchestrateur.

## Vérifier l'installation

```bash
claude plugin details plugin-flutter
```

Attendu : 2 skills, 5 agents, des hooks sur `PreToolUse` et `PostToolUse`, environ 1 070 jetons ajoutés à chaque session. Un skill ne charge son contenu qu'à son invocation : environ 5 500 jetons pour update-project, 5 800 pour adopt-existing-project.

Depuis le dossier du plugin, la suite de tests déterministes :

```bash
bash tests/run-all.sh
```

## La première ouverture d'un projet

Le `bootstrap-project` de l'orchestrateur, comme `adopt-existing-project`, propose d'installer des règles de permission dans `<projet>/.claude/settings.json` : les règles génériques de l'orchestrateur et celles de Flutter (`templates/permissions-fragment.json`, rendues par le scaffold-engineer). Trois points à connaître :

- les règles `allow` du projet ne s'appliquent **qu'après acceptation de la confiance du workspace**, à la première session interactive ouverte dans ce dossier ; `deny` et `ask` s'appliquent toujours ;
- ouvrez la session **à la racine du projet** : c'est elle qui fixe `CLAUDE_PROJECT_DIR`, que les hooks utilisent comme racine, et le scaffold-engineer ne crée l'app que là ;
- en mode non interactif (`claude -p`), Claude Code refuse l'écriture de `.claude/settings.json`, qu'il protège : le skill donne la commande de copie à lancer vous-même. De même pour `.forge/config.yaml`, que le protect-sensitive de l'orchestrateur protège.

## Migrer un projet de plugin-flutter 0.x

Les fichiers d'un projet vous appartiennent : la mise à jour du plugin ne les touche pas, et Claude n'édite jamais `.forge/config.yaml`. Après avoir installé les deux plugins et ouvert une nouvelle session :

1. **`.forge/config.yaml`**, à éditer vous-même : `schema_version: 2`, le bloc `platforms:` de premier niveau retiré, et ce bloc `parts` ajouté, avec vos plateformes. Les skills des deux plugins le montrent quand elles trouvent un fichier sans `parts`, et s'arrêtent jusque-là.

   ```yaml
   parts:
     app:
       path: .
       plugin: plugin-flutter
       interface: 1
       toolchain:
         test: flutter test
         format: dart format --output=none --set-exit-if-changed .
         analyze: flutter analyze
         add_dep: flutter pub add
         manifests: [pubspec.yaml, pubspec.lock]
         # integration_test: flutter test integration_test -d <device id from flutter devices>   # optional
       platforms: [android, web, linux]
   ```

   La ligne `integration_test` reste un commentaire tant qu'aucun appareil n'y est nommé : les tests d'intégration sont alors classés bloqués. Pour les lancer, décommentez-la avec un identifiant que `flutter devices` affiche (`linux` sur une machine Linux, `chrome` pour le web).

2. **`.claude/settings.json`**, facultatif : les règles génériques que l'orchestrateur ajoute — en `allow` : `Bash(git --version)`, `Bash(jq --version)`, `Bash(git show *)`, `Bash(git ls-files)`, `Bash(git ls-files *)` ; en `deny` : `Read(./**/*.jks)`, `Read(./**/*.keystore)`, `Read(./**/*.p12)`, `Read(./**/*.pfx)`. Un projet de la v0.1 ou de la v0.2 trouve toutes les règles de la 1.0 dans `templates/project-settings.json` du plugin, à comparer avec le sien.
3. **Documents.** Un PRD ou un TRD approuvé sous la 0.x n'a pas d'empreinte dans `.forge/approvals.log` : le doc-status-guard de l'orchestrateur le repasse en REVIEW à sa première modification. Le `create-feature` de l'orchestrateur demande alors votre approbation, et la consigne.
4. **`CLAUDE.md`** du projet : il nomme encore `/plugin-flutter:create-feature` et ses voisins. Remplacez-les par `/plugin-orchestrator:…`, comme dans `templates/doc-templates/CLAUDE.md` du plugin.

Tant que plugin-flutter 0.x reste installé à côté de l'orchestrateur, les hooks communs tournent en double (mêmes blocages, en plus lent) et l'orchestrateur refuse de lui confier quoi que ce soit : ses agents ne répondent pas `INTERFACE: 1`. La mise à jour vers la 1.0 règle les deux.

Une app Flutter qui n'a jamais eu de `.forge/` s'adopte par `/plugin-flutter:adopt-existing-project` (voir le [guide](USER_GUIDE.md#adopter-une-app-existante--adopt-existing-project)).

## Mettre à jour

- **Marketplace locale** : le plugin est lu sur place. Une modification de ses fichiers s'applique à la session suivante, ou tout de suite par `/reload-plugins`. Rien à réinstaller, et `version` n'y change rien.
- **Marketplace `soon`** : `claude plugin marketplace update soon`, puis `claude plugin update plugin-orchestrator@soon` et `claude plugin update plugin-flutter@soon`. Un appareil ne reçoit une nouvelle copie que si la `version` du plugin a changé. Pour ne plus y penser : `/plugin` → Marketplaces → `soon` → *Enable auto-update*.

## Désinstaller

```bash
claude plugin uninstall plugin-flutter@soon --scope user
claude plugin uninstall plugin-orchestrator@soon --scope user
claude plugin marketplace remove soon     # retire aussi la marketplace et ses plugins
```

En session : `/plugin uninstall plugin-flutter`.

Les projets gardent leurs fichiers (`.forge/`, `.claude/settings.json`, docs) : ils vous appartiennent.
