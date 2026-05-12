#!/usr/bin/env bats
# Smoke tests for the native DEW variant (bin-dew/).
# Skipped automatically when bin-dew/ has not been built.

load '../../../lib/helpers'

setup() {
    if [ ! -d "$BIN_DEW" ]; then
        skip "DEW variant not built (run 'make fetch-dew && make build-dew' first)"
    fi
}

@test "dew eqpt: binary exists and is executable" {
    [ -x "$BIN_DEW/eqpt" ]
}

@test "dew eqpt: produces version identifier" {
    run "$BIN_DEW/eqpt" </dev/null
    [[ "$output" == *"EQPT, version 3245R71"* ]]
}

@test "dew eqpt: links against DEW eqlib (R136)" {
    run "$BIN_DEW/eqpt" </dev/null
    [[ "$output" == *"EQLIB, version 3245R136"* ]]
}

@test "dew eq3: binary exists and is executable" {
    [ -x "$BIN_DEW/eq3" ]
}

@test "dew eq3: runs and calls into eqlib (requires data1)" {
    run "$BIN_DEW/eq3" </dev/null
    [[ "$output" == *"eqlib/openin"* ]]
}

@test "dew eq6: binary exists and is executable" {
    [ -x "$BIN_DEW/eq6" ]
}

@test "dew eq6: runs and calls into eqlib (requires data1)" {
    run "$BIN_DEW/eq6" </dev/null
    [[ "$output" == *"eqlib/openin"* ]]
}

@test "dew supcrt: binary exists and is executable" {
    [ -x "$BIN_DEW/supcrt" ]
}

@test "dew supcrt: produces SUPCRT92 version identifier" {
    run "$BIN_DEW/supcrt" </dev/null
    [[ "$output" == *"SUPCRT92 Version 1.1"* ]]
}

@test "dew cprons92: binary exists and is executable" {
    [ -x "$BIN_DEW/cprons92" ]
}

@test "dew cprons92: produces CPRONS92 version identifier" {
    run "$BIN_DEW/cprons92" </dev/null
    [[ "$output" == *"CPRONS92 Version 1.0"* ]]
}
