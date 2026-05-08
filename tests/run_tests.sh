#!/usr/bin/env bash
# EQ3/6 test runner.
# Discovers every test.sh under tests/cases/ and runs each in a subshell.
# Usage: bash tests/run_tests.sh
#        make test

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES_DIR="$REPO_ROOT/tests/cases"

PASS=0
FAIL=0
FAILED_CASES=()

run_case() {
    local test_sh="$1"
    local name
    name="$(realpath --relative-to="$CASES_DIR" "$(dirname "$test_sh")")"

    if bash "$test_sh"; then
        PASS=$((PASS + 1))
        echo "  -> PASSED: $name"
    else
        FAIL=$((FAIL + 1))
        FAILED_CASES+=("$name")
        echo "  -> FAILED: $name"
    fi
}

echo "=== EQ3/6 test suite ==="
echo

# Discover test.sh files at cases/*/ and cases/*/*/
while IFS= read -r -d '' test_sh; do
    run_case "$test_sh"
done < <(find "$CASES_DIR" -name "test.sh" -print0 | sort -z)

echo
echo "Results: $PASS passed, $FAIL failed"

if [ "${#FAILED_CASES[@]}" -gt 0 ]; then
    echo
    echo "Failed cases:"
    for c in "${FAILED_CASES[@]}"; do
        echo "  $c"
    done
    exit 1
fi

# ---------------------------------------------------------------------------
# TODO: Full upstream test library (170+ cases)
#
# Source: upstream/EQ3_6v8.0a TestLibrary PC.zip
# Libraries:
#   EQ3NR: 3tlib_cmp (56 cases), 3tlib_hmw (5), 3tlib_fmt (6),
#           3tlib_ymp (56), 3tlib_ypf (8)
#   EQ6:   6tlib_cmp (20 cases), 6tlib_hmw (6), 6tlib_fmt (5),
#           6tlib_ymp (20), 6tlib_ypf (2)
#
# Each library dir in the ZIP contains paired .3i/.3o (or .6i/.6o) files
# suitable for full output-diff regression testing.
#
# Extension path:
#   1. Add assert_output_matches() to lib/helpers.sh that diffs actual vs.
#      reference output (with tolerance for floating-point formatting differences
#      and the run-time/date stamps in the header).
#   2. Add stage_data1_hmw() to helpers.sh for Pitzer/HMW cases (uses data1f).
#   3. Extract all cases from the ZIP into tests/cases/eq3nr/ and
#      tests/cases/eq6/ — each with an input file, a reference .3o/.6o, and
#      a test.sh that calls run_eq3nr/run_eq6 + assert_output_matches.
# ---------------------------------------------------------------------------
