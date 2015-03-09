###########################################################
#  Makefile for Fermi DGEMM/DTRSM library                 #
###########################################################
all: libdgemm.so.1.0.1

OBJS = cuda_dgemm.o fermi_dgemm.o

.PRECIOUS: $(OBJS)

all : libdgemm.so.1.0.1 

fermi_dgemm.o : fermi_dgemm.c fermi_dgemm.h helper_nvcc.cubin_bits.h dgemm_kernels_sass.cubin_bits.h

#DEFINES = -DMPI
DEFINES += -DVERBOSE_PRINT
#DEFINES += -DGOTO

%.o: %.c
	mpicc -O0 -c -fPIC $(DEFINES) $*.c -o $*.o -I$(CUDA_INC)

libdgemm.so.1.0.1: $(OBJS)

	gcc -O3 -shared -Wl,-soname,libdgemm.so.1 -o libdgemm.so.1.0.1 $(OBJS) -L$(CUDA_LIB) -lcudart -lcuda
	#mpicc -O3 -shared -Wl,-soname,libdgemm.so.1 -o libdgemm.so.1.0.1 $(OBJS) -L$(CUDA_LIB) -lcudart -lcuda
	#mpicc -O3 -shared -Wl,-soname,libdgemm.so.1 -o libdgemm.so.1.0.1 $(OBJS) -L$(CUDA_LIB) -lcudart 
	ln -sf libdgemm.so.1.0.1 libdgemm.so.1.0
	ln -sf libdgemm.so.1.0 libdgemm.so.1
	ln -sf libdgemm.so.1 libdgemm.so

clean:
	rm -f $(OBJS) $(CUBINS) libdgemm.so.1.0.1 libdgemm.so.1.0 libdgemm.so.1 libdgemm.so
