#!/usr/bin/env bash
# PostToolUse hook - detects manual edits to TASKS.md
# Reminds to use ./tools/tasks.py instead

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract tool name and file path from the input
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || echo "")
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' || echo "")

# Check if this is an Edit or Write to TASKS.md
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
    if [[ "$FILE_PATH" == *"TASKS.md" ]]; then
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "<tasks-md-warning>\n**WARNING: You manually edited TASKS.md!**\n\nTASKS.md should ONLY be modified via the `tasks` CLI (`./tools/tasks.py`).\n\n**Required workflow:**\n1. Check that `./tools/tasks.py` exists in the project.\n2. If stale or missing, sync it from canonical: `./tools/tasks.py selfupdate`\n3. Use CLI commands:\n   - `./tools/tasks.py new feature \"Title\" --prio P1`\n   - `./tools/tasks.py new task \"Title\" --under F-0001`\n   - `./tools/tasks.py start T-0001`\n   - `./tools/tasks.py done T-0001`\n   - `./tools/tasks.py validate`\n\n**Why?** The CLI ensures:\n- Proper ID generation (no duplicates)\n- Correct format and schema\n- Dependency tracking\n- Single WIP enforcement\n\nPlease revert your manual edit and use the CLI.\n</tasks-md-warning>"
  }
}
EOF
        exit 0
    fi
fi

# No TASKS.md edit detected - return empty context
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ""
  }
}
EOF
exit 0
