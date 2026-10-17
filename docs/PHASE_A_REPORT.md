# Rapport de phase A — dart-multiplatform-forge v0.1

| | |
| --- | --- |
| Date | 2026-10-17 |
| Claude Code installé | 2.1.296 |
| Document audité | `ARCHITECTURE.md` (statut DRAFT) |
| Statut proposé | REVIEW après intégration des corrections du §5 ; APPROVED sur votre accord explicite |

## 0. En bref

- Les 8 points de la doc officielle sont traités : **6 confirmés** (dont un par la doc seule, l'exécution headless relevant de la phase F) et **2 partiellement infirmés** : la restriction de Bash par motif dans un agent, et la mise à jour d'une marketplace locale.
- Deux constats pèsent sur la sécurité :
  - **un exit 1 ne bloque pas** : seul l'exit 2 bloque, et le champ `onFailure: "block"` couvre plantage, script absent et dépassement de délai ;
  - **les restrictions par agent ne s'expriment pas dans le frontmatter** ; un hook du plugin peut toutefois les imposer, car il reçoit `agent_type`.
- Rien de bloquant : Claude Code 2.1.296 couvre toutes les fonctions retenues. La plus récente, `onFailure`, date de la 2.1.295.
- Côté machine :
  - NixOS n'a pas de `/bin/bash` ;
  - Chrome est absent et le SDK Android incomplet ;
  - Linux desktop est opérationnel ;
  - `gitleaks` est absent (il ne sert qu'en v0.2).
- Neuf décisions vous reviennent (§7). Aucun fichier du plugin n'a été créé, hormis ce rapport et `PROGRESS.md`.

## 1. Environnement détecté

| Outil | Version | Chemin | Statut |
| --- | --- | --- | --- |
| claude | 2.1.296 | `~/.nix-profile/bin/claude` | OK |
| flutter | 3.44.3, canal stable (nixpkgs) | `~/.nix-profile/bin/flutter` | OK — stable courant : 3.47.7 (§4) |
| dart | 3.12.2 | `~/.nix-profile/bin/dart` | OK |
| git | 2.50.1 | `/run/current-system/sw/bin/git` | OK |
| gh | 2.72.0 | `/run/current-system/sw/bin/gh` | OK |
| jq | 1.7.1 | `/run/current-system/sw/bin/jq` | OK |
| gitleaks | — | — | **Absent**, non bloquant : secret-scan relève de la v0.2, avec repli regex prévu |

Plateformes, d'après `flutter doctor -v` (exit 0, « Doctor found issues in 2 categories ») :

| Cible | État sur cette machine |
| --- | --- |
| Linux desktop | OK : clang 19.1.7, cmake 4.1.2, ninja 1.13.2, pkg-config 0.29.2. Ces outils sont fournis par l'enveloppe Nix de Flutter et absents du PATH du shell |
| Android | SDK partiel : seuls les platform-tools 36 sont présents, `cmdline-tools` manque, donc build non garanti. `/dev/kvm` est présent. Un téléphone physique est branché (SM A566B, Android 16) : je ne l'utiliserai pas sans votre accord |
| Web | Chrome et Chromium absents : tests web impossibles localement ; `flutter build web` non vérifié |
| iOS, macOS, Windows | Non compilables sous Linux, comme le prévoit le document |

Autres constats :

- **`/bin/bash` n'existe pas sous NixOS** (`/bin/sh` et `/usr/bin/env` existent). Les exemples de la doc, et 23 fichiers de `plugin-dev`, utilisent `#!/bin/bash`, qui échouerait ici.
- Outils de test : `python3` est présent ; `yq`, PyYAML, `shellcheck` et `bats` sont absents. Les tests resteront en bash + jq pur, comme prévu.
- `bwrap` et `socat` sont absents : `claude plugin eval` refuse donc tout cas qui accorde Bash (§3.8).
- **`plugin-dev`** (version `ea10b213686c`) est installé depuis la marketplace **`claude-plugins-official`**, et non `anthropics/claude-code` comme l'indique la mission.
  - Il est antérieur à la doc actuelle : aucune mention de `onFailure`, `agent_type`, `${CLAUDE_SKILL_DIR}` ni `claude plugin validate`.
  - Il emploie `#!/bin/bash` et l'ancien `"decision": "approve"`.
  - Je m'en sers comme aide-mémoire ; en cas de conflit, la doc officielle et `claude plugin validate` priment.
- Superpowers n'est pas installé dans ce profil, alors que votre CLAUDE.md global le prévoit pour les tâches non triviales.
- Profil actif : `~/.claude` (`CLAUDE_CONFIG_DIR` non défini, aucun `.claude-profil` dans l'arborescence). C'est le compte que consommeraient les sessions headless de la phase F.
- Emplacement : le dossier est `~/Documents/claude-plugin/App`, hors de la convention `~/Documents/project-code/<projet>/` de votre CLAUDE.md. Je ne déplace rien (décision D6).

## 2. Sources

Toutes consultées le 2026-10-17. La doc en ligne décrit des fonctions jusqu'à la v2.1.301, plus récente que la version installée ; j'ai vérifié qu'aucune fonction retenue n'exige plus que la 2.1.296.

| Réf. | Source |
| --- | --- |
| S1 | Plugin manifest reference — https://code.claude.com/docs/en/plugins/manifest-reference |
| S2 | Marketplace reference — https://code.claude.com/docs/en/plugins/marketplace-reference |
| S3 | Create a marketplace — https://code.claude.com/docs/en/plugins/create-marketplace ; Publish — https://code.claude.com/docs/en/plugins/publish |
| S4 | Plugin commands reference — https://code.claude.com/docs/en/plugins/cli-reference ; Plugin loading — https://code.claude.com/docs/en/plugins/loading |
| S5 | Add components to a plugin — https://code.claude.com/docs/en/plugins/components |
| S6 | Create custom subagents — https://code.claude.com/docs/en/sub-agents |
| S7 | Skills — https://code.claude.com/docs/en/skills |
| S8 | Hooks reference — https://code.claude.com/docs/en/hooks |
| S9 | Configure permissions — https://code.claude.com/docs/en/permissions |
| S10 | Headless — https://code.claude.com/docs/en/headless ; CLI reference — https://code.claude.com/docs/en/cli-reference |
| S11 | Test plugins with evals — https://code.claude.com/docs/en/plugin-evals |
| S12 | Tools reference — https://code.claude.com/docs/en/tools-reference ; Interactive mode — https://code.claude.com/docs/en/interactive-mode |
| L1 | Aide locale : `claude --help`, `claude plugin {validate, marketplace, install, uninstall, update, enable, list, eval} --help` (2.1.296) |
| L2 | Sonde jetable dans le scratchpad de session (hors projet), passée à `claude plugin validate` ; détails au §3.1 |
| T1 | Index des versions Flutter — https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json |
| T2 | GitHub Actions billing — https://docs.github.com/en/billing/concepts/product-billing/github-actions ; page « Actions runner pricing » |
| T3 | Aide locale : `gh … --help` (2.72.0), `dart format --help` ; sortie de `flutter doctor -v` |

## 3. Points à vérifier, un par un

### 3.1 Champs exacts et obligatoires de `plugin.json` et `marketplace.json` — **Confirmé**, avec précisions

`plugin.json` (S1) :

- Seul `name` est obligatoire : kebab-case, sans espace, `@` ni `:`. `dart-multiplatform-forge` est valide et n'est pas réservé.
- `version`, `description` et `author` sont facultatifs, mais leur absence produit un avertissement, donc un échec sous `--strict`. Si `author` est présent, `author.name` est requis.
- `license` (identifiant SPDX) et `keywords` sont reconnus : **la forme attendue du document est valide telle quelle**.
- Un champ inconnu est retiré au chargement et signalé en avertissement.
- `homepage` doit être une URL valide, **faute de quoi le plugin ne se charge pas**. À n'ajouter qu'avec le dépôt GitHub.
- `version` fige les utilisateurs d'une installation distante sur cette version jusqu'à son changement. Elle est ignorée pour une marketplace locale, dont le plugin est lu sur place.
- Un `CLAUDE.md` à la racine du plugin n'est pas chargé et déclenche un avertissement.

`marketplace.json` (S2, S3) :

- Champs obligatoires : `name`, `owner` (avec `owner.name`) et `plugins`. Chaque entrée exige `name` et `source`.
- Une `description` manquante produit un avertissement.
- Quand le plugin et sa marketplace partagent un dépôt, l'entrée s'écrit `"source": "./"`, avec **le même `name`** que `plugin.json` (S3, page Publish).
- Ne pas répéter `version` dans l'entrée : celle de `plugin.json` prime, et le validateur avertit.

Vérifié par exécution (L2) :

- `plugin.json` et `marketplace.json` (`"source": "./"`) dans une même racine : `claude plugin validate` → exit 0 ; `--strict --json` → exit 0, `success: true`.
- Après ajout d'un champ inconnu : avertissement, et `--strict` → exit 1.

### 3.2 Commandes `/plugin …`, option `--plugin-dir`, existence de `claude plugin validate` — **Confirmé**, sauf « Mettre à jour », **infirmé** pour une marketplace locale

| Étape | Document | Constat (S4, L1) |
| --- | --- | --- |
| Test sans installation | `claude --plugin-dir ./dart-multiplatform-forge` | ✔ Le plugin vaut pour la session seule et apparaît comme `<nom>@inline`. Après une modification : `/reload-plugins`. Il prend le pas sur une copie installée du même nom |
| Ajouter la marketplace | `/plugin marketplace add ./…` | ✔ Existe aussi en shell : `claude plugin marketplace add <chemin> [--scope user\|project\|local]` |
| Installer | `/plugin install dart-multiplatform-forge@<mp>` | ✔ En session, la commande ouvre la fiche du plugin dans le panneau, où l'on confirme. En shell : `claude plugin install dart-multiplatform-forge@<mp> [-s user\|project\|local]` |
| Mettre à jour | `/plugin marketplace update <mp>` puis réinstaller | ✘ Une marketplace locale est **lue sur place** : une modification s'applique à la session suivante, ou par `/reload-plugins`, sans changer de version. Marketplace GitHub (plus tard) : `claude plugin marketplace update <mp>` puis `claude plugin update dart-multiplatform-forge@<mp>`, sans réinstallation |
| Désinstaller | `/plugin uninstall dart-multiplatform-forge` | ✔ En shell : `claude plugin uninstall dart-multiplatform-forge@<mp> [-s …]`. Pour retirer la marketplace : `claude plugin marketplace remove <mp>`, qui désinstalle aussi ses plugins |
| Valider | `claude plugin validate <chemin>` si disponible | ✔ Existe, avec `--strict` (avertissements = échec) et `--json`. Codes : 0 réussi, 1 échec, 2 erreur du validateur. Si la racine contient les deux manifestes, il valide les deux (≥ 2.1.289) |

- `/plugin` n'existe qu'en session interactive ; en `-p`, il répond qu'il n'est pas disponible.
- `claude plugin details <nom>` donne l'inventaire des composants et leur coût estimé en jetons ; utile en phase F.
- D'après la sonde L2, le validateur ne voit **pas** :
  - un script de hook absent, référencé dans `hooks.json` ;
  - un frontmatter d'agent `description: [unclosed` — sonde non concluante, le parseur étant peut-être tolérant.

  Nos tests statiques doivent couvrir ces deux cas.

### 3.3 Frontmatter des agents : champs, syntaxe de `tools`, restriction de Bash par motif — **Partiellement infirmé**

- **Champs (S5, S6) — confirmé.**
  - Obligatoires pour un agent de plugin : `name` et `description`.
  - Reconnus : `tools`, `disallowedTools`, `model`, `effort`, `maxTurns`, `autoCompactWindow`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation`, `color`, `experimental.cacheTtl`.
  - **Ignorés pour un agent de plugin** : `permissionMode`, `hooks`, `mcpServers`, `initialPrompt`.
- **Syntaxe de `tools` — confirmé.**
  - Chaîne séparée par des virgules (`Read, Grep, Glob, Bash`) ou liste YAML.
  - Champ omis : l'agent hérite de **tous** les outils.
  - `model` accepte `sonnet`, `opus`, `haiku`, `fable`, un identifiant complet, ou `inherit`.
- **Restreindre Bash par motif — infirmé.**
  - `disallowedTools: Bash(git push *)` retire Bash **en entier** (S6).
  - Un motif dans `tools` n'est pas documenté : non vérifiable sans session, et je ne m'y fierai pas.
  - Les mentions « Bash (lecture : `flutter --version`, `dart pub deps`) » et « Bash (`git diff`, `git log`, `flutter analyze`) » du tableau « Agents » ne s'expriment donc **pas dans le frontmatter**.
- **Limites d'écriture par dossier — une restriction plus fine existe, hors frontmatter.**
  - Les hooks du plugin s'exécutent aussi dans les sous-agents, et leur entrée porte `agent_type`, qui vaut `dart-multiplatform-forge:<nom>` pour un agent du plugin (S8).
  - Un hook `PreToolUse` peut donc refuser à `test-engineer` tout `Edit` ou `Write` hors de `test/` et `integration_test/`, et à `code-reviewer` toute commande Bash hors d'une liste blanche.
  - Proposition E4 au §5.
- **Risque silencieux.**
  - Un agent de plugin dont le frontmatter ne se parse pas se charge « avec tous les champs ignorés » (S5) : il perd son `tools`, donc reçoit tous les outils.
  - Un reviewer au YAML cassé gagnerait ainsi le droit d'écrire, sans le moindre message.
  - Le test de frontmatter doit donc être strict.
- **Orchestration.**
  - Un sous-agent n'a jamais `AskUserQuestion` : confirmé.
  - Il peut lancer des sous-agents si `Agent` figure dans ses `tools` (S6). Nos agents ne listeront pas `Agent`, et le test le vérifiera.
- **En session interactive, les sous-agents tournent en arrière-plan par défaut** (mode fork) : leur résultat arrive par notification, au tour suivant (S6). `create-feature` doit attendre le rapport du test-engineer avant l'étape 7.

### 3.4 Frontmatter des skills et règles de chargement automatique — **Confirmé**

- **Champs.** Tous sont facultatifs ; `description` est recommandée (S7). Champs utiles : `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context`, `agent`, `paths`, `hooks`.
- **Nom de commande** : `/dart-multiplatform-forge:<dossier>`. Un `name` dans le frontmatter remplace le dernier segment.
- **Chargement.**
  - La description est toujours en contexte, sauf avec `disable-model-invocation: true`.
  - Le contenu complet entre à l'invocation et **reste en contexte aux tours suivants**. C'est un coût récurrent, d'où la consigne de moins de 500 lignes et le renvoi vers des fichiers annexes.
  - `description` et `when_to_use` réunis sont tronqués à 1 536 caractères.
- **`allowed-tools`** accorde des outils sans invite pendant le tour, mais ne restreint rien. Je propose de ne pas l'utiliser en v0.1, pour que les permissions restent dans le `settings.json` du projet, seule source.
- **En `-p`**, `AskUserQuestion` n'est offert qu'en présence d'un hôte de permission (S8, S10). Les skills posent donc leurs questions de validation **en texte**, puis s'arrêtent.

### 3.5 `hooks.json` : format, événements, entrée JSON, codes de sortie — **Confirmé**, avec deux corrections de fond

**Format** (S1, S5) : `{"description": "…", "hooks": {"PreToolUse": [{"matcher": "…", "hooks": [{"type": "command", …}]}]}}`. Sans l'enveloppe `"hooks"`, le fichier ne se charge pas.

**Événements** :

- `PreToolUse`, `PostToolUse` et `Stop` sont les noms exacts.
- `Stop` n'a pas de matcher. `Edit|Write` est lu comme une liste de noms exacts.
- L'outil `MultiEdit` n'existe plus (S12).

**Entrée** (stdin) :

- Toujours : `session_id`, `cwd`, `hook_event_name`, `permission_mode` ; dans un sous-agent, en plus, `agent_id` et `agent_type`.
- `PreToolUse` : `tool_name`, `tool_input` (`command` pour Bash ; `file_path`, **toujours absolu**, pour Write et Edit) et `tool_use_id`.
- `PostToolUse` : les mêmes, plus `tool_response`.
- `Stop` : `stop_hook_active` et `last_assistant_message`.

**Bloquer** : exit 2, auquel cas stderr est transmis à Claude comme raison ; ou exit 0 avec `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "…"}}`.

**Correction 1 — le fail-closed.**

- **Un exit 1 ne bloque pas** : c'est une erreur non bloquante, et la commande passe.
- Un script qui plante, introuvable ou qui dépasse son délai laisse passer lui aussi, sauf si le hook déclare `"onFailure": "block"` (≥ 2.1.295, S8).
- Le fail-closed de guard-destructive exige donc les deux : `exit 2` sur toute erreur interne (`jq` absent, JSON illisible) **et** `"onFailure": "block"`.
- Version minimale à documenter : **2.1.295**.

**Correction 2 — la forme d'appel.**

- La doc recommande la forme exec dès qu'une commande cite `${CLAUDE_PLUGIN_ROOT}` : `"command": "bash", "args": ["${CLAUDE_PLUGIN_ROOT}/hooks/scripts/guard-destructive.sh"]`.
- Cette forme se passe de shell, de guillemets, de bit exécutable et de shebang, ce qui contourne aussi l'absence de `/bin/bash`.
- Validé par la sonde L2.

**`Stop`** :

- Un exit 2 ou `decision: "block"` **font reprendre Claude**. `hookSpecificOutput.additionalContext` le fait reprendre sans afficher d'erreur.
- `stop_hook_active` et un plafond de 8 reprises évitent les boucles.
- `onFailure` est sans effet sur `Stop`.
- `Stop` ne se déclenche ni sur interruption, ni sur erreur d'API : une coupure de quota déclenche `StopFailure`. Cela confirme le principe du checkpoint écrit après chaque étape.

**`PostToolUse`** ne peut pas bloquer ; un exit 2 y montre seulement stderr à Claude.

**Portée** : les hooks du plugin se déclenchent dans **toutes** les sessions où le plugin est activé, dès son chargement, que ses skills servent ou non (S5). Chaque hook doit donc rester inerte hors de son contexte.

**Couverture** : l'outil `Monitor` exécute lui aussi une commande shell, soumise aux mêmes règles que Bash (S12). Le matcher du guard doit donc être `Bash|Monitor`.

**Levée ponctuelle** :

- Une commande tapée par l'utilisateur avec le préfixe `!` s'exécute « sans passer par Claude » (S12). Ce n'est pas un appel d'outil, elle échappe donc à `PreToolUse`.
- C'est la voie naturelle d'une levée ponctuelle faite par l'utilisateur. La doc ne le dit qu'implicitement : à confirmer en phase F.

### 3.6 Disponibilité de `${CLAUDE_PLUGIN_ROOT}` dans les hooks et les skills — **Confirmé**

- **Hooks.** La variable est substituée dans `command` et `args`, et exportée dans l'environnement du processus avec `CLAUDE_PLUGIN_DATA` et `CLAUDE_PROJECT_DIR` (S1).
- **Skills et agents.** Elle est substituée **dans le corps Markdown** au chargement, ainsi que dans les règles Bash de `allowed-tools` (S1, S7).
- **Commandes Bash de Claude.** La variable n'existe **pas** dans leur environnement. Un skill doit donc écrire `${CLAUDE_PLUGIN_ROOT}/templates/…` dans son texte, et Claude reçoit le chemin absolu.
- **Fichiers annexes.** Seul le contenu de `SKILL.md` est substitué. Les fichiers lus par `Read`, comme les gabarits de `reference/doc-templates/`, ne doivent pas contenir la variable.
- **`${CLAUDE_SKILL_DIR}`** existe aussi et désigne le dossier du skill. Je propose de garder `${CLAUDE_PLUGIN_ROOT}` partout, comme le demande la mission.
- **Mises à jour.** La racine change à chaque mise à jour d'une installation distante : il ne faut y écrire aucun état. L'état vit dans `<projet>/.forge/`.

### 3.7 Un plugin peut-il fournir des règles de permission ? — **Confirmé : non** (l'hypothèse est juste)

- Le `settings.json` à la racine d'un plugin, comme la clé `settings` du manifeste, n'applique que `agent` et `subagentStatusLine` ; les autres clés sont ignorées (S1, S5).
- La couche 1 reste donc un gabarit que bootstrap-project copie dans le projet après accord.

Compléments utiles (S9) :

- Les règles `allow` d'un `.claude/settings.json` de projet ne s'appliquent qu'**après acceptation de la confiance du workspace** ; `deny` et `ask` s'appliquent toujours.
- L'ordre d'évaluation est `deny`, puis `ask`, puis `allow` : la première règle qui correspond l'emporte.
- Un hook qui bloque (exit 2) passe avant les `allow`, mais un hook ne peut lever ni un `deny` ni un `ask`.
- `Bash(x:*)` équivaut à `Bash(x *)` ; la doc et la boîte de dialogue écrivent la forme avec espace.
- Une règle Bash ne couvre que la forme écrite : `git -C . push` échappe à `Bash(git push *)`. Le hook reste la couche qui analyse la commande.

### 3.8 Exécution headless avec un plugin chargé — **Confirmé par la doc** ; exécution reportée à la phase F (quota)

- **Chargement.** `claude -p --plugin-dir <dossier> "…"` est supporté. Avec `--output-format stream-json`, l'événement `system/init` liste `plugins` et `plugin_errors` : on peut donc **prouver** que le plugin est chargé. `--include-hook-events` émet en plus les événements des hooks (S10, L1).
- **`--bare` est exclu.** Il n'utilise que `ANTHROPIC_API_KEY` ou un `apiKeyHelper`, jamais l'abonnement : l'employer reviendrait à basculer vers l'API payante, ce que vos règles interdisent.
- **Configuration chargée.** Sans `--bare`, la session charge aussi votre configuration utilisateur : `~/.claude`, `plugin-dev`, le CLAUDE.md global. C'est acceptable, et ce sera documenté.
- **Permissions.**
  - Dans un dossier jamais approuvé, `-p` **ignore les `allow` du projet** (avertissement sur stderr), mais applique `deny`, `ask` et les hooks.
  - Les scénarios passeront donc `--allowedTools` explicitement, avec `--permission-mode dontAsk` : le mode par défaut peut être `auto`, et `dontAsk` refuse tout ce qui n'est pas autorisé.
- **Scénarios à plusieurs tours** (points de validation) : `--session-id <uuid>`, puis `--resume <uuid> "<réponse>"`.
- **`--max-turns`** est documenté en ligne mais absent de `claude --help` en 2.1.296 : non vérifié.
- **`claude plugin eval`** existe (S11), mais je ne le retiens pas pour la v0.1 :
  - coût : 3 exécutions par cas, plus par défaut un bras témoin sans plugin ;
  - bac à sable : il exige `bubblewrap` et `socat` (absents) dès qu'on accorde Bash, et rend `$HOME` illisible, donc `~/.pub-cache` et Flutter avec ;
  - publication : il publie son rapport en artefact, sauf `--no-publish`.

## 4. Vérifications côté outils

| Point | Résultat | Source |
| --- | --- | --- |
| Version Flutter stable courante | **3.47.7** (Dart 3.13.5), publiée le 2026-10-08. Version installée : 3.44.3 / Dart 3.12.2 (nixpkgs 25.05), soit trois versions mineures de retard. Sans effet sur la v0.1 : bootstrap consigne `flutter --version` dans DECISIONS.md. Une mise à jour passerait par Nix, et relève de votre décision | T1 |
| `gh` 2.72.0 | Existent : `auth status` ; `repo create` (`--private`, `--public`, `--source`, `--push`) ; `repo delete` (scope `delete_repo` requis) ; `repo edit --visibility`, qui exige désormais `--accept-visibility-change-consequences` ; `pr create` (`-B -H -t -b -d`) ; `pr merge`. Le motif du guard doit détecter `--visibility` n'importe où dans `gh repo edit` | T3 |
| `dart` et `flutter` | `dart format --set-exit-if-changed` existe. `dart pub publish` existe en plus de `flutter pub publish` : le guard doit bloquer les deux | T3 |
| Quotas GitHub Actions | Gratuit pour les dépôts publics sur runners standard. Dépôts privés : Free 2 000 min/mois, Pro 3 000, Team 3 000, Enterprise Cloud 50 000. Tarifs : Linux 2 cœurs 0,006 $/min, Windows 0,010 $, macOS 0,062 $ (≈ 10 × Linux). La doc ne publie plus de table de « multiplicateurs » : **le décompte exact du quota inclus pour macOS est non vérifié** (sujet v0.2+) | T2 |

## 5. Écarts entre ARCHITECTURE.md et la doc officielle — corrections proposées

| # | Section | ARCHITECTURE.md | Constat | Correction proposée |
| --- | --- | --- | --- | --- |
| E1 | Manifeste, cycle de vie | « Mettre à jour : `marketplace update` puis réinstaller » | Une marketplace locale est lue sur place ; `claude plugin update` existe | En local : redémarrage ou `/reload-plugins`. Depuis GitHub : `claude plugin marketplace update <mp>`, puis `claude plugin update <id>` |
| E2 | Cycle de vie | Seulement des commandes `/plugin` | `/plugin` n'existe qu'en interactif | Documenter aussi les commandes shell `claude plugin …`, scriptables et utilisables dans les tests |
| E3 | Agents | Bash « lecture » limité par agent | Non exprimable dans le frontmatter | Colonne « Outils » réécrite : le frontmatter liste `Read, Grep, Glob, Bash[, Write, Edit]` ; les limites passent par la consigne et par E4 |
| E4 | Agents, risques | Limites par dossier « portées par la consigne et vérifiées par le reviewer » | Les hooks du plugin voient `agent_type` | **Nouveau hook `agent-scope-guard`** (`PreToolUse` ; `Edit\|Write\|NotebookEdit\|Bash\|Monitor`), actif seulement pour les trois agents du plugin, fail-closed. Il impose des chemins autorisés par agent et une liste blanche Bash : `git diff/log/show/status`, `flutter analyze` et `dart analyze` pour code-reviewer ; `flutter --version`, `dart pub deps` et git en lecture pour flutter-architect ; `flutter test` et `dart test` pour test-engineer. Le contrôle `git diff --name-only` du reviewer reste la seconde couche, car test-engineer peut encore écrire par Bash. **Hors du périmètre v0.1 strict → décision D2** |
| E5 | Agents | `model` sans valeur | Valeurs vérifiées (§3.3) | `sonnet` pour test-engineer et code-reviewer (économie de quota) ; `inherit` pour flutter-architect (jugement d'architecture) → D7 |
| E6 | Orchestration, TDD | Étapes 6 et 7 enchaînées | Sous-agents en arrière-plan par défaut | Consigne dans create-feature : « attendre le rapport du test-engineer avant l'étape 7 ; ne rien écrire en parallèle » |
| E7 | Hooks | guard « fail-closed » | Un exit 1 ne bloque pas | guard : `exit 2` sur toute erreur interne et `"onFailure": "block"`. format-dart : `exit 0` toujours et `"onFailure": "continue"`. Version minimale 2.1.295 dans INSTALLATION.md |
| E8 | Hooks | Filtre `Bash` | `Monitor` exécute aussi des commandes | Matcher `Bash\|Monitor`. Un appel `Monitor` sans `command` (mode WebSocket) est autorisé |
| E9 | Hooks | Liste du guard | Des formes équivalentes ne sont pas couvertes | Ajouter : `dart pub publish` ; `git push` avec `-f` ou `--force*` **à n'importe quelle position**, ainsi que la refspec `+ref`, forme abrégée d'un force-push ; `git branch --delete --force` ; `git checkout -- <chemin>` (pas seulement `.`) ; `rm` avec `-r` et `-f` dans n'importe quel ordre (`-fr`, `-Rf`, `--recursive --force`). **À trancher (D4)** : `git restore` hors `--staged`, qui jette des modifications non commitées comme `checkout -- .`, ainsi que `git stash drop` et `git stash clear` |
| E10 | Hooks | checkpoint-reminder « rappelle » | `Stop` peut faire reprendre Claude ou seulement prévenir l'utilisateur | `additionalContext` une seule fois, si `stop_hook_active` est faux, et seulement si `.forge/checkpoint.md` existe → D3 |
| E11 | Hooks | Scripts bash | `/bin/bash` absent sous NixOS | Forme exec : `bash` en `command`, le script dans `args`. Shebang `#!/usr/bin/env bash` pour l'exécution directe en test |
| E12 | Hooks, installation | — | Les hooks sont actifs dans toute session où le plugin est activé | Chaque hook reste inerte hors de son contexte (fichiers `.dart`, présence de `.forge/`). INSTALLATION.md explique les portées `user`, `project` et `local` : en portée `user`, le guard protège tous vos projets |
| E13 | Skills | Points de validation | `AskUserQuestion` indisponible en `-p` | Questions posées en texte, puis arrêt : même comportement en interactif et en headless |
| E14 | Couche 1 (gabarit) | `Bash(x:*)` ; liste `deny` | `:*` reste valide, mais la forme à espace est la norme ; la liste `deny` a des trous | Passer à la forme `Bash(x *)`. Ajouter aux `deny` : `Bash(git push --force*)`, `Bash(git push * --force*)`, `Bash(git push -f*)`, `Bash(git push * -f*)`, `Bash(git push * +*)`, `Bash(git branch -D *)`, `Bash(dart pub publish*)`, `Bash(flutter pub publish*)`, `Read(./.env.*)`, et **`Edit(./.forge/config.yaml)`**, qui protège la config dès la v0.1 (protect-sensitive restant en v0.2 ; `Edit()` et non `Write()`, comme le note votre CLAUDE.md). Ajouter aux `ask`, qui l'emportent sur `allow` : `Bash(git add -A*)`, `Bash(git add .)`, `Bash(git add --all*)`. Rappeler dans SECURITY.md que les `allow` attendent la confiance du workspace |
| E15 | Tests | Validateur intégré « peut-être » | Il existe, s'exécute en local, sans quota | Ajouter `claude plugin validate . --strict` à `run-all.sh`. Comme il ne voit ni le YAML des agents ni les scripts des hooks, `test_frontmatter.sh` les couvre (analyseur strict en bash/awk, frontmatter limité à des lignes `clé: valeur`), ainsi que `test_paths.sh`. `test_frontmatter.sh` vérifie aussi qu'aucun agent ne liste `Agent` |
| E16 | Scénarios | « headless avec le plugin chargé » | Contraintes du §3.8 | `claude -p --plugin-dir`, sans `--bare` ; `--permission-mode dontAsk` avec `--allowedTools` ; preuve de chargement par `stream-json` ; tours multiples par `--session-id` puis `--resume` ; pas de `plugin eval` en v0.1 |
| E17 | TDD | Le test-engineer « rend la sortie ROUGE », et l'étape 7 se tient en session principale | Les deux sont prévus en même temps | Le test-engineer lance ROUGE et le rapporte ; la session principale relance l'étape 7 pour consigner la preuve, conformément à la règle du rapport vérifié |
| E18 | Multiplateforme | `platforms.enabled: [android, web, linux]` | Seul Linux est vérifiable sur cette machine | Garder cette valeur par défaut, mais faire la démo de la phase F en `linux` seul |
| E19 | Méthode | « plugin-dev (marketplace anthropics/claude-code) » | Installé depuis `claude-plugins-official`, et antérieur à la doc | Skills de plugin-dev comme aide-mémoire. `claude plugin validate`, déterministe et gratuit, à chaque phase. Agent `skill-reviewer` une seule fois en fin de phase D (il coûte du quota). agent-creator n'est pas indispensable, le cahier des charges fixant déjà le contenu des agents → D9 |

## 6. Plan ajusté des phases B à G

Les commits sont locaux, au format Conventional Commits, sans push. `PROGRESS.md` est mis à jour après chaque étape.

**B — Squelette**

1. Après votre accord, reporter les corrections retenues dans `ARCHITECTURE.md` (statut → REVIEW), dans un commit séparé : `docs(architecture): apply phase A corrections`.
2. `git init -b main` dans le dossier validé (D6).
3. Créer l'arborescence v0.1, et elle seule.
4. Écrire `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (`"source": "./"` ; noms et auteur selon D5), `.gitignore` et `LICENSE` (MIT).
5. Vérifier : `claude plugin validate . --strict` doit sortir en 0.
6. Commit `chore: scaffold plugin skeleton`.

**C — Hooks et leurs tests**, en rouge puis vert : les tests sur entrées JSON simulées d'abord, les scripts ensuite.

- guard-destructive : une trentaine de commandes dangereuses et une trentaine de sûres, plus un JSON illisible, `jq` absent et un appel `Monitor`.
- format-dart : un `.dart` formaté, un autre fichier ignoré, `dart` absent sans erreur.
- checkpoint-reminder : rappel émis ; silence si `stop_hook_active` ; silence sans `.forge/`.
- `agent-scope-guard`, si D2 = oui.
- `hooks/hooks.json` en forme exec, puis commit `feat(hooks): …`.

**D — Agents, skills et gabarits**

- Frontmatter limité aux champs vérifiés, sans `Agent` dans `tools`. Rapport final au format STATUS / FILES_CHANGED / COMMANDS_RUN / OPEN_QUESTIONS.
- create-feature en 15 étapes, avec E6, E13 et E17.
- Références internes par `${CLAUDE_PLUGIN_ROOT}`.
- Gabarits : `project-settings.json` (corrigé selon E14), `forge-config.yaml`, `checkpoint.md`, et `reference/doc-templates/` (PRD, TRD, PLAN, DECISIONS).
- Une revue par `skill-reviewer`, puis commit `feat: add v0.1 agents and skills`.

**E — Tests déterministes.** `tests/run-all.sh` couvre les 8 fichiers du tableau, plus `claude plugin validate . --strict`. Sans réseau ni quota. Tout doit être vert avant le commit `test: …`.

**F — Validation réelle**, en deux temps.

1. **Sans quota** :
   - `flutter create` puis `flutter test` d'un projet jetable, pour vérifier que le Flutter de Nix fonctionne ici (non fait en phase A, pour rester dans le périmètre) ;
   - `claude --plugin-dir . plugin details dart-multiplatform-forge` ;
   - scénario 4 au niveau du seul hook.
2. **Avec quota** : je vous préviens et j'attends votre accord avant chaque lot, avec une estimation du nombre de sessions et de tours.
   - Scénarios 1 à 5 en `claude -p --plugin-dir`, dans un dossier temporaire hors du plugin.
   - Preuves : `stream-json`, checkpoint, `git status`.
   - Points à confirmer au passage : `--max-turns` ; l'éventuelle obligation de `--verbose` avec `stream-json` ; le comportement de `!` face aux hooks.

**G — Documentation et rapport**

- README, INSTALLATION (version minimale 2.1.295, portées, commandes du §3.2), USER_GUIDE, SECURITY (les trois couches, les limites du guard, la confiance du workspace), TROUBLESHOOTING.
- CHANGELOG 0.1.0, puis commit final local.

## 7. Décisions attendues

| # | Question | Ma recommandation |
| --- | --- | --- |
| D1 | Approuvez-vous les corrections E1 à E19, et leur report dans ARCHITECTURE.md (statut → REVIEW) ? | Oui |
| D2 | Ajoute-t-on le hook `agent-scope-guard` (E4) à la v0.1 ? | Oui : sans lui, deux mentions du tableau « Agents » restent sans effet |
| D3 | checkpoint-reminder : faire reprendre Claude une fois (`additionalContext`, qui coûte un tour), ou seulement vous prévenir (`systemMessage`) ? | Le faire reprendre une fois |
| D4 | Étend-on le guard à `git restore` (hors `--staged`), `git stash drop` et `git stash clear` ? | Oui, pour préserver les modifications non commitées |
| D5 | Quel nom pour `author` et `owner`, quel titulaire pour la LICENSE MIT, quel nom de marketplace ? | `Allosun` ; marketplace `dart-multiplatform-forge` |
| D6 | Initialise-t-on le dépôt ici (`~/Documents/claude-plugin/App`), hors de `~/Documents/project-code/` ? | À votre choix ; je ne déplace rien sans accord |
| D7 | Modèles des agents (E5) ? | `sonnet` pour test-engineer, `sonnet` pour code-reviewer, `inherit` pour flutter-architect |
| D8 | Quel profil pour les sessions headless de la phase F : `~/.claude` (actuel) ou `vincent` (`echo vincent > .claude-profil`) ? | Celui qui doit porter le coût |
| D9 | plugin-dev : agent-creator pour rédiger les agents, ou rédaction directe suivie de `skill-reviewer` en fin de phase D ? | Rédaction directe, puis `skill-reviewer` |

## Annexe — ce qui n'a pas été fait en phase A

- Aucune session headless : elle aurait consommé du quota.
- Aucun `flutter create` ni `flutter test`, et aucun `claude plugin details` sur un vrai plugin.
- Aucun fichier du plugin n'a été créé, hormis ce rapport et `PROGRESS.md`, exigé par vos règles générales.
- La sonde L2 reste dans le scratchpad de session : sa suppression par `rm -rf` a été refusée par le système de permissions, et je ne l'ai pas relancée.
- Le nombre de projets de `~/.claude.json` est resté stable (36) avant et après les appels à `claude plugin validate`.
