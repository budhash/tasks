# Design: `renumber` verb (issue #12)

**Status:** approved (interactive brainstorm, 2026-07-03; scope re-confirmed 2026-07-13)
**Motivation:** the byteorb three-way `T-2006` collision — with no `renumber`,
resolving an ID collision meant hand-editing `TASKS.md` (the documented
anti-pattern, see #5) and manually repointing every reference.

## Decisions (made with the user)

1. **Scope:** renumber only, this round. Allocation (#13), ref-integrity (#14),
   and the merge driver (#15) are separate rounds.
2. **External references:** `renumber` never rewrites anything outside
   `TASKS.md`. An optional `--refs` flag *detects and reports* remaining
   mentions in tracked files, read-only — fixing them is the operator's/agent's
   job. (Auto-rewriting prose is the #9 false-positive class; explicitly out.)
3. **Kinds:** both `T-` and `F-`. Features also rename every `@shadow` copy.
   Same-kind only (`T-→T-`, `F-→F-`).
4. **Target availability:** refuse if the target ID exists (clear error, no
   `--force`); `renumber OLD --next` moves to the next free ID of the same
   kind. Safest, fully backward-compatible (new verb, no existing behavior
   changes).

## Command surface

```
tasks renumber OLD NEW [--refs]      # rename OLD → explicit NEW
tasks renumber OLD --next [--refs]   # rename OLD → next free ID (same kind)
```

Short ID forms accepted (`T-7`, `F-1`), normalized as everywhere else.

## Behavior (inside TASKS.md — always)

- Rename the `(OLD)` token on the item's primary line **and** every `@shadow`
  copy (features).
- Repoint every other item's `@deps=` / `@rel=` list containing `OLD` → `NEW`.
  Lists are read/written through the anchored tag-region helpers, so a prose
  mention of the ID in a *title* is untouched (consistent with #9/1.1.1).
  Short-form hand-written deps (`@deps=T-12`) are normalized on rewrite.
- Rename the `## OLD` header in `# Notes` → `## NEW` (body text untouched).
- Print a summary: primary/shadow line count, `@deps`/`@rel` repoint counts,
  notes-header rename.

## `--refs` (opt-in, read-only)

After the rename, scan git-tracked files (`git ls-files`) in Python for
remaining `\b<KIND>-0*<n>\b` mentions (catches short forms like `T-12` for
`T-0012` without matching `T-00123`), and print `file:line: excerpt`. Never
modifies any file. Outside a git repo (or git unavailable): print a one-line
"skipped" note. Mentions remaining inside `TASKS.md` itself (prose titles,
notes bodies) are reported the same way.

## Guards (hard refusal, `SystemExit` with a clear message)

- `OLD` not found.
- `NEW` already exists → suggests `--next`.
- Cross-kind (`T-` → `F-` or vice versa).
- `OLD == NEW`.
- Both `NEW` and `--next` given, or neither.

## Non-goals (v1)

External rewrites; `--id`/`reserve` allocation (#13); repurposed-ID detection
(#14); merge driver (#15); `--force` in any form.

## Testing

New e2e scenarios: task rename + `@deps`/`@rel` repoint + notes header +
`show`/`validate`; guards (taken, cross-kind, missing, same-id); `--next`;
feature rename incl. `@shadow` sync; `--refs` reporting (git repo case: file
listed, file *not* modified) and the not-a-repo skip.
