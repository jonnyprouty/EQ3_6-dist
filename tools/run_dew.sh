#!/usr/bin/env bash
# Run a DEW aqueous speciation calculation using the pyDEW container.
#
# Selects the container runtime automatically: prefers podman over docker;
# fails with a clear message if neither is found.
#
# Usage:
#   run_dew.sh --temp <C> --pressure <bar> [SPECIES=molality ...] [options]
#
# Examples:
#   run_dew.sh --temp 500 --pressure 10000 NA+=0.1 CL-=0.1
#   run_dew.sh --temp 300 --pressure 5000 CA+2=0.01 SO4-2=0.01 --outdir ./results
#   run_dew.sh --temp 700 --pressure 20000 FE+2=0.001 --json
#
# Options:
#   --temp        Temperature in °C (300–1000)
#   --pressure    Pressure in bar (e.g. 10000 for 10 kbar)
#   SPECIES=mol   Basis species molalities; repeatable
#   --ph          Fix pH instead of computing by charge balance
#   --uebal       Charge-balance species when --ph is set (default: NA+)
#   --outdir DIR  Write EQ3 input/output files to DIR on the host
#   --json        Print results as JSON
#
# Dependencies:
#   podman or docker with access to docker.io/simonwmatthews/pydew:v2.15
#
# Notes:
#   The pyDEW container uses the DEW-modified R71 EQPT and EQ3 binaries internally.
#   This workflow is independent of the v8.0a EQ3/6 binaries in this repo.

set -euo pipefail

PYDEW_IMAGE="docker.io/simonwmatthews/pydew:v2.15"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Container runtime detection: podman > docker > fail
if command -v podman >/dev/null 2>&1; then
    CONTAINER="podman"
elif command -v docker >/dev/null 2>&1; then
    CONTAINER="docker"
else
    echo "ERROR: neither podman nor docker found. Install one to use DEW calculations." >&2
    exit 1
fi

# Parse --outdir from args before forwarding the rest to dew_calc.py.
# All other arguments pass through unchanged.
OUTDIR=""
PASSTHROUGH=()
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    if [ "$arg" = "--outdir" ]; then
        i=$(( i + 1 ))
        OUTDIR="${!i}"
    else
        PASSTHROUGH+=("$arg")
    fi
    i=$(( i + 1 ))
done

VOLUME_ARGS=()
CONTAINER_OUTDIR=""
if [ -n "$OUTDIR" ]; then
    mkdir -p "$OUTDIR"
    OUTDIR="$(cd "$OUTDIR" && pwd)"
    # Rootless Podman maps the container user (jovyan, uid=1000) to a subuid on
    # the host, so the directory must be world-writable for the container to write.
    chmod 777 "$OUTDIR"
    VOLUME_ARGS+=(-v "${OUTDIR}:/dew_out:Z")
    CONTAINER_OUTDIR="--outdir /dew_out"
fi

# pyDEW's load_coder_modules() does os.chdir() and relies on sys.path[0]==''
# (i.e. CWD) to find dew2019.pyx via pyximport. Running a .py file sets
# sys.path[0] to the script's directory instead, breaking the import.
# Workaround: use -c to keep sys.path[0]=='', then set sys.argv and exec().
"$CONTAINER" run --rm \
    -v "${SCRIPT_DIR}/dew_calc.py:/dew_calc.py:ro,Z" \
    "${VOLUME_ARGS[@]}" \
    "$PYDEW_IMAGE" \
    python -c "import sys; sys.argv=sys.argv[1:]; exec(open(sys.argv[0]).read())" \
    /dew_calc.py "${PASSTHROUGH[@]}" $CONTAINER_OUTDIR
