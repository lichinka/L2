#include <stdio.h>       /* standard I/O routines                 */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>       /* standard I/O routines                 */
#include <omp.h>
#include "mpi.h"

#include <sys/time.h>
#include <time.h>
//#include <cblas.h>

#define USEGPU 1

#ifdef USEGPU
#include <cuda.h>
#include <math.h>
#include <cublas.h>
//#include <cublas_v2.h>
#include <cuda_runtime_api.h>
#endif
//#include <magma.h>

#include "utils.h"

#ifdef  USEGPU
#define NUM_THREADS_GPU 2
#define PINNED 1
#else
#define NUM_THREADS_GPU 0
#endif

#define NUM_THREADS_CPU 8

#define NN 2000;

#define root 0


inline
void printtime()
{
	time_t t;
	time(&t);
	printf("%s", ctime(&t)); fflush(stdout);
}


void dgemm_ (char *transa,
		char *transb,
		int *m, int *n, int *k,
		double *alpha, double *A, int *lda,
		double *B, int *ldb,
		double *beta, double *C, int *ldc) ;


double mysecond()
{
        struct timeval tp;
        struct timezone tzp;
        int i;

        i = gettimeofday(&tp,&tzp);
        return ( (double) tp.tv_sec + (double) tp.tv_usec * 1.e-6 );
}


//


int main (int argc, char *argv[])
{
	int numprocs;
	int myid;
	int t;
	int nthreads, tid, procs, maxthreads, inpar, dynamic, nested;

	int N = NN;
	int M = NN;
	int K = NN;

	time_t globaltime;

	printtime();
	printf("Starting...\n");fflush(stdout);



	MPI_Init(&argc,&argv);
    MPI_Comm_size(MPI_COMM_WORLD,&numprocs);
    MPI_Comm_rank(MPI_COMM_WORLD,&myid);
	

	//cublasInit( );
	int error;	
	cuInit(error);
	//printout_devices( );
	if (error) printf("cuInit = %d\n", error);


	//double t_gflops = 0.;

	//#ifdef USEGPU
	//	t_gflops += NUM_THREADS_GPU*2*gpu_frequency*gpu_numProcessors;
	//#endif
	//	t_gflops += NUM_THREADS_CPU*4*2.2;

	int Ncpu = 0;

	if ( argc == 2 ) 
	{
		N    = atoi(argv[1]); M = N; K = M;
	}
	if (myid == root) printf("Running cublas on %dx%dx%d with %d PEs...\n", M, N, K, numprocs); fflush(stdout);

	double  alpha =  1.;
	double  beta  = -1.;

	int lda    = M;
	int ldb    = K;
	int ldc    = M;

	int size_A = K*lda;
	int size_B = N*ldb;
	int size_C = N*ldc;


	char transa = 'n';
	char transb = 'n';

	double otime = 0.;
	double ttime = 0.;
	double time = 0.;
	double mpitime = 0.;

	double* d_A_m;
	double* d_B_m;
	double* d_C_m;

	int size_A_m = K*lda;
	int size_B_m = N*ldb;
	int size_C_m = N*ldc;

	double* A;
	double* B;
	double* C;
	double* Cg;

	double** addGPU;
	addGPU  = (double**) malloc(3*sizeof(double*));

	otime -= mysecond();

	cublasStatus status;
	double** addGPU0;
	addGPU0 = (double**) malloc(3*sizeof(double*));
	if (myid == root)
	{
		A  = (double*) malloc(sizeof(double)*size_A);
		if (A == 0)  printf("Could not allocate A.\n");

		B  = (double*) malloc(sizeof(double)*size_B);
		if (B == 0)  printf("Could not allocate B.\n");

		C  = (double*) malloc(sizeof(double)*size_C);
		if (C == 0)  printf("Could not allocate C.\n");

		Cg = (double*) malloc(sizeof(double)*size_C);
		if (Cg == 0) printf("Could not allocate Cg.\n");

		fill(A,  size_A,  31.);
		eye (B,     ldb,   N );
		fill(C,  size_C,  31.);
		fill(Cg, size_C,  31.);

		ttime -= mysecond();

		printtime();
		printf("Allocating... "); fflush(stdout);
		status = cudaMalloc( (void**)&d_A_m , size_A_m*sizeof(double));
		if (status) printf("status error %d\n", status);
		status = cudaMalloc( (void**)&d_B_m , size_B_m*sizeof(double)) ;
		if (status) printf("status error %d\n", status);
		status = cudaMalloc( (void**)&d_C_m , size_C_m*sizeof(double));
		if (status) printf("status error %d\n", status);
		printf("ok\n"); fflush(stdout);

		printtime();
		printf("Copying... "); fflush(stdout);
		status = cublasSetMatrix( M, K, sizeof( double ), A, lda, d_A_m, lda ) ;
		if (status) printf("status error %d\n", status);
		status = cublasSetMatrix( K, N, sizeof( double ), B, ldb, d_B_m, ldb ) ;
		if (status) printf("status error %d\n", status);
		status = cublasSetMatrix( M, N, sizeof( double ), C, ldc, d_C_m, ldc ) ;
		if (status) printf("status error %d\n", status);
		printf("ok\n\n"); fflush(stdout);

		ttime += mysecond();

		addGPU0[0] = d_A_m;
		addGPU0[1] = d_B_m;
		addGPU0[2] = d_C_m;
	}

	MPI_Bcast(addGPU0, 3, MPI_LONG_LONG_INT, root, MPI_COMM_WORLD);

	addGPU[0] = addGPU0[0];
	addGPU[1] = addGPU0[1];
	addGPU[2] = addGPU0[2];

	int* Narray = (int) malloc(sizeof(int)*(numprocs + 1));
	Narray[0] = 0; Narray[numprocs] = N;

	int ii;
	for (ii = 1; ii < numprocs; ++ii)
		Narray[ii] = Narray[ii - 1] + N/numprocs;

	int myA = myid*M/numprocs;
	int myN = Narray[myid + 1] - Narray[myid]; 

//
// 1- single PE dgemm
//

	if (myid == root)
	{
		printtime();
		printf("%dx%dx%d DGEMM -- 1 PE, ", M, N, K);
		time    = -mysecond();
		mpitime = -mysecond();

		cublasDgemm('n',
				'n',
				M,
				N,
				K,
				alpha,
				//d_A_m,
				addGPU0[0],
				lda,
				//d_B_m,
				addGPU0[1],
				ldb,
				beta,
				//d_C_m,
				addGPU0[2],
				ldc);

		cudaThreadSynchronize();
		time  += mysecond();
		mpitime += mysecond();

		status = cublasGetError();
		if (status) printf("1- DGEMM status error %s\n", cudaGetErrorString(status)); fflush(stdout);


		printf("overall Gflops = %f %f s.\n", 2.*M*N*K/1e9/mpitime, mpitime);
		printf("1- pid %d, my Gflops = %f %f s.\n\n", myid, 2.*M*N*K/1e9/time, time);
	}
	fflush(stdout);
	MPI_Barrier(MPI_COMM_WORLD);


//
// 2- multiple PEs dgemm
//

	if (myid == 0) printtime();
	if (myid == 0) printf("%dx%dx%d DGEMM -- %d PE, ", M, N, K, numprocs);
	MPI_Barrier(MPI_COMM_WORLD);

	time    = -mysecond();
	mpitime = -mysecond();

	cublasDgemm('n',
			'n',
			M,
			N,
			K,
			alpha,
			//d_A_m,
			addGPU0[0],
			lda,
			//d_B_m,
			addGPU0[1],
			ldb,
			beta,
			//d_C_m,
			addGPU0[2],
			ldc);

	cudaThreadSynchronize();
	time  += mysecond();

    MPI_Barrier(MPI_COMM_WORLD);

	mpitime += mysecond();

	status = cublasGetError();
	if (status) printf("2- pid %d, DGEMM status error %s\n", myid, cudaGetErrorString(status)); fflush(stdout);
	if (myid == root) printf("overall Gflops = %f %f s.\n", 2.*M*N*K/1e9/mpitime, mpitime);

	printf("2- pid %d, my Gflops = %f %f s.\n", myid, 2.*M*N*K/1e9/time, time);
	fflush(stdout);

    MPI_Barrier(MPI_COMM_WORLD);

	//
	// 3- single PE split DGEMM
	//

    if (myid == root)
    {
		printf("\n");
		printtime();
        printf("%dx%dx%d DGEMM -- 1 PE, ", M, myN, K); fflush(stdout);
        time    = -mysecond();
        mpitime = -mysecond();

        cublasDgemm('n',
                'n',
                M,
                myN,
                K,
                alpha,
                //d_A_m,
                addGPU0[0],
                lda,
                //d_B_m,
                addGPU0[1],
                ldb,
                beta,
                //d_C_m,
                addGPU0[2],
                ldc);

        cudaThreadSynchronize();
        time  += mysecond();
        mpitime += mysecond();

        status = cublasGetError();
        if (status) printf("DGEMM status error %s\n", cudaGetErrorString(status));fflush(stdout);

		printf("overall Gflops = %f %f s.\n", 2.*M*myN*K/1e9/mpitime, mpitime);
        printf("3- pid %d, my Gflops = %f %f s.\n", myid, 2.*M*myN*K/1e9/time, time);
		fflush(stdout);
    }

    MPI_Barrier(MPI_COMM_WORLD);

	//
	// multi PE dgemm
	//


	printf("\n"); fflush(stdout);
	if (myid == 0) printtime();
    if (myid == root) printf("%dx%dx%d DGEMM -- %d PE, ", M, myN, K, numprocs);
	fflush(stdout);
    MPI_Barrier(MPI_COMM_WORLD);

	time    = -mysecond();
	mpitime = -mysecond();

	cublasDgemm('n',
			'n',
			M,
			myN,
			K,
			alpha,
			//d_A_m,
			addGPU0[0],
			lda,
			//d_B_m,
			addGPU0[1] + Narray[myid]*K,
			ldb,
			beta,
			//d_C_m,
			addGPU0[2] + Narray[myid]*M,
			ldc);

	cudaThreadSynchronize();	
	time  += mysecond();

	MPI_Barrier(MPI_COMM_WORLD);
	mpitime += mysecond();


	status = cublasGetError();
	if (status) printf("4- pid %d, DGEMM status error %s\n", myid, cudaGetErrorString(status)); fflush(stdout);

    if (myid == root) printf("overall Gflops = %f %f s.\n", 2.*M*N*K/1e9/mpitime, mpitime);
	fflush(stdout);
	MPI_Barrier(MPI_COMM_WORLD);
	printf("4- pid %d, my Gflops = %f %f s.\n", myid, 2.*M*myN*K/1e9/time, time);


// done

	if (myid == root)
	{
		status = cublasGetMatrix( M, N, sizeof( double ), d_C_m, ldc, C, ldc ) ;
		if (status) printf("status error %d\n", status);

		status = cublasGetError();
		if (status) printf("status error %d\n", status);

		free(A);
		free(B);
		free(C);
		free(Cg);

		cudaFree(d_A_m);
		cudaFree(d_B_m);
		cudaFree(d_C_m);
	}

	otime += mysecond();


	MPI_Finalize();

	exit(0);

}
