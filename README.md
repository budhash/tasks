# tasks

[![CI](https://github.com/budhash/tasks/actions/workflows/ci.yml/badge.svg)](https://github.com/budhash/tasks/actions/workflows/ci.yml)
![Python](https://img.shields.io/badge/python-3.8%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A one-file, zero-dependency, hierarchy-aware task tracker for a plain-text
`TASKS.md`. Python 3.8+, standard library only.

Your backlog lives **in the repo**, as a human-readable, diff-friendly markdown
file, managed by a CLI that enforces structure (stable IDs, one active task,
dependency tracking, CI-checkable validation). No database, no service, no
account.

**Why not just…?**
- *a hand-written `TODO.md`* — no IDs, no validation, no dependency/▶-in-progress
  discipline; it rots. `tasks` keeps it structured and CI-checkable.
- *GitHub Issues / Jira* — great for public/team tracking, but they live outside
  your repo and need the network. `tasks` is local, offline, and versioned with
  your code.

## Install

`tasks` is a single file — vendor it into your project so the repo is
self-contained:

```bash
mkdir -p tools
curl -fsSL https://raw.githubusercontent.com/budhash/tasks/main/tasks.py -o tools/tasks.py
chmod +x tools/tasks.py
./tools/tasks.py init        # create a starter TASKS.md
```

That's it — no `pip install`, no dependencies. Commit `tools/tasks.py` **and**
your `TASKS.md` to your repo. Keep it current later with `./tools/tasks.py
selfupdate` (see below).

> Just trying it from a clone of this repo? The script is at the root here, so
> run `./tasks.py …` instead of `./tools/tasks.py …`.

## Task lifecycle

A typical flow, from empty repo to a tracked, validated backlog:

```bash
# 1. Start a backlog
./tools/tasks.py init

# 2. Add a feature and break it into tasks (IDs are auto-assigned)
./tools/tasks.py new feature "Auth MVP" --prio P0 --section Now
./tools/tasks.py new task "Define User schema" --under F-0001 --prio P0 --effort 2h
./tools/tasks.py new task "Token validation"  --under F-0001 --prio P1 --effort 4h --deps T-0001
./tools/tasks.py new task "Login endpoint"    --under F-0001 --prio P1 --deps T-0002

# 3. Work it — one active task at a time is enforced
./tools/tasks.py start T-0001     # marks T-0001 ▶ doing
./tools/tasks.py done  T-0001     # ✓ done; auto-stamps @done=YYYY-MM-DD
./tools/tasks.py start T-0002

# 4. See where things stand
./tools/tasks.py tree
```

```
• F-0001 P0 todo — Auth MVP
  ✓ T-0001 P0 done — Define User schema @effort=2h @done=2026-06-21
  ▶ T-0002 P1 doing — Token validation @effort=4h @deps=T-0001
  • T-0003 P1 todo — Login endpoint @deps=T-0002
• F-0002 P2 todo — Notifications
```

```bash
# 5. What should I pick up next? (highest-priority, unblocked, in Now)
./tools/tasks.py next

# 6. Park or defer work
./tools/tasks.py skip  T-0003     # moves it to ## Skipped
./tools/tasks.py defer T-0003     # sets status 'deferred' (stays in place)
./tools/tasks.py reopen T-0003    # back to 'todo'

# 7. Gate it in CI — non-zero exit if TASKS.md is malformed
./tools/tasks.py validate
```

See a fully-populated example in [`examples/TASKS.md`](examples/TASKS.md).

## Commands

`./tools/tasks.py help` prints the full reference and the `TASKS.md` schema.
Highlights:

| Command | What |
|---|---|
| `init` | Create a starter `TASKS.md` |
| `new feature\|task "Title" [...]` | Create an item (`--prio`/`--priority`, `--under ID`, `--section`, `--effort`, `--tags`, `--deps`, `--status`) |
| `start \| done \| skip \| defer \| reopen ID` | Status transitions (`start` enforces a single active task) |
| `tree` / `list [filters]` / `show ID [--full]` | Views |
| `next` | Next actionable task (highest prio, unblocked, in `Now`) |
| `mv` / `set` / `link` | Move sections, set fields, edit deps/relations |
| `sync ID` | Reconcile a task with its linked GitHub issue (`@issue=`; needs the `gh` CLI) |
| `validate` | Check the file (CI-friendly, non-zero on failure) |
| `version` / `selfupdate` | Show version / sync to canonical |

> `--prio` and `--priority` are accepted interchangeably.

## Concepts worth knowing

- **Sections vs status.** Items live in `## Now`, `## Backlog`, or `## Skipped`;
  each item also has a status (`todo/doing/done/skipped/deferred`). `skip` both
  sets status *and* moves the item to `## Skipped`; `defer` only sets the status
  and leaves the item where it is.
- **Shadow features.** When you skip/scatter a task whose feature lives in
  another section, `tasks` leaves a lightweight duplicate of the parent feature
  line tagged `@shadow` so the hierarchy stays readable across sections. They're
  managed automatically (and cleaned up); don't hand-edit them.
- **Commit your `TASKS.md`.** It's meant to be versioned with your code.
  (This repo's `.gitignore` ignores a root `TASKS.md` only because it's the
  tool's own test scratch — that does not apply to your project.)

## selfupdate

```bash
./tools/tasks.py selfupdate            # sync this copy to canonical
./tools/tasks.py selfupdate --check    # report only, don't write
./tools/tasks.py selfupdate --source <path-or-url> --allow-untrusted-source
```

`selfupdate` compares the copy's `__version__` to the canonical source and, only
if canonical is newer, atomically replaces the file in place. Because it
overwrites the running script, it is deliberately conservative:

- **HTTPS only** — plaintext `http://` (and https→http redirects) are refused.
- **Trusted default** — the canonical source is the compiled-in default URL. A
  non-default source (via `--source` or `TASKS_CANONICAL_SOURCE`) requires
  `--allow-untrusted-source`, so a stray env var can't silently swap the tool.
- **Validated payload** — the fetched content must parse as Python and look like
  `tasks.py` before it replaces the script.

## CI usage

`validate` is the gate. Drop this into a workflow to keep `TASKS.md` well-formed:

```yaml
- uses: actions/checkout@v4
- run: ./tools/tasks.py validate
```

## Layout

| Path | What |
|---|---|
| `tasks.py` | The engine — task commands, `validate`, `version`, `selfupdate`. |
| `examples/TASKS.md` | A populated sample file. |
| `hooks/tasks-md-guard.sh` | Optional PostToolUse hook nudging edits through the CLI. |
| `tests/test_tasks_e2e.sh` | Conformance suite (155 scenarios). |
| `schema.md` | `TASKS.md` format quick-reference (full spec in `tasks.py help`). |
| `CHANGELOG.md` · `CONTRIBUTING.md` · `CLAUDE.md` | History · contributing · dev guide. |

## Develop

```bash
make help      # list targets
make check     # syntax check + full e2e suite (the gate)
```

CI runs the suite across Python 3.8–3.12 on every push and PR. Zero
dependencies — standard library only, one file. See `CONTRIBUTING.md`.
