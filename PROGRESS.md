# PROGRESS — plugin-flutter v0.1

Dernière mise à jour : 2026-10-19
Reprise : « Reprends depuis PROGRESS.md » → lire ce fichier, puis `git log --oneline`.

## État courant

**v0.1.0 clôturée le 2026-10-19** (« clôture la v1 ») : phases A à G faites, rapport final dans `docs/V0.1_REPORT.md`, ARCHITECTURE.md en APPROVED, tag local `v0.1.0`. Suite déterministe verte à la clôture : 502 assertions, 4 validations. Prochaine étape : la v0.2 (github-workflow, debug-project, devops-engineer, secret-scan), qui ne démarre que sur votre demande.

**v0.1.1 publiée le 2026-10-19** : le plugin s'appelle désormais `flutter-forge` (ex-`dart-multiplatform-forge`), auteur `Soon`. Il est publié dans le dépôt public `soonlysoul/flutter-forge` et s'installe sur tout appareil depuis la marketplace `soon` (dépôt public `soonlysoul/claude-plugins`) : `claude plugin install flutter-forge@soon`. Voir D10.

**v0.1.2 publiée le 2026-10-19** : le plugin s'appelle désormais `plugin-flutter` (ex-`flutter-forge`), dans le dépôt public `soonlysoul/plugin-flutter` : `claude plugin install plugin-flutter@soon`. Voir D11.

Décisions D1 à D9 (`docs/PHASE_A_REPORT.md` §7) : le questionnaire a été refusé, puis la consigne « continue » donnée. Les recommandations du §7 sont donc appliquées **par défaut**, et chacune reste révisable :

| # | Retenu |
| --- | --- |
| D1 | Corrections E1–E19 reportées dans ARCHITECTURE.md ; REVIEW, puis APPROVED à la clôture du 2026-10-19 |
| D2 | `agent-scope-guard` ajouté à la v0.1 |
| D3 | checkpoint-reminder fait reprendre Claude une fois (`additionalContext`) |
| D4 | guard étendu à `git restore` (hors `--staged`), `git stash drop`/`clear` |
| D5 | *(remplacée par D10)* Auteur et titulaire MIT : `Allosun` ; propriétaire de la marketplace : `Soon` (votre modification du 2026-10-19) ; marketplace `dart-multiplatform-forge` |
| D6 | Dépôt initialisé sur place, `~/Documents/claude-plugin/App` (rien déplacé) |
| D7 | `inherit` pour flutter-architect, `sonnet` pour test-engineer et code-reviewer |
| D8 | Profil `~/.claude`, celui de cette session : vous avez validé la phase F.2 le 2026-10-19 sans désigner d'autre compte |
| D9 | Rédaction directe des agents, puis `skill-reviewer` en fin de phase D |
| D10 | *(nom et dépôt remplacés par D11)* 2026-10-19, à votre demande : nom `flutter-forge` ; auteur et titulaire MIT `Soon` ; dépôts **publics** ; catalogue séparé `soonlysoul/claude-plugins` (marketplace `soon`) qui référence `soonlysoul/flutter-forge` en source `github` ; `version` dans `plugin.json` seulement, augmentée à chaque release. Les rapports datés (`PHASE_A_REPORT`, `V0.1_REPORT`) gardent l'ancien nom. |
| D11 | 2026-10-19, à votre demande : nom `plugin-flutter`, dépôt `soonlysoul/plugin-flutter`, à l'image de `plugin-nixos`. Version 0.1.2, un correctif comme le renommage précédent : la 0.2 reste celle des skills et agents prévus. Le CHANGELOG 0.1.1 et D10 gardent l'ancien nom. |

## Phase A — Audit et vérification — terminée

Rapport : `docs/PHASE_A_REPORT.md`. Détail des commandes de la phase A : historique git de ce fichier (commit `70895b6`).

## Phase B — Squelette — terminée

- [x] B.1 `git init -b main` ; commit de l'état audité (`70895b6`)
- [x] B.2 Corrections E1–E19 dans ARCHITECTURE.md, statut → REVIEW (`036a162`)
- [x] B.3 `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `LICENSE`, `.gitignore`
- [x] B.4 Validation stricte
- [x] B.5 Commit `chore: scaffold plugin skeleton`

| Commande | Résultat |
| --- | --- |
| `git init -b main` | exit 0 |
| `claude plugin validate . --strict` | exit 0 — ne valide **que** `marketplace.json` |
| `claude plugin validate . --strict --json` | exit 0, `success: true`, `contents: []` |
| `claude plugin validate .claude-plugin/plugin.json --strict` | exit 0 |

Correction du rapport de phase A, §3.2 : avec la racine `.`, le validateur ne contrôle que la marketplace. `plugin.json` doit être visé explicitement, d'où deux validations dans `run-all.sh`.

## Phase C — Hooks et leurs tests — terminée

TDD : chaque cycle a vu son test échouer pour la bonne raison (script vide ou règle absente), puis passer.

| Cycle | Objet | ROUGE | VERT |
| --- | --- | --- | --- |
| C1 | guard : contrat d'entrée, fail-closed | 10 échecs | 13/13 |
| C2 | guard : analyseur (composition, préfixes, citations, heredocs, `bash -c`, `eval`, `$(…)`) | 39 échecs | 66/66 |
| C3 | guard : règles git | 41 échecs | 133/133 |
| C4 | guard : rm, gh, pub, find, xargs | 37 échecs | 200/200 |
| C5 | agent-scope-guard | 40 échecs | 73/73 |
| C6 | format-dart | 3 échecs | 16/16 (dont le vrai `dart format`) |
| C7 | checkpoint-reminder | 4 échecs | 15/15 |
| C8 | `hooks/hooks.json` (test_paths, volet hooks) | 1 échec (fichier absent) | 36/36 |
| C2b | revue : substitutions des heredocs non cités | 3 échecs | 206/206 |

Deux échecs inattendus, débogués :

- **`missing jq is named in the reason`** : sans PATH, `dirname` était introuvable, et le script bloquait sur « bibliothèque absente » au lieu de nommer `jq`. Corrigé par une expansion bash.
- **Champs décalés dans test_paths** : `read` fusionne des tabulations consécutives, ce qui perdait le `matcher` vide de `Stop`. Corrigé par le séparateur `\x1f`.

Fichiers :

- `hooks/hooks.json`
- `hooks/scripts/{guard-destructive,agent-scope-guard,format-dart,checkpoint-reminder}.sh`
- `hooks/scripts/lib/shell-lexer.sh`
- `tests/lib.sh`
- `tests/hooks/test_{guard_destructive,agent_scope_guard,format_dart,checkpoint_reminder}.sh`
- `tests/static/test_paths.sh` (volet hooks)

| Commande | Résultat |
| --- | --- |
| `bash tests/hooks/test_guard_destructive.sh` | exit 0 — 206 réussis |
| `bash tests/hooks/test_agent_scope_guard.sh` | exit 0 — 73 réussis |
| `bash tests/hooks/test_format_dart.sh` | exit 0 — 16 réussis |
| `bash tests/hooks/test_checkpoint_reminder.sh` | exit 0 — 15 réussis |
| `bash tests/static/test_paths.sh` | exit 0 — 36 réussis |
| `claude plugin validate .claude-plugin/plugin.json --strict` | exit 0 ; `--json` : `contents: []`, donc les hooks ne sont **pas** inspectés par le validateur |
| `claude plugin validate . --strict` | exit 0 |

Limites relevées en revue, à documenter dans SECURITY.md (phase G) :

- commande désignée par une variable ;
- alias git ;
- citation `$'…'` ;
- `pwsh -Command` et `Remove-Item` ;
- `find -delete` ;
- `rm -r` sans `-f` ;
- tag poussé par son seul nom ;
- `git checkout <fichier>` sans `--` ;
- liens symboliques (agent-scope-guard) ;
- racine = `CLAUDE_PROJECT_DIR`, donc le dossier de lancement.

Testé sous bash 5.2 seulement ; bash 3.2 (macOS) non vérifié.

## Phase D — Agents, skills, gabarits — terminée

TDD : les tests statiques ont été écrits d'abord, et ont échoué sur l'absence des fichiers. L'auto-test de l'analyseur strict passait déjà : 7 frontmatters cassés rejetés.

Fichiers :

- `agents/{flutter-architect,test-engineer,code-reviewer}.md`
- `skills/{bootstrap-project,create-feature,git-workflow,recover-session}/SKILL.md`
- `skills/bootstrap-project/reference/doc-templates/{PRD,TRD,IMPLEMENTATION_PLAN,DECISIONS,CLAUDE}.md`
- `templates/{project-settings.json,forge-config.yaml,checkpoint.md}`
- `tests/static/test_{frontmatter,tdd_skill,settings_template}.sh`
- volet skills de `tests/static/test_paths.sh`

Constats :

- **`argument-hint: [app-name]` est une liste YAML**, pas une chaîne : le test strict l'a refusé, et les trois valeurs sont désormais citées.
- **Validateur officiel** : même en `--strict` sur `agents/`, il **accepte** un frontmatter invalide (`description: Use when: …`, `[unclosed`, `---` jamais refermé). Sonde : exit 0 dans les trois cas. `test_frontmatter.sh` est donc la seule barrière.
- **Un premier essai de sonde était faux** : un dossier qui ne s'appelle pas `agents/` est validé comme un plugin, et échoue faute de manifeste. Il a été refait avec des dossiers `agents/`.
- **`test_tdd_skill`** comparait en tenant compte de la casse (« Wait » ≠ « wait ») : le test a été corrigé, pas le contenu.

Revue `plugin-dev:skill-reviewer` (une passe, lecture seule) : 2 constats bloquants, 10 importants et 8 mineurs. Chacun a été vérifié sur les fichiers avant correction.

- **B1** : un projet créé dans un sous-dossier a pour racine de hooks le dossier parent, si bien que les agents ne peuvent ni écrire ni lancer `flutter test`. Correctif : bootstrap crée de préférence dans le dossier courant, rédige lui-même le TRD sinon, et demande une nouvelle session à la racine. create-feature vérifie `${CLAUDE_PROJECT_DIR}`.
- **B2** : rien n'est commité avant l'étape 15, donc la revue portait sur un diff vide. Correctif : indexation explicite, puis revue de `git diff --cached <base>`.
- **Importants** :
  - descriptions limitées aux projets ayant `.forge/` ;
  - checkpoint ignoré à l'étape 1 et à la création de branche ;
  - tests ROUGE déjà verts : arrêt ;
  - PRD et TRD doivent être APPROVED ;
  - dépendance ajoutée et plateformes vérifiées dès l'étape 4 ;
  - étapes 11 et 12 relancées après les corrections de revue, arrêt si un constat bloquant subsiste ;
  - `restore --staged` autorisé, et `git rm --cached` prévu avant le premier commit ;
  - un TRD APPROVED modifié repasse en DRAFT, et un nouvel ADR est `proposed` ;
  - appareil fourni pour `integration_test/`, sinon tests classés bloqués.
- **Écart assumé** (constat 5) : l'ordre des étapes 13 et 14 d'ARCHITECTURE.md est gardé. Le reviewer liste désormais les docs à mettre à jour (`DOCS_TO_UPDATE`), au lieu de les signaler comme constats.
- **Tests** : 9 assertions ajoutées d'abord (ROUGE : 9 échecs), puis corrections (VERT).

## Phase E — Tests déterministes — terminée

- `tests/static/test_manifest.sh`. ROUGE par mutation : une copie aux manifestes faussés échoue sur exactement les 6 propriétés mutées. Puis 14/14 sur le vrai plugin.
- `tests/run-all.sh` : 9 suites, puis `claude plugin validate --strict` sur `.`, `.claude-plugin/plugin.json`, `agents` et `skills`.
- `tests/scenarios/` : README, scénarios 01 à 05, et `headless.sh`, qui refuse de tourner sans `FORGE_ALLOW_QUOTA=1` ou depuis le dossier du plugin. Les deux refus ont été vérifiés, exit 2.

| Commande | Résultat |
| --- | --- |
| `bash tests/run-all.sh` | exit 0 — 13 réussis (9 suites, 500 assertions, 4 validations), 0 échoué, 0 bloqué ; après F.2 : 502 assertions |

## Phase F.1 — Validation sans quota — faite

| Commande | Résultat |
| --- | --- |
| `flutter create --org com.example --project-name demo_probe --platforms linux …` (scratchpad) | exit 0 |
| `flutter test` (projet jetable) | exit 0 — 1 test réussi |
| `flutter analyze` (projet jetable) | exit 0 — aucun problème |
| guard-destructive sur `git reset --hard` dans ce dépôt réel, fichier modifié non commité | exit 2, raison claire ; empreinte du fichier inchangée |
| `claude --plugin-dir . plugin details dart-multiplatform-forge` | exit 0 — `@inline`, 4 skills, 3 agents, hooks sur 3 événements ; ~848 jetons permanents |
| Projets de `~/.claude.json` avant / après | 36 / 36 |

## Phase F.2 — Scénarios réels — terminée (accord donné le 2026-10-19)

Profil `~/.claude`, celui de cette session (D8 : aucun autre compte désigné). Avant de commencer, copie de `~/.claude.json` dans le scratchpad. Scénarios lancés un par un. Résultat : 36 projets avant comme après, aucun perdu.

| Scénario | Tours | Résultat | Coût estimé (API) |
| --- | --- | --- | --- |
| 4 Blocage | 1 | **réussi** : un seul appel `git reset --hard`, refusé par guard-destructive (exit 2) avec sa raison ; aucune reformulation ; fichier intact | 0,25 $ |
| 1 Bootstrap | 3 | **réussi avec réserve** : arrêts aux étapes 2 et 7 ; création dans le dossier courant ; `.forge/`, 4 docs en DRAFT, 6 autorisations à `false` ; `flutter test` exit 0 (revérifié). Réserve : `.claude/settings.json` refusé par Claude Code en `-p`, non contourné, copié à la main | 3,27 $ |
| 2 Feature TDD | 2 | **réussi** : arrêt à l'étape 2 (DRAFT) ; puis étapes 3 à 14. Tests écrits par le test-engineer, sous `test/` seulement ; ROUGE exit 1 puis VERT exit 0 consignés ; revue de `git diff --cached main` ; commit refusé (règle `ask`), puis fait à la main | 3,54 $ |
| 3 Préservation | 1 | **réussi** : arrêt à l'étape 1 avec 3 options ; `lib/main.dart` identique (sha256), aucun stash | 0,52 $ |
| 5 Reprise | 1 | **réussi** : un seul `flutter test` ciblé (ROUGE confirmé) ; aucun agent, aucune écriture ; étape 8 proposée ; 3 vraies incohérences du jeu d'essai relevées | 0,44 $ |

Total : environ 8,02 $ en équivalent API, sur le quota de l'abonnement.

Défauts trouvés et corrigés pendant F.2 :

- **checkpoint-reminder** se déclenchait à tort sur le dossier `.forge/` non suivi (`0da9906`, TDD : 2 tests ROUGE puis VERT) ;
- **bootstrap-project** donne désormais la commande de copie de `.claude/settings.json` quand l'écriture est refusée.

Constats sur la 2.1.296 : voir `tests/scenarios/README.md`, section « Observed ».

## Phase G — Documentation et rapport — terminée

- `README.md`, `docs/{INSTALLATION,USER_GUIDE,SECURITY,TROUBLESHOOTING}.md`, `CHANGELOG.md` (0.1.0), en français.
- Commandes vérifiées par `--help` avant d'être citées : `plugin install|uninstall -s/--scope`, `marketplace add --scope`, `marketplace remove`, `plugin disable|enable`, `plugin details`.
- Liens relatifs des docs : vérifiés, aucun cassé.

## Phases suivantes
- [x] D — Agents, skills, gabarits, revue `skill-reviewer`, commit (`f1f3e2b`)
- [x] E — `tests/run-all.sh` au vert, commit (`5e3fe7f`)
- [x] F.1 — Validation sans quota (`flutter create`/`test` jetable, `plugin details`, scénario 4 au niveau du hook)
- [x] F.2 — Scénarios headless 1 à 5 : tous réussis (1 avec réserve)
- [x] G — Docs complétées avec F.2, rapport `docs/V0.1_REPORT.md`, commit final
