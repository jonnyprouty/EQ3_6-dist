# Test suite documentation

## Overview

The test suite uses [bats-core](https://github.com/bats-core/bats-core). Install it with
`dnf install bats` / `apt install bats` / `brew install bats-core`, then run `make test`.

```
make test          # smoke tests + packaging checks + source validation
make test-testlib  # upstream test library (170 cases, requires make extract-testlib first)
```

`make test-testlib` is separate because it requires the upstream test library ZIP
(`upstream/EQ3_6v8.0a TestLibrary PC.zip`) and takes a few minutes to run. It does not
run as part of `make test` or the packaging-time `%check` / `dh_auto_test` checks.

---

## Testlib suite

The testlib cases come from `upstream/EQ3_6v8.0a TestLibrary PC.zip`, which is part of
the official EQ3/6 v8.0a distribution. Each case pairs an input file (`.3i` for EQ3NR,
`.6i` for EQ6) with a reference output committed to this repo.

### Libraries

| Library | Executable | Database | Cases | Notes |
|---|---|---|---|---|
| `3tlib_cmp` | eq3nr | data0.com | 41 | Standard comprehensive database |
| `6tlib_cmp` | eq6   | data0.com | 21 | Standard comprehensive database |
| `3tlib_fmt` | eq3nr | data0.fmt | 7  | Format/parsing edge cases |
| `6tlib_fmt` | eq6   | data0.fmt | 5  | Format/parsing edge cases |
| `3tlib_hmw` | eq3nr | data0.hmw | 9  | HMW/Pitzer activity model |
| `6tlib_hmw` | eq6   | data0.hmw | 7  | HMW/Pitzer activity model |
| `3tlib_ymp` | eq3nr | data0.ymp | 41 | Yucca Mountain Project database |
| `6tlib_ymp` | eq6   | data0.ymp | 21 | Yucca Mountain Project database |
| `3tlib_ypf` | eq3nr | data0.ypf | 7  | YMP Pitzer variant |
| `6tlib_ypf` | eq6   | data0.ypf | 2  | YMP Pitzer variant |
| `xchtlib`   | eq3nr + eq6 | data0.com | 9 (6+3) | Ion exchange cases |

**Total: 170 cases**

### Reference outputs and per-platform refs

Reference outputs live in `tests/testlib/expected/<platform>/`. Two platforms are
committed: `linux/` (generated on Fedora 43 with gfortran 15.2.1) and `mac/` (generated
on macOS 15 with Homebrew gfortran 15.2.0).

`assert_output_matches_ref` in `tests/lib/helpers.bash` resolves:
1. `tests/testlib/expected/<uname-s>-derived platform>/<lib>/<case>.out` if it exists
2. `tests/testlib/expected/linux/<lib>/<case>.out` as fallback

The platform tag is `linux` on Linux and `mac` on macOS (from `uname -s`). This gives
each platform an exact match rather than a toleranced comparison.

To regenerate refs for the current platform:
```bash
make extract-testlib       # extract inputs and compile data1 files
make regen-testlib-refs    # writes to tests/testlib/expected/<platform>/
# commit the results
```

---

### Why Linux and Mac produce different outputs

EQ3NR speciation calculations (algebraic equilibrium) are numerically stable; most cases
produce bit-identical output across platforms. EQ6 reaction-path calculations are
iterative: the code integrates a system of ODEs using a predictor-corrector method with
adaptive step-size control. Each step's outcome depends on whether intermediate
floating-point values cross the convergence threshold.

Because gfortran 15.2.1 (Red Hat, x86-64) and gfortran 15.2.0 (Homebrew, macOS x86-64)
produce slightly different rounding in extended-precision intermediate calculations, the
predictor-corrector sequences diverge after many steps. This is genuine numerical path
divergence, not just final-value rounding: two correct ODE solutions that follow different
paths through the adaptive step-size controller. For most short runs the difference is a
single ULP in a charge-balance diagnostic. For long reaction paths (mineral precipitation
sequences, titration runs) the difference can be in the step-size log.

The following cases have different Linux and Mac reference outputs. The "first difference"
column shows the first output line that differs between the two platforms.

#### Platform-divergent EQ6 cases (6tlib_cmp)

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `crisqtz` | H+ molality | 9.59577E-14 | 9.59688E-14 |
| `dedolo` | delxi (step size) | 1.7988E-06 | 1.7987E-06 |
| `heatswfl` | Charge discrepancy | -3.5118E-10 | -3.5117E-10 |
| `heatsw` | Antigorite saturation index | 0.00000 | -0.00000 |
| `j13wtitr` | Charge discrepancy | -6.5173E-16 | -6.5260E-16 |
| `j13wtuff` | Charge discrepancy | 1.8521E-15 | 1.8504E-15 |
| `methane` | Actual charge imbalance | 3.2046E-13 | 3.2047E-13 |
| `microft` | Actual charge imbalance | 2.1475E-15 | 2.1476E-15 |
| `micro` | Actual charge imbalance | 1.3553E-20 | 0.0000E+00 |
| `pptcal` | Charge discrepancy | 1.4215E-13 | 1.4216E-13 |
| `pptqtza` | delxi (step size) | 6.6800E-05 | 6.6799E-05 |
| `pptqtz` | Stoich. ionic asymmetry | 3.11285E-18 | 3.11115E-18 |
| `pyrsw` | Ca(Prop)+ molality | 1.9085E-44 | 1.9086E-44 |
| `rwssdiag` | Nontronite-Mg saturation | -0.0000 | 0.0000 |
| `rwtitr` | delxi (step size) | 9.7284E-05 | 9.7283E-05 |
| `swtitr` | Charge discrepancy | -1.2378E-11 | -1.2377E-11 |
| `swxrca` | Exchanger 1 saturation | -0.00000 | 0.00000 |
| `swxrcaft` | Charge discrepancy | 6.8621E-11 | 6.8620E-11 |

#### Platform-divergent EQ6 cases (6tlib_fmt)

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `c4pgwbN2` | Charge discrepancy | -1.7584E-11 | -1.7585E-11 |
| `f24vc7b3` | Most rapidly changing species | Cl- (-0.8267) | Na+ (-0.4288) |
| `f24vc7k4` | Most rapidly changing species | Cl- (-0.7311) | K+ (-0.1291) |
| `f24vc7m` | H+ Jacobian entry | -2.05909E-11 | -2.05910E-11 |
| `gypnaclx` | delxi (step size) | 2.7250E-03 | 2.7249E-03 |

#### Platform-divergent EQ6 cases (6tlib_hmw)

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `calhal` | delxi (step size) | 9.3160E-02 | 9.3159E-02 |
| `evapsw` | delxi (step size) | 2.4498E-01 | 2.4499E-01 |
| `evswgyha` | Charge discrepancy | -2.0166E-17 | -1.1124E-16 |
| `gypanhy` | Actual charge imbalance | -1.1670E-14 | -1.1559E-14 |
| `mgso4` | Actual charge imbalance | -8.7663E-13 | -8.7751E-13 |
| `swv1sxk` | Charge discrepancy | -2.5403E-16 | -6.9812E-16 |

#### Platform-divergent EQ6 cases (6tlib_ymp)

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `dedolo` | delxi (step size) | 2.0438E-04 | 2.0451E-04 |
| `heatswfl` | Charge discrepancy | -3.7407E-11 | -3.7408E-11 |
| `heatsw` | Charge discrepancy | -7.8171E-17 | 3.2851E-17 |
| `j13wsf` | Charge discrepancy | 6.0322E-17 | 8.8945E-17 |
| `j13wtuff` | Al total molality | 1.02824E-09 | 1.02825E-09 |
| `methane` | Calcite moles | 0.0000 | -0.0000 |
| `microft` | Actual charge imbalance | 2.7105E-20 | 1.3553E-20 |
| `micro` | delxi (step size) | 8.6619E-06 | 1.0154E-05 |
| `pptcal` | Charge discrepancy | 9.5566E-18 | 2.0834E-17 |
| `pptqtza` | Stoich. ionic asymmetry | 3.11115E-18 | 3.11200E-18 |
| `rwssdiag` | Actual charge imbalance | 1.2089E-16 | 1.1948E-16 |
| `rwtitr` | delxi (step size) | 4.0388E-06 | 4.0382E-06 |
| `swtitr` | Charge discrepancy | -2.3335E-12 | -2.3337E-12 |
| `swxrca` | Charge discrepancy | -9.2468E-13 | -9.2490E-13 |
| `swxrcaft` | Charge discrepancy | 7.7957E-11 | 7.7958E-11 |

#### Platform-divergent EQ6 cases (6tlib_ypf)

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `calhal90` | delxi (step size) | 1.7774E-03 | 1.7774E-03 (Xi differs: 5.9844E-03 vs 5.9843E-03) |
| `evapsw60` | delxi (step size) | 1.6001E+00 | 1.6002E+00 |

#### Platform-divergent EQ3NR case (3tlib_ypf)

One EQ3NR case also differs slightly (charge balance diagnostic in the YMP Pitzer database):

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `arcmir` | Charge imbalance | -1.0043077481E-12 | -1.0040857035E-12 |

#### Platform-divergent xchtlib cases

| Case | First differing quantity | Linux value | Mac value |
|---|---|---|---|
| `swxrca` (eq6) | Exchanger 1 saturation | -0.00000 | 0.00000 |
| `swxrcaft` (eq6) | Charge discrepancy | 6.8621E-11 | 6.8620E-11 |

---

### Known non-converging cases

Three cases fail to reach "Normal exit" — both in our build and in the upstream PC
reference outputs. The EQ6 solver exhausts step-size reduction attempts and terminates
with an error. These cases are still tested: the reference captures the partial output
including the terminal error message, and the test asserts that the output matches the
reference. The `assert_match "Normal exit"` check is omitted for these cases in the
generated BATS files.

| Case | Library | Terminal error |
|---|---|---|
| `heatswfl.6i` | `6tlib_ymp` | `Hybrid Newton-Raphson iteration has gone sour` at Xi=1.6032 |
| `swv1sxk.3i`  | `xchtlib`   | EQ3NR solver does not converge for ion exchange configuration |
| `swv1sxk.6i`  | `xchtlib`   | EQ6 solver does not converge for ion exchange configuration |

These match the upstream PC reference behavior: the upstream `.3o`/`.6o` files for
these cases also end with the EQ6/EQ3NR convergence error messages, without "Normal exit".

---

## Smoke tests

`tests/cases/smoke/` contains fast smoke tests that run against the compiled binaries
without any thermodynamic database. They verify that the executables exist, are runnable,
and produce the expected version strings.

## Source validation

`make check-sources` validates that `sources.mk` matches the extracted `src/` tree. This
runs automatically as part of `make test`.

## DEW smoke tests

`tests/cases/dew/smoke/smoke_dew.bats` checks that the DEW variant binaries (`bin-dew/`)
exist and produce expected version identifiers. Run via `make test-dew`.
