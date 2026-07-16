# LEARNINGS

Insights, gotchas, and decisions worth remembering — newest first. For *what*
changed see `CHANGELOG.md`; this file records *why* and what it taught us.

## 2026-07-16 — v1.4.1 (migration readiness: blind-dogfood audits)

- **Blind readers find what self-review can't.** Preparing a machine move, we ran
  three rounds of "fresh agent, cold clone, zero context, answer a resume
  questionnaire from the repo alone". Round 1: stale claims ("155 scenarios"),
  lagging layout tables/roadmap, and no in-repo resume point. Round 2: an
  overclaiming doc sentence, a flagship example file that predated the flagship
  feature, and a real bug (#25: `validate` swallows unknown argv). Round 3: only
  minor phrasing — converged. Each reader must be blind to the previous reports,
  or later rounds just re-confirm earlier ones.
- **The highest-value probe is "continue where we left off".** It cleanly
  separates "nothing is unmerged" (derivable from git) from "what would you do
  next" (not derivable unless written down). `MEMORY.md` now pins the resume
  point and is maintained in the same PR as any release or roadmap change.
- **Hardcoded counts in prose always rot.** Pin them to a version ("as of
  v1.4.0") and point at the runner for the live number. And when a frozen
  history entry (CHANGELOG) is misleading, append a dated editor's note — never
  rewrite the entry.
- **Example files are docs and rot like docs.** `examples/TASKS.md` was billed
  as "fully populated" but had no milestone content two releases after
  milestones shipped. When a feature ships, grep the examples too.

## 2026-07-15 — v1.4.0 (collision-resistant allocation)

- **Fail closed when the flag *is* the safety.** `new --base <ref>` exists to
  prevent cross-branch ID collisions; if git fails, falling back to local-only
  allocation would silently reintroduce exactly what the user opted into
  preventing — so it errors instead. Contrast with `renumber --refs`, which
  degrades gracefully outside a repo: that one is a best-effort *report*, not a
  correctness guarantee. The rule: graceful degradation is for observability
  features, hard failure is for safety features.
- **A `--force` sketched in triage isn't a commitment.** The #13 triage note
  said "refuse if taken unless `--force`", but forcing a duplicate ID is file
  corruption in every case — there is no valid use. Dropped it and recorded
  the deviation in the design doc rather than shipping a footgun for symmetry.
- **Test needles must not look like flags.** `assert_contains … "--base"` broke
  because the harness greps for the needle and grep ate it as an option.
  Assert on message *words* ("cannot read"), not flag-shaped substrings — or
  the assertion tests grep's argv parsing instead of the CLI.

## 2026-07-13 — v1.3.0 (`renumber`)

- **Mutate structure, report prose.** The renumber design's key call (made
  explicitly with the user): the tool rewrites only *structured* references it
  can identify positionally (`@deps`/`@rel` tag regions, the `## <ID>` notes
  header, shadow lines) and merely *reports* free-text mentions (`--refs`,
  read-only, repo-wide). Auto-rewriting prose is the #9 false-positive class
  in write form; leaving it to the operator keeps the tool trustworthy. This
  "detect, don't rewrite" split is the template for #14 (`validate --refs`).
- **Design decisions made in chat evaporate; specs in-repo don't.** The
  renumber design sat approved-but-unwritten for ten days across sessions.
  Committing `docs/superpowers/specs/…-renumber-design.md` with the PR means
  the *why* (no `--force`, refuse-occupied, `--next`) survives the
  conversation that produced it.
- **Short-form IDs are part of the reference surface.** Hand-written
  `@deps=T-12` and prose `T-12` both mean `T-0012`. The repoint path gets this
  free (parse_id_list normalizes), but the `--refs` scanner needed an explicit
  `\bT-0*12\b` pattern — matching short forms without swallowing `T-00123`.
  Any future reference-scanning feature (#14) must handle both forms too.

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
