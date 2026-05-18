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
# DEW workshop helpers
#
# DEW EQ3/EQ6 (R110/R100) need data1 + data2 + data3 (compiled from DATA0 by
# bin-dew/eqpt).  Three datasets are cached under tests/.dew_data_cache/:
#
#   psat      — Psat DATA0 (surface conditions, from psat_data0___examples_from_enki.zip)
#   10kbar    — 10 kbar DATA0 (high P-T, from 10_kbar_300-650c.zip)
#   upstream  — upstream-dew/EQPT/DATA0 (used for MOR hydrothermal example)

DEW_DATA_CACHE="$REPO_ROOT/tests/.dew_data_cache"

# Stage data1, data2, data3 from the given DEW dataset cache into workdir.
# dataset: psat | 10kbar | upstream
stage_dew_data() {
    local workdir="$1"
    local dataset="$2"
    local cache="$DEW_DATA_CACHE/$dataset"
    if [ ! -f "$cache/data1" ]; then
        echo "ERROR: $cache/data1 not found — run 'make extract-dew-workshop' first." >&2
        return 1
    fi
    cp "$cache/data1" "$workdir/data1"
    [ -f "$cache/data2" ] && cp "$cache/data2" "$workdir/data2" || true
    [ -f "$cache/data3" ] && cp "$cache/data3" "$workdir/data3" || true
}

# Normalize DEW EQ3/EQ6 output for comparison.  The DEW binaries (R110/R100)
# write null bytes into the timing fields (uninitialized Fortran CHARACTER
# buffers), making the output a binary file.  Use -a to force text search.
# DEW uses lowercase "start time"/"end time" unlike the v8.0a uppercase form.
normalize_dew_output() {
    local file="$1"
    grep -av \
        -e '^          start time = ' \
        -e '^            end time = ' \
        -e '^          user time = ' \
        -e '^           cpu time = ' \
        "$file"
}

# Assert that the actual DEW output matches the platform-appropriate reference.
# expected_rel: path relative to tests/dew/expected/ (e.g. surface_seawater.out).
assert_dew_output_matches_ref() {
    local actual="$1"
    local expected_rel="$2"
    local expected
    expected="$REPO_ROOT/tests/dew/expected/$_EQ_PLATFORM/$expected_rel"
    if [ ! -f "$expected" ]; then
        expected="$REPO_ROOT/tests/dew/expected/linux/$expected_rel"
    fi
    if [ ! -f "$expected" ]; then
        echo "Reference not found: $expected" >&2
        return 1
    fi
    local diff_out
    diff_out=$(diff <(normalize_dew_output "$actual") <(normalize_dew_output "$expected")) || {
        echo "DEW output does not match reference $expected:" >&2
        echo "$diff_out" | head -40 >&2
        return 1
    }
}

# assert_match_dew: like assert_match but uses grep -a for binary-compatible DEW output files.
assert_match_dew() {
    local pattern="$1"
    local file="$2"
    local label="${3:-$pattern}"
    if ! grep -qa "$pattern" "$file" 2>/dev/null; then
        echo "assert_match_dew failed: '$label' — pattern '$pattern' not found in $file" >&2
        return 1
    fi
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

# ---------------------------------------------------------------------------
# Testlib helpers

DATA1_CACHE="$REPO_ROOT/tests/.data1_cache"

# Canonical platform tag used for reference output selection.
# ubuntu: Ubuntu Linux (gfortran from Ubuntu apt produces different ODE paths)
# mac:    macOS (Homebrew gfortran)
# linux:  all other Linux distributions (baseline, Fedora-generated refs)
case "$(uname -s)" in
    Darwin) _EQ_PLATFORM=mac ;;
    Linux)
        if grep -qi ubuntu /etc/os-release 2>/dev/null; then
            _EQ_PLATFORM=ubuntu
        else
            _EQ_PLATFORM=linux
        fi
        ;;
    *) _EQ_PLATFORM=linux ;;
esac

# Stage the cached data1 file for the given dataset into workdir.
# dataset: com | hmw | ymp | ypf | fmt
stage_data1_for() {
    local workdir="$1"
    local dataset="$2"
    local src="$DATA1_CACHE/data1.${dataset}"
    if [ ! -f "$src" ]; then
        echo "ERROR: $src not found — run 'make extract-testlib' first." >&2
        return 1
    fi
    cp "$src" "$workdir/data1"
}

# Normalize EQ3/6 output for comparison: strip the four timing lines that
# contain wall-clock timestamps and run time, which vary between runs.
normalize_eq_output() {
    local file="$1"
    grep -v \
        -e '^ Run  [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' \
        -e '^          Start time = ' \
        -e '^            End time = ' \
        -e '^           Run time = ' \
        "$file"
}

# Assert that the actual EQ3/6 output matches the platform-appropriate reference.
# expected_rel: path relative to tests/testlib/expected/ (e.g. 3tlib_cmp/acidmwb.out).
# Looks for tests/testlib/expected/<platform>/<expected_rel> first, then
# tests/testlib/expected/linux/<expected_rel> as fallback.
assert_output_matches_ref() {
    local actual="$1"
    local expected_rel="$2"
    local expected
    expected="$REPO_ROOT/tests/testlib/expected/$_EQ_PLATFORM/$expected_rel"
    if [ ! -f "$expected" ]; then
        expected="$REPO_ROOT/tests/testlib/expected/linux/$expected_rel"
    fi
    local diff_out
    diff_out=$(diff <(normalize_eq_output "$actual") <(normalize_eq_output "$expected")) || {
        echo "Output does not match reference $expected:" >&2
        echo "$diff_out" | head -40 >&2
        return 1
    }
}
