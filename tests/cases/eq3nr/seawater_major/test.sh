#!/usr/bin/env bash
# EQ3NR: seawater major-ion speciation at 25°C using the B-dot equation.
# Source: 3tlib_cmp/swmaj.3i from the upstream test library.
# Expected: calcite supersaturation ~0.650, Normal exit.
source "$(dirname "$0")/../../../lib/helpers.sh"

setup_workdir
stage_data1 "$WORKDIR"
run_eq3nr "$WORKDIR" "$(dirname "$0")/input"

assert_match "Normal exit"  "$WORKDIR/output"
assert_match "Calcite"      "$WORKDIR/output" "calcite appears in mineral saturation table"
assert_match "0.57"         "$WORKDIR/output" "calcite saturation index ~0.57 (YMP database)"
assert_match "8.22"         "$WORKDIR/output" "input pH 8.22 echoed"
assert_no_match "STOP"      "$WORKDIR/run.log" "no fatal STOP"

end_test
