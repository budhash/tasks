# LEARNINGS

Insights, gotchas, and decisions worth remembering — newest first. For *what*
changed see `CHANGELOG.md`; this file records *why* and what it taught us.

## 2026-07-13 — v1.1.2 / v1.2.0 (shadow-sync fix, `set --title`)

- **"First match in file order" is a bug class, not a bug.** `set_tag`,
  `edit_links`, and `cmd_update` all independently edited the first line
  carrying an ID — and a `@shadow` copy can precede the primary (shadow in
  `## Now`, primary in `## Backlog`). One report (#17, `set --milestone`)
  turned out to cover *every* field-edit verb, including `done F-N` marking the
  shadow done. When a duplicate-carrying representation exists (shadows), any
  "find the item" helper must define which copy it means. Decision:
  `find_all_item_lines()` — edits apply to primary **and** shadows, matching
  how shadows are created (copied from the primary, tags included).
- **The init template pollutes naive test greps.** The `# Meta` schema example
  contains a literal `(F-0001) [P0]` line inside a code fence. The CLI ignores
  it (`iter_content_lines` skips fences and non-Tasks sections) but a bare
  `grep "(F-0001)" TASKS.md` in a test does not — it produced a false PASS in
  scenario 49's first draft. Anchor test greps on the item *title*, or go
  through the CLI (`show`) instead of grepping the file.
- **The trailing-tag-region model keeps paying off.** `split_item_tags()`
  (added for #9) made `set --title` nearly free: title and tags are separate
  fields, so retitling preserves tags by construction. New edge it surfaced: a
  title *ending* in a tag-shaped token would merge into the tag region on
  re-parse — reject at input time rather than surprise at read time.

## 2026-07-01 — v1.1.0 / v1.1.1 (milestones, tag-region parsing)

- **Whole-line regex scans read prose as data.** Tags extracted via
  `re.search` over the full item line meant a task *titled* after the
  `@tags=… → @milestone=…` migration was parsed as being *in* milestone `foo`
  (#9): phantom rollup buckets, and `migrate-tags-to-milestone` skipping the
  very task that tracked the migration. Machine data in a mixed prose/data
  line needs a positional anchor (the trailing `@…` token run), not a
  substring match. The write path (`re.sub` stripping look-alikes out of
  titles) had the same flaw.
- **Sentinel values must be excluded from the real value space.** The implicit
  `default` milestone bucket is configurable; a sentinel matching the `M<n>`
  ID pattern would make `set --milestone m1` ambiguous between "assign" and
  "clear". Reject such sentinels at startup rather than documenting around it.
- **Backward compatibility is testable as bytes.** The strongest compat test
  in the suite: run every read-only command against a file with no milestone
  data and `cksum` it before/after. Byte-for-byte equality is a stricter and
  simpler invariant than any behavioral assertion.
- **Migration helpers must not destroy what they migrate.** The first
  `migrate-tags-to-milestone` stripped the interim tag *before* checking for a
  conflicting existing `@milestone=` — silently deleting the association it
  existed to preserve, while reporting success. Order of operations in
  rewrite-helpers: check conflicts first, mutate second, and never count a
  skipped item as migrated.
- **Adversarial review of "done" work pays.** A four-lens review pass
  (correctness, tests, comments, silent failures) on the merged-green
  milestone PR found one real data-loss bug and a case-sensitivity
  inconsistency before any user hit them.

## 2026-06-21 — v1.0.x (foundations)

- **One file, zero deps is a feature, not a style.** Vendorability
  (`tools/tasks.py`, `selfupdate`) depends on it; every enhancement must fit
  inside that constraint (stdlib only, 3.8+ syntax).
- **`selfupdate` is a self-overwrite and is treated as hostile input:**
  HTTPS-only, non-default sources gated behind an explicit flag, payload must
  compile and look like `tasks.py`, atomic `O_EXCL` + `os.replace` write.
