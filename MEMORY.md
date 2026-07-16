# MEMORY.md — successor briefing

> **Rank:** this file ranks BELOW `CLAUDE.md`. If they disagree, `CLAUDE.md` wins —
> then fix the loser. It carries only what the code and the other docs can't say:
> what just happened, off-repo context, and the pinned resume point.
> **Maintenance:** update "Now / next" and "What just happened" in the same PR as any
> release or roadmap-changing merge; delete lines that stop being true.

## Now / next (the resume point)

- **Nothing is in flight.** `main` is the complete, released state (v1.4.0,
  2026-07-15). No open PRs; the only branch is `main`.
- **Next up, if told "continue where we left off": issue #14 — `validate --refs`**,
  a reference-integrity check. Agreed shape (triage comment on the issue): v1 detects
  *dangling* refs only (`@deps=`/`@rel=`/`## <ID>` notes header pointing at an ID
  that no longer exists), opt-in flag, read-only report — the same
  "detect, don't rewrite" template as `renumber --refs`. `_report_external_refs()`
  in `tasks.py` is already half the engine; short-form IDs (`T-12` ≡ `T-0012`) must
  be handled (see the v1.3.0 LEARNINGS entry). Fold #25 (validate silently ignores
  unknown args) into the same round — that bug becomes dangerous the moment
  `validate` grows its first flag.
- Queue after #14 (recommended order, from the issue-triage comments): #16 (CLI verb
  for the `# Milestones` registry), #11's remaining half (`note ID` verb — retitle
  shipped in v1.2.0), #6 (refuse mutating commands on main), #5 (docs: CLI-only vs
  manual edits), #15 (merge-driver discussion — deliberately sequenced last).
- Open but unsequenced June backlog — priority is the **user's** call, don't
  self-assign: #2 (`rm` verb), #3 (`--tags-add`/`--tags-rm`), #4 (validate
  `@pr`/`@branch` freshness). #13's `reserve N` stays deferred unless a real gap is
  observed (recorded on the issue).

## What just happened (2026-06-21 → 2026-07-15)

Six releases, each driven by real usage in consumer repos; every design decision and
its *why* is in `LEARNINGS.md` and `docs/superpowers/specs/`:
v1.1.0 milestones → v1.1.1 trailing-tag-region parsing (#9) → v1.1.2 shadow-sync
field edits (#17) → v1.2.0 `set --title` (#18) → v1.3.0 `renumber` (#12) →
v1.4.0 `new --id`/`--base` (#13). The through-line: a three-way ID collision
(`T-2006`, three parallel branches) in a consumer repo produced the
fix/prevent/detect triad — #12 shipped (fix), #13 shipped (prevent), #14 open
(detect).

## Off-repo context a fresh machine won't have

- **Consumers:** the tool is vendored as `tools/tasks.py` into private sibling
  projects (`taxjot`, `byteorb`, `stead` — checkouts lived next to this repo on the
  old machine; they are NOT required for developing this repo). The milestone
  feature's spec originated in taxjot; the ID-collision incident happened in byteorb.
  Consumers pick up releases via `./tools/tasks.py selfupdate`.
- **Standing user rule (upstream/mirror):** when a tasks bug or need surfaces while
  working in a consumer repo — file the GitHub issue upstream here FIRST, then mirror
  it as one P2 task in that consumer's `TASKS.md` referencing the issue URL. Defer
  adding mirror tasks while other `TASKS.md` PRs are in flight (ID churn); prefer one
  umbrella task over many mirrors.
- **Pending deferred action from that rule:** byteorb still needs an umbrella P2 task
  "track budhash/tasks #12–#15" on its next `TASKS.md`-touching PR (was deferred
  behind byteorb's #291).
- **The issue tracker is the roadmap** (GitHub, budhash/tasks); triage comments on
  #11–#16 carry the agreed scopes. A new machine needs `gh auth login` for that work.

## New-machine bootstrap

```bash
git clone https://github.com/budhash/tasks.git && cd tasks
make check          # py_compile + full e2e suite; must be green before anything else
gh auth login       # only needed for issue/PR/release work
```

Requirements: python3 ≥ 3.8, bash, git; `gh` for GitHub work. No install, no deps.
A root `TASKS.md` here is gitignored dev scratch (the tool's own playground), not
project state.

## Process facts that bit us before (details in LEARNINGS.md)

- Release = bump `__version__` + `CHANGELOG.md` entry + `make check` green →
  squash-merge → `git tag -a vX.Y.Z && git push origin vX.Y.Z` (the tag push IS the
  release) → `gh release create vX.Y.Z`.
- TDD is the norm: failing e2e scenario first, watched failing *for the right
  reason*; design docs to `docs/superpowers/specs/` in the same PR.
- Real-world verification: before releasing format-adjacent changes, run the
  read-only commands against a copy of a real consumer `TASKS.md` (byte-for-byte
  round-trip, cf. e2e scenario 31).
- Known accepted Pyright loose-typing diagnostics in `tasks.py` (see CLAUDE.md
  roadmap) — don't chase them casually.
