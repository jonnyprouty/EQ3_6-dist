#!/usr/bin/env bash
# Shared BATS helpers for EQ3/6 test suite.
# Load from a .bats file:
#   load '../../lib/helpers'    # smoke/  (2 levels up)
#   load '../../../lib/helpers' # eq3nr/* or eq6/* (3 levels up)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$REPO_ROOT/bin"
BIN_DEW="$REPO_ROOT/bin-dew"

# ---------------------------------------------------------------------------
# Workdir management — call in BATS setup()/teardown()

setup_workdir() {
    WORKDIR="$(mktemp -d)"
}

teardown_workdir() {
    rm -rf "$WORKDIR"
}

# ---------------------------------------------------------------------------
# Data file staging
#
# data1 is the binary thermodynamic database produced by eqpt from data0.
# The pre-built copy in src/eqpt/src/data1 is used directly.
#
# TODO: Add stage_data1_hmw() for HMW/Pitzer cases (uses src/eqpt/src/data1f).

stage_data1() {
    local workdir="$1"
    local src="$REPO_ROOT/src/eqpt/src/data1"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found — run 'make build' first." >&2
        return 1
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
# DEW variant helpers (bin-dew/)

stage_data0_dew() {
    local workdir="$1"
    local src="$REPO_ROOT/upstream-dew/EQPT/DATA0"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found — run 'make fetch-dew' first." >&2
        return 1
    fi
    cp "$src" "$workdir/DATA0"
}

run_eq3_dew() {
    local workdir="$1"
    local input_file="$2"
    cp "$input_file" "$workdir/input"
    (cd "$workdir" && "$BIN_DEW/eq3" > run.log 2>&1) || true
}

run_eq6_dew() {
    local workdir="$1"
    local input_file="$2"
    cp "$input_file" "$workdir/input"
    (cd "$workdir" && "$BIN_DEW/eq6" > run.log 2>&1) || true
}

# ---------------------------------------------------------------------------
# Assertions — return 1 on failure (BATS treats non-zero as test failure)

assert_match() {
    local pattern="$1"
    local file="$2"
    local label="${3:-$pattern}"
    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo "assert_match failed: '$label' — pattern '$pattern' not found in $file" >&2
        return 1
    fi
}

assert_no_match() {
    local pattern="$1"
    local file="$2"
    local label="${3:-not $pattern}"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo "assert_no_match failed: '$label' — unexpected pattern '$pattern' in $file" >&2
        return 1
    fi
}
