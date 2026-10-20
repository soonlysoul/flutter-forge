# Sécurité

La sécurité repose sur **trois couches indépendantes**. Aucune ne suffit seule.

| Couche | Où | Ce qu'elle fait | Ce qu'elle ne fait pas |
| --- | --- | --- | --- |
| 1. Règles de permission | `<projet>/.claude/settings.json`, copié depuis `templates/project-settings.json` après votre accord | `allow`, `ask`, `deny` évalués par Claude Code | Ne couvre que la forme écrite d'une commande |
| 2. Hooks du plugin | `hooks/hooks.json` | Analysent chaque commande et chaque écriture, bloquent | N'accordent jamais une permission |
| 3. Préautorisations | `<projet>/.forge/config.yaml` | Les workflows les lisent avant toute action externe | Ne lèvent jamais un blocage des couches 1 et 2 |

Un plugin **ne peut pas** imposer de règles de permission : le `settings.json` d'un plugin n'applique que `agent` et `subagentStatusLine`. C'est pourquoi la couche 1 est un gabarit que vous installez.

## Couche 1 — les règles de permission proposées

- **Sans demander** : `flutter test`, `flutter analyze`, `dart format`, `flutter pub get`, `flutter pub get --enforce-lockfile`, les commandes de `flutter pub` qui ne modifient rien (`flutter pub outdated`, `flutter pub deps`, `flutter pub add --dry-run`), `flutter build`, `flutter --version`, `flutter --version --machine`, `flutter doctor`, `flutter devices`, `git status`, `git diff`, `git log`, `git add <fichiers>`, `git switch`, `git remote -v`, `git rev-parse`, `git branch --show-current`, et les `gh` en lecture : `gh --version`, `gh auth status`, `gh repo view`, `gh pr view`, `gh pr checks`, `gh run list`, `gh run view`, `gh run watch`, `gh workflow list`, `gh workflow view`, `gh issue list`, `gh issue view`.
- **Demandent d'abord** : `git commit`, `git push`, `gh pr create`, `gh pr edit`, `gh repo create`, `gh issue create`, `gh run rerun`, `gh workflow run` (ces deux derniers consomment des minutes de CI), `flutter pub upgrade`, `flutter upgrade`, `flutter downgrade` et `flutter channel` (ces trois-là changent Flutter pour tous les projets de la machine), et `git add -A` / `git add .` / `git add --all`.
- **Refusées** : `git reset --hard`, `git clean`, `git push --force`, `git push -f` et leurs variantes (`+ref`, option placée après le dépôt), `git branch -D`, `gh repo delete`, `gh pr merge`, `dart pub publish`, `flutter pub publish`, la lecture de `.env`, `.env.*` et `key.properties`, et toute modification de `.forge/config.yaml`.

À savoir :

- L'ordre d'évaluation est `deny`, puis `ask`, puis `allow`, et la première règle qui correspond l'emporte. Un `deny` de n'importe quel niveau l'emporte sur un `allow` de n'importe quel autre.
- Les `allow` d'un projet ne s'appliquent **qu'après acceptation de la confiance du workspace**. `deny` et `ask` s'appliquent toujours.
- Les règles de fichiers s'écrivent `Edit(…)`, qui couvre tous les outils d'écriture. Une règle `Write(…)` ne protège rien.
- Une règle Bash ne couvre que la forme écrite : `git -C . push --force` échappe à `Bash(git push --force*)`. C'est la couche 2 qui analyse la commande.

## Couche 2 — les hooks

### guard-destructive

Actif sur `Bash`, `PowerShell` et `Monitor`, dans toutes les sessions où le plugin est activé. Il bloque :

- `git reset --hard` ; `git clean -f` ; `git push` forcé (`-f`, `--force`, `--force-with-lease`, `--force-if-includes`, `+ref`), qui supprime une branche distante (`--delete`, `:ref`), en miroir (`--mirror`) ou qui pousse des tags (`--tags`, `--follow-tags`, `refs/tags/…`) ;
- `git branch -D` ; `git checkout -- <chemin>`, `git checkout .`, `git checkout --force` ; `git restore` sans `--staged` seul ; `git stash drop`, `git stash clear` ; `git switch --discard-changes` ;
- `rm` récursif et forcé hors de `build/`, ou sans cible visible (`… | xargs rm -rf`) ;
- `gh repo delete`, `gh repo edit --visibility`, `gh pr merge`, `gh release create|edit|upload|delete`, `gh api -X DELETE` ;
- `flutter pub publish`, `dart pub publish` (sauf `--dry-run`).

Il découpe la commande, ignore le texte cité (un message de commit qui parle de `git push --force` passe), passe les préfixes (`sudo`, `env`, `VAR=…`, `timeout`…) et descend dans `bash -c`, `eval`, `$(…)`, les accents graves, `find -exec`, les heredocs donnés à un shell et les substitutions des heredocs non cités.

### secret-scan

Actif sur `Bash`, `PowerShell` et `Monitor`, dans toutes les sessions où le plugin est activé, comme guard-destructive : un secret n'a sa place dans aucun dépôt. Avant un `git commit`, il refuse :

- les fichiers de secrets, quel que soit leur contenu : `.env` et `.env.*` (sauf `.env.example`, `.env.sample`, `.env.template`), `*.jks`, `*.keystore`, `key.properties`, `*.p12`, `*.pfx` ;
- les **lignes ajoutées** qui contiennent une clé privée (`-----BEGIN … PRIVATE KEY`), une clé d'accès AWS, un jeton GitHub (`ghp_…`, `gho_…`, `github_pat_…`), une clé `sk-…` (OpenAI, Anthropic…) ou une clé Google (`AIza…`). Retirer un secret d'un fichier passe ; un certificat public passe. Les clés Google des fichiers de configuration Firebase (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) passent aussi : elles sont faites pour être livrées avec l'app, et seule la règle Google est levée pour ces fichiers.

Il lit ce que le commit peut inclure, et seulement cela : l'index (`git diff --cached`, y compris avant le premier commit) ; les modifications non indexées prises par `-a` ou par un chemin nommé ; les modifications et les fichiers non suivis désignés par un `git add` de la même ligne (`git add lib/a.dart && git commit` ne lit que `lib/a.dart`, `git add .` tout le dossier). Il suit `cd`, `pushd`, `git -C`, `--git-dir`, `bash -c`, `eval` et `$(…)`.

Il **refuse** ce qu'il ne peut pas vérifier avant que la commande s'exécute, en demandant de la découper : `git init` ou `git clone` sur la même ligne qu'un commit (le dépôt n'existe pas encore), `git add -f` (un fichier ignoré, que l'index ne montre pas encore), `git apply --cached`. Si **gitleaks** est installé, il le lance en plus (`gitleaks git --pre-commit --staged`), ce qui couvre des centaines de formats de plus ; les règles de noms de fichiers restent les siennes.

Le secret n'est **jamais affiché** : le message nomme le fichier et la règle, puis demande de désindexer le fichier et de vous dire lequel le contenait. Une commande qui ne contient pas le mot `commit` est écartée sans même lancer `jq`.

### protect-sensitive

Actif sur `Edit`, `Write` et `NotebookEdit`, **seulement dans un projet qui a un dossier `.forge/`** : le plus proche dossier parent du fichier qui en contient un, même si la session a été ouverte plus haut. Avant d'écrire un fichier de signature (`key.properties`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`), des entitlements Apple (`*.entitlements`) ou du code de CI (`.github/workflows/*`, `.github/actions/*`), il vous demande confirmation dans l'invite de permission, étiquetée `[plugin:plugin-flutter]`. `.forge/config.yaml` est protégé partout, même dans un projet où `.claude/settings.json` n'est pas installé.

En mode non interactif (`claude -p`), personne ne peut répondre : l'écriture est refusée, et Claude lit la raison. Les skills donnent alors la commande à lancer vous-même.

### agent-scope-guard

Inerte hors des cinq agents du plugin. Pour eux, il refuse toute écriture hors de leurs dossiers et toute commande hors de leur liste (voir le [guide](USER_GUIDE.md#les-agents)) ; product-architect n'a aucune commande. Un agent du plugin dont le périmètre n'est pas déclaré dans le hook est bloqué. Il compense une limite de Claude Code : le frontmatter d'un agent ne sait pas restreindre Bash à certaines commandes, ni l'écriture à certains dossiers.

### Fail-closed

Les quatre gardes — guard-destructive, agent-scope-guard, secret-scan (pour un commit) et protect-sensitive (pour un fichier sensible) — **bloquent en cas de doute** : `jq` absent, entrée illisible, bibliothèque manquante, imbrication trop profonde. Ils sortent alors en 2, et `hooks.json` déclare `"onFailure": "block"`, qui couvre aussi un script introuvable, un plantage ou un délai dépassé. Ce champ exige Claude Code 2.1.295. Un hook qui sortirait en 1 laisserait passer la commande.

`format-dart` et `checkpoint-reminder` sont au contraire **fail-open** : ils ne bloquent jamais rien.

## Lever un blocage

Une levée se fait **par vous, jamais par Claude** qui reformulerait la commande. Les messages du guard demandent à Claude de ne pas réessayer autrement et de vous expliquer le risque. Pour exécuter vous-même une commande bloquée, tapez-la dans un terminal, ou dans la session avec le préfixe `!` : elle s'exécute alors sans appel d'outil, donc sans passer par les hooks (déduit de la documentation, **non vérifié**).

## Limites connues

Le guard est un **filet de sécurité, pas une garantie**. Il analyse la commande par motifs, et ne voit pas :

- une commande désignée par une variable : `G=git; $G reset --hard` ;
- un alias git (`git config alias.nuke 'reset --hard'`, puis `git nuke`) ;
- la citation `$'…'`, ni `pwsh -Command`, ni les commandes natives de PowerShell (`Remove-Item -Recurse`) ;
- `find … -delete` ; `rm -r` sans `-f`, qui supprime pourtant sans demander les fichiers modifiables ;
- un tag poussé sous son seul nom (`git push origin v1.0.0`) ;
- `git checkout <fichier>` sans `--`, impossible à distinguer de `git checkout <branche>` ;
- un script lancé par fichier (`bash script.sh`), dont le contenu n'est pas lu.

Pour secret-scan :

- sans gitleaks, ses motifs sont volontairement peu nombreux : un jeton Slack, Stripe ou une clé secrète AWS (`aws_secret_access_key`) passent. **Installez gitleaks** pour une vraie couverture (sous NixOS : `home.packages = [ pkgs.gitleaks ];` dans Home Manager) ;
- il ne voit que `git commit` : pas `git commit-tree`, `git merge`, `git cherry-pick`, `git rebase`, `git am`, ni un commit fait par un script lancé par fichier ;
- un `cd` vers un chemin qui contient une variable bloque le commit, faute de savoir quel dépôt il vise ;
- un fichier modifié sur la même ligne par une autre commande (`sed -i`, `git apply` sans `--cached`, un script) est lu dans son état d'avant : le hook passe avant toute la ligne. Seul le texte de la ligne est analysé, ce qui attrape `printf 'KEY=…' > f && git add f && git commit` ;
- les fichiers binaires sont lus comme du texte (pour qu'un attribut `-diff` ne masque rien) : une chaîne d'une bibliothèque native commitée peut ressembler à une clé, faux positif qui se lève par `!` ;
- gitleaks lit l'index, et l'arbre de travail entier pour `-a` ou `git add -A` ; un fichier non suivi n'est lu que par les motifs intégrés ;
- un faux positif (clé d'exemple dans un test) se lève par vous seul : `! git commit …`.

Pour protect-sensitive : sans `jq`, il ne connaît pas le chemin du fichier et ne regarde que la racine de session ; il ne voit que les outils d'écriture de Claude ; une écriture par Bash (`sed -i`, `cp`, redirection) lui échappe. La règle `deny` `Edit(./.forge/config.yaml)` et la relecture du diff avant commit restent les autres barrières.

Pour les mises à jour : aucun hook ne bloque `flutter upgrade`, `flutter downgrade` ni `flutter channel`. La règle `ask` de la couche 1 et la consigne d'update-project sont les seules barrières. De même, seule la consigne d'adopt-existing-project interdit un `flutter pub get` sans `--enforce-lockfile` pendant l'analyse, qui réécrirait un `pubspec.lock` périmé.

Pour agent-scope-guard : un lien symbolique placé sous `test/` et pointant ailleurs n'est pas suivi ; la racine du projet est `CLAUDE_PROJECT_DIR`, c'est-à-dire le dossier où la session a été lancée.

Les règles `deny` de la couche 1 forment la seconde barrière pour les formes courantes. Signalez toute formulation qui passe : elle deviendra un test.

## Secrets

- Aucun jeton ni secret n'est affiché, écrit dans `.forge/` ou passé en argument de commande visible.
- Le hook `secret-scan` vérifie chaque commit (voir plus haut) ; `git-workflow` relit aussi `git diff --cached` avant de committer.
- `github-workflow` ne demande, n'affiche ni ne transmet jamais de jeton : sans `gh auth status` valide, il s'arrête et vous laisse lancer `! gh auth login`. L'agent devops-engineer ne peut pas lancer `gh auth status --show-token`.
- Le gabarit CI n'utilise aucun secret, donne au jeton de la CI la lecture seule (`contents: read`), ne le garde pas dans `.git/config` (`persist-credentials: false`) et épingle ses actions par SHA de commit.
- `.gitignore` des projets générés : `.env*`, `*.jks`, `*.keystore`, `key.properties`.

## Actions toujours soumises à votre accord

Quelle que soit la configuration : fusion dans la branche principale, changement de visibilité, suppression, release publique, toute dépense, tout changement de fournisseur ou de mode d'authentification. S'y ajoutent, depuis la v0.2 : la création du dépôt distant (propriétaire, nom et visibilité reconfirmés à chaque fois), l'ajout ou la modification de la CI, et toute relance de CI sur un dépôt privé, qui consomme des minutes. Depuis la v0.3 : le plan de lots d'une mise à jour et chaque majeure, la resynchronisation d'un lockfile périmé, tout changement de la version de Flutter (fait par vous), le plan d'adoption d'une app existante et chaque modification d'un de ses fichiers, et toute modification du PRD ou du TRD.
