#!/usr/bin/env bats
# EQ3NR: seawater major-ion speciation at 25°C using the B-dot equation.
# Source: 3tlib_cmp/swmaj.3i from the upstream test library.
# Expected: calcite supersaturation ~0.57, Normal exit.

load '../../../lib/helpers'

setup() {
    setup_workdir
    stage_data1 "$WORKDIR"
}

teardown() {
    teardown_workdir
}

@test "seawater_major: normal exit, calcite saturation, no STOP" {
    run_eq3nr "$WORKDIR" "$BATS_TEST_DIRNAME/input"
    assert_match "Normal exit" "$WORKDIR/output"
    assert_match "Calcite"     "$WORKDIR/output" "calcite appears in mineral saturation table"
    assert_match "0.57"        "$WORKDIR/output" "calcite saturation index ~0.57"
    assert_match "8.22"        "$WORKDIR/output" "input pH 8.22 echoed"
    assert_no_match "STOP"     "$WORKDIR/run.log" "no fatal STOP"
}
