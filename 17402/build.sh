#!/bin/sh

# 
# compilation script prepared for Daint and Opcode
#
SRC=.

case $( hostname ) in 
    *daint* | *santis*)
        MODS="PrgEnv-gnu craype-accel-nvidia35 cudatoolkit/6.5.14-1.0502.9613.6.1 cray-libsci_acc/3.1.1"
        CC=cc
        CXX=CC
        CUDA=${CUDATOOLKIT_HOME}
        ;;
    *opcode*)
        MODS="mvapich2/2.0-gcc-opcode2-4.7.2"
        CC=mpicc
        CXX=g++
        CUDA=/apps/opcode/CUDA-5.5
        ;;
    *)
        echo "Don't know how to compile here. Exiting."
        exit 1
        ;;
esac

echo "Checking modules on $( hostname ) ..."
for m in ${MODS}; do
    if [ -z "$( echo ${LOADEDMODULES} | grep ${m} )" ]; then
        echo -e "Missing <${m}>"
        exit 1
    fi
done

echo "Building on $( hostname ) ..."
${CXX} ${SRC}/10_mpi.cpp -I${CUDA}/include -L${CUDA}/lib64 -L${CUDA}/stubs -lcublas -lOpenCL -o 10_mpi
${CC}  -DPINNED ${SRC}/osu_bw_cl.c -I${CUDA}/include -L${CUDA}/lib64 -lcublas -lOpenCL -o osu_bw_cl

