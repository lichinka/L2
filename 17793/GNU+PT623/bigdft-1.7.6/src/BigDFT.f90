!> @file
!! BigDFT package performing ab initio calculation based on wavelets
!! @author
!!    Copyright (C) 2007-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Main program to calculate electronic structures
program BigDFT
   use module_base
   use bigdft_run!module_types
   use yaml_strings, only: f_strcpy
   use yaml_output, only: yaml_map
   !use internal_coordinates, only : get_neighbors

   implicit none     !< As a general policy, we will have "implicit none" by assuming the same

   character(len=*), parameter :: subname='BigDFT' !< Used by memocc routine (timing)
   integer :: ierr,infocode!,iproc,nproc
   integer :: ncount_bigdft
   !input variables
   type(run_objects) :: runObj
   !output variables
   type(DFT_global_output) :: outs
   character(len=60), dimension(:), allocatable :: arr_posinp,arr_radical
   character(len=60) :: filename,posinp_id!, run_id
   integer :: iconfig,nconfig!,ngroups,igroup
   real(kind=8),dimension(:,:),allocatable :: fxyz
   integer :: iat
   logical :: file_exists
   integer,dimension(:),allocatable :: atoms_ref
   type(dictionary), pointer :: run,options

   call f_lib_initialize()

   call bigdft_command_line_options(options)

   !-finds the number of taskgroup size
   !-initializes the mpi_environment for each group
   !-decides the radical name for each run
   call bigdft_init(options)

   !case with parser information
   !this key will contain the runs which are associated to the current BigDFT instance
   run => dict_iter(options .get. 'BigDFT')
   do while(associated(run))
      call run_objects_init(runObj,run)
      call init_global_output(outs,bigdft_nat(runObj))

      posinp_id = run // 'posinp' 
      call call_bigdft(runObj,outs,infocode)

         if (runObj%inputs%ncount_cluster_x > 1) then
            if (bigdft_mpi%iproc ==0 ) call yaml_map('Wavefunction Optimization Finished, exit signal',infocode)
            ! geometry optimization
            call geopt(runObj,outs,bigdft_mpi%nproc,bigdft_mpi%iproc,ncount_bigdft)
         end if

         !if there is a last run to be performed do it now before stopping
         if (runObj%inputs%last_run == -1) then
            runObj%inputs%last_run = 1
            call call_bigdft(runObj, outs,infocode)
         end if

         if (runObj%inputs%ncount_cluster_x > 1) then
            !filename='final_'//trim(posinp_id)
            call f_strcpy(src='final_'//trim(posinp_id),dest=filename)
            call bigdft_write_atomic_file(runObj,outs,filename,&
                 'FINAL CONFIGURATION',cwd_path=.true.)

!!$            if (bigdft_mpi%iproc == 0) call write_atomic_file(filename,outs%energy,runObj%atoms%astruct%rxyz, &
!!$                 & runObj%atoms%astruct%ixyz_int, runObj%atoms,'FINAL CONFIGURATION',forces=outs%fxyz)
         else
            !filename='forces_'//trim(arr_posinp(iconfig))
            call f_strcpy(src='forces_'//trim(posinp_id),dest=filename)
            call bigdft_write_atomic_file(runObj,outs,filename,&
                 'Geometry + metaData forces',cwd_path=.true.)

!!$            if (bigdft_mpi%iproc == 0) call write_atomic_file(filename,outs%energy,runObj%atoms%astruct%rxyz, &
!!$                 & runObj%atoms%astruct%ixyz_int, runObj%atoms,'Geometry + metaData forces',forces=outs%fxyz)
         end if

         ! Deallocations.
         call deallocate_global_output(outs)
         call free_run_objects(runObj)
         run => dict_next(run)
   end do !loop over iconfig

   call dict_free(options)
   call bigdft_finalize(ierr)


   call f_lib_finalize()

END PROGRAM BigDFT
