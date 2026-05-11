#!/usr/bin/env bats
# EQ6: heat a quenched fluid from 25°C to 150°C to find the in situ pH.
# Source: 6tlib_cmp/heatqf.6i from the upstream test library.
# Expected: run reaches 150°C, Normal exit.

load '../../../lib/helpers'

setup() {
    setup_workdir
    stage_data1 "$WORKDIR"
}

teardown() {
    teardown_workdir
}

@test "heat_quench: reaches 150°C, normal exit, no STOP" {
    run_eq6 "$WORKDIR" "$BATS_TEST_DIRNAME/input"
    assert_match "Normal exit"        "$WORKDIR/output"
    assert_match "Temperature=   150" "$WORKDIR/output" "run reaches 150°C"
    assert_no_match "STOP"            "$WORKDIR/run.log" "no fatal STOP"
}
