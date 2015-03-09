#all: dgemm_cpu dgemm_gpu dgemm_gpu_pinned
all: dgemm_gpu dgemm_gpu_pinned

dgemm_cpu: dgemm.f90 timer.o
	ifort -o dgemm_cpu -O3 dgemm.f90 timer.o -L$(MKL_LIB) -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5

dgemm_gpu: dgemm_cublas.f90 fortran_thunking.o timer.o
	ifort -o dgemm_gpu -O3 dgemm_cublas.f90 fortran_thunking.o timer.o -L$(CUDADIR)/lib64 -lcublas -lcudart 

dgemm_gpu_pinned: dgemm_speed_pinned.f90 timer.o
	ifort -i8  -o dgemm_gpu_pinned -O3 dgemm_speed_pinned.f90 fortran_thunking.o timer.o -L$(CUDADIR)/lib64 -lcublas -lcudart 

timer.o: timer.c
	icc -c timer.c

fortran_thunking.o: fortran_thunking.c
	icc -c fortran_thunking.c -I$(CUDADIR)/include -L$(CUDADIR)/lib64 -lcublas -lcudart 


clean:
	rm dgemm_gpu dgemm_cpu
