# Dépannage

Premier réflexe, depuis le dossier du plugin :

```bash
claude plugin details plugin-flutter   # le plugin est-il chargé, avec ses composants ?
bash tests/run-all.sh                            # ses fichiers sont-ils intacts ?
```

## Toutes les commandes shell sont bloquées

**Symptôme** : chaque commande Bash échoue avec `Blocked by plugin-flutter (guard-destructive): jq is required…`.

**Cause** : `jq` est absent du `PATH` de Claude Code. Le guard est fail-closed : sans `jq`, il ne peut pas lire la commande, donc il la refuse.

**Solution** : installer `jq` (sous NixOS, par la configuration système ou Home Manager), puis relancer la session. Pour débloquer en urgence, désactiver le plugin depuis un terminal : `claude plugin disable plugin-flutter@soon` (`@plugin-flutter` pour la marketplace locale), puis `claude plugin enable …` une fois `jq` installé.

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

## Un commit est bloqué par secret-scan

**Symptôme** : `Blocked by plugin-flutter (secret-scan): this commit would include secrets:`, suivi des fichiers et des règles.

**Si c'est un vrai secret** : désindexer le fichier (`git restore --staged <fichier>`, ou `git rm --cached <fichier>` avant le premier commit), sortir le secret du code (variable d'environnement, fichier non suivi listé dans `.gitignore`), puis committer. Si le secret a déjà été poussé, le révoquer : le retirer de l'historique ne suffit pas.

**Si c'est un faux positif** (clé d'exemple dans un test, clé Firebase publique) : vous seul pouvez lever le blocage, en lançant le commit vous-même (`! git commit …`). Avec gitleaks, un commentaire `gitleaks:allow` sur la ligne ou un fichier `.gitleaksignore` évite le blocage suivant ; les règles de noms de fichiers et les motifs intégrés du hook, eux, ne lisent pas ces exceptions.

**« … in a separate command »** : la ligne fait quelque chose que le hook ne peut pas voir avant qu'elle s'exécute — `git init` ou `git clone`, `git add -f`, `git apply --cached` suivis d'un commit. Lancer cette commande seule, puis le commit dans un second appel : le hook lit alors le vrai index.

**`gitleaks failed (exit …)`** : gitleaks est installé mais n'a pas pu tourner, souvent à cause d'un `.gitleaks.toml` invalide. Le commit est bloqué par prudence ; corriger la configuration, ou lancer `gitleaks git --pre-commit --staged -v` à la main pour voir l'erreur.

## Claude demande confirmation pour écrire un fichier

**Symptôme** : une invite étiquetée `[plugin:plugin-flutter]` demande de confirmer l'écriture de `key.properties`, d'un keystore, d'entitlements, de `.github/workflows/…` ou de `.forge/config.yaml`.

**Cause** : le hook protect-sensitive. C'est voulu : ces fichiers signent l'app, lui donnent des droits, ou s'exécutent avec les jetons du dépôt.

**Solution** : approuver si vous avez demandé ce changement. En mode `-p`, l'écriture est refusée ; le skill donne alors la commande à lancer vous-même.

## `github-workflow` s'arrête sur `gh auth status`

**Cause** : `gh` n'est pas installé, ou pas connecté au compte voulu.

**Solution** : `! gh auth login` (dans la session, avec le préfixe `!`, ou dans un terminal). Ne collez jamais de jeton dans la conversation. Vérifiez ensuite le compte actif avec `gh auth status`.

## La CI échoue alors que tout passe en local

**Causes courantes** : la version de Flutter de la CI diffère de la vôtre (le gabarit l'épingle sur `flutter --version` au moment de l'ajout ; update-project signale l'écart et vous propose d'aligner la ligne `flutter-version:`) ; un fichier non formaté (`dart format --set-exit-if-changed .`) ; un fichier oublié dans le commit.

**Solution** : `/plugin-flutter:github-workflow checks` fait lire les journaux à l'agent devops-engineer, qui classe l'échec ; un échec du code part ensuite vers `/plugin-flutter:debug-project`.

## Les agents ne peuvent ni écrire ni lancer `flutter test`

**Symptôme** : `Blocked by plugin-flutter (agent-scope-guard): test-engineer may only write under: test/, integration_test/` pour un fichier qui est pourtant sous `test/`.

**Cause** : la session a été lancée ailleurs qu'à la racine du projet, par exemple dans le dossier parent. Les hooks prennent le dossier de lancement (`CLAUDE_PROJECT_DIR`) comme racine.

**Solution** : quitter, puis `cd <projet> && claude`. Dans VSCode, ouvrir le dossier **du projet**, pas son parent.

## Les règles `allow` du projet sont ignorées

**Symptôme** : Claude demande la permission pour `flutter test` ou `git status` malgré `.claude/settings.json`. Au démarrage, Claude Code écrit sur sa sortie d'erreur `Ignoring N permissions.allow entries … this workspace has not been trusted`.

**Cause** : la confiance du workspace n'a pas été accordée. Les `allow` d'un projet restent inertes jusque-là ; `deny` et `ask` s'appliquent toujours.

**Solution** : ouvrir une session interactive dans le dossier et accepter la question de confiance. En mode `-p`, passer les outils par `--allowedTools`.

## `.forge/config.yaml` n'est pas créé

**Symptôme** : bootstrap-project ou adopt-existing-project signale que l'écriture de `.forge/config.yaml` a été refusée, et affiche une commande `! … sed … > .forge/config.yaml`.

**Cause** : le hook protect-sensitive protège ce fichier partout, puisque c'est lui qui porte vos préautorisations. En mode non interactif, personne ne peut confirmer l'écriture, qui est donc refusée.

**Solution** : lancer la commande affichée, depuis la racine du projet ; elle copie le gabarit du plugin en y mettant vos plateformes (et, pour une adoption, votre branche principale). Puis dire au skill de continuer.

## adopt-existing-project s'arrête dès le début

**Causes**, dans l'ordre où le skill les vérifie :

- pas de `pubspec.yaml` Flutter à la racine de la session : relancer Claude Code dans le dossier de l'app ;
- `.forge/` existe déjà : le projet est adopté, utilisez recover-session ou create-feature ;
- le dossier n'est pas un dépôt Git : vérifiez qu'il ne contient pas de secret, puis `git init -b main` et un premier commit, par vous ;
- des modifications non commitées : committez-les ou mettez-les de côté vous-même ;
- la branche courante n'est pas la branche principale : `git switch <branche principale>`.

## update-project ne met pas Flutter à jour

**Cause** : voulu. `flutter upgrade`, `flutter downgrade` et `flutter channel` changent Flutter pour tous les projets de la machine : le skill ne les lance jamais. Quand `flutter --version --machine` donne une racine sous `/nix/store/`, Flutter vient de Nix et ne change que par votre configuration Nix.

**Solution** : mettre Flutter à jour vous-même (configuration Nix, ou `! flutter upgrade`), puis dire au skill de continuer. Il relève la nouvelle version, relance les vérifications et vous propose d'aligner `flutter-version:` dans `.github/workflows/ci.yml`.

## `dart pub …` sort en 69

**Cause** : dans un projet Flutter, `dart pub` a besoin du `dart` fourni avec Flutter. Sous NixOS, le `dart` du `PATH` peut en être un autre.

**Solution** : `flutter pub …`, que les skills utilisent toujours.

## `flutter pub get --enforce-lockfile` sort en 65

**Cause** : `pubspec.lock` ne correspond plus à `pubspec.yaml`, par exemple après une contrainte modifiée à la main. Un `flutter pub get` simple le réécrirait.

**Solution** : update-project vous propose de le resynchroniser dans un premier commit, à part (`chore(deps): sync pubspec.lock with pubspec.yaml`). Pendant une adoption, l'analyse et les tests de référence sont notés « non exécutés », et la resynchronisation est laissée à update-project.

## `.claude/settings.json` n'est pas installé

**Symptôme** : bootstrap-project signale que l'écriture de `.claude/settings.json` a été refusée.

**Cause** : Claude Code protège ses fichiers de configuration. En mode non interactif, ou sans votre confirmation, il refuse de les écrire, même quand l'outil `Write` est autorisé. C'est voulu : un dépôt ne doit pas pouvoir s'accorder des permissions tout seul.

**Solution** : lancer vous-même la commande de copie que le skill affiche, depuis la racine du projet :

```bash
mkdir -p .claude && cp <dossier du plugin>/templates/project-settings.json .claude/settings.json
```

Tant que ce n'est pas fait, aucune règle du projet ne s'applique, y compris la protection de `.forge/config.yaml`.

## Un commit est refusé en mode `-p`

**Cause** : la règle `ask` sur `git commit` du gabarit demande une confirmation, et personne ne peut répondre en mode non interactif.

**Solution** : committer en session interactive, ou vous-même. Ce comportement est voulu.

## Un agent semble avoir plus d'outils que prévu

**Cause probable** : son frontmatter ne se lit plus. Claude Code charge alors l'agent avec tous ses champs ignorés, donc avec **tous les outils**, sans message. Le validateur officiel ne le détecte pas, même avec `--strict` : `claude plugin validate agents --strict` accepte par exemple `description: Use when: …`, qui n'est pas du YAML valide.

**Solution** : `bash tests/static/test_frontmatter.sh` nomme la ligne fautive. Un `: ` dans une valeur exige des guillemets. agent-scope-guard continue de limiter les écritures et les commandes des cinq agents.

## Claude reprend la main pour mettre à jour le checkpoint

**Symptôme** : en fin de tour, « Stop hook feedback » demande de mettre à jour `.forge/checkpoint.md`.

**Cause** : le checkpoint est plus ancien que le dernier commit ou qu'un fichier modifié, y compris un fichier que vous avez modifié vous-même dans l'éditeur. Un dernier commit qui contient le checkpoint lui-même, inchangé depuis, ne déclenche rien : le checkpoint est écrit juste avant le commit qui le porte, et n'est plus modifié ensuite (depuis la v0.3).

**Solution** : laisser Claude le mettre à jour (une seule reprise par fin de tour, jamais deux de suite), ou le mettre à jour vous-même. Le hook se tait dès que le checkpoint est à jour, et ne parle jamais dans un projet sans `.forge/checkpoint.md`.

## `format-dart` ne formate rien

**Causes** : `dart` n'est pas dans le `PATH` de Claude Code ; le fichier n'a pas l'extension `.dart` ; le fichier contient une erreur de syntaxe, que `dart format` refuse. Le hook est fail-open et ne signale rien.

**Vérifier** : `command -v dart` dans le même environnement que Claude Code ; `dart format <fichier>` à la main.

## Une modification du plugin n'est pas prise en compte

**Cause** : une marketplace locale est lue sur place, mais une session déjà ouverte garde l'état chargé.

**Solution** : `/reload-plugins` dans la session, ou une nouvelle session.

## Version de Claude Code antérieure à 2.1.295

Le champ `onFailure` des hooks est alors inconnu. Le guard bloque toujours sur ses propres erreurs (exit 2), mais un script introuvable ou un délai dépassé laissent passer la commande. Mettre Claude Code à jour.
