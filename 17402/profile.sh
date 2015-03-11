#!/bin/bash -l

#
# turn on profiling
# reference script available at
#   https://bluewaters.ncsa.illinois.edu/openacc-and-cuda-profiling
# counter reference available at
#   http://www.cs.cmu.edu/afs/cs/academic/class/15668-s11/www/cuda-doc/Compute_Profiler.txt
#
export COMPUTE_PROFILE=1
export COMPUTE_PROFILE_CSV=1
export COMPUTE_PROFILE_LOG=compute.$( hostname ).log
export COMPUTE_PROFILE_CONFIG=compute.config

#
# timed-transfer tests
#
#for i in $( seq 8 15 ); do
#    NUM="$( echo "2^${i}" | bc -l )"
#    echo "# Transfering ${NUM} doubles ..."
#    ./10_mpi 0 gpu 0 ${NUM}
#done

#
# OpenCL bandwidth test
#
./osu_bw_cl
