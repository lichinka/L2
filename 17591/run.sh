#!/usr/bin/env bash

export CRAY_CUDA_MPS=1

aprun -n1 ./proxy 2000
