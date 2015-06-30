# cd /scratch/daint/piccinal/17793/GNU/bigdft-1.7.6/
module swap PrgEnv-cray PrgEnv-gnu
module load craype-accel-nvidia35
module unload cray-libsci
module unload cray-libsci_acc
module load fftw

### compile:
export FC=ftn
export F77=ftn
export CC=cc
export CXX=CC
export CFLAGS="-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2"
export FCFLAGS="-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2"
export FFLAGS="-I/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/include -O2"
export LDFLAGS="-O2"
export LIBS="-L/opt/cray/nvidia/default/lib64 -L/opt/nvidia/cudatoolkit6.5/default/"
export FCLIBS=" "
#!!! replace all "-arch sm_13" with "-arch sm_35" in S_GPU/configure.ac

./configure \
--with-blas=no \
--with-lapack=no \
--with-scalapack=no \
--with-blacs=no \
--with-ext-linalg='-L/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64 -lmkl_intel_lp64 -lmkl_gf_ilp64 -lmkl_core -lmkl_sequential -lpthread -lm' \
--enable-opencl \
--with-ocl-path=/opt/nvidia/cudatoolkit6.5/default 

## without perftools
make

## with perftools
module load perftools/6.2.3
make clean
make
pat_build -w -g mpi,opencl bigdft

