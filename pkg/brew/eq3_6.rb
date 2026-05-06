class Eq36 < Formula
  desc "EQ3/6 geochemical equilibrium modeling software"
  homepage "https://github.com/llnl/EQ3_6"
  url "https://github.com/llnl/EQ3_6/raw/HEAD/EQ36_80a_Linux.zip"
  sha256 "1d97b03aaf7c2f9fa22fe4dd95defb62d11e78e26dd8295d83ced02628d2f3bf"
  version "8.0a"
  license :cannot_represent  # LLNL distribution terms; see NOTICE.txt

  # Homebrew's gcc formula provides gfortran on both macOS and Linux.
  # The system Xcode on macOS does not include gfortran.
  depends_on "gcc"

  def install
    # The ZIP's inner archsrc.tar stores all .f and .h files as .f.gz / .h.gz.
    # gfortran cannot compile compressed files — gunzip is required before build.
    src = buildpath/"eq36src"
    src.mkpath
    system "sh", "-c",
           "unzip -p '#{cached_download}' Linux/EQ3_6v8.0a/archsrc.tar" \
           " | tar -xf - -C '#{src}'"
    system "find", src.to_s, "-name", "*.gz", "-exec", "gunzip", "{}", ";"

    obj = buildpath/"obj"
    obj.mkpath

    # Resolve the versioned gfortran binary from the Homebrew gcc formula.
    gcc_version = Formula["gcc"].any_installed_version.major
    gfortran = Formula["gcc"].opt_bin/"gfortran-#{gcc_version}"

    compile_dir = lambda do |component|
      Dir["#{src}/#{component}/src/*.f"].sort.each do |f|
        system gfortran, "-O2", "-c", f,
               "-o", "#{obj}/#{File.basename(f, ".f")}.o",
               "-J#{obj}"
      end
    end

    # Compile shared libraries first (dependency order matters).
    compile_dir.call("eqlibu")
    compile_dir.call("eqlibg")
    compile_dir.call("eqlib")
    compile_dir.call("eq3nr")

    # EQ6: Fortran module files must precede all other eq6 sources.
    system gfortran, "-O2", "-c", "#{src}/eq6/src/mod6pt.f",
           "-o", "#{obj}/mod6pt.o", "-J#{obj}"
    system gfortran, "-O2", "-c", "#{src}/eq6/src/mod6xf.f",
           "-o", "#{obj}/mod6xf.o", "-J#{obj}"
    Dir["#{src}/eq6/src/*.f"].sort.reject { |f|
      f.end_with?("mod6pt.f", "mod6xf.f")
    }.each do |f|
      system gfortran, "-O2", "-c", f,
             "-o", "#{obj}/#{File.basename(f, ".f")}.o",
             "-J#{obj}"
    end

    compile_dir.call("eqpt")
    compile_dir.call("xcon3")
    compile_dir.call("xcon6")

    # Collect .o files produced by a source directory.
    objs_for = lambda do |component|
      Dir["#{src}/#{component}/src/*.f"].map do |f|
        "#{obj}/#{File.basename(f, ".f")}.o"
      end
    end

    eqlibu_o = objs_for.call("eqlibu")
    eqlibg_o = objs_for.call("eqlibg")
    eqlib_o  = objs_for.call("eqlib")
    eq6_mod_o = ["#{obj}/mod6pt.o", "#{obj}/mod6xf.o"]
    eq6_other_o = Dir["#{src}/eq6/src/*.f"].reject { |f|
      f.end_with?("mod6pt.f", "mod6xf.f")
    }.map { |f| "#{obj}/#{File.basename(f, ".f")}.o" }

    {
      "eq3nr" => eqlibu_o + eqlibg_o + eqlib_o + objs_for.call("eq3nr"),
      "eq6"   => eqlibu_o + eqlibg_o + eqlib_o + eq6_mod_o + eq6_other_o,
      "eqpt"  => eqlibu_o + objs_for.call("eqpt"),
      "xcon3" => eqlibu_o + objs_for.call("xcon3"),
      "xcon6" => eqlibu_o + objs_for.call("xcon6"),
    }.each do |exe, objs|
      system gfortran, "-O2", "-o", exe, *objs
      bin.install exe
    end
  end

  test do
    # Each executable exits non-zero when run without input, but should
    # print identifying text before failing.
    output = shell_output("#{bin}/eq3nr 2>&1; true")
    assert_match "8.0a", output
  end
end
