#!/usr/bin/env bats
# EQ6: microcline dissolution in pH 4 HCl — reaction path modeling.
# Source: 6tlib_cmp/micro.6i from the upstream test library.
# Expected: gibbsite, kaolinite, muscovite precipitate in sequence; Normal exit.

load '../../../lib/helpers'

setup() {
    setup_workdir
    stage_data1 "$WORKDIR"
}

teardown() {
    teardown_workdir
}

@test "microcline: secondary minerals precipitate, normal exit, no STOP" {
    run_eq6 "$WORKDIR" "$BATS_TEST_DIRNAME/input"
    assert_match "Normal exit" "$WORKDIR/output"
    assert_match "Gibbsite"    "$WORKDIR/output" "gibbsite precipitates"
    assert_match "Kaolinite"   "$WORKDIR/output" "kaolinite precipitates"
    assert_match "Muscovite"   "$WORKDIR/output" "muscovite precipitates"
    assert_no_match "STOP"     "$WORKDIR/run.log" "no fatal STOP"
}
