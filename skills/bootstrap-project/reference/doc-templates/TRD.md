# TRD — <App name>

| | |
| --- | --- |
| Objective | How the app is built: structure, state, navigation, data, platforms and dependencies |
| Status | DRAFT |
| Approved | — (date and approver, written only after the user's explicit approval) |
| Assumptions | <what this document takes for granted> |
| Confirmed decisions | <decisions the user has confirmed, with their date> |
| Related documents | docs/product/PRD.md, docs/engineering/DECISIONS.md |
| Verification criteria | The code follows this layout; every dependency has an ADR with its platform check |

## Architecture

Feature-first layout:

```
lib/
├── main.dart
├── app/            # MaterialApp, routing, theme
├── core/           # cross-cutting utilities, errors
└── features/<feature>/
    ├── data/           # sources, repositories
    ├── domain/         # models, pure logic
    └── presentation/   # widgets, state
```

Tests mirror `lib/` under `test/`; integration tests live in `integration_test/`.

## Technical defaults

Each deviation is an ADR in DECISIONS.md.

| Concern | Default | Choice |
| --- | --- | --- |
| Channel | Flutter stable | <version from `flutter --version`> |
| Lints | `flutter_lints`, strict analyzer modes | |
| State | Riverpod | |
| Navigation | `go_router` | |
| Persistence | local first, before any remote backend | |

## Platforms

Three distinct states: enabled (folder present), built (build succeeded, command recorded), tested (tests run on that target).

| Platform | Enabled | Built | Tested | Notes |
| --- | --- | --- | --- | --- |
| <platform> | yes/no | not verified | not verified | |

## Dependencies

| Package | Why | Alternative considered | Platforms checked | ADR |
| --- | --- | --- | --- | --- |

## Data

<Local data first. When a backend is considered, write BACKEND_SCHEMA.md with three parts: local data, real needs for a backend, future evolutions.>

## Testing approach

<Unit, widget and integration tests; what runs on which platform.>

## Risks

- <risk> — <mitigation>
