#include<mpi.h>
#include<cuda_runtime.h>
#include<cassert>
#include<iostream>

extern "C"{
    void libsci_acc_init();
    void Cblacs_get(int context, int request, int* value);
    void Cblacs_gridinit(int* context, const char * order, int np_row, int np_col);
    void Cblacs_gridexit(int context);
    void descset_(int *desc, int *m, int *n, int *mb, int *nb, int *irsrc, int *icsrc, int *ictxt, int *lld);

    void pdsymm_(const char *side, const char *uplo, int *m, int *n,
                 double *alpha, double *a, int *ia, int *ja, int *desca,
                 double *b, int *ib, int *jb, int *descb,
                 double *beta, double *c, int *ic, int *jc, int *descc);
}

int main(int argc, char** argv)
{
    int ctxt = -1;
    int id = -1;
    int np = -1;
    MPI_Init(&argc, &argv);

    MPI_Comm_rank(MPI_COMM_WORLD, &id);
    MPI_Comm_size(MPI_COMM_WORLD, &np);

    assert(np == 4);

    int np_row = 2;
    int np_col = 2;

    if(id == 0)
        std::cout << "Initialize libsci_acc" << std::endl;
    libsci_acc_init();

    std::cout << "About to CBLAS ...\n";
    Cblacs_get(-1, 0, &ctxt);

    Cblacs_gridinit(&ctxt, "C", np_row, np_col);

    int szl = 5120;
    int nb = 512;
    int n = 10240;

    int ik = 129;
    int sz = n - ik + 1;
    int i_one = 1;
    int i_zero = 1;

    double d_one = 1;
    double d_zero = 0;

    double *a;
    double *b;
    double *c;

    cudaMalloc(&a, szl*szl*sizeof(double));
    cudaMalloc(&b, szl*nb*sizeof(double));
    cudaMalloc(&c, szl*nb*sizeof(double));

    int desca[9];
    int descb[9];
    descset_(desca, &n, &n, &nb, &nb, &i_zero, &i_zero, &ctxt, &szl);
    descset_(descb, &n, &nb, &nb, &nb, &i_zero, &i_zero, &ctxt, &szl);

    pdsymm_("L", "L", &sz, &nb, &d_one, a, &ik, &ik, desca, b, &ik, &i_one, descb, &d_zero, c, &ik, &i_one, descb);

    cudaFree(a);
    cudaFree(b);
    cudaFree(c);

    MPI_Barrier(MPI_COMM_WORLD);
    Cblacs_gridexit(0);
    MPI_Finalize();
}
