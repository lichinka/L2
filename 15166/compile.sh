#!/bin/sh

case $( hostname ) in
    *daint*)
        MODS="PrgEnv-gnu cudatoolkit"
        ;;
    *)
        echo "# Don't know how to compile here. Exiting."
        exit 1
        ;;
esac

echo "Checking modules on $( hostname ) ..."
for m in ${MODS}; do
    if [ -z "$( echo ${LOADEDMODULES} | grep ${m} )" ]; then
        echo -e "# Please issue:\n\tmodule load ${m}"
        exit 1
    fi
done

echo "# Building on $( hostname ) ..."
nvcc -keep -Xcompiler ,\"-Wall\" test_case.cu -o test_case_with_warnings
nvcc -x c++  -Xcompiler ,\"-Wall\" test_case.cu -o test_case_without_warnings

