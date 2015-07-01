After finishing the last round of bechmarks using the new set of profiling tools provided by Cray, we are now able to share with you the requested information regarding the instrumented runs of BigDFT using OpenCL.

This is a short summary of all the happening during this time:

    * Using the GNU compiler: 
        * the code was crashing at runtime:
               => recompiling without `libsci_acc` fixed it.
        * perftools/624 has a large overhead
               => perftools/623 is the recommended version.

    * Using the INTEL compiler:
        * again, perftools/623 is the recommended version due to the lower overhead
               => an example report in may be found in /scratch/daint/lucamar/bigdft/intel/pat/report-1052531.out

    * Using the Cray compiler:
        * there is a compilation issue because of a conflict with the `-soname` flag.

We have also prepared a set of profile reports of instrumented runs using both the GNU and Intel compilers with OpenCL and OpenMP support.
In the directory `/scratch/daint/lucasbe/l2/17793` you may find the profile results for BigDFT v1.7.6.
The first build script included (`build-bigdft-xc30_gnu-mkl_gpu.sh`) uses the GNU compiler v4.8.2, whereas the other one (`build-bigdft-xc30_intel-mkl_gpu.sh`) uses the Intel compiler v15.0.1.
In the directory `INPUT_DATA` you may find the files used as input for the tested runs.
The directory `RESULTS` contains the gather data after the runs finished successfully. The ones including the suffix `PT623` are the output of the instrumented executables. These runs were launched using the included `run.sh` script. The file contents are as follows:

    * o_bigdft.1024.1.8.1.daint+omp+ocl.GNU         => 128 MPI tasks, 8 OpenMP threads per MPI task, GPU acceleration on, GNU compiler
    * o_bigdft.1024.1.8.1.daint+omp+ocl.GNU+PT623   => 128 MPI tasks, 8 OpenMP threads per MPI task, GPU acceleration on, GNU compiler, instrumented
    * o_bigdft.1024.1.8.1.daint+omp+ocl.INTEL       => 128 MPI tasks, 8 OpenMP threads per MPI task, GPU acceleration on, Intel compiler
    * o_bigdft.1024.1.8.1.daint+omp+ocl.INTEL+PT623 => 128 MPI tasks, 8 OpenMP threads per MPI task, GPU acceleration on, Intel compiler, instrumented
    * o_bigdft.1024.1.8.1.daint+noomp+ocl.GNU       => 128 MPI tasks, no OpenMP, GPU acceleration on, GNU compiler
    * o_bigdft.1024.1.8.1.daint+noomp+ocl.GNU+PT623 => 128 MPI tasks, no OpenMP, GPU acceleration on, GNU compiler, instrumented

The data for `pat_report` containing performance information of the profiled runs using OpenCL are also included in the `RESULTS` folder, namely:

    * o_bigdft.1024.1.8.1.daint+omp+ocl.GNU+PT623.xf,
    * o_bigdft.1024.1.8.1.daint+omp+ocl.INTEL+PT623.xf,
    * o_bigdft.1024.1.8.1.daint+noomp+ocl.GNU+PT623.xf.
    
In order to visualize the performance profile reports, including all traced calls, use the following commands:

$> module load perftools/6.2.3
$> pat_report -T -i../GNU+PT623/bigdft-1.7.6/src/bigdft+pat o_bigdft.1024.1.8.1.daint+noomp+ocl.GNU+PT623.xf
$> pat_report -T -i/scratch/daint/piccinal/17793/GNU+PT623/bigdft-1.7.6/src/bigdft+pat o_bigdft.1024.1.8.1.daint+omp+ocl.GNU+PT623.xf
$> pat_report -T -i/scratch/daint/lucamar/bigdft/bin/bigdft1768-intel_gpu+pat.x o_bigdft.1024.1.8.1.daint+omp+ocl.INTEL+PT623.xf


We hope that you find all the provided information useful and the instructions clear.
If you have a specific issue with the tool or the procedure to generate a performance profile, please do not hesitate to contact us again.

