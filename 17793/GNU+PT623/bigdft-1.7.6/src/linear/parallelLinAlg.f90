!> @file
!! Wavefunction put into a localisation region
!! @author
!!    Copyright (C) 2011-2012 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> @warning
!! This works only if the matrices have the same sizes for all processes!!
subroutine dgemm_parallel(iproc, nproc, blocksize, comm, transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nproc, blocksize, comm, m, n, k, lda, ldb, ldc
  character(len=1),intent(in) :: transa, transb
  real(kind=8),intent(in) :: alpha, beta
  real(kind=8),dimension(lda,k),intent(in) :: a
  real(kind=8),dimension(ldb,n),intent(in) :: b
  real(kind=8),dimension(ldc,n),intent(out) :: c

  ! Local variables
  integer :: ierr, i, j, istat, iall, ii1, ii2, mbrow, mbcol, nproc_scalapack, nprocrow, nproccol
  integer :: context, irow, icol, numroc, info
  integer :: lnrow_a, lncol_a, lnrow_b, lncol_b, lnrow_c, lncol_c
  real(kind=8) :: tt1, tt2
  real(kind=8),dimension(:,:),allocatable :: la, lb, lc
  integer,dimension(9) :: desc_lc, desc_la, desc_lb
  character(len=*),parameter :: subname='dgemm_parallel'

  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(m)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'
  
  
  ! Initialize blacs context,
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol )
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  
  ! Initialize the result c to zero. For processes participating in the calculation, 
  ! c will be partially (only at the position that process was working on) overwritten with the result. 
  ! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(ldc*n, c(1,1))
  if(irow==-1) call vscal(ldc*n,0.0_wp,c(1,1),1)
  
  ! Only execute this part if this process has a part of the matrix to work on. 
  processIf: if(irow/=-1) then

      ! Determine the size of the local matrix la (lnrow_a x lncol_a):
      lnrow_a = max(numroc(m, mbrow, irow, 0, nprocrow),1)
      lncol_a = max(numroc(k, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local a of size ',lnrow_a,' x ',lncol_a

      ! Determine the size of the local matrix lb (lnrow_b x lncol_b):
      lnrow_b = max(numroc(k, mbrow, irow, 0, nprocrow),1)
      lncol_b = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local b of size ',lnrow_b,' x ',lncol_b

      ! Determine the size of the local matrix lc (lnrow_c x lncol_c):
      lnrow_c = max(numroc(m, mbrow, irow, 0, nprocrow),1)
      lncol_c = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local c of size ',lnrow_c,' x ',lncol_c
  
      ! Initialize descriptor arrays.
      call descinit(desc_la, m, k, mbrow, mbcol, 0, 0, context, lnrow_a, info)
      call descinit(desc_lb, k, n, mbrow, mbcol, 0, 0, context, lnrow_b, info)
      call descinit(desc_lc, m, n, mbrow, mbcol, 0, 0, context, lnrow_c, info)
  
      ! Allocate the local arrays
      la = f_malloc((/ lnrow_a, lncol_a /),id='la')
      lb = f_malloc((/ lnrow_b, lncol_b /),id='lb')
      lc = f_malloc((/ lnrow_c, lncol_c /),id='lc')
  
      ! Copy the global array a to the local array la.
      ! The same for b and lb, cpectively.
      do i=1,k
          do j=1,m
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
      do i=1,n
          do j=1,k
              call pdelset(lb(1,1), j, i, desc_lb, b(j,i))
          end do
      end do
  
  
      ! Do the matrix matrix multiplication.
      call pdgemm(transa, transb, m, n, k, 1.d0, la(1,1), 1, 1, desc_la, lb(1,1), 1, 1, &
                  desc_lb, 0.d0, lc(1,1), 1, 1, desc_lc)
  
  
      ! Put the local result lc to the global result c.
      do i=1,n
          do j=1,m
              call pdelset2(c(j,i), lc(1,1), j, i, desc_lc, 0.d0)
          end do
      end do
  
      ! Deallocate the local arrays.
      call f_free(la)
      call f_free(lb)
      call f_free(lc)

      call blacs_gridexit(context)
  
  end if processIf
  
  
  ! Gather the result on all processes.
  if (nproc > 1) then
     call mpiallred(c(1,1), m*n, mpi_sum, comm)
  end if

  !call blacs_exit(0)

end subroutine dgemm_parallel


!> ATTENTION: This works only if the matrices have the same sizes for all processes!!
subroutine dsymm_parallel(iproc, nproc, blocksize, comm, side, uplo, m, n, alpha, a, lda, b, ldb, beta, c, ldc)
use module_base
implicit none

! Calling arguments
integer,intent(in) :: iproc, nproc, blocksize, comm, m, n, lda, ldb, ldc
character(len=1),intent(in) :: side, uplo
real(kind=8),intent(in) :: alpha, beta
real(kind=8),dimension(lda,m),intent(in) :: a
real(kind=8),dimension(ldb,n),intent(in) :: b
real(kind=8),dimension(ldc,n),intent(out) :: c

! Local variables
integer :: ierr, i, j, istat, iall, ii1, ii2, mbrow, mbcol, nproc_scalapack, nprocrow, nproccol
integer :: context, irow, icol, numroc, info
integer :: lnrow_a, lncol_a, lnrow_b, lncol_b, lnrow_c, lncol_c
real(kind=8) :: tt1, tt2
real(kind=8),dimension(:,:),allocatable :: la, lb, lc
integer,dimension(9) :: desc_lc, desc_la, desc_lb
character(len=*),parameter :: subname='dgemm_parallel'


  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(m)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'
  
  
  ! Initialize blacs context,
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol )
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  
  ! Initialize the result c to zero. For processes participating in the calculation, 
  ! c will be partially (only at the position that process was working on) overwritten with the result. 
  ! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(ldc*n, c(1,1))
  if(irow==-1) call vscal(ldc*n,0.0_wp, c(1,1),1)
  
  ! Only execute this part if this process has a part of the matrix to work on. 
  processIf: if(irow/=-1) then

      ! Determine the size of the local matrix la (lnrow_a x lncol_a):
      lnrow_a = max(numroc(m, mbrow, irow, 0, nprocrow),1)
      lncol_a = max(numroc(m, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local a of size ',lnrow_a,' x ',lncol_a

      ! Determine the size of the local matrix lb (lnrow_b x lncol_b):
      lnrow_b = max(numroc(m, mbrow, irow, 0, nprocrow),1)
      lncol_b = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local b of size ',lnrow_b,' x ',lncol_b

      ! Determine the size of the local matrix lc (lnrow_c x lncol_c):
      lnrow_c = max(numroc(m, mbrow, irow, 0, nprocrow),1)
      lncol_c = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local c of size ',lnrow_c,' x ',lncol_c
  
      ! Initialize descriptor arrays.
      call descinit(desc_la, m, m, mbrow, mbcol, 0, 0, context, lnrow_a, info)
      call descinit(desc_lb, m, n, mbrow, mbcol, 0, 0, context, lnrow_b, info)
      call descinit(desc_lc, m, n, mbrow, mbcol, 0, 0, context, lnrow_c, info)
  
      ! Allocate the local arrays
      la = f_malloc((/ lnrow_a, lncol_a /),id='la')
      lb = f_malloc((/ lnrow_b, lncol_b /),id='lb')
      lc = f_malloc((/ lnrow_c, lncol_c /),id='lc')
  
      ! Copy the global array a to the local array la.
      ! The same for b and lb, cpectively.
      do i=1,m
          do j=1,m
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
      do i=1,n
          do j=1,m
              call pdelset(lb(1,1), j, i, desc_lb, b(j,i))
          end do
      end do
  
  
      ! Do the matrix matrix multiplication.
      call pdsymm(side, uplo, m, n, alpha, la(1,1), 1, 1, desc_la, lb(1,1), 1, 1, &
                  desc_lb, beta, lc(1,1), 1, 1, desc_lc)
  
  
      ! Put the local result lc to the global result c.
      do i=1,n
          do j=1,m
              call pdelset2(c(j,i), lc(1,1), j, i, desc_lc, 0.d0)
          end do
      end do
  
      ! Deallocate the local arrays.
      call f_free(la)
      call f_free(lb)
      call f_free(lc)

      call blacs_gridexit(context)
  
  end if processIf
  
  
  ! Gather the result on all processes.
  if (nproc > 1) then
     call mpiallred(c(1,1), m*n, mpi_sum, comm)
  end if

  !call blacs_exit(0)

end subroutine dsymm_parallel


subroutine dsyev_parallel(iproc, nproc, blocksize, comm, jobz, uplo, n, a, lda, w, info)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in) :: iproc, nproc, blocksize, comm, n, lda
  integer,intent(out) :: info
  character(len=1),intent(in) :: jobz, uplo
  real(kind=8),dimension(lda,n),intent(inout) :: a
  real(kind=8),dimension(n),intent(out) :: w
  
  ! Local variables
  integer :: ierr, mbrow, mbcol, i, j, istat, lwork, ii1, ii2, nproc_scalapack, iall
  integer :: nprocrow, nproccol, context, irow, icol, lnrow, lncol, numroc, liwork, neval_found, neval_computed
  real(kind=8) :: tt1, tt2
  real(kind=8),dimension(:,:),allocatable :: la, lz
  real(kind=8),dimension(:),allocatable :: work, gap
  integer,dimension(9) :: desc_lz, desc_la
  integer,dimension(:),allocatable :: iwork, ifail, icluster
  character(len=*),parameter :: subname='dsyev_parallel'
  
  
  
  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(n)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !nproc_scalapack = nproc
  if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'

  
  ! Initialize blacs context
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol)
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  !write(*,*) 'iproc, irow, icol', iproc, irow, icol
  
  ! Initialize the matrix mat to zero for processes that don't do the calculation.
  ! For processes participating in the diagonalization, 
  ! it will be partially (only at the position that process was working on) overwritten with the result. 
  ! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(lda*n, a(1,1))
  if(irow==-1) call vscal(lda*n,0.0_wp, a(1,1),1)
  ! Everything that follows is only done if the current process is part of the grid.
  processIf: if(irow/=-1) then
      ! Determine the size of the matrix (lnrow x lncol):
      lnrow = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local matrix of size ',lnrow,' x ',lncol
  
      ! Initialize descriptor arrays.
      call descinit(desc_la, n, n, mbrow, mbcol, 0, 0, context, lnrow, info)
      call descinit(desc_lz, n, n, mbrow, mbcol, 0, 0, context, lnrow, info)
  
      ! Allocate the local array lmat
      la = f_malloc((/ lnrow, lncol /),id='la')
  
      ! Copy the global array mat to the local array lmat.
      ! The same for loverlap and overlap, respectively.
      !call vcopy(norb**2, ham(1,1), 1, mat(1,1), 1)
      !call vcopy(norb**2, ovrlp(1,1), 1, overlap(1,1), 1)
      do i=1,n
          do j=1,n
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
  
  
      ! Solve the generalized eigenvalue problem.
      lz = f_malloc((/ lnrow, lncol /),id='lz')
      ifail = f_malloc(n,id='ifail')
      icluster = f_malloc(2*nprocrow*nproccol,id='icluster')
      gap = f_malloc(nprocrow*nproccol,id='gap')
  
      ! workspace query
      lwork=-1
      liwork=-1
      work = f_malloc(100,id='work')
      iwork = f_malloc(100,id='iwork')
      call pdsyevx(jobz, 'a', 'l', n, la(1,1), 1, 1, desc_la, &
                    0.d0, 1.d0, 0, 1, -1.d0, neval_found, neval_computed, w(1), &
                   -1.d0, lz(1,1), 1, 1, desc_lz, work, lwork, iwork, liwork, &
                   ifail, icluster, gap, info)
      lwork=ceiling(work(1))
      lwork=lwork+n**2 !to be sure to have enough workspace, to be optimized later.
      liwork=iwork(1)
      liwork=liwork+n**2 !to be sure to have enough workspace, to be optimized later.
      !write(*,*) 'iproc, lwork, liwork', iproc, lwork, liwork
      call f_free(work)
      call f_free(iwork)
      work = f_malloc(lwork,id='work')
      iwork = f_malloc(liwork,id='iwork')
  
      call pdsyevx(jobz, 'a', 'l', n, la(1,1), 1, 1, desc_la, &
                   0.d0, 1.d0, 0, 1, -1.d0, neval_found, neval_computed, w(1), &
                   -1.d0, lz(1,1), 1, 1, desc_lz, work, lwork, iwork, liwork, &
                   ifail, icluster, gap, info)
      if(info/=0) then
          write(*,'(2(a,i0))') 'ERROR in pdsyevx on process ',iproc,', info=', info
          !stop
      end if

  
      ! Gather together the eigenvectors from all processes and store them in mat.
      do i=1,n
          do j=1,n
              call pdelset2(a(j,i), lz(1,1), j, i, desc_la, 0.d0)
          end do
      end do
  
  
      call f_free(la)
      call f_free(lz)
      call f_free(work)
      call f_free(iwork)
      call f_free(ifail)
      call f_free(icluster)
      call f_free(gap)

      call blacs_gridexit(context)
  
  end if processIF
  
  ! Gather the eigenvectors on all processes.
  if (nproc > 1) then
     call mpiallred(a(1,1), n**2, mpi_sum, comm)
  end if
  
  ! Broadcast the eigenvalues if required. If nproc_scalapack==nproc, then all processes
  ! diagonalized the matrix and therefore have the eigenvalues.
  if(nproc_scalapack/=nproc) then
      call mpi_bcast(w(1), n, mpi_double_precision, 0, comm, ierr)
      call mpi_bcast(info, 1, mpi_integer, 0, comm, ierr)
  end if

  !call blacs_exit(0)

end subroutine dsyev_parallel





subroutine dsygv_parallel(iproc, nproc, blocksize, nprocMax, comm, itype, jobz, uplo, n, a, lda, b, ldb, w, info)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in) :: iproc, nproc, blocksize, nprocMax, comm, itype, n, lda, ldb
  integer,intent(out) :: info
  character(len=1),intent(in) :: jobz, uplo
  real(kind=8),dimension(lda,n),intent(inout) :: a
  real(kind=8),dimension(ldb,n),intent(inout) :: b
  real(kind=8),dimension(n),intent(out) :: w
  
  ! Local variables
  integer :: ierr, mbrow, mbcol, i, j, istat, lwork, ii1, ii2, nproc_scalapack, iall
  integer :: nprocrow, nproccol, context, irow, icol, lnrow, lncol, numroc, liwork, nw_found, nw_computed
  real(kind=8) :: tt1, tt2
  real(kind=8),dimension(:,:),allocatable :: la, lb, lz
  real(kind=8),dimension(:),allocatable :: work, gap
  integer,dimension(9) :: desc_lz, desc_la, desc_lb
  integer,dimension(:),allocatable :: iwork, ifail, icluster
  character(len=*),parameter :: subname='dsygv_parallel'
  
 call timing(iproc,'diagonal_par  ','ON') 
  
  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(n)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  !nproc_scalapack = min(ii1*ii2,nproc)
  nproc_scalapack = min(ii1*ii2,nprocMax)
  !nproc_scalapack = nproc
  if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'
  
  
  ! Initialize blacs context
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol )
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  !write(*,*) 'iproc, irow, icol', iproc, irow, icol
  
  ! Initialize the matrix mat to zero for processes that don't do the calculation.
  ! For processes participating in the diagonalization, 
  ! it will be partially (only at the position that process was working on) overwritten with the result. 
  ! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(lda*n, a(1,1))
  if(irow==-1) call vscal(lda*n,0.0_wp, a(1,1),1)  

  ! Everything that follows is only done if the current process is part of the grid.
  processIf: if(irow/=-1) then
      ! Determine the size of the matrix (lnrow x lncol):
      lnrow = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local matrix of size ',lnrow,' x ',lncol
  
      ! Initialize descriptor arrays.
      call descinit(desc_la, n, n, mbrow, mbcol, 0, 0, context, lnrow, info)
      call descinit(desc_lb, n, n, mbrow, mbcol, 0, 0, context, lnrow, info)
      call descinit(desc_lz, n, n, mbrow, mbcol, 0, 0, context, lnrow, info)
  
      ! Allocate the local array la
      la = f_malloc((/ lnrow, lncol /),id='la')
      lb = f_malloc((/ lnrow, lncol /),id='lb')
  
      ! Copy the global array mat to the local array la.
      ! The same for lb and b, respectively.
      !call vcopy(n**2, a(1,1), 1, mat(1,1), 1)
      !call vcopy(n**2, b(1,1), 1, b(1,1), 1)
      do i=1,n
          do j=1,n
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
              call pdelset(lb(1,1), j, i, desc_lb, b(j,i))
          end do
      end do
  
  
      ! Solve the generalized eigenvalue problem.
      lz = f_malloc((/ lnrow, lncol /),id='lz')
      ifail = f_malloc(n,id='ifail')
      icluster = f_malloc(2*nprocrow*nproccol,id='icluster')
      gap = f_malloc(nprocrow*nproccol,id='gap')
  
      ! workspace query
      lwork=-1
      liwork=-1
      work = f_malloc(100,id='work')
      iwork = f_malloc(100,id='iwork')
      call pdsygvx(itype, jobz, 'a', uplo, n, la(1,1), 1, 1, desc_la, lb(1,1), 1, 1, &
                   desc_lb, 0.d0, 1.d0, 0, 1, -1.d0, nw_found, nw_computed, w(1), &
                   -1.d0, lz(1,1), 1, 1, desc_lz, work, lwork, iwork, liwork, &
                   ifail, icluster, gap, info)
      lwork=ceiling(work(1))
      lwork=lwork+n**2 !to be sure to have enough workspace, to be optimized later.
      liwork=iwork(1)
      liwork=liwork+n**2 !to be sure to have enough workspace, to be optimized later.
      !write(*,*) 'iproc, lwork, liwork', iproc, lwork, liwork
      call f_free(work)
      call f_free(iwork)
  
      work = f_malloc(lwork,id='work')
      iwork = f_malloc(liwork,id='iwork')
  
      call pdsygvx(1, 'v', 'a', 'l', n, la(1,1), 1, 1, desc_la, lb(1,1), 1, 1, &
                   desc_lb, 0.d0, 1.d0, 0, 1, -1.d0, nw_found, nw_computed, w(1), &
                   -1.d0, lz(1,1), 1, 1, desc_lz, work, lwork, iwork, liwork, &
                   ifail, icluster, gap, info)
      if(info/=0) then
          write(*,'(2(a,i0))') 'ERROR in pdsygvx on process ',iproc,', info=',info
      end if
  
      ! Gather together the eigenvectors from all processes and store them in mat.
      do i=1,n
          do j=1,n
              call pdelset2(a(j,i), lz(1,1), j, i, desc_la, 0.d0)
          end do
      end do
  
  
      call f_free(la)
      call f_free(lz)
      call f_free(lb)
      call f_free(work)
      call f_free(iwork)
      call f_free(ifail)
      call f_free(icluster)
      call f_free(gap)

      call blacs_gridexit(context)
  
  end if processIF
  
  ! Gather the eigenvectors on all processes.
  if (nproc > 1) then
     call mpiallred(a(1,1), n**2, mpi_sum, bigdft_mpi%mpi_comm)
  end if
  
  ! Broadcast the eigenvalues if required. If nproc_scalapack==nproc, then all processes
  ! diagonalized the matrix and therefore have the eigenvalues.
  if(nproc_scalapack/=nproc) then
      call mpi_bcast(w(1), n, mpi_double_precision, 0, bigdft_mpi%mpi_comm, ierr)
      call mpi_bcast(info, 1, mpi_integer, 0, bigdft_mpi%mpi_comm, ierr)
  end if

 !call blacs_exit(0)

 call timing(iproc,'diagonal_par  ','OF') 

end subroutine dsygv_parallel




subroutine dgesv_parallel(iproc, nproc, blocksize, comm, n, nrhs, a, lda, b, ldb, info)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer,intent(in):: iproc, nproc, blocksize, comm, n, nrhs, lda, ldb
  integer,intent(out):: info
  real(8),dimension(lda,n),intent(inout):: a
  real(8),dimension(ldb,nrhs),intent(inout):: b
  
  ! Local variables
  integer:: ierr, mbrow, mbcol, i, j, istat, ii1, ii2, nproc_scalapack, iall
  integer:: nprocrow, nproccol, context, irow, icol, lnrow_a, lncol_a, lnrow_b, lncol_b, numroc
  real(8):: tt1, tt2
  real(8),dimension(:,:),allocatable:: la, lb
  integer,dimension(9):: desc_lb, desc_la
  integer,dimension(:),allocatable:: ipiv
  character(len=*),parameter:: subname='dgsev_parallel'
  
  
  
  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(n)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !nproc_scalapack = nproc
  if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'

  
  ! Initialize blacs context
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol)
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  !write(*,*) 'iproc, irow, icol', iproc, irow, icol
  
  ! Initialize the matrix mat to zero for processes that don't do the calculation.
  ! For processes participating in the diagonalization, 
  ! it will be partially (only at the position that process was working on) overwritten with the result. 
  ! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(ldb*nrhs, b(1,1))
  if(irow==-1) call vscal(ldb*nrhs,0.0_wp, b(1,1),1)
  
  ! Everything that follows is only done if the current process is part of the grid.
  processIf: if(irow/=-1) then
      ! Determine the size of the matrix (lnrow x lncol):
      lnrow_a = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol_a = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local matrix of size ',lnrow_a,' x ',lncol_a
      lnrow_b = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol_b = max(numroc(nrhs, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local rhs of size ',lnrow_b,' x ',lncol_b
  
      ! Initialize descriptor arrays.
      call descinit(desc_la, n, n, mbrow, mbcol, 0, 0, context, lnrow_a, info)
      call descinit(desc_lb, n, nrhs, mbrow, mbcol, 0, 0, context, lnrow_b, info)
  
      ! Allocate the local arrays
      la = f_malloc((/ lnrow_a, lncol_a /),id='la')
      lb = f_malloc((/ lnrow_b, lncol_b /),id='lb')
  
      ! Copy the global array mat to the local array lmat.
      ! The same for loverlap and overlap, respectively.
      do i=1,n
          do j=1,n
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
      do i=1,nrhs
          do j=1,n
              call pdelset(lb(1,1), j, i, desc_lb, b(j,i))
          end do
      end do
  
  
      ! Solve the linear system of equations.
      ipiv = f_malloc(lnrow_b+n,id='ipiv')
      call pdgesv(n, nrhs, la(1,1), 1, 1, desc_la, ipiv(1), lb(1,1), 1, 1, desc_lb, info)
      call f_free(ipiv)

  
      ! Gather together the result
      !call to_zero(ldb*nrhs, b(1,1))
      call vscal(ldb*nrhs,0.0_wp, b(1,1),1)
      do i=1,nrhs
          do j=1,n
              call pdelset2(b(j,i), lb(1,1), j, i, desc_lb, 0.d0)
          end do
      end do
  
  
      call f_free(la)
      call f_free(lb)

      call blacs_gridexit(context)
  
  end if processIF

  
  ! Gather the result on all processes
  if (nproc > 1) then
     call mpiallred(b(1,1), n*nrhs, mpi_sum, comm)
  end if
  
  !call blacs_exit(0)

end subroutine dgesv_parallel




subroutine dpotrf_parallel(iproc, nproc, blocksize, comm, uplo, n, a, lda)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nproc, blocksize, comm, n, lda
  character(len=1),intent(in) :: uplo
  real(kind=8),dimension(lda,n),intent(inout) :: a

  ! Local variables
  integer :: ierr, i, j, istat, iall, ii1, ii2, mbrow, mbcol, nproc_scalapack, nprocrow, nproccol
  integer :: context, irow, icol, numroc, info
  integer :: lnrow_a, lncol_a
  real(kind=8) :: tt1, tt2
  real(kind=8),dimension(:,:),allocatable :: la
  integer,dimension(9) :: desc_la
  character(len=*),parameter :: subname='dpotrf_parallel'

  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(n)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'
  
  
  ! Initialize blacs context,
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol )
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  
  !!! Initialize the result c to zero. For processes participating in the calculation, 
  !!! c will be partially (only at the position that process was working on) overwritten with the result. 
  !!! At the end we can the make an allreduce to get the correct result on all processes.
  !!if(irow==-1) call to_zero(ldc*n, c(1,1))
  !if(irow==-1) call to_zero(lda*n, a(1,1))
  if(irow==-1) call vscal(lda*n,0.0_wp, a(1,1),1)
  
  ! Only execute this part if this process has a part of the matrix to work on. 
  processIf: if(irow/=-1) then

      ! Determine the size of the local matrix la (lnrow_a x lncol_a):
      lnrow_a = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol_a = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local a of size ',lnrow_a,' x ',lncol_a

  
      ! Initialize descriptor arrays.
      call descinit(desc_la, n, n, mbrow, mbcol, 0, 0, context, lnrow_a, info)
  
      ! Allocate the local arrays
      la = f_malloc((/ lnrow_a, lncol_a /),id='la')
  
      ! Copy the global array a to the local array la.
      ! The same for b and lb, cpectively.
      do i=1,n
          do j=1,n
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
  
  
      ! Do the cholseky factorization
      call pdpotrf(uplo, n, la, 1, 1, desc_la, info)
  
  
      ! Put the local result la to the global result a.
      do i=1,n
          do j=1,n
              call pdelset2(a(j,i), la(1,1), j, i, desc_la, 0.d0)
          end do
      end do
  
      ! Deallocate the local arrays.
      call f_free(la)

      call blacs_gridexit(context)
  
  end if processIf
  
  
  ! Gather the result on all processes.
  if (nproc > 1) then
     call mpiallred(a(1,1), n*n, mpi_sum, comm)
  end if

  !call blacs_exit(0)

end subroutine dpotrf_parallel


subroutine dpotri_parallel(iproc, nproc, blocksize, comm, uplo, n, a, lda)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nproc, blocksize, comm, n, lda
  character(len=1),intent(in) :: uplo
  real(kind=8),dimension(lda,n),intent(inout) :: a

  ! Local variables
  integer :: ierr, i, j, istat, iall, ii1, ii2, mbrow, mbcol, nproc_scalapack, nprocrow, nproccol
  integer :: context, irow, icol, numroc, info
  integer :: lnrow_a, lncol_a
  real(kind=8) :: tt1, tt2
  real(kind=8),dimension(:,:),allocatable :: la
  integer,dimension(9) :: desc_la
  character(len=*),parameter :: subname='dpotrf_parallel'

  ! Block size for scalapack
  mbrow=blocksize
  mbcol=blocksize
  
  ! Number of processes that will be involved in the calculation
  tt1=dble(n)/dble(mbrow)
  tt2=dble(n)/dble(mbcol)
  ii1=ceiling(tt1)
  ii2=ceiling(tt2)
  nproc_scalapack = min(ii1*ii2,nproc)
  !if(iproc==0) write(*,'(a,i0,a)') 'scalapack will use ',nproc_scalapack,' processes.'
  
  ! process grid: number of processes per row and column
  tt1=sqrt(dble(nproc_scalapack))
  ii1=ceiling(tt1)
  do i=ii1,nproc_scalapack
      if(mod(nproc_scalapack,i)==0) then
          nprocrow=i
          exit
      end if
  end do
  nproccol=nproc_scalapack/nprocrow
  if(iproc==0) write(*,'(a,i0,a,i0,a)') 'calculation is done on process grid with dimension ',nprocrow,' x ',nproccol,'.'
  
  
  ! Initialize blacs context,
  call blacs_get(-1, 0, context)
  call blacs_gridinit(context, 'r', nprocrow, nproccol )
  call blacs_gridinfo(context,nprocrow, nproccol, irow, icol)
  
  !!! Initialize the result c to zero. For processes participating in the calculation, 
  !!! c will be partially (only at the position that process was working on) overwritten with the result. 
  !!! At the end we can the make an allreduce to get the correct result on all processes.
  !if(irow==-1) call to_zero(lda*n, a(1,1))
  if(irow==-1) call vscal(lda*n,0.0_wp, a(1,1),1)
  
  ! Only execute this part if this process has a part of the matrix to work on. 
  processIf: if(irow/=-1) then

      ! Determine the size of the local matrix la (lnrow_a x lncol_a):
      lnrow_a = max(numroc(n, mbrow, irow, 0, nprocrow),1)
      lncol_a = max(numroc(n, mbcol, icol, 0, nproccol),1)
      !write(*,'(a,i0,a,i0,a,i0)') 'iproc ',iproc,' will have a local a of size ',lnrow_a,' x ',lncol_a

  
      ! Initialize descriptor arrays.
      call descinit(desc_la, n, n, mbrow, mbcol, 0, 0, context, lnrow_a, info)
  
      ! Allocate the local arrays
      la = f_malloc((/ lnrow_a, lncol_a /),id='la')
  
      ! Copy the global array a to the local array la.
      ! The same for b and lb, cpectively.
      do i=1,n
          do j=1,n
              call pdelset(la(1,1), j, i, desc_la, a(j,i))
          end do
      end do
  
  
      ! Calculate the inverse, using the cholesky factorization stored in a.
      call pdpotri(uplo, n, la, 1, 1, desc_la, info)
  
  
      ! Put the local result la to the global result a.
      do i=1,n
          do j=1,n
              call pdelset2(a(j,i), la(1,1), j, i, desc_la, 0.d0)
          end do
      end do
  
      ! Deallocate the local arrays.
      call f_free(la)

      call blacs_gridexit(context)
  
  end if processIf
  
  
  ! Gather the result on all processes.
  if (nproc > 1) then
     call mpiallred(a(1,1), n*n, mpi_sum, comm)
  end if

  !call blacs_exit(0)

end subroutine dpotri_parallel
