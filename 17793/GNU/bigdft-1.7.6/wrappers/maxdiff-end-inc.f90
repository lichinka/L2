!> @file
!! Include fortran file for end maxdiff operations
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
  if ( mpirank(mpi_comm) == iroot) then
     do jproc=2,nproc
        do i=1,ndims
           maxdiff=max(maxdiff,&
                abs(array_glob(i,jproc)-array_glob(i,1)))
        end do
     end do
  end if

  call f_free(array_glob)

  !in case of broadcasting the difference should be known by everyone
  !and it should be (roughly) the same
  if (bcst) then
     !never put check =.true. here, otherwise stack overflow
     call mpibcast(maxdiff,1,root=iroot,comm=mpi_comm,check=.false.)
     call mpibarrier(mpi_comm) !redundant?
  end if
