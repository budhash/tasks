# TASKS.md schema (quick reference)

The full, canonical spec is printed by `./tasks.py help` (the in-file
docstring). This is the cheat-sheet.

## Document structure

```
# Meta            Schema docs + metadata
# Tasks           The work items
  ## Now          Active work (priority-sorted)
  ## Backlog      Future work
  ## Skipped      Deprioritized
# Notes           Free-form notes keyed by item ID
```

## Item line

One line per item, exact format:

```
- [ ] (F-0001) [P1] [todo] Feature title @deps=T-0001 @tags=mvp
  - [x] (T-0007) [P0] [done] A task @effort=4h @done=2026-01-01
```

- `(F-####)` / `(T-####)` — unique immutable ID (F = feature, T = task).
- `[P0|P1|P2|P3]` — priority (P0 = critical).
- `[todo|doing|done|skipped|deferred]` — status.
- Checkbox follows status: `[x]` iff `done`, else `[ ]`.
- Indent 2 spaces per level for parent/child hierarchy.
- Indented bullets without an ID under an item are "detail lines" (preserved
  on subtree moves).

## Tags (optional)

| Tag | Meaning |
|---|---|
| `@deps=F-2,T-11` | Blocked by / depends on |
| `@rel=T-100` | Related |
| `@branch=feat/x` | Implementing branch |
| `@pr=123` | Pull request number |
| `@issue=42` | GitHub issue number |
| `@tags=a,b` | Custom tags |
| `@effort=4h` | Estimated effort |
| `@system=sprint-1` | System tag (sprint-*/milestone-*/phase-*/epic-*) |
| `@done=YYYY-MM-DD` | Completion date (auto-added) |

## Sections

Items live under `## Now`, `## Backlog`, or `## Skipped` (inside `# Tasks`).
`skip` moves an item to `## Skipped` **and** sets status `skipped`; `defer` only
sets status `deferred` and leaves the item in place.

## Shadow features

When a task is skipped/scattered into a section its parent feature isn't in,
`tasks` leaves a lightweight copy of the parent feature line tagged `@shadow` in
that section, so the hierarchy stays readable across sections. Shadows are
created and cleaned up automatically — treat them as derived; don't hand-edit.

## Invariants enforced

- Unique, immutable IDs (auto-generated; never reused).
- At most one task `[doing]` at a time (single active task).
- Checkbox state always matches status.
- `validate` exits non-zero on any violation (CI-friendly).
