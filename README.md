# EQ3/6-dist

Packaging for [EQ3/6 v8.0a](https://github.com/llnl/EQ3_6), the geochemical
equilibrium modeling software developed at Lawrence Livermore National
Laboratory. This repo builds and packages the **unmodified** upstream source
for Linux (RPM, .deb) and macOS (Homebrew).

## What is EQ3/6?

EQ3/6 is a software package for geochemical modeling of aqueous solutions
interacting with minerals, gases, and other solids. It provides five
executables:

| Executable | Purpose |
|---|---|
| `eq3nr` | Speciation / no-reaction calculation |
| `eq6` | Reaction path modeling |
| `eqpt` | Property estimation |
| `xcon3` | Input file format converter for eq3nr |
| `xcon6` | Input file format converter for eq6 |

## Installation

### RPM (Fedora / RHEL / Rocky)

```bash
sudo rpm -i eq3-6-8.0a-1.fc43.x86_64.rpm
```

### Debian / Ubuntu

```bash
sudo dpkg -i eq3-6_8.0a_amd64.deb
```

### Homebrew (macOS and Linux)

```bash
brew install --build-from-source pkg/brew/eq3_6.rb
```

### Build from source

Requirements: `gfortran`, `make`, `unzip`, `curl`

```bash
git clone --recurse-submodules https://github.com/jonnyprouty/EQ3_6-dist.git
cd EQ3_6-dist
make fetch    # initialize upstream submodule (if not cloned with --recurse-submodules)
make          # extract and compile all executables to bin/
```

Executables are written to `bin/`. To install symlinks into a directory on
your `PATH`:

```bash
make symlinks LINK_DIR=~/.local/bin
```

## Documentation

PDF documentation can be downloaded from OSTI:

```bash
make docs     # downloads to docs/
```

| Document | OSTI ID |
|---|---|
| Part 1: EQ3/6 overview and installation guide | [138894](https://www.osti.gov/biblio/138894) |
| Part 2: EQPT user's guide | [138639](https://www.osti.gov/biblio/138639) |
| Part 3: EQ3NR theoretical manual and user's guide | [138643](https://www.osti.gov/biblio/138643) |
| Part 4: EQ6 theoretical manual and user's guide | [138820](https://www.osti.gov/biblio/138820) |

## Upstream

The EQ3/6 source is provided by LLNL at https://github.com/llnl/EQ3_6 and is
referenced here as a git submodule. No modifications are made to the upstream
code; this repo contains only build and packaging infrastructure.

## License

The build and packaging scripts in this repository are licensed under the
[BSD 3-Clause License](LICENSE). The EQ3/6 software itself is distributed
under separate terms by Lawrence Livermore National Laboratory; see `NOTICE.txt`
within the upstream distribution.
