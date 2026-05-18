#!/usr/bin/env bats
# DEW workshop EQ3 test cases.
# Sources: DEW/psat_data0___examples_from_enki.zip (psat dataset)
#          DEW/10_kbar_300-650c.zip (10kbar dataset)
# Presentations: monday1_eq___non-eq_models_class.pptx, tuesday1_hipt_calculations.pptx,
#                tuesday3_eq3.pptx, introduction.pptx
#
# Requires: make extract-dew-workshop (builds tests/.dew_data_cache/ and tests/dew/inputs/)

load '../../../lib/helpers'

DEW_CACHE="$REPO_ROOT/tests/.dew_data_cache"
DEW_INPUTS="$REPO_ROOT/tests/dew/inputs"

setup() {
    if [ ! -d "$BIN_DEW" ]; then
        skip "DEW variant not built (run 'make fetch-dew && make build-dew' first)"
    fi
    if [ ! -f "$DEW_CACHE/psat/data1" ]; then
        skip "DEW data cache missing (run 'make extract-dew-workshop' first)"
    fi
    setup_workdir
}

teardown() { teardown_workdir; }

# ---------------------------------------------------------------------------
# psat dataset — surface / near-surface conditions

@test "dew/surface_seawater: eq3 output matches reference (psat, 25°C)" {
    stage_dew_data "$WORKDIR" psat
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/surface_seawater/input"
    assert_dew_output_matches_ref "$WORKDIR/output" "surface_seawater.out"
}

@test "dew/calcite_25c: eq3 normal exit and output matches reference (psat, 25°C)" {
    stage_dew_data "$WORKDIR" psat
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/calcite_25c/input"
    assert_match_dew "normal exit" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "calcite_25c.out"
}

@test "dew/calcite_solid_soln: eq3 output matches reference (psat, 25°C, solid solution)" {
    stage_dew_data "$WORKDIR" psat
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/calcite_solid_soln/input"
    assert_dew_output_matches_ref "$WORKDIR/output" "calcite_solid_soln.out"
}

@test "dew/co2_h2o: eq3 normal exit and output matches reference (psat, 25°C, CO2-H2O)" {
    stage_dew_data "$WORKDIR" psat
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/co2_h2o/input"
    assert_match_dew "normal exit" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "co2_h2o.out"
}

# ---------------------------------------------------------------------------
# 10kbar dataset — high P-T conditions (tuesday1_hipt_calculations.pptx)

@test "dew/co2_650c_10kbar: eq3 normal exit and output matches reference (10kbar, 650°C)" {
    stage_dew_data "$WORKDIR" 10kbar
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/co2_650c_10kbar/input"
    assert_match_dew "normal exit" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "co2_650c_10kbar.out"
}

@test "dew/pelitic_550c_10kbar: eq3 normal exit and output matches reference (10kbar, 550°C)" {
    stage_dew_data "$WORKDIR" 10kbar
    run_eq3_dew "$WORKDIR" "$DEW_INPUTS/pelitic_550c_10kbar/input"
    assert_match_dew "normal exit" "$WORKDIR/output"
    assert_dew_output_matches_ref "$WORKDIR/output" "pelitic_550c_10kbar.out"
}
