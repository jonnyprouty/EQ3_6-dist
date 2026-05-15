# TODO

Items are not necessarily worked in order, but new work should not paint us into a corner
on any of these goals. See CLAUDE.md for guidance on how to apply this list.

---

## 1. Migrate tests to BATS

The current bespoke `tests/run_tests.sh` + `tests/lib/helpers.sh` reimplements what
[bats-core](https://github.com/bats-core/bats-core) provides out of the box: test discovery,
TAP-format output (understood natively by GitHub Actions and most CI systems), and colored
pass/fail reporting. Migrating keeps tests in bash but removes the hand-rolled framework.

- [x] Document `bats-core` as a test dependency (`dnf install bats` / `apt install bats` / `brew install bats-core`)
- [x] Convert `tests/lib/helpers.sh` to a BATS helper library (`load helpers` pattern)
- [x] Convert each `tests/cases/**/test.sh` to a `.bats` file
- [x] Replace `tests/run_tests.sh` with a direct `bats tests/` invocation
- [x] Update `make test` to invoke `bats`
- [x] Update RPM `%check`, deb rules, and Homebrew `test do` block to use `bats`
  - Decision: packaging-time checks remain as raw shell/Ruby (environments lack test inputs);
    instead, `tests/cases/packaging/packaging_checks.bats` runs the packaging check logic
    against local binaries to catch stale expected strings.

---

## 2. Expand test coverage — upstream test library

Goal: Run all 170+ input/output pairs from `upstream/EQ3_6v8.0a TestLibrary PC.zip`.
Prerequisite: BATS migration (item 1) so the framework scales cleanly.

Infrastructure additions needed (see existing TODOs in `tests/run_tests.sh`):
- [x] Add `assert_output_matches()` BATS helper with floating-point tolerance
  - Decision: used per-platform exact references instead of tolerance. EQ6 ODE path
    divergence between gfortran versions is not rounding noise — it is genuine path
    divergence. Per-platform refs in `tests/testlib/expected/{linux,mac}/` give exact
    matches on each platform without masking real regressions with a tolerance band.
- [x] Add `stage_data1_hmw()` BATS helper for Pitzer/HMW cases (uses `src/eqpt/src/data1f`)
  - Decision: implemented as `stage_data1_for(workdir, dataset)` in helpers.bash, which
    serves all datasets uniformly. HMW data1 is compiled from `data0.hmw` and cached at
    `tests/.data1_cache/data1.hmw` by `make extract-testlib`.
- [x] Add a `make extract-testlib` target (or inline logic) to unzip test library cases

Test libraries to add:

| Library | EQ3NR cases | EQ6 cases | Notes |
|---|---|---|---|
| `3tlib_cmp` | 41 | 21 | Standard database — largest group |
| `3tlib_fmt` | 7 | 5 | Format/parsing edge cases |
| `3tlib_hmw` | 9 | 7 | HMW/Pitzer database — needs `data1f` |
| `3tlib_ymp` | 41 | 21 | Yucca Mountain Project database |
| `3tlib_ypf` | 7 | 2 | YMP Pitzer variant |
| `xchtlib` | 6 | 3 | Ion exchange |

**All 170 cases implemented. Linux: 170/170 pass. Mac: 170/170 pass.**
Three cases are known non-converging (no Normal exit in upstream or our output); see
`TESTS.md` for details.

---

## 3. DEW (Deep Earth Water) test suite

Goal: Run EQ3/6 calculations from the DEW community test cases in `DEW/`.
Source: http://www.dewcommunity.org/resources.html

Cases are organized by P-T condition (e.g., `10_kbar_300-650c`) and use custom DEW
thermodynamic databases (DATA0 files) rather than the standard `data1`. Conditions span:
- Pressure: 0.2 GPa – 50 kbar
- Temperature: 300–1000 °C

**Status: investigated — pyDEW required.** The DEW DATA0 files are in the old EQ3/6 R71
format (circa 1987–1991) which is **incompatible** with v8.0a EQPT in two ways:

1. **DATA0 format**: The old format has an explicit `NCT/NSQ` count header and no separate
   `basis species` section (the first NSQ aqueous species are implicitly the basis species).
   The v8.0a `EQPT/gnenb` scans for a `basis species` keyword and hits EOF on DEW DATA0.

2. **data1 binary format**: The DEW-distributed pre-compiled EQPT (macOS) uses 8-byte
   Fortran record length markers; our gfortran EQ3/6 uses 4-byte markers. Beyond that,
   the internal data1 structure also changed between the R71 and v8.0a versions —
   converting record markers is not sufficient for compatibility.

**Consequence for the colleague**: The pre-compiled macOS EQ3/EQ6 executables from the DEW
ZIPs work fine on the right architecture. They cannot be used on Linux directly. The
modern v8.0a executables cannot read the old-format DATA0 or data1 files.

**DEW EQPT binary architecture**: The newer DEW EQPT binaries (e.g. in `10_kbar_300-650c`,
dated 2025-03-07) are **ARM64 (Apple Silicon only)** — confirmed via Mach-O header
`cf fa ed fe 0c 00 00 01`. They will not run on Intel Macs or Linux. This is why a
colleague using an Intel Mac cannot run "Dimitri's EQPT" on the DEW DATA0 files.

**DEW EQPT interactive stdin**: The DEW EQPT requires three interactive prompts (`n/n/y`
for Pitzer/HKF/data0s). Running without piping answers causes `fmt: end of file` crash.
`tools/run_dew_eqpt.sh` wraps this correctly for Apple Silicon users.

**Immediate workaround**: Pre-built `data1` files are included in every DEW ZIP — the
colleague can use those directly without re-running EQPT.

**pyDEW architecture — corrected understanding**: pyDEW generates R71-format DATA0
(the same old format), NOT v8.0a-compatible DATA0. Our v8.0a EQPT cannot process it.
The [pyDEW container](https://hub.docker.com/r/simonwmatthews/pydew) (`simonwmatthews/pydew:v2.15`)
bundles its own x86-64 Linux R71 EQPT, EQ3, and EQ6 binaries. `pyDEW.Fluid()` runs the
entire pipeline internally (DATA0 → EQPT → data1 → EQ3) using those bundled binaries.

**Consequence**: The DEW and v8.0a stacks are **parallel, non-interoperating tracks**:
- DEW calculations: use `bin-dew/` executables (native build) or `tools/run_dew.sh` (container)
- Standard calculations: use our v8.0a `eq3nr`/`eq6` (ambient to moderate P-T)

`tools/run_dew.sh` wraps the pyDEW container for command-line aqueous speciation (podman/docker).
`tools/dew_calc.py` is the Python entry point executed inside the container.

**Native DEW build** (`upstream-dew/` submodule, `make build-dew`): Builds five executables
(`eqpt`, `eq3`, `eq6`, `supcrt`, `cprons92`) to `bin-dew/` from the
[SUPCRTandEQs/DEW_activities](https://gitlab.com/ENKI-portal/SUPCRTandEQs) source using
gfortran + `-std=legacy -ffixed-line-length-none`. Source patches in `patches/dew-*.patch`
are applied automatically before compilation and are intended to be submitted upstream.

**Dependency classification**: The pyDEW container is for the Python `pyDEW.Fluid()` workflow
only. The native `bin-dew/` executables cover all direct EQ3/6 DEW use cases without a container.

- [x] Audit a sample of DEW cases to confirm they run against current EQ3/6 executables
- [x] Determine whether DEW DATA0 files are directly usable or require regeneration via pyDEW
- [x] Identify root cause of DEW EQPT failure for colleague (ARM64 binary, Intel Mac mismatch)
- [x] Create `tools/run_dew_eqpt.sh` wrapper for correct DEW EQPT invocation (Apple Silicon)
- [x] Clarify pyDEW architecture: R71 stack in container, not v8.0a bridge
- [x] Create `tools/run_dew.sh` + `tools/dew_calc.py` for command-line DEW calculations
- [x] Add `upstream-dew/` submodule and `make build-dew` for native DEW variant build
- [x] Add `make patch-dew` precompile hook (auto-applies `patches/dew-*.patch`)
- [x] Add BATS smoke tests for DEW variant (`tests/cases/dew/smoke/smoke_dew.bats`)
- [ ] Add BATS test cases for DEW calculations with actual EQ3 input/output pairs
- [ ] Document pyDEW container as optional dependency in README
- [x] Package DEW variant (RPM/deb/Homebrew for `eq3-6-dew`) — includes DATA0 and sprons93 in `/usr/share/eq3-6-dew/` (or Homebrew's `share/eq3-6-dew/`)

---

## 4. Package build & install verification checklist

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
