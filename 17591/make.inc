#
#	CPU_GFLOPS = 8.8
#	GPU_GFLOPS = 300
	GPU_FLAG   = USEGPU

    #DEFINES = -DMPI
	#DEFINES += -DVERBOSE_PRINT
	#DEFINES += -DFERMI_DGEMM_VERBOSE_PRINT
	DEFINES += -DLIBSCI
	#DEFINES += -DINTERLEAVE


	CC        = cc
	CPP       = g++
	NVCC      = nvcc
	FORT      = gfortran

	ARCH      = ar
	ARCHFLAGS = cr
	RANLIB    = ranlib

	#OPTS      = -O3 -g -fopenmp -D$(GPU_FLAG) #-DCPU_GFLOPS=$(CPU_GFLOPS) -DGPU_GFLOPS=$(GPU_GFLOPS) 
	OPTS      = -O3 -g -D$(GPU_FLAG) #-DCPU_GFLOPS=$(CPU_GFLOPS) -DGPU_GFLOPS=$(GPU_GFLOPS) 
	NVOPTS    = --compiler-options -fno-strict-aliasing  -arch sm_20 \
                    -DUNIX -O2
	LDOPTS    =  

#	MAGMADIR	 = /users/fgilles/Projects/Todi/Magma/magma_1.1.0_v2.2/
#	LIBMAGMA     = $(MAGMADIR)/lib/libmagma.a
#	LIBMAGMABLAS = $(MAGMADIR)/lib/libmagmablas.a

 
	#LIB       = -L/opt/acml/4.4.0/gfortran64/lib -L/opt/cray/nvidia/default/lib64 -lcublas -lcudart -lcuda -lpthread -lm -lacml -lacml_mv 
	#LIB       = -L/opt/xt-libsci/11.0.03/gnu/46/interlagos/lib/ -L$(MAGMADIR)/lib/ -L/opt/cray/nvidia/default/lib64 -lcublas -lcudart -lcuda -lmagma -lmagmablas -lmagma -lpthread -lm -lsci_gnu_mp -lgfortran 
	LIB       = -L/opt/cray/nvidia/default/lib64 -lcublas -lcudart -lcuda -lpthread -lm -lgfortran 

	CUDADIR   = /apps/castor/CUDA-5.0/cuda/
	HOMEDIR   = /home/fgilles/

	LIBDIR   += -L$(CUDADIR)/lib64/ -L/users/fgilles/Projects/Fuji/Libs/GotoBLAS2/
	INC       = -I$(CUDADIR)/include/
	
