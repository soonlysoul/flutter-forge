# PROGRESS — dart-multiplatform-forge v0.1

Dernière mise à jour : 2026-10-18T00:30+02:00
Reprise : « Reprends depuis PROGRESS.md » → lire ce fichier, puis `git log --oneline`.

## État courant

**Phase C — terminée.** Phase D à venir.

Décisions D1 à D9 (`docs/PHASE_A_REPORT.md` §7) : le questionnaire a été refusé, puis la consigne « continue » donnée. Les recommandations du §7 sont donc appliquées **par défaut**, et chacune reste révisable :

| # | Retenu |
| --- | --- |
| D1 | Corrections E1–E19 reportées dans ARCHITECTURE.md (statut REVIEW, pas APPROVED) |
| D2 | `agent-scope-guard` ajouté à la v0.1 |
| D3 | checkpoint-reminder fait reprendre Claude une fois (`additionalContext`) |
| D4 | guard étendu à `git restore` (hors `--staged`), `git stash drop`/`clear` |
| D5 | Auteur, propriétaire et titulaire MIT : `Allosun` ; marketplace `dart-multiplatform-forge` |
| D6 | Dépôt initialisé sur place, `~/Documents/claude-plugin/App` (rien déplacé) |
| D7 | `inherit` pour flutter-architect, `sonnet` pour test-engineer et code-reviewer |
| D8 | **Non tranché** : ne concerne que la phase F avec quota, qui attend votre accord |
| D9 | Rédaction directe des agents, puis `skill-reviewer` en fin de phase D |

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

## Phases suivantes
- [ ] D — Agents, skills, gabarits, revue `skill-reviewer`, commit
- [ ] E — `tests/run-all.sh` au vert, commit
- [ ] F.1 — Validation sans quota (`flutter create`/`test` jetable, `plugin details`, scénario 4 au niveau du hook)
- [ ] F.2 — Scénarios headless 1 à 5 : **attend votre accord** (quota), et D8
- [ ] G — Docs FR, CHANGELOG 0.1.0, commit final
