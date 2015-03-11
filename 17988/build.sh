#!/bin/sh

# 
# compilation script 
#
case $( hostname ) in 
    *daint* | *santis*)
        MODS="PrgEnv-gnu craype-accel-nvidia35 cray-libsci_acc/3.1.1 cudatoolkit/6.5.14-1.0502.9613.6.1"
        MAKE_INC="make.daint"
        ;;
    *)
        echo "Don't know how to compile here. Exiting."
        exit 1
        ;;
esac

echo -n "Checking modules on $( hostname ) ... "
for m in ${MODS}; do
    if [ -z "$( echo ${LOADEDMODULES} | grep ${m} )" ]; then
        echo -e "<${m}> is missing"
        exit 1
    fi
done
echo "ok"

echo "Building on $( hostname ) ..."
cat ${MAKE_INC} Makefile > /tmp/.makefile
make -Bf /tmp/.makefile
