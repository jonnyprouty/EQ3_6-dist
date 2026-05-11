#!/usr/bin/env bats
# Smoke test: all five executables are present, run without crashing, and
# produce identifying output.
#
# The version header (8.0a) is only printed after the input file is opened;
# it does not appear on a no-args invocation. We check the program-specific
# identifier string that appears in the startup error instead.

load '../../lib/helpers'

@test "eq3nr produces startup identifier" {
    out="$("$BIN/eq3nr" 2>&1 || true)"
    [[ $out == *"EQLIBU/openin"* ]]
}

@test "eq6 produces startup identifier" {
    out="$("$BIN/eq6" 2>&1 || true)"
    [[ $out == *"EQLIBU/openin"* ]]
}

@test "eqpt produces startup identifier" {
    out="$("$BIN/eqpt" 2>&1 || true)"
    [[ $out == *"EQLIBU/openin"* ]]
}

@test "xcon3 produces startup identifier" {
    out="$("$BIN/xcon3" 2>&1 || true)"
    [[ $out == *"XCON3/xcon3"* ]]
}

@test "xcon6 produces startup identifier" {
    out="$("$BIN/xcon6" 2>&1 || true)"
    [[ $out == *"XCON6/xcon6"* ]]
}
