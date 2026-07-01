#!/usr/bin/env bash
# End-to-end test suite for tasks.
# Simulates real workflows: shadow features, section moves, merged views,
# status transitions, dependency tracking, and error handling.
#
# Usage: bash tests/test_tasks_e2e.sh   (or: make test)
#        Run from the project root directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# Canonical repo keeps tasks.py at the root; vendored projects use tools/tasks.py.
if [ -f "${PROJECT_ROOT}/tasks.py" ]; then
    TASKS_PY="${PROJECT_ROOT}/tasks.py"
else
    TASKS_PY="${PROJECT_ROOT}/tools/tasks.py"
fi

if [ ! -f "$TASKS_PY" ]; then
    echo "ERROR: tasks.py not found at $TASKS_PY"
    echo "Run this script from the project root."
    exit 1
fi

PASS=0
FAIL=0
ERRORS=""

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

assert_contains() {
    local label="$1" output="$2" expected="$3"
    if echo "$output" | grep -qF "$expected"; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC}: $label"
    else
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  FAIL: $label\n    Expected to contain: $expected\n    Got: $(echo "$output" | head -5)"
        echo -e "  ${RED}FAIL${NC}: $label"
        echo "    Expected to contain: $expected"
    fi
}

assert_not_contains() {
    local label="$1" output="$2" unexpected="$3"
    if echo "$output" | grep -qF "$unexpected"; then
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}\n  FAIL: $label\n    Should NOT contain: $unexpected"
        echo -e "  ${RED}FAIL${NC}: $label"
        echo "    Should NOT contain: $unexpected"
    else
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}PASS${NC}: $label"
    fi
}

TEST_DIR=""

fresh_init() {
    cd "$TEST_DIR"
    rm -f TASKS.md TASKS.md.backup
    python3 "$TASKS_PY" init 2>&1
}

setup_test_dir() {
    TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tasks_test.XXXXXX")
    cd "$TEST_DIR"
}

cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

run() {
    python3 "$TASKS_PY" "$@" 2>&1
}

trap cleanup EXIT

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 1: Basic PM Workflow (init, create, start, done) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

out=$(run new feature "User Authentication" --prio P1 --section Now)
assert_contains "Create feature" "$out" "Created F-0001"

out=$(run new task "Define auth interface" --prio P0 --under F-0001 --effort 2h)
assert_contains "Create task with --effort" "$out" "Created T-0001"

out=$(run new task "Implement login" --prio P1 --under F-0001 --effort 4h --deps T-0001)
assert_contains "Create task with --deps" "$out" "Created T-0002"

out=$(run new task "Add tests" --prio P1 --under F-0001 --tags testing,auth --deps T-0002)
assert_contains "Create task with --tags" "$out" "Created T-0003"

# Verify inline tags were written
out=$(run show T-0001)
assert_contains "T-0001 has @effort" "$out" "Effort: 2h"

out=$(run show T-0002)
assert_contains "T-0002 has @deps" "$out" "Depends on: T-0001"
assert_contains "T-0002 has @effort" "$out" "Effort: 4h"

out=$(run show T-0003)
assert_contains "T-0003 has @tags" "$out" "Tags: testing,auth"

# Start and complete workflow
out=$(run start T-0001)
assert_contains "Start T-0001" "$out" "Updated T-0001"

out=$(run current)
assert_contains "Current shows T-0001" "$out" "T-0001"

out=$(run done T-0001)
assert_contains "Done T-0001" "$out" "Updated T-0001"

out=$(run next)
assert_contains "Next is T-0002" "$out" "T-0002"

out=$(run start T-0002)
assert_contains "Start T-0002" "$out" "Updated T-0002"

out=$(run done T-0002)
assert_contains "Done T-0002" "$out" "Updated T-0002"

out=$(run validate)
assert_contains "Validate passes" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 2: Skip creates shadow, tree shows merged view ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Auth System" --prio P1 --section Now > /dev/null
run new task "Login endpoint" --prio P0 --under F-0001 > /dev/null
run new task "Session tokens" --prio P1 --under F-0001 > /dev/null
run new task "OAuth2 support" --prio P2 --under F-0001 > /dev/null
run new task "Legacy LDAP" --prio P3 --under F-0001 > /dev/null

out=$(run skip T-0004)
assert_contains "Skip moves to Skipped" "$out" "Moved T-0004 to section 'Skipped'"

# Tree should show merged view with section labels
out=$(run tree)
assert_contains "Tree shows [Now] label" "$out" "[Now]"
assert_contains "Tree shows [Skipped] label" "$out" "[Skipped]"
assert_contains "Tree shows T-0004 under Skipped" "$out" "T-0004"
assert_contains "Tree shows T-0001 (remaining in Now)" "$out" "T-0001"

# Verify show also has merged view
out=$(run show F-0001)
assert_contains "Show F-0001 has [Now] section" "$out" "[Now]"
assert_contains "Show F-0001 has [Skipped] section" "$out" "[Skipped]"

# TASKS.md should have @shadow in Skipped
out=$(cat TASKS.md)
assert_contains "Shadow created in Skipped" "$out" "@shadow"

out=$(run validate)
assert_contains "Validate passes with shadows" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 3: Start moves task to Now (cross-section) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Backend API" --prio P1 --section Backlog > /dev/null
run new task "Design API" --prio P0 --under F-0001 > /dev/null
run new task "Implement routes" --prio P1 --under F-0001 > /dev/null

out=$(run list --section Backlog)
assert_contains "T-0001 initially in Backlog" "$out" "T-0001"

out=$(run start T-0001)
assert_contains "Start T-0001 (cross-section)" "$out" "Moved T-0001"

out=$(run tree)
assert_contains "Tree has [Backlog] for remaining tasks" "$out" "[Backlog]"
assert_contains "Tree has [Now] for started task" "$out" "[Now]"

out=$(run list --section Now)
assert_contains "T-0001 moved to Now" "$out" "T-0001"

out=$(run list --section Backlog)
assert_contains "T-0002 still in Backlog" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 4: Defer is status-only, no section move ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Notifications" --prio P1 --section Now > /dev/null
run new task "Email integration" --prio P0 --under F-0001 > /dev/null
run new task "SMS integration" --prio P2 --under F-0001 > /dev/null

out=$(run defer T-0002)
assert_contains "Defer T-0002" "$out" "Updated T-0002"

out=$(cat TASKS.md)
assert_not_contains "Defer does NOT create shadow" "$out" "@shadow"

out=$(run show T-0002)
assert_contains "Deferred task still in Now" "$out" "Section: Now"
assert_contains "Status is deferred" "$out" "deferred"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 5: Reopen resets terminal status ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Search" --prio P1 --section Now > /dev/null
run new task "Full text search" --prio P0 --under F-0001 > /dev/null
run new task "Fuzzy matching" --prio P1 --under F-0001 > /dev/null
run new task "Autocomplete" --prio P2 --under F-0001 > /dev/null

# Reopen from done
run start T-0001 > /dev/null
run done T-0001 > /dev/null
out=$(run reopen T-0001)
assert_contains "Reopen done task" "$out" "Updated T-0001"
out=$(run show T-0001)
assert_contains "Reopened task is todo" "$out" "todo"

# Reopen from skipped
run skip T-0002 > /dev/null
out=$(run reopen T-0002)
assert_contains "Reopen skipped task" "$out" "Updated T-0002"
out=$(run show T-0002)
assert_contains "Reopened skipped task is todo" "$out" "todo"

# Reopen from deferred
run defer T-0003 > /dev/null
out=$(run reopen T-0003)
assert_contains "Reopen deferred task" "$out" "Updated T-0003"
out=$(run show T-0003)
assert_contains "Reopened deferred task is todo" "$out" "todo"

# Reopen on non-terminal should fail
run start T-0001 > /dev/null
out=$(run reopen T-0001 || true)
assert_contains "Reopen doing task fails" "$out" "not in a terminal state"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 6: Feature collapse (backlog/now) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Dashboard" --prio P1 --section Now > /dev/null
run new task "Widget A" --prio P0 --under F-0001 > /dev/null
run new task "Widget B" --prio P1 --under F-0001 > /dev/null
run new task "Widget C" --prio P2 --under F-0001 > /dev/null
run new task "Widget D" --prio P3 --under F-0001 > /dev/null

run skip T-0003 > /dev/null
run skip T-0004 > /dev/null

out=$(run tree)
assert_contains "Scattered: has [Now] section" "$out" "[Now]"
assert_contains "Scattered: has [Skipped] section" "$out" "[Skipped]"

out=$(run backlog F-0001)
assert_contains "Backlog collapse" "$out" "Moved F-0001"

out=$(cat TASKS.md)
assert_not_contains "No shadows after collapse" "$out" "@shadow"

out=$(run tree)
assert_not_contains "No section labels after collapse" "$out" "[Now]"
assert_not_contains "No section labels after collapse (2)" "$out" "[Skipped]"
assert_contains "All tasks under F-0001" "$out" "T-0001"
assert_contains "All tasks under F-0001 (2)" "$out" "T-0004"

out=$(run now F-0001)
assert_contains "Now promote" "$out" "Moved F-0001"

out=$(run list --section Now)
assert_contains "F-0001 now in Now" "$out" "F-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 7: WIP enforcement (single doing) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "API" --prio P1 --section Now > /dev/null
run new task "Endpoint A" --prio P0 --under F-0001 > /dev/null
run new task "Endpoint B" --prio P1 --under F-0001 > /dev/null

run start T-0001 > /dev/null

out=$(run start T-0002)
assert_contains "Start T-0002 succeeds" "$out" "Updated T-0002"

out=$(run show T-0001)
assert_contains "T-0001 reverted to todo" "$out" "todo"

out=$(run current)
assert_contains "Only T-0002 is doing" "$out" "T-0002"
assert_not_contains "T-0001 not doing anymore" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 8: Multiple Features with shadows ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Auth" --prio P0 --section Now > /dev/null
run new feature "Billing" --prio P1 --section Now > /dev/null
run new task "Login" --prio P0 --under F-0001 > /dev/null
run new task "Logout" --prio P1 --under F-0001 > /dev/null
run new task "Payments" --prio P0 --under F-0002 > /dev/null
run new task "Invoices" --prio P1 --under F-0002 > /dev/null

run skip T-0002 > /dev/null
run skip T-0004 > /dev/null

out=$(run tree)
assert_contains "F-0001 has Skipped section" "$out" "[Skipped]"
assert_contains "F-0001 has Now section" "$out" "[Now]"

out=$(run show F-0001)
assert_contains "Show F-0001 merged" "$out" "[Now]"
assert_contains "Show F-0001 merged skipped" "$out" "[Skipped]"

out=$(run show F-0002)
assert_contains "Show F-0002 merged" "$out" "[Now]"
assert_contains "Show F-0002 merged skipped" "$out" "[Skipped]"

out=$(run validate)
assert_contains "Validate passes with multiple shadows" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 9: mv --under with shadow cleanup ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Frontend" --prio P1 --section Now > /dev/null
run new feature "Backend" --prio P1 --section Now > /dev/null
run new task "Login UI" --prio P0 --under F-0001 > /dev/null
run new task "Login API" --prio P0 --under F-0001 > /dev/null

run skip T-0002 > /dev/null

out=$(cat TASKS.md)
assert_contains "Shadow exists before mv" "$out" "@shadow"

out=$(run mv T-0002 --under F-0002)
assert_contains "Move T-0002 under F-0002" "$out" "Moved T-0002"

shadow_count=$(grep -c "@shadow" TASKS.md || true)
assert_contains "Shadow cleaned after mv --under" "$shadow_count" "0"

out=$(run show F-0002)
assert_contains "T-0002 now under F-0002" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 10: Top-level task skip (no parent Feature) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new task "Standalone task" --prio P1 --section Now > /dev/null

out=$(run skip T-0001)
assert_contains "Skip standalone task" "$out" "Moved T-0001"

out=$(run list --section Skipped)
assert_contains "Standalone task in Skipped" "$out" "T-0001"

out=$(cat TASKS.md)
assert_not_contains "No shadow for standalone" "$out" "@shadow"

out=$(run validate)
assert_contains "Validate passes for standalone" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 11: done does NOT move section ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Cleanup" --prio P1 --section Now > /dev/null
run new task "Remove old code" --prio P0 --under F-0001 > /dev/null

run start T-0001 > /dev/null
run done T-0001 > /dev/null

out=$(run show T-0001)
assert_contains "Done task stays in Now" "$out" "Section: Now"

out=$(cat TASKS.md)
assert_not_contains "No shadow on done" "$out" "@shadow"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 12: new task with all inline flags ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Full flags test" --prio P0 --section Now > /dev/null
run new task "First" --prio P0 --under F-0001 > /dev/null

out=$(run new task "Second task" --prio P1 --under F-0001 --effort 4h --tags security,critical --deps T-0001)
assert_contains "Create with all flags" "$out" "Created T-0002"

out=$(run show T-0002)
assert_contains "Has effort" "$out" "Effort: 4h"
assert_contains "Has tags" "$out" "Tags: security,critical"
assert_contains "Has deps" "$out" "Depends on: T-0001"

out=$(run validate)
assert_contains "Validate passes with inline flags" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 13: Complex scatter and re-collapse ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Complex Feature" --prio P1 --section Now > /dev/null
run new task "Task A" --prio P0 --under F-0001 > /dev/null
run new task "Task B" --prio P1 --under F-0001 > /dev/null
run new task "Task C" --prio P2 --under F-0001 > /dev/null
run new task "Task D" --prio P3 --under F-0001 > /dev/null

run skip T-0003 > /dev/null
run skip T-0004 > /dev/null
run start T-0001 > /dev/null

out=$(run tree)
assert_contains "Scatter: Now section" "$out" "[Now]"
assert_contains "Scatter: Skipped section" "$out" "[Skipped]"

run backlog F-0001 > /dev/null

out=$(cat TASKS.md)
assert_not_contains "No shadows after backlog collapse" "$out" "@shadow"

out=$(run list --section Backlog)
assert_contains "T-0001 in Backlog" "$out" "T-0001"
assert_contains "T-0002 in Backlog" "$out" "T-0002"
assert_contains "T-0003 in Backlog" "$out" "T-0003"
assert_contains "T-0004 in Backlog" "$out" "T-0004"

run now F-0001 > /dev/null
run skip T-0004 > /dev/null

out=$(cat TASKS.md)
assert_contains "Shadow re-created after re-scatter" "$out" "@shadow"

run now F-0001 > /dev/null
out=$(cat TASKS.md)
assert_not_contains "No shadows after Now collapse" "$out" "@shadow"

out=$(run validate)
assert_contains "Validate passes after scatter-collapse cycles" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 14: Validate catches orphaned shadow ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Test Feature" --prio P1 --section Now > /dev/null
run new task "Test Task" --prio P0 --under F-0001 > /dev/null

# Inject orphan shadow (no matching primary F-0099) — portable (no sed -i)
awk '/^## Skipped/{print; print "- [ ] (F-0099) [P1] [todo] Orphan Feature @shadow"; next} 1' \
    TASKS.md > TASKS.md.tmp && mv TASKS.md.tmp TASKS.md

out=$(run validate || true)
assert_contains "Validate catches orphan shadow" "$out" "shadow F-0099 has no primary"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 15: mv --section cleans up empty shadow ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Shadow Test" --prio P1 --section Now > /dev/null
run new task "Task A" --prio P0 --under F-0001 > /dev/null
run new task "Task B" --prio P1 --under F-0001 > /dev/null

run skip T-0002 > /dev/null
out=$(cat TASKS.md)
assert_contains "Shadow exists after skip" "$out" "@shadow"

run mv T-0002 --section Now > /dev/null
out=$(cat TASKS.md)
assert_not_contains "Empty shadow auto-cleaned by mv" "$out" "@shadow"

out=$(run validate)
assert_contains "Validate passes after cleanup" "$out" "OK"

# Verify validate detects manually-orphaned empty shadow
run mv T-0002 --under F-0001 > /dev/null
run skip T-0002 > /dev/null
sed '/T-0002.*skipped/d' TASKS.md > TASKS.md.tmp && mv TASKS.md.tmp TASKS.md
out=$(run validate)
assert_contains "Validate warns about empty shadow" "$out" "empty shadow"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 16: next respects dependencies ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Deps Test" --prio P1 --section Now > /dev/null
run new task "Foundation" --prio P1 --under F-0001 > /dev/null
run new task "Depends on foundation" --prio P0 --under F-0001 --deps T-0001 > /dev/null

out=$(run next)
assert_contains "Next respects deps: T-0001 first" "$out" "T-0001"

run start T-0001 > /dev/null
run done T-0001 > /dev/null
out=$(run next)
assert_contains "Next after unblock: T-0002" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 17: Feature-only status changes ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Feature Status" --prio P1 --section Now > /dev/null
run new task "Child task" --prio P0 --under F-0001 > /dev/null

out=$(run defer F-0001)
assert_contains "Defer Feature" "$out" "Updated F-0001"
out=$(run show F-0001)
assert_contains "Feature deferred status" "$out" "deferred"
assert_contains "Feature stays in Now" "$out" "Section: Now"

out=$(run reopen F-0001)
assert_contains "Reopen Feature" "$out" "Updated F-0001"
out=$(run show F-0001)
assert_contains "Feature reopened to todo" "$out" "todo"

run start T-0001 > /dev/null
run done T-0001 > /dev/null
out=$(run done F-0001)
assert_contains "Done Feature" "$out" "Updated F-0001"
out=$(run show F-0001)
assert_contains "Feature done status" "$out" "done"
assert_contains "Feature stays in Now (done)" "$out" "Section: Now"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 18: Skip on Feature (status-only, no move) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Skip Feature Test" --prio P1 --section Now > /dev/null
run new task "Child" --prio P0 --under F-0001 > /dev/null

out=$(run skip F-0001)
assert_contains "Skip Feature" "$out" "Updated F-0001"
out=$(run show F-0001)
assert_contains "Feature skipped status" "$out" "skipped"
assert_contains "Feature stays in Now after skip" "$out" "Section: Now"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 19: Backlog/Now section listing ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Now Feature" --prio P0 --section Now > /dev/null
run new feature "Backlog Feature" --prio P2 --section Backlog > /dev/null
run new task "Now Task" --prio P0 --under F-0001 > /dev/null
run new task "Backlog Task" --prio P2 --under F-0002 > /dev/null

out=$(run backlog)
assert_contains "Backlog list shows F-0002" "$out" "F-0002"
assert_contains "Backlog list shows T-0002" "$out" "T-0002"
assert_not_contains "Backlog list excludes Now items" "$out" "Now Feature"

out=$(run now)
assert_contains "Now list shows F-0001" "$out" "F-0001"
assert_contains "Now list shows T-0001" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 20: Top-level priority sorting in Now section ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Low prio feature" --prio P3 --section Now > /dev/null
run new feature "High prio feature" --prio P0 --section Now > /dev/null
run new task "Under low" --prio P0 --under F-0001 > /dev/null
run new task "Under high" --prio P0 --under F-0002 > /dev/null

out=$(run tree)
f2_line=$(echo "$out" | grep -n "F-0002" | head -1 | cut -d: -f1)
f1_line=$(echo "$out" | grep -n "F-0001" | head -1 | cut -d: -f1)

if [ "$f2_line" -lt "$f1_line" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: Top-level sort: P0 Feature before P3 Feature"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Top-level sort wrong (F-0002@$f2_line, F-0001@$f1_line)"
    echo -e "  ${RED}FAIL${NC}: Top-level sort wrong (F-0002@$f2_line, F-0001@$f1_line)"
fi

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 21: nextid and ID normalization ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Test" --prio P1 > /dev/null
run new task "Task" --prio P0 --under F-0001 > /dev/null

out=$(run nextid)
assert_contains "Next feature ID" "$out" "F-0002"
assert_contains "Next task ID" "$out" "T-0002"

out=$(run show F-1)
assert_contains "Short ID F-1 works" "$out" "F-0001"

out=$(run show T-1)
assert_contains "Short ID T-1 works" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 22: init --force with backup ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Will be backed up" --prio P1 > /dev/null

out=$(run init --force)
assert_contains "Backup created" "$out" "Backed up"
assert_contains "Init with force" "$out" "Initialized"

if [ -f "TASKS.md.backup" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: Backup file exists"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Backup file missing"
    echo -e "  ${RED}FAIL${NC}: Backup file missing"
fi

out=$(cat TASKS.md.backup)
assert_contains "Backup has old content" "$out" "Will be backed up"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 23: Skip then start same task (flip-flop) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Flip flop" --prio P1 --section Now > /dev/null
run new task "Bouncy task" --prio P0 --under F-0001 > /dev/null
run new task "Stable task" --prio P1 --under F-0001 > /dev/null

run skip T-0001 > /dev/null
out=$(run show T-0001)
assert_contains "After skip: in Skipped" "$out" "skipped"

run reopen T-0001 > /dev/null
run start T-0001 > /dev/null
out=$(run show T-0001)
assert_contains "After start: doing" "$out" "doing"

shadow_count=$(grep -c "@shadow" TASKS.md || true)
if [ "$shadow_count" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: Empty shadow cleaned after task moved back"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: Shadow still exists ($shadow_count)"
    echo -e "  ${RED}FAIL${NC}: Shadow still exists after task moved back ($shadow_count shadows)"
fi

out=$(run validate)
assert_contains "Validate passes after flip-flop" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 24: link command (deps add/rm/set) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Link test" --prio P1 --section Now > /dev/null
run new task "Base" --prio P0 --under F-0001 > /dev/null
run new task "Dependent" --prio P1 --under F-0001 > /dev/null
run new task "Also dependent" --prio P2 --under F-0001 > /dev/null

out=$(run link T-0002 --deps add T-0001)
assert_contains "Link deps add" "$out" "Linked"

out=$(run link T-0003 --deps set T-0001,T-0002)
assert_contains "Link deps set" "$out" "Linked"

out=$(run show T-0003)
assert_contains "T-0003 deps" "$out" "Depends on: T-0001,T-0002"

out=$(run link T-0003 --deps rm T-0002)
assert_contains "Link deps rm" "$out" "Linked"

out=$(run show T-0003)
assert_contains "T-0003 deps after rm" "$out" "Depends on: T-0001"
assert_not_contains "T-0002 removed from deps" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 25: set command (branch, pr, issue, system) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Metadata" --prio P1 --section Now > /dev/null
run new task "Rich task" --prio P0 --under F-0001 > /dev/null

run set T-0001 --branch feat/rich-task > /dev/null
run set T-0001 --pr 42 > /dev/null
run set T-0001 --issue 99 > /dev/null
run set T-0001 --system sprint-3 > /dev/null

out=$(run show T-0001)
assert_contains "Branch set" "$out" "Branch: feat/rich-task"
assert_contains "PR set" "$out" "PR: #42"
assert_contains "Issue set" "$out" "Issue: #99"
assert_contains "System set" "$out" "System: sprint-3"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 26: list with filters ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Filter test" --prio P1 --section Now > /dev/null
run new task "P0 todo" --prio P0 --under F-0001 > /dev/null
run new task "P1 todo" --prio P1 --under F-0001 > /dev/null
run new task "P2 todo" --prio P2 --under F-0001 > /dev/null

run start T-0001 > /dev/null
run done T-0001 > /dev/null
run set T-0002 --effort 4h > /dev/null
run set T-0002 --system sprint-1 > /dev/null

out=$(run list --status done)
assert_contains "Filter by done" "$out" "T-0001"
assert_not_contains "Done filter excludes todo" "$out" "T-0002"

out=$(run list --prio P1)
assert_contains "Filter by P1" "$out" "T-0002"
assert_not_contains "P1 filter excludes P0" "$out" "T-0001"

out=$(run list --effort)
assert_contains "Filter by effort (any)" "$out" "T-0002"

out=$(run list --system sprint-1)
assert_contains "Filter by system" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 27: Notes section ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Notes test" --prio P1 --section Now > /dev/null
run new task "Task with notes" --prio P0 --under F-0001 > /dev/null

cat >> TASKS.md << 'NOTES'

## T-0001
Implementation detail: use Redis for caching.
Watch out for connection pooling issues.
NOTES

out=$(run show T-0001 --full)
assert_contains "Show --full includes notes" "$out" "Redis for caching"
assert_contains "Show --full includes second line" "$out" "connection pooling"

out=$(run validate)
assert_contains "Validate passes with notes" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 28: prio command ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Prio test" --prio P1 --section Now > /dev/null
run new task "Change my prio" --prio P2 --under F-0001 > /dev/null

out=$(run prio T-0001 P0)
assert_contains "Prio change" "$out" "Updated"

out=$(run show T-0001)
assert_contains "Prio is now P0" "$out" "P0"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 29: Error handling ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

out=$(run show T-9999 2>&1 || true)
assert_contains "Show nonexistent" "$out" "not found"

out=$(run start T-9999 2>&1 || true)
assert_contains "Start nonexistent" "$out" "not found"

run new feature "Err test" --prio P1 --section Now > /dev/null
run new task "Err task" --prio P0 --under F-0001 > /dev/null
run start T-0001 > /dev/null
run done T-0001 > /dev/null
out=$(run done T-0001 2>&1 || true)
assert_contains "Double done rejected" "$out" "already done"

out=$(run init 2>&1 || true)
assert_contains "Init existing fails" "$out" "already exists"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 30: Full sprint simulation ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

# PM creates two features
run new feature "User Auth" --prio P0 --section Now > /dev/null
run new feature "Notifications" --prio P2 --section Backlog > /dev/null

# Tasks under Auth
run new task "Login endpoint" --prio P0 --under F-0001 --effort 4h > /dev/null
run new task "Signup endpoint" --prio P0 --under F-0001 --effort 3h --deps T-0001 > /dev/null
run new task "Password reset" --prio P1 --under F-0001 --effort 2h --deps T-0001 > /dev/null
run new task "OAuth2 (future)" --prio P3 --under F-0001 --effort 8h > /dev/null

# Tasks under Notifications
run new task "Email templates" --prio P1 --under F-0002 --effort 2h > /dev/null
run new task "SMS gateway" --prio P2 --under F-0002 --effort 4h --deps T-0005 > /dev/null

run start T-0001 > /dev/null
run done T-0001 > /dev/null
run skip T-0004 > /dev/null
run defer T-0003 > /dev/null
run start T-0002 > /dev/null

out=$(run tree)
assert_contains "Complex: Auth feature visible" "$out" "F-0001"
assert_contains "Complex: Notifications visible" "$out" "F-0002"
assert_contains "Complex: T-0002 is doing" "$out" "T-0002"
assert_contains "Complex: Auth has section labels" "$out" "[Now]"
assert_contains "Complex: Auth skipped section" "$out" "[Skipped]"

run done T-0002 > /dev/null
run now F-0002 > /dev/null
out=$(run next)
assert_contains "Complex: next task after auth done" "$out" "T-0005"

run start T-0005 > /dev/null
run done T-0005 > /dev/null
run start T-0006 > /dev/null
run done T-0006 > /dev/null
run done F-0002 > /dev/null

out=$(run validate)
assert_contains "Complex: final validate passes" "$out" "OK"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 31: Milestone AC1 — no milestone data round-trips byte-for-byte ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Legacy" --prio P1 --section Now > /dev/null
run new task "Legacy task" --prio P0 --under F-0001 > /dev/null

before=$(cksum < TASKS.md)
# Run every read-only / milestone-aware command; none may mutate a file with no milestone data.
run list > /dev/null
run list --milestone default > /dev/null
run tree > /dev/null
run next > /dev/null
run show F-0001 > /dev/null
run current > /dev/null
run nextid > /dev/null
run backlog > /dev/null
run now > /dev/null
run milestone > /dev/null
run validate > /dev/null
after=$(cksum < TASKS.md)

if [ "$before" = "$after" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: TASKS.md unchanged byte-for-byte (no milestone data)"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: TASKS.md mutated by milestone-aware commands (before=$before after=$after)"
    echo -e "  ${RED}FAIL${NC}: TASKS.md mutated by milestone-aware commands"
fi

out=$(cat TASKS.md)
assert_not_contains "No @milestone tag written implicitly" "$out" "@milestone"

out=$(run list --milestone default)
assert_contains "Unassigned task in default bucket (no registry)" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 32: Milestone AC2 — new --milestone + alias resolution via registry ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   Complete federal estimate
- M2  alias=beta   status=planned  Surfaces and API
MS

run new feature "Rollup" --prio P1 --section Now > /dev/null
out=$(run new task "Alpha task" --prio P0 --under F-0001 --milestone alpha)
assert_contains "new --milestone accepted" "$out" "Created T-0001"

out=$(cat TASKS.md)
assert_contains "Stores value as typed (@milestone=alpha)" "$out" "@milestone=alpha"

out=$(run list --milestone m1)
assert_contains "list --milestone m1 finds alias-tagged task" "$out" "T-0001"

out=$(run list --milestone alpha)
assert_contains "list --milestone alpha finds task" "$out" "T-0001"

out=$(run list --milestone m2)
assert_not_contains "list --milestone m2 excludes M1 task" "$out" "T-0001"

out=$(run show T-0001)
assert_contains "show displays resolved milestone" "$out" "M1 (alpha)"

out=$(run milestone M1)
assert_contains "milestone M1 detail shows alias" "$out" "alpha"
assert_contains "milestone M1 detail shows task" "$out" "T-0001"

out=$(run milestone alpha)
assert_contains "milestone <alias> detail resolves to M1" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 33: Milestone AC3 — unassigned task in default bucket ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Sentinel" --prio P1 --section Now > /dev/null
run new task "No milestone" --prio P0 --under F-0001 > /dev/null

out=$(run list --milestone default)
assert_contains "Unassigned appears under default" "$out" "T-0001"

out=$(run milestone)
assert_contains "Rollup has a default bucket" "$out" "default"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 34: Milestone AC4 — set --milestone \"\" clears to sentinel ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   North star
MS

run new feature "Clearable" --prio P1 --section Now > /dev/null
run new task "Assigned" --prio P0 --under F-0001 --milestone m1 > /dev/null

out=$(run show T-0001)
assert_contains "Task starts assigned to M1" "$out" "M1"

out=$(run set T-0001 --milestone "")
assert_contains "set --milestone empty clears" "$out" "T-0001"

out=$(cat TASKS.md)
assert_not_contains "Milestone tag removed after clear" "$out" "@milestone"

out=$(run list --milestone default)
assert_contains "Cleared task back in default bucket" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 35: Milestone AC5 — rollup sums across id+alias, includes default ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   North star
MS

run new feature "Counts" --prio P1 --section Now > /dev/null
run new task "By id" --prio P0 --under F-0001 --milestone m1 > /dev/null
run new task "By alias" --prio P1 --under F-0001 --milestone alpha > /dev/null
run new task "Unassigned" --prio P2 --under F-0001 > /dev/null

run start T-0001 > /dev/null
run done T-0001 > /dev/null

out=$(run milestone)
assert_contains "Rollup shows M1" "$out" "M1"
assert_contains "M1 sums id+alias to 2 tasks" "$out" "2 tasks"
assert_contains "M1 is 50% done" "$out" "50% done"
assert_contains "Rollup includes default bucket" "$out" "default"
assert_contains "default has 1 task" "$out" "1 task"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 36: Milestone AC6 — no registry, freeform grouped by raw value ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Freeform" --prio P1 --section Now > /dev/null
run new task "X work" --prio P0 --under F-0001 --milestone sprint-x > /dev/null
run new task "Y work" --prio P1 --under F-0001 --milestone sprint-y > /dev/null

out=$(run milestone)
assert_contains "Freeform bucket sprint-x" "$out" "sprint-x"
assert_contains "Freeform bucket sprint-y" "$out" "sprint-y"

out=$(run list --milestone sprint-x)
assert_contains "Freeform filter matches x task" "$out" "T-0001"
assert_not_contains "Freeform filter excludes y task" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 37: Milestone AC7 — validate warns (exit 0) on unknown milestone ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   North star
MS

run new feature "Validated" --prio P1 --section Now > /dev/null
run new task "Known" --prio P0 --under F-0001 --milestone m1 > /dev/null
run new task "Unknown" --prio P1 --under F-0001 --milestone zzz > /dev/null

set +e
out=$(run validate 2>&1)
rc=$?
set -e

assert_contains "Validate warns on unknown milestone" "$out" "unknown milestone"
assert_contains "Validate still passes (structural OK)" "$out" "OK: TASKS.md validation passed"
assert_not_contains "Known milestone not flagged" "$out" "unknown milestone 'm1'"

if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: Unknown milestone is a warning, not an error (exit 0)"
else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: validate exited $rc on unknown milestone (want 0)"
    echo -e "  ${RED}FAIL${NC}: validate exited $rc on unknown milestone (want 0)"
fi

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 38: migrate-tags-to-milestone helper ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Interim" --prio P1 --section Now > /dev/null
run new task "Interim task" --prio P0 --under F-0001 --tags m1,security > /dev/null

out=$(run migrate-tags-to-milestone m1)
assert_contains "Migrate reports converted task" "$out" "Migrated 1"

out=$(cat TASKS.md)
assert_contains "Milestone tag added" "$out" "@milestone=m1"
assert_contains "Non-milestone tag preserved" "$out" "@tags=security"

out=$(run list --milestone m1)
assert_contains "Migrated task now in m1 bucket" "$out" "T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 39: sentinel guard + next --milestone ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   North star
- M2  alias=beta   status=planned  Later
MS

# A sentinel that collides with the M<n> ID pattern must be rejected.
out=$(TASKS_MILESTONE_SENTINEL=m1 python3 "$TASKS_PY" milestone 2>&1 || true)
assert_contains "Rejects sentinel matching M<n>" "$out" "must not match"

run new feature "NextMS" --prio P1 --section Now > /dev/null
run new task "M2 urgent" --prio P0 --under F-0001 --milestone m2 > /dev/null
run new task "M1 later" --prio P1 --under F-0001 --milestone m1 > /dev/null

out=$(run next)
assert_contains "Plain next picks highest prio (M2 task)" "$out" "T-0001"

out=$(run next --milestone m1)
assert_contains "next --milestone m1 picks the M1 task" "$out" "T-0002"
assert_not_contains "next --milestone m1 skips M2 task" "$out" "Next task: T-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 40: milestone on existing features + milestone --table report ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   Federal estimate
- M2  alias=beta   status=planned  Surfaces and API
MS

# Two existing features created WITHOUT a milestone, then assigned after the fact.
run new feature "Estimator core" --prio P0 --section Now > /dev/null
run new feature "API surface" --prio P1 --section Now > /dev/null
run new feature "Housekeeping" --prio P2 --section Backlog > /dev/null
run new task "Compute engine" --prio P0 --under F-0002 > /dev/null

# Assign a milestone to an already-existing feature.
out=$(run set F-0001 --milestone m1)
assert_contains "set --milestone works on an existing feature" "$out" "F-0001"

out=$(run list --milestone m1)
assert_contains "Feature listed under its milestone" "$out" "F-0001"

# Attribute F-0002 to M2 indirectly, via a task under it.
run set T-0001 --milestone m2 > /dev/null

out=$(run milestone --table)
assert_contains "Table header" "$out" "MILESTONE"
assert_contains "Table has FEATURES column" "$out" "FEATURES"
assert_contains "Table has STATUS column" "$out" "STATUS"
assert_contains "M1 row lists directly-tagged feature" "$out" "F-0001"
assert_contains "M1 shows registry status" "$out" "active"
assert_contains "M2 row lists feature via its tagged task" "$out" "F-0002"
assert_contains "M2 shows registry status" "$out" "planned"
assert_contains "Untagged feature falls into default row" "$out" "F-0003"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 41: set --milestone clears via 'default' and 'clear' (no tag written) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   North star
MS

run new feature "Clear tokens" --prio P1 --section Now > /dev/null
run new task "By default word" --prio P0 --under F-0001 --milestone m1 > /dev/null
run new task "By clear word" --prio P1 --under F-0001 --milestone m1 > /dev/null

out=$(run set T-0001 --milestone default)
assert_contains "set --milestone default reports clear" "$out" "Cleared @milestone"
out=$(run set T-0002 --milestone clear)
assert_contains "set --milestone clear reports clear" "$out" "Cleared @milestone"

out=$(cat TASKS.md)
assert_not_contains "Sentinel is never written into a task line" "$out" "@milestone"

out=$(run list --milestone default)
assert_contains "Both cleared tasks back in default (T-0001)" "$out" "T-0001"
assert_contains "Both cleared tasks back in default (T-0002)" "$out" "T-0002"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 42: validate does NOT warn on milestones when there is no registry ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Freeform" --prio P1 --section Now > /dev/null
run new task "Freeform task" --prio P0 --under F-0001 --milestone anything-goes > /dev/null

set +e
out=$(run validate 2>&1)
rc=$?
set -e

assert_not_contains "No unknown-milestone warning without a registry" "$out" "unknown milestone"
assert_contains "Freeform milestone still validates OK" "$out" "OK: TASKS.md validation passed"
if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC}: validate exits 0 in freeform mode"
else
    FAIL=$((FAIL + 1)); ERRORS="${ERRORS}\n  FAIL: validate exited $rc in freeform mode (want 0)"
    echo -e "  ${RED}FAIL${NC}: validate exited $rc in freeform mode (want 0)"
fi

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 43: migrate removes @tags entirely when the milestone was its only tag ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Solo tag" --prio P1 --section Now > /dev/null
run new task "Only m1" --prio P0 --under F-0001 --tags m1 > /dev/null

out=$(run migrate-tags-to-milestone m1)
assert_contains "Migrate reports 1 task" "$out" "Migrated 1"

# Scope to the task line — the init template's schema example also contains @tags=.
out=$(grep "(T-0001)" TASKS.md)
assert_contains "Milestone tag written" "$out" "@milestone=m1"
assert_not_contains "Empty @tags= not left behind on the task line" "$out" "@tags"

# Nothing-matched path is distinct from success
out=$(run migrate-tags-to-milestone doesnotexist)
assert_contains "0-match migrate is a distinct message" "$out" "nothing migrated"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 44: migrate preserves a conflicting @milestone= and reports it (no data loss) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   One
- M2  alias=beta   status=planned  Two
MS

run new feature "Conflict" --prio P1 --section Now > /dev/null
run new task "Tagged m1 but milestoned m2" --prio P0 --under F-0001 --tags m1,keep --milestone m2 > /dev/null

out=$(run migrate-tags-to-milestone m1)
assert_contains "Conflict is reported to the user" "$out" "skipped T-0001"
assert_contains "Conflict is not counted as migrated" "$out" "Migrated 0"

out=$(cat TASKS.md)
assert_contains "Existing @milestone=m2 preserved" "$out" "@milestone=m2"
assert_contains "Interim @tags=m1 left intact (not silently dropped)" "$out" "m1,keep"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 45: rollup shows zero-task registry milestones; alias case-insensitive; assign warns ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   Has work
- M2  alias=beta   status=planned  No work yet
MS

run new feature "Rollup zero" --prio P1 --section Now > /dev/null
run new task "Only M1 work" --prio P0 --under F-0001 --milestone m1 > /dev/null

out=$(run milestone)
assert_contains "Rollup includes M1" "$out" "M1 (alpha)"
assert_contains "Rollup includes registry milestone with no tasks (M2)" "$out" "M2 (beta)"

# Alias case-insensitivity (spec: case-insensitive on both id and alias)
out=$(run milestone ALPHA)
assert_contains "Detail resolves uppercase alias ALPHA -> M1" "$out" "MILESTONE M1"
assert_contains "Uppercase-alias detail lists the task" "$out" "T-0001"

# Assignment-time nudge for a value absent from the registry (still assigned)
out=$(run set T-0001 --milestone m11)
assert_contains "Unknown milestone warns at assignment time" "$out" "not in the # Milestones registry"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 46: milestone --table pins features to the correct milestone row ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   One
- M2  alias=beta   status=planned  Two
MS

run new feature "Direct M1" --prio P0 --section Now > /dev/null
run new feature "Via task M2" --prio P1 --section Now > /dev/null
run new feature "Unassigned" --prio P2 --section Backlog > /dev/null
run new task "engine" --prio P0 --under F-0002 --milestone m2 > /dev/null
run set F-0001 --milestone m1 > /dev/null

out=$(run milestone --table)

# Row-association (not mere token presence): the feature must be on the right row.
assert_row() {
    local label="$1" output="$2" rowkey="$3" needle="$4"
    if echo "$output" | grep -F "$rowkey" | grep -qF "$needle"; then
        PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC}: $label"
    else
        FAIL=$((FAIL + 1)); ERRORS="${ERRORS}\n  FAIL: $label ('$rowkey' row lacks '$needle')"
        echo -e "  ${RED}FAIL${NC}: $label"
    fi
}
assert_row "F-0001 on the M1 row" "$out" "M1 (alpha)" "F-0001"
assert_row "F-0002 on the M2 row (via its task)" "$out" "M2 (beta)" "F-0002"
assert_row "F-0003 on the default row" "$out" "default" "F-0003"

# Misattribution guard: F-0002 must NOT appear on the M1 row.
if echo "$out" | grep -F "M1 (alpha)" | grep -qF "F-0002"; then
    FAIL=$((FAIL + 1)); ERRORS="${ERRORS}\n  FAIL: F-0002 misattributed to M1 row"
    echo -e "  ${RED}FAIL${NC}: F-0002 misattributed to M1 row"
else
    PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC}: F-0002 not on the M1 row"
fi

out=$(run list --milestone ALPHA)
assert_contains "list resolves uppercase alias ALPHA -> M1 feature" "$out" "F-0001"

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 47: validate warns on registry-health problems (dup id, alias collision) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

cat >> TASKS.md << 'MS'

# Milestones

- M1  alias=alpha  status=active   First
- M1  alias=gamma  status=planned  Duplicate id
- M2  alias=alpha  status=planned  Alias collides with M1
MS

run new feature "Reg health" --prio P1 --section Now > /dev/null

set +e
out=$(run validate 2>&1)
rc=$?
set -e

assert_contains "Warns on duplicate milestone id" "$out" "duplicate milestone id M1"
assert_contains "Warns on colliding alias" "$out" "alias 'alpha' already used"
assert_contains "Registry-health issues are warnings, still OK" "$out" "OK: TASKS.md validation passed"
if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}PASS${NC}: registry-health problems are warnings (exit 0)"
else
    FAIL=$((FAIL + 1)); ERRORS="${ERRORS}\n  FAIL: validate exited $rc on registry-health warnings (want 0)"
    echo -e "  ${RED}FAIL${NC}: validate exited $rc on registry-health warnings (want 0)"
fi

# ============================================================
echo -e "\n${YELLOW}=== SCENARIO 48: tags are parsed from the trailing tag region, not prose (issue #9) ===${NC}"
# ============================================================
setup_test_dir
fresh_init > /dev/null

run new feature "Prose parsing" --prio P1 --section Now > /dev/null
run new task "Real work" --prio P0 --under F-0001 --milestone m1 > /dev/null
# Title MENTIONS @milestone= and @tags= in prose but carries NO real milestone tag.
run new task "Migrate @tags=foo -> @milestone=foo across tasks" --prio P1 --under F-0001 > /dev/null

out=$(run milestone)
assert_contains "Real milestone m1 counted" "$out" "m1"
assert_not_contains "No phantom bucket from prose @milestone=foo" "$out" "foo"

out=$(run list --milestone default)
assert_contains "Prose-only task falls into default bucket" "$out" "T-0002"

out=$(run list --milestone foo)
assert_not_contains "Prose mention does not match a milestone filter" "$out" "T-0002"

out=$(run show T-0002)
assert_not_contains "show does not report a prose milestone" "$out" "Milestone:"

# migrate must not treat a prose @milestone= as an existing (conflicting) assignment.
run set T-0002 --tags realtag > /dev/null
out=$(run migrate-tags-to-milestone realtag)
assert_contains "Prose task migrates (not skipped as a false conflict)" "$out" "Migrated 1"
out=$(run show T-0002)
assert_contains "Migrated task now resolves to realtag" "$out" "Milestone: realtag"

# write side: setting a tag must not strip a look-alike token out of the title prose.
out=$(grep "(T-0002)" TASKS.md)
assert_contains "Prose @milestone=foo preserved in the title" "$out" "@milestone=foo across tasks"

out=$(run validate)
assert_contains "Validate still passes with prose look-alikes" "$out" "OK"

# ============================================================
# Summary
# ============================================================
echo -e "\n${YELLOW}======================================${NC}"
echo -e "${YELLOW}         TEST RESULTS${NC}"
echo -e "${YELLOW}======================================${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAIL${NC}"
    echo -e "\n${RED}Failures:${NC}$ERRORS"
else
    echo -e "  ${RED}Failed: $FAIL${NC}"
fi
echo -e "${YELLOW}======================================${NC}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
