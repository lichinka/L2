!
! Simple Fortan90 program that multiplies 2 square matrices calling Sgemm
!  C = alpha A*B + beta C
!
! This example is using cudaMallocHost to allocate the matrices in pinned memory.
! Pinned memory enables fast PCI-e transfer.
!
! The code is using the iso_c_binding Fortran 2003 extension. 
! It has been tested with the Intel Fortran compiler v10.1 and g95.
!


program matrix_multiply
use iso_c_binding 

implicit none

! Define the floating point kind to be  single_precision
integer, parameter :: fp_kind = kind(0.0d0) 

! Define matrices as pointer. 
real (fp_kind), dimension(:,:), allocatable ::      A, B, C

real (fp_kind)::      time_start,time_end,wallclock
real (fp_kind)::      alpha=1._fp_kind,beta=1._fp_kind, c_right
integer::  i,j, res, m1



!do m1=128,2560,32
do m1=128,128*20,128

! Allocating memory 

 allocate(A(m1,m1)) 

 allocate(B(m1,m1))

 allocate(C(m1,m1))

 ! Initialize the matrices A,B and C
 A=1._fp_kind
 B=2._fp_kind
 C=3._fp_kind

 ! With the prescribed inputs, each element of the C matrix should be equal to c_right
 c_right= 2._fp_kind*m1+3._fp_kind

! Compute the matrix product  computation
 !call cpu_time(time_start)
 time_start=wallclock()

  call cublas_DGEMM ('n','n',m1,m1,m1,alpha,A,m1,B,m1,beta,C,m1)

! call cpu_time(time_end)
 time_end=wallclock()

! Print timing information
 print "(i5,1x,a,1x,f8.4,2x,a,f12.4)", m1, " time =",time_end-time_start, " MFLOPS=",1.e-6*2._fp_kind*m1*m1*m1/(time_end-time_start)

! check the result
     do j=1,m1
      do i=1,m1
       if ( abs(c(i,j)- c_right ) .gt. 1.d-8 ) then
             print *, "dgemm failed", i,j, abs(c(i,j)- c_right ),c(i,j)
	     exit
       end if
      end do
     end do
          
   deallocate(A,B,C)
end do

end program matrix_multiply

