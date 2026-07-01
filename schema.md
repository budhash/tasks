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

Machine tags live in the **trailing run of `@…` tokens** after the title. A
`@key=value` written inside the descriptive title/prose is left as text, not
parsed as a tag.

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
| `@milestone=m1` | Milestone id or alias (first-class; see Milestones) |
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

## Milestones (optional, opt-in)

A task may carry one `@milestone=<id-or-alias>` tag. It is fully optional and
orthogonal to `@system=`/`@tags=`: files with no milestone data behave exactly
as before, and a task without the tag falls into an implicit sentinel bucket
named `default` (override via `TASKS_MILESTONE_SENTINEL`; it must not look like
an `M<n>` id). The sentinel is never written into task lines.

An optional `# Milestones` registry (its own H1 section) maps ids → alias →
status → title, and powers alias resolution + rollups:

```
# Milestones

- M1  alias=alpha  status=active   Complete federal estimate
- M2  alias=beta   status=planned  Surfaces / API
```

With a registry, `@milestone=alpha` and `@milestone=m1` are the same milestone.
Without one, milestones are freeform (any string, grouped by raw value).

| Command | What |
|---|---|
| `new … --milestone m1` | Assign at creation |
| `set T-7 --milestone alpha` | Assign/change (alias ok); `""`, `clear`, or the sentinel name clears |
| `list --milestone m1` | Filter (alias-resolved; `default` = unassigned) |
| `milestone` / `milestone M1` / `milestone --table` | Rollup / one milestone's detail / milestone×features table |
| `next --milestone m1` | Next actionable task within a milestone |
| `migrate-tags-to-milestone m1` | Rewrite interim `@tags=m1` → `@milestone=m1` (conflicting `@milestone=` left intact + reported) |

`validate` warns (never errors) on an `@milestone=` value missing from the
registry, and on registry-health problems (duplicate ids, colliding aliases),
when a registry exists. Assigning an unknown milestone via `new`/`set` also
prints a freeform warning. The sentinel is never written into a task line.

## Invariants enforced

- Unique, immutable IDs (auto-generated; never reused).
- At most one task `[doing]` at a time (single active task).
- Checkbox state always matches status.
- `validate` exits non-zero on any violation (CI-friendly).
