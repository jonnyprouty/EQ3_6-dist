Name:           eq3-6
Version:        8.0a
Release:        1%{?dist}
Summary:        EQ3/6 geochemical equilibrium modeling software

# The upstream distribution does not include a separate LICENSE file;
# the license terms are embedded in the source archive documentation.
License:        See NOTICE.txt in upstream distribution (BSD-3-Clause)
URL:            https://github.com/llnl/EQ3_6
Source0:        EQ36_80a_Linux.zip
Source1:        https://www.osti.gov/servlets/purl/138894#eq3-6-install-guide.pdf
Source2:        https://www.osti.gov/servlets/purl/138639#eq3-6-eqpt-guide.pdf
Source3:        https://www.osti.gov/servlets/purl/138643#eq3-6-eq3nr-manual.pdf
Source4:        https://www.osti.gov/servlets/purl/138820#eq3-6-eq6-manual.pdf

BuildRequires:  gcc-gfortran
BuildRequires:  unzip
BuildRequires:  findutils

# Standalone Fortran executables; no explicit Requires beyond libgfortran,
# which rpmbuild detects automatically via find-requires.

%package doc
Summary:        Documentation for EQ3/6 geochemical modeling software
BuildArch:      noarch
License:        See NOTICE.txt in upstream distribution (BSD-3-Clause)

%description doc
PDF documentation for EQ3/6 v8.0a:
  - Part 1: EQ3/6 package overview and installation guide (OSTI 138894)
  - Part 2: EQPT user's guide (OSTI 138639)
  - Part 3: EQ3NR theoretical manual and user's guide (OSTI 138643)
  - Part 4: EQ6 theoretical manual and user's guide (OSTI 138820)

%description
EQ3/6 v8.0a is a software package for geochemical modeling of aqueous
solutions interacting with minerals, gases, and other solids. Originally
developed at Lawrence Livermore National Laboratory.

Includes five executables:
  eq3nr  - speciation / no-reaction calculation
  eq6    - reaction path modeling
  eqpt   - property estimation
  xcon3  - input file format converter for eq3nr
  xcon6  - input file format converter for eq6

%prep
# The ZIP's inner archsrc.tar stores every .f and .h source file as
# .f.gz / .h.gz.  Extract the tar, then gunzip everything before build.
mkdir -p eq36src
unzip -p %{SOURCE0} Linux/EQ3_6v8.0a/archsrc.tar | tar -xf - -C eq36src/
find eq36src -name '*.gz' | xargs gunzip

%build
FC=gfortran
FFLAGS="-O2"
OBJ="%{_builddir}/%{name}-%{version}/obj"
mkdir -p "${OBJ}" bin

compile_dir() {
    local srcdir="$1"
    for f in "${srcdir}"/*.f; do
        [ -f "${f}" ] || continue
        ${FC} ${FFLAGS} -c "${f}" \
              -o "${OBJ}/$(basename "${f%.f}").o" \
              -J"${OBJ}"
    done
}

# Compile in dependency order: shared libs first, then programs.
compile_dir eq36src/eqlibu/src
compile_dir eq36src/eqlibg/src
compile_dir eq36src/eqlib/src
compile_dir eq36src/eq3nr/src

# EQ6: Fortran module files must precede all other eq6 sources.
${FC} ${FFLAGS} -c eq36src/eq6/src/mod6pt.f \
      -o "${OBJ}/mod6pt.o" -J"${OBJ}"
${FC} ${FFLAGS} -c eq36src/eq6/src/mod6xf.f \
      -o "${OBJ}/mod6xf.o" -J"${OBJ}"
for f in eq36src/eq6/src/*.f; do
    base="$(basename "${f%.f}")"
    [ "${base}" = "mod6pt" ] || [ "${base}" = "mod6xf" ] && continue
    ${FC} ${FFLAGS} -c "${f}" \
          -o "${OBJ}/${base}.o" -J"${OBJ}"
done

compile_dir eq36src/eqpt/src
compile_dir eq36src/xcon3/src
compile_dir eq36src/xcon6/src

# Helper: list .o files produced by a source directory
objs_for() {
    local srcdir="$1"
    for f in "${srcdir}"/*.f; do
        [ -f "${f}" ] && echo "${OBJ}/$(basename "${f%.f}").o"
    done
}

EQLIBU_O=$(objs_for eq36src/eqlibu/src)
EQLIBG_O=$(objs_for eq36src/eqlibg/src)
EQLIB_O=$(objs_for eq36src/eqlib/src)

${FC} ${FFLAGS} -o bin/eq3nr \
      ${EQLIBU_O} ${EQLIBG_O} ${EQLIB_O} \
      $(objs_for eq36src/eq3nr/src)

EQ6_OTHER_O=$(for f in eq36src/eq6/src/*.f; do
    base="$(basename "${f%.f}")"
    [ "${base}" = "mod6pt" ] || [ "${base}" = "mod6xf" ] && continue
    echo "${OBJ}/${base}.o"
done)
${FC} ${FFLAGS} -o bin/eq6 \
      ${EQLIBU_O} ${EQLIBG_O} ${EQLIB_O} \
      "${OBJ}/mod6pt.o" "${OBJ}/mod6xf.o" ${EQ6_OTHER_O}

${FC} ${FFLAGS} -o bin/eqpt  ${EQLIBU_O} $(objs_for eq36src/eqpt/src)
${FC} ${FFLAGS} -o bin/xcon3 ${EQLIBU_O} $(objs_for eq36src/xcon3/src)
${FC} ${FFLAGS} -o bin/xcon6 ${EQLIBU_O} $(objs_for eq36src/xcon6/src)

%install
install -d %{buildroot}%{_bindir}
install -m 755 bin/eq3nr  %{buildroot}%{_bindir}/eq3nr
install -m 755 bin/eq6    %{buildroot}%{_bindir}/eq6
install -m 755 bin/eqpt   %{buildroot}%{_bindir}/eqpt
install -m 755 bin/xcon3  %{buildroot}%{_bindir}/xcon3
install -m 755 bin/xcon6  %{buildroot}%{_bindir}/xcon6

install -d %{buildroot}%{_docdir}/%{name}
install -m 644 %{SOURCE1} %{buildroot}%{_docdir}/%{name}/138894.pdf
install -m 644 %{SOURCE2} %{buildroot}%{_docdir}/%{name}/138639.pdf
install -m 644 %{SOURCE3} %{buildroot}%{_docdir}/%{name}/138643.pdf
install -m 644 %{SOURCE4} %{buildroot}%{_docdir}/%{name}/138820.pdf

%files
%{_bindir}/eq3nr
%{_bindir}/eq6
%{_bindir}/eqpt
%{_bindir}/xcon3
%{_bindir}/xcon6

%files doc
%{_docdir}/%{name}/138894.pdf
%{_docdir}/%{name}/138639.pdf
%{_docdir}/%{name}/138643.pdf
%{_docdir}/%{name}/138820.pdf

%changelog
* Wed May 06 2026 Packager <packager@example.com> - 8.0a-1
- Initial RPM packaging of EQ3/6 v8.0a
