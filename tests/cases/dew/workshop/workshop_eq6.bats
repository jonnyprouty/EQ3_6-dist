#!/usr/bin/env bats
# DEW workshop EQ6 test cases.
# Sources: DEW/10_kbar_300-650c.zip (pelitic fluid)
#          upstream-dew/EQ6/input (MOR hydrothermal, canonical upstream example)
# Presentations: tuesday1_hipt_calculations.pptx, wednesday1_eq6.pptx
#
# Requires: make extract-dew-workshop (builds tests/.dew_data_cache/ and tests/dew/inputs/)

load '../../../lib/helpers'

DEW_CACHE="$REPO_ROOT/tests/.dew_data_cache"
DEW_INPUTS="$REPO_ROOT/tests/dew/inputs"

setup() {
    if [ ! -d "$BIN_DEW" ]; then
        skip "DEW variant not built (run 'make fetch-dew && make build-dew' first)"
    fi
    if [ ! -f "$DEW_CACHE/10kbar/data1" ]; then
        skip "DEW data cache missing (run 'make extract-dew-workshop' first)"
    fi
    setup_workdir
}

teardown() { teardown_workdir; }

@test "dew/pelitic_10kbar_eq6: eq6 normal exit and output matches reference (10kbar, pelitic fluid)" {
    stage_dew_data "$WORKDIR" 10kbar
    run_eq6_dew "$WORKDIR" "$DEW_INPUTS/pelitic_10kbar_eq6/input"
    assert_match_dew "average value of delzi" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "pelitic_10kbar_eq6.out"
}

@test "dew/mor_hydrothermal: eq6 normal exit and output matches reference (upstream, MOR hydrothermal)" {
    stage_dew_data "$WORKDIR" upstream
    run_eq6_dew "$WORKDIR" "$DEW_INPUTS/mor_hydrothermal/input"
    assert_match_dew "average value of delzi" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "mor_hydrothermal.out"
}
