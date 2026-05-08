#!/usr/bin/env bash
# Shared test helpers for EQ3/6 test suite.
# Source this file from each test.sh:
#   source "$(dirname "$0")/../../lib/helpers.sh"   # two levels up
#   source "$(dirname "$0")/../../../lib/helpers.sh" # three levels up

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$REPO_ROOT/bin"

# Shared counters (set/read by pass/fail; run_tests.sh uses exit code per subshell)
PASS_COUNT=0
FAIL_COUNT=0

# ---------------------------------------------------------------------------
# Workdir management

setup_workdir() {
    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT
}

# ---------------------------------------------------------------------------
# Data file staging
#
# data1 is the binary thermodynamic database produced by eqpt from data0.
# The pre-built copy in src/eqpt/src/data1 is used directly (no regeneration
# needed since eqpt is tested separately in the smoke suite).
#
# TODO: For tests requiring the HMW/Pitzer database, add stage_data1_hmw()
# that copies src/eqpt/src/data1f instead.

stage_data1() {
    local workdir="$1"
    local src="$REPO_ROOT/src/eqpt/src/data1"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found. Run 'make build' first." >&2
        exit 1
    fi
    cp "$src" "$workdir/data1"
}

# ---------------------------------------------------------------------------
# Executables

run_eq3nr() {
    local workdir="$1"
    local input_file="$2"
    cp "$input_file" "$workdir/input"
    (cd "$workdir" && "$BIN/eq3nr" > run.log 2>&1) || true
}

run_eq6() {
    local workdir="$1"
    local input_file="$2"
    cp "$input_file" "$workdir/input"
    (cd "$workdir" && "$BIN/eq6" > run.log 2>&1) || true
}

# ---------------------------------------------------------------------------
# Assertions

assert_match() {
    local pattern="$1"
    local file="$2"
    local label="${3:-$pattern}"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        pass "  assert_match: $label"
    else
        fail "  assert_match: $label" "pattern '$pattern' not found in $file"
    fi
}

assert_no_match() {
    local pattern="$1"
    local file="$2"
    local label="${3:-not $pattern}"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        pass "  assert_no_match: $label"
    else
        fail "  assert_no_match: $label" "unexpected pattern '$pattern' found in $file"
    fi
}

# ---------------------------------------------------------------------------
# Reporting

_GREEN='\033[0;32m'
_RED='\033[0;31m'
_RESET='\033[0m'

pass() {
    local label="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${_GREEN}PASS${_RESET} $label"
}

fail() {
    local label="$1"
    local reason="${2:-}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${_RED}FAIL${_RESET} $label${reason:+: $reason}"
}

# Call at end of a test.sh to exit with the right code.
end_test() {
    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    fi
    exit 0
}
