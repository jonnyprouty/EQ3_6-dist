#!/usr/bin/env bats
# EQ3NR: oxygenated solution with calcite and hematite pinned at saturation.
# Source: 3tlib_cmp/oxcalhem.3i from the upstream test library.
# Expected: both minerals listed at or near SI=0, Normal exit.

load '../../../lib/helpers'

setup() {
    setup_workdir
    stage_data1 "$WORKDIR"
}

teardown() {
    teardown_workdir
}

@test "mineral_equilibrium: normal exit, calcite and hematite present, no STOP" {
    run_eq3nr "$WORKDIR" "$BATS_TEST_DIRNAME/input"
    assert_match "Normal exit" "$WORKDIR/output"
    assert_match "Calcite"     "$WORKDIR/output" "calcite present in output"
    assert_match "Hematite"    "$WORKDIR/output" "hematite present in output"
    assert_no_match "STOP"     "$WORKDIR/run.log" "no fatal STOP"
}
