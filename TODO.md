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
- [ ] Update RPM `%check`, deb rules, and Homebrew `test do` block to use `bats`

---

## 2. Expand test coverage — upstream test library

Goal: Run all 170+ input/output pairs from `upstream/EQ3_6v8.0a TestLibrary PC.zip`.
Prerequisite: BATS migration (item 1) so the framework scales cleanly.

Infrastructure additions needed (see existing TODOs in `tests/run_tests.sh`):
- [ ] Add `assert_output_matches()` BATS helper with floating-point tolerance
- [ ] Add `stage_data1_hmw()` BATS helper for Pitzer/HMW cases (uses `src/eqpt/src/data1f`)
- [ ] Add a `make extract-testlib` target (or inline logic) to unzip test library cases

Test libraries to add:

| Library | EQ3NR cases | EQ6 cases | Notes |
|---|---|---|---|
| `3tlib_cmp` | 41 | 21 | Standard database — largest group |
| `3tlib_fmt` | 7 | 5 | Format/parsing edge cases |
| `3tlib_hmw` | 9 | 7 | HMW/Pitzer database — needs `data1f` |
| `3tlib_ymp` | 41 | 21 | Yucca Mountain Project database |
| `3tlib_ypf` | 7 | 2 | YMP Pitzer variant |
| `xchtlib` | 6 | 3 | Ion exchange |

---

## 3. DEW (Deep Earth Water) test suite

Goal: Run EQ3/6 calculations from the DEW community test cases in `DEW/`.
Source: http://www.dewcommunity.org/resources.html

Cases are organized by P-T condition (e.g., `10_kbar_300-650c`) and use custom DEW
thermodynamic databases (DATA0 files) rather than the standard `data1`. Conditions span:
- Pressure: 0.2 GPa – 50 kbar
- Temperature: 300–1000 °C

**Status: unknown** — it is unclear whether the stock EQ3/6 v8.0a executables can run
these cases as-is, or whether the DEW DATA0 files need to be regenerated using
[pyDEW](https://gitlab.com/simonwmatthews/pyDEW). That is a prerequisite question.

- [ ] Audit a sample of DEW cases to confirm they run against current EQ3/6 executables
- [ ] Determine whether DEW DATA0 files are directly usable or require regeneration via pyDEW
- [ ] If pyDEW is needed: decide whether it becomes a test dependency or a separate `make` target
- [ ] Add BATS test cases for DEW P-T suites (once runnable)

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
