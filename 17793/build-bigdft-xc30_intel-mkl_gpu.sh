#!/bin/bash -l

# remove "-g -arch=sm_13" from the default flags of NVCC defined in S_GPU/configure.ac 
# define --with-nvcc-flags="-arch sm_35" in the configure line (current GPU architecture)

module swap PrgEnv-cray PrgEnv-intel
module swap intel intel/15.0.1.133
module unload cray-libsci
module load cudatoolkit

# configure
./configure 'FC=ftn' 'CC=cc' 'CXX=icpc' 'FCFLAGS=-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2 -openmp -g' '--prefix=/apps/daint/sandbox/lucamar/bin/bigdft1768/intel/' '--with-ext-linalg=-L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_core -lmkl_intel_thread -lpthread -lm' '--enable-opencl' '--enable-cuda-gpu' '--with-cuda-path='$CRAY_CUDATOOLKIT_DIR '--with-ocl-path='$CRAY_CUDATOOLKIT_DIR '--with-nvcc-flags=-arch sm_35' 'LIBS=-L/opt/cray/nvidia/default/lib64 -L'$CRAY_CUDATOOLKIT_DIR/lib64 'CFLAGS=-O2' 'FCLIBS= '

# build
make VERBOSE=1

# instrument
module load perftools/6.2.3
make clean
make
pat_build -w -g mpi,opencl bigdft
