# CLAUDE.md — tasks

Guidance for developing **this** repository (a single-file, zero-dependency
`TASKS.md` task tracker). Read `README.md` for user-facing usage; this file is
for contributors and AI sessions working on the tool itself.

**Read order for a fresh session:** `README.md` (what the tool does) → this file
(rules) → `MEMORY.md` (session-to-session state: what just happened, what's next)
→ `LEARNINGS.md` (why past decisions went the way they did). `MEMORY.md` ranks
*below* this file — if they disagree, this file wins and the loser gets fixed.

## What this is

`tasks.py` is a self-contained CLI that manages a plain-text `TASKS.md`
(hierarchy-aware features/tasks with IDs, priority, status, deps, effort,
notes). It is designed to be **vendored** into other projects as
`tools/tasks.py`, so the whole tool is one file and runs anywhere Python 3.8+
exists — no install, no PATH, no network.

## Hard constraints (do not break these)

1. **Single file.** All engine code lives in `tasks.py`. Don't split it into a
   package — vendorability depends on it being one file.
2. **Zero third-party dependencies.** Standard library only. `selfupdate` uses
   `urllib`; everything else is stdlib. Adding a dependency breaks the
   zero-install promise — don't.
3. **Python 3.8+.** CI runs the suite on 3.8–3.12; keep syntax/stdlib usage
   compatible with 3.8 (no `match`, no `X | Y` type unions at runtime, etc.).
4. **Schema lives in the docstring.** The `TASKS.md` format spec is the module
   docstring in `tasks.py` (printed by `tasks help`); `schema.md` is a derived
   quick-reference. Update the docstring first; keep `schema.md` in sync.

## Layout

| Path | What |
|---|---|
| `tasks.py` | The engine — commands, parser, validator, `version`/`selfupdate`. |
| `tests/test_tasks_e2e.sh` | The conformance gate (54 scenarios / 298 assertions as of v1.4.0 — `make test` prints the live count; don't trust doc numbers over the runner). |
| `hooks/tasks-md-guard.sh` | Optional PostToolUse hook nudging edits through the CLI. |
| `schema.md` | `TASKS.md` format quick-reference (full spec = the docstring). |
| `docs/superpowers/specs/` | Committed design docs (`YYYY-MM-DD-<topic>-design.md`) for larger features — the decisions *and their why*, written before implementation. ("superpowers" = the brainstorm/TDD workflow tooling used in AI sessions; the docs are plain markdown.) |
| `LEARNINGS.md` | Insight/decision ledger, newest first — read before repeating a class of change. |
| `MEMORY.md` | Maintainer session-to-session state (resume point, off-repo context, bootstrap). |
| `CHANGELOG.md` | Per-release record (entries are history — don't rewrite old ones). |
| `Makefile` · `.github/workflows/ci.yml` | Dev runner + CI (Python matrix). |

## Development workflow

```bash
make help      # list targets
make check     # py_compile + full e2e suite — THE gate before any commit
make test      # e2e suite only
make smoke     # quick functional smoke (init/new/start/done/validate)
```

- **The e2e suite is the safety net.** It's a behavioral suite, not unit tests.
  Any behavior change must keep it green; any new behavior needs a new scenario.
- **Tests must be portable.** CI runs on Linux. Avoid BSD-only shell (e.g.
  `sed -i ''` — GNU sed parses it differently); prefer `awk` or
  `sed ... > tmp && mv tmp file`.
- Run `make check` before committing; don't push red.

## selfupdate — security invariants (don't regress)

`selfupdate` overwrites the running script with content fetched from a URL, so
it is deliberately conservative. Preserve all of these:
- **HTTPS only** — reject `http://` and https→http redirect downgrades.
- **Trusted default** — only `DEFAULT_CANONICAL_SOURCE` updates without a flag;
  any other `--source` / `TASKS_CANONICAL_SOURCE` requires
  `--allow-untrusted-source` (prevents silent env-var hijack).
- **Validated payload** — fetched content must `compile()` and look like
  `tasks.py` before it replaces the script.
- **Safe write** — `realpath` + `O_EXCL` temp + atomic `os.replace` + cleanup.

## Releasing

1. Bump `__version__` in `tasks.py` and add a `CHANGELOG.md` entry.
2. `make check` (green), commit.
3. Tag and push: `git tag -a vX.Y.Z -m "tasks vX.Y.Z" && git push origin vX.Y.Z`
   (a tag push is the release; optionally `gh release create`).

Vendored copies on older versions pick up the new release via
`tasks selfupdate` (which fetches `tasks.py` from `main`'s raw URL). Keep the
`__version__` bump and the released tag consistent.

## Conventions

- `anyhow`-style: errors are surfaced via `raise SystemExit("clear message")`;
  no silent failures.
- Commands are dispatched from `main()` (an `if/elif` chain on `argv[1]`); add a
  command by writing `cmd_<name>` and a branch, and document it in the docstring
  command list.
- Commit messages: clear and imperative; one concern per commit. No
  "Generated with" / "Co-Authored-By" trailers.
- All changes land via feature branch → PR → CI green → squash-merge; never
  commit to `main` directly.
- Number references: in `CHANGELOG.md`, `LEARNINGS.md`, and spec prose, `#N`
  cites a **GitHub issue**; the `(#N)` suffix on a squash-merge commit subject
  is the **PR** number. They are different sequences on the same tracker.
- New behavior is developed test-first: add the e2e scenario, watch it fail for
  the right reason, then implement. Larger features get a design doc in
  `docs/superpowers/specs/` committed with the same PR.

## Roadmap / known items

- **The living roadmap is the GitHub issue tracker** (budhash/tasks). Triage
  comments on the issues carry the agreed scope; the current queue order and
  resume point are pinned in `MEMORY.md` (updated with each release).
- **Type hints.** Some internal annotations are loose (a strict checker flags a
  few `Optional` narrowing sites — known and accepted). Runtime behavior is
  covered by the e2e suite; tightening these is a welcome incremental cleanup.
- Longer-horizon ideas (no issue yet): a bridge to editor/agent task tooling,
  schema versioning + migration, and a multi-project rollup view.
