# Dépannage

Premier réflexe, depuis le dossier du plugin :

```bash
claude plugin details plugin-flutter        # le plugin est-il chargé, avec ses composants ?
claude plugin details plugin-orchestrator   # l'orchestrateur aussi ?
bash tests/run-all.sh                       # ses fichiers sont-ils intacts ?
```

Les blocages par guard-destructive, secret-scan ou protect-sensitive, le rappel du checkpoint et les documents repassés en REVIEW viennent des hooks de plugin-orchestrator : voir son [TROUBLESHOOTING.md](https://github.com/soonlysoul/plugin-orchestrator/blob/main/docs/TROUBLESHOOTING.md).

## Une skill de plugin-flutter s'arrête sur plugin-orchestrator

**Symptôme** : update-project ou adopt-existing-project dit qu'il faut plugin-orchestrator 0.1.0 ou plus, et s'arrête sans rien faire.

**Cause** : aucun skill `plugin-orchestrator:…` n'est chargé dans la session : le plugin n'est pas installé, est désactivé, ou a été installé après l'ouverture de la session.

**Solution** : `claude plugin install plugin-orchestrator@soon --scope user` (ou `claude plugin enable plugin-orchestrator@soon`), puis une nouvelle session.

## Une skill montre un bloc `parts` à ajouter

**Symptôme** : update-project, ou un workflow de l'orchestrateur, s'arrête sur un `.forge/config.yaml` sans `parts` (`schema_version: 1`).

**Cause** : le projet a été créé avec plugin-flutter 0.x. Claude n'édite jamais ce fichier.

**Solution** : l'éditer vous-même, comme le décrit [la migration](INSTALLATION.md#migrer-un-projet-de-plugin-flutter-0x), puis relancer.

## L'orchestrateur refuse de déléguer à plugin-flutter

**Symptôme** : un workflow de l'orchestrateur s'arrête sur un rapport sans `INTERFACE: 1`, ou dit que plugin-flutter n'expose pas de scaffold à l'interface 1, et demande sa mise à jour.

**Cause** : la copie de plugin-flutter chargée est une 0.x. Les hooks communs tournent alors aussi en double.

**Solution** : `claude plugin marketplace update soon`, puis `claude plugin update plugin-flutter@soon`, et une nouvelle session ; `claude plugin details plugin-flutter` doit annoncer 1.0.0 ou plus.

## Le scaffold s'arrête sur un projet en sous-dossier

**Symptôme** : au démarrage d'un projet, le scaffold-engineer rend `STATUS: blocked` : le projet n'est pas à la racine de la session.

**Cause** : ses limites d'écriture comptent depuis le dossier où la session a été lancée.

**Solution** : `cd <projet> && claude`, puis `/plugin-orchestrator:recover-session` : le démarrage reprend au scaffold, Git et `.forge/` déjà en place.

## Les agents du plugin sont bloqués en tout

**Symptôme** : chaque appel d'un agent du plugin échoue avec `Blocked by plugin-flutter (agent-scope-guard): jq is required…`.

**Cause** : `jq` est absent du `PATH` de Claude Code. agent-scope-guard est fail-closed : sans `jq`, il ne peut pas lire l'appel, donc il le refuse. Le guard-destructive de l'orchestrateur bloque alors aussi toutes les commandes shell.

**Solution** : installer `jq` (sous NixOS, par la configuration système ou Home Manager), puis relancer la session.

## « hook error … failed; blocking because onFailure is "block" »

**Cause** : le script du hook n'a pas pu s'exécuter : fichier absent, `bash` introuvable, délai dépassé. Le hook bloque alors par construction.

**Solution** : `bash tests/run-all.sh` signale un script manquant (`test_paths`). Vérifier que `bash` est sur le `PATH`. Le plugin n'utilise jamais `/bin/bash`, absent sous NixOS.

## La CI échoue alors que tout passe en local

**Causes courantes** : la version de Flutter de la CI diffère de la vôtre (le gabarit l'épingle sur `flutter --version` au moment de l'ajout ; update-project signale l'écart et vous propose d'aligner la ligne `flutter-version:`) ; un fichier non formaté (`dart format --set-exit-if-changed .`) ; un fichier oublié dans le commit.

**Solution** : `/plugin-orchestrator:github-workflow checks` fait lire les journaux à l'agent devops-engineer de plugin-flutter, qui classe l'échec ; un échec du code part ensuite vers `/plugin-orchestrator:debug-project`.

## Les agents ne peuvent ni écrire ni lancer `flutter test`

**Symptôme** : `Blocked by plugin-flutter (agent-scope-guard): test-engineer may only write under: test/, integration_test/` pour un fichier qui est pourtant sous `test/`.

**Cause** : la session a été lancée ailleurs qu'à la racine du projet, par exemple dans le dossier parent. Les hooks prennent le dossier de lancement (`CLAUDE_PROJECT_DIR`) comme racine.

**Solution** : quitter, puis `cd <projet> && claude`. Dans VSCode, ouvrir le dossier **du projet**, pas son parent.

## Les règles `allow` du projet sont ignorées

**Symptôme** : Claude demande la permission pour `flutter test` ou `git status` malgré `.claude/settings.json`. Au démarrage, Claude Code écrit sur sa sortie d'erreur `Ignoring N permissions.allow entries … this workspace has not been trusted`.

**Cause** : la confiance du workspace n'a pas été accordée. Les `allow` d'un projet restent inertes jusque-là ; `deny` et `ask` s'appliquent toujours.

**Solution** : ouvrir une session interactive dans le dossier et accepter la question de confiance. En mode `-p`, passer les outils par `--allowedTools`.

## `.forge/config.yaml` n'est pas créé

**Symptôme** : adopt-existing-project signale que l'écriture de `.forge/config.yaml` a été refusée, et affiche une commande `! … sed … > .forge/config.yaml`.

**Cause** : le protect-sensitive de l'orchestrateur protège ce fichier partout, puisque c'est lui qui porte vos préautorisations. En mode non interactif, personne ne peut confirmer l'écriture, qui est donc refusée.

**Solution** : lancer la commande affichée, depuis la racine du projet ; elle copie le gabarit du plugin en y mettant vos plateformes (et, pour une adoption, votre branche principale). Puis dire au skill de continuer.

## adopt-existing-project s'arrête dès le début

**Causes**, dans l'ordre où le skill les vérifie :

- pas de `pubspec.yaml` Flutter à la racine de la session : relancer Claude Code dans le dossier de l'app ;
- plugin-orchestrator absent de la session : voir plus haut ;
- `.forge/` existe déjà : le projet est adopté, utilisez `/plugin-orchestrator:recover-session` ou `/plugin-orchestrator:create-feature` ; sans `parts`, ajoutez d'abord le bloc que le skill montre ;
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

**Symptôme** : le bootstrap de l'orchestrateur ou adopt-existing-project signale que l'écriture de `.claude/settings.json` a été refusée.

**Cause** : Claude Code protège ses fichiers de configuration. En mode non interactif, ou sans votre confirmation, il refuse de les écrire, même quand l'outil `Write` est autorisé. C'est voulu : un dépôt ne doit pas pouvoir s'accorder des permissions tout seul.

**Solution** : lancer vous-même la commande de copie que le skill affiche, depuis la racine du projet :

```bash
mkdir -p .claude && cp <dossier de plugin-flutter>/templates/project-settings.json .claude/settings.json
```

Tant que ce n'est pas fait, aucune règle du projet ne s'applique, y compris la protection de `.forge/config.yaml`.

## Un commit est refusé en mode `-p`

**Cause** : la règle `ask` sur `git commit` du gabarit demande une confirmation, et personne ne peut répondre en mode non interactif.

**Solution** : committer en session interactive, ou vous-même. Ce comportement est voulu.

## Un agent semble avoir plus d'outils que prévu

**Cause probable** : son frontmatter ne se lit plus. Claude Code charge alors l'agent avec tous ses champs ignorés, donc avec **tous les outils**, sans message. Le validateur officiel ne le détecte pas, même avec `--strict` : `claude plugin validate agents --strict` accepte par exemple `description: Use when: …`, qui n'est pas du YAML valide.

**Solution** : `bash tests/static/test_frontmatter.sh` nomme la ligne fautive. Un `: ` dans une valeur exige des guillemets. agent-scope-guard continue de limiter les écritures et les commandes des cinq agents.

## `format-dart` ne formate rien

**Causes** : `dart` n'est pas dans le `PATH` de Claude Code ; le fichier n'a pas l'extension `.dart` ; le fichier contient une erreur de syntaxe, que `dart format` refuse. Le hook est fail-open et ne signale rien.

**Vérifier** : `command -v dart` dans le même environnement que Claude Code ; `dart format <fichier>` à la main.

## Une modification du plugin n'est pas prise en compte

**Cause** : une marketplace locale est lue sur place, mais une session déjà ouverte garde l'état chargé.

**Solution** : `/reload-plugins` dans la session, ou une nouvelle session.

## Version de Claude Code antérieure à 2.1.295

Le champ `onFailure` des hooks est alors inconnu. agent-scope-guard bloque toujours sur ses propres erreurs (exit 2), mais un script introuvable ou un délai dépassé laissent passer l'appel. Mettre Claude Code à jour.
