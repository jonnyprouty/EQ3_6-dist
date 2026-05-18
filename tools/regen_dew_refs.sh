#!/usr/bin/env bash
# Regenerate DEW workshop reference outputs for the current platform.
# Run via: make regen-dew-refs
# Commit the results in tests/dew/expected/<platform>/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DEW="$REPO_ROOT/bin-dew"
DEW_CACHE="$REPO_ROOT/tests/.dew_data_cache"
DEW_INPUTS="$REPO_ROOT/tests/dew/inputs"

case "$(uname -s)" in
    Darwin) PLATFORM=mac ;;
    *)      PLATFORM=linux ;;
esac
EXPECTED="$REPO_ROOT/tests/dew/expected/$PLATFORM"

echo "==> Platform: $PLATFORM  (writing to tests/dew/expected/$PLATFORM/)"

# DEW EQ3/EQ6 R110/R100 write null bytes into timing fields (uninitialized
# Fortran CHARACTER buffers).  Strip timing lines using -a to force text mode.
strip_dew_timing() {
    grep -av \
        -e '^          start time = ' \
        -e '^            end time = ' \
        -e '^          user time = ' \
        -e '^           cpu time = ' \
        "$1"
}

run_case() {
    local exe="$1"       # eq3 or eq6
    local dataset="$2"   # psat | 10kbar | upstream
    local input="$3"     # path to input file
    local outfile="$4"   # destination .out reference file

    local tmpdir
    tmpdir=$(mktemp -d)
    cp "$DEW_CACHE/$dataset/data1" "$tmpdir/data1"
    cp "$DEW_CACHE/$dataset/data2" "$tmpdir/data2"
    cp "$DEW_CACHE/$dataset/data3" "$tmpdir/data3"
    cp "$input" "$tmpdir/input"
    (cd "$tmpdir" && "$BIN_DEW/$exe" > run.log 2>&1) || {
        echo "  FAILED (exe error): $exe on $(basename "$input")" >&2
        cat "$tmpdir/run.log" >&2
        rm -rf "$tmpdir"
        return 1
    }
    # DEW EQ3 ends with "normal exit"; DEW EQ6 ends with "no further input found"
    # after printing "average value of delzi" (no "normal exit" in R100).
    if grep -qa "normal exit" "$tmpdir/output" 2>/dev/null; then
        : # normal EQ3 termination
    elif grep -qa "average value of delzi" "$tmpdir/output" 2>/dev/null; then
        : # normal EQ6 termination (R100 style)
    else
        echo "  WARNING: no normal termination — $(basename "$input") (non-converging, still writing reference)" >&2
    fi
    mkdir -p "$(dirname "$outfile")"
    strip_dew_timing "$tmpdir/output" > "$outfile"
    rm -rf "$tmpdir"
}

echo ""
echo "==> EQ3 cases (psat dataset) ..."
for case in surface_seawater calcite_25c calcite_solid_soln co2_h2o; do
    echo "    $case"
    run_case eq3 psat "$DEW_INPUTS/$case/input" "$EXPECTED/$case.out"
done

echo ""
echo "==> EQ3 cases (10kbar dataset) ..."
for case in co2_650c_10kbar pelitic_550c_10kbar; do
    echo "    $case"
    run_case eq3 10kbar "$DEW_INPUTS/$case/input" "$EXPECTED/$case.out"
done

echo ""
echo "==> EQ6 cases ..."
echo "    pelitic_10kbar_eq6"
run_case eq6 10kbar "$DEW_INPUTS/pelitic_10kbar_eq6/input" "$EXPECTED/pelitic_10kbar_eq6.out"
echo "    mor_hydrothermal"
run_case eq6 upstream "$DEW_INPUTS/mor_hydrothermal/input" "$EXPECTED/mor_hydrothermal.out"

echo ""
echo "==> Done. Commit tests/dew/expected/$PLATFORM/."
