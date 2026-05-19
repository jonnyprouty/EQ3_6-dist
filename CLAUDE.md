# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo packages two variants of EQ3/6 geochemical modeling software:

- **v8.0a (standard)**: The unmodified LLNL distribution for Linux (RPM, .deb) and macOS (Homebrew). No source modifications — the upstream ZIP is extracted and compiled as-is. Source: `upstream/` submodule → https://github.com/llnl/EQ3_6
- **DEW variant**: EQ3/6 modified for high pressure-temperature Deep Earth Water conditions, plus SUPCRT92 and CPRONS92. Compiled from `upstream-dew/` submodule → https://gitlab.com/ENKI-portal/SUPCRTandEQs (branch `DEW_activities`). Executables land in `bin-dew/`.

Both variants are compiled with gfortran using `-static-libgfortran -static-libgcc` so the binaries are self-contained and archivable alongside model runs.

## First-time setup

```bash
# v8.0a (standard)
make fetch    # initializes upstream/ submodule
make          # extracts source + compiles all 5 executables to bin/
make docs     # downloads documentation PDFs to docs/ (requires internet)

# DEW variant (optional; requires libgfortran-static on Fedora/RHEL)
make fetch-dew   # initializes upstream-dew/ submodule
make build-dew   # applies source patches + compiles 5 executables to bin-dew/
```

**Critical extraction detail (v8.0a)**: `archsrc.tar` (inside the upstream ZIP) stores every `.f` and `.h` file as `.f.gz` / `.h.gz`. The Makefile's `extract` target runs `gunzip` on all of them after `tar -xf`. If you see "no input files" link errors, the source was not properly decompressed.

**DEW source patches**: `patches/dew-*.patch` are applied automatically before compiling the DEW variant. Each patch is a unified diff relative to the repo root (`patch -p1`). When adding a new patch for an upstream DEW bug, drop the file in `patches/` with a `dew-` prefix and it will be picked up on the next `make build-dew`.

## Make targets

### v8.0a targets

| Target | Effect |
|---|---|
| `make` / `make build` | Extract (if needed) + compile all 5 executables to `bin/` |
| `make fetch` | Init/update `upstream/` submodule |
| `make extract` | Extract and decompress Fortran source to `src/` |
| `make clean` | Remove `obj/` and `bin/` |
| `make distclean` | Also remove `src/`, DEW build dirs, `pkg/rpm/build/`, `pkg/deb/staging/`, `pkg/dist/` |
| `make symlinks LINK_DIR=/path` | Create symlinks; **`LINK_DIR` must be set explicitly** |
| `make docs` | Download documentation PDFs from OSTI to `docs/` |
| `make docs-package` | Create `pkg/dist/eq3-6-docs_8.0a.tar.gz` from downloaded PDFs |
| `make test` | Run the BATS test suite (requires `bats-core` and a prior `make build`) |
| `make rpm` | Build RPM (requires `rpm-build`); output → `pkg/dist/` |
| `make deb` | Build binary .deb (requires `dpkg-dev`); output → `pkg/dist/` |
| `make deb-doc` | Build documentation .deb; output → `pkg/dist/` |
| `make brew` | Install via `pkg/brew/eq3_6.rb` Homebrew formula |

### DEW variant targets

| Target | Effect |
|---|---|
| `make fetch-dew` | Init/update `upstream-dew/` submodule |
| `make patch-dew` | Apply all `patches/dew-*.patch` to `upstream-dew/` (auto-run before compile) |
| `make build-dew` | Apply patches + compile all 5 DEW executables to `bin-dew/` |
| `make test-dew` | Run DEW BATS smoke tests (skipped if `bin-dew/` absent) |
| `make clean-dew` | Remove `obj-dew/` and `bin-dew/` |
| `make symlinks-dew LINK_DIR=/path` | Create `dew-` prefixed symlinks; **`LINK_DIR` must be set explicitly** |
| `make rpm-dew` | Build DEW RPM (requires `rpm-build`); output → `pkg/dist/` |
| `make deb-dew` | Build DEW .deb (requires `dpkg-dev`, prior `make build-dew`); output → `pkg/dist/` |
| `make brew-dew` | Install DEW variant via `pkg/brew/eq3_6_dew.rb` Homebrew formula |

Running both `make symlinks` and `make symlinks-dew` into the same `LINK_DIR` produces zero name conflicts: v8.0a installs as `eq3nr`, `eq6`, `eqpt`, `xcon3`, `xcon6`; DEW installs as `dew-eq3`, `dew-eq6`, `dew-eqpt`, `dew-supcrt`, `dew-cprons92`.

### Farm build

`make farm` builds packages on all three platforms in parallel. Before use, copy
`ssh_build_farm.mk.example` to `ssh_build_farm.mk` (gitignored) and fill in your builder
hostnames. The file is never committed — hostnames stay out of git.

- Pushes the current commit to the remote
- Each platform runs `platform-build` via its `*_CONNECTION` variable: empty string for the
  local machine, `ssh <host>` (or `ssh <host> env PATH=...` for Mac) for remote machines
- Fedora: RPMs via `make rpm rpm-dew`
- Ubuntu: .deb packages via `make deb deb-dew`
- Mac: Homebrew install via `make brew brew-dew`
- Output from each machine is buffered and printed as a complete block when it finishes

`*_CONNECTION` and `*_FARM_REPO` are defined directly in `ssh_build_farm.mk` — empty
string for the local machine, `ssh host ...` for remote. `platform-build` includes a
`sync` step that pulls the latest commit on whichever machine runs it, using that
machine's `REPO_URL` from its own `ssh_build_farm.mk`, so pull authentication is
resolved on the builder rather than the initiating machine.

## Architecture

### v8.0a variant (`bin/`)

Five executables, each linking against shared libraries compiled from `src/`:

| Executable | Purpose | Libraries |
|---|---|---|
| `eq3nr` | Equilibrium speciation (no reaction) | eqlibu + eqlibg + eqlib |
| `eq6` | Reaction path modeling | eqlibu + eqlibg + eqlib |
| `eqpt` | Property estimation | eqlibu only |
| `xcon3` | Input file converter for eq3nr | eqlibu only |
| `xcon6` | Input file converter for eq6 | eqlibu only |

Source directories (all under `src/`, gitignored, generated by `make extract`):
- `eqlibu/src/`, `eqlibg/src/`, `eqlib/src/` — shared libraries
- `eq3nr/src/`, `eq6/src/`, `eqpt/src/`, `xcon3/src/`, `xcon6/src/` — programs
- `eqlib/inc/`, `xcon3/inc/`, `xcon6/inc/` — include headers

**EQ6 module dependency**: `eq6/src/mod6pt.f` and `eq6/src/mod6xf.f` are Fortran modules that must compile first (producing `obj/mod6pt.mod` and `obj/mod6xf.mod`). They are listed in `EQ6_MODULE_SRCS` in `sources.mk`; the order-only prerequisite rule in the Makefile enforces this.

**`sources.mk`**: Tracked file containing the static list of all 496 v8.0a `.f` source basenames across the 8 component directories. Generated and validated by:
- `make regen-sources` — regenerate from the extracted tree (run after a submodule bump, then review `git diff sources.mk` and commit alongside the submodule pointer change)
- `make check-sources` — validate the live extracted tree matches `sources.mk`; also runs automatically as part of `make test`

### DEW variant (`bin-dew/`)

Five executables compiled from `upstream-dew/` (SUPCRTandEQs, branch `DEW_activities`).
All link statically against `obj-dew/libeq_dew.a` (built from `eqlibr136.f`), except
SUPCRT and CPRONS which are standalone.

| Executable | Source | Purpose |
|---|---|---|
| `eqpt` | `EQPT/eqpt.f` + `eqlibr136.f` | DATA0→data1 preprocessor (R71) |
| `eq3` | `EQ3/eq3nr110.f` + `eqlibr136.f` | EQ3 speciation (R110) |
| `eq6` | `EQ6/eq6r100.f` + `eqlibr136.f` | EQ6 mass transfer (R100) |
| `supcrt` | `SUPCRT/sup92pc.f` + 3 others | SUPCRT92 thermodynamic calculator |
| `cprons92` | `CPRONS/cprons92.f` | sprons sequential→direct access converter |

Key data files in `upstream-dew/` (not installed by `make build-dew`, use directly):
- `upstream-dew/EQPT/DATA0` — DEW thermodynamic database (required by `eqpt` and `eq3`/`eq6`)
- `upstream-dew/CPRONS/sprons93` — SUPCRT sequential property data (input for `cprons92`)

**Compile flags**: `-ffixed-line-length-none` allows the DEW sources (written for f2c) to
use lines longer than the standard 72-column F77 limit. `patches/dew-*.patch` correct
gfortran-15-incompatible constructs; each patch targets a specific upstream bug and is
intended to be submitted upstream.

## Repo layout

```
upstream/          git submodule → llnl/EQ3_6 (contains the ZIP archives)
upstream-dew/      git submodule → gitlab.com/ENKI-portal/SUPCRTandEQs (DEW_activities)
patches/           source patches applied before DEW compilation (dew-*.patch)
pkg/
  rpm/eq3_6.spec.in      RPM spec template for v8.0a (generated: eq3_6.spec)
  rpm/eq3_6_dew.spec.in  RPM spec template for DEW variant (generated: eq3_6_dew.spec)
  deb/debian/            Debian package metadata (control, *.in templates → generated control.*)

  brew/eq3_6.rb.in       Homebrew formula template for v8.0a (generated: eq3_6.rb)
  brew/eq3_6_dew.rb.in   Homebrew formula template for DEW variant (generated: eq3_6_dew.rb)
src/               (gitignored) extracted Fortran source (v8.0a)
bin/               (gitignored) compiled v8.0a executables
obj/               (gitignored) v8.0a object files and .mod files
bin-dew/           (gitignored) compiled DEW variant executables
obj-dew/           (gitignored) DEW object files and patch stamp
sources.mk         static source file lists for v8.0a (tracked; update with make regen-sources)
tools/gen_sources.py  generates sources.mk from extracted src/ tree
```

## Documentation

PDFs are not stored in the repo. Fetch them with `make docs` (downloads to `docs/`, gitignored):

| File | OSTI ID | Title |
|---|---|---|
| `docs/138894.pdf` | [138894](https://www.osti.gov/biblio/138894) | Part 1: EQ3/6 overview and installation guide |
| `docs/138639.pdf` | [138639](https://www.osti.gov/biblio/138639) | Part 2: EQPT user's guide |
| `docs/138643.pdf` | [138643](https://www.osti.gov/biblio/138643) | Part 3: EQ3NR theoretical manual and user's guide |
| `docs/138820.pdf` | [138820](https://www.osti.gov/biblio/138820) | Part 4: EQ6 theoretical manual and user's guide |

- `upstream/ReadMe.md` — Upstream distribution notes

## macOS setup (from scratch)

Tested on macOS 15 Sequoia, Intel x86_64. Apple Silicon should work identically
(Homebrew installs to `/opt/homebrew` instead of `/usr/local`).

**1. Xcode Command Line Tools** (provides `git`, `make`, `clang`, `curl`):
```bash
xcode-select --install
```
Skip if `xcode-select -p` already returns a path.

**2. Homebrew** (https://brew.sh):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Follow any post-install instructions shown (e.g., adding brew to `$PATH`).

**3. Clone the repo**:
```bash
git clone --recurse-submodules https://github.com/jonnyprouty/EQ3_6-dist.git
cd EQ3_6-dist
```

**4. Build and install via Homebrew**:
```bash
make brew
```
This stages the formula into a local Homebrew tap and runs
`brew install --build-from-source`. Homebrew will automatically install `gcc`
(which provides `gfortran`) if not already present. Build takes ~2 minutes.

**5. Verify**:
```bash
brew test eq3_6     # Homebrew smoke test
eq3nr               # confirm in PATH
```

**6. Run the test suite** (optional):
```bash
brew install bats-core
make test
```

**Notes:**
- `gfortran` comes from Homebrew's `gcc` formula — system Xcode does not include it.
- Homebrew 4+ requires formulae to be in a tap; `make brew` handles this automatically
  by creating a local tap at `$(brew --repository)/Library/Taps/local/homebrew-eq3-6/`.
- SSH sessions may have a minimal `$PATH` that excludes `/usr/local/bin`. Either source
  your shell profile or prefix commands with `PATH="/usr/local/bin:$PATH"`.
- `make test` requires `bats-core`; SSH sessions need `export PATH=/usr/local/bin:$PATH`
  if `bats` is not found.

## Template policy

Any packaging file that contains version strings, compiler flags, architecture tokens,
or other Makefile-controlled values must use the `.in` template system:

1. Create a `<name>.in` file with `@@TOKEN@@` placeholders.
2. Add a generation rule to the Makefile (see the `pkg/rpm/eq3_6.spec` rule as the
   canonical pattern).
3. Add the generated output to `.gitignore` and to `distclean`.
4. Add the generated output as a prerequisite of the `generate` target.

Tokens available: `@@VERSION@@`, `@@DEW_VERSION@@`, `@@FC@@`, `@@FFLAGS@@`,
`@@LDFLAGS@@`, `@@DEB_ARCH@@`, `@@DEW_SRC_URL@@`, `@@DEW_SHA256@@`.

Candidates include RPM spec files, Homebrew formulae, and `.deb` binary control files.
Static metadata (package descriptions, `Architecture: all` for arch-independent docs)
does not need templating.

When reviewing a proposed new packaging file, check: does it contain any of the values
listed above hard-coded? If yes, make it a `.in` template instead.

## Ubuntu 26.04 LTS build setup

For building `.deb` packages on Ubuntu Server 26.04 LTS (recommended over Desktop —
same repos, ~2 GB lighter):

```bash
sudo apt update
sudo apt install -y gfortran dpkg-dev bats
```

To verify static Fortran runtime libraries are available (required for
`-static-libgfortran -static-libgcc`):
```bash
dpkg -L libgfortran-dev | grep '\.a$'
```

After cloning, run `make generate` before any deb targets — this produces the binary
control files from `.in` templates using the local architecture.

## Design decisions

When a non-obvious design choice is made during a task, record the rationale here before
closing the task — not in TODO.md checked-off items or commit messages alone, where it
becomes hard to find. If the decision is already covered by existing policy in this file,
no separate entry is needed.

### Testing

**Per-platform exact refs, not floating-point tolerance**
EQ6 ODE path divergence across gfortran builds (Fedora RPM vs Ubuntu apt vs Homebrew) is
genuine predictor-corrector step divergence, not rounding noise — a tolerance band would
mask real regressions. Reference outputs live in `tests/testlib/expected/{linux,ubuntu,mac}/`
and `tests/dew/expected/{linux,ubuntu,mac}/`.

**Platform tags: `linux`, `ubuntu`, `mac`**
`linux` = Fedora (baseline). `ubuntu` = Ubuntu apt gfortran (different ODE paths). `mac` =
Homebrew gfortran. Detected in `tests/lib/helpers.bash` and all `tools/regen_*_refs.sh`
scripts via `/etc/os-release`. Only differing refs are committed per platform; identical
cases fall through to the `linux/` fallback in `assert_output_matches_ref`.

**`test-testlib` must use `build` (PHONY), not `$(TARGETS)` directly**
Make evaluates pattern rules at graph-parse time. If `src/` hasn't been extracted yet,
`$(OBJ_DIR)/%.o` has no matching rule even with `$(EXTRACT_STAMP)` listed as a prerequisite.
The two-phase `build` PHONY ensures extraction completes before the sub-make schedules
compilation. `test-dew` can use `$(DEW_TARGETS)` directly because DEW sources are committed
files in the submodule, not dynamically extracted.

**Packaging-time test checks**
RPM `%check`, deb `rules`, and Homebrew `test do` blocks remain as raw shell/Ruby —
packaging CI environments lack the test input files. `tests/cases/packaging/packaging_checks.bats`
validates the same logic against locally-installed binaries.

### DEW variant compatibility

**DEW DATA0 and data1 are incompatible with v8.0a**
DEW DATA0 uses the old R71 format: explicit NCT/NSQ count header, no `basis species`
section. v8.0a EQPT scans for `basis species` and hits EOF. DEW data1 binaries additionally
use 8-byte Fortran record markers vs. our gfortran's 4-byte, and the internal data1
structure changed between R71 and v8.0a. Pre-built `data1` files included in each DEW ZIP
are usable directly without re-running EQPT.

**DEW and v8.0a are parallel non-interoperating tracks**
pyDEW generates R71-format DATA0 (same old format), not v8.0a-compatible. The pyDEW
container bundles its own x86-64 Linux R71 EQPT/EQ3/EQ6; `pyDEW.Fluid()` uses those
internally. The DEW EQPT binaries distributed in ZIPs (2025) are ARM64 (Apple Silicon)
only — they will not run on Intel Macs or Linux.

**DEW EQPT requires piped stdin**
DEW EQPT requires three interactive prompts (`n/n/y` for Pitzer/HKF/data0s). Running
without piped answers causes a `fmt: end of file` crash. `tools/run_dew_eqpt.sh` wraps
this correctly for Apple Silicon users.

### Farm build

**`REPO_URL` defaults to HTTPS**
Remote farm machines pull without SSH keys. Only override with SSH in `ssh_build_farm.mk`
if the builder has keys configured. The `sync` prereq of `platform-build` runs on the
target machine and reads its own `REPO_URL`, so authentication is resolved locally on
each builder rather than being inherited from the initiating machine.

**`*_CONNECTION` set directly — no `CURRENT_HOST` comparison**
`ssh_build_farm.mk` defines `FEDORA_CONNECTION`, `UBUNTU_CONNECTION`, `MAC_CONNECTION`
as empty string (local) or `ssh host ...` (remote). The old `FEDORA_BUILDER` /
`CURRENT_HOST` / `ifeq` machinery that derived connections from hostname comparisons
has been removed.

---

## TODO list

Before starting any task, read `TODO.md`. Ensure the approach chosen is compatible with the
goals listed there, and ideally moves them forward. Avoid design choices that would make
future items harder — for example, don't structure tests in a way that won't scale to 170+
cases or that can't be migrated to BATS. TODO items don't need to be completed in every
task, but we should not paint ourselves into a corner.

## Git workflow

Always create a new branch before making any changes. Work on the branch until the change is confirmed complete, then merge it into `main`.

```bash
git checkout -b <branch-name>   # start work
# ... make changes, commit ...
git checkout main
git merge <branch-name>         # merge when complete
git branch -d <branch-name>
```
