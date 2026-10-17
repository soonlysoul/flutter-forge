# Sécurité

La sécurité repose sur **trois couches indépendantes**. Aucune ne suffit seule.

| Couche | Où | Ce qu'elle fait | Ce qu'elle ne fait pas |
| --- | --- | --- | --- |
| 1. Règles de permission | `<projet>/.claude/settings.json`, copié depuis `templates/project-settings.json` après votre accord | `allow`, `ask`, `deny` évalués par Claude Code | Ne couvre que la forme écrite d'une commande |
| 2. Hooks du plugin | `hooks/hooks.json` | Analysent chaque commande et chaque écriture, bloquent | N'accordent jamais une permission |
| 3. Préautorisations | `<projet>/.forge/config.yaml` | Les workflows les lisent avant toute action externe | Ne lèvent jamais un blocage des couches 1 et 2 |

Un plugin **ne peut pas** imposer de règles de permission : le `settings.json` d'un plugin n'applique que `agent` et `subagentStatusLine`. C'est pourquoi la couche 1 est un gabarit que vous installez.

## Couche 1 — les règles de permission proposées

- **Sans demander** : `flutter test`, `flutter analyze`, `dart format`, `flutter pub get`, `git status`, `git diff`, `git log`, `git add <fichiers>`, `git switch`.
- **Demandent d'abord** : `git commit`, `git push`, `gh pr create`, `flutter pub upgrade`, et `git add -A` / `git add .` / `git add --all`.
- **Refusées** : `git reset --hard`, `git clean`, `git push --force` et ses variantes (`-f`, `+ref`), `git branch -D`, `gh repo delete`, `gh pr merge`, `dart pub publish`, `flutter pub publish`, la lecture de `.env`, `.env.*` et `key.properties`, et toute modification de `.forge/config.yaml`.

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

### agent-scope-guard

Inerte hors des trois agents du plugin. Pour eux, il refuse toute écriture hors de leurs dossiers et toute commande hors de leur liste (voir le [guide](USER_GUIDE.md#les-agents)). Il compense une limite de Claude Code : le frontmatter d'un agent ne sait pas restreindre Bash à certaines commandes, ni l'écriture à certains dossiers.

### Fail-closed

Les deux gardes **bloquent en cas de doute** : `jq` absent, entrée illisible, bibliothèque manquante, imbrication trop profonde. Ils sortent alors en 2, et `hooks.json` déclare `"onFailure": "block"`, qui couvre aussi un script introuvable, un plantage ou un délai dépassé. Ce champ exige Claude Code 2.1.295. Un hook qui sortirait en 1 laisserait passer la commande.

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

Pour agent-scope-guard : un lien symbolique placé sous `test/` et pointant ailleurs n'est pas suivi ; la racine du projet est `CLAUDE_PROJECT_DIR`, c'est-à-dire le dossier où la session a été lancée.

Les règles `deny` de la couche 1 forment la seconde barrière pour les formes courantes. Signalez toute formulation qui passe : elle deviendra un test.

## Secrets

- Aucun jeton ni secret n'est affiché, écrit dans `.forge/` ou passé en argument de commande visible.
- `git-workflow` relit `git diff --cached` avant chaque commit, à la recherche de motifs de secrets (clés AWS, `-----BEGIN`, `ghp_`, `sk-`, `AIza`). Le hook `secret-scan` arrive en v0.2.
- `.gitignore` des projets générés : `.env*`, `*.jks`, `*.keystore`, `key.properties`.

## Actions toujours soumises à votre accord

Quelle que soit la configuration : fusion dans la branche principale, changement de visibilité, suppression, release publique, toute dépense, tout changement de fournisseur ou de mode d'authentification.
