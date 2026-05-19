# Test suite documentation

## Overview

The test suite uses [bats-core](https://github.com/bats-core/bats-core). Install it with
`dnf install bats` / `apt install bats` / `brew install bats-core`, then run `make test`.

```
make test          # smoke tests + packaging checks + source validation
make test-testlib  # upstream test library (170 cases; auto-fetches, builds, and extracts inputs)
make test-dew      # DEW smoke + workshop tests (auto-builds bin-dew/ and data caches)
```

`make test-testlib` is separate because it requires the upstream test library ZIP
(`upstream/EQ3_6v8.0a TestLibrary PC.zip`) and takes a few minutes to run. It does not
run as part of `make test` or the packaging-time `%check` / `dh_auto_test` checks.
All prerequisites (submodule init, extraction, data1 compilation) are handled automatically.

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

Reference outputs live in `tests/testlib/expected/<platform>/`. Three platforms are
committed: `linux/` (generated on Fedora 43 with gfortran 15.2.1), `ubuntu/` (generated
on Ubuntu 26.04 with gfortran 15.2.0 apt), and `mac/` (generated on macOS 15 with
Homebrew gfortran 15.2.0).

`assert_output_matches_ref` in `tests/lib/helpers.bash` resolves:
1. `tests/testlib/expected/<platform>/<lib>/<case>.out` if it exists
2. `tests/testlib/expected/linux/<lib>/<case>.out` as fallback

The platform tag is `linux` on Fedora/RHEL, `ubuntu` on Ubuntu (detected via
`/etc/os-release`), and `mac` on macOS (from `uname -s`). This gives each platform an
exact match rather than a toleranced comparison.

To regenerate refs for the current platform:
```bash
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

### Ubuntu-specific divergences

Ubuntu (gfortran 15.2.0 apt) diverges from Fedora (gfortran 15.2.1 RPM) on 27 cases.
Where a case also diverges on macOS, the Ubuntu value differs from both; where it is
not in the Mac tables above, Ubuntu is the only diverging platform.

#### Ubuntu-divergent EQ3NR cases (3tlib_ymp)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `henleyph` | Ionic asymmetry (J) | 3.25261E-17 | 3.68629E-17 |

#### Ubuntu-divergent EQ6 cases (6tlib_cmp)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `heatswfl` | Charge discrepancy | 7.4925E-12 | 7.4924E-12 |
| `heatsw` | Antigorite saturation index | -0.00000 | 0.00000 |
| `j13wtitr` | Charge discrepancy | -6.5173E-16 | -6.5260E-16 |
| `j13wtuff` | Charge discrepancy | 1.8521E-15 | 1.8504E-15 |
| `methane` | Charge discrepancy | 1.6335E-13 | 1.6336E-13 |
| `pyrsw` | Charge discrepancy | -1.2928E-15 | -1.4038E-15 |
| `swxrca` | Exchanger 1 saturation | 0.00000 | -0.00000 |
| `swxrcaft` | Exchanger 1 saturation | 0.00000 | -0.00000 |

#### Ubuntu-divergent EQ6 cases (6tlib_fmt)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `c4pgwbN2` | Charge discrepancy | -1.7584E-11 | -1.7585E-11 |
| `f24vc7b3` | Most rapidly changing species | Cl- (-0.8267) | Na+ (-0.4288) |
| `f24vc7m` | Actual charge imbalance | 1.3975E-13 | 1.2764E-13 |

#### Ubuntu-divergent EQ6 cases (6tlib_hmw)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `evapsw` | delxi (step size) | 2.4498E-01 | 2.4499E-01 |
| `evswgyha` | Charge discrepancy | 6.4965E-16 | 5.8775E-16 |
| `mgso4` | delxi (step size) | 4.2093E-06 | 4.2092E-06 |

#### Ubuntu-divergent EQ6 cases (6tlib_ymp)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `heatswfl` | Charge discrepancy | -3.7407E-11 | -3.7408E-11 |
| `heatsw` | Charge discrepancy | -3.0802E-16 | -8.5977E-17 |
| `j13wtuff` | delxi (step size) | 8.6454E-05 | 8.6453E-05 |
| `micro` | Actual charge imbalance | 0.0000E+00 | 2.7105E-20 |
| `microft` | Actual charge imbalance | 3.7947E-19 | 2.9816E-19 |
| `pptcal` | Charge discrepancy | 9.5566E-18 | 1.4762E-17 |
| `swxrca` | Charge discrepancy | -2.2009E-17 | -1.3303E-16 |
| `swxrcaft` | delxi (step size) | 8.0780E-03 | 8.0772E-03 |

#### Ubuntu-divergent EQ6 cases (6tlib_ypf)

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `calhal90` | Actual charge imbalance | 2.1427E-13 | 2.1416E-13 |
| `evapsw60` | Charge discrepancy | 9.0466E-14 | 9.0384E-14 |

#### Ubuntu-divergent xchtlib cases

| Case | First differing quantity | Linux value | Ubuntu value |
|---|---|---|---|
| `swxrca` (eq6) | Exchanger 1 saturation | 0.00000 | -0.00000 |
| `swxrcaft` (eq6) | Exchanger 1 saturation | 0.00000 | -0.00000 |

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

---

## DEW workshop tests

`tests/cases/dew/workshop/` contains 8 functional tests that run actual EQ3/6 DEW
calculations from the DEW community workshop materials and compare against committed
reference outputs.

```
make test-dew               # smoke + workshop (auto-builds bin-dew/ and data caches)
make test-dew-workshop      # workshop cases only
```

### Datasets and cases

Three DATA0 databases are compiled at setup time into `tests/.dew_data_cache/`:

| Dataset | Source | Conditions |
|---|---|---|
| `psat` | `DEW/psat_data0___examples_from_enki.zip` | Surface to low P-T |
| `10kbar` | `DEW/10_kbar_300-650c.zip` | 300–650°C, 10 kbar |
| `upstream` | `upstream-dew/EQPT/DATA0` | Canonical DEW upstream example |

| Case | Exe | Dataset | Condition | Normal exit? |
|---|---|---|---|---|
| `surface_seawater` | eq3 | psat | 25°C, psat | No (arrsim convergence failure in DEW R110) |
| `calcite_25c` | eq3 | psat | 25°C, psat | Yes |
| `calcite_solid_soln` | eq3 | psat | 25°C, psat | No (arrsim) |
| `co2_h2o` | eq3 | psat | 25°C, psat | Yes |
| `co2_650c_10kbar` | eq3 | 10kbar | 650°C, 10 kbar | Yes |
| `pelitic_550c_10kbar` | eq3 | 10kbar | 550°C, 10 kbar | Yes |
| `pelitic_10kbar_eq6` | eq6 | 10kbar | 650°C, 10 kbar | Yes (R100 "average value of delzi") |
| `mor_hydrothermal` | eq6 | upstream | 350°C, MOR | Yes (R100 "average value of delzi") |

### Reference outputs and reproducibility

Reference outputs live in `tests/dew/expected/<platform>/`. Platforms currently committed:

| Platform tag | Host | Compiler | Divergent cases |
|---|---|---|---|
| `linux` | Fedora 43 x86-64 | gfortran 15.2.1 (Red Hat RPM) | baseline (8/8 refs) |
| `ubuntu` | Ubuntu 26.04 x86-64 | gfortran 15.2.0 (Ubuntu apt) | `pelitic_10kbar_eq6` (1/8 ref) |
| `mac` | macOS 15 x86-64 | gfortran 15.2.0 (Homebrew) | `co2_650c_10kbar`, `pelitic_550c_10kbar`, `pelitic_10kbar_eq6`, `mor_hydrothermal` (4/8 refs) |

The `assert_dew_output_matches_ref` helper resolves:
1. `tests/dew/expected/<platform>/<case>.out` if it exists
2. `tests/dew/expected/linux/<case>.out` as fallback

Platform is detected at test time from `uname -s` and `/etc/os-release` (see
`_EQ_PLATFORM` in `tests/lib/helpers.bash`).

To regenerate references for the current platform:
```bash
make regen-dew-refs         # writes to tests/dew/expected/<platform>/
# commit the results
```

### Platform-divergent DEW cases

#### EQ3 cases (macOS only)

Two EQ3 speciation cases produce different last-digit values on macOS:

| Case | First differing quantity | Fedora/Ubuntu (linux) | Mac |
|---|---|---|---|
| `co2_650c_10kbar` | `beta(CONC H+)` activity coefficient | 2.50422E-10 | 2.50423E-10 |
| `pelitic_550c_10kbar` | Charge imbalance | 0.1966927105E-07 | 0.1966927132E-07 |

EQ3NR speciation is algebraic (no ODE integration), so these differ for a different
reason than the EQ6 cases.  The DEW EQ3 R110 activity coefficient model calls
subroutine `betgam` (in `eqlibr136.f`), which iterates the Helgeson-Kirkham-Flowers
equations and the Born dielectric correction for the DEW pressure-temperature model.
The iteration accumulates inner products of species molalities and activity
coefficients — operations where Homebrew gfortran 15.2.0 produces slightly different
x87 extended-precision intermediates than Red Hat gfortran 15.2.1.  For ambient cases
(psat dataset) the values agree; for high P-T cases (10 kbar) the HKF terms are
larger and the extended-precision divergence is large enough to round to a different
last digit.

#### EQ6 cases

`pelitic_10kbar_eq6` diverges on both Ubuntu and macOS relative to the Fedora baseline,
while `mor_hydrothermal` diverges only on macOS:

| Case | Platform | First differing quantity | linux value | Platform value |
|---|---|---|---|---|
| `pelitic_10kbar_eq6` | ubuntu | Reaction progress | 2.04013621037949E-05 | 2.04013500438004E-05 |
| `pelitic_10kbar_eq6` | mac | Reaction progress | 2.04013621037949E-05 | 2.04013697534068E-05 |
| `mor_hydrothermal` | mac | COPPER saturation index | -0.0000 | 0.0000 (sign-of-zero) |

These are genuine ODE path divergences — the same phenomenon documented for `6tlib_*`
cases above.  The EQ6 R100 reaction path integration (subroutine `path` in
`eq6r100.f`, line 7071) uses a predictor-corrector method where predictor values for
the next step are computed by subroutine `taylor` (line 15032) as truncated Taylor
series in the reaction-progress variable `delzi`.  The Taylor coefficients `dzvec0`
are finite-difference derivatives of the basis variable vector `zvec0`, accumulated
by subroutine `zvecpr` (line 16057) after each accepted step.

At each step `path` calls `taylor` to extrapolate, then calls `eqcalc` (line 2568)
to correct via Newton-Raphson.  The corrected step is accepted or rejected based on
whether the residual functions in `betaz` (line 1468) fall within tolerance.  When
the step is accepted, `zvecpr` updates the derivative vectors for the next predictor.

Different gfortran packaging builds (Red Hat RPM vs Ubuntu apt vs Homebrew) apply
different optimization passes and produce different x87/SSE2 instruction sequences
for the Taylor accumulation loop in `taylor`.  The resulting extended-precision
intermediates differ by ≤1 ULP.  After enough steps those differences compound into
divergent step-size decisions in `path`, sending different builds down different
branches of the adaptive step-size controller.

- On **Ubuntu** the bifurcation occurs at step 17 of `pelitic_10kbar_eq6` (the Ubuntu
  and Fedora builds take a different number of Newton-Raphson corrector iterations at
  that step).
- On **macOS** the bifurcation occurs at step 2, and `mor_hydrothermal` also diverges
  at the final saturation index print (sign of a near-zero value in subroutine `wrtabx`).
- `pelitic_10kbar_eq6` diverges on all non-Fedora platforms because it is the longest
  DEW EQ6 run (22 000+ output lines, 17 accepted steps) — more steps means more
  opportunities for accumulated ULP differences to cross a convergence threshold.
  `mor_hydrothermal` is shorter (1 900 lines) and only diverges on macOS.

### Why the DEW binaries needed initialization flags

The DEW R110/R100 source (from `upstream-dew/`, branch `DEW_activities`) contains
numerous uninitialized Fortran variables that cause non-deterministic output across
process invocations.  Three gfortran flags are applied to all DEW executables to
eliminate this non-determinism:

- **`-finit-character=32`** — initializes CHARACTER variables to spaces.  Without
  this, `eqpt` writes heap garbage into CHARACTER fields of the binary data1/data2/data3
  files, and `eq3`/`eq6` use uninitialized CHARACTER variables in species-name
  comparisons that alter convergence paths.

- **`-finit-real=zero`** — initializes REAL variables to 0.0.  Without this,
  uninitialized REAL locals perturb the EQ6 ODE predictor-corrector, causing
  last-digit pH/concentration differences across invocations.

- **`-finit-integer=0`** — initializes INTEGER variables to 0.  Prevents
  uninitialized INTEGER flags from taking invalid values that could misdirect
  activity-model or convergence logic.

A companion source patch (`patches/dew-eqlibr136-betgam-eqlgp.patch`) fixes a bug
in `betgam` where the missing `include "eqlgp.h"` left `iopg1` (the activity
coefficient model selector) as an uninitialized local variable rather than reading
it from COMMON `/eqlgp/`.  This bug caused spurious "entry to betgam with iopg1 = *****"
aborts when the CHARACTER initialization flag changed the stack layout.

---

## pyDEW container comparison

`make compare-dew-container` runs all 8 DEW workshop test inputs through the
[pyDEW container](https://hub.docker.com/r/simonwmatthews/pydew) (`simonwmatthews/pydew:v2.15`)
and compares results against the committed native `bin-dew/` references.  This is an
informational comparison tool, not part of CI or `make test`.

```
make compare-dew-container       # compare (requires podman or docker, DEW/*.zip files)
make regen-container-refs        # regenerate committed container refs (then commit)
```

### What the container is

The pyDEW container bundles x86-64 Linux executables from the **R71 EQ3/EQ6 code base**
(circa 1987–1991), distinct from the **R110/R100** code in the `upstream-dew/` submodule.
These two stacks share the same DATA0 thermodynamic databases but differ in:

- Fortran record-length markers in the binary data1 file: 8-byte (container, from the
  original f2c/SVR4 Fortran convention) vs. 4-byte (gfortran default).  The data1 files
  from one stack cannot be read by the other.
- Output format: the R71 code prints scientific notation without a leading zero
  (`.25000E+02`) while R110/R100 prints with a leading zero (`0.25000E+02`).
- Some descriptive label strings for activity-coefficient options (`iopg5`, `iopg9`,
  `iopg10`) were updated between R71 and R110 to reflect the expanded DEW P-T model.

### Determinism

All 8 cases are deterministic across 3 runs on the container (tested on Fedora 43,
podman, `simonwmatthews/pydew:v2.15`).  The container's EQ3/EQ6 binaries were not
compiled with `-finit-character=32`, so CHARACTER variables are initialized to null
bytes (0x00) rather than spaces.  On Linux, the OS initializes heap memory to zero
for new processes, making the uninitialized values reproducibly null — this is why
the container is deterministic despite lacking the init flag.

### What differs between container and native outputs

Tested with `make compare-dew-container` on the 8 workshop cases (Fedora 43,
`simonwmatthews/pydew:v2.15` container, compared to `tests/dew/expected/linux/`):

| Case | Changed lines | Nature of differences |
|---|---|---|
| `surface_seawater` | 134 | Format only |
| `calcite_25c` | 314 | Format only |
| `calcite_solid_soln` | 348 | Format only |
| `co2_h2o` | 290 | Format only |
| `co2_650c_10kbar` | 388 | Format only |
| `pelitic_550c_10kbar` | 952 | Format only |
| `pelitic_10kbar_eq6` | 20827 | Format only (long reaction path: many steps × same pattern) |
| `mor_hydrothermal` | 742 | Format + updated label text |

All differences are cosmetic (see "What the container is" above).  All thermodynamic
values — equilibrium constants, molalities, saturation indices, reaction progress,
charge balance — are numerically identical between the two stacks for all 8 cases.

### Committed container references

Reference outputs live in `tests/dew/expected/container/`.  They are normalized (timing
lines and null bytes stripped) so that future `make compare-dew-container` runs can
detect if the container outputs change (e.g. a new image version introduces numerical
differences).  Regenerate with `make regen-container-refs` after pulling a new image.
