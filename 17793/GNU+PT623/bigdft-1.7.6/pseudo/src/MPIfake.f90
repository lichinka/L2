!> @file
!!    Fake functions for MPI in the case of serial version
!!    Copy of the file @ref flib/src/MPIfake.f90
!!    except the routine @ref mpi_wtime
!!
!! @author
!!    Copyright (C) 2007-2013 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 
!!
!! @todo
!! Use flib library with the pseudo program


subroutine  MPI_INIT(ierr)
  implicit none
  integer, intent(out) :: ierr
  ierr=0
END SUBROUTINE MPI_INIT
        
subroutine MPI_INITIALIZED(init,ierr)
  implicit none
  integer, intent(out) :: init,ierr
  init=1
  ierr=0
END SUBROUTINE  MPI_INITIALIZED

subroutine  MPI_COMM_RANK(MPI_COMM_WORLD,iproc,ierr)
  implicit none
  integer, intent(in) :: MPI_COMM_WORLD
  integer, intent(out) :: iproc,ierr
  iproc=0
  ierr=MPI_COMM_WORLD*0
END SUBROUTINE MPI_COMM_RANK

subroutine  MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)
  implicit none
  integer, intent(in) :: MPI_COMM_WORLD
  integer, intent(out) :: nproc,ierr
  nproc=1
  ierr=MPI_COMM_WORLD*0
END SUBROUTINE MPI_COMM_SIZE

subroutine  MPI_COMM_GROUP(MPI_COMM_WORLD,MPI_GROUP,ierr)
  implicit none
  integer, intent(in) :: MPI_COMM_WORLD
  integer, intent(out) :: MPI_GROUP,ierr
  MPI_GROUP=1
  ierr=MPI_COMM_WORLD*0
END SUBROUTINE MPI_COMM_GROUP

subroutine  MPI_COMM_CREATE(MPI_COMM_WORLD,MPI_GROUP,MPI_COMM,ierr)
  implicit none
  integer, intent(in) :: MPI_COMM_WORLD
  integer, intent(out) :: MPI_GROUP,MPI_COMM,ierr
  MPI_GROUP=1
  MPI_COMM=1
  ierr=MPI_COMM_WORLD*0
END SUBROUTINE MPI_COMM_CREATE

subroutine  MPI_GROUP_INCL(GROUP,N,NRANKS,NEWGROUP,ierr)
  implicit none
  integer, intent(in) :: GROUP,N
  integer, intent(in) :: NRANKS(N)
  integer, intent(out) :: NEWGROUP,ierr
  NEWGROUP=size(NRANKS)
  ierr=GROUP*0
END SUBROUTINE MPI_GROUP_INCL

subroutine mpi_test(request,flag,MPI_Status)
  implicit none
  integer, intent(in) :: request
  integer, intent(out) :: flag
  integer, intent(out) :: MPI_Status
  flag = 1 + 0*request
  MPI_Status = 1
end subroutine mpi_test

subroutine mpi_wait(request,MPI_Status)
  implicit none
  integer, intent(in) :: request
  integer, intent(out) :: MPI_Status
  MPI_Status = 1 + 0*request
end subroutine mpi_wait


!here we have routines which do not transform the argument for nproc==1
!these routines can be safely called also in the serial version
subroutine  MPI_FINALIZE(ierr)
  implicit none
  integer, intent(out) :: ierr
  ierr=0
END SUBROUTINE MPI_FINALIZE

subroutine MPI_BCAST()
  implicit none
END SUBROUTINE MPI_BCAST

subroutine  MPI_BARRIER(MPI_COMM_WORLD,ierr)
  implicit none
  integer, intent(in) :: MPI_COMM_WORLD
  integer, intent(out) :: ierr
  ierr=MPI_COMM_WORLD*0
END SUBROUTINE MPI_BARRIER


! These routines in serial version should not be called.
! A stop is added when necessary, otherwise for copying routines, the corresponding copy 
! is implemented whenever possible
subroutine MPI_REDUCE()
  implicit none
  stop 'MPIFAKE: REDUCE'
END SUBROUTINE MPI_REDUCE

subroutine  MPI_ALLREDUCE()
  implicit none
  !stop 'MPIFAKE: ALLREDUCE' eliminated due to ABINIT module
END SUBROUTINE MPI_ALLREDUCE

subroutine  MPI_ALLGatherV()
  implicit none
  stop 'MPIFAKE: ALLGATHERV'
END SUBROUTINE  MPI_ALLGatherV

subroutine  MPI_ALLGATHER()
  implicit none
  stop 'MPIFAKE: ALLGATHER'
END SUBROUTINE  MPI_ALLGATHER

subroutine  MPI_GatherV()
  implicit none
  stop 'MPIFAKE: GATHERV'
END SUBROUTINE  MPI_GatherV

subroutine  MPI_Gather()
  implicit none
  stop 'MPIFAKE: GATHER'
END SUBROUTINE  MPI_Gather


subroutine  MPI_ALLTOALL()
  implicit none
  stop 'MPIFAKE: ALLTOALL'
END SUBROUTINE  MPI_ALLTOALL

subroutine  MPI_ALLTOALLV()
  implicit none
  stop 'MPIFAKE: ALLTOALLV'
END SUBROUTINE  MPI_ALLTOALLV

subroutine  MPI_REDUCE_SCATTER()
  implicit none
  stop 'MPIFAKE: REDUCE_SCATTER'
END SUBROUTINE  MPI_REDUCE_SCATTER

subroutine  MPI_ABORT()
  implicit none
  stop 'MPIFAKE: MPI_ABORT'
END SUBROUTINE  MPI_ABORT

subroutine  MPI_IRECV()
  implicit none
  stop 'MPIFAKE: IRECV'
END SUBROUTINE  MPI_IRECV

subroutine  MPI_RECV()
  implicit none
  stop 'MPIFAKE: RECV'
END SUBROUTINE  MPI_RECV

subroutine  MPI_ISEND()
  implicit none
  stop 'MPIFAKE: ISEND'
END SUBROUTINE  MPI_ISEND

subroutine  MPI_SEND()
  implicit none
  stop 'MPIFAKE: SEND'
END SUBROUTINE  MPI_SEND

subroutine  MPI_WAITALL()
  implicit none
  stop 'MPIFAKE: WAITALL'
END SUBROUTINE  MPI_WAITALL

subroutine MPI_GET_PROCESSOR_NAME(nodename_local,namelen,ierr)
  implicit none
  integer, intent(out) :: namelen,ierr
  character(len=*), intent(inout) :: nodename_local
  ierr=0
  namelen=9
  nodename_local(1:9)='localhost'
  nodename_local(10:len(nodename_local))=repeat(' ',max(len(nodename_local)-10,0))
END SUBROUTINE  MPI_GET_PROCESSOR_NAME

subroutine  mpi_error_string()
  implicit none
  stop 'MPIFAKE: mpi_error_string'
END SUBROUTINE  MPI_ERROR_STRING

subroutine  MPI_SCATTER()
  implicit none
  stop 'MPIFAKE: SCATTER'
END SUBROUTINE  MPI_SCATTER

subroutine  MPI_SCATTERV()
  implicit none
  stop 'MPIFAKE: SCATTERV'
END SUBROUTINE  MPI_SCATTERV

subroutine mpi_attr_get ()
  implicit none
  stop 'MPIFAKE: mpi_attr_get'
END SUBROUTINE  MPI_ATTR_GET

subroutine mpi_type_size ()
  implicit none
  stop 'MPIFAKE: mpi_type_size'
END SUBROUTINE  MPI_TYPE_SIZE

subroutine mpi_comm_free ()
  implicit none
  stop 'MPIFAKE: mpi_comm_free'
END SUBROUTINE  MPI_COMM_FREE

subroutine mpi_waitany ()
  implicit none
  return !stop 'MPIFAKE: mpi_waitany'
END SUBROUTINE  MPI_WAITANY

subroutine mpi_irsend()
  implicit none
  stop 'MPIFAKE: mpi_irsend'
END SUBROUTINE  MPI_IRSEND

subroutine mpi_rsend()
  implicit none
  stop 'MPIFAKE: mpi_rsend'
END SUBROUTINE  MPI_RSEND

subroutine mpi_win_free()
  implicit none
  stop 'MPIFAKE: mpi_win_free'
END SUBROUTINE  MPI_WIN_FREE

subroutine mpi_win_fence()
  implicit none
  stop 'MPIFAKE: mpi_win_fence'
END SUBROUTINE  MPI_WIN_FENCE

subroutine mpi_win_create()
  implicit none
  stop 'MPIFAKE: mpi_win_create'
END SUBROUTINE  MPI_WIN_CREATE

subroutine mpi_get()
  implicit none
  stop 'MPIFAKE: mpi_get'
END SUBROUTINE  MPI_GET

subroutine mpi_get_address()
  implicit none
  stop 'MPIFAKE: mpi_get_address'
END SUBROUTINE  MPI_GET_ADDRESS

subroutine mpi_type_create_struct()
  implicit none
  stop 'MPIFAKE: mpi_type_create_structure'
END SUBROUTINE  MPI_TYPE_CREATE_STRUCT

subroutine mpi_type_vector()
  implicit none
  stop 'MPIFAKE: mpi_type_vector'
END SUBROUTINE  MPI_TYPE_VECTOR

subroutine mpi_type_create_hvector()
  implicit none
  stop 'MPIFAKE: mpi_type_create_hvector'
END SUBROUTINE  MPI_TYPE_CREATE_HVECTOR

subroutine mpi_type_commit()
  implicit none
  stop 'MPIFAKE: mpi_type_commit'
END SUBROUTINE  MPI_TYPE_COMMIT

subroutine mpi_type_contiguous()
  implicit none
  stop 'MPIFAKE: mpi_type_contiguous'
END SUBROUTINE  MPI_TYPE_CONTIGUOUS

subroutine mpi_type_free()
  implicit none
  stop 'MPIFAKE: mpi_type_free'
END SUBROUTINE  MPI_TYPE_FREE

subroutine mpi_testall()
  implicit none
  stop 'MPIFAKE: mpi_testall'
END SUBROUTINE  MPI_TESTALL

subroutine mpi_info_create()
  implicit none
  stop 'MPIFAKE: mpi_info_create'
END SUBROUTINE  MPI_INFO_CREATE

subroutine mpi_info_set()
  implicit none
  stop 'MPIFAKE: mpi_info_set'
END SUBROUTINE  MPI_INFO_SET

subroutine mpi_info_free()
  implicit none
  stop 'MPIFAKE: mpi_info_free'
END SUBROUTINE  MPI_INFO_FREE

subroutine mpi_group_free()
  implicit none
  stop 'MPIFAKE: mpi_group_free'
END SUBROUTINE  MPI_GROUP_FREE

! Do not include this routine in order to avoid the dependency with nanosec
!real(kind=8) function mpi_wtime()
!  implicit none
!  integer(kind=8) :: itns
!  call nanosec(itns)
!  mpi_wtime=real(itns,kind=8)*1.d-9
!end function mpi_wtime

