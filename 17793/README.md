After finishing the last set of bechmarks using the new set of profiling tools provided by Cray, we are happy to contact you with the requested information regarding the instrumented runs of BigDFT using OpenCL.

This is a short summary of all the happening during this time:

    * Using the GNU compiler: 
        * the code was crashing at runtime:
               => recompiling without `libsci_acc` fixed it.  
        * perftools/624 has a large overhead
               => perftools/623 is the recommended version
               => an example report may be found in /scratch/santis/piccinal/BIGDFT/17793_19422/GNU+OCL/176/bin/0/xf ???

    * Using the INTEL compiler:
        * again, perftools/623 is the recommended version due to the lower overhead
                => an example report in may be found in /scratch/daint/lucamar/bigdft/intel/pat/report-1052531.out

    * Using the Cray compiler:
        * there is a compilation issue because of a conflicts with the `-soname` flag.


We have also prepared a set of profile reports of instrumented runs using both the GNU and Intel compilers with OpenCL support.
In the directory `/scratch/daint/lucasbe/l2/17793` you may find the profile results for BigDFT v1.7.6.
The first build script included (build-bigdft-xc30_gnu-mkl_gpu.sh) was used to compile using the GNU compiler v4.8.2, whereas the other one (build-bigdft-xc30_intel-mkl_gpu.sh) was used to compile with Intel v15.0.1. All versions include support for OpenCL.
In the directory `INPUT_DATA` you may find the files used as input for the tested runs.
The directory `RESULTS` contains the gather data after the runs finished successfully. The ones including the suffix `PT623` are the output of the instrumented executables. These runs were launched using the included `run.sh` script.
The output of both profiled runs using OpenCL are also included in the `RESULTS`, namely `bigdft1768-intel_gpu+pat.x+4239-960t.xf`, and `bigdft-gnu_gpu+pat+29698-2112t.xf`. You can visualize the performance profile information using this command, e.g.:

$> pat_report bigdft-gnu_gpu+pat+29698-2112t.xf

If you have a specific issue with the tool or the procedure of generate the performance profile, please do not hesitate to contact us again.

