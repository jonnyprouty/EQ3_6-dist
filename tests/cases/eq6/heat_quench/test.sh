#!/usr/bin/env bash
# EQ6: heat a quenched fluid from 25°C to 150°C to find the in situ pH.
# Source: 6tlib_cmp/heatqf.6i from the upstream test library.
# Expected: run reaches 150°C, Normal exit.
source "$(dirname "$0")/../../../lib/helpers.sh"

setup_workdir
stage_data1 "$WORKDIR"
run_eq6 "$WORKDIR" "$(dirname "$0")/input"

assert_match "Normal exit"        "$WORKDIR/output"
assert_match "Temperature=   150" "$WORKDIR/output" "run reaches 150°C"
assert_no_match "STOP"            "$WORKDIR/run.log" "no fatal STOP"

end_test
