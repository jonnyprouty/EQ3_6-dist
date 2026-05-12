#!/usr/bin/env bash
# Run the DEW-distributed EQPT binary to compile a DEW DATA0 into data1/data2.
#
# Usage: run_dew_eqpt.sh <dew-eqpt-dir> [output-dir]
#
# <dew-eqpt-dir>  Path to an extracted DEW EQPT directory containing:
#                   EQPT     - the DEW EQPT binary (ARM64 macOS)
#                   DATA0    - the DEW thermodynamic database (old R71 format)
#                   slist    - species list file
#                   data0s   - combined data file
# [output-dir]    Where to copy the resulting data1/data2/output.
#                 Defaults to the current directory.
#
# The DEW EQPT binary requires three interactive prompts answered n/n/y:
#   1. Use Pitzer ion-interaction parameters? → n
#   2. Use HKF equation of state parameters? → n
#   3. Use data0s?                           → y
#
# Architecture note: DEW EQPT binaries distributed with the kbar P-T cases
# (e.g. 10_kbar_300-650c) are ARM64 Mach-O binaries compiled for Apple Silicon.
# They will NOT run on Intel Macs or Linux. If you need to re-run EQPT on an
# Intel Mac or Linux system, use pyDEW to generate a v8.0a-compatible DATA0 and
# process it with our gfortran-compiled eqpt.

set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }

if [ $# -lt 1 ]; then
    echo "Usage: $(basename "$0") <dew-eqpt-dir> [output-dir]" >&2
    exit 1
fi

SRC_DIR="$(cd "$1" && pwd)"
OUT_DIR="${2:-.}"
OUT_DIR="$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)"

# Validate required files
[ -f "$SRC_DIR/EQPT" ] || die "EQPT binary not found in $SRC_DIR"
[ -f "$SRC_DIR/DATA0" ] || [ -f "$SRC_DIR/data0" ] || die "DATA0/data0 not found in $SRC_DIR"
[ -f "$SRC_DIR/slist" ] || die "slist not found in $SRC_DIR"
[ -f "$SRC_DIR/data0s" ] || die "data0s not found in $SRC_DIR"

# Architecture check
EQPT_ARCH=""
if command -v file >/dev/null 2>&1; then
    EQPT_ARCH="$(file "$SRC_DIR/EQPT" 2>/dev/null || true)"
fi
HOST_ARCH="$(uname -m)"

if echo "$EQPT_ARCH" | grep -qi "arm64\|aarch64"; then
    if [ "$HOST_ARCH" != "arm64" ] && [ "$HOST_ARCH" != "aarch64" ]; then
        warn "EQPT binary is ARM64 (Apple Silicon) but this host is $HOST_ARCH."
        warn "This binary cannot run on Intel Macs or Linux."
        warn "On Intel Mac/Linux, use pyDEW to generate a v8.0a DATA0 and run our eqpt instead."
        exit 1
    fi
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

cp "$SRC_DIR/EQPT"  "$WORKDIR/EQPT"
cp "$SRC_DIR/slist" "$WORKDIR/slist"
cp "$SRC_DIR/data0s" "$WORKDIR/data0s"

# Normalize DATA0 → data0 (Linux is case-sensitive; the binary expects lowercase)
if [ -f "$SRC_DIR/data0" ]; then
    cp "$SRC_DIR/data0" "$WORKDIR/data0"
else
    cp "$SRC_DIR/DATA0" "$WORKDIR/data0"
fi

chmod +x "$WORKDIR/EQPT"

echo "Running DEW EQPT in $WORKDIR ..."
( cd "$WORKDIR" && printf "n\nn\ny\n" | ./EQPT ) || die "EQPT exited with error"

for f in data1 data2 output; do
    if [ -f "$WORKDIR/$f" ]; then
        cp "$WORKDIR/$f" "$OUT_DIR/$f"
        echo "  wrote $OUT_DIR/$f"
    else
        warn "$f not produced by EQPT run"
    fi
done

echo "Done."
