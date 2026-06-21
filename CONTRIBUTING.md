# Contributing

Thanks for your interest. `tasks` is intentionally small; a few rules keep it
that way.

## Hard constraints

1. **One file.** All engine code stays in `tasks.py` — vendorability depends on
   it being a single file. No packages.
2. **Zero third-party dependencies.** Standard library only.
3. **Python 3.8+.** CI runs the suite on 3.8–3.12; keep syntax/stdlib usage
   3.8-compatible.
4. **Portable tests.** CI runs on Linux. Avoid BSD-only shell (e.g. `sed -i ''`);
   prefer `awk` or `sed … > tmp && mv tmp file`.

## Workflow

```bash
make check     # py_compile + full e2e suite — run before every commit
make test      # e2e suite only
make smoke     # quick functional smoke test
```

- The `tests/test_tasks_e2e.sh` suite is the gate. **Any behavior change must
  keep it green; any new behavior needs a new scenario.**
- The `TASKS.md` schema is the module docstring in `tasks.py` (printed by
  `tasks help`). Update it there first; keep `schema.md` in sync.
- Don't weaken the `selfupdate` security invariants (HTTPS-only, trusted-source
  gating, payload validation, safe write) — see `CLAUDE.md`.

## Pull requests

- One concern per PR; clear, imperative commit messages.
- `make check` green, and the change documented in `CHANGELOG.md`.

## Releasing (maintainers)

Bump `__version__` + `CHANGELOG.md`, then `git tag -a vX.Y.Z -m "tasks vX.Y.Z"
&& git push origin vX.Y.Z`.

## Known cleanup

Some internal type annotations are loose (a strict type checker flags a few
`Optional` narrowing sites). Runtime behavior is covered by the e2e suite;
incremental tightening is welcome.
