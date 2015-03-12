#!/usr/bin/env bash

export OMP_NUM_THREADS=2
export CRAY_CUDA_MPS=1

aprun -n 4 -d 2 ./proxy 4000
