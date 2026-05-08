#!/usr/bin/env bash
# EQ6: microcline dissolution in pH 4 HCl — reaction path modeling.
# Source: 6tlib_cmp/micro.6i from the upstream test library.
# Expected: gibbsite, kaolinite, muscovite precipitate in sequence; Normal exit.
source "$(dirname "$0")/../../../lib/helpers.sh"

setup_workdir
stage_data1 "$WORKDIR"
run_eq6 "$WORKDIR" "$(dirname "$0")/input"

assert_match "Normal exit"  "$WORKDIR/output"
assert_match "Gibbsite"     "$WORKDIR/output" "gibbsite precipitates"
assert_match "Kaolinite"    "$WORKDIR/output" "kaolinite precipitates"
assert_match "Muscovite"    "$WORKDIR/output" "muscovite precipitates"
assert_no_match "STOP"      "$WORKDIR/run.log" "no fatal STOP"

end_test
