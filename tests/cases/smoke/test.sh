#!/usr/bin/env bash
# Smoke test: all five executables are present, run without crashing, and
# produce identifying output.
#
# The version header (8.0a) is only printed after the input file is opened;
# it does not appear on a no-args invocation.  Instead we check for the
# program-specific identifier string that appears in the startup error.
source "$(dirname "$0")/../../lib/helpers.sh"

# Each entry: "executable  expected_string_in_output"
declare -A CHECKS=(
    [eq3nr]="EQLIBU/openin"
    [eq6]="EQLIBU/openin"
    [eqpt]="EQLIBU/openin"
    [xcon3]="XCON3/xcon3"
    [xcon6]="XCON6/xcon6"
)

for exe in eq3nr eq6 eqpt xcon3 xcon6; do
    exe_path="$BIN/$exe"
    if [ ! -x "$exe_path" ]; then
        fail "$exe" "executable not found at $exe_path"
        continue
    fi
    output="$("$exe_path" 2>&1 || true)"
    expected="${CHECKS[$exe]}"
    if echo "$output" | grep -q "$expected"; then
        pass "$exe startup output"
    else
        fail "$exe startup output" "expected '$expected' not found"
    fi
done

end_test
