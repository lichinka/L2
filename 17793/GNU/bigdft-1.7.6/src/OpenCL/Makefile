# Makefile.in generated by automake 1.14.1 from Makefile.am.
# src/OpenCL/Makefile.  Generated from Makefile.in by configure.

# Copyright (C) 1994-2013 Free Software Foundation, Inc.

# This Makefile.in is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.




am__is_gnu_make = test -n '$(MAKEFILE_LIST)' && test -n '$(MAKELEVEL)'
am__make_running_with_option = \
  case $${target_option-} in \
      ?) ;; \
      *) echo "am__make_running_with_option: internal error: invalid" \
              "target option '$${target_option-}' specified" >&2; \
         exit 1;; \
  esac; \
  has_opt=no; \
  sane_makeflags=$$MAKEFLAGS; \
  if $(am__is_gnu_make); then \
    sane_makeflags=$$MFLAGS; \
  else \
    case $$MAKEFLAGS in \
      *\\[\ \	]*) \
        bs=\\; \
        sane_makeflags=`printf '%s\n' "$$MAKEFLAGS" \
          | sed "s/$$bs$$bs[$$bs $$bs	]*//g"`;; \
    esac; \
  fi; \
  skip_next=no; \
  strip_trailopt () \
  { \
    flg=`printf '%s\n' "$$flg" | sed "s/$$1.*$$//"`; \
  }; \
  for flg in $$sane_makeflags; do \
    test $$skip_next = yes && { skip_next=no; continue; }; \
    case $$flg in \
      *=*|--*) continue;; \
        -*I) strip_trailopt 'I'; skip_next=yes;; \
      -*I?*) strip_trailopt 'I';; \
        -*O) strip_trailopt 'O'; skip_next=yes;; \
      -*O?*) strip_trailopt 'O';; \
        -*l) strip_trailopt 'l'; skip_next=yes;; \
      -*l?*) strip_trailopt 'l';; \
      -[dEDm]) skip_next=yes;; \
      -[JT]) skip_next=yes;; \
    esac; \
    case $$flg in \
      *$$target_option*) has_opt=yes; break;; \
    esac; \
  done; \
  test $$has_opt = yes
am__make_dryrun = (target_option=n; $(am__make_running_with_option))
am__make_keepgoing = (target_option=k; $(am__make_running_with_option))
pkgdatadir = $(datadir)/bigdft
pkgincludedir = $(includedir)/bigdft
pkglibdir = $(libdir)/bigdft
pkglibexecdir = $(libexecdir)/bigdft
am__cd = CDPATH="$${ZSH_VERSION+.}$(PATH_SEPARATOR)" && cd
install_sh_DATA = $(install_sh) -c -m 644
install_sh_PROGRAM = $(install_sh) -c
install_sh_SCRIPT = $(install_sh) -c
INSTALL_HEADER = $(INSTALL_DATA)
transform = $(program_transform_name)
NORMAL_INSTALL = :
PRE_INSTALL = :
POST_INSTALL = :
NORMAL_UNINSTALL = :
PRE_UNINSTALL = :
POST_UNINSTALL = :
build_triplet = x86_64-unknown-linux-gnu
host_triplet = x86_64-unknown-linux-gnu
EXTRA_PROGRAMS = conv_check$(EXEEXT) conv_check_fft$(EXEEXT) \
	bench_conv$(EXEEXT) bench_conv_quick$(EXEEXT) \
	bench_zgemm$(EXEEXT) stream_check$(EXEEXT)
#am__append_1 = -Wl,-rpath=$(abs_top_builddir)/src
am__append_2 = -labinit -lxcf90 -lxc   -lOpenCL -lm -lstdc++  -L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm  $(top_builddir)/yaml-0.1.4/src/.libs/libyaml.a   
subdir = src/OpenCL
DIST_COMMON = $(srcdir)/Makefile.in $(srcdir)/Makefile.am \
	$(top_srcdir)/config/depcomp
ACLOCAL_M4 = $(top_srcdir)/aclocal.m4
am__aclocal_m4_deps = $(top_srcdir)/config/m4/defs.m4 \
	$(top_srcdir)/config/m4/flush.m4 \
	$(top_srcdir)/config/m4/fortran.m4 \
	$(top_srcdir)/config/m4/pic.m4 $(top_srcdir)/config/m4/pkg.m4 \
	$(top_srcdir)/configure.ac
am__configure_deps = $(am__aclocal_m4_deps) $(CONFIGURE_DEPENDENCIES) \
	$(ACLOCAL_M4)
mkinstalldirs = $(install_sh) -d
CONFIG_HEADER = $(top_builddir)/config.h
CONFIG_CLEAN_FILES =
CONFIG_CLEAN_VPATH_FILES =
LIBRARIES = $(noinst_LIBRARIES)
ARFLAGS = cru
AM_V_AR = $(am__v_AR_$(V))
am__v_AR_ = $(am__v_AR_$(AM_DEFAULT_VERBOSITY))
am__v_AR_0 = @echo "  AR      " $@;
am__v_AR_1 = 
libOpenCL_a_AR = $(AR) $(ARFLAGS)
libOpenCL_a_LIBADD =
am__libOpenCL_a_SOURCES_DIST = Stream.h Tool.h bench_lib.h \
	OpenCL_wrappers.c OpenCL_wrappers.h MagicFilter.c \
	MagicFilter.h MagicFilter_Generator.cpp \
	MagicFilter_Generator.h Kinetic.c Kinetic.h \
	Kinetic_Generator.cpp Kinetic_Generator.h Kinetic_k.h \
	Kinetic_k_Generator.cpp Kinetic_k_Generator.h Wavelet.c \
	Wavelet.h Wavelet_Generator.cpp Wavelet_Generator.h \
	Uncompress.c Uncompress.h Initialize.c Initialize.h \
	Profiling.c Hamiltonian.c Reduction.c Reduction.h \
	Reduction_Generator.cpp Reduction_Generator.h Preconditioner.c \
	Density.c dsfft.c fft_generator_noshared.cpp fft_noshared.c \
	fft_generator_helper.cpp dsfft_generator.cpp fft_generator.h \
	Benchmark.c Benchmark_Generator.cpp Benchmark_Generator.h
am__objects_1 = OpenCL_wrappers.$(OBJEXT) \
	MagicFilter.$(OBJEXT) \
	MagicFilter_Generator.$(OBJEXT) \
	Kinetic.$(OBJEXT) Kinetic_Generator.$(OBJEXT) \
	Kinetic_k_Generator.$(OBJEXT) Wavelet.$(OBJEXT) \
	Wavelet_Generator.$(OBJEXT) Uncompress.$(OBJEXT) \
	Initialize.$(OBJEXT) Profiling.$(OBJEXT) \
	Hamiltonian.$(OBJEXT) Reduction.$(OBJEXT) \
	Reduction_Generator.$(OBJEXT) \
	Preconditioner.$(OBJEXT) Density.$(OBJEXT) \
	dsfft.$(OBJEXT) fft_generator_noshared.$(OBJEXT) \
	fft_noshared.$(OBJEXT) \
	fft_generator_helper.$(OBJEXT) \
	dsfft_generator.$(OBJEXT) Benchmark.$(OBJEXT) \
	Benchmark_Generator.$(OBJEXT)
am_libOpenCL_a_OBJECTS = $(am__objects_1)
libOpenCL_a_OBJECTS = $(am_libOpenCL_a_OBJECTS)
am_bench_conv_OBJECTS = bench_conv.$(OBJEXT) bench_lib.$(OBJEXT)
bench_conv_OBJECTS = $(am_bench_conv_OBJECTS)
bench_conv_DEPENDENCIES =
am_bench_conv_quick_OBJECTS = bench_conv_quick.$(OBJEXT) \
	bench_lib.$(OBJEXT)
bench_conv_quick_OBJECTS = $(am_bench_conv_quick_OBJECTS)
bench_conv_quick_DEPENDENCIES =
am_bench_zgemm_OBJECTS = bench_zgemm.$(OBJEXT) bench_lib.$(OBJEXT)
bench_zgemm_OBJECTS = $(am_bench_zgemm_OBJECTS)
bench_zgemm_DEPENDENCIES =
am_conv_check_OBJECTS = conv_check.$(OBJEXT)
conv_check_OBJECTS = $(am_conv_check_OBJECTS)
conv_check_DEPENDENCIES =
am_conv_check_fft_OBJECTS = conv_check_fft.$(OBJEXT)
conv_check_fft_OBJECTS = $(am_conv_check_fft_OBJECTS)
conv_check_fft_DEPENDENCIES =
am_stream_check_OBJECTS = Stream.$(OBJEXT) StreamCheck.$(OBJEXT)
stream_check_OBJECTS = $(am_stream_check_OBJECTS)
stream_check_DEPENDENCIES =
AM_V_P = $(am__v_P_$(V))
am__v_P_ = $(am__v_P_$(AM_DEFAULT_VERBOSITY))
am__v_P_0 = false
am__v_P_1 = :
AM_V_GEN = $(am__v_GEN_$(V))
am__v_GEN_ = $(am__v_GEN_$(AM_DEFAULT_VERBOSITY))
am__v_GEN_0 = @echo "  GEN     " $@;
am__v_GEN_1 = 
AM_V_at = $(am__v_at_$(V))
am__v_at_ = $(am__v_at_$(AM_DEFAULT_VERBOSITY))
am__v_at_0 = @
am__v_at_1 = 
DEFAULT_INCLUDES = -I. -I$(top_builddir)
depcomp = $(SHELL) $(top_srcdir)/config/depcomp
am__depfiles_maybe = depfiles
am__mv = mv -f
COMPILE = $(CC) $(DEFS) $(DEFAULT_INCLUDES) $(INCLUDES) $(AM_CPPFLAGS) \
	$(CPPFLAGS) $(AM_CFLAGS) $(CFLAGS)
AM_V_CC = $(am__v_CC_$(V))
am__v_CC_ = $(am__v_CC_$(AM_DEFAULT_VERBOSITY))
am__v_CC_0 = @echo "  CC      " $@;
am__v_CC_1 = 
CCLD = $(CC)
LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o $@
AM_V_CCLD = $(am__v_CCLD_$(V))
am__v_CCLD_ = $(am__v_CCLD_$(AM_DEFAULT_VERBOSITY))
am__v_CCLD_0 = @echo "  CCLD    " $@;
am__v_CCLD_1 = 
CXXCOMPILE = $(CXX) $(DEFS) $(DEFAULT_INCLUDES) $(INCLUDES) \
	$(AM_CPPFLAGS) $(CPPFLAGS) $(AM_CXXFLAGS) $(CXXFLAGS)
AM_V_CXX = $(am__v_CXX_$(V))
am__v_CXX_ = $(am__v_CXX_$(AM_DEFAULT_VERBOSITY))
am__v_CXX_0 = @echo "  CXX     " $@;
am__v_CXX_1 = 
CXXLD = $(CXX)
CXXLINK = $(CXXLD) $(AM_CXXFLAGS) $(CXXFLAGS) $(AM_LDFLAGS) $(LDFLAGS) \
	-o $@
AM_V_CXXLD = $(am__v_CXXLD_$(V))
am__v_CXXLD_ = $(am__v_CXXLD_$(AM_DEFAULT_VERBOSITY))
am__v_CXXLD_0 = @echo "  CXXLD   " $@;
am__v_CXXLD_1 = 
FCCOMPILE = $(FC) $(AM_FCFLAGS) $(FCFLAGS)
AM_V_FC = $(am__v_FC_$(V))
am__v_FC_ = $(am__v_FC_$(AM_DEFAULT_VERBOSITY))
am__v_FC_0 = @echo "  FC      " $@;
am__v_FC_1 = 
FCLD = $(FC)
FCLINK = $(FCLD) $(AM_FCFLAGS) $(FCFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o \
	$@
AM_V_FCLD = $(am__v_FCLD_$(V))
am__v_FCLD_ = $(am__v_FCLD_$(AM_DEFAULT_VERBOSITY))
am__v_FCLD_0 = @echo "  FCLD    " $@;
am__v_FCLD_1 = 
SOURCES = $(libOpenCL_a_SOURCES) $(bench_conv_SOURCES) \
	$(bench_conv_quick_SOURCES) $(bench_zgemm_SOURCES) \
	$(conv_check_SOURCES) $(conv_check_fft_SOURCES) \
	$(stream_check_SOURCES)
DIST_SOURCES = $(am__libOpenCL_a_SOURCES_DIST) $(bench_conv_SOURCES) \
	$(bench_conv_quick_SOURCES) $(bench_zgemm_SOURCES) \
	$(conv_check_SOURCES) $(conv_check_fft_SOURCES) \
	$(stream_check_SOURCES)
am__can_run_installinfo = \
  case $$AM_UPDATE_INFO_DIR in \
    n|no|NO) false;; \
    *) (install-info --version) >/dev/null 2>&1;; \
  esac
am__tagged_files = $(HEADERS) $(SOURCES) $(TAGS_FILES) $(LISP)
# Read a list of newline-separated strings from the standard input,
# and print each of them once, without duplicates.  Input order is
# *not* preserved.
am__uniquify_input = $(AWK) '\
  BEGIN { nonempty = 0; } \
  { items[$$0] = 1; nonempty = 1; } \
  END { if (nonempty) { for (i in items) print i; }; } \
'
# Make sure the list of sources is unique.  This is necessary because,
# e.g., the same source file might be shared among _SOURCES variables
# for different programs/libraries.
am__define_uniq_tagged_files = \
  list='$(am__tagged_files)'; \
  unique=`for i in $$list; do \
    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
  done | $(am__uniquify_input)`
ETAGS = etags
CTAGS = ctags
DISTFILES = $(DIST_COMMON) $(DIST_SOURCES) $(TEXINFOS) $(EXTRA_DIST)
ACLOCAL = aclocal-1.14
AMTAR = $${TAR-tar}
AM_DEFAULT_VERBOSITY = 1
AR = ar
AUTOCONF = autoconf
AUTOHEADER = autoheader
AUTOMAKE = automake-1.14
AWK = gawk
BIGDFT_MAJOR_VERSION = 1
BIGDFT_MICRO_VERSION = 6
BIGDFT_MINOR_VERSION = 7
BIGDFT_NANO_VERSION = 
BUILD_BINDINGS_END = */
BUILD_BINDINGS_START = /*
CC = cc
CCDEPMODE = depmode=gcc3
CFLAGS = -I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2
CONFIG_ARGS =  '--with-blas=no' '--with-lapack=no' '--with-scalapack=no' '--with-blacs=no' '--with-ext-linalg=-L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm' '--enable-opencl' '--with-ocl-path=/opt/nvidia/cudatoolkit6.5/default' 'CC=cc' 'CFLAGS=-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2' 'LDFLAGS=-O2' 'LIBS=-L/opt/cray/nvidia/default/lib64 -L/opt/nvidia/cudatoolkit6.5/default/' 'CXX=CC' 'FC=ftn' 'FCFLAGS=-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2' 'F77=ftn' 'FFLAGS=-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2'
CPP = 
CPPFLAGS = 
CUDA_INCLUDE = 
CUDA_INCLUDE_PATH = 
CUDA_PATH = 
CXX = CC
CXXDEPMODE = depmode=gcc3
CXXFLAGS = -g -O2
CYGPATH_W = echo
DEFS = -DHAVE_CONFIG_H
DEPDIR = .deps
DGEMMSY_CPPFLAGS = 
ECHO_C = 
ECHO_N = -n
ECHO_T = 
EGREP = 
EXEEXT = 
F77 = ftn
F90_1D_POINTER_SHIFT = 0
F90_1D_POINTER_SIZE = 6
F90_2D_POINTER_SHIFT = 0
F90_2D_POINTER_SIZE = 9
F90_3D_POINTER_SHIFT = 0
F90_3D_POINTER_SIZE = 12
F90_4D_POINTER_SHIFT = 0
F90_4D_POINTER_SIZE = 15
F90_5D_POINTER_SHIFT = 0
F90_5D_POINTER_SIZE = 18
FC = ftn
FCDEFS = 
FCFLAGS = -I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2
FCFLAGS_OPENMP = -fopenmp
FCFLAGS_f90 = 
FCLIBS =  
FFLAGS = -I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2
GDBUS_CFLAGS = 
GDBUS_LIBS = 
GLIB_CFLAGS = 
GLIB_END_FALSE = 
GLIB_END_TRUE = */
GLIB_FALSE = 
GLIB_LIBS = 
GLIB_TRUE = /*
GOBJECT_INTROSPECTION_CFLAGS = 
GOBJECT_INTROSPECTION_LIBS = 
GREP = 
G_IR_COMPILER = 
G_IR_SCANNER = 
INSTALL = /usr/bin/install -c
INSTALL_DATA = ${INSTALL} -m 644
INSTALL_PROGRAM = ${INSTALL}
INSTALL_SCRIPT = ${INSTALL}
INSTALL_STRIP_PROGRAM = $(install_sh) -c -s
LDFLAGS = -O2 -L/opt/nvidia/cudatoolkit6.5/default/lib -L$(top_builddir)/libxc-2.0.x/src/.libs -L$(top_builddir)/libABINIT/src 
LIBABINIT_INCLUDE =  -I$(top_builddir)/libABINIT/src
LIBETSFIO_INCLUDE = 
LIBOBJS = 
LIBS = -lrt -L/opt/cray/nvidia/default/lib64 -L/opt/nvidia/cudatoolkit6.5/default/ $(am__append_2)
LIBSGPU_INCLUDE = 
LIBS_EXT_DEPS =  -lOpenCL -lm -lstdc++  -L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm  $(top_builddir)/yaml-0.1.4/src/.libs/libyaml.a   
LIBS_SHORT_DEPS = -labinit -lxcf90 -lxc   -lOpenCL -lm -lstdc++  -L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm  $(top_builddir)/yaml-0.1.4/src/.libs/libyaml.a   
LIBXC_CFLAGS = -I/usr/include
LIBXC_INCLUDE = -I$(top_builddir)/libxc-2.0.x/src
LIBXC_LIBS = -lxcf90 -lxc
LIB_ARCHIVE_CFLAGS = 
LIB_ARCHIVE_LIBS = 
LIB_YAML_CFLAGS = -I$(top_srcdir)/yaml-0.1.4/include
LIB_YAML_LIBS = $(top_builddir)/yaml-0.1.4/src/.libs/libyaml.a
LINALG_LIBS = -L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm
LTLIBOBJS = 
MAKEINFO = makeinfo
MEMORY_LIMIT = 0
MKDIR_P = /bin/mkdir -p
MODULE_EXT = mod
MPI_INCLUDE = 
MPI_LDFLAGS = 
MPI_LIBS = 
NVCC = 
NVCC_FLAGS = 
OBJEXT = o
OCL_INCLUDE = -I/opt/nvidia/cudatoolkit6.5/default/include
OCL_INCLUDE_PATH = /opt/nvidia/cudatoolkit6.5/default/include
PACKAGE = bigdft
PACKAGE_BUGREPORT = Damien.Caliste@cea.fr
PACKAGE_NAME = BigDFT - DFT over wavelets
PACKAGE_STRING = BigDFT - DFT over wavelets 1.7.6
PACKAGE_TARNAME = bigdft
PACKAGE_URL = 
PACKAGE_VERSION = 1.7.6
PATH_SEPARATOR = :
PKG_CONFIG = /usr/bin/pkg-config
RANLIB = ranlib
RECL_INT_KIND = 16
SED = /usr/bin/sed
SET_MAKE = 
SHELL = /bin/sh
STRIP = 
VERSION = 1.7.6
abs_builddir = /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6/src/OpenCL
abs_srcdir = /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6/src/OpenCL
abs_top_builddir = /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6
abs_top_srcdir = /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6
ac_ct_CC = cc
ac_ct_CXX = 
ac_ct_F77 = 
ac_ct_FC = 
ac_have_doxygen = yes
ac_have_pdflatex = no
am__include = include
am__leading_dot = .
am__quote = 
am__tar = $${TAR-tar} chof - "$$tardir"
am__untar = $${TAR-tar} xf -
bindir = ${exec_prefix}/bin
build = x86_64-unknown-linux-gnu
build_alias = 
build_cpu = x86_64
build_os = linux-gnu
build_vendor = unknown
builddir = .
datadir = ${datarootdir}
datarootdir = ${prefix}/share
docdir = ${datarootdir}/doc/${PACKAGE_TARNAME}
dvidir = ${docdir}
exec_prefix = ${prefix}
girdir = 
host = x86_64-unknown-linux-gnu
host_alias = 
host_cpu = x86_64
host_os = linux-gnu
host_vendor = unknown
htmldir = ${docdir}
includedir = ${prefix}/include
infodir = ${datarootdir}/info
install_sh = ${SHELL} /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6/config/install-sh
libdir = ${exec_prefix}/lib
libexecdir = ${exec_prefix}/libexec
localedir = ${datarootdir}/locale
localstatedir = ${prefix}/var
mandir = ${datarootdir}/man
mkdir_p = $(MKDIR_P)
moduledir = ${prefix}/include/
oldincludedir = /usr/include
pdfdir = ${docdir}
prefix = /usr/local
program_transform_name = s,x,x,
psdir = ${docdir}
sbindir = ${exec_prefix}/sbin
sharedstatedir = ${prefix}/com
srcdir = .
subdirs =  libxc-2.0.x S_GPU yaml-0.1.4
sysconfdir = ${prefix}/etc
target_alias = 
top_build_prefix = ../../
top_builddir = ../..
top_srcdir = ../..
typelibsdir = 

# To be installed:
noinst_LIBRARIES = libOpenCL.a
#OCL_SOURCES = 

# Code source.
OCL_SOURCES = \
	Stream.h Tool.h bench_lib.h \
	OpenCL_wrappers.c         OpenCL_wrappers.h \
	MagicFilter.c             MagicFilter.h \
	MagicFilter_Generator.cpp MagicFilter_Generator.h \
	Kinetic.c                 Kinetic.h \
	Kinetic_Generator.cpp     Kinetic_Generator.h \
	Kinetic_k.h \
	Kinetic_k_Generator.cpp   Kinetic_k_Generator.h \
	Wavelet.c                 Wavelet.h \
	Wavelet_Generator.cpp     Wavelet_Generator.h \
	Uncompress.c              Uncompress.h \
	Initialize.c              Initialize.h \
	Profiling.c \
	Hamiltonian.c \
	Reduction.c               Reduction.h \
	Reduction_Generator.cpp   Reduction_Generator.h \
	Preconditioner.c \
	Density.c \
	dsfft.c \
	fft_generator_noshared.cpp \
	fft_noshared.c \
	fft_generator_helper.cpp \
	dsfft_generator.cpp       fft_generator.h \
	Benchmark.c \
	Benchmark_Generator.cpp   Benchmark_Generator.h

libOpenCL_a_SOURCES = $(OCL_SOURCES)
CLEANFILES = $(EXTRA_PROGRAMS)
AM_FCFLAGS = -I$(top_builddir)/includes   -I$(top_builddir)/libABINIT/src -I. -I$(srcdir)
AM_CPPFLAGS = -I/opt/nvidia/cudatoolkit6.5/default/include
AM_CFLAGS = -Wall -Wno-deprecated-declarations
AM_CXXFLAGS = -Wall -Wno-deprecated-declarations
AM_LDFLAGS = -L$(top_builddir)/src $(am__append_1)
conv_check_SOURCES = conv_check.f90
conv_check_LDADD = -lbigdft-1 -L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm
conv_check_fft_SOURCES = conv_check_fft.f90
conv_check_fft_LDADD = -lbigdft-1
stream_check_SOURCES = Stream.c StreamCheck.c
stream_check_LDADD = -lbigdft-1
bench_conv_SOURCES = bench_conv.c bench_lib.c
bench_conv_LDADD = -lbigdft-1
bench_conv_quick_SOURCES = bench_conv_quick.c bench_lib.c
bench_conv_quick_LDADD = -lbigdft-1
bench_zgemm_SOURCES = bench_zgemm.c bench_lib.c
bench_zgemm_LDADD = -lbigdft-1
all: all-am

.SUFFIXES:
.SUFFIXES: .c .cpp .f90 .o .obj
$(srcdir)/Makefile.in:  $(srcdir)/Makefile.am  $(am__configure_deps)
	@for dep in $?; do \
	  case '$(am__configure_deps)' in \
	    *$$dep*) \
	      ( cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) am--refresh ) \
	        && { if test -f $@; then exit 0; else break; fi; }; \
	      exit 1;; \
	  esac; \
	done; \
	echo ' cd $(top_srcdir) && $(AUTOMAKE) --gnu src/OpenCL/Makefile'; \
	$(am__cd) $(top_srcdir) && \
	  $(AUTOMAKE) --gnu src/OpenCL/Makefile
.PRECIOUS: Makefile
Makefile: $(srcdir)/Makefile.in $(top_builddir)/config.status
	@case '$?' in \
	  *config.status*) \
	    cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) am--refresh;; \
	  *) \
	    echo ' cd $(top_builddir) && $(SHELL) ./config.status $(subdir)/$@ $(am__depfiles_maybe)'; \
	    cd $(top_builddir) && $(SHELL) ./config.status $(subdir)/$@ $(am__depfiles_maybe);; \
	esac;

$(top_builddir)/config.status: $(top_srcdir)/configure $(CONFIG_STATUS_DEPENDENCIES)
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) am--refresh

$(top_srcdir)/configure:  $(am__configure_deps)
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) am--refresh
$(ACLOCAL_M4):  $(am__aclocal_m4_deps)
	cd $(top_builddir) && $(MAKE) $(AM_MAKEFLAGS) am--refresh
$(am__aclocal_m4_deps):

clean-noinstLIBRARIES:
	-test -z "$(noinst_LIBRARIES)" || rm -f $(noinst_LIBRARIES)

libOpenCL.a: $(libOpenCL_a_OBJECTS) $(libOpenCL_a_DEPENDENCIES) $(EXTRA_libOpenCL_a_DEPENDENCIES) 
	$(AM_V_at)-rm -f libOpenCL.a
	$(AM_V_AR)$(libOpenCL_a_AR) libOpenCL.a $(libOpenCL_a_OBJECTS) $(libOpenCL_a_LIBADD)
	$(AM_V_at)$(RANLIB) libOpenCL.a

bench_conv$(EXEEXT): $(bench_conv_OBJECTS) $(bench_conv_DEPENDENCIES) $(EXTRA_bench_conv_DEPENDENCIES) 
	@rm -f bench_conv$(EXEEXT)
	$(AM_V_CCLD)$(LINK) $(bench_conv_OBJECTS) $(bench_conv_LDADD) $(LIBS)

bench_conv_quick$(EXEEXT): $(bench_conv_quick_OBJECTS) $(bench_conv_quick_DEPENDENCIES) $(EXTRA_bench_conv_quick_DEPENDENCIES) 
	@rm -f bench_conv_quick$(EXEEXT)
	$(AM_V_CCLD)$(LINK) $(bench_conv_quick_OBJECTS) $(bench_conv_quick_LDADD) $(LIBS)

bench_zgemm$(EXEEXT): $(bench_zgemm_OBJECTS) $(bench_zgemm_DEPENDENCIES) $(EXTRA_bench_zgemm_DEPENDENCIES) 
	@rm -f bench_zgemm$(EXEEXT)
	$(AM_V_CCLD)$(LINK) $(bench_zgemm_OBJECTS) $(bench_zgemm_LDADD) $(LIBS)

conv_check$(EXEEXT): $(conv_check_OBJECTS) $(conv_check_DEPENDENCIES) $(EXTRA_conv_check_DEPENDENCIES) 
	@rm -f conv_check$(EXEEXT)
	$(AM_V_FCLD)$(FCLINK) $(conv_check_OBJECTS) $(conv_check_LDADD) $(LIBS)

conv_check_fft$(EXEEXT): $(conv_check_fft_OBJECTS) $(conv_check_fft_DEPENDENCIES) $(EXTRA_conv_check_fft_DEPENDENCIES) 
	@rm -f conv_check_fft$(EXEEXT)
	$(AM_V_FCLD)$(FCLINK) $(conv_check_fft_OBJECTS) $(conv_check_fft_LDADD) $(LIBS)

stream_check$(EXEEXT): $(stream_check_OBJECTS) $(stream_check_DEPENDENCIES) $(EXTRA_stream_check_DEPENDENCIES) 
	@rm -f stream_check$(EXEEXT)
	$(AM_V_CCLD)$(LINK) $(stream_check_OBJECTS) $(stream_check_LDADD) $(LIBS)

mostlyclean-compile:
	-rm -f *.$(OBJEXT)

distclean-compile:
	-rm -f *.tab.c

include ./$(DEPDIR)/Benchmark.Po
include ./$(DEPDIR)/Benchmark_Generator.Po
include ./$(DEPDIR)/Density.Po
include ./$(DEPDIR)/Hamiltonian.Po
include ./$(DEPDIR)/Initialize.Po
include ./$(DEPDIR)/Kinetic.Po
include ./$(DEPDIR)/Kinetic_Generator.Po
include ./$(DEPDIR)/Kinetic_k_Generator.Po
include ./$(DEPDIR)/MagicFilter.Po
include ./$(DEPDIR)/MagicFilter_Generator.Po
include ./$(DEPDIR)/OpenCL_wrappers.Po
include ./$(DEPDIR)/Preconditioner.Po
include ./$(DEPDIR)/Profiling.Po
include ./$(DEPDIR)/Reduction.Po
include ./$(DEPDIR)/Reduction_Generator.Po
include ./$(DEPDIR)/Stream.Po
include ./$(DEPDIR)/StreamCheck.Po
include ./$(DEPDIR)/Uncompress.Po
include ./$(DEPDIR)/Wavelet.Po
include ./$(DEPDIR)/Wavelet_Generator.Po
include ./$(DEPDIR)/bench_conv.Po
include ./$(DEPDIR)/bench_conv_quick.Po
include ./$(DEPDIR)/bench_lib.Po
include ./$(DEPDIR)/bench_zgemm.Po
include ./$(DEPDIR)/dsfft.Po
include ./$(DEPDIR)/dsfft_generator.Po
include ./$(DEPDIR)/fft_generator_helper.Po
include ./$(DEPDIR)/fft_generator_noshared.Po
include ./$(DEPDIR)/fft_noshared.Po

.c.o:
	$(AM_V_CC)$(COMPILE) -MT $@ -MD -MP -MF $(DEPDIR)/$*.Tpo -c -o $@ $<
	$(AM_V_at)$(am__mv) $(DEPDIR)/$*.Tpo $(DEPDIR)/$*.Po
#	$(AM_V_CC)source='$<' object='$@' libtool=no \
#	DEPDIR=$(DEPDIR) $(CCDEPMODE) $(depcomp) \
#	$(AM_V_CC_no)$(COMPILE) -c -o $@ $<

.c.obj:
	$(AM_V_CC)$(COMPILE) -MT $@ -MD -MP -MF $(DEPDIR)/$*.Tpo -c -o $@ `$(CYGPATH_W) '$<'`
	$(AM_V_at)$(am__mv) $(DEPDIR)/$*.Tpo $(DEPDIR)/$*.Po
#	$(AM_V_CC)source='$<' object='$@' libtool=no \
#	DEPDIR=$(DEPDIR) $(CCDEPMODE) $(depcomp) \
#	$(AM_V_CC_no)$(COMPILE) -c -o $@ `$(CYGPATH_W) '$<'`

.cpp.o:
	$(AM_V_CXX)$(CXXCOMPILE) -MT $@ -MD -MP -MF $(DEPDIR)/$*.Tpo -c -o $@ $<
	$(AM_V_at)$(am__mv) $(DEPDIR)/$*.Tpo $(DEPDIR)/$*.Po
#	$(AM_V_CXX)source='$<' object='$@' libtool=no \
#	DEPDIR=$(DEPDIR) $(CXXDEPMODE) $(depcomp) \
#	$(AM_V_CXX_no)$(CXXCOMPILE) -c -o $@ $<

.cpp.obj:
	$(AM_V_CXX)$(CXXCOMPILE) -MT $@ -MD -MP -MF $(DEPDIR)/$*.Tpo -c -o $@ `$(CYGPATH_W) '$<'`
	$(AM_V_at)$(am__mv) $(DEPDIR)/$*.Tpo $(DEPDIR)/$*.Po
#	$(AM_V_CXX)source='$<' object='$@' libtool=no \
#	DEPDIR=$(DEPDIR) $(CXXDEPMODE) $(depcomp) \
#	$(AM_V_CXX_no)$(CXXCOMPILE) -c -o $@ `$(CYGPATH_W) '$<'`

.f90.o:
	$(AM_V_FC)$(FCCOMPILE) -c -o $@ $(FCFLAGS_f90) $<

.f90.obj:
	$(AM_V_FC)$(FCCOMPILE) -c -o $@ $(FCFLAGS_f90) `$(CYGPATH_W) '$<'`

ID: $(am__tagged_files)
	$(am__define_uniq_tagged_files); mkid -fID $$unique
tags: tags-am
TAGS: tags

tags-am: $(TAGS_DEPENDENCIES) $(am__tagged_files)
	set x; \
	here=`pwd`; \
	$(am__define_uniq_tagged_files); \
	shift; \
	if test -z "$(ETAGS_ARGS)$$*$$unique"; then :; else \
	  test -n "$$unique" || unique=$$empty_fix; \
	  if test $$# -gt 0; then \
	    $(ETAGS) $(ETAGSFLAGS) $(AM_ETAGSFLAGS) $(ETAGS_ARGS) \
	      "$$@" $$unique; \
	  else \
	    $(ETAGS) $(ETAGSFLAGS) $(AM_ETAGSFLAGS) $(ETAGS_ARGS) \
	      $$unique; \
	  fi; \
	fi
ctags: ctags-am

CTAGS: ctags
ctags-am: $(TAGS_DEPENDENCIES) $(am__tagged_files)
	$(am__define_uniq_tagged_files); \
	test -z "$(CTAGS_ARGS)$$unique" \
	  || $(CTAGS) $(CTAGSFLAGS) $(AM_CTAGSFLAGS) $(CTAGS_ARGS) \
	     $$unique

GTAGS:
	here=`$(am__cd) $(top_builddir) && pwd` \
	  && $(am__cd) $(top_srcdir) \
	  && gtags -i $(GTAGS_ARGS) "$$here"
cscopelist: cscopelist-am

cscopelist-am: $(am__tagged_files)
	list='$(am__tagged_files)'; \
	case "$(srcdir)" in \
	  [\\/]* | ?:[\\/]*) sdir="$(srcdir)" ;; \
	  *) sdir=$(subdir)/$(srcdir) ;; \
	esac; \
	for i in $$list; do \
	  if test -f "$$i"; then \
	    echo "$(subdir)/$$i"; \
	  else \
	    echo "$$sdir/$$i"; \
	  fi; \
	done >> $(top_builddir)/cscope.files

distclean-tags:
	-rm -f TAGS ID GTAGS GRTAGS GSYMS GPATH tags

distdir: $(DISTFILES)
	@srcdirstrip=`echo "$(srcdir)" | sed 's/[].[^$$\\*]/\\\\&/g'`; \
	topsrcdirstrip=`echo "$(top_srcdir)" | sed 's/[].[^$$\\*]/\\\\&/g'`; \
	list='$(DISTFILES)'; \
	  dist_files=`for file in $$list; do echo $$file; done | \
	  sed -e "s|^$$srcdirstrip/||;t" \
	      -e "s|^$$topsrcdirstrip/|$(top_builddir)/|;t"`; \
	case $$dist_files in \
	  */*) $(MKDIR_P) `echo "$$dist_files" | \
			   sed '/\//!d;s|^|$(distdir)/|;s,/[^/]*$$,,' | \
			   sort -u` ;; \
	esac; \
	for file in $$dist_files; do \
	  if test -f $$file || test -d $$file; then d=.; else d=$(srcdir); fi; \
	  if test -d $$d/$$file; then \
	    dir=`echo "/$$file" | sed -e 's,/[^/]*$$,,'`; \
	    if test -d "$(distdir)/$$file"; then \
	      find "$(distdir)/$$file" -type d ! -perm -700 -exec chmod u+rwx {} \;; \
	    fi; \
	    if test -d $(srcdir)/$$file && test $$d != $(srcdir); then \
	      cp -fpR $(srcdir)/$$file "$(distdir)$$dir" || exit 1; \
	      find "$(distdir)/$$file" -type d ! -perm -700 -exec chmod u+rwx {} \;; \
	    fi; \
	    cp -fpR $$d/$$file "$(distdir)$$dir" || exit 1; \
	  else \
	    test -f "$(distdir)/$$file" \
	    || cp -p $$d/$$file "$(distdir)/$$file" \
	    || exit 1; \
	  fi; \
	done
check-am: all-am
check: check-am
all-am: Makefile $(LIBRARIES)
installdirs:
install: install-am
install-exec: install-exec-am
install-data: install-data-am
uninstall: uninstall-am

install-am: all-am
	@$(MAKE) $(AM_MAKEFLAGS) install-exec-am install-data-am

installcheck: installcheck-am
install-strip:
	if test -z '$(STRIP)'; then \
	  $(MAKE) $(AM_MAKEFLAGS) INSTALL_PROGRAM="$(INSTALL_STRIP_PROGRAM)" \
	    install_sh_PROGRAM="$(INSTALL_STRIP_PROGRAM)" INSTALL_STRIP_FLAG=-s \
	      install; \
	else \
	  $(MAKE) $(AM_MAKEFLAGS) INSTALL_PROGRAM="$(INSTALL_STRIP_PROGRAM)" \
	    install_sh_PROGRAM="$(INSTALL_STRIP_PROGRAM)" INSTALL_STRIP_FLAG=-s \
	    "INSTALL_PROGRAM_ENV=STRIPPROG='$(STRIP)'" install; \
	fi
mostlyclean-generic:

clean-generic:
	-test -z "$(CLEANFILES)" || rm -f $(CLEANFILES)

distclean-generic:
	-test -z "$(CONFIG_CLEAN_FILES)" || rm -f $(CONFIG_CLEAN_FILES)
	-test . = "$(srcdir)" || test -z "$(CONFIG_CLEAN_VPATH_FILES)" || rm -f $(CONFIG_CLEAN_VPATH_FILES)

maintainer-clean-generic:
	@echo "This command is intended for maintainers to use"
	@echo "it deletes files that may require special tools to rebuild."
clean: clean-am

clean-am: clean-generic clean-noinstLIBRARIES mostlyclean-am

distclean: distclean-am
	-rm -rf ./$(DEPDIR)
	-rm -f Makefile
distclean-am: clean-am distclean-compile distclean-generic \
	distclean-tags

dvi: dvi-am

dvi-am:

html: html-am

html-am:

info: info-am

info-am:

install-data-am:

install-dvi: install-dvi-am

install-dvi-am:

install-exec-am:

install-html: install-html-am

install-html-am:

install-info: install-info-am

install-info-am:

install-man:

install-pdf: install-pdf-am

install-pdf-am:

install-ps: install-ps-am

install-ps-am:

installcheck-am:

maintainer-clean: maintainer-clean-am
	-rm -rf ./$(DEPDIR)
	-rm -f Makefile
maintainer-clean-am: distclean-am maintainer-clean-generic

mostlyclean: mostlyclean-am

mostlyclean-am: mostlyclean-compile mostlyclean-generic

pdf: pdf-am

pdf-am:

ps: ps-am

ps-am:

uninstall-am:

.MAKE: install-am install-strip

.PHONY: CTAGS GTAGS TAGS all all-am check check-am clean clean-generic \
	clean-noinstLIBRARIES cscopelist-am ctags ctags-am distclean \
	distclean-compile distclean-generic distclean-tags distdir dvi \
	dvi-am html html-am info info-am install install-am \
	install-data install-data-am install-dvi install-dvi-am \
	install-exec install-exec-am install-html install-html-am \
	install-info install-info-am install-man install-pdf \
	install-pdf-am install-ps install-ps-am install-strip \
	installcheck installcheck-am installdirs maintainer-clean \
	maintainer-clean-generic mostlyclean mostlyclean-compile \
	mostlyclean-generic pdf pdf-am ps ps-am tags tags-am uninstall \
	uninstall-am


$(EXTRA_PROGRAMS): lib.stamp

lib.stamp:
	cd ..; $(MAKE) libbigdft-1.a

stream: stream_check
	OPENCL_PROFILE=1 OPENCL_PROFILE_CONFIG='$(srcdir)/profile.conf' ./stream_check

bench: bench_conv
	OPENCL_PROFILE=1 OPENCL_PROFILE_CONFIG='$(srcdir)/profile.conf' ./bench_conv

bench_quick: bench_conv_quick
	OPENCL_PROFILE=1 OPENCL_PROFILE_CONFIG='$(srcdir)/profile.conf' ./bench_conv_quick

bench_zg: bench_zgemm
	OPENCL_PROFILE=1 OPENCL_PROFILE_CONFIG='$(srcdir)/profile.conf' ./bench_zgemm

check_conv: conv_check
	echo 124 132 130 100 > fort.1
	./conv_check

check_conv_fft: conv_check_fft
	echo 64 70 84 100 > fort.2
	./conv_check_fft

# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
