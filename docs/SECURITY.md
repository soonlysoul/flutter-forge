# Sécurité

La sécurité repose sur **trois couches indépendantes**. Aucune ne suffit seule.

| Couche | Où | Ce qu'elle fait | Ce qu'elle ne fait pas |
| --- | --- | --- | --- |
| 1. Règles de permission | `<projet>/.claude/settings.json`, copié depuis `templates/project-settings.json` après votre accord | `allow`, `ask`, `deny` évalués par Claude Code | Ne couvre que la forme écrite d'une commande |
| 2. Hooks | `hooks/hooks.json` de plugin-flutter (agents du plugin, format) et de plugin-orchestrator (garde-fous communs) | Analysent chaque commande et chaque écriture, bloquent | N'accordent jamais une permission |
| 3. Préautorisations | `<projet>/.forge/config.yaml` | Les workflows les lisent avant toute action externe | Ne lèvent jamais un blocage des couches 1 et 2 |

Un plugin **ne peut pas** imposer de règles de permission : le `settings.json` d'un plugin n'applique que `agent` et `subagentStatusLine`. C'est pourquoi la couche 1 est un gabarit que vous installez.

Depuis la 1.0, les garde-fous communs à tous les projets — commandes destructives, secrets, fichiers sensibles, rappel du checkpoint, statut des documents — sont ceux de plugin-orchestrator, à installer avec plugin-flutter : leur fonctionnement et leurs limites sont dans [son SECURITY.md](https://github.com/soonlysoul/plugin-orchestrator/blob/main/docs/SECURITY.md). plugin-flutter garde les hooks propres à ses agents et à Dart, ci-dessous, et les règles de permission de Flutter.

## Couche 1 — les règles de permission proposées

Ce sont celles de `templates/project-settings.json` : les règles génériques de l'orchestrateur et celles de Flutter. Au démarrage d'un projet, l'orchestrateur les assemble lui-même : ses règles génériques, et le fragment Flutter (`templates/permissions-fragment.json`) que lui rend le scaffold-engineer, qui ne l'écrit jamais. À l'adoption, `adopt-existing-project` propose le fichier complet.

- **Sans demander** : `flutter test`, `flutter analyze`, `dart format`, `flutter pub get`, `flutter pub get --enforce-lockfile`, les commandes de `flutter pub` qui ne modifient rien (`flutter pub outdated`, `flutter pub deps`, `flutter pub add --dry-run`), `flutter build`, `flutter --version`, `flutter --version --machine`, `flutter doctor`, `flutter devices`, `git --version`, `jq --version`, `git status`, `git diff`, `git log`, `git show`, `git ls-files`, `git add <fichiers>`, `git switch`, `git remote -v`, `git rev-parse`, `git branch --show-current`, et les `gh` en lecture : `gh --version`, `gh auth status`, `gh repo view`, `gh pr view`, `gh pr checks`, `gh run list`, `gh run view`, `gh run watch`, `gh workflow list`, `gh workflow view`, `gh issue list`, `gh issue view`.
- **Demandent d'abord** : `git commit`, `git push`, `gh pr create`, `gh pr edit`, `gh repo create`, `gh issue create`, `gh run rerun`, `gh workflow run` (ces deux derniers consomment des minutes de CI), `flutter pub upgrade`, `flutter upgrade`, `flutter downgrade` et `flutter channel` (ces trois-là changent Flutter pour tous les projets de la machine), et `git add -A` / `git add .` / `git add --all`.
- **Refusées** : `git reset --hard`, `git clean`, `git push --force`, `git push -f` et leurs variantes (`+ref`, option placée après le dépôt), `git branch -D`, `gh repo delete`, `gh pr merge`, `dart pub publish`, `flutter pub publish`, la lecture de `.env`, `.env.*`, `key.properties` et des keystores et certificats (`*.jks`, `*.keystore`, `*.p12`, `*.pfx`), et toute modification de `.forge/config.yaml`.

À savoir :

- L'ordre d'évaluation est `deny`, puis `ask`, puis `allow`, et la première règle qui correspond l'emporte. Un `deny` de n'importe quel niveau l'emporte sur un `allow` de n'importe quel autre.
- Les `allow` d'un projet ne s'appliquent **qu'après acceptation de la confiance du workspace**. `deny` et `ask` s'appliquent toujours.
- Les règles de fichiers s'écrivent `Edit(…)`, qui couvre tous les outils d'écriture. Une règle `Write(…)` ne protège rien.
- Une règle Bash ne couvre que la forme écrite : `git -C . push --force` échappe à `Bash(git push --force*)`. C'est la couche 2 qui analyse la commande.

## Couche 2 — les hooks

Ceux de plugin-orchestrator agissent dans toutes les sessions où il est activé : guard-destructive (`git reset --hard`, `push --force`, `rm -rf` hors `build/`, `gh repo delete`, `gh pr merge`, `flutter pub publish` et `dart pub publish` sans `--dry-run`…), secret-scan (un commit qui contient un fichier ou un motif de secret, gitleaks s'il est installé), protect-sensitive (confirmation avant d'écrire un fichier de signature, des entitlements Apple, un workflow de CI ou `.forge/config.yaml`), checkpoint-reminder et doc-status-guard. plugin-flutter n'en a plus de copie : aucun ne tourne en double, à condition de ne pas garder un plugin-flutter 0.x installé à côté.

### agent-scope-guard

Inerte hors des cinq agents du plugin (y compris un agent d'un autre plugin qui porterait le même nom). Pour eux, il refuse toute écriture hors de leurs dossiers et toute commande hors de leur liste (voir le [guide](USER_GUIDE.md#les-agents)) ; le code-reviewer n'écrit rien ; le scaffold-engineer ne lance `flutter create` que sur le dossier de la session, jamais avec `--overwrite`, et n'écrit à la racine que `analysis_options.yaml`. Un agent du plugin dont le périmètre n'est pas déclaré dans le hook est bloqué. Il compense une limite de Claude Code : le frontmatter d'un agent ne sait pas restreindre Bash à certaines commandes, ni l'écriture à certains dossiers.

### Fail-closed

agent-scope-guard **bloque en cas de doute** : `jq` absent, entrée illisible, lexer `hooks/scripts/lib/shell-lexer.sh` manquant. Il sort alors en 2, et `hooks.json` déclare `"onFailure": "block"`, qui couvre aussi un script introuvable, un plantage ou un délai dépassé. Ce champ exige Claude Code 2.1.295. Un hook qui sortirait en 1 laisserait passer la commande.

`format-dart` est au contraire **fail-open** : il ne bloque jamais rien.

## Lever un blocage

Une levée se fait **par vous, jamais par Claude** qui reformulerait la commande. Les messages des gardes demandent à Claude de ne pas réessayer autrement et de vous expliquer le risque. Pour exécuter vous-même une commande bloquée, tapez-la dans un terminal, ou dans la session avec le préfixe `!` : elle s'exécute alors sans appel d'outil, donc sans passer par les hooks (déduit de la documentation, **non vérifié**).

## Limites connues

Les limites des gardes communs (commandes désignées par une variable, alias git, couverture de secret-scan sans gitleaks, écritures par Bash que protect-sensitive ne voit pas…) sont décrites dans le SECURITY.md de plugin-orchestrator.

Pour les mises à jour : aucun hook ne bloque `flutter upgrade`, `flutter downgrade` ni `flutter channel`. La règle `ask` de la couche 1 et la consigne d'update-project sont les seules barrières. De même, seule la consigne d'adopt-existing-project interdit un `flutter pub get` sans `--enforce-lockfile` pendant l'analyse, qui réécrirait un `pubspec.lock` périmé.

Pour agent-scope-guard : un lien symbolique placé sous `test/` et pointant ailleurs n'est pas suivi ; la racine du projet est `CLAUDE_PROJECT_DIR`, c'est-à-dire le dossier où la session a été lancée.

Pour le scaffold-engineer : il lance `flutter create`, qui écrit à la racine (`.gitignore`, `README.md`, `pubspec.yaml`…) par Bash, ce que le hook ne restreint pas ; ses écritures par Edit et Write, elles, sont bornées. Son rapport liste les fichiers créés, et l'orchestrateur les compare à `git status` avant de s'en servir.

Les règles `deny` de la couche 1 forment la seconde barrière pour les formes courantes. Signalez toute formulation qui passe : elle deviendra un test.

## Secrets

- Aucun jeton ni secret n'est affiché, écrit dans `.forge/` ou passé en argument de commande visible.
- Le secret-scan de l'orchestrateur vérifie chaque commit ; son git-workflow relit aussi `git diff --cached` avant de committer.
- L'orchestrateur ne demande, n'affiche ni ne transmet jamais de jeton ; l'agent devops-engineer ne peut pas lancer `gh auth status --show-token`.
- Le gabarit CI n'utilise aucun secret, donne au jeton de la CI la lecture seule (`contents: read`), ne le garde pas dans `.git/config` (`persist-credentials: false`) et épingle ses actions par SHA de commit.
- `.gitignore` des projets : celui que `flutter create` écrit, complété par l'orchestrateur (ou par l'adoption) de `.env*`, `*.jks`, `*.keystore`, `key.properties`.

## Actions toujours soumises à votre accord

Quelle que soit la configuration : fusion dans la branche principale, changement de visibilité, suppression, release publique, toute dépense, tout changement de fournisseur ou de mode d'authentification. S'y ajoutent, depuis la v0.2 : la création du dépôt distant (propriétaire, nom et visibilité reconfirmés à chaque fois), l'ajout ou la modification de la CI, et toute relance de CI sur un dépôt privé, qui consomme des minutes. Depuis la v0.3 : le plan de lots d'une mise à jour et chaque majeure, la resynchronisation d'un lockfile périmé, tout changement de la version de Flutter (fait par vous), le plan d'adoption d'une app existante et chaque modification d'un de ses fichiers, et toute modification du PRD ou du TRD.
