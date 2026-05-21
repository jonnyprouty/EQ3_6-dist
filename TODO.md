# TODO

Items are not necessarily worked in order, but new work should not paint us into a corner
on any of these goals. See CLAUDE.md for guidance on how to apply this list.

---

## 1. DEW (Deep Earth Water) test suite

- [ ] Document pyDEW container as optional dependency in README
- [ ] **Tier 3 (larger effort)**: `surface_seawater` at pe = −8.4 likely needs a direct
      analytical pre-estimate of log[O2(aq)] and log[H2(aq)] from the Nernst equation before
      entering `arrsim`, bypassing the ill-conditioned simultaneous-estimation path for
      jflag=27 species when pe is explicitly specified. This mirrors deeper v8.0a arrset
      machinery; scope is closer to a subsystem backport than a patch.

---

## 2. Minimal Fortran reproducers for platform divergence

The test suites document two distinct platform-divergence mechanisms that produce different
reference outputs on Fedora, Ubuntu, and macOS despite identical source code and compiler
version numbers.  Small, self-contained Fortran programs that exhibit the same divergence
would serve as license-free, upstream-submittable reproduction cases.

**Requirements:**
- Single source file per reproducer; same file compiled unmodified on all three platforms
- No EQ3/6 source, headers, or data files — the programs must stand alone
- No architecture-specific pragmas or compiler flags beyond standard `-O2`
- When the binary is built on Fedora (gfortran 15.2.1 RPM), Ubuntu (gfortran 15.2.0 apt),
  and macOS (gfortran 15.2.0 Homebrew), the output should visibly diverge in the same
  character as the test suite divergences: different last-digit values or different
  branch-taken counts

**Reproducer 1 — ODE predictor-corrector step divergence** (`tools/repro/ode_diverge.f`):

Implement an adaptive-step Adams-Bashforth-Moulton predictor-corrector loop for a
nonlinear ODE (e.g. a Lotka-Volterra or logistic equation) over enough steps that
accumulated Taylor-coefficient differences cross the step-acceptance threshold at
least once.  The acceptance criterion should be a floating-point comparison against
a fixed tolerance, so that a ≤1 ULP difference in the residual can flip the branch
and produce a different step count or final state value.  This mirrors the `taylor`
→ `zvecpr` → `path` divergence in `eq6r100.f` that causes the EQ6 ODE cases to
produce different reaction-progress values on Ubuntu and macOS.

**Reproducer 2 — Iterated activity-coefficient inner-product divergence** (`tools/repro/actcoef_diverge.f`):

Implement a fixed-point iteration for ionic-strength-weighted activity coefficients
using the extended Debye-Hückel equation (no EQ3/6 code; just the published formula).
Run at a high-P-T condition where the Born dielectric correction term is large (order
10² – 10³).  After convergence, print the final log γ values to sufficient precision
to expose the last-digit difference.  This mirrors the `betgam` HKF iteration in
`eqlibr136.f` that causes the two high-P-T EQ3 DEW cases (`co2_650c_10kbar`,
`pelitic_550c_10kbar`) to differ between macOS and Fedora/Ubuntu.

**Verification:**
- Build each reproducer on all three platforms with `gfortran -O2 repro.f -o repro`
- Run and capture output; diff the three outputs
- The diff pattern should qualitatively match the corresponding divergences in
  `TESTS.md` (last-digit differences in the ODE case, last-digit log γ in the
  activity-coefficient case)
- If the outputs are identical across platforms, the reproducer does not yet capture
  the right operation — iterate on the formula or iteration count

- [ ] Write `tools/repro/ode_diverge.f` and verify it diverges across platforms
- [ ] Write `tools/repro/actcoef_diverge.f` and verify it diverges across platforms
- [ ] Add a `make test-repro` target that builds both on the current platform and
      prints the output (comparison across platforms is manual / farm-build)

---

## 3. Test environment setup helper

The pattern of copying data files into a tmpdir, running a binary with `cwd=tmpdir`, and
cleaning up is duplicated across `tools/compare_dew_container.sh`, `tools/regen_dew_refs.sh`,
and `tests/lib/helpers.bash` (`run_eq3nr`, `run_eq6`, `run_eq3_dew`, `run_eq6_dew`).
A single generic helper would replace all of these.

- [ ] Add a `run_eq_case()` helper in `tests/lib/helpers.bash` that accepts: binary path
      (full), workdir, and input file path.  It should: copy the input file to
      `workdir/input`, run the binary with `cwd=workdir`, and capture stdout+stderr to
      `workdir/run.log`.  Data file staging remains the caller's responsibility (via the
      existing `stage_data1_for`, `stage_dew_data`, etc.) — `run_eq_case()` handles only
      execution.  This works for any EQ binary regardless of variant.
- [ ] Replace the per-binary wrappers (`run_eq3nr`, `run_eq6`, `run_eq3_dew`, `run_eq6_dew`)
      with thin one-liners over `run_eq_case()` so callers that already use those names
      keep working.
- [ ] Refactor `tools/regen_dew_refs.sh` `run_case()` and `tools/compare_dew_container.sh`
      `run_case_container()` to source `tests/lib/helpers.bash` and call `run_eq_case()`
      rather than re-implementing the same loop.

---

## 4. Cross-platform test diff tool (`tools/farm_test_diff.sh`)

Goal: single script that SSHs to each build machine, runs the full test suite,
collects raw BATS output, diffs results across platforms, and produces a
structured summary suitable for updating `TESTS.md`.

The script should:
- Accept an optional list of platforms (default: all three from `ssh_build_farm.mk`)
- Run `make test test-testlib test-dew` on each machine in parallel (background SSH jobs)
- Capture full BATS TAP output per platform into timestamped local files
  (`/tmp/farm_test_<platform>_<timestamp>.tap` or similar)
- Diff outcomes across platforms: for each test, report pass/fail per platform
  in a table (test name | fedora | ubuntu | mac)
- Highlight cases that pass on some platforms but fail on others (genuine divergences)
  vs cases that fail everywhere (regressions)
- For failing cases, show the first differing line between platforms so the
  nature of the divergence is immediately visible without reading full output files
- Print a TESTS.md-ready markdown table of platform-divergent cases that can be
  pasted into the "Known platform divergences" section

Makefile hook:
- [ ] Add `make farm-test-diff` target that invokes `tools/farm_test_diff.sh`
- [ ] Add to `.PHONY`

Implementation:
- [ ] Write `tools/farm_test_diff.sh`
  - Sources `ssh_build_farm.mk` (or reads the same variables via make) to get
    `*_CONNECTION` and `*_FARM_REPO` without duplicating connection logic
  - Uses `bats --tap` output format for machine-readable pass/fail lines
  - Parallel SSH with `wait` + per-platform log files; prints each platform's
    result block as it completes
- [ ] Verify output on all three platforms and confirm TESTS.md table format

---

## 5. Package build & install verification checklist

Use this as a **manual release rubric** — run through it before tagging a release. It is a
template; do not check items off and commit. The goal is for every box to be checkable at
release time.

### RPM (Fedora/RHEL)
- [ ] `make rpm` completes without errors
- [ ] `rpm -i pkg/dist/eq3_6-*.rpm` installs cleanly
- [ ] All five executables (`eq3nr`, `eq6`, `eqpt`, `xcon3`, `xcon6`) are in PATH
- [ ] RPM `%check` smoke test passes

### Debian/Ubuntu
- [ ] `make deb` completes without errors
- [ ] `dpkg -i pkg/dist/eq3-6_*.deb` installs cleanly
- [ ] All five executables are in PATH

### Homebrew (macOS)
- [ ] `brew install --build-from-source pkg/brew/eq3_6.rb` succeeds
- [ ] `brew test eq3_6` passes
- [ ] All five executables are accessible via `brew`

---

## 6. DEW build warning cleanup

Observed in `make farm` output (RPM `%build` section and direct `make build-dew`).
Items are ordered roughly by ease of fix.

### Rank mismatch warnings (upstream F77 idioms)

gfortran flags several argument rank mismatches that are harmless under Fortran
pass-by-reference semantics but pollute build output:

- `eqlibr136.f:8149` — `ir` passed rank-1 to `msolvr` (expects scalar)
- `eqlibr136.f:7763` — `ir` passed scalar to `nrstep` (expects rank-1)
- `eq3nr110.f:1818,5736` — `cstor` rank mismatch in `gcsts` calls
- `eq3nr110.f:374` — `nxmod` rank-1 vs scalar
- `eq3nr110.f:1288` — `cstor` scalar vs rank-2
- `eq6r100.f:8972–8974` — `ars`, `amn`, `ags`, `azero`, `hydn`, `conc` in `pabssw` call

These are candidates for upstream bug reports and/or `patches/dew-*.patch` fixes.
Fixing them requires understanding whether the caller or callee has the correct
declaration and adjusting the other side. Adding `-w` to `DEW_FFLAGS` would silence
all warnings but would also hide future real issues — prefer targeted fixes.

- [ ] Audit each rank mismatch; determine correct array rank and fix via patch
- [ ] Submit fixed files upstream to ENKI-portal/SUPCRTandEQs

### COMMON block size mismatches

`eq6r100.f` includes `vx.h` and `nk.h` but declares COMMON blocks at sizes that
disagree with those seen by other compilation units:

- `vxc`: 9920 bytes in `eq6r100.f` vs 9824 bytes elsewhere
- `nk`: 392 bytes in `eq6r100.f` vs 196 bytes elsewhere

A COMMON block size mismatch is a real bug: if different compilation units lay out
the block differently, one unit will read variables at wrong offsets. The program
may run because the larger unit never accesses the tail fields, but it is still
undefined behavior. This should be investigated before the mismatch grows.

- [ ] Identify which compilation unit has the correct size for `vxc` and `nk`
- [ ] Fix the mismatch via a `patches/dew-*.patch` and submit upstream

### RPM `%check` null byte warning

`command substitution: ignored null byte in input` — the RPM `%check` smoke test
captures DEW binary output via `$()`. DEW binaries write null bytes in timing
fields (uninitialized `CHARACTER` buffers), so the shell silently drops them and
emits this warning. The test still passes; the warning is cosmetic.

Fixing it properly would require either piping through `tr -d '\0'` in the spec's
`%check` block or patching the DEW binaries to initialize those buffers (the
determinism flags `-finit-character=32` already cover new code, but this is a
pre-existing initialized `CHARACTER` with a specific fill pattern that still
contains nulls in the timing section).

- [ ] Evaluate whether adding `tr -d '\0'` to the `%check` output capture in
      `pkg/rpm/eq3_6_dew.spec.in` is sufficient to silence the warning cleanly
