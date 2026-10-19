# Dépannage

Premier réflexe, depuis le dossier du plugin :

```bash
claude plugin details dart-multiplatform-forge   # le plugin est-il chargé, avec ses composants ?
bash tests/run-all.sh                            # ses fichiers sont-ils intacts ?
```

## Toutes les commandes shell sont bloquées

**Symptôme** : chaque commande Bash échoue avec `Blocked by dart-multiplatform-forge (guard-destructive): jq is required…`.

**Cause** : `jq` est absent du `PATH` de Claude Code. Le guard est fail-closed : sans `jq`, il ne peut pas lire la commande, donc il la refuse.

**Solution** : installer `jq` (sous NixOS, par la configuration système ou Home Manager), puis relancer la session. Pour débloquer en urgence, désactiver le plugin depuis un terminal : `claude plugin disable dart-multiplatform-forge@dart-multiplatform-forge`, puis `claude plugin enable …` une fois `jq` installé.

## « hook error … failed; blocking because onFailure is "block" »

**Cause** : le script du hook n'a pas pu s'exécuter : fichier absent, `bash` introuvable, délai dépassé. Le hook bloque alors par construction.

**Solution** : `bash tests/run-all.sh` signale un script manquant (`test_paths`). Vérifier que `bash` est sur le `PATH`. Le plugin n'utilise jamais `/bin/bash`, absent sous NixOS.

## Une commande légitime est bloquée

Le guard préfère un faux positif à une commande destructive. Cas courants :

| Commande bloquée | Pourquoi | Que faire |
| --- | --- | --- |
| Commit dont le message passe par un heredoc non cité (`<<EOF`) avec des accents graves | Bash exécuterait réellement ce qui est entre accents graves | Citer le délimiteur : `git commit -F - <<'EOF'` |
| `rm -rf` sur un dossier autre que `build/` | Suppression récursive définitive | La lancer vous-même, hors de Claude ou avec le préfixe `!` |
| `git restore <fichier>` | Jette les modifications non commitées du fichier | `git restore --staged <fichier>` pour seulement désindexer |
| `dart pub publish` | Publication | `--dry-run` passe ; la publication réelle se fait par vous |

Claude ne doit jamais reformuler une commande bloquée pour la faire passer. S'il le fait, signalez-le.

## Les agents ne peuvent ni écrire ni lancer `flutter test`

**Symptôme** : `Blocked by dart-multiplatform-forge (agent-scope-guard): test-engineer may only write under: test/, integration_test/` pour un fichier qui est pourtant sous `test/`.

**Cause** : la session a été lancée ailleurs qu'à la racine du projet, par exemple dans le dossier parent. Les hooks prennent le dossier de lancement (`CLAUDE_PROJECT_DIR`) comme racine.

**Solution** : quitter, puis `cd <projet> && claude`. Dans VSCode, ouvrir le dossier **du projet**, pas son parent.

## Les règles `allow` du projet sont ignorées

**Symptôme** : Claude demande la permission pour `flutter test` ou `git status` malgré `.claude/settings.json`. Au démarrage, Claude Code écrit sur sa sortie d'erreur `Ignoring N permissions.allow entries … this workspace has not been trusted`.

**Cause** : la confiance du workspace n'a pas été accordée. Les `allow` d'un projet restent inertes jusque-là ; `deny` et `ask` s'appliquent toujours.

**Solution** : ouvrir une session interactive dans le dossier et accepter la question de confiance. En mode `-p`, passer les outils par `--allowedTools`.

## `.claude/settings.json` n'est pas installé

**Symptôme** : bootstrap-project signale que l'écriture de `.claude/settings.json` a été refusée.

**Cause** : Claude Code protège ses fichiers de configuration. En mode non interactif, ou sans votre confirmation, il refuse de les écrire, même quand l'outil `Write` est autorisé. C'est voulu : un dépôt ne doit pas pouvoir s'accorder des permissions tout seul.

**Solution** : lancer vous-même la commande de copie que le skill affiche, depuis la racine du projet :

```bash
mkdir -p .claude && cp /chemin/vers/dart-multiplatform-forge/templates/project-settings.json .claude/settings.json
```

Tant que ce n'est pas fait, aucune règle du projet ne s'applique, y compris la protection de `.forge/config.yaml`.

## Un commit est refusé en mode `-p`

**Cause** : la règle `ask` sur `git commit` du gabarit demande une confirmation, et personne ne peut répondre en mode non interactif.

**Solution** : committer en session interactive, ou vous-même. Ce comportement est voulu.

## Un agent semble avoir plus d'outils que prévu

**Cause probable** : son frontmatter ne se lit plus. Claude Code charge alors l'agent avec tous ses champs ignorés, donc avec **tous les outils**, sans message. Le validateur officiel ne le détecte pas, même avec `--strict` : `claude plugin validate agents --strict` accepte par exemple `description: Use when: …`, qui n'est pas du YAML valide.

**Solution** : `bash tests/static/test_frontmatter.sh` nomme la ligne fautive. Un `: ` dans une valeur exige des guillemets. agent-scope-guard continue de limiter les écritures et les commandes des trois agents.

## Claude reprend la main pour mettre à jour le checkpoint

**Symptôme** : en fin de tour, « Stop hook feedback » demande de mettre à jour `.forge/checkpoint.md`.

**Cause** : le checkpoint est plus ancien que le dernier commit ou qu'un fichier modifié, y compris un fichier que vous avez modifié vous-même dans l'éditeur.

**Solution** : laisser Claude le mettre à jour (une seule reprise par fin de tour, jamais deux de suite), ou le mettre à jour vous-même. Le hook se tait dès que le checkpoint est à jour, et ne parle jamais dans un projet sans `.forge/checkpoint.md`.

## `format-dart` ne formate rien

**Causes** : `dart` n'est pas dans le `PATH` de Claude Code ; le fichier n'a pas l'extension `.dart` ; le fichier contient une erreur de syntaxe, que `dart format` refuse. Le hook est fail-open et ne signale rien.

**Vérifier** : `command -v dart` dans le même environnement que Claude Code ; `dart format <fichier>` à la main.

## Une modification du plugin n'est pas prise en compte

**Cause** : une marketplace locale est lue sur place, mais une session déjà ouverte garde l'état chargé.

**Solution** : `/reload-plugins` dans la session, ou une nouvelle session.

## Version de Claude Code antérieure à 2.1.295

Le champ `onFailure` des hooks est alors inconnu. Le guard bloque toujours sur ses propres erreurs (exit 2), mais un script introuvable ou un délai dépassé laissent passer la commande. Mettre Claude Code à jour.
