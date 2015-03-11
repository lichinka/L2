#!/usr/bin/env bash

export OMP_NUM_THREADS=8
export MPICH_RDMA_ENABLED_CUDA=1
export CRAY_LIBSCI_ACC_MODE=1

aprun -N 1 -d 8 -n 4 -cc none ./test_bug_symm
