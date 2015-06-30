export LD_LIBRARY_PATH=/opt/intel/15.0.1.133/composer_xe_2015.1.133/mkl/lib/intel64:$LD_LIBRARY_PATH
export CRAY_TCMALLOC_MEMFS_FORCE=1
export OMP_WAIT_POLICY=PASSIVE

## run without perftools/623
aprun -n 128 -N 1 -d 8 -j 1  bigdft

## run with perftools/623
module load perftools/6.2.3
pat_build -w -g mpi,opencl bigdft-gnu_gpu       # => bigdft+pat
aprun -n 128 -N 1 -d 8 -j 1  bigdft-gnu_gpu+pat
pat_report bigdft-gnu_gpu+pat+29698-2112t.xf > xf


# Results are in /scratch/daint/lucasbe/l2/17793/RESULTS
