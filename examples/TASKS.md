# TASKS.md

Single source of truth for features + tasks in this repo.

Use `./tools/tasks.py help` for CLI commands.

---

# Meta

## Info

This file is managed by `./tools/tasks.py` CLI tool.

- Run `./tools/tasks.py help` for full documentation
- Manual edits may break parsing - use CLI commands instead
- Task IDs (F-####, T-####) are auto-generated and must be unique
- Checkbox state must match status: `[x]` for done, `[ ]` otherwise

## Schema

Format: `- [ ] (ID) [PRIO] [STATUS] Title @tags...`

Example:
```
- [ ] (F-0001) [P0] [todo] Feature title @issue=42 @tags=security,mvp
  - [ ] (T-0001) [P0] [todo] Subtask @deps=T-0002 @effort=4h
  - [x] (T-0002) [P0] [done] Another subtask @done=2025-01-01
```

Tags: `@deps=` `@rel=` `@branch=` `@pr=` `@issue=` `@tags=` `@effort=` `@system=` `@done=`

---

# Tasks

## Now

- [ ] (F-0001) [P0] [todo] Auth MVP
  - [x] (T-0001) [P0] [done] Define User schema @effort=2h @done=2026-06-21
  - [ ] (T-0002) [P1] [doing] Token validation @effort=4h @deps=T-0001
  - [ ] (T-0003) [P1] [todo] Login endpoint @deps=T-0002
## Backlog

- [ ] (F-0002) [P2] [todo] Notifications
  - [ ] (T-0004) [P2] [todo] Email provider spike @tags=research
## Skipped

---

# Notes

Use `## <ID>` headers (e.g., `## F-0001`) for structured notes per task.
Use `./tools/tasks.py show <id> --full` to display notes with task details.

- 2026-06-21: Initialized TASKS.md
