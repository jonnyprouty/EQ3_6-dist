#!/usr/bin/env bats
# Verify that packaging build-time smoke checks stay valid against local binaries.
#
# Each test runs the actual check logic from the packaging file rather than
# duplicating the expected strings here. If a packaging script becomes stale
# (wrong pattern, broken logic) this test will catch it.

load '../../lib/helpers'

@test "RPM %check passes against local binaries" {
    local spec="$REPO_ROOT/pkg/rpm/eq3_6.spec"
    # Extract the %check body (everything between %check and the next %section)
    local script
    script="$(awk '/^%check/{f=1;next} f && /^%[a-zA-Z]/{f=0} f' "$spec")"
    # %check uses relative paths (bin/eq3nr), so run from REPO_ROOT
    (cd "$REPO_ROOT" && bash -euo pipefail -c "$script")
}

@test "Homebrew test do assertion holds against local eq3nr" {
    local formula="$REPO_ROOT/pkg/brew/eq3_6.rb"
    # Parse the expected string from the assert_match line in the test do block
    local pattern
    pattern="$(grep 'assert_match' "$formula" | sed 's/.*assert_match "\([^"]*\)".*/\1/')"
    [ -n "$pattern" ] || {
        echo "could not parse assert_match pattern from $formula" >&2
        return 1
    }
    local out
    out="$("$BIN/eq3nr" 2>&1 || true)"
    [[ $out == *"$pattern"* ]]
}
