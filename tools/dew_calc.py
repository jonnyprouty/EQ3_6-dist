#!/usr/bin/env python3
"""
Run a DEW aqueous speciation calculation via pyDEW and print results.

Usage (inside the pyDEW container):
    python dew_calc.py --temp <C> --pressure <bar> [SPECIES=molality ...] [options]

Examples:
    python dew_calc.py --temp 500 --pressure 10000 NA+=0.1 CL-=0.1
    python dew_calc.py --temp 300 --pressure 5000 CA+2=0.01 SO4-2=0.01 --outdir /out

Arguments:
    --temp        Temperature in °C (300–1000)
    --pressure    Pressure in bar (e.g. 10000 for 10 kbar)
    SPECIES=mol   Basis species molalities (e.g. NA+=0.1); repeatable
    --ph          Fix pH instead of computing by charge balance
    --uebal       Charge-balance species when pH is fixed (default: NA+)
    --outdir      Directory to copy EQ3 input/output files into
    --json        Print results as JSON instead of plain text
"""
import argparse
import json
import os
import shutil
import sys
import warnings

warnings.filterwarnings("ignore")

import pyDEW


def parse_args():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--temp", type=float, required=True)
    p.add_argument("--pressure", type=float, required=True)
    p.add_argument("--ph", type=float, default=None)
    p.add_argument("--uebal", default="NA+")
    p.add_argument("--outdir", default=None)
    p.add_argument("--json", action="store_true")
    p.add_argument("--help", "-h", action="store_true")
    p.add_argument("species", nargs="*")
    return p.parse_args()


def main():
    args = parse_args()

    if args.help:
        print(__doc__)
        sys.exit(0)

    T_K = args.temp + 273.15
    P = args.pressure

    if not (573.15 <= T_K <= 1273.15):
        sys.exit(f"ERROR: --temp must be between 300 and 1000 °C (got {args.temp})")
    if P <= 0:
        sys.exit(f"ERROR: --pressure must be positive (got {P})")

    molalities = {}
    for s in args.species:
        if "=" not in s:
            sys.exit(f"ERROR: species argument must be SPECIES=molality, got: {s!r}")
        name, val = s.split("=", 1)
        try:
            molalities[name] = float(val)
        except ValueError:
            sys.exit(f"ERROR: molality for {name!r} is not a number: {val!r}")

    dew = pyDEW.System()

    kwargs = dict(molalities=molalities) if molalities else {}
    if args.ph is not None:
        kwargs["pH"] = args.ph
        kwargs["uebal"] = args.uebal

    fluid = pyDEW.Fluid(dew, T_K, P, **kwargs)

    if args.outdir:
        os.makedirs(args.outdir, exist_ok=True)
        # pyDEW writes EQ3 working files to a 'working/' subdirectory in CWD
        src_dir = "working"
        for fname in ("input", "output", "data0", "data1", "data2", "slist"):
            src = os.path.join(src_dir, fname)
            if os.path.exists(src):
                shutil.copy(src, os.path.join(args.outdir, fname))

    if args.json:
        result = {
            "temperature_C": args.temp,
            "pressure_bar": P,
            "pH": float(fluid.pH),
            "fO2": float(fluid.fO2),
            "aqueous_species": fluid.aqueous_species.to_dict(orient="records"),
        }
        print(json.dumps(result, indent=2))
    else:
        print(f"T = {args.temp} °C,  P = {P:.0f} bar ({P/1000:.1f} kbar)")
        print(f"pH = {float(fluid.pH):.4f},  log fO2 = {float(fluid.fO2):.4f}")
        print()
        print(fluid.aqueous_species.sort_values("molality", ascending=False)
              .to_string(index=False))


if __name__ == "__main__":
    main()
