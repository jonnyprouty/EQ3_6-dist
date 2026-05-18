#!/usr/bin/env bash
# Compare DEW workshop test outputs from the pyDEW container against the
# committed native bin-dew/ references.
#
# Usage:
#   tools/compare_dew_container.sh [--runs N] [--regen]
#
#   --runs N    Run each case N times to verify determinism (default: 3)
#   --regen     Write container outputs to tests/dew/expected/container/ and exit
#               (use this to generate or update the committed container refs)
#
# Requirements:
#   podman (preferred) or docker
#   DEW/psat_data0___examples_from_enki.zip
#   DEW/10_kbar_300-650c.zip
#
# The container used is simonwmatthews/pydew:v2.15.  It bundles x86-64 Linux
# R71 EQ3/EQ6 binaries that are a different code base from the native DEW
# variant (R110/R100) built by 'make build-dew'.  Its data1 binary format uses
# 8-byte Fortran record-length markers vs. the 4-byte markers from our gfortran
# build, so the two stacks cannot share data1 files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEW_INPUTS="$REPO_ROOT/tests/dew/inputs"
CONTAINER_CACHE="$REPO_ROOT/tests/.dew_data_cache/container"
EXPECTED_CONTAINER="$REPO_ROOT/tests/dew/expected/container"
EXPECTED_LINUX="$REPO_ROOT/tests/dew/expected/linux"
IMAGE="simonwmatthews/pydew:v2.15"
RUNS=3
REGEN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --runs)  RUNS="$2"; shift 2 ;;
        --regen) REGEN=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Container runtime

if command -v podman &>/dev/null; then
    RUNTIME=podman
elif command -v docker &>/dev/null; then
    RUNTIME=docker
else
    echo "error: neither podman nor docker found in PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# DEW ZIPs

DEW_PSAT_ZIP="$REPO_ROOT/DEW/psat_data0___examples_from_enki.zip"
DEW_10KBAR_ZIP="$REPO_ROOT/DEW/10_kbar_300-650c.zip"
DEW_UPSTREAM_DATA0="$REPO_ROOT/upstream-dew/EQPT/DATA0"

for f in "$DEW_PSAT_ZIP" "$DEW_10KBAR_ZIP" "$DEW_UPSTREAM_DATA0"; do
    if [ ! -f "$f" ]; then
        echo "error: required file not found: $f" >&2
        echo "       Run 'make fetch-dew' for upstream-dew, and ensure DEW/*.zip files are present." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Helpers

# Make a temp directory accessible to the container.
# The container runs as jovyan (uid ~525287 on the host side), so the directory
# must be world-writable.  :z (shared SELinux relabeling) is required on Fedora.
make_shared_tmpdir() {
    local d; d=$(mktemp -d)
    chmod 777 "$d"
    echo "$d"
}

container_vol() {
    # Emit the correct volume flag for the runtime.
    # podman on SELinux hosts needs :z to relabel the mount.
    local host_path="$1" container_path="$2"
    if [ "$RUNTIME" = "podman" ]; then
        echo "-v ${host_path}:${container_path}:z"
    else
        echo "-v ${host_path}:${container_path}"
    fi
}

run_in_container() {
    # Run a bash command inside the container with one host→container volume mount.
    local hostdir="$1" containerdir="$2" cmd="$3"
    local vflag; vflag=$(container_vol "$hostdir" "$containerdir")
    # shellcheck disable=SC2086
    $RUNTIME run --rm $vflag "$IMAGE" bash -c "$cmd" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Normalize: strip timing/run lines and null bytes for cross-stack comparison.
#
# The ' Run ...' line contains wall-clock timestamps (null bytes in the
# container build, spaces in our -finit-character=32 build).
# CHARACTER variable padding (species names, etc.) also differs: null bytes
# in the container vs. spaces in our build.  tr -d strips nulls so that
# diff sees only meaningful content differences.

normalize() {
    grep -av \
        -e '^ Run ' \
        -e '^          start time = ' \
        -e '^            end time = ' \
        -e '^          user time = ' \
        -e '^           cpu time = ' \
        "$1" 2>/dev/null | tr -d '\000'
}

# ---------------------------------------------------------------------------
# Build container data1 caches

build_container_cache() {
    local dataset="$1"   # psat | 10kbar | upstream
    local cache_dir="$CONTAINER_CACHE/$dataset"

    if [ -f "$cache_dir/data1" ]; then
        return 0
    fi

    echo "==> Building container data1 cache: $dataset ..."
    mkdir -p "$cache_dir"

    local tmpdir; tmpdir=$(make_shared_tmpdir)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" RETURN

    local eqpt_stdin
    case "$dataset" in
        psat)
            unzip -p "$DEW_PSAT_ZIP" \
                "Psat data0 & examples from ENKI/EQPTrun/DATA0" > "$tmpdir/data0"
            unzip -p "$DEW_PSAT_ZIP" \
                "Psat data0 & examples from ENKI/EQPTrun/data0s" > "$tmpdir/data0s"
            eqpt_stdin="n\nn\ny\n"
            ;;
        10kbar)
            unzip -p "$DEW_10KBAR_ZIP" \
                "10 kbar 300-650C/EQPT/DATA0" > "$tmpdir/data0"
            unzip -p "$DEW_10KBAR_ZIP" \
                "10 kbar 300-650C/EQPT/data0s" > "$tmpdir/data0s"
            eqpt_stdin="n\nn\ny\n"
            ;;
        upstream)
            cp "$DEW_UPSTREAM_DATA0" "$tmpdir/data0"
            eqpt_stdin="n\nn\nn\n"
            ;;
    esac

    run_in_container "$tmpdir" "/work" \
        "cd /work && printf '${eqpt_stdin}' | eqpt >/dev/null 2>&1" || true

    if [ ! -f "$tmpdir/data1" ]; then
        # Run again with visible output for diagnosis
        run_in_container "$tmpdir" "/work" \
            "cd /work && printf '${eqpt_stdin}' | eqpt 2>&1 | tail -5" >&2 || true
        echo "error: container eqpt did not produce data1 for $dataset" >&2
        exit 1
    fi

    cp "$tmpdir/data1" "$cache_dir/data1"
    [ -f "$tmpdir/data2" ] && cp "$tmpdir/data2" "$cache_dir/data2" || true
    [ -f "$tmpdir/data3" ] && cp "$tmpdir/data3" "$cache_dir/data3" || true
    echo "    done ($(ls -lh "$cache_dir/data1" | awk '{print $5}'))"
}

# ---------------------------------------------------------------------------
# Run one case through the container

run_case_container() {
    local exe="$1"     # eq3 | eq6
    local dataset="$2" # psat | 10kbar | upstream
    local input="$3"   # absolute path to input file
    local outfile="$4" # where to write normalized output

    local cache_dir="$CONTAINER_CACHE/$dataset"
    local tmpdir; tmpdir=$(make_shared_tmpdir)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" RETURN

    cp "$cache_dir/data1" "$tmpdir/data1"
    [ -f "$cache_dir/data2" ] && cp "$cache_dir/data2" "$tmpdir/data2" || true
    [ -f "$cache_dir/data3" ] && cp "$cache_dir/data3" "$tmpdir/data3" || true
    cp "$input" "$tmpdir/input"

    run_in_container "$tmpdir" "/work" \
        "cd /work && $exe >/dev/null 2>&1" || true

    if [ -f "$tmpdir/output" ]; then
        normalize "$tmpdir/output" > "$outfile"
    else
        echo "(no output produced)" > "$outfile"
    fi
}

# ---------------------------------------------------------------------------
# Test cases

CASES_EXE=(     eq3              eq3          eq3                  eq3      eq3              eq3                  eq6               eq6            )
CASES_DATASET=( psat             psat         psat                 psat     10kbar           10kbar               10kbar            upstream       )
CASES_NAME=(    surface_seawater calcite_25c  calcite_solid_soln   co2_h2o  co2_650c_10kbar  pelitic_550c_10kbar  pelitic_10kbar_eq6 mor_hydrothermal )

# ---------------------------------------------------------------------------
# Main

build_container_cache psat
build_container_cache 10kbar
build_container_cache upstream

if [ "$REGEN" -eq 1 ]; then
    echo ""
    echo "==> Regenerating container reference outputs ..."
    mkdir -p "$EXPECTED_CONTAINER"
    for i in "${!CASES_NAME[@]}"; do
        local_name="${CASES_NAME[$i]}"
        echo "    ${CASES_EXE[$i]}  $local_name"
        run_case_container \
            "${CASES_EXE[$i]}" \
            "${CASES_DATASET[$i]}" \
            "$DEW_INPUTS/$local_name/input" \
            "$EXPECTED_CONTAINER/$local_name.out"
    done
    echo ""
    echo "==> Done. Commit tests/dew/expected/container/."
    exit 0
fi

# ---------------------------------------------------------------------------
# Comparison run

echo ""
echo "==> pyDEW container ($IMAGE) vs native bin-dew/ (linux refs)"
echo "    Runs per case: $RUNS"
echo ""

PASS=0
FAIL=0
NONDETERMINISTIC=0

printf "%-30s  %-10s  %s\n" "Case" "Det." "vs ref"
printf "%-30s  %-10s  %s\n" "-----" "-----" "-----"

tmpbase=$(mktemp -d)
trap 'rm -rf "$tmpbase"' EXIT

for i in "${!CASES_NAME[@]}"; do
    name="${CASES_NAME[$i]}"
    exe="${CASES_EXE[$i]}"
    dataset="${CASES_DATASET[$i]}"
    input="$DEW_INPUTS/$name/input"

    # Run RUNS times
    det="pass"
    for r in $(seq 1 "$RUNS"); do
        run_case_container "$exe" "$dataset" "$input" "$tmpbase/${name}_run${r}.txt"
    done

    # Check determinism: all runs identical?
    for r in $(seq 2 "$RUNS"); do
        if ! diff -q "$tmpbase/${name}_run1.txt" "$tmpbase/${name}_run${r}.txt" >/dev/null 2>&1; then
            det="FAIL(r$r)"
            NONDETERMINISTIC=$((NONDETERMINISTIC + 1))
            break
        fi
    done

    # Always compare against linux (native Fedora) refs to show stack divergence.
    # Also note if a committed container ref exists and whether current output
    # matches it (detects container version changes).
    local_linux_ref="$EXPECTED_LINUX/$name.out"
    local_container_ref="$EXPECTED_CONTAINER/$name.out"

    if diff -q "$tmpbase/${name}_run1.txt" <(normalize "$local_linux_ref") >/dev/null 2>&1; then
        vs_ref="identical to linux"
        PASS=$((PASS + 1))
    else
        ndiff=$(diff "$tmpbase/${name}_run1.txt" <(normalize "$local_linux_ref") 2>/dev/null \
            | grep -c '^[<>]' || true)
        vs_ref="$ndiff changed lines vs linux"
        # If a container ref exists, check whether current output matches it
        if [ -f "$local_container_ref" ]; then
            if diff -q "$tmpbase/${name}_run1.txt" <(normalize "$local_container_ref") >/dev/null 2>&1; then
                vs_ref="$vs_ref (matches committed container ref)"
            else
                vs_ref="$vs_ref (DIFFERS from committed container ref — container updated?)"
            fi
        fi
        FAIL=$((FAIL + 1))
    fi

    printf "%-30s  %-10s  %s\n" "$name" "$det" "$vs_ref"
done

echo ""
echo "==> Results: $PASS identical, $FAIL differ, $NONDETERMINISTIC non-deterministic (of ${#CASES_NAME[@]} cases)"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "==> Diffs (container vs linux native) ..."
    for i in "${!CASES_NAME[@]}"; do
        name="${CASES_NAME[$i]}"
        ref="$EXPECTED_LINUX/$name.out"
        if ! diff -q "$tmpbase/${name}_run1.txt" <(normalize "$ref") >/dev/null 2>&1; then
            echo ""
            echo "  --- $name ---"
            diff "$tmpbase/${name}_run1.txt" <(normalize "$ref") | head -30 || true
        fi
    done
fi
