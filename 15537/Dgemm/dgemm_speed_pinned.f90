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


! Interface to cudaMallocHost and cudaFree
module cuda_alloc
  use iso_c_binding
 interface 
! cudaMallocHost
 integer (C_INT) function cudaMallocHost(buffer, size)  bind(C,name="cudaMallocHost")
  use iso_c_binding
  implicit none
  type (C_PTR)  :: buffer
  integer (C_SIZE_T), value :: size
 end function cudaMallocHost
! cudaFreeHost
 integer (C_INT) function cudaFreeHost(buffer)  bind(C,name="cudaFreeHost")
  use iso_c_binding
  implicit none
  type (C_PTR), value :: buffer
 end function cudaFreeHost
 end interface 
end module cuda_alloc

program matrix_multiply
use iso_c_binding 
use cuda_alloc 

implicit none

! Define the floating point kind to be  single_precision
integer, parameter :: fp_kind = kind(0.0d0) 

! The allocation is performed by C function call.
! Define the C pointer as type (C_PTR)
 type(C_PTR) :: cptr_A, cptr_B, cptr_C

! Define matrices as pointer. 
real (fp_kind), dimension(:,:), pointer ::      A, B, C

real (fp_kind)::      time_start,time_end,wallclock
real (fp_kind)::      alpha=1._fp_kind,beta=1._fp_kind, c_right
integer::  i,j, res, m1



!do m1=128,2560,32
do m1=128,128*20,128

! Allocating memory with cudaMallocHost. 
! The Fortan arrays, now defined as pointers, are then associated with the C pointers using the 
! new interoperability defined in iso_c_binding

 !allocate(A(m1,m1)) 
 res = cudaMallocHost ( cptr_A, m1*m1*sizeof(fp_kind) )
 call c_f_pointer ( cptr_A, A, (/ m1, m1 /) )

 !allocate(B(m1,m1))
 res = cudaMallocHost ( cptr_B, m1*m1*sizeof(fp_kind) )
 call c_f_pointer ( cptr_B, B, (/ m1, m1 /) )

 !allocate(C(m1,m1))
 res = cudaMallocHost ( cptr_C, m1*m1*sizeof(fp_kind) )
 call c_f_pointer ( cptr_C, C, (/ m1, m1 /) )

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
          
! Clean up the C memory allocated. We need to use the cudaFreeHost function call
  res = cudaFreeHost (cptr_A)
  res = cudaFreeHost (cptr_B)
  res = cudaFreeHost (cptr_C)
end do

end program matrix_multiply

