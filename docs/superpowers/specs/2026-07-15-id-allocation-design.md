# Design: collision-resistant ID allocation on `new` (issue #13)

**Status:** approved (triage recommendation on #13, confirmed 2026-07-15)
**Motivation:** the byteorb three-way `T-2006` collision — parallel branches each
ran `new`, each allocated the same next ID from their local `TASKS.md`, and the
merge produced duplicates. `renumber` (#12, v1.3.0) is the cleanup; this is the
prevention.

## Scope (per triage, split by cost)

1. **`new … --id <ID>`** — create with an explicit ID instead of auto-allocating.
   Trivial, high-value: colliding branches can take disjoint ranges up front.
2. **`new … --base <git-ref>`** — auto-allocate the next ID considering *both*
   the local file and `TASKS.md` at a git ref (`max(local, base) + 1`). Covers
   the fork-from-`main` case that caused the incident without any manual range
   planning.
3. **`reserve N`** — **deferred.** Needs persisted reservation state, which
   introduces a new concept into the `TASKS.md` format. Not in this round.

## Command surface

```
tasks new task    "Title" --id T-42            # explicit ID (short forms fine)
tasks new feature "Title" --base origin/main   # next = max(local, ref) + 1
tasks new task    "Title" --id T-42 --base origin/main   # also verify vs ref
```

## Decisions

- **No `--force` on a taken `--id`.** The triage sketch mentioned one, but a
  forced duplicate ID is file corruption, never a feature. Refuse with a clear
  message (same principle as renumber's refuse-if-taken). Deviation recorded
  here deliberately.
- **`--base` fails closed.** If git is unavailable, the ref doesn't resolve, or
  `TASKS.md` doesn't exist at the ref, `new` errors out — it does **not**
  silently fall back to local-only allocation. A silent fallback would quietly
  reintroduce the exact collision this flag exists to prevent (see the
  migrate-helper learning: never report safety you didn't provide). Contrast
  with `renumber --refs`, which *degrades* gracefully — that one is a
  best-effort report, not a correctness guarantee.
- **`--id` + `--base` compose.** With both, the explicit ID must be free in the
  base ref too — checking only locally would miss the incident case.
- **Kind must match.** `new task --id F-7` is refused (same rule as renumber).
- **Format unchanged.** This is CLI allocation behavior only; `schema.md` and
  the file format are untouched. Fully backward compatible: both flags are
  opt-in, `new` without them behaves exactly as before.

## Behavior details

- Explicit `--id` is normalized like every other ID input (`T-7` → `T-0007`).
- "Taken" means any item line carrying the ID (primary or `@shadow`), via the
  same lookup the rest of the tool uses (`find_all_item_lines`).
- `--base` resolves the tasks file's repo-relative path
  (`git rev-parse --show-toplevel` + relpath) and reads
  `git show <ref>:<relpath>`; the fetched content is scanned with the same
  fence-skipping iteration as the local file (the `# Meta` template example
  contains a literal `(F-0001)` inside a code fence — a naive scan would
  count it).
- Errors (all `SystemExit`, clear message): ID taken locally ("pick a free id
  or omit --id"), ID taken at ref, kind mismatch, invalid ID, not a git repo,
  unreadable `<ref>:TASKS.md`, tasks file outside the repo.

## Non-goals (v1)

`reserve` / persisted ranges; scanning *all* branches for a global max
(heavier, more edge cases — an explicit single `--base` covers the incident
pattern); applying `--base` to `renumber --next` (can follow if wanted).

## Testing

New e2e scenarios: `--id` create + normalization + guards (taken, cross-kind,
invalid); `--base` allocation picks up a higher max from the ref (committed
file ahead of working tree), fail-closed on missing ref / outside a repo /
file absent at ref; `--id --base` refuses an ID taken only in the ref;
plain `new` unchanged.
