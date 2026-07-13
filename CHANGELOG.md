# Changelog

All notable changes to `tasks`. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project uses
[semantic versioning](https://semver.org/).

## [1.3.0] — 2026-07-13

### Added
- `renumber OLD (NEW | --next) [--refs]` — reassign an item's ID without
  hand-editing (#12). Renames the primary line and all `@shadow` copies,
  repoints every `@deps=`/`@rel=` list containing the old ID (tag region only —
  prose mentions stay untouched, per the #9 rules), and renames the `## <OLD>`
  header in `# Notes`. Refuses an occupied target (use `--next` for the next
  free ID of the same kind), cross-kind moves, and no-ops. `--refs` prints a
  read-only report of remaining mentions across git-tracked files (canonical
  and short forms) — repointing those is deliberately left to the operator.
  Motivated by the multi-branch ID-collision incident; pairs with #13/#14.

## [1.2.0] — 2026-07-13

### Added
- `set ID --title "New title"` — replace an item's descriptive title in place,
  preserving its ID, status, priority, and all trailing machine tags (#18; the
  retitle half of #11). Applies to the primary line and any `@shadow` copies.
  Titles that would *end* with a tag-shaped token (e.g. `... @milestone=m1`) are
  rejected, since on re-parse that token would merge into the machine-tag
  region; tag-lookalikes elsewhere in the title stay prose, per the #9 rules.

## [1.1.2] — 2026-07-13

### Fixed
- Field edits landed on the first line carrying an ID in file order — which for
  a feature with a `@shadow` copy can be the shadow, not the canonical line.
  `set F-N --milestone m1` on such a feature tagged only the shadow, so the
  feature showed up in both its milestone and the `default` bucket (#17). The
  same first-match bug affected `set` (all tags), `link --deps/--rel`, `prio`,
  and the status verbs. All of these now apply to the primary line **and** every
  shadow copy, keeping the derived copies in sync — consistent with how shadows
  are created (copied from the primary, tags included).

## [1.1.1] — 2026-07-01

### Fixed
- Machine tags (`@milestone=`, `@deps=`, `@tags=`, `@effort=`, …) are now parsed
  and edited only in the trailing tag region of an item line, not by scanning the
  whole line. A task whose descriptive title merely *mentions* `@milestone=foo`
  (e.g. one titled after the `@tags=… → @milestone=…` migration) is no longer
  miscounted into a phantom milestone bucket by `milestone`, and
  `migrate-tags-to-milestone` no longer treats it as an already-assigned conflict
  and skips it. The write path is fixed too: `set`/`link` no longer strip a
  look-alike `@key=value` out of the title prose. (#9)

## [1.1.0] — 2026-07-01

### Added
- First-class **milestone** dimension (opt-in, fully backward-compatible). A task
  may carry one `@milestone=<id-or-alias>` tag; a task without it resolves to an
  implicit sentinel bucket (`default`, configurable via `TASKS_MILESTONE_SENTINEL`,
  which must not match the `M<n>` id pattern — the tool rejects one that does).
  The sentinel is never written to task lines, so existing `TASKS.md` files
  round-trip byte-for-byte.
- Optional `# Milestones` registry section mapping id → alias → status → title.
  When present it powers alias resolution (`@milestone=alpha` ≡ `@milestone=m1`)
  and rollups; when absent, milestones are freeform (grouped by raw value).
- CLI: `new … --milestone`, `set T-N --milestone` (`""` clears to the sentinel),
  `list --milestone` (alias-resolved; `default` = unassigned), `next --milestone`,
  a new `milestone` rollup command with a `milestone <id>` detail view and a
  `milestone --table` (milestone × features × status) view, and a
  `migrate-tags-to-milestone <tag>` helper for projects moving off the interim
  `@tags=<id>` convention. Migration leaves a task with a *conflicting*
  `@milestone=` untouched and reports it (never silently drops the label).
  `show` now displays a resolved `Milestone:` line.
- `validate` warns (exit 0) on an `@milestone=` value not in the registry, and on
  registry-health problems (duplicate ids, colliding aliases), when a registry
  exists; it never hard-fails on milestone data. Assigning an unknown milestone
  via `new`/`set` prints a non-fatal freeform warning.

## [1.0.1] — 2026-06-21

### Fixed
- `skip` (and other moves into `## Skipped`) crashed with `TypeError: NoneType
  + int` when the target standard section didn't already exist in `TASKS.md`
  (e.g. a project that never skipped a task, so it had no `## Skipped`). Missing
  standard sections (`Now`/`Backlog`/`Skipped`) are now auto-created in
  canonical order — consistent with shadow-feature auto-creation. (#1)

## [1.0.0] — 2026-06-21

Initial release.

### Features
- Single-file, zero-dependency task tracker for a plain-text `TASKS.md`
  (Python 3.8+, standard library only).
- Hierarchy-aware features and tasks with stable immutable IDs
  (`F-0001` / `T-0007`), priority, status, dependencies, effort, and notes.
- Workflow commands: `new`, `start`, `done`, `skip`, `defer`, `reopen`,
  `mv`, `link`, `set`, `next`, `tree`, `list`, `show`, `current`, `backlog`,
  `now`, `nextid`.
- Single active-task enforcement, checkbox↔status sync, and CI-friendly
  `validate` (non-zero exit on any schema violation).
- GitHub issue `sync` (`@issue` / `@pr` ↔ issue state).
- `version` and `selfupdate` — keep a vendored copy current from the canonical
  source (atomic in-place update; `--check` / `--source` supported). Hardened:
  HTTPS-only, non-default sources gated behind `--allow-untrusted-source`,
  fetched payload validated (compiles + looks like `tasks.py`) before replacing
  the script, symlink-safe write.
- `--prio` and `--priority` accepted interchangeably on `new`/`list`.
- PostToolUse `tasks-md-guard.sh` hook to nudge edits through the CLI.
- 155-scenario end-to-end test suite; CI across Python 3.8–3.12.
- Docs: install + task-lifecycle walkthrough, a populated `examples/TASKS.md`,
  and `CONTRIBUTING.md`. Consistent `./tools/tasks.py` invocation throughout.
