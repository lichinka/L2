!> @file
!!  File defining the routines to initialize the communications between processes
!! @author
!!    Copyright (C) 2013-2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Module defining routines to initialize the communications
module communications_init
  use communications_base
  implicit none

  private

  public :: init_comms_linear
  public :: init_comms_linear_sumrho
  public :: initialize_communication_potential
  public :: orbitals_communicators

  contains

    subroutine init_comms_linear(iproc, nproc, imethod_overlap, npsidim_orbs, orbs, lzd, nspin, collcom)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, imethod_overlap, npsidim_orbs, nspin
      type(orbitals_data),intent(in) :: orbs
      type(local_zone_descriptors),intent(in) :: lzd
      type(comms_linear),intent(inout) :: collcom
      
      ! Local variables
      integer :: iorb, iiorb, ilr, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, i3, ii3
      integer :: ipt, nvalp_c, nvalp_f, i3s, n3p, ii, i, jjproc, jproc, ii3min, ii3max, np, n1p1, iseg, j0, j1, ierr
      real(kind=8),dimension(:,:,:),allocatable :: weightppp_c, weightppp_f
      real(kind=8) :: weight_c_tot, weight_f_tot, weightp_c, weightp_f, tt
      integer,dimension(:,:),allocatable :: istartend_c, istartend_f
      integer,dimension(:,:,:),allocatable :: index_in_global_c, index_in_global_f
      
      real(kind=4) :: tr0, tr1, trt0, trt1
      real(kind=8) :: time0, time1, time2, time3, time4, time5, ttime
      logical, parameter :: extra_timing=.false.

      call timing(iproc,'init_collcomm ','ON')
      if (extra_timing) call cpu_time(trt0)   
      call f_routine('init_comms_linear')

      ! method to calculate the overlap
      collcom%imethod_overlap = imethod_overlap

      ! Split up the z dimension in disjoint pieces.
      tt = real(lzd%glr%d%n3+1,kind=8)/real(nproc,kind=8)
      ii = floor(tt)
      n3p = ii
      jjproc = lzd%glr%d%n3+1 - nproc*ii
      if (iproc<=jjproc-1) n3p = n3p + 1
      i=1
      do jproc=0,nproc-1
          if (iproc==jproc) i3s = i
          i = i + ii
          if (jproc<=jjproc-1) i = i + 1
      end do

      ! Determine the maximal extent in teh z direction that iproc has to handle
      ii3min = 1000000000
      ii3max = -1000000000
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          if (lzd%llr(ilr)%wfd%nseg_c>0) then
              n1p1=lzd%llr(ilr)%d%n1+1
              np=n1p1*(lzd%llr(ilr)%d%n2+1)
              do iseg=1,lzd%llr(ilr)%wfd%nseg_c
                  j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
                  j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  ii3=i3+lzd%llr(ilr)%ns3
                  ii3min = min(ii3min,ii3)
                  ii3max = max(ii3max,ii3)
              end do
          end if
      end do
      
    
      !!index_in_global_c=f_malloc((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,0.to.lzd%glr%d%n3/),id='index_in_global_c')
      !!index_in_global_f=f_malloc((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,0.to.lzd%glr%d%n3/),id='index_in_global_f')
      index_in_global_c=f_malloc((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,ii3min.to.ii3max/),id='index_in_global_c')
      index_in_global_f=f_malloc((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,ii3min.to.ii3max/),id='index_in_global_f')

      weightppp_c=f_malloc0((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,1.to.max(1,n3p)/),id='weightppp_c')
      weightppp_f=f_malloc0((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,1.to.max(1,n3p)/),id='weightppp_c')
      
    
      call get_weights(iproc, nproc, orbs, lzd, i3s, n3p, weightppp_c, weightppp_f, weight_c_tot, weight_f_tot)
    
      ! Assign the grid points to the processes such that the work is equally distributed
      istartend_c=f_malloc((/1.to.2,0.to.nproc-1/),id='istartend_c')
      istartend_f=f_malloc((/1.to.2,0.to.nproc-1/),id='istartend_f')

      if (extra_timing) call cpu_time(tr0)
      !call assign_weight_to_process(iproc, nproc, lzd, weight_c, weight_f, weight_c_tot, weight_f_tot, &
      !     istartend_c, istartend_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
      !     weightp_c, weightp_f, collcom%nptsp_c, collcom%nptsp_f, nvalp_c, nvalp_f)
      call assign_weight_to_process(iproc, nproc, lzd, i3s, n3p, weightppp_c, weightppp_f, weight_c_tot, weight_f_tot, &
           istartend_c, istartend_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
           weightp_c, weightp_f, collcom%nptsp_c, collcom%nptsp_f, nvalp_c, nvalp_f)
     
      if (extra_timing) call cpu_time(tr1)
      if (extra_timing) time0=real(tr1-tr0,kind=8)

      if (extra_timing) call cpu_time(tr0)
      !call assign_weight_to_process_new(iproc, nproc, lzd, weight_c, weight_f, weight_c_tot, weight_f_tot, &
      !     istartend_c, istartend_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
      !     weightp_c, weightp_f, collcom%nptsp_c, collcom%nptsp_f, nvalp_c, nvalp_f)
      if (extra_timing) call cpu_time(tr1)
      if (extra_timing) time1=real(tr1-tr0,kind=8)

      if (extra_timing) call cpu_time(tr0)   
      ! Determine the index of a grid point i1,i2,i3 in the compressed array
      call get_index_in_global2(lzd%glr, ii3min, ii3max, index_in_global_c, index_in_global_f)
      if (extra_timing) call cpu_time(tr1)   
      if (extra_timing) time2=real(tr1-tr0,kind=8)

      if (extra_timing) call cpu_time(tr0) 
      ! Determine values for mpi_alltoallv
      call allocate_MPI_communication_arrays(nproc, collcom)
      call determine_communication_arrays(iproc, nproc, npsidim_orbs, orbs, nspin, lzd, istartend_c, istartend_f, &
           ii3min, ii3max, index_in_global_c, index_in_global_f, nvalp_c, nvalp_f, &
           collcom%nsendcounts_c, collcom%nsenddspls_c, collcom%nrecvcounts_c, collcom%nrecvdspls_c, &
           collcom%nsendcounts_f, collcom%nsenddspls_f, collcom%nrecvcounts_f, collcom%nrecvdspls_f)
      if (extra_timing) call cpu_time(tr1)   
      if (extra_timing) time3=real(tr1-tr0,kind=8)
    
      !Now set some integers in the collcomm structure
      collcom%ndimind_c = sum(collcom%nrecvcounts_c)
      collcom%ndimind_f = sum(collcom%nrecvcounts_f)
    
      ! Now rearrange the data on the process to communicate them
      collcom%ndimpsi_c=0
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          collcom%ndimpsi_c=collcom%ndimpsi_c+lzd%llr(ilr)%wfd%nvctr_c
      end do
      collcom%ndimpsi_f=0
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          collcom%ndimpsi_f=collcom%ndimpsi_f+lzd%llr(ilr)%wfd%nvctr_f
      end do
    
      call allocate_local_comms_cubic(collcom)
    
      if (extra_timing) call cpu_time(tr0) 
      call determine_num_orbs_per_gridpoint_new(iproc, nproc, lzd, i3s, n3p, weightppp_c, weightppp_f, &
           istartend_c, istartend_f, &
           istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
           weightp_c, weightp_f, collcom%nptsp_c, collcom%nptsp_f, &
           collcom%norb_per_gridpoint_c, collcom%norb_per_gridpoint_f)
      if (extra_timing) call cpu_time(tr1)   
      if (extra_timing) time4=real(tr1-tr0,kind=8)
      call f_free(weightppp_c)
      call f_free(weightppp_f)
      if (extra_timing) call cpu_time(tr0)   
      call get_switch_indices(iproc, nproc, orbs, lzd, nspin, &
           collcom%nptsp_c, collcom%nptsp_f, collcom%norb_per_gridpoint_c, collcom%norb_per_gridpoint_f, &
           collcom%ndimpsi_c, collcom%ndimpsi_f, istartend_c, istartend_f, &
           istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
           collcom%nsendcounts_c, collcom%nsenddspls_c, collcom%ndimind_c, collcom%nrecvcounts_c, collcom%nrecvdspls_c, &
           collcom%nsendcounts_f, collcom%nsenddspls_f, collcom%ndimind_f, collcom%nrecvcounts_f, collcom%nrecvdspls_f, &
           ii3min, ii3max, index_in_global_c, index_in_global_f, &
           weightp_c, weightp_f, collcom%isendbuf_c, collcom%irecvbuf_c, collcom%isendbuf_f, collcom%irecvbuf_f, &
           collcom%indexrecvorbital_c, collcom%iextract_c, collcom%iexpand_c, &
           collcom%indexrecvorbital_f, collcom%iextract_f, collcom%iexpand_f)
      if (extra_timing) call cpu_time(tr1)   
      if (extra_timing) time5=real(tr1-tr0,kind=8)
    
      ! These variables are used in various subroutines to speed up the code
      collcom%isptsp_c(1) = 0
      do ipt=2,collcom%nptsp_c
            collcom%isptsp_c(ipt) = collcom%isptsp_c(ipt-1) + collcom%norb_per_gridpoint_c(ipt-1)
      end do
      if (maxval(collcom%isptsp_c)>collcom%ndimind_c) stop 'maxval(collcom%isptsp_c)>collcom%ndimind_c'
    
      collcom%isptsp_f(1) = 0
      do ipt=2,collcom%nptsp_f
            collcom%isptsp_f(ipt) = collcom%isptsp_f(ipt-1) + collcom%norb_per_gridpoint_f(ipt-1)
      end do
      if (maxval(collcom%isptsp_f)>collcom%ndimind_f) stop 'maxval(collcom%isptsp_f)>collcom%ndimind_f'
    
      ! Not used any more, so deallocate...
      call f_free(istartend_c)
      call f_free(istartend_f)
    
      call f_free(index_in_global_c)
      call f_free(index_in_global_f)
        
      call f_release_routine()
      
      call timing(iproc,'init_collcomm ','OF')
      if (extra_timing) call cpu_time(trt1)   
      if (extra_timing) ttime=real(trt1-trt0,kind=8)

      if (extra_timing.and.iproc==0) print*,'time0,time1',time0,time1,time2,time3,time4,time5,&
           time0+time1+time2+time3+time4+time5,ttime
  
    end subroutine init_comms_linear


    subroutine get_weights(iproc, nproc, orbs, lzd, i3s, n3p, weightppp_c, weightppp_f, weight_c_tot, weight_f_tot)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, i3s, n3p
      type(orbitals_data),intent(in) :: orbs
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,1:max(1,n3p)),intent(out) :: weightppp_c, weightppp_f
      real(kind=8),intent(out) :: weight_c_tot, weight_f_tot
      
      ! Local variables
      integer :: iorb, iiorb, i0, i1, i2, i3, ii, iseg, ilr, istart, iend, i, j0, j1, ii1, ii2, ii3, n1p1, np
      integer :: i3e, ii3s, ii3e, is, ie, i3start, i3end, size_of_double, ierr, info, window, jproc, ncount
      real(kind=8),dimension(:),allocatable :: reducearr
      real(kind=8),dimension(:,:,:),allocatable :: weightloc
      integer,dimension(:,:),allocatable :: i3startend
      real(kind=8) :: tt
    
      call f_routine(id='get_weights')
    
      ii=(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1)
      weight_c_tot=0.d0
      weight_f_tot=0.d0
    
   
!      orbs_it=>orbital_iterator(orbs)
!      do while(associated(orbs_it))
!        iorb=get_absolute_orbital(orbs_it)
!        ilr=get_orbital_locreg(orbs_it)
!        
!        [....]
!
!        orbs_it=>orbital_next(orbs_it)
!      end do

    


      !@NEW ##################################
      ! coarse part


      i3start=1000000000
      i3end=-1000000000
      do iorb=1,orbs%norbp
          iiorb = orbs%isorb+iorb
          if (orbs%spinsgn(iiorb)<0.d0) cycle !consider only up orbitals
          ilr = orbs%inwhichlocreg(iiorb)
          i3start = min(i3start,lzd%llr(ilr)%ns3)
          i3end = max(i3end,lzd%llr(ilr)%ns3+lzd%llr(ilr)%d%n3)
      end do
      if (orbs%norbp==0) then
         !want i3end-i3start+1=0
         !i3start+1>lzd%glr%d%n3+1 or 1>i3end+1
         i3end=0
         i3start=1
      end if

      weightloc = f_malloc0((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,1.to.(i3end-i3start+1)/),id='weightloc')
      ncount = (lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)
      reducearr = f_malloc(ncount,id='reducearr')


      !call to_zero((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p,weightppp_c(0,0,1))
      i3e=i3s+n3p-1
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          if (orbs%spinsgn(iiorb)<0.d0) cycle !consider only up orbitals
          ilr = orbs%inwhichlocreg(iiorb)
          ii3s = lzd%llr(ilr)%ns3
          ii3e = ii3s + lzd%llr(ilr)%d%n3
          !!write(*,'(a,6i8)') 'init: iproc, iorb, ii3s, ii3e, i3s, i3e', iproc, iorb, ii3s, ii3e, i3s, i3e
          !if (ii3s+1>i3e .or. ii3e+1<i3s) cycle !+1 since ns3 starts at 0, but is3 at 1

          n1p1=lzd%llr(ilr)%d%n1+1
          np=n1p1*(lzd%llr(ilr)%d%n2+1)

          if (lzd%llr(ilr)%wfd%nseg_c>0) then
              !!$omp do
              do iseg=1,lzd%llr(ilr)%wfd%nseg_c
                  j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
                  j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  ii3=i3+lzd%llr(ilr)%ns3
                  if (ii3>i3end) stop 'strange 1'
                  if (ii3<i3start) stop 'strange 2'
                  !if (ii3+1<i3s) cycle
                  !if (ii3+1>i3e) exit
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  !write(*,'(a,8i8)') 'jj, ii, j0, j1, i0, i1, i2, i3',jj,ii,j0,j1,i0,i1,i2,i3
                  ii2=i2+lzd%llr(ilr)%ns2
                  do i=i0,i1
                      ii1=i+lzd%llr(ilr)%ns1
                      !weightppp_c(ii1,ii2,ii3+1-i3s+1)=weightppp_c(ii1,ii2,ii3+1-i3s+1)+1.d0
                      weightloc(ii1,ii2,ii3-i3start+1)=weightloc(ii1,ii2,ii3-i3start+1)+1.d0
                      !weight_c_tot=weight_c_tot+1.d0
                  end do
              end do
              !!$omp end do
          end if
      end do

      !!tt = sum(weightloc_c)
      !!call mpiallred(tt, 1, mpi_sum, bigdft_mpi%mpi_comm)
      !!write(*,*) 'tt1',tt
      


      
      do i3=1,lzd%glr%d%n3+1
          ! Check whether this slice has been (partially) calculated by iproc,
          ! otherwise fill with zero
          if (i3start+1<=i3 .and. i3<=i3end+1) then
              call vcopy(ncount, weightloc(0,0,i3-i3start), 1, reducearr(1), 1)
          else
              call to_zero(ncount, reducearr(1))
          end if

          ! Communicate the slice and the zeros (a bit wasteful...)
          if (nproc>1) then
              call mpiallred(reducearr(1), ncount, mpi_sum, bigdft_mpi%mpi_comm)
          end if

          ! Check whether iproc needs this slice
          if (i3s<=i3 .and. i3<=i3s+n3p-1) then
              call vcopy(ncount, reducearr(1), 1, weightppp_c(0,0,i3-i3s+1), 1)
          end if
      end do
      !!call mpi_type_size(mpi_double_precision, size_of_double, ierr)
      !!call mpi_info_create(info, ierr)
      !!call mpi_info_set(info, "no_locks", "true", ierr)
      !!call mpi_win_create(weightppp_c(0,0,1), &
      !!     int((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p*size_of_double,kind=mpi_address_kind), size_of_double, &
      !!     info, bigdft_mpi%mpi_comm, window, ierr)
      !!call mpi_info_free(info, ierr)
      !!call mpi_win_fence(mpi_mode_noprecede, window, ierr)
      !!dummybuf = f_malloc((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p,id='dummybuf')
      !!i3startend = f_malloc0((/1.to.2,0.to.nproc-1/),id='i3startend')
      !!call mpiallred(i3startend(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm)
      !!do jproc=0,nproc-1
      !!    !Check whether there is an overlap
      !!    is = max(i3startend(1,iproc),i3startend(1,jproc))
      !!    ie = min(i3startend(2,iproc),i3startend(2,jproc))
      !!    if (ie-is>=0) then
      !!        call mpi_fetch_and_op(weightloc_c(0,0,i2-i3startend(1,iproc)+1), dummybuf(1), &
      !!             mpi_double_precision, jproc, &
      !!             int(is-i3startend(1,jproc),kind=mpi_address_kind), mpi_sum, window, ierr)
      !!    end if
      !!end do
      !!call mpi_win_fence(0, window, ierr)
      !!call mpi_win_free(window, ierr)
      !!call f_free(dummybuf)

      weight_c_tot = 0.d0
      tt=0
      do i3=1,n3p
          do i2=0,lzd%glr%d%n2
              do i1=0,lzd%glr%d%n1
                  tt=tt+weightppp_c(i1,i2,i3)
                  weightppp_c(i1,i2,i3)=weightppp_c(i1,i2,i3)**2
                  weight_c_tot = weight_c_tot + weightppp_c(i1,i2,i3)
              end do
          end do
      end do
      if (nproc>1) then
          call mpiallred(weight_c_tot, 1, mpi_sum, bigdft_mpi%mpi_comm)
          call mpiallred(tt, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if



      ! fine part
      if (i3end-i3start>=0) then
          call to_zero((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(i3end-i3start+1), weightloc(0,0,1))
      end if
      !call to_zero((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p,weightppp_f(0,0,1))
      i3e=i3s+n3p-1
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          if (orbs%spinsgn(iiorb)<0.d0) cycle !consider only up orbitals
          ilr = orbs%inwhichlocreg(iiorb)
          ii3s = lzd%llr(ilr)%ns3
          ii3e = ii3s + lzd%llr(ilr)%d%n3
          !!write(*,'(a,6i8)') 'init: iproc, iorb, ii3s, ii3e, i3s, i3e', iproc, iorb, ii3s, ii3e, i3s, i3e
          !if (ii3s+1>i3e .or. ii3e+1<i3s) cycle !+1 since ns3 starts at 0, but is3 at 1

          n1p1=lzd%llr(ilr)%d%n1+1
          np=n1p1*(lzd%llr(ilr)%d%n2+1)

          istart=lzd%llr(ilr)%wfd%nseg_c+min(1,lzd%llr(ilr)%wfd%nseg_f)
          iend=istart+lzd%llr(ilr)%wfd%nseg_f-1
          if (istart<=iend) then
              !!$omp do
              do iseg=istart,iend
                  j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
                  j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  ii3=i3+lzd%llr(ilr)%ns3
                  if (ii3>i3end) stop 'strange 1'
                  if (ii3<i3start) stop 'strange 2'
                  !if (ii3+1<i3s) cycle
                  !if (ii3+1>i3e) exit
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  !write(*,'(a,8i8)') 'jj, ii, j0, j1, i0, i1, i2, i3',jj,ii,j0,j1,i0,i1,i2,i3
                  ii2=i2+lzd%llr(ilr)%ns2
                  do i=i0,i1
                      ii1=i+lzd%llr(ilr)%ns1
                      !weightppp_f(ii1,ii2,ii3+1-i3s+1)=weightppp_f(ii1,ii2,ii3+1-i3s+1)+1.d0
                      weightloc(ii1,ii2,ii3-i3start+1)=weightloc(ii1,ii2,ii3-i3start+1)+1.d0
                  end do
              end do
              !!$omp end do
          end if
      end do

      do i3=1,lzd%glr%d%n3+1
          ! Check whether this slice has been (partially) calculated by iproc,
          ! otherwise fill with zero
          if (i3start+1<=i3 .and. i3<=i3end+1) then
              call vcopy(ncount, weightloc(0,0,i3-i3start), 1, reducearr(1), 1)
          else
              call to_zero(ncount, reducearr(1))
          end if

          ! Communicate the slice and the zeros (a bit wasteful...)
          if (nproc>1) then
              call mpiallred(reducearr(1), ncount, mpi_sum, bigdft_mpi%mpi_comm)
          end if

          ! Check whether iproc needs this slice
          if (i3s<=i3 .and. i3<=i3s+n3p-1) then
              call vcopy(ncount, reducearr(1), 1, weightppp_f(0,0,i3-i3s+1), 1)
          end if
      end do

      call f_free(reducearr)
      call f_free(weightloc)


      weight_f_tot = 0.d0
      do i3=1,n3p
          do i2=0,lzd%glr%d%n2
              do i1=0,lzd%glr%d%n1
                  weightppp_f(i1,i2,i3)=weightppp_f(i1,i2,i3)**2
                  weight_f_tot = weight_f_tot + weightppp_f(i1,i2,i3)
              end do
          end do
      end do
      if (nproc>1) then
          call mpiallred(weight_f_tot, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if
      !write(*,*) 'iproc, weight_f_tot', iproc, weight_f_tot
      !@ENDNEW ##################################


      call f_release_routine()
    
    end subroutine get_weights


    subroutine assign_weight_to_process(iproc, nproc, lzd, i3s, n3p, weightppp_c, weightppp_f, &
               weight_tot_c, weight_tot_f, &
               istartend_c, istartend_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
               weightp_c, weightp_f, nptsp_c, nptsp_f, nvalp_c, nvalp_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, i3s, n3p
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,1:max(1,n3p)),intent(in) :: weightppp_c, weightppp_f
      real(kind=8),intent(in) :: weight_tot_c, weight_tot_f
      integer,dimension(2,0:nproc-1),intent(out) :: istartend_c, istartend_f
      integer,intent(out) :: istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f
      real(kind=8),intent(out) :: weightp_c, weightp_f
      integer,intent(out) :: nptsp_c, nptsp_f
      integer,intent(out) :: nvalp_c, nvalp_f
      
      ! Local variables
      integer :: jproc, i1, i2, i3, ii, istart, iend, j0, j1, ii_c, ii_f, n1p1, np, jjproc
      !!$$integer :: ii2, iiseg, jprocdone
      integer :: i, iseg, i0, iitot, ii3
      real(kind=8) :: tt, tt2, weight_c_ideal, weight_f_ideal, ttt, weight_prev
      real(kind=8),dimension(:,:),allocatable :: weights_c_startend, weights_f_startend
      character(len=*),parameter :: subname='assign_weight_to_process'
      integer,dimension(:),allocatable :: points_per_process, nval_c, nval_f
      integer,dimension(:,:),allocatable :: istartendseg_c
      real(kind=8),dimension(:),allocatable :: weightpp_c, weight_per_process_c
      integer,dimension(:,:),allocatable :: istartendseg_f
      real(kind=8),dimension(:),allocatable :: weightpp_f, weight_per_process_f

      call f_routine(id='assign_weight_to_process')
    
      ! Ideal weight per process.
      weight_c_ideal=weight_tot_c/dble(nproc)
      weight_f_ideal=weight_tot_f/dble(nproc)
    
      weights_c_startend = f_malloc((/ 1.to.2, 0.to.nproc-1 /),id='weights_c_startend')
      weights_f_startend = f_malloc((/ 1.to.2, 0.to.nproc-1 /),id='weights_f_startend')
    
      tt=0.d0
      weights_c_startend(1,0)=0.d0
      do jproc=0,nproc-2
          tt=tt+weight_c_ideal
          weights_c_startend(2,jproc)=dble(floor(tt,kind=8))
          weights_c_startend(1,jproc+1)=dble(floor(tt,kind=8))+1.d0
      end do
      weights_c_startend(2,nproc-1)=weight_tot_c
    
      ! Iterate through all grid points and assign them to processes such that the
      ! load balancing is optimal.


          !@NEW #################################
          call to_zero(2*nproc, istartend_c(1,0))
          weight_per_process_c = f_malloc0(0.to.nproc,id='weight_per_process_c')
          points_per_process = f_malloc0(0.to.nproc-1,id='points_per_process')
          istartendseg_c = f_malloc0((/1.to.2,0.to.nproc-1/),id='istartendseg_c')
          nval_c = f_malloc0(0.to.nproc,id='nval_c')
          weightpp_c = f_malloc0(0.to.nproc,id='weightpp_c')

          weight_per_process_c(iproc) = sum(weightppp_c)
          if (nproc>1) then
              call mpiallred(weight_per_process_c(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          if (sum(weight_per_process_c)/=weight_tot_c) then
              write(*,'(a,2f16.2)') 'sum(weight_per_process_c), weight_tot_c', sum(weight_per_process_c), weight_tot_c
              stop 'sum(weight_per_process_c)/=weight_tot_c'
          end if
          if (iproc==0) then
              weight_prev = 0.d0
              jjproc = 0
          else
              weight_prev = sum(weight_per_process_c(0:iproc-1)) !total weight of process up to iproc-1
              jjproc = nproc-1
              do jproc=0,nproc-1
                  !write(*,'(a,2i5,3f10.1)') 'iproc, jproc, weight_prev, (weights_c_startend(:,jproc))', iproc, jproc, weight_prev, (weights_c_startend(:,jproc))
                  !if (weight_prev<weights_c_startend(1,jproc)) then
                  if (weights_c_startend(1,jproc)<=weight_prev .and. weight_prev<=weights_c_startend(2,jproc)) then
                      ! This process starts the assignment with process jjproc
                      jjproc = jproc
                      exit
                  end if
                  !if (weight_prev+1.d0<=weights_c_startend(1,jproc) .and. &
                  !     weight_prev+weight_per_process_c(iproc)>=weights_c_startend(1,jproc)) then
                  !    jjproc=max(jproc-1,0)
                  !    exit
                  !end if
              end do
          end if

          ! Determine the number of grid points handled by each process
          n1p1=lzd%glr%d%n1+1
          np=n1p1*(lzd%glr%d%n2+1)
          do iseg=1,lzd%glr%wfd%nseg_c
              j0=lzd%glr%wfd%keygloc(1,iseg)
              j1=lzd%glr%wfd%keygloc(2,iseg)
              ii=j0-1
              i3=ii/np
              if (i3+1<i3s) cycle
              if (i3+1>i3s+n3p-1) exit
              ii3=i3-i3s+1
              ii=ii-i3*np
              i2=ii/n1p1
              i0=ii-i2*n1p1
              i1=i0+j1-j0
              do i=i0,i1
                  points_per_process(iproc) = points_per_process(iproc) + 1
              end do
          end do
          if (nproc>1) then
              call mpiallred(points_per_process(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if



          tt = weight_prev
          ! number of gris points handled by processes 0..iproc-1
          iitot = sum(points_per_process(0:iproc-1)) !total number of grid points up to iproc-1
          !!write(*,'(a,i7,f14.1,2i9)') 'start: iproc, tt, iitot, jjproc', iproc, tt, iitot, jjproc
          !!write(*,'(a,i5,100f12.1)') 'iproc, weights_c_startend', iproc, weights_c_startend
          ! only do this on task 0 due to the allreduce later
          if (iproc==0) then
              istartend_c(1,0) = 1
              istartendseg_c(1,0) = 1
          end if
          n1p1=lzd%glr%d%n1+1
          np=n1p1*(lzd%glr%d%n2+1)
          do iseg=1,lzd%glr%wfd%nseg_c
              j0=lzd%glr%wfd%keygloc(1,iseg)
              j1=lzd%glr%wfd%keygloc(2,iseg)
              ii=j0-1
              i3=ii/np
              if (i3+1<i3s) cycle
              if (i3+1>i3s+n3p-1) exit
              ii3=i3+1-i3s+1
              ii=ii-i3*np
              i2=ii/n1p1
              i0=ii-i2*n1p1
              i1=i0+j1-j0
              do i=i0,i1
                  iitot = iitot + 1
                  tt = tt + weightppp_c(i,i2,ii3)
                  if (jjproc<nproc-1) then
                      if (tt>=weights_c_startend(1,jjproc+1)) then
                          !write(*,'(a,2i6,2f10.1)') 'iproc, jjproc, tt, weights_c_startend(1,jjproc+1)', iproc, jjproc, tt, weights_c_startend(1,jjproc+1)
                          jjproc = jjproc + 1
                          istartend_c(1,jjproc) = iitot
                          istartendseg_c(1,jjproc) = iseg
                      end if
                  end if
                  if (weightppp_c(i,i2,ii3)>0.d0) then
                      nval_c(jjproc) = nval_c(jjproc) + nint(sqrt(weightppp_c(i,i2,ii3))) !total number of grid points to be handled by process jjproc
                      weightpp_c(jjproc) = weightpp_c(jjproc) + weightppp_c(i,i2,ii3) !total weight to be handled by process jjproc
                  end if
              end do
          end do

          ! Communicate the data and assign the processor specific values
          if (nproc>1) then
              call mpiallred(istartend_c(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm) !a bit wasteful to communicate the zeros of the second entry...
              call mpiallred(istartendseg_c(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm) !a bit wasteful to communicate the zeros of the second entry...
              call mpiallred(nval_c(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
              call mpiallred(weightpp_c(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          do jproc=0,nproc-2
              istartend_c(2,jproc) = istartend_c(1,jproc+1)-1
              istartendseg_c(2,jproc) = istartendseg_c(1,jproc+1)
          end do
          istartend_c(2,nproc-1) = lzd%glr%wfd%nvctr_c
          istartendseg_c(2,nproc-1) = lzd%glr%wfd%nseg_c
          istartp_seg_c = istartendseg_c(1,iproc)
          iendp_seg_c = istartendseg_c(2,iproc)
          nvalp_c = nval_c(iproc)
          weightp_c = weightpp_c(iproc)
          nptsp_c=istartend_c(2,iproc)-istartend_c(1,iproc)+1

          call f_free(weight_per_process_c)
          call f_free(points_per_process)
          call f_free(istartendseg_c)
          call f_free(nval_c)
          call f_free(weightpp_c)
          !write(*,'(a,i7,100i12)') 'new: iproc, istartend_c',iproc, istartend_c 
          !!write(*,'(a,i7,100i12)') 'new: iproc, istartp_seg_c', iproc, istartp_seg_c
          !!write(*,'(a,i7,100i12)') 'new: iproc, iendp_seg_c', iproc, iendp_seg_c
          !!write(*,'(a,i7,100i12)') 'new: iproc, nvalp_c', iproc, nvalp_c
          !!write(*,'(a,i7,100f12.1)') 'new: iproc, weightp_c', iproc, weightp_c
          !!write(*,'(a,i7,100i12)') 'new: iproc, nptsp_c', iproc, nptsp_c

          ! Some checks
          ii_c=istartend_c(2,iproc)-istartend_c(1,iproc)+1
          if (nproc > 1) then
            call mpiallred(ii_c, 1, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          if(ii_c/=lzd%glr%wfd%nvctr_c) then
             write(*,*) 'ii_c/=lzd%glr%wfd%nvctr_c',ii_c,lzd%glr%wfd%nvctr_c
             stop
          end if
    
          if (nproc > 1) then
             call mpiallred(weightp_c,1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=tt)
          else
              tt=weightp_c
          end if
          if(tt/=weight_tot_c) then
              write(*,*) 'tt, weight_tot_c', tt, weight_tot_c
              stop 'wrong partition of coarse weights'
          end if

          if (nproc > 1) then
             call mpiallred(nptsp_c, 1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=ii)
          else
              ii=nptsp_c
          end if
          if(ii/=lzd%glr%wfd%nvctr_c) then
              write(*,*) 'ii, lzd%glr%wfd%nvctr_c', ii, lzd%glr%wfd%nvctr_c
              stop 'wrong partition of coarse grid points'
          end if
          !@END NEW #############################


      !!end if
    
      ! Same for fine region
      tt=0.d0
      weights_f_startend(1,0)=0.d0
      do jproc=0,nproc-2
          tt=tt+weight_f_ideal
          weights_f_startend(2,jproc)=dble(floor(tt,kind=8))
          weights_f_startend(1,jproc+1)=dble(floor(tt,kind=8))+1.d0
      end do
      weights_f_startend(2,nproc-1)=weight_tot_f
    



          !@NEW #################################
          call to_zero(2*nproc, istartend_f(1,0))
          weight_per_process_f = f_malloc0(0.to.nproc,id='weight_per_process_f')
          points_per_process = f_malloc0(0.to.nproc-1,id='points_per_process')
          istartendseg_f = f_malloc0((/1.to.2,0.to.nproc-1/),id='istartendseg_f')
          nval_f = f_malloc0(0.to.nproc,id='nval_f')
          weightpp_f = f_malloc0(0.to.nproc,id='weightpp_f')

          weight_per_process_f(iproc) = sum(weightppp_f)
          if (nproc>1) then
              call mpiallred(weight_per_process_f(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          if (sum(weight_per_process_f)/=weight_tot_f) then
              write(*,'(a,2f16.2)') 'sum(weight_per_process_f), weight_tot_f', sum(weight_per_process_f), weight_tot_f
              stop 'sum(weight_per_process_f)/=weight_tot_f'
          end if
          if (iproc==0) then
              weight_prev = 0.d0
              jjproc = 0
          else
              weight_prev = sum(weight_per_process_f(0:iproc-1)) !total weight of process up to iproc-1
              jjproc = nproc-1
              do jproc=0,nproc-1
                  !write(*,'(a,2i5,3f10.1)') 'iproc, jproc, weight_prev, (weights_f_startend(:,jproc))', iproc, jproc, weight_prev, (weights_f_startend(:,jproc))
                  if (weights_f_startend(1,jproc)<=weight_prev .and. weight_prev<=weights_f_startend(2,jproc)) then
                      ! This process starts the assignment with process jjproc
                      jjproc = jproc
                      exit
                  end if
                  !if (weight_prev+1.d0<=weights_f_startend(1,jproc) .and. &
                  !    weight_prev+weight_per_process_f(iproc)>=weights_f_startend(1,jproc)) then
                  !    jjproc=max(jproc-1,0)
                  !    exit
                  !end if
              end do
          end if

          ! Determine the number of grid points handled by each process
          n1p1=lzd%glr%d%n1+1
          np=n1p1*(lzd%glr%d%n2+1)
          istart=lzd%glr%wfd%nseg_c+min(1,lzd%glr%wfd%nseg_f)
          iend=istart+lzd%glr%wfd%nseg_f-1
          if (istart<=iend) then
              do iseg=istart,iend
                  j0=lzd%glr%wfd%keygloc(1,iseg)
                  j1=lzd%glr%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  if (i3+1<i3s) cycle
                  if (i3+1>i3s+n3p-1) exit
                  ii3=i3-i3s+1
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  do i=i0,i1
                      points_per_process(iproc) = points_per_process(iproc) + 1
                  end do
              end do
          end if
          if (nproc>1) then
              call mpiallred(points_per_process(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if



          tt = weight_prev
          ! number of gris points handled by processes 0..iproc-1
          iitot = sum(points_per_process(0:iproc-1)) !total number of grid points up to iproc-1
          !!write(*,'(a,i7,f14.1,2i9)') 'start: iproc, tt, iitot, jjproc', iproc, tt, iitot, jjproc
          !!write(*,'(a,i5,100f12.1)') 'iproc, weights_f_startend', iproc, weights_f_startend
          ! only do this on task 0 due to the allreduce later
          n1p1=lzd%glr%d%n1+1
          np=n1p1*(lzd%glr%d%n2+1)
          istart=lzd%glr%wfd%nseg_c+min(1,lzd%glr%wfd%nseg_f)
          iend=istart+lzd%glr%wfd%nseg_f-1
          if (iproc==0) then
              istartend_f(1,0) = 1
              istartendseg_f(1,0) = istart
          end if
          if (istart<=iend) then
              do iseg=istart,iend
                  j0=lzd%glr%wfd%keygloc(1,iseg)
                  j1=lzd%glr%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  if (i3+1<i3s) cycle
                  if (i3+1>i3s+n3p-1) exit
                  ii3=i3+1-i3s+1
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  do i=i0,i1
                      iitot = iitot + 1
                      tt = tt + weightppp_f(i,i2,ii3)
                      if (jjproc<nproc-1) then
                          if (tt>=weights_f_startend(1,jjproc+1)) then
                              !write(*,'(a,2i6,2f10.1)') 'iproc, jjproc, tt, weights_f_startend(1,jjproc+1)', iproc, jjproc, tt, weights_f_startend(1,jjproc+1)
                              jjproc = jjproc + 1
                              istartend_f(1,jjproc) = iitot
                              istartendseg_f(1,jjproc) = iseg
                          end if
                      end if
                      if (weightppp_f(i,i2,ii3)>0.d0) then
                          nval_f(jjproc) = nval_f(jjproc) + nint(sqrt(weightppp_f(i,i2,ii3))) !total number of grid points to be handled by process jjproc
                          weightpp_f(jjproc) = weightpp_f(jjproc) + weightppp_f(i,i2,ii3) !total weight to be handled by process jjproc
                      end if
                  end do
              end do
          !!!!end if

          ! Communicate the data and assign the processor specific values
          if (nproc>1) then
              call mpiallred(istartend_f(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm) !a bit wasteful to communicate the zeros of the second entry...
              call mpiallred(istartendseg_f(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm) !a bit wasteful to communicate the zeros of the second entry...
              call mpiallred(nval_f(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
              call mpiallred(weightpp_f(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          do jproc=0,nproc-2
              istartend_f(2,jproc) = istartend_f(1,jproc+1)-1
              istartendseg_f(2,jproc) = istartendseg_f(1,jproc+1)
          end do
          istartend_f(2,nproc-1) = lzd%glr%wfd%nvctr_f
          istartendseg_f(2,nproc-1) = lzd%glr%wfd%nseg_c + lzd%glr%wfd%nseg_f
          istartp_seg_f = istartendseg_f(1,iproc)
          iendp_seg_f = istartendseg_f(2,iproc)
          nvalp_f = nval_f(iproc)
          weightp_f = weightpp_f(iproc)
          nptsp_f=istartend_f(2,iproc)-istartend_f(1,iproc)+1

          call f_free(weight_per_process_f)
          call f_free(points_per_process)
          call f_free(istartendseg_f)
          call f_free(nval_f)
          call f_free(weightpp_f)
          !write(*,'(a,i7,100i12)') 'new: iproc, istartend_f',iproc, istartend_f 
          !!write(*,'(a,i7,100i12)') 'new: iproc, istartp_seg_f', iproc, istartp_seg_f
          !!write(*,'(a,i7,100i12)') 'new: iproc, iendp_seg_f', iproc, iendp_seg_f
          !write(*,'(a,i7,100i12)') 'new: iproc, nvalp_f', iproc, nvalp_f
          !!write(*,'(a,i7,100f12.1)') 'new: iproc, weightp_f', iproc, weightp_f
          !!write(*,'(a,i7,100i12)') 'new: iproc, nptsp_f', iproc, nptsp_f

          ! Some checks
          ii_f=istartend_f(2,iproc)-istartend_f(1,iproc)+1
          if (nproc > 1) then
            call mpiallred(ii_f, 1, mpi_sum, bigdft_mpi%mpi_comm)
          end if
          if(ii_f/=lzd%glr%wfd%nvctr_f) then
             write(*,*) 'ii_f/=lzd%glr%wfd%nvctr_f',ii_f,lzd%glr%wfd%nvctr_f
             stop
          end if
    
          if (nproc > 1) then
             call mpiallred(weightp_f,1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=tt)
          else
              tt=weightp_f
          end if
          if(tt/=weight_tot_f) then
              write(*,*) 'tt, weight_tot_f', tt, weight_tot_f
              stop 'wrong partition of coarse weights'
          end if

          if (nproc > 1) then
             call mpiallred(nptsp_f, 1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=ii)
          else
              ii=nptsp_f
          end if
          if(ii/=lzd%glr%wfd%nvctr_f) then
              write(*,*) 'ii, lzd%glr%wfd%nvctr_f', ii, lzd%glr%wfd%nvctr_f
              stop 'wrong partition of coarse grid points'
          end if
          !@END NEW #############################



      end if
    
    
    
    
      call f_free(weights_c_startend)
      call f_free(weights_f_startend)
    

      call f_release_routine()
      
    end subroutine assign_weight_to_process

    subroutine assign_weight_to_process_new(iproc, nproc, lzd, weight_c, weight_f, weight_tot_c, weight_tot_f, &
               istartend_c, istartend_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
               weightp_c, weightp_f, nptsp_c, nptsp_f, nvalp_c, nvalp_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,0:lzd%glr%d%n3),intent(in) :: weight_c, weight_f
      real(kind=8),intent(in) :: weight_tot_c, weight_tot_f
      integer,dimension(2,0:nproc-1),intent(out) :: istartend_c, istartend_f
      integer,intent(out) :: istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f
      real(kind=8),intent(out) :: weightp_c, weightp_f
      integer,intent(out) :: nptsp_c, nptsp_f
      integer,intent(out) :: nvalp_c, nvalp_f
      
      ! Local variables
      integer :: jproc, i1, i2, i3, ii, istart, iend, j0, j1, ii_c, ii_f, n1p1, np, it, npr
      integer :: i, iseg, i0, iitot, eproc, sproc, ith, nth, ierr, eseg, iitotseg, iitote
      real(kind=8) :: tt, ttseg, tt2, weight_c_ideal, weight_f_ideal, nproc_block, ttt
      real(kind=8),dimension(:,:),allocatable :: weights_c_startend, weights_f_startend
      real(kind=4) :: tr0, tr1
      real(kind=8) :: time1, time2
      !$ integer  :: omp_get_thread_num,omp_get_max_threads
    
      ! Ideal weight per process.
      weight_c_ideal=weight_tot_c/dble(nproc)
      weight_f_ideal=weight_tot_f/dble(nproc)
    
      weights_c_startend = f_malloc((/ 1.to.2, 0.to.nproc-1 /),id='weights_c_startend')
      weights_f_startend = f_malloc((/ 1.to.2, 0.to.nproc-1 /),id='weights_f_startend')
    
      tt=0.d0
      weights_c_startend(1,0)=0.d0
      do jproc=0,nproc-2
          tt=tt+weight_c_ideal
          weights_c_startend(2,jproc)=dble(floor(tt,kind=8))
          weights_c_startend(1,jproc+1)=dble(floor(tt,kind=8))+1.d0
      end do
      weights_c_startend(2,nproc-1)=weight_tot_c

      !split into subroutine and divide into larger sections so each thread does one chunk of MPI procs
      istart=1
      iend=lzd%glr%wfd%nseg_c

      if (nproc==1) then
         istartend_c(1,0)=1
         istartend_c(2,0)=lzd%glr%wfd%nvctr_c
         weightp_c = weight_tot_c 
         istartp_seg_c=istart
         iendp_seg_c=iend
         ttt=0.d0
         do i1=0,lzd%glr%d%n1
            do i2=0,lzd%glr%d%n2
               do i3=0,lzd%glr%d%n3
                  ttt = ttt+sqrt(weight_c(i1,i2,i3))
               end do
            end do
         end do
         nvalp_c=nint(ttt)
      else
         nth=1
         !$  nth = OMP_GET_max_threads()
         nproc_block=real(nproc,kind=8)/nth

         !$omp parallel default(none) &
         !$omp private(sproc,eproc,iitot,iitote,iitotseg,ttseg,eseg,ith,time1,tr0,tr1,time2) &
         !$omp shared(nproc_block,istart,iend,lzd,weight_c,iproc,nproc,weights_c_startend,weight_tot_c) &
         !$omp shared(istartp_seg_c,iendp_seg_c,weightp_c,istartend_c,nth,nvalp_c)
         ith=0
         !$ ith = OMP_GET_THREAD_NUM()
         !check we have enough MPI tasks for each thread
         if (nproc_block>1) then
            sproc=nint(nproc_block*ith)
            if (ith==nth-1) then
               eproc=nproc-1
            else
               eproc=nint(nproc_block*(ith+1))-1
            end if
         else
            if (ith<nproc) then
               sproc=ith
               eproc=ith
            else
               sproc=-1
               eproc=-1
            end if
         end if

         !call cpu_time(tr0)
         if (ith/=0.and.sproc/=-1) then
            call assign_weight_to_process_find_end_point(nproc, sproc, lzd, weight_c, &
                 weights_c_startend, istart, iend, ttseg, iitotseg, eseg)
         else
            ttseg=0.d0
            iitotseg=0
            eseg=istart
         end if
         !call cpu_time(tr1)
         !time2=real(tr1-tr0,kind=8)

         if (sproc/=-1) call assign_weight_to_process_sub(iproc, eproc+1, lzd, weight_c, weight_tot_c, &
              istartend_c(1,sproc), istartp_seg_c, iendp_seg_c, weightp_c, weights_c_startend(1,sproc), &
              eseg, iend, ttseg, iitotseg, sproc, nvalp_c)
         !call cpu_time(tr0)
         !time1=real(tr0-tr1,kind=8)
         !if (iproc==0) print*,'thread times',iproc,ith,time2,time1,time1+time2
         !$omp end parallel

         ! check
         !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !if (iproc==0) print*,''
         !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !do jproc=0,nproc-1!sproc,eproc
         !   if (iproc==jproc) then
         !      print*,istartend_c(1,jproc),istartend_c(2,jproc),nint(weightp_c),nint(weight_tot_c/dble(nproc)),nint(weightp_c-weight_tot_c/dble(nproc))
         !   end if
         !   call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !end do
      end if

      ! Same for fine region
      tt=0.d0
      weights_f_startend(1,0)=0.d0
      do jproc=0,nproc-2
          tt=tt+weight_f_ideal
          weights_f_startend(2,jproc)=dble(floor(tt,kind=8))
          weights_f_startend(1,jproc+1)=dble(floor(tt,kind=8))+1.d0
      end do
      weights_f_startend(2,nproc-1)=weight_tot_f
    
      istart=lzd%glr%wfd%nseg_c+min(1,lzd%glr%wfd%nseg_f)
      iend=istart+lzd%glr%wfd%nseg_f-1

      if (nproc==1) then
         istartend_f(1,0)=1
         istartend_f(2,0)=lzd%glr%wfd%nvctr_f
         weightp_f = weight_tot_f
         istartp_seg_f=istart
         iendp_seg_f=iend
         ttt=0.d0
         do i1=0,lzd%glr%d%n1
            do i2=0,lzd%glr%d%n2
               do i3=0,lzd%glr%d%n3
                  ttt = ttt+sqrt(weight_f(i1,i2,i3))
               end do
            end do
         end do
         nvalp_f=nint(ttt)
      else

         !$omp parallel default(none) &
         !$omp private(sproc,eproc,iitot,iitote,iitotseg,ttseg,eseg,ith) &
         !$omp shared(nproc_block,istart,iend,lzd,weight_f,iproc,nproc,weights_f_startend,weight_tot_f) &
         !$omp shared(istartp_seg_f,iendp_seg_f,weightp_f,istartend_f,nth,nvalp_f)
         ith=0
         !$ ith = OMP_GET_THREAD_NUM()
         !check we have enough MPI tasks for each thread
         if (nproc_block>1) then
            sproc=nint(nproc_block*ith)
            if (ith==nth-1) then
               eproc=nproc-1
            else
               eproc=nint(nproc_block*(ith+1))-1
            end if
         else
            if (ith<nproc) then
               sproc=ith
               eproc=ith
            else
               sproc=-1
               eproc=-1
            end if
         end if

         if (ith/=0.and.sproc/=-1) then
            call assign_weight_to_process_find_end_point(nproc, sproc, lzd, weight_f, &
                 weights_f_startend, istart, iend, ttseg, iitotseg, eseg)
         else
            ttseg=0.d0
            iitotseg=0
            eseg=istart
         end if

         if (sproc/=-1)call assign_weight_to_process_sub(iproc, eproc+1, lzd, weight_f, weight_tot_f, &
              istartend_f(1,sproc), istartp_seg_f, iendp_seg_f, weightp_f, weights_f_startend(1,sproc), &
              eseg, iend, ttseg, iitotseg, sproc, nvalp_f)
         !$omp end parallel

         ! check
         !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !if (iproc==0) print*,''
         !call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !do jproc=0,nproc-1!sproc,eproc
         !   if (iproc==jproc) then
         !      print*,istartend_f(1,jproc),istartend_f(2,jproc),nint(weightp_f),nint(weight_tot_f/dble(nproc)),nint(weightp_f-weight_tot_f/dble(nproc))
         !   end if
         !   call mpi_barrier(bigdft_mpi%mpi_comm,ierr)
         !end do
      end if

      call f_free(weights_c_startend)
      call f_free(weights_f_startend)
    
      nptsp_c=istartend_c(2,iproc)-istartend_c(1,iproc)+1
      nptsp_f=istartend_f(2,iproc)-istartend_f(1,iproc)+1
        
      ! some check
      ii_f=istartend_f(2,iproc)-istartend_f(1,iproc)+1
      if (nproc > 1) then
        call mpiallred(ii_f, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if
      !if(ii_f/=lzd%glr%wfd%nvctr_f) stop 'assign_weight_to_process: ii_f/=lzd%glr%wfd%nvctr_f'
      if(ii_f/=lzd%glr%wfd%nvctr_f) then
         write(*,*) 'ii_f/=lzd%glr%wfd%nvctr_f',ii_f,lzd%glr%wfd%nvctr_f
         if (iproc==0) then
             do jproc=0,nproc-1
                 write(*,*) jproc, istartend_f(1,jproc), istartend_f(2,jproc)
             end do
         end if
         stop
      end if
     
      ii_c=istartend_c(2,iproc)-istartend_c(1,iproc)+1
      if (nproc > 1) then
        call mpiallred(ii_c, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if
      if(ii_c/=lzd%glr%wfd%nvctr_c) then
         write(*,*) 'ii_c/=lzd%glr%wfd%nvctr_c',ii_c,lzd%glr%wfd%nvctr_c
         stop
      end if
    
      ! some checks
      if (nproc > 1) then
         call mpiallred(weightp_c,1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=tt)
         !call mpi_allreduce(weightp_c, tt, 1, mpi_double_precision, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      else
          tt=weightp_c
      end if
      if(tt/=weight_tot_c) then
         write(*,*) 'wrong partition of coarse weights',tt,weight_tot_c
         stop
      end if
      if (nproc > 1) then
         call mpiallred(weightp_f,1,mpi_sum,bigdft_mpi%mpi_comm,recvbuf=tt)
         !call mpi_allreduce(weightp_f, tt, 1, mpi_double_precision, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      else
          tt=weightp_f
      end if     
      if(tt/=weight_tot_f) then
         write(*,*) 'wrong partition of fine weights',tt,weight_tot_f
         stop
      end if
      if (nproc > 1) then
         call mpiallred(nptsp_c, 1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=ii)
         !call mpi_allreduce(nptsp_c, ii, 1, mpi_integer, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      else
          ii=nptsp_c
      end if
      if(ii/=lzd%glr%wfd%nvctr_c) then
         write(*,*) 'wrong partition of coarse grid points',ii,lzd%glr%wfd%nvctr_c
         stop
      end if
      if (nproc > 1) then
         call mpiallred(nptsp_f, 1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=ii)
         !call mpi_allreduce(nptsp_f, ii, 1, mpi_integer, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      else
          ii=nptsp_f
      end if
      if(ii/=lzd%glr%wfd%nvctr_f) then
         write(*,*) 'wrong partition of fine grid points',ii,lzd%glr%wfd%nvctr_f
         stop
      end if
      
    end subroutine assign_weight_to_process_new

    !better name and change names to indicate coarse OR fine
    subroutine assign_weight_to_process_sub(iproc, nproc, lzd, weight_c, weight_tot_c, &
               istartend_c, istartp_seg_c, iendp_seg_c, weightp_c, weights_c_startend,&
               istart, iend, ttseg, iitotseg, jprocs, nvalp_c)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,0:lzd%glr%d%n3),intent(in) :: weight_c
      real(kind=8),intent(in) :: weight_tot_c
      integer,dimension(2,jprocs:nproc-1),intent(out) :: istartend_c
      integer,intent(inout) :: istartp_seg_c, iendp_seg_c
      real(kind=8),intent(inout) :: weightp_c
      real(kind=8),dimension(1:2,jprocs:nproc-1),intent(in) :: weights_c_startend
      integer, intent(in) :: istart, iend
      integer, intent(in) :: iitotseg
      real(kind=8), intent(in) :: ttseg
      integer, intent(in) :: jprocs
      integer, intent(out) :: nvalp_c
      
      ! Local variables
      integer ::  jproc, i1, i2, i3, ii, j0, j1, n1p1, np, i, iseg, i0, iitot
      real(kind=8) :: tt2, tt, ttt
    
      ! Iterate through all grid points and assign them to processes such that the
      ! load balancing is optimal.
      jproc=jprocs
      tt=ttseg
      tt2=0.d0
      ttt=0.d0
      iitot=iitotseg
      n1p1=lzd%glr%d%n1+1
      np=n1p1*(lzd%glr%d%n2+1)
      loop_nseg_c: do iseg=istart,iend
         j0=lzd%glr%wfd%keygloc(1,iseg)
         j1=lzd%glr%wfd%keygloc(2,iseg)
         ii=j0-1
         i3=ii/np
         ii=ii-i3*np
         i2=ii/n1p1
         i0=ii-i2*n1p1
         i1=i0+j1-j0
         do i=i0,i1
            tt=tt+weight_c(i,i2,i3)
            tt2=tt2+weight_c(i,i2,i3)
            ttt=ttt+sqrt(weight_c(i,i2,i3))
            iitot=iitot+1
            if (jproc==nproc) then
               if (tt>weights_c_startend(2,jproc-1)+1) exit loop_nseg_c
            else if (tt>weights_c_startend(1,jproc)) then
               if (jproc>jprocs) then
                  if (iproc==jproc) then
                     istartp_seg_c=iseg
                  else if (iproc==jproc-1) then
                     iendp_seg_c=iseg
                     weightp_c=tt2
                     nvalp_c=nint(ttt)
                  end if
                  tt2=0.d0
                  ttt=0.d0
                  istartend_c(1,jproc)=iitot+1
               else if (jproc==jprocs) then
                  if (jproc==0) then
                     istartend_c(1,jproc)=1
                     if (iproc==jproc) istartp_seg_c=istart
                  else
                     tt2=0.d0
                     ttt=0.d0
                     istartend_c(1,jproc)=iitot+1
                     if (iproc==jproc) istartp_seg_c=iseg
                  end if
               end if
               jproc=jproc+1
            end if
         end do
      end do loop_nseg_c
    
      do jproc=jprocs,nproc-2
         istartend_c(2,jproc)=istartend_c(1,jproc+1)-1
      end do
      istartend_c(2,nproc-1)=iitot    

      if(iproc==nproc-1) then
         weightp_c=tt2
         iendp_seg_c=min(iseg,iend)
         nvalp_c=nint(ttt)
      end if

    end subroutine assign_weight_to_process_sub

    subroutine assign_weight_to_process_find_end_point(iproc, nproc, lzd, weight_c, &
               weights_c_startend, istart, iend, ttseg, iitot, iseg)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc !technically nproc isn't full nproc...
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,0:lzd%glr%d%n3),intent(in) :: weight_c
      real(kind=8),dimension(1:2,0:nproc),intent(in) :: weights_c_startend
      integer, intent(in) :: istart, iend
      integer, intent(out) :: iitot, iseg
      real(kind=8), intent(out) :: ttseg
      
      ! Local variables
      integer ::  i1, i2, i3, ii, j0, j1, n1p1, np, i, i0
      real(kind=8) :: tt

      tt=0.d0
      iitot=0
      n1p1=lzd%glr%d%n1+1
      np=n1p1*(lzd%glr%d%n2+1)
      loop_nseg_c: do iseg=istart,iend
         j0=lzd%glr%wfd%keygloc(1,iseg)
         j1=lzd%glr%wfd%keygloc(2,iseg)
         ii=j0-1
         i3=ii/np
         ii=ii-i3*np
         i2=ii/n1p1
         i0=ii-i2*n1p1
         i1=i0+j1-j0
         tt=tt+sum(weight_c(i0:i1,i2,i3))
         if (tt>weights_c_startend(1,nproc)) exit
         ttseg=tt
         iitot=iitot+i1-i0+1
      end do loop_nseg_c

    end subroutine assign_weight_to_process_find_end_point

    subroutine get_index_in_global2(lr, ii3min, ii3max, index_in_global_c, index_in_global_f)
    use module_base
    use module_types
    implicit none
    
    ! Calling arguments
    type(locreg_descriptors),intent(in) :: lr
    integer,intent(in) :: ii3min, ii3max
    integer,dimension(0:lr%d%n1,0:lr%d%n2,ii3min:ii3max),intent(out) :: index_in_global_c, index_in_global_f
    
    ! Local variables
    integer :: iitot, iseg, j0, j1, ii, i1, i2, i3, i0, i, istart, iend, np, n1p1
    
    call f_routine(id='get_index_in_global2')

    ! Could optimize these loops by cycling and updating iitot as soon as
    ! (i3<ii3min .or. i3>ii3max)
    
    iitot=0
    n1p1=lr%d%n1+1
    np=n1p1*(lr%d%n2+1)
    do iseg=1,lr%wfd%nseg_c
       j0=lr%wfd%keygloc(1,iseg)
       j1=lr%wfd%keygloc(2,iseg)
       ii=j0-1
       i3=ii/np
       ii=ii-i3*np
       i2=ii/n1p1
       i0=ii-i2*n1p1
       i1=i0+j1-j0
       do i=i0,i1
          iitot=iitot+1
          if (i3>=ii3min .and. i3<=ii3max) then
              index_in_global_c(i,i2,i3)=iitot
          end if
       end do
    end do 
    
    
    iitot=0
    istart=lr%wfd%nseg_c+min(1,lr%wfd%nseg_f)
    iend=istart+lr%wfd%nseg_f-1
    do iseg=istart,iend
       j0=lr%wfd%keygloc(1,iseg)
       j1=lr%wfd%keygloc(2,iseg)
       ii=j0-1
       i3=ii/np
       ii=ii-i3*np
       i2=ii/n1p1
       i0=ii-i2*n1p1
       i1=i0+j1-j0
       do i=i0,i1
          iitot=iitot+1
          if (i3>=ii3min .and. i3<=ii3max) then
              index_in_global_f(i,i2,i3)=iitot
          end if
       end do
    end do

    call f_release_routine()
    
    end subroutine get_index_in_global2


    subroutine determine_communication_arrays(iproc, nproc, npsidim_orbs, orbs, nspin, lzd, &
               istartend_c, istartend_f, ii3min, ii3max, index_in_global_c, index_in_global_f, &
               nvalp_c, nvalp_f,  nsendcounts_c, nsenddspls_c, nrecvcounts_c, nrecvdspls_c, &
               nsendcounts_f, nsenddspls_f, nrecvcounts_f, nrecvdspls_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, npsidim_orbs, nspin, ii3min, ii3max
      type(orbitals_data),intent(in) :: orbs
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(2,0:nproc-1),intent(in) :: istartend_c, istartend_f
      integer,dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,ii3min:ii3max),intent(in) :: index_in_global_c, index_in_global_f
      integer,intent(in) :: nvalp_c, nvalp_f
      integer,dimension(0:nproc-1),intent(out) :: nsendcounts_c, nsenddspls_c, nrecvcounts_c, nrecvdspls_c
      integer,dimension(0:nproc-1),intent(out) :: nsendcounts_f, nsenddspls_f, nrecvcounts_f, nrecvdspls_f
      
      ! Local variables
      integer :: iorb, iiorb, i1, i2, i3, ii, jproc, jproctarget, ierr, ilr, j0, j1, i0, i, ind, n1p1, np
      integer :: ii1, ii2, ii3, iseg, istart, iend
      integer,dimension(:),allocatable :: nsendcounts_tmp, nsenddspls_tmp, nrecvcounts_tmp, nrecvdspls_tmp
      character(len=*),     parameter :: subname='determine_communication_arrays'

      call f_routine(id='determine_communication_arrays')
    
      ! Determine values for mpi_alltoallv
      ! first nsendcounts
      nsendcounts_c=0
      nsendcounts_f=0
    
      !$omp parallel default(private) shared(ilr,nproc,orbs,lzd,index_in_global_c,istartend_c,nsendcounts_c,nsendcounts_f) &
      !$omp shared(istartend_f,index_in_global_f,n1p1,np)
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          if (lzd%llr(ilr)%wfd%nseg_c>0) then
              n1p1=lzd%llr(ilr)%d%n1+1
              np=n1p1*(lzd%llr(ilr)%d%n2+1)
              !$omp do firstprivate(ilr) reduction(+:nsendcounts_c)
              do iseg=1,lzd%llr(ilr)%wfd%nseg_c
                  j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
                  j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  ii2=i2+lzd%llr(ilr)%ns2
                  ii3=i3+lzd%llr(ilr)%ns3
                  do i=i0,i1
                      ii1=i+lzd%llr(ilr)%ns1
                      ind=index_in_global_c(ii1,ii2,ii3)
                      jproctarget=-1
                      do jproc=0,nproc-1
                          if(ind>=istartend_c(1,jproc) .and. ind<=istartend_c(2,jproc)) then
                              jproctarget=jproc
                              exit
                          end if
                      end do
                      if (jproctarget /= -1) &
                           nsendcounts_c(jproctarget)=nsendcounts_c(jproctarget)+1
                  end do
              end do
              !$omp end do
          end if
      end do
    
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          istart=lzd%llr(ilr)%wfd%nseg_c+min(1,lzd%llr(ilr)%wfd%nseg_f)
          iend=istart+lzd%llr(ilr)%wfd%nseg_f-1
          if (istart<iend) then
              n1p1=lzd%llr(ilr)%d%n1+1
              np=n1p1*(lzd%llr(ilr)%d%n2+1)
              !$omp do firstprivate(ilr) reduction(+:nsendcounts_f)
              do iseg=istart,iend
                  j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
                  j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
                  ii=j0-1
                  i3=ii/np
                  ii=ii-i3*np
                  i2=ii/n1p1
                  i0=ii-i2*n1p1
                  i1=i0+j1-j0
                  ii2=i2+lzd%llr(ilr)%ns2
                  ii3=i3+lzd%llr(ilr)%ns3
                  do i=i0,i1
                      ii1=i+lzd%llr(ilr)%ns1
                      !call get_index_in_global(lzd%glr, ii1, ii2, ii3, 'f', ind)
                      ind=index_in_global_f(ii1,ii2,ii3)
                      jproctarget=-1
                      do jproc=0,nproc-1
                          if(ind>=istartend_f(1,jproc) .and. ind<=istartend_f(2,jproc)) then
                              jproctarget=jproc
                              exit
                          end if
                      end do
                      if (jproctarget /= -1) &
                           nsendcounts_f(jproctarget)=nsendcounts_f(jproctarget)+1
                  end do
              end do
              !$omp end do
          end if
       end do
       !$omp end parallel
    
    
      ! The first check is to make sure that there is no stop in case this process has no orbitals (in which case
      ! npsidim_orbs is 1 and not 0 as assumed by the check)
      if(npsidim_orbs>1 .and. sum(nsendcounts_c)+7*sum(nsendcounts_f)/=npsidim_orbs) then
          write(*,'(a,2i10)') 'sum(nsendcounts_c)+sum(nsendcounts_f)/=npsidim_orbs', &
                              sum(nsendcounts_c)+sum(nsendcounts_f), npsidim_orbs
          stop
      end if
      
      ! now nsenddspls
      nsenddspls_c(0)=0
      do jproc=1,nproc-1
          nsenddspls_c(jproc)=nsenddspls_c(jproc-1)+nsendcounts_c(jproc-1)
      end do
      nsenddspls_f(0)=0
      do jproc=1,nproc-1
          nsenddspls_f(jproc)=nsenddspls_f(jproc-1)+nsendcounts_f(jproc-1)
      end do
   
      ! now nrecvcounts
      ! use an mpi_alltoallv to gather the data
      nsendcounts_tmp = f_malloc(0.to.nproc-1,id='nsendcounts_tmp')
      nsenddspls_tmp = f_malloc(0.to.nproc-1,id='nsenddspls_tmp')
      nrecvcounts_tmp = f_malloc(0.to.nproc-1,id='nrecvcounts_tmp')
      nrecvdspls_tmp = f_malloc(0.to.nproc-1,id='nrecvdspls_tmp')
      nsendcounts_tmp=1
      nrecvcounts_tmp=1
      do jproc=0,nproc-1
          nsenddspls_tmp(jproc)=jproc
          nrecvdspls_tmp(jproc)=jproc
      end do
      if(nproc>1) then
          call mpi_alltoallv(nsendcounts_c, nsendcounts_tmp, nsenddspls_tmp, mpi_integer, nrecvcounts_c, &
               nrecvcounts_tmp, nrecvdspls_tmp, mpi_integer, bigdft_mpi%mpi_comm, ierr)
          call mpi_alltoallv(nsendcounts_f, nsendcounts_tmp, nsenddspls_tmp, mpi_integer, nrecvcounts_f, &
               nrecvcounts_tmp, nrecvdspls_tmp, mpi_integer, bigdft_mpi%mpi_comm, ierr)
      else
          nrecvcounts_c=nsendcounts_c
          nrecvcounts_f=nsendcounts_f
      end if
      call f_free(nsendcounts_tmp)
      call f_free(nsenddspls_tmp)
      call f_free(nrecvcounts_tmp)
      call f_free(nrecvdspls_tmp)
    
      ! now recvdspls
      nrecvdspls_c(0)=0
      do jproc=1,nproc-1
          nrecvdspls_c(jproc)=nrecvdspls_c(jproc-1)+nrecvcounts_c(jproc-1)
      end do
      nrecvdspls_f(0)=0
      do jproc=1,nproc-1
          nrecvdspls_f(jproc)=nrecvdspls_f(jproc-1)+nrecvcounts_f(jproc-1)
      end do
    
      if(sum(nrecvcounts_c)/=nspin*nvalp_c) then
          stop 'sum(nrecvcounts_c)/=nspin*nvalp_c'
      end if
      if(sum(nrecvcounts_f)/=nspin*nvalp_f) then
          write(*,*) 'sum(nrecvcounts_f), nspin*nvalp_f', sum(nrecvcounts_f), nspin*nvalp_f
          stop 'sum(nrecvcounts_f)/=nspin*nvalp_f'
      end if

      call f_release_routine()
    
    end subroutine determine_communication_arrays


    subroutine determine_num_orbs_per_gridpoint_new(iproc, nproc, lzd, i3s, n3p, weightppp_c, weightppp_f, &
               istartend_c, istartend_f, &
               istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
               weightp_c, weightp_f, nptsp_c, nptsp_f, &
               norb_per_gridpoint_c, norb_per_gridpoint_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in):: iproc, nproc, i3s, n3p, nptsp_c, nptsp_f, istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f
      type(local_zone_descriptors),intent(in):: lzd
      integer,dimension(2,0:nproc-1),intent(in):: istartend_c, istartend_f
      real(kind=8),intent(in):: weightp_c, weightp_f
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,1:max(1,n3p)),intent(in),target :: weightppp_c, weightppp_f
      integer,dimension(nptsp_c),intent(out):: norb_per_gridpoint_c
      integer,dimension(nptsp_f),intent(out):: norb_per_gridpoint_f
      
      ! Local variables
      integer :: ii, i1, i2, i3, iipt, iseg, jj, j0, j1, iitot, i, istart, iend, i0
      integer :: icheck_c,icheck_f,iiorb_c,iiorb_f, npgp_c,npgp_f,np,n1p1
      integer :: window, i3min_c, i3max_c, i3min_f, i3max_f, size_of_double, ierr, jproc, is, ie, info, ncount
      integer,dimension(:),allocatable :: i3s_par, n3_par
      real(kind=8),dimension(:,:,:),pointer :: workrecv_c, workrecv_f
      !!integer,dimension(:),allocatable:: iseg_start_c, iseg_start_f
    
      call f_routine(id='determine_num_orbs_per_gridpoint_new')
    
      icheck_c = 0
      icheck_f = 0
      iiorb_f=0
      iiorb_c=0
      iipt=0
    
      n1p1=lzd%glr%d%n1+1
      np=n1p1*(lzd%glr%d%n2+1)


      !@NEW ######################################
       

       ! Initialize the MPI window
       if (nproc>1) then
           ! These arrays start at one instead of 0
           i3min_c = (lzd%glr%wfd%keygloc(1,istartp_seg_c)-1)/np + 1
           i3max_c = (lzd%glr%wfd%keygloc(2,iendp_seg_c)-1)/np + 1

           workrecv_c = f_malloc_ptr((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,i3min_c.to.i3max_c/),id='workrecv')

           i3s_par = f_malloc0(0.to.nproc-1,id='i3s_par')
           i3s_par(iproc)=i3s
           call mpiallred(i3s_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
           n3_par = f_malloc0(0.to.nproc-1,id='n3_par')
           n3_par(iproc)=n3p
           call mpiallred(n3_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)

           call mpi_type_size(mpi_double_precision, size_of_double, ierr)
           call mpi_info_create(info, ierr)
           call mpi_info_set(info, "no_locks", "true", ierr)
           call mpi_win_create(weightppp_c(0,0,1), &
                int((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p*size_of_double,kind=mpi_address_kind), size_of_double, &
                info, bigdft_mpi%mpi_comm, window, ierr)
           call mpi_info_free(info, ierr)
           call mpi_win_fence(mpi_mode_noprecede, window, ierr)

           do jproc=0,nproc-1
               ! Check whether ther is an overlap
               is = max(i3min_c,i3s_par(jproc))
               ie = min(i3max_c,i3s_par(jproc)+n3_par(jproc)-1)
               if (ie-is>=0) then
                   ncount = (ie-is+1)*(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)
                   !write(*,'(9(a,i0),a)') 'process ',iproc,'(i3min=',i3min_c,',i3max=',i3max_c,') gets ',(ie-is+1), &
                   !                    ' lines at ',is,' from ',is-i3s_par(jproc)+1,' on process ', &
                   !                    jproc,'(i3s=',i3s_par(jproc),',n3p=',n3_par(jproc),')'
                   !if (iproc/=jproc) then
                       call mpi_get(workrecv_c(0,0,is), ncount, mpi_double_precision, jproc, &
                            int((is-i3s_par(jproc))*(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1),kind=mpi_address_kind), &
                            ncount, mpi_double_precision, window, ierr)
                   !else
                   !    ncount = (lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1)
                   !    call vcopy(ncount, weightppp_c(0,0,is-i3s_par(jproc)+1), 1, workrecv_c(0,0,is), 1)
                   !end if
               end if
           end do
           ! Synchronize the communication
           call mpi_win_fence(0, window, ierr)
           call mpi_win_free(window, ierr)

       else
           workrecv_c => weightppp_c
       end if


       icheck_c = 0
       iiorb_c = 0
       do iseg=istartp_seg_c,iendp_seg_c
           jj=lzd%glr%wfd%keyvloc(iseg)
           j0=lzd%glr%wfd%keygloc(1,iseg)
           j1=lzd%glr%wfd%keygloc(2,iseg)
           ii=j0-1
           i3=ii/np
           ii=ii-i3*np
           i2=ii/n1p1
           i0=ii-i2*n1p1
           i1=i0+j1-j0
           do i=i0,i1
               iitot=jj+i-i0
               if(iitot>=istartend_c(1,iproc) .and. iitot<=istartend_c(2,iproc)) then
                   !write(1100+iproc,'(a,4i8,f10.1)') 'iproc, i, i2, i3, workrecv_c_c(i,i2,i3+1)', iproc, i, i2, i3, workrecv_c(i,i2,i3+1)
                   icheck_c = icheck_c + 1
                   iipt=jj-istartend_c(1,iproc)+i-i0+1
                   npgp_c = nint(sqrt(workrecv_c(i,i2,i3+1)))
                   iiorb_c=iiorb_c+nint(workrecv_c(i,i2,i3+1))
                   norb_per_gridpoint_c(iipt)=npgp_c
               end if
           end do
       end do

       if (nproc>1) then
           call f_free_ptr(workrecv_c)
           call f_free(i3s_par)
           call f_free(n3_par)
       end if


      !@ENDNEW ######################################
    
      if(icheck_c/=nptsp_c) stop 'icheck_c/=nptsp_c'
      if(iiorb_c/=nint(weightp_c)) then
          write(*,*) 'iiorb_c, nint(weightp_c)', iiorb_c, nint(weightp_c)
          stop 'iiorb_c/=weightp_c'
      end if
    
    

      !@NEW ######################################
       

       if (nproc>1) then
           ! These arrays start at one instead of 0
           i3min_f = (lzd%glr%wfd%keygloc(1,istartp_seg_f)-1)/np + 1
           i3max_f = (lzd%glr%wfd%keygloc(2,iendp_seg_f)-1)/np + 1

           workrecv_f = f_malloc_ptr((/0.to.lzd%glr%d%n1,0.to.lzd%glr%d%n2,i3min_f.to.i3max_f/),id='workrecv')

           i3s_par = f_malloc0(0.to.nproc-1,id='i3s_par')
           i3s_par(iproc)=i3s
           call mpiallred(i3s_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
           n3_par = f_malloc0(0.to.nproc-1,id='n3_par')
           n3_par(iproc)=n3p
           call mpiallred(n3_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)

           ! Initialize the MPI window
           call mpi_type_size(mpi_double_precision, size_of_double, ierr)
           call mpi_info_create(info, ierr)
           call mpi_info_set(info, "no_locks", "true", ierr)
           call mpi_win_create(weightppp_f(0,0,1), &
                int((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*n3p*size_of_double,kind=mpi_address_kind), size_of_double, &
                info, bigdft_mpi%mpi_comm, window, ierr)
           call mpi_info_free(info, ierr)
           call mpi_win_fence(mpi_mode_noprecede, window, ierr)

           do jproc=0,nproc-1
               ! Check whether ther is an overlap
               is = max(i3min_f,i3s_par(jproc))
               ie = min(i3max_f,i3s_par(jproc)+n3_par(jproc)-1)
               if (ie-is>=0) then
                   ncount = (ie-is+1)*(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)
                   !!write(*,'(9(a,i0),a)') 'process ',iproc,'(i3min=',i3min_f,',i3max=',i3max_f,') gets ',(ie-is+1), &
                   !!                    ' lines at ',is,' from ',is-i3s_par(jproc)+1,' on process ', &
                   !!                    jproc,'(i3s=',i3s_par(jproc),',n3p=',n3_par(jproc),')'
                   call mpi_get(workrecv_f(0,0,is), ncount, mpi_double_precision, jproc, &
                        int((is-i3s_par(jproc))*(lzd%glr%d%n1+1)*(lzd%glr%d%n2+1),kind=mpi_address_kind), &
                        ncount, mpi_double_precision, window, ierr)
               end if
           end do
           ! Synchronize the communication
           call mpi_win_fence(0, window, ierr)
           call mpi_win_free(window, ierr)
       else
           workrecv_f => weightppp_f
       end if


       icheck_f = 0
       iiorb_f = 0
       do iseg=istartp_seg_f,iendp_seg_f
           jj=lzd%glr%wfd%keyvloc(iseg)
           j0=lzd%glr%wfd%keygloc(1,iseg)
           j1=lzd%glr%wfd%keygloc(2,iseg)
           ii=j0-1
           i3=ii/np
           ii=ii-i3*np
           i2=ii/n1p1
           i0=ii-i2*n1p1
           i1=i0+j1-j0
           do i=i0,i1
               iitot=jj+i-i0
               if(iitot>=istartend_f(1,iproc) .and. iitot<=istartend_f(2,iproc)) then
                   !!write(1100+iproc,'(a,4i8,f10.1)') 'iproc, i, i2, i3, workrecv_f(i,i2,i3+1)', iproc, i, i2, i3, workrecv_f(i,i2,i3+1)
                   icheck_f = icheck_f + 1
                   iipt=jj-istartend_f(1,iproc)+i-i0+1
                   npgp_f = nint(sqrt(workrecv_f(i,i2,i3+1)))
                   iiorb_f=iiorb_f+nint(workrecv_f(i,i2,i3+1))
                   norb_per_gridpoint_f(iipt)=npgp_f
               end if
           end do
       end do

       if (nproc>1) then
           call f_free_ptr(workrecv_f)
           call f_free(i3s_par)
           call f_free(n3_par)
       end if


      !@ENDNEW ######################################
    
      if(icheck_f/=nptsp_f) stop 'icheck_f/=nptsp_f'
      if(iiorb_f/=nint(weightp_f)) then
          write(*,*) 'iiorb_f, weightp_f', iiorb_f, weightp_f
          stop 'iiorb_f/=weightp_f'
      end if

      call f_release_routine()
    
    end subroutine determine_num_orbs_per_gridpoint_new



    subroutine get_switch_indices(iproc, nproc, orbs, lzd, nspin, &
               nptsp_c, nptsp_f, norb_per_gridpoint_c, norb_per_gridpoint_f, &
               ndimpsi_c, ndimpsi_f, istartend_c, istartend_f, &
               istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, &
               nsendcounts_c, nsenddspls_c, ndimind_c, nrecvcounts_c, nrecvdspls_c, &
               nsendcounts_f, nsenddspls_f, ndimind_f, nrecvcounts_f, nrecvdspls_f, &
               ii3min, ii3max, index_in_global_c, index_in_global_f, &
               weightp_c, weightp_f,  isendbuf_c, irecvbuf_c, isendbuf_f, irecvbuf_f, &
               indexrecvorbital_c, iextract_c, iexpand_c, indexrecvorbital_f, iextract_f, iexpand_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nspin, nptsp_c, nptsp_f, ndimpsi_c, ndimpsi_f, ndimind_c,ndimind_f
      integer,intent(in) :: istartp_seg_c, iendp_seg_c, istartp_seg_f, iendp_seg_f, ii3min, ii3max
      type(orbitals_data),intent(in) :: orbs
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(nptsp_c),intent(in):: norb_per_gridpoint_c
      integer,dimension(nptsp_f),intent(in):: norb_per_gridpoint_f
      integer,dimension(2,0:nproc-1),intent(in) :: istartend_c, istartend_f
      integer,dimension(0:nproc-1),intent(in) :: nsendcounts_c, nsenddspls_c, nrecvcounts_c, nrecvdspls_c
      integer,dimension(0:nproc-1),intent(in) :: nsendcounts_f, nsenddspls_f, nrecvcounts_f, nrecvdspls_f
      integer,dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,ii3min:ii3max),intent(in) :: index_in_global_c, index_in_global_f
      real(kind=8),intent(in) :: weightp_c, weightp_f
      integer,dimension(ndimpsi_c),intent(out) :: isendbuf_c, irecvbuf_c
      integer,dimension(ndimpsi_f),intent(out) :: isendbuf_f, irecvbuf_f
      integer,dimension(ndimind_c),intent(out) :: indexrecvorbital_c, iextract_c, iexpand_c
      integer,dimension(ndimind_f),intent(out) :: indexrecvorbital_f, iextract_f, iexpand_f
      
      ! Local variables
      integer :: i, iorb, iiorb, i1, i2, i3, ind, jproc, jproctarget, ii, ierr, iseg, iitot, ilr, n1p1, np
      integer :: i3min_c, i3max_c, i3min_f, i3max_f
      integer :: istart, iend, indglob, ii1, ii2, ii3, j1, i0, j0, ipt
      integer,dimension(:),allocatable :: nsend_c,nsend_f, indexsendorbital2, indexrecvorbital2
      integer,dimension(:),allocatable :: gridpoint_start_c, gridpoint_start_f, gridpoint_start_tmp_c, gridpoint_start_tmp_f
      real(kind=8),dimension(:,:,:),allocatable :: weight_c, weight_f
      integer,dimension(:),allocatable :: indexsendorbital_c, indexsendbuf_c, indexrecvbuf_c
      integer,dimension(:),allocatable :: indexsendorbital_f, indexsendbuf_f, indexrecvbuf_f
      character(len=*),parameter :: subname='get_switch_indices'
    
    
      call f_routine(id='get_switch_indices')
      
      indexsendorbital_c = f_malloc(ndimpsi_c,id='indexsendorbital_c')
      indexsendbuf_c = f_malloc(ndimpsi_c,id='indexsendbuf_c')
      indexrecvbuf_c = f_malloc(sum(nrecvcounts_c),id='indexrecvbuf_c')
      indexsendorbital_f = f_malloc(ndimpsi_f,id='indexsendorbital_f')
      indexsendbuf_f = f_malloc(ndimpsi_f,id='indexsendbuf_f')
      indexrecvbuf_f = f_malloc(sum(nrecvcounts_f),id='indexrecvbuf_f')
      gridpoint_start_c = f_malloc(istartend_c(1,iproc).to.istartend_c(2,iproc),id='gridpoint_start_c')
      gridpoint_start_f = f_malloc(istartend_f(1,iproc).to.istartend_f(2,iproc),id='gridpoint_start_f')
      if (nspin==2) then
          !!gridpoint_start_tmp_c = f_malloc((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1),id='gridpoint_start_tmp_c')
          !!gridpoint_start_tmp_f = f_malloc((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1),id='gridpoint_start_tmp_f')
          gridpoint_start_tmp_c = f_malloc(istartend_c(1,iproc).to.istartend_c(2,iproc),id='gridpoint_start_tmp_c')
          gridpoint_start_tmp_f = f_malloc(istartend_f(1,iproc).to.istartend_f(2,iproc),id='gridpoint_start_tmp_f')
      end if
      gridpoint_start_c=-1
      gridpoint_start_f=-1


      !!write(*,'(a,i7,4i9)') 'iproc, i3min_c, i3max_c, i3min_f, i3max_f', iproc, i3min_c, i3max_c, i3min_f, i3max_f
    
      !write(*,*) 'ndimpsi_f, sum(nrecvcounts_f)', ndimpsi_f, sum(nrecvcounts_f)
    
      nsend_c = f_malloc(0.to.nproc-1,id='nsend_c')
      nsend_f = f_malloc(0.to.nproc-1,id='nsend_f')
    
      nsend_c=0
      nsend_f=0
    
      !$omp parallel default(private) shared(orbs,lzd,index_in_global_c,index_in_global_f,istartend_c,istartend_f)&
      !$omp shared(nsend_c,nsend_f,nsenddspls_c,nsenddspls_f,ndimpsi_c,ndimpsi_f,nsendcounts_c,nsendcounts_f,nproc) &
      !$omp shared(isendbuf_c,isendbuf_f,indexsendbuf_c,indexsendbuf_f,indexsendorbital_c,indexsendorbital_f)
    
      !$omp sections
      !$omp section
      iitot=0
     
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          n1p1=lzd%llr(ilr)%d%n1+1
          np=n1p1*(lzd%llr(ilr)%d%n2+1)
          do iseg=1,lzd%llr(ilr)%wfd%nseg_c
              !jj=lzd%llr(ilr)%wfd%keyvloc(iseg)
              j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
              j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
              ii=j0-1
              i3=ii/np
              ii=ii-i3*np
              i2=ii/n1p1
              i0=ii-i2*n1p1
              i1=i0+j1-j0
              !write(*,'(a,8i8)') 'jj, ii, j0, j1, i0, i1, i2, i3',jj,ii,j0,j1,i0,i1,i2,i3
              ii2=i2+lzd%llr(ilr)%ns2
              ii3=i3+lzd%llr(ilr)%ns3
              do i=i0,i1
                  ii1=i+lzd%llr(ilr)%ns1
                  !call get_index_in_global(lzd%glr, ii1, ii2, ii3, 'c', indglob)
                  indglob=index_in_global_c(ii1,ii2,ii3)
                  iitot=iitot+1
               jproctarget=-1
               do jproc=0,nproc-1
                  if(indglob>=istartend_c(1,jproc) .and. indglob<=istartend_c(2,jproc)) then
                     jproctarget=jproc
                     exit
                  end if
               end do
               !write(600+iproc,'(a,2(i0,1x),i0,a,i0)') 'point ',ii1,ii2,ii3,' goes to process ',jproctarget
              
               if (jproctarget/=-1) then
                  nsend_c(jproctarget)=nsend_c(jproctarget)+1
                  ind=nsenddspls_c(jproctarget)+nsend_c(jproctarget)
                  isendbuf_c(iitot)=ind
                  indexsendbuf_c(ind)=indglob
                  indexsendorbital_c(iitot)=iiorb
               end if
               !indexsendorbital(ind)=iiorb
            end do
         end do
      end do
      !write(*,*) 'iitot,ndimpsi_c',iitot,ndimpsi_c
      if(iitot/=ndimpsi_c) stop 'iitot/=ndimpsi_c'
    
      !check
      do jproc=0,nproc-1
          if(nsend_c(jproc)/=nsendcounts_c(jproc)) stop 'nsend_c(jproc)/=nsendcounts_c(jproc)'
      end do
    
    
      !$omp section
      ! fine part
      iitot=0
      do iorb=1,orbs%norbp
         iiorb=orbs%isorb+iorb
         ilr=orbs%inwhichlocreg(iiorb)
         istart=lzd%llr(ilr)%wfd%nseg_c+min(1,lzd%llr(ilr)%wfd%nseg_f)
         iend=istart+lzd%llr(ilr)%wfd%nseg_f-1
         n1p1=lzd%llr(ilr)%d%n1+1
         np=n1p1*(lzd%llr(ilr)%d%n2+1)
         do iseg=istart,iend
            !jj=lzd%llr(ilr)%wfd%keyvloc(iseg)
            j0=lzd%llr(ilr)%wfd%keygloc(1,iseg)
            j1=lzd%llr(ilr)%wfd%keygloc(2,iseg)
            ii=j0-1
            i3=ii/np
            ii=ii-i3*np
            i2=ii/n1p1
            i0=ii-i2*n1p1
            i1=i0+j1-j0
            !write(*,'(a,8i8)') 'jj, ii, j0, j1, i0, i1, i2, i3',jj,ii,j0,j1,i0,i1,i2,i3
            ii2=i2+lzd%llr(ilr)%ns2
            ii3=i3+lzd%llr(ilr)%ns3
            do i=i0,i1
               ii1=i+lzd%llr(ilr)%ns1
               !call get_index_in_global(lzd%glr, ii1, ii2, ii3, 'f', indglob)
               indglob=index_in_global_f(ii1,ii2,ii3)
               iitot=iitot+1
               jproctarget=-1
               do jproc=0,nproc-1
                  if(indglob>=istartend_f(1,jproc) .and. indglob<=istartend_f(2,jproc)) then
                     jproctarget=jproc
                     exit
                  end if
               end do
               if (jproctarget/=-1) then
                  nsend_f(jproctarget)=nsend_f(jproctarget)+1
                  ind=nsenddspls_f(jproctarget)+nsend_f(jproctarget)
                  isendbuf_f(iitot)=ind
                  indexsendbuf_f(ind)=indglob
                  indexsendorbital_f(iitot)=iiorb
               end if
               !indexsendorbital(ind)=iiorb
            end do
         end do
     
      end do
      
      if(iitot/=ndimpsi_f) stop 'iitot/=ndimpsi_f'
    
      !$omp end sections
      !$omp end parallel
    
      !check
      do jproc=0,nproc-1
          !write(*,*) 'nsend(jproc), nsendcounts_f(jproc)', nsend(jproc), nsendcounts_f(jproc)
          if(nsend_f(jproc)/=nsendcounts_f(jproc)) stop 'nsend_f(jproc)/=nsendcounts_f(jproc)'
      end do
    
      indexsendorbital2 = f_malloc(ndimpsi_c,id='indexsendorbital2')
      indexsendorbital2=indexsendorbital_c
      do i=1,ndimpsi_c
          ind=isendbuf_c(i)
          indexsendorbital_c(ind)=indexsendorbital2(i)
      end do
    
      ! Inverse of isendbuf
      call get_reverse_indices(ndimpsi_c, isendbuf_c, irecvbuf_c)
    
      call f_free(indexsendorbital2)
      indexsendorbital2 = f_malloc(ndimpsi_f,id='indexsendorbital2')
      indexsendorbital2=indexsendorbital_f
      do i=1,ndimpsi_f
          ind=isendbuf_f(i)
          indexsendorbital_f(ind)=indexsendorbital2(i)
      end do
    
      ! Inverse of isendbuf
    
      call get_reverse_indices(ndimpsi_f, isendbuf_f, irecvbuf_f)
      call f_free(indexsendorbital2)
    
    
      if(nproc>1) then
          ! Communicate indexsendbuf
          call mpi_alltoallv(indexsendbuf_c, nsendcounts_c, nsenddspls_c, mpi_integer, indexrecvbuf_c, &
               nrecvcounts_c, nrecvdspls_c, mpi_integer, bigdft_mpi%mpi_comm, ierr)
          ! Communicate indexsendorbitals
          call mpi_alltoallv(indexsendorbital_c, nsendcounts_c, nsenddspls_c, mpi_integer, indexrecvorbital_c, &
               nrecvcounts_c, nrecvdspls_c, mpi_integer, bigdft_mpi%mpi_comm, ierr)
    
          ! Communicate indexsendbuf
          call mpi_alltoallv(indexsendbuf_f, nsendcounts_f, nsenddspls_f, mpi_integer, indexrecvbuf_f, &
               nrecvcounts_f, nrecvdspls_f, mpi_integer, bigdft_mpi%mpi_comm, ierr)
          ! Communicate indexsendorbitals
          call mpi_alltoallv(indexsendorbital_f, nsendcounts_f, nsenddspls_f, mpi_integer, indexrecvorbital_f, &
               nrecvcounts_f, nrecvdspls_f, mpi_integer, bigdft_mpi%mpi_comm, ierr)
       else
           indexrecvbuf_c=indexsendbuf_c
           indexrecvorbital_c=indexsendorbital_c
           indexrecvbuf_f=indexsendbuf_f
           indexrecvorbital_f=indexsendorbital_f
       end if
    
        

      ! gridpoint_start is the starting index of a given grid point in the overall array
      ii=1
      do ipt=1,nptsp_c
          i=ipt+istartend_c(1,iproc)-1
          if (norb_per_gridpoint_c(ipt)>0) then
              gridpoint_start_c(i)=ii
          else
              gridpoint_start_c(i)=0
          end if
          ii=ii+norb_per_gridpoint_c(ipt)
      end do

      ii=1
      do ipt=1,nptsp_f
          i=ipt+istartend_f(1,iproc)-1
          if (norb_per_gridpoint_f(ipt)>0) then
              gridpoint_start_f(i)=ii
          else
              gridpoint_start_f(i)=0
          end if
          ii=ii+norb_per_gridpoint_f(ipt)
      end do



      if (nspin==2) then
          gridpoint_start_tmp_c=gridpoint_start_c
          gridpoint_start_tmp_f=gridpoint_start_f
      end if
        
    
      if(maxval(gridpoint_start_c)>sum(nrecvcounts_c)) stop '1: maxval(gridpoint_start_c)>sum(nrecvcounts_c)'
      if(maxval(gridpoint_start_f)>sum(nrecvcounts_f)) stop '1: maxval(gridpoint_start_f)>sum(nrecvcounts_f)'

      ! Rearrange the communicated data
      if (nspin==1) then
          do i=1,sum(nrecvcounts_c)
              ii=indexrecvbuf_c(i)
              ind=gridpoint_start_c(ii)
              iextract_c(i)=ind
              gridpoint_start_c(ii)=gridpoint_start_c(ii)+1  
          end do
      else
          do i=1,sum(nrecvcounts_c)
              ii=indexrecvbuf_c(i)
              ind=gridpoint_start_c(ii)
              if (gridpoint_start_c(ii)-gridpoint_start_tmp_c(ii)+1>norb_per_gridpoint_c(ii-istartend_c(1,iproc)+1)) then
                  ! orbitals which fulfill this condition are down orbitals which should be put at the end
                  !ind = ind + ((ndimind_c+ndimind_f)/2-norb_per_gridpoint_c(ii-istartend_c(1,iproc)+1))
                  ind = ind + (ndimind_c/2-norb_per_gridpoint_c(ii-istartend_c(1,iproc)+1))
              end if
              iextract_c(i)=ind
              gridpoint_start_c(ii)=gridpoint_start_c(ii)+1  
          end do
      end if
      !write(*,'(a,2i12)') 'sum(iextract_c), nint(weightp_c*(weightp_c+1.d0)*.5d0)', sum(iextract_c), nint(weightp_c*(weightp_c+1.d0)*.5d0)
      !if(sum(iextract_c)/=nint(weightp_c*(weightp_c+1.d0)*.5d0)) stop 'sum(iextract_c)/=nint(weightp_c*(weightp_c+1.d0)*.5d0)'
      if(maxval(iextract_c)>sum(nrecvcounts_c)) then
          stop 'maxval(iextract_c)>sum(nrecvcounts_c)'
      end if
      if(minval(iextract_c)<1) stop 'minval(iextract_c)<1'
    
      ! Rearrange the communicated data
      if (nspin==1) then
          do i=1,sum(nrecvcounts_f)
              ii=indexrecvbuf_f(i)
              ind=gridpoint_start_f(ii)
              iextract_f(i)=ind
              gridpoint_start_f(ii)=gridpoint_start_f(ii)+1  
          end do
      else
          do i=1,sum(nrecvcounts_f)
              ii=indexrecvbuf_f(i)
              ind=gridpoint_start_f(ii)
              if (gridpoint_start_f(ii)-gridpoint_start_tmp_f(ii)+1>norb_per_gridpoint_f(ii-istartend_f(1,iproc)+1)) then
                  ! orbitals which fulfill this condition are down orbitals which should be put at the end
                  ind = ind + (ndimind_f/2-norb_per_gridpoint_f(ii-istartend_f(1,iproc)+1))
              end if
              iextract_f(i)=ind
              gridpoint_start_f(ii)=gridpoint_start_f(ii)+1  
          end do
      end if
      if(maxval(iextract_f)>sum(nrecvcounts_f)) stop 'maxval(iextract_f)>sum(nrecvcounts_f)'
      if(minval(iextract_f)<1) stop 'minval(iextract_f)<1'
        
    
      ! Get the array to transfrom back the data
      call get_reverse_indices(sum(nrecvcounts_c), iextract_c, iexpand_c)
      call get_reverse_indices(sum(nrecvcounts_f), iextract_f, iexpand_f)
          
    
      indexrecvorbital2 = f_malloc(sum(nrecvcounts_c),id='indexrecvorbital2')
      indexrecvorbital2=indexrecvorbital_c
      do i=1,sum(nrecvcounts_c)
          ind=iextract_c(i)
          indexrecvorbital_c(ind)=indexrecvorbital2(i)
      end do
      call f_free(indexrecvorbital2)
      indexrecvorbital2 = f_malloc(sum(nrecvcounts_f),id='indexrecvorbital2')
      indexrecvorbital2=indexrecvorbital_f
      do i=1,sum(nrecvcounts_f)
          ind=iextract_f(i)
          indexrecvorbital_f(ind)=indexrecvorbital2(i)
      end do
      call f_free(indexrecvorbital2)
    
    
      if(minval(indexrecvorbital_c)<1) stop 'minval(indexrecvorbital_c)<1'
      if(maxval(indexrecvorbital_c)>orbs%norb) stop 'maxval(indexrecvorbital_c)>orbs%norb'
      if(minval(indexrecvorbital_f)<1) stop 'minval(indexrecvorbital_f)<1'
      if(maxval(indexrecvorbital_f)>orbs%norb) stop 'maxval(indexrecvorbital_f)>orbs%norb'
    

      call f_free(indexsendorbital_c)
      call f_free(indexsendbuf_c)
      call f_free(indexrecvbuf_c)
      call f_free(indexsendorbital_f)
      call f_free(indexsendbuf_f)
      call f_free(indexrecvbuf_f)
      call f_free(gridpoint_start_c)
      call f_free(gridpoint_start_f)
      if (nspin==2) then
          call f_free(gridpoint_start_tmp_c)
          call f_free(gridpoint_start_tmp_f)
      end if
      call f_free(nsend_c)
      call f_free(nsend_f)


      call f_release_routine()
    
    end subroutine get_switch_indices



    subroutine get_reverse_indices(n, indices, reverse_indices)
      use module_base
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: n
      integer,dimension(n),intent(in) :: indices
      integer,dimension(n),intent(out) :: reverse_indices
    
      ! Local variables
      integer :: i, j, m, j0, j1, j2, j3
    
      !$omp parallel default(private) &
      !$omp shared(n, m, indices, reverse_indices)
    
      m=mod(n,4)
      if (m/=0) then
          do i=1,m
              j=indices(i)
              reverse_indices(j)=i
          end do
      end if
    
      !$omp do
      do i=m+1,n,4
          j0=indices(i+0)
          reverse_indices(j0)=i+0
          j1=indices(i+1)
          reverse_indices(j1)=i+1
          j2=indices(i+2)
          reverse_indices(j2)=i+2
          j3=indices(i+3)
          reverse_indices(j3)=i+3
      end do
      !$omp end do
    
      !$omp end parallel
    
      !!do i=1,n
      !!    j=indices(i)
      !!    reverse_indices(j)=i
      !!end do
    
    end subroutine get_reverse_indices



    subroutine get_gridpoint_start(iproc, nproc, lzd, ndimind_c, nrecvcounts_c, ndimind_f, nrecvcounts_f, &
               indexrecvbuf_c, indexrecvbuf_f, &
               i3min_c, i3max_c, weight_c, i3min_f, i3max_f, weight_f, gridpoint_start_c, gridpoint_start_f)
      use module_base
      use module_types
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc,ndimind_c,ndimind_f,i3min_c,i3max_c,i3min_f,i3max_f
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(0:nproc-1),intent(in) :: nrecvcounts_c, nrecvcounts_f
      integer,dimension(ndimind_c),intent(in) :: indexrecvbuf_c
      integer,dimension(ndimind_f),intent(in) :: indexrecvbuf_f
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,i3min_c:i3max_c),intent(out) :: weight_c
      real(kind=8),dimension(0:lzd%glr%d%n1,0:lzd%glr%d%n2,i3min_f:i3max_f),intent(out) :: weight_f
      integer,dimension((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(lzd%glr%d%n3+1)),intent(out) :: gridpoint_start_c, gridpoint_start_f
      
      ! Local variables
      integer :: i, ii, jj, i1, i2, i3, n1p1, np
    
    
      !weight_c=0.d0
      call to_zero((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(i3max_c-i3min_c+1), weight_c(0,0,i3min_c))
      call to_zero((lzd%glr%d%n1+1)*(lzd%glr%d%n2+1)*(i3max_f-i3min_f+1), weight_f(0,0,i3min_f))
    
      n1p1=lzd%glr%d%n1+1
      np=n1p1*(lzd%glr%d%n2+1)

      !!$omp parallel default(private) shared(lzd,nrecvcounts_c,indexrecvbuf_c,weight_c,gridpoint_start_c) &
      !!$omp shared(nrecvcounts_f,indexrecvbuf_f,weight_f,gridpoint_start_f,np,n1p1)
    
      !!$omp sections
      !!$omp section
      do i=1,sum(nrecvcounts_c)
          ii=indexrecvbuf_c(i)
          !write(650+iproc,*) i, ii
          jj=ii-1
          i3=jj/np
          jj=jj-i3*np
          i2=jj/n1p1
          i1=jj-i2*n1p1
          weight_c(i1,i2,i3)=weight_c(i1,i2,i3)+1.d0
      end do
    
      !write(*,*) 'in get_gridpoint_start: maxval(weight_c)', maxval(weight_c)
    
      ii=1
      i=0
      !gridpoint_start_c=0
      do i3=0,lzd%glr%d%n3
          do i2=0,lzd%glr%d%n2
              do i1=0,lzd%glr%d%n1
                  i=i+1
                  if(weight_c(i1,i2,i3)>0.d0) then
                      gridpoint_start_c(i)=ii
                      ii=ii+nint(weight_c(i1,i2,i3))
                  else
                      gridpoint_start_c(i) = 0
                  end if
              end do
          end do
      end do
    
      !!$omp section
     
      do i=1,sum(nrecvcounts_f)
          ii=indexrecvbuf_f(i)
          write(*,*) 'i, ii', i, ii
          jj=ii-1
          i3=jj/np
          jj=jj-i3*np
          i2=jj/n1p1
          i1=jj-i2*n1p1
          weight_f(i1,i2,i3)=weight_f(i1,i2,i3)+1.d0
      end do
    
    
      ii=1
      i=0
      !gridpoint_start_f=0
      do i3=0,lzd%glr%d%n3
          do i2=0,lzd%glr%d%n2
              do i1=0,lzd%glr%d%n1
                  i=i+1
                  if(weight_f(i1,i2,i3)>0.d0) then
                      gridpoint_start_f(i)=ii
                      ii=ii+nint(weight_f(i1,i2,i3))
                  else
                      gridpoint_start_f(i)=0
                  end if
              end do
          end do
      end do
    
      !!$omp end sections
      !!$omp end parallel
    
    end subroutine get_gridpoint_start


    !> The sumrho routines
    subroutine init_comms_linear_sumrho(iproc, nproc, lzd, orbs, nspin, nscatterarr, collcom_sr)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nspin
      type(local_zone_descriptors),intent(in) :: lzd
      type(orbitals_data),intent(in) :: orbs
      integer,dimension(0:nproc-1,4),intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      type(comms_linear),intent(inout) :: collcom_sr
    
      ! Local variables
      integer :: ipt, ii
      real(kind=8) :: weight_tot, weight_ideal
      integer,dimension(:,:),allocatable :: istartend
      character(len=*),parameter :: subname='init_comms_linear_sumrho'
      real(kind=8),dimension(:),allocatable :: weights_per_slice, weights_per_zpoint
    
      ! Note: all weights are double precision to avoid integer overflow
      call timing(iproc,'init_collco_sr','ON')
    
      istartend = f_malloc((/ 1.to.2, 0.to.nproc-1 /),id='istartend')
      weights_per_slice = f_malloc(0.to.nproc-1,id='weights_per_slice')
      weights_per_zpoint = f_malloc(lzd%glr%d%n3i,id='weights_per_zpoint')
      call get_weights_sumrho(iproc, nproc, orbs, lzd, nscatterarr, weight_tot, weight_ideal, &
           weights_per_slice, weights_per_zpoint)

    
      call assign_weight_to_process_sumrho(iproc, nproc, weight_tot, weight_ideal, weights_per_slice, &
           lzd, orbs, nscatterarr, istartend, collcom_sr%nptsp_c)

    
      call f_free(weights_per_slice)
    

      call allocate_MPI_communication_arrays(nproc, collcom_sr, only_coarse=.true.)

      call determine_communication_arrays_sumrho(iproc, nproc, collcom_sr%nptsp_c, lzd, orbs, istartend, &
           collcom_sr%nsendcounts_c, collcom_sr%nsenddspls_c, &
           collcom_sr%nrecvcounts_c, collcom_sr%nrecvdspls_c, collcom_sr%ndimpsi_c)

      !Now set some integers in the collcomm structure
      collcom_sr%ndimind_c = sum(collcom_sr%nrecvcounts_c)

      call allocate_local_comms_cubic(collcom_sr, only_coarse=.true.)
    
      call determine_num_orbs_per_gridpoint_sumrho(iproc, nproc, collcom_sr%nptsp_c, lzd, orbs, &
           istartend, weight_tot, weights_per_zpoint, collcom_sr%norb_per_gridpoint_c)
    
      ! Some check
      ii=sum(collcom_sr%norb_per_gridpoint_c)
      if (nspin*ii/=collcom_sr%ndimind_c) then
          write(*,*) 'nspin*ii/=collcom_sr%ndimind_c', ii, collcom_sr%ndimind_c
          stop 'nspin*ii/=collcom_sr%ndimind_c'
      end if
    
    
      collcom_sr%psit_c=f_malloc_ptr(collcom_sr%ndimind_c,id='collcom_sr%psit_c')
    
      call get_switch_indices_sumrho(iproc, nproc, collcom_sr%nptsp_c, collcom_sr%ndimpsi_c, collcom_sr%ndimind_c, lzd, &
           orbs, nspin, istartend, collcom_sr%norb_per_gridpoint_c, collcom_sr%nsendcounts_c, collcom_sr%nsenddspls_c, &
           collcom_sr%nrecvcounts_c, collcom_sr%nrecvdspls_c, collcom_sr%isendbuf_c, collcom_sr%irecvbuf_c, &
           collcom_sr%iextract_c, collcom_sr%iexpand_c, collcom_sr%indexrecvorbital_c)
    
      ! These variables are used in various subroutines to speed up the code
      collcom_sr%isptsp_c(1) = 0
      do ipt=2,collcom_sr%nptsp_c
            collcom_sr%isptsp_c(ipt) = collcom_sr%isptsp_c(ipt-1) + collcom_sr%norb_per_gridpoint_c(ipt-1)
      end do
    
      call allocate_MPI_comms_cubic_repartition(nproc, collcom_sr)
    
      call communication_arrays_repartitionrho(iproc, nproc, lzd, nscatterarr, istartend, &
           collcom_sr%nsendcounts_repartitionrho, collcom_sr%nsenddspls_repartitionrho, &
           collcom_sr%nrecvcounts_repartitionrho, collcom_sr%nrecvdspls_repartitionrho)
    
      call communication_arrays_repartitionrho_general(iproc, nproc, lzd, nscatterarr, istartend, & 
           collcom_sr%ncomms_repartitionrho, collcom_sr%commarr_repartitionrho)
    
      call f_free(weights_per_zpoint)
      call f_free(istartend)
    
      call timing(iproc,'init_collco_sr','OF')
    
    end subroutine init_comms_linear_sumrho



    subroutine get_weights_sumrho(iproc, nproc, orbs, lzd, nscatterarr, &
               weight_tot, weight_ideal, weights_per_slice, weights_per_zpoint)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(orbitals_data),intent(in) :: orbs
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(0:nproc-1,4),intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      real(kind=8),intent(out) :: weight_tot, weight_ideal
      real(kind=8),dimension(0:nproc-1),intent(out) :: weights_per_slice
      real(kind=8),dimension(lzd%glr%d%n3i),intent(out) :: weights_per_zpoint
    
      ! Local variables
      integer :: iorb, ilr, i3, i2, i1, is1, ie1, is2, ie2, is3, ie3
      real(kind=8) :: tt, zz
      real(kind=8),dimension(:,:),allocatable :: weight_xy
    
      call f_routine(id='get_weights_sumrho')
    
      call to_zero(lzd%glr%d%n3i, weights_per_zpoint(1))
    
      weight_xy=f_malloc((/lzd%glr%d%n1i,lzd%glr%d%n2i/),id='weight_xy')
    
      !write(*,*) 'iproc, nscatterarr', iproc, nscatterarr(iproc,:)
    
      tt=0.d0
      weights_per_slice(:) = 0.0d0
      do i3=nscatterarr(iproc,3)+1,nscatterarr(iproc,3)+nscatterarr(iproc,2)
          call to_zero(lzd%glr%d%n1i*lzd%glr%d%n2i, weight_xy(1,1))
          do iorb=1,orbs%norb
              if (orbs%spinsgn(iorb)<0.d0) cycle !consider only up orbitals
              ilr=orbs%inwhichlocreg(iorb)
              is3=1+lzd%Llr(ilr)%nsi3
              ie3=lzd%Llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i
              if (is3>i3 .or. i3>ie3) cycle
              is1=1+lzd%Llr(ilr)%nsi1
              ie1=lzd%Llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i
              is2=1+lzd%Llr(ilr)%nsi2
              ie2=lzd%Llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i
              !$omp parallel default(none) shared(is2, ie2, is1, ie1, weight_xy) private(i2, i1)
              !$omp do
              do i2=is2,ie2
                  do i1=is1,ie1
                      weight_xy(i1,i2) = weight_xy(i1,i2)+1.d0
                  end do
              end do
              !$omp end do
              !$omp end parallel
          end do
          zz=0.d0
          !$omp parallel default(none) shared(lzd, weight_xy, zz, tt) private(i2, i1)
          !$omp do reduction(+: tt, zz)
          do i2=1,lzd%glr%d%n2i
              do i1=1,lzd%glr%d%n1i
                 tt = tt + .5d0*(weight_xy(i1,i2)*(weight_xy(i1,i2)+1.d0))
                 zz = zz + .5d0*(weight_xy(i1,i2)*(weight_xy(i1,i2)))
              end do
          end do
          !$omp end do
          !$omp end parallel
          weights_per_zpoint(i3)=zz
      end do
      weights_per_slice(iproc)=tt
      if (nproc > 1) then
         call mpiallred(weights_per_slice(0), nproc, mpi_sum, bigdft_mpi%mpi_comm)
         call mpiallred(tt,1,mpi_sum, bigdft_mpi%mpi_comm,recvbuf=weight_tot)
         !call mpi_allreduce(tt, weight_tot, 1, mpi_double_precision, mpi_sum, bigdft_mpi%mpi_comm, ierr)
         call mpiallred(weights_per_zpoint(1), lzd%glr%d%n3i, mpi_sum, bigdft_mpi%mpi_comm)
      else
         weight_tot=tt
      end if
    
      call f_free(weight_xy)
    
      ! Ideal weight per process
      weight_ideal = weight_tot/dble(nproc)
    
      call f_release_routine()
    
    end subroutine get_weights_sumrho


    subroutine assign_weight_to_process_sumrho(iproc, nproc, weight_tot, weight_ideal, weights_per_slice, &
               lzd, orbs, nscatterarr, istartend, nptsp)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      real(kind=8),intent(in) :: weight_tot, weight_ideal
      real(kind=8),dimension(0:nproc-1),intent(in) :: weights_per_slice
      type(local_zone_descriptors),intent(in) :: lzd
      type(orbitals_data),intent(in) :: orbs
      integer,dimension(0:nproc-1,4),intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      integer,dimension(2,0:nproc-1),intent(out) :: istartend
      integer,intent(out) :: nptsp
    
      ! Local variables
      integer :: jproc, i1, i2, i3, ii, iorb, ilr, is1, ie1, is2, ie2, is3, ie3, jproc_out
      real(kind=8),dimension(:,:),allocatable :: slicearr
      real(kind=8), dimension(:,:),allocatable :: weights_startend
      real(kind=8) :: tt
    
      call f_routine(id='assign_weight_to_process_sumrho')
    
      weights_startend=f_malloc((/1.to.2,0.to.nproc-1/),id='weights_startend')
    
      tt=0.d0
      weights_startend(1,0)=0.d0
      do jproc=0,nproc-2
          tt=tt+weight_ideal
          weights_startend(2,jproc)=dble(floor(tt,kind=8))
          weights_startend(1,jproc+1)=dble(floor(tt,kind=8))+1.d0
      end do
      weights_startend(2,nproc-1)=weight_tot
    
      ! Iterate through all grid points and assign them to processes such that the
      ! load balancing is optimal.
      if (nproc==1) then
          istartend(1,0)=1
          istartend(2,0)=lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i
      else
          slicearr=f_malloc((/lzd%glr%d%n1i,lzd%glr%d%n2i/),id='slicearr')
          istartend(1,:)=0
          istartend(2,:)=0
          tt=0.d0
          jproc=0
          ii=0
          outer_loop: do jproc_out=0,nproc-1
              if (tt+weights_per_slice(jproc_out)<weights_startend(1,iproc)) then
                  tt=tt+weights_per_slice(jproc_out)
                  ii=ii+nscatterarr(jproc_out,2)*lzd%glr%d%n1i*lzd%glr%d%n2i
                  cycle outer_loop
              end if
              i3_loop: do i3=nscatterarr(jproc_out,3)+1,nscatterarr(jproc_out,3)+nscatterarr(jproc_out,2)
                  call to_zero(lzd%glr%d%n1i*lzd%glr%d%n2i, slicearr(1,1))
                  do iorb=1,orbs%norb
                      if (orbs%spinsgn(iorb)<0.d0) cycle !consider only up orbitals
                      ilr=orbs%inwhichlocreg(iorb)
                      is1=1+lzd%Llr(ilr)%nsi1
                      ie1=lzd%Llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i
                      is2=1+lzd%Llr(ilr)%nsi2
                      ie2=lzd%Llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i
                      is3=1+lzd%Llr(ilr)%nsi3
                      ie3=lzd%Llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i
                      if (is3>i3 .or. i3>ie3) cycle
                      !$omp parallel default(none) shared(lzd, slicearr, is1, ie1, is2, ie2) private(i1, i2)
                      !$omp do
                      do i2=1,lzd%glr%d%n2i
                          if (is2>i2 .or. i2>ie2) cycle
                          do i1=1,lzd%glr%d%n1i
                              if (is1<=i1 .and. i1<=ie1) then
                                  slicearr(i1,i2)=slicearr(i1,i2)+1.d0
                              end if
                          end do
                      end do
                      !$omp end do
                      !$omp end parallel
                  end do
                  do i2=1,lzd%glr%d%n2i
                      do i1=1,lzd%glr%d%n1i
                          ii=ii+1
                          tt=tt+.5d0*slicearr(i1,i2)*(slicearr(i1,i2)+1.d0)
                          if (tt>=weights_startend(1,iproc)) then
                              istartend(1,iproc)=ii
                              exit outer_loop
                          end if
                      end do
                   end do
               end do i3_loop
            end do outer_loop
            call f_free(slicearr)
      end if
    
      if (nproc > 1) then
         call mpiallred(istartend(1,0), 2*nproc, mpi_sum, bigdft_mpi%mpi_comm)
      end if
    
      do jproc=0,nproc-2
          istartend(2,jproc)=istartend(1,jproc+1)-1
      end do
      istartend(2,nproc-1)=lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i
    
      do jproc=0,nproc-1
          if (iproc==jproc) then
              nptsp=istartend(2,jproc)-istartend(1,jproc)+1
          end if
      end do
    
      call f_free(weights_startend)
    
      ! Some check
      ii=nptsp
      if (nproc > 1) then
        call mpiallred(ii, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if
      if (ii/=lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i) then
          stop 'ii/=lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i'
      end if
    
      call f_release_routine()
    
    end subroutine assign_weight_to_process_sumrho



    subroutine determine_num_orbs_per_gridpoint_sumrho(iproc, nproc, nptsp, lzd, orbs, &
               istartend, weight_tot, weights_per_zpoint, norb_per_gridpoint)
      use module_base
      use module_types
      use yaml_output
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nptsp
      type(local_zone_descriptors),intent(in) :: lzd
      type(orbitals_data),intent(in) :: orbs
      integer,dimension(2,0:nproc-1),intent(in) :: istartend
      real(kind=8),intent(in) :: weight_tot
      real(kind=8),dimension(lzd%glr%d%n3i),intent(in) :: weights_per_zpoint
      integer,dimension(nptsp),intent(out) :: norb_per_gridpoint
    
      ! Local variables
      integer :: i3, ii, i2, i1, ipt, ilr, is1, ie1, is2, ie2, is3, ie3, iorb, i, ii3, ii2
      real(kind=8) :: tt, weight_check
    
    
      if (nptsp>0) then
          call to_zero(nptsp, norb_per_gridpoint(1))
      end if
      do i3=1,lzd%glr%d%n3i
          if (i3*lzd%glr%d%n1i*lzd%glr%d%n2i<istartend(1,iproc) .or. &
              (i3-1)*lzd%glr%d%n1i*lzd%glr%d%n2i+1>istartend(2,iproc)) then
              cycle
          end if
          ii3=(i3-1)*lzd%glr%d%n1i*lzd%glr%d%n2i
          if (weights_per_zpoint(i3)==0.d0) then
              cycle
          end if
          do iorb=1,orbs%norbu
              ilr=orbs%inwhichlocreg(iorb)
              is3=1+lzd%Llr(ilr)%nsi3
              ie3=lzd%Llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i
              if (is3>i3 .or. i3>ie3) cycle
              is2=1+lzd%Llr(ilr)%nsi2
              ie2=lzd%Llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i
              is1=1+lzd%Llr(ilr)%nsi1
              ie1=lzd%Llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i
              !$omp parallel default(none) &
              !$omp shared(i3, ii3, is2, ie2, is1, ie1, lzd, istartend, iproc, norb_per_gridpoint) private(i2, i1, ii, ii2, ipt)
              !$omp do
              do i2=is2,ie2
                  ii2=ii3+(i2-1)*lzd%glr%d%n1i
                  do i1=is1,ie1
                      ii=ii2+i1
                      if (ii>=istartend(1,iproc) .and. ii<=istartend(2,iproc)) then
                          ipt=ii-istartend(1,iproc)+1
                          norb_per_gridpoint(ipt)=norb_per_gridpoint(ipt)+1
                      end if
                  end do
              end do
              !$omp end do
              !$omp end parallel
          end do
      end do
    
      tt=0.d0
      !$omp parallel default(none) shared(tt, nptsp, norb_per_gridpoint) private(i)
      !$omp do reduction(+:tt)
      do i=1,nptsp
          tt=tt+.5d0*dble(norb_per_gridpoint(i)*(norb_per_gridpoint(i)+1))
      end do
      !$omp end do
      !$omp end parallel
      weight_check=tt
    
    
      ! Some check
      if (nproc > 1) then
        call mpiallred(weight_check, 1, mpi_sum, bigdft_mpi%mpi_comm)
      end if
      if (abs(weight_check-weight_tot) > 1.d-3) then
          write(*,*) 'ERROR: weight_check/=weight_tot', weight_check, weight_tot
          stop '2: weight_check/=weight_tot'
      else if (abs(weight_check-weight_tot) > 0.d0) then
         call yaml_warning('The total weight for density seems inconsistent! Ref:'//&
               trim(yaml_toa(weight_tot,fmt='(1pe25.17)'))//', Check:'//&
               trim(yaml_toa(weight_check,fmt='(1pe25.17)')))
      end if
    
    end subroutine determine_num_orbs_per_gridpoint_sumrho


    subroutine determine_communication_arrays_sumrho(iproc, nproc, nptsp, lzd, orbs, &
               istartend, nsendcounts, nsenddspls, nrecvcounts, &
               nrecvdspls, ndimpsi)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nptsp
      type(local_zone_descriptors),intent(in) :: lzd
      type(orbitals_data),intent(in) :: orbs
      integer,dimension(2,0:nproc-1),intent(in) :: istartend
      integer,dimension(0:nproc-1),intent(out) :: nsendcounts, nsenddspls, nrecvcounts, nrecvdspls
      integer,intent(out) :: ndimpsi
    
      ! Local variables
      integer :: iorb, iiorb, ilr, is1, ie1, is2, ie2, is3, ie3, jproc, i3, i2, i1, ind, ii, ierr, ii0, ii3, ii2
      integer,dimension(:),allocatable :: nsendcounts_tmp, nsenddspls_tmp, nrecvcounts_tmp, nrecvdspls_tmp
      character(len=*),parameter :: subname='determine_communication_arrays_sumrho'
    
    
      call to_zero(nproc,nsendcounts(0))
    
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          is1=1+lzd%Llr(ilr)%nsi1
          ie1=lzd%Llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i
          is2=1+lzd%Llr(ilr)%nsi2
          ie2=lzd%Llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i
          is3=1+lzd%Llr(ilr)%nsi3
          ie3=lzd%Llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i
          do jproc=0,nproc-1
              ii=0
              do i3=is3,ie3
                  if (i3*lzd%glr%d%n1i*lzd%glr%d%n2i<istartend(1,jproc) .or. &
                      (i3-1)*lzd%glr%d%n1i*lzd%glr%d%n2i+1>istartend(2,jproc)) then
                      cycle
                  end if
                  ii0=0
                  ii3=(i3-1)*lzd%glr%d%n1i*lzd%glr%d%n2i
                  !$omp parallel default(none) &
                  !$omp shared(i3, is2, ie2, is1, ie1, lzd, istartend, jproc, ii0, ii3) private(i2, i1, ind, ii2)
                  !$omp do reduction(+:ii0)
                  do i2=is2,ie2
                      ii2=ii3+(i2-1)*lzd%glr%d%n1i
                      do i1=is1,ie1
                        ind = ii2+i1
                        if (ind>=istartend(1,jproc) .and. ind<=istartend(2,jproc)) then
                            !nsendcounts(jproc)=nsendcounts(jproc)+1
                            ii0=ii0+1
                        end if
                      end do
                  end do
                  !$omp end do
                  !$omp end parallel
                  ii=ii+ii0
              end do
             nsendcounts(jproc)=nsendcounts(jproc)+ii
           end do
      end do
    
    
      ! Some check
      ii=0
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          ilr=orbs%inwhichlocreg(iiorb)
          ii = ii + lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i
      end do
      if (ii/=sum(nsendcounts)) then
          stop 'ii/=sum(nsendcounts)'
      end if
      ndimpsi=ii
    
    
      nsenddspls(0)=0
      do jproc=1,nproc-1
          nsenddspls(jproc)=nsenddspls(jproc-1)+nsendcounts(jproc-1)
      end do
    
      nsendcounts_tmp = f_malloc(0.to.nproc-1,id='nsendcounts_tmp')
      nsenddspls_tmp = f_malloc(0.to.nproc-1,id='nsenddspls_tmp')
      nrecvcounts_tmp = f_malloc(0.to.nproc-1,id='nrecvcounts_tmp')
      nrecvdspls_tmp = f_malloc(0.to.nproc-1,id='nrecvdspls_tmp')
      nsendcounts_tmp=1
      nrecvcounts_tmp=1
      do jproc=0,nproc-1
          nsenddspls_tmp(jproc)=jproc
          nrecvdspls_tmp(jproc)=jproc
      end do
      if(nproc>1) then
          call mpi_alltoallv(nsendcounts, nsendcounts_tmp, nsenddspls_tmp, mpi_integer, nrecvcounts, &
               nrecvcounts_tmp, nrecvdspls_tmp, mpi_integer, bigdft_mpi%mpi_comm, ierr)
      else
          nrecvcounts=nsendcounts
      end if
      call f_free(nsendcounts_tmp)
      call f_free(nsenddspls_tmp)
      call f_free(nrecvcounts_tmp)
      call f_free(nrecvdspls_tmp)
    
      !!ndimind = sum(nrecvcounts)
    
      !!! Some check
      !!ii=sum(norb_per_gridpoint)
      !!if (ii/=ndimind) stop 'ii/=sum(nrecvcounts)'
    
      nrecvdspls(0)=0
      do jproc=1,nproc-1
          nrecvdspls(jproc)=nrecvdspls(jproc-1)+nrecvcounts(jproc-1)
      end do
    
    end subroutine determine_communication_arrays_sumrho



    subroutine get_switch_indices_sumrho(iproc, nproc, nptsp, ndimpsi, ndimind, lzd, orbs, nspin, istartend, &
               norb_per_gridpoint, nsendcounts, nsenddspls, nrecvcounts, nrecvdspls, &
               isendbuf, irecvbuf, iextract, iexpand, indexrecvorbital)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, nptsp, ndimpsi, ndimind, nspin
      type(local_zone_descriptors),intent(in) :: lzd
      type(orbitals_data),intent(in) :: orbs
      integer,dimension(2,0:nproc-1),intent(in) :: istartend
      integer,dimension(nptsp),intent(in) :: norb_per_gridpoint
      integer,dimension(0:nproc-1),intent(in) :: nsendcounts, nsenddspls, nrecvcounts, nrecvdspls
      integer,dimension(ndimpsi),intent(out) :: isendbuf, irecvbuf
      integer,dimension(ndimind),intent(out) :: iextract, iexpand, indexrecvorbital
    
      ! Local variables
      integer :: jproc, iitot, iiorb, ilr, is1, ie1, is2, ie2, is3, ie3, i3, i2, i1, ind, indglob, ierr, ii
      integer :: iorb, i, ipt, indglob2, indglob3, indglob3a, itotadd
      integer,dimension(:),allocatable :: nsend, indexsendbuf, indexsendorbital, indexsendorbital2, indexrecvorbital2
      integer,dimension(:),allocatable :: gridpoint_start, indexrecvbuf, gridpoint_start_tmp
      character(len=*),parameter :: subname='get_switch_indices_sumrho'
    
    
      nsend = f_malloc(0.to.nproc-1,id='nsend')
      nsend=0
      indexsendbuf = f_malloc(ndimpsi,id='indexsendbuf')
      indexsendorbital = f_malloc(ndimpsi,id='indexsendorbital')
      !!allocate(isendbuf(ndimpsi), stat=istat)
      !!call memocc(istat, isendbuf, 'isendbuf', subname)
    
      iitot=0
      !!$omp parallel default(shared) &
      !!$omp private(iorb, iiorb, ilr, is1, ie1, is2, ie2, is3, ie3, i3, i2, i1, indglob, ind)
      !!$omp do lastprivate(iitot)
      do jproc=0,nproc-1
          iitot=0
          do iorb=1,orbs%norbp
              iiorb=orbs%isorb+iorb
              ilr=orbs%inwhichlocreg(iiorb)
              is1=1+lzd%Llr(ilr)%nsi1
              ie1=lzd%Llr(ilr)%nsi1+lzd%llr(ilr)%d%n1i
              is2=1+lzd%Llr(ilr)%nsi2
              ie2=lzd%Llr(ilr)%nsi2+lzd%llr(ilr)%d%n2i
              is3=1+lzd%Llr(ilr)%nsi3
              ie3=lzd%Llr(ilr)%nsi3+lzd%llr(ilr)%d%n3i
              itotadd=(ie2-is2+1)*(ie1-is1+1)
              do i3=is3,ie3
                  indglob3a=i3*lzd%glr%d%n1i*lzd%glr%d%n2i
                  indglob3=indglob3a-lzd%glr%d%n1i*lzd%glr%d%n2i
                  if (indglob3a<istartend(1,jproc) .or. &
                      indglob3+1>istartend(2,jproc)) then
                      iitot=iitot+itotadd
                      cycle
                  end if
                  do i2=is2,ie2
                      indglob2=indglob3+(i2-1)*lzd%glr%d%n1i
                      do i1=is1,ie1
                          indglob = indglob2+i1
                          iitot=iitot+1
                          if (indglob>=istartend(1,jproc) .and. indglob<=istartend(2,jproc)) then
                              nsend(jproc)=nsend(jproc)+1
                              ind=nsenddspls(jproc)+nsend(jproc)
                              isendbuf(iitot)=ind
                              indexsendbuf(ind)=indglob
                              indexsendorbital(iitot)=iiorb
                              !exit
                          end if
                      end do
                  end do
              end do
          end do
      end do
      !!$omp end do
      !!$omp end parallel
    
    
      if(iitot/=ndimpsi) stop 'iitot/=ndimpsi'
    
      !check
      do jproc=0,nproc-1
          if(nsend(jproc)/=nsendcounts(jproc)) stop 'nsend(jproc)/=nsendcounts(jproc)'
      end do
    
    !!call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
    !!t2=mpi_wtime()
    !!tt=t2-t1
    !!if(iproc==0) write(*,*) 'time 5.1: iproc', iproc, tt
    
    
    
      !!allocate(irecvbuf(ndimpsi), stat=istat)
      !!call memocc(istat, irecvbuf, 'irecvbuf', subname)
    
      indexsendorbital2 = f_malloc(ndimpsi,id='indexsendorbital2')
      indexsendorbital2=indexsendorbital
      do i=1,ndimpsi
          ind=isendbuf(i)
          indexsendorbital(ind)=indexsendorbital2(i)
      end do
    
      ! Inverse of isendbuf
      call get_reverse_indices(ndimpsi, isendbuf, irecvbuf)
    
      call f_free(indexsendorbital2)
    
    
      indexrecvbuf = f_malloc(ndimind,id='indexrecvbuf')
      !!allocate(indexrecvorbital(ndimind), stat=istat)
      !!call memocc(istat, indexrecvorbital, 'indexrecvorbital', subname)
    
      if(nproc>1) then
          ! Communicate indexsendbuf
          call mpi_alltoallv(indexsendbuf, nsendcounts, nsenddspls, mpi_integer, indexrecvbuf, &
               nrecvcounts, nrecvdspls, mpi_integer, bigdft_mpi%mpi_comm, ierr)
          ! Communicate indexsendorbitals
          call mpi_alltoallv(indexsendorbital, nsendcounts, nsenddspls, &
               mpi_integer, indexrecvorbital, &
               nrecvcounts, nrecvdspls, mpi_integer, bigdft_mpi%mpi_comm, ierr)
       else
           indexrecvbuf=indexsendbuf
           indexrecvorbital=indexsendorbital
       end if
    
      call f_free(indexsendbuf)
    
      call f_free(indexsendorbital)
    !!call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
    !!t2=mpi_wtime()
    !!tt=t2-t1
    !!if(iproc==0) write(*,*) 'time 5.2: iproc', iproc, tt
    
    
       gridpoint_start = f_malloc(istartend(1, iproc).to.istartend(2, iproc),id='gridpoint_start')
       gridpoint_start_tmp = f_malloc(istartend(1, iproc).to.istartend(2, iproc),id='gridpoint_start_tmp')
    
       ii=1
       do ipt=1,nptsp
           i=ipt+istartend(1,iproc)-1
           if (norb_per_gridpoint(ipt)>0) then
               gridpoint_start(i)=ii
           else
               gridpoint_start(i)=0
           end if
           ii=ii+norb_per_gridpoint(ipt)
       end do
    
       if (nspin*ii/=ndimind+nspin) then
           stop '(nspin*ii/=ndimind+nspin)'
       end if
       if(maxval(gridpoint_start)>ndimind) stop '1: maxval(gridpoint_start)>sum(nrecvcountc)'
       if(minval(indexrecvbuf)<istartend(1,iproc)) stop '1: minval(indexrecvbuf)<istartend(1,iproc)'
       if(maxval(indexrecvbuf)>istartend(2,iproc)) stop '1: maxval(indexrecvbuf)>istartend(2,iproc)'
    
       !!allocate(iextract(ndimind), stat=istat)
       !!call memocc(istat, iextract, 'iextract', subname)

       gridpoint_start_tmp = gridpoint_start
    
      ! Rearrange the communicated data
      do i=1,ndimind
          ii=indexrecvbuf(i)
          ind=gridpoint_start(ii)
          !if (gridpoint_start(ii)-gridpoint_start_tmp(ii)>norb_per_gridpoint(ii-istartend(1,iproc)+1)) then
          if (gridpoint_start(ii)-gridpoint_start_tmp(ii)+1>norb_per_gridpoint(ii-istartend(1,iproc)+1)) then
              ! orbitals which fulfill this condition are down orbitals which
              ! should be put at the end
              ind = ind + (ndimind/2-norb_per_gridpoint(ii-istartend(1,iproc)+1))
          end if
          iextract(i)=ind
          gridpoint_start(ii)=gridpoint_start(ii)+1
          !!write(*,'(a,5i9)') 'ii, gridpoint_start(ii), gridpoint_start_tmp(ii), rep per gridpoint, norb_per_gridpoint(ii-istartend(1,iproc)+1)', &
          !!                    ii, gridpoint_start(ii), gridpoint_start_tmp(ii), gridpoint_start(ii)-gridpoint_start_tmp(ii), norb_per_gridpoint(ii-istartend(1,iproc)+1)
      end do

    
      if(maxval(iextract)>ndimind) then
          stop 'maxval(iextract)>ndimind'
      end if
      if(minval(iextract)<1) stop 'minval(iextract)<1'
    
      call f_free(indexrecvbuf)
    
    
      !! allocate(iexpand(ndimind), stat=istat)
      !! call memocc(istat, iexpand, 'iexpand', subname)
      ! Get the array to transfrom back the data
      call get_reverse_indices(ndimind, iextract, iexpand)
    
    !!call mpi_barrier(bigdft_mpi%mpi_comm, ierr)
    !!t2=mpi_wtime()
    !!tt=t2-t1
    !!if(iproc==0) write(*,*) 'time 5.3: iproc', iproc, tt
    
      indexrecvorbital2 = f_malloc(ndimind,id='indexrecvorbital2')
    
      if (ndimind>0) then
          call vcopy(ndimind, indexrecvorbital(1), 1, indexrecvorbital2(1), 1)
      end if
    
      !$omp parallel default(none) &
      !$omp shared(ndimind, iextract, indexrecvorbital, indexrecvorbital2) private(i, ind)
      !$omp do
      do i=1,ndimind
          ind=iextract(i)
          indexrecvorbital(ind)=indexrecvorbital2(i)
      end do
      !$omp end do
      !$omp end parallel
    
      call f_free(indexrecvorbital2)
    
      if(minval(indexrecvorbital)<1) stop 'minval(indexrecvorbital)<1'
      if(maxval(indexrecvorbital)>orbs%norb) stop 'maxval(indexrecvorbital)>orbs%norb'
    
    
      call f_free(gridpoint_start)
      call f_free(gridpoint_start_tmp)
      call f_free(nsend)
    
    
    end subroutine get_switch_indices_sumrho



    subroutine communication_arrays_repartitionrho(iproc, nproc, lzd, nscatterarr, istartend, &
               nsendcounts_repartitionrho, nsenddspls_repartitionrho, &
               nrecvcounts_repartitionrho, nrecvdspls_repartitionrho)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(0:nproc-1,4),intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      integer,dimension(2,0:nproc-1),intent(in) :: istartend
      integer,dimension(0:nproc-1),intent(out) :: nsendcounts_repartitionrho, nsenddspls_repartitionrho
      integer,dimension(0:nproc-1),intent(out) :: nrecvcounts_repartitionrho, nrecvdspls_repartitionrho
    
      ! Local variables
      integer :: jproc_send, jproc_recv, ii, i3, i2, i1, jproc
    
      jproc_send=0
      jproc_recv=0
      ii=0
      nsendcounts_repartitionrho=0
      nrecvcounts_repartitionrho=0
      do i3=1,lzd%glr%d%n3i
          do i2=1,lzd%glr%d%n2i
              do i1=1,lzd%glr%d%n1i
                  ii=ii+1
                  if (ii>istartend(2,jproc_send)) then
                      jproc_send=jproc_send+1
                  end if
                  if (i3>nscatterarr(jproc_recv,3)+nscatterarr(jproc_recv,2)) then
                      jproc_recv=jproc_recv+1
                  end if
                  if (iproc==jproc_send) then
                      nsendcounts_repartitionrho(jproc_recv)=nsendcounts_repartitionrho(jproc_recv)+1
                  end if
                  if (iproc==jproc_recv) then
                      nrecvcounts_repartitionrho(jproc_send)=nrecvcounts_repartitionrho(jproc_send)+1
                  end if
              end do
          end do
      end do
    
      nsenddspls_repartitionrho(0)=0
      nrecvdspls_repartitionrho(0)=0
      do jproc=1,nproc-1
          nsenddspls_repartitionrho(jproc)=nsenddspls_repartitionrho(jproc-1)+&
                                                      nsendcounts_repartitionrho(jproc-1)
          nrecvdspls_repartitionrho(jproc)=nrecvdspls_repartitionrho(jproc-1)+&
                                                      nrecvcounts_repartitionrho(jproc-1)
      end do
    
    end subroutine communication_arrays_repartitionrho
    
    
    subroutine communication_arrays_repartitionrho_general(iproc, nproc, lzd, nscatterarr, istartend, &
               ncomms_repartitionrho, commarr_repartitionrho)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(local_zone_descriptors),intent(in) :: lzd
      integer,dimension(0:nproc-1,4),intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      integer,dimension(2,0:nproc-1),intent(in) :: istartend
      integer,intent(out) :: ncomms_repartitionrho
      integer,dimension(:,:),pointer,intent(out) :: commarr_repartitionrho
      character(len=*),parameter :: subname='communication_arrays_repartitionrho_general'
    
      ! Local variables
      integer :: i1, i2, i3, ii, jproc, jproc_send, iidest, nel, ioverlaps, iassign
      logical :: started
    
      call f_routine(id='communication_arrays_repartitionrho_general')
    
      ! only do this if task iproc has to receive a part of the potential
      if (nscatterarr(iproc,1)>0) then
        
          ! First process from which iproc has to receive data
          ncomms_repartitionrho=0
          i3=nscatterarr(iproc,3)-nscatterarr(iproc,4)
          ii=(i3)*(lzd%glr%d%n2i)*(lzd%glr%d%n1i)+1
          do jproc=nproc-1,0,-1
              if (ii>=istartend(1,jproc)) then
                  jproc_send=jproc
                  ncomms_repartitionrho=ncomms_repartitionrho+1
                  exit
              end if
          end do
        
          ! The remaining processes
          iidest=0
          nel=0
          started=.false.
          do i3=nscatterarr(iproc,3)-nscatterarr(iproc,4)+1,nscatterarr(iproc,3)-nscatterarr(iproc,4)+nscatterarr(iproc,1)
              ii=(i3-1)*(lzd%glr%d%n2i)*(lzd%glr%d%n1i)
              do i2=1,lzd%glr%d%n2i
                  do i1=1,lzd%glr%d%n1i
                      ii=ii+1
                      iidest=iidest+1
                      if (ii>=istartend(1,jproc_send) .and. ii<=istartend(2,jproc_send)) then
                          nel=nel+1
                      else
                          jproc_send=jproc_send+1
                          ncomms_repartitionrho=ncomms_repartitionrho+1
                      end if
                  end do
              end do
          end do
        
        
          call allocate_MPI_comms_cubic_repartitionp2p(ncomms_repartitionrho, commarr_repartitionrho)
        
        
          ! First process from which iproc has to receive data
          ioverlaps=0
          i3=nscatterarr(iproc,3)-nscatterarr(iproc,4)
          ii=(i3)*(lzd%glr%d%n2i)*(lzd%glr%d%n1i)+1
          do jproc=nproc-1,0,-1
              if (ii>=istartend(1,jproc)) then
                  jproc_send=jproc
                  ioverlaps=ioverlaps+1
                  exit
              end if
          end do
        
        
          ! The remaining processes
          iassign=0
          iidest=0
          nel=0
          started=.false.
          do i3=nscatterarr(iproc,3)-nscatterarr(iproc,4)+1,nscatterarr(iproc,3)-nscatterarr(iproc,4)+nscatterarr(iproc,1)
              ii=(i3-1)*(lzd%glr%d%n2i)*(lzd%glr%d%n1i)
              do i2=1,lzd%glr%d%n2i
                  do i1=1,lzd%glr%d%n1i
                      ii=ii+1
                      iidest=iidest+1
                      if (ii>=istartend(1,jproc_send) .and. ii<=istartend(2,jproc_send)) then
                          nel=nel+1
                      else
                          commarr_repartitionrho(4,ioverlaps)=nel
                          jproc_send=jproc_send+1
                          ioverlaps=ioverlaps+1
                          nel=1
                          started=.false.
                      end if
                      if (.not.started) then
                          if (jproc_send>=nproc) stop 'ERROR: jproc_send>=nproc'
                          commarr_repartitionrho(1,ioverlaps)=jproc_send
                          commarr_repartitionrho(2,ioverlaps)=ii-istartend(1,jproc_send)+1
                          commarr_repartitionrho(3,ioverlaps)=iidest
                          started=.true.
                          iassign=iassign+1
                      end if
                  end do
              end do
          end do
          commarr_repartitionrho(4,ioverlaps)=nel
          if (ioverlaps/=ncomms_repartitionrho) stop 'ERROR: ioverlaps/=ncomms_repartitionrho'
          if (iassign/=ncomms_repartitionrho) stop 'ERROR: iassign/=ncomms_repartitionrho'
        
          ! some checks
          nel=0
          !nel_array=f_malloc0(0.to.nproc-1,id='nel_array')
          do ioverlaps=1,ncomms_repartitionrho
              nel=nel+commarr_repartitionrho(4,ioverlaps)
              ii=commarr_repartitionrho(1,ioverlaps)
              !nel_array(ii)=nel_array(ii)+commarr_repartitionrho(4,ioverlaps)
          end do
          if (nel/=nscatterarr(iproc,1)*lzd%glr%d%n2i*lzd%glr%d%n1i) then
              stop 'nel/=nscatterarr(iproc,2)*lzd%glr%d%n2i*lzd%glr%d%n1i'
          end if
          !!call mpiallred(nel_array(0), nproc, mpi_sum, bigdft_mpi%mpi_comm, ierr)
          !!if (nel_array(iproc)/=istartend(2,iproc)-istartend(1,iproc)+1) then
          !!    !stop 'nel_array(iproc)/=istartend(2,iproc)-istartend(1,iproc)+1'
          !!end if
          !!call f_free(nel_array)
    
      else
          ncomms_repartitionrho=0
          call allocate_MPI_comms_cubic_repartitionp2p(1, commarr_repartitionrho)
    
      end if
    
      call f_release_routine()
    
    end subroutine communication_arrays_repartitionrho_general




    !> Potential communication
    subroutine initialize_communication_potential(iproc, nproc, nscatterarr, orbs, lzd, nspin, comgp)
      use module_base
      use module_types
      use communications_base, only: p2pComms_null
      implicit none
      
      ! Calling arguments
      integer,intent(in):: iproc, nproc
      integer,dimension(0:nproc-1,4),intent(in):: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
      type(orbitals_data),intent(in):: orbs
      type(local_zone_descriptors),intent(in):: lzd
      integer,intent(in) :: nspin
      type(p2pComms),intent(out):: comgp
      
      ! Local variables
      integer:: is1, ie1, is2, ie2, is3, ie3, ilr, ii, iorb, iiorb, jproc, kproc, istsource
      integer:: ioverlap, is3j, ie3j, is3k, ie3k, mpidest, istdest, ioffsetx, ioffsety, ioffsetz
      integer :: is3min, ie3max, tag, ncount, ierr, nmaxoverlap
      logical :: datatype_defined
      character(len=*),parameter:: subname='initialize_communication_potential'
      integer,dimension(6) :: ise


      call timing(iproc,'init_commPot  ','ON')
      
      !call nullify_p2pComms(comgp)
      comgp = p2pComms_null()
    
      !allocate(comgp%ise(6,0:nproc-1), stat=istat)
      !call memocc(istat, comgp%ise, 'comgp%ise', subname)
      !!comgp%ise = f_malloc_ptr((/1.to.6,0.to.nproc-1/),id='comgp%ise')
      
      ! Determine the bounds of the potential that we need for
      ! the orbitals on this process.
      !iiorb=0
      is1=1000000000
      ie1=-1000000000
      is2=1000000000
      ie2=-1000000000
      is3=1000000000
      ie3=-1000000000
      !do iorb=1,orbs%norbu_par(jproc,0)
      do iorb=1,orbs%norbp
          
          iiorb=orbs%isorb+iorb 
          ilr=orbs%inwhichlocreg(iiorb)
      
          ii=1+lzd%Llr(ilr)%nsi1
          if(ii < is1) then
              is1=ii
          end if
          ii=lzd%Llr(ilr)%nsi1+lzd%Llr(ilr)%d%n1i
          if(ii > ie1) then
              ie1=ii
          end if
      
          ii=1+lzd%Llr(ilr)%nsi2
          if(ii < is2) then
              is2=ii
          end if
          ii=lzd%Llr(ilr)%nsi2+lzd%Llr(ilr)%d%n2i
          if(ii > ie2) then
              ie2=ii
          end if
      
          ii=1+lzd%Llr(ilr)%nsi3
          if(ii < is3) then
              is3=ii
          end if
          ii=lzd%Llr(ilr)%nsi3+lzd%Llr(ilr)%d%n3i
          if(ii > ie3) then
              ie3=ii
          end if
      
      end do
      comgp%ise(1)=is1
      comgp%ise(2)=ie1
      comgp%ise(3)=is2
      comgp%ise(4)=ie2
      comgp%ise(5)=is3
      comgp%ise(6)=ie3
    
    
      
      ! Determine how many slices each process receives.
      !allocate(comgp%noverlaps(0:nproc-1), stat=istat)
      !call memocc(istat, comgp%noverlaps, 'comgp%noverlaps', subname)
      !comgp%noverlaps = f_malloc_ptr(0.to.nproc-1,id='comgp%noverlaps')
      !nmaxoverlap=0
      !do jproc=0,nproc-1
          is3j=comgp%ise(5)
          ie3j=comgp%ise(6)
          mpidest=iproc
          ioverlap=0
          do kproc=0,nproc-1
              is3k=nscatterarr(kproc,3)+1
              ie3k=is3k+nscatterarr(kproc,2)-1
              if(is3j<=ie3k .and. ie3j>=is3k) then
                  ioverlap=ioverlap+1
                  !if(iproc==0) write(*,'(2(a,i0),a)') 'process ',jproc,' gets potential from process ',kproc,'.' 
              !TAKE INTO ACCOUNT THE PERIODICITY HERE
              else if(ie3j > lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F') then
                  ie3j = comgp%ise(6) - lzd%Glr%d%n3i
                  if(ie3j>=is3k) then
                     ioverlap=ioverlap+1
                  end if
                  if(is3j <= ie3k)then
                     ioverlap=ioverlap+1
                  end if
              end if
          end do
          !if (ioverlap>nmaxoverlap) nmaxoverlap=ioverlap
          comgp%noverlaps=ioverlap
          !!if(iproc==0) write(*,'(2(a,i0),a)') 'Process ',jproc,' gets ',ioverlap,' potential slices.'
      !end do
      
      ! Determine the parameters for the communications.
      !allocate(comgp%comarr(6,nmaxoverlap,0:nproc-1))
      !call memocc(istat, comgp%comarr, 'comgp%comarr', subname)
      !call to_zero(6*nmaxoverlap*nproc, comgp%comarr(1,1,0))
      comgp%comarr = f_malloc0_ptr((/1.to.6,1.to.comgp%noverlaps/),id='comgp%comarr')
      !allocate(comgp%mpi_datatypes(0:nmaxoverlap,0:nproc-1), stat=istat)
      !call memocc(istat, comgp%mpi_datatypes, 'comgp%mpi_datatypes', subname)
      !call to_zero((nmaxoverlap+1)*nproc, comgp%mpi_datatypes(0,0))
      comgp%mpi_datatypes = f_malloc0_ptr(0.to.comgp%noverlaps,id='comgp%mpi_datatypes')
      comgp%nrecvBuf = 0
      is3min=0
      ie3max=0
    
      ! Only do this if we have more than one MPI task
      nproc_if: if (nproc>1) then
          is3j=comgp%ise(5)
          ie3j=comgp%ise(6)
          mpidest=iproc
          ioverlap=0
          istdest=1
          datatype_defined =.false.
          do kproc=0,nproc-1
              is3k=nscatterarr(kproc,3)+1
              ie3k=is3k+nscatterarr(kproc,2)-1
              !SHOULD TAKE INTO ACCOUNT THE PERIODICITY HERE
              !Need to split the region
              if(is3j<=ie3k .and. ie3j>=is3k) then
                  is3=max(is3j,is3k) ! starting index in z dimension for data to be sent
                  ie3=min(ie3j,ie3k) ! ending index in z dimension for data to be sent
                  ioffsetz=is3-is3k ! starting index (in z direction) of data to be sent (actually it is the index -1)
                  ioffsety=comgp%ise(3)-1
                  ioffsetx=comgp%ise(1)
                  ioverlap=ioverlap+1
                  if(is3<is3min .or. ioverlap==1) then
                      is3min=is3
                  end if
                  if(ie3>ie3max .or. ioverlap==1) then
                      ie3max=ie3
                  end if
                  istsource = ioffsetz*lzd%glr%d%n1i*lzd%glr%d%n2i + ioffsety*lzd%glr%d%n1i + ioffsetx
                  ncount = 1
                  comgp%comarr(1,ioverlap)=kproc
                  comgp%comarr(2,ioverlap)=istsource
                  comgp%comarr(3,ioverlap)=iproc
                  comgp%comarr(4,ioverlap)=istdest
                  comgp%comarr(5,ioverlap)=ie3-is3+1
                  comgp%comarr(6,ioverlap)=lzd%glr%d%n1i*lzd%glr%d%n2i
                  if (.not. datatype_defined) then
                      call mpi_type_vector(comgp%ise(4)-comgp%ise(3)+1, comgp%ise(2)-comgp%ise(1)+1, &
                           lzd%glr%d%n1i, mpi_double_precision, comgp%mpi_datatypes(0), ierr)
                      call mpi_type_commit(comgp%mpi_datatypes(0), ierr)
                      !comgp%mpi_datatypes(2,jproc)=1
                      datatype_defined=.true.
                  end if
        
                  istdest = istdest + &
                            (ie3-is3+1)*(comgp%ise(2)-comgp%ise(1)+1)*(comgp%ise(4)-comgp%ise(3)+1)
                  !if(iproc==jproc) then
                      comgp%nrecvBuf = comgp%nrecvBuf + &
                            (ie3-is3+1)*(comgp%ise(2)-comgp%ise(1)+1)*(comgp%ise(4)-comgp%ise(3)+1)
                  !end if
              else if(ie3j > lzd%Glr%d%n3i .and. lzd%Glr%geocode /= 'F')then
                   stop 'WILL PROBABLY NOT WORK!'
                   ie3j = comgp%ise(6) - lzd%Glr%d%n3i
                   if(ie3j>=is3k) then
                       is3=max(0,is3k) ! starting index in z dimension for data to be sent
                       ie3=min(ie3j,ie3k) ! ending index in z dimension for data to be sent
                       ioffsetz=is3-0 ! starting index (in z direction) of data to be sent (actually it is the index -1)
                       ioverlap=ioverlap+1
                       !tag=tag+1
                       !!tag=p2p_tag(jproc)
                       if(is3<is3min .or. ioverlap==1) then
                           is3min=is3
                       end if
                       if(ie3>ie3max .or. ioverlap==1) then
                           ie3max=ie3
                       end if
                       !!call setCommunicationPotential(kproc, is3, ie3, ioffsetz, lzd%Glr%d%n1i, lzd%Glr%d%n2i, jproc,&
                       !!     istdest, tag, comgp%comarr(1,ioverlap,jproc))
                       istsource=ioffsetz*lzd%glr%d%n1i*lzd%glr%d%n2i+1
                       !ncount=(ie3-is3+1)*lzd%glr%d%n1i*lzd%glr%d%n2i
                       ncount=lzd%glr%d%n1i*lzd%glr%d%n2i
                       call setCommsParameters(kproc, jproc, istsource, istdest, ncount, tag, comgp%comarr(1,ioverlap))
                       comgp%comarr(7,ioverlap)=(ie3-is3+1)
                       comgp%comarr(8,ioverlap)=lzd%glr%d%n1i*lzd%glr%d%n2i
                       istdest = istdest + (ie3-is3+1)*ncount
                       if(iproc==jproc) then
                           comgp%nrecvBuf = comgp%nrecvBuf + (ie3-is3+1)*lzd%Glr%d%n1i*lzd%Glr%d%n2i
                       end if
                   end if
                   if(is3j <= ie3k)then
                       is3=max(is3j,is3k) ! starting index in z dimension for data to be sent
                       ie3=min(lzd%Glr%d%n3i,ie3k) ! ending index in z dimension for data to be sent
                       ioffsetz=is3-is3k ! starting index (in z direction) of data to be sent (actually it is the index -1)
                       ioverlap=ioverlap+1
                       !tag=tag+1
                       !!tag=p2p_tag(jproc)
                       if(is3<is3min .or. ioverlap==1) then
                           is3min=is3
                       end if
                       if(ie3>ie3max .or. ioverlap==1) then
                           ie3max=ie3
                       end if
                       !!call setCommunicationPotential(kproc, is3, ie3, ioffsetz, lzd%Glr%d%n1i, lzd%Glr%d%n2i, jproc,&
                       !!     istdest, tag, comgp%comarr(1,ioverlap,jproc))
                       istsource=ioffsetz*lzd%glr%d%n1i*lzd%glr%d%n2i+1
                       !ncount=(ie3-is3+1)*lzd%glr%d%n1i*lzd%glr%d%n2i
                       ncount=lzd%glr%d%n1i*lzd%glr%d%n2i
                       call setCommsParameters(kproc, jproc, istsource, istdest, ncount, tag, comgp%comarr(1,ioverlap))
                       comgp%comarr(7,ioverlap)=ie3-is3+1
                       comgp%comarr(8,ioverlap)=lzd%glr%d%n1i*lzd%glr%d%n2i
                       istdest = istdest + (ie3-is3+1)*ncount
                       if(iproc==jproc) then
                           comgp%nrecvBuf = comgp%nrecvBuf + (ie3-is3+1)*lzd%Glr%d%n1i*lzd%Glr%d%n2i
                       end if
                   end if
              end if
          end do
          !!comgp%ise3(1,jproc)=is3min
          !!comgp%ise3(2,jproc)=ie3max
          !!if (iproc==0) write(*,*) 'is3min,comgp%ise(5,jproc)', is3min,comgp%ise(5,jproc)
          !!if (iproc==0) write(*,*) 'ie3max,comgp%ise(6,jproc)', ie3max,comgp%ise(6,jproc)
          !if (comgp%ise(5,jproc)/=is3min) stop 'ERROR 1'
          !if (comgp%ise(6,jproc)/=ie3max) stop 'ERROR 2'
          if(ioverlap/=comgp%noverlaps) stop 'ioverlap/=comgp%noverlaps'
    
      else nproc_if ! monoproc
    
          comgp%nrecvbuf = (comgp%ise(2)-comgp%ise(1)+1)*(comgp%ise(4)-comgp%ise(3)+1)*&
                           (comgp%ise(6)-comgp%ise(5)+1)
      
      end if nproc_if
    
      ! This is the size of the communication buffer without spin
      comgp%nrecvbuf=max(comgp%nrecvbuf,1)

      ! Copy the spin value
      comgp%nspin=nspin
      
      ! To indicate that no communication is going on.
      comgp%communication_complete=.true.
      !!comgp%messages_posted=.false.
    
      call timing(iproc,'init_commPot  ','OF')
    
    end subroutine initialize_communication_potential



    !> Routines for the cubic version

    !> Partition the orbitals between processors to ensure load balancing
    !! the criterion will depend on GPU computation
    !! and/or on the sizes of the different localisation region.
    !!
    !! Calculate the number of elements to be sent to each process
    !! and the array of displacements.
    !! Cubic strategy: 
    !!    - the components are equally distributed among the wavefunctions
    !!    - each processor has all the orbitals in transposed form
    !!    - each wavefunction is equally distributed in its transposed form
    !!    - this holds for each k-point, which regroups different processors
    subroutine orbitals_communicators(iproc,nproc,lr,orbs,comms,basedist)
      use module_base
      use module_types
      use yaml_output, only: yaml_toa
      implicit none
      integer, intent(in) :: iproc,nproc
      type(locreg_descriptors), intent(in) :: lr
      type(orbitals_data), intent(inout) :: orbs
      type(comms_cubic), intent(out) :: comms
      integer, dimension(0:nproc-1,orbs%nkpts), intent(in), optional :: basedist
      !local variables
      character(len=*), parameter :: subname='orbitals_communicators'
      logical :: yesorb,yescomp
      integer :: jproc,nvctr_tot,ikpts,iorbp,jorb,norb_tot,ikpt
      integer :: nkptsp,ierr,kproc,jkpts,jkpte,jsorb,lubo,lubc,info,jkpt
      integer, dimension(:), allocatable :: mykpts
      logical, dimension(:), allocatable :: GPU_for_comp
      integer, dimension(:,:), allocatable :: nvctr_par,norb_par !<for all the components and orbitals (with k-pts)
      
      !check of allocation of important arrays
      if (.not. associated(orbs%norb_par)) then
         write(*,*)'ERROR: norb_par array not allocated'
         stop
      end if
   
      !Allocations of nvctr_par and norb_par
      nvctr_par = f_malloc((/ 0.to.nproc-1, 0.to.orbs%nkpts /),id='nvctr_par')
      norb_par = f_malloc((/ 0.to.nproc-1, 0.to.orbs%nkpts /),id='norb_par')
      mykpts = f_malloc(orbs%nkpts,id='mykpts')
    
      !initialise the arrays
      do ikpts=0,orbs%nkpts
         do jproc=0,nproc-1
            nvctr_par(jproc,ikpts)=0 
            norb_par(jproc,ikpts)=0 
         end do
      end do
    
      !calculate the same k-point distribution for the orbitals
      !assign the k-point to the given orbital, counting one orbital after each other
      jorb=1
      ikpts=1
      do jproc=0,nproc-1
         do iorbp=1,orbs%norb_par(jproc,0)
            norb_par(jproc,ikpts)=norb_par(jproc,ikpts)+1
            if (mod(jorb,orbs%norb)==0) then
               ikpts=ikpts+1
            end if
            jorb=jorb+1
         end do
      end do
      !some checks
      if (orbs%norb /= 0) then
         !check the distribution
         do ikpts=1,orbs%nkpts
            !print *,'partition',ikpts,orbs%nkpts,'ikpts',norb_par(:,ikpts)
            norb_tot=0
            do jproc=0,nproc-1
               norb_tot=norb_tot+norb_par(jproc,ikpts)
            end do
            if(norb_tot /= orbs%norb) then
               call f_err_throw('Orbital partition is incorrect for k-point'//&
                    trim(yaml_toa(ikpts))//'; expected '//&
                    trim(yaml_toa(orbs%norb))//' orbitals, found'//&
                    trim(yaml_toa(norb_tot)),&
                    err_name='BIGDFT_RUNTIME_ERROR')
            end if
         end do
      end if
    
    
      !balance the components between processors
      !in the most symmetric way
      !here the components are taken into account for all the k-points
    
      !create an array which indicate which processor has a GPU associated 
      !from the viewpoint of the BLAS routines (deprecated, not used anymore)
      GPU_for_comp = f_malloc(0.to.nproc-1,id='GPU_for_comp')
    
      if (nproc > 1 .and. .not. GPUshare) then
         call MPI_ALLGATHER(GPUblas,1,MPI_LOGICAL,GPU_for_comp(0),1,MPI_LOGICAL,&
              bigdft_mpi%mpi_comm,ierr)
      else
         GPU_for_comp(0)=GPUblas
      end if
    
      call f_free(GPU_for_comp)
    
      !old k-point repartition
    !!$  !decide the repartition for the components in the same way as the orbitals
    !!$  call parallel_repartition_with_kpoints(nproc,orbs%nkpts,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),nvctr_par)
    
    !!$  ikpts=1
    !!$  ncomp_res=(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)
    !!$  do jproc=0,nproc-1
    !!$     loop_comps: do
    !!$        if (nvctr_par(jproc,0) >= ncomp_res) then
    !!$           nvctr_par(jproc,ikpts)= ncomp_res
    !!$           ikpts=ikpts+1
    !!$           nvctr_par(jproc,0)=nvctr_par(jproc,0)-ncomp_res
    !!$           ncomp_res=(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)
    !!$        else
    !!$           nvctr_par(jproc,ikpts)= nvctr_par(jproc,0)
    !!$           ncomp_res=ncomp_res-nvctr_par(jproc,0)
    !!$           nvctr_par(jproc,0)=0
    !!$           exit loop_comps
    !!$        end if
    !!$        if (nvctr_par(jproc,0) == 0 ) then
    !!$           ncomp_res=(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)
    !!$           exit loop_comps
    !!$        end if
    !!$
    !!$     end do loop_comps
    !!$  end do
    
      !new k-point repartition
      if (present(basedist)) then
         do jkpt=1,orbs%nkpts
            do jproc=0,nproc-1
               nvctr_par(jproc,jkpt)=basedist(jproc,jkpt)
            end do
         end do
      else
         !first try the naive repartition
         call kpts_to_procs_via_obj(nproc,orbs%nkpts,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),nvctr_par(0,1))
      end if
      !then silently check whether the distribution agree
      info=-1
      call check_kpt_distributions(nproc,orbs%nkpts,orbs%norb,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),&
           norb_par(0,1),nvctr_par(0,1),info,lubo,lubc)
      if (info/=0 .and. .not. present(basedist)) then !redo the distribution based on the orbitals scheme
         info=-1
         call components_kpt_distribution(nproc,orbs%nkpts,orbs%norb,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),norb_par(0,1),nvctr_par(0,1))
         call check_kpt_distributions(nproc,orbs%nkpts,orbs%norb,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),&
              norb_par(0,1),nvctr_par(0,1),info,lubo,lubc)
      end if
      if (info /=0) then
         !if (iproc==0) then
         !   write(*,*)'ERROR for nproc,nkpts,norb,nvctr',nproc,orbs%nkpts,orbs%norb,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)
         !   call print_distribution_schemes(nproc,orbs%nkpts,norb_par(0,1),nvctr_par(0,1))
         !end if
         !call MPI_BARRIER(bigdft_mpi%mpi_comm,ierr)
         !stop
         if (iproc==0) call print_distribution_schemes(nproc,orbs%nkpts,norb_par(0,1),nvctr_par(0,1))
         call f_err_throw('ERROR for nproc,nkpts,norb,nvctr' // &
              & trim(yaml_toa( (/ nproc,orbs%nkpts,orbs%norb,(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f) /) )), &
              & err_id=BIGDFT_RUNTIME_ERROR)
      end if
    
    !write(*,'(a,i2,3x,8i7,i10)') 'iproc, nvctr_par(jproc), sum', iproc, (nvctr_par(jproc,1), jproc=0,nproc-1), sum(nvctr_par(:,1))
    !write(*,*) 'iproc, (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%norbp', iproc, (lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%norbp
      !some checks
      !check the distribution
      do ikpts=1,orbs%nkpts
         !print *,'iproc,cpts:',lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,nvctr_par(:,ikpts)
         nvctr_tot=0
         do jproc=0,nproc-1
            nvctr_tot=nvctr_tot+nvctr_par(jproc,ikpts)
         end do
         if(nvctr_tot /= lr%wfd%nvctr_c+7*lr%wfd%nvctr_f) then
            write(*,*)'ERROR: partition of components incorrect, kpoint:',ikpts
            stop
         end if
      end do
    
      !this function which associates a given k-point to a processor in the component distribution
      !the association is chosen such that each k-point is associated to only
      !one processor
      !if two processors treat the same k-point the processor which highest rank is chosen
      do ikpts=1,orbs%nkpts
         loop_jproc: do jproc=nproc-1,0,-1
            if (nvctr_par(jproc,ikpts) /= 0) then
               orbs%ikptproc(ikpts)=jproc
               exit loop_jproc
            end if
         end do loop_jproc
      end do
      
      !print*,'check',orbs%ikptproc(:)
    
    !write(*,*) 'orbs%norb_par',orbs%norb_par
    
      !calculate the number of k-points treated by each processor in both
      ! the component distribution and the orbital distribution.
      !to have a correct distribution, a k-point should be divided between the same processors
      nkptsp=0
      orbs%iskpts=-1
      do ikpts=1,orbs%nkpts
         if (nvctr_par(iproc,ikpts) /= 0 .or. norb_par(iproc,ikpts) /= 0) then
            if (orbs%iskpts == -1) orbs%iskpts=ikpts-1
            nkptsp=nkptsp+1
            mykpts(nkptsp) = ikpts
         end if
      end do
      orbs%nkptsp=nkptsp
    
    !!$  allocate(orbs%ikptsp(orbs%nkptsp+ndebug),stat=i_stat)
    !!$  call memocc(i_stat,orbs%ikptsp,'orbs%ikptsp',subname)
    !!$  orbs%ikptsp(1:orbs%nkptsp)=mykpts(1:orbs%nkptsp)
    
      !print the distribution scheme used for this set of orbital
      !in the case of multiple k-points
      if (iproc == 0 .and. verbose > 1 .and. orbs%nkpts > 1) then
         call print_distribution_schemes(nproc,orbs%nkpts,norb_par(0,1),nvctr_par(0,1))
      end if
    
      !print *,iproc,orbs%nkptsp,orbs%norbp,orbs%norb,orbs%nkpts
      !call MPI_BARRIER(bigdft_mpi%mpi_comm,ierr)
      !call MPI_FINALIZE(ierr)
      !stop
      !check that for any processor the orbital k-point repartition is contained into the components
      if (orbs%norb /= 0) then
         do jproc=0,nproc-1
            jsorb=0
            do kproc=0,jproc-1
               jsorb=jsorb+orbs%norb_par(kproc,0)
            end do
            jkpts=min(jsorb/orbs%norb+1,orbs%nkpts)
            if (nvctr_par(jproc,jkpts) == 0 .and. orbs%norb_par(jproc,0) /=0 ) then
               if (iproc ==0) write(*,*)'ERROR, jproc: ',jproc,' the orbital k-points distribution starts before the components one'
               !print *,jsorb,jkpts,jproc,orbs%iskpts,nvctr_par(jproc,jkpts)
               stop
            end if
            jkpte=min((jsorb+orbs%norb_par(jproc,0)-1)/orbs%norb+1,orbs%nkpts)
            if (nvctr_par(jproc,jkpte) == 0 .and. orbs%norb_par(jproc,0) /=0) then
               if (iproc ==0) write(*,*)'ERROR, jproc: ',jproc,&
                    ' the orbital k-points distribution ends after the components one'
               print *,jsorb,jkpte,jproc,orbs%iskpts,orbs%nkptsp,nvctr_par(jproc,jkpte)
               stop
            end if
         end do
      end if
    
      !before printing the distribution schemes, check that the two distributions contain
      !the same k-points
      yesorb=.false.
      kpt_components: do ikpts=1,orbs%nkptsp
         ikpt=orbs%iskpts+ikpts
         do jorb=1,orbs%norbp
            if (orbs%iokpt(jorb) == ikpt) yesorb=.true.
         end do
         if (.not. yesorb .and. orbs%norbp /= 0) then
            write(*,*)' ERROR: processor ', iproc,' kpt ',ikpt,&
                 ' not found in the orbital distribution'
            call MPI_ABORT(bigdft_mpi%mpi_comm, ierr)
         end if
      end do kpt_components
    
      yescomp=.false.
      kpt_orbitals: do jorb=1,orbs%norbp
         ikpt=orbs%iokpt(jorb)   
         do ikpts=1,orbs%nkptsp
            if (orbs%iskpts+ikpts == ikpt) yescomp=.true.
         end do
         if (.not. yescomp) then
            write(*,*)' ERROR: processor ', iproc,' kpt,',ikpt,&
                 'not found in the component distribution'
            call MPI_ABORT(bigdft_mpi%mpi_comm, ierr)
         end if
      end do kpt_orbitals
    
      !print *,'AAAAiproc',iproc,orbs%iskpts,orbs%iskpts+orbs%nkptsp
    
      !allocate communication arrays
      comms%nvctr_par = f_malloc_ptr((/ 0.to.nproc-1, 0.to.orbs%nkpts /),id='comms%nvctr_par')
      comms%ncntd = f_malloc_ptr(0.to.nproc-1,id='comms%ncntd')
      comms%ncntt = f_malloc_ptr(0.to.nproc-1,id='comms%ncntt')
      comms%ndspld = f_malloc_ptr(0.to.nproc-1,id='comms%ndspld')
      comms%ndsplt = f_malloc_ptr(0.to.nproc-1,id='comms%ndsplt')
    
      !assign the partition of the k-points to the communication array
      !calculate the number of componenets associated to the k-point
      do jproc=0,nproc-1
         comms%nvctr_par(jproc,0)=0
         do ikpt=1,orbs%nkpts
            comms%nvctr_par(jproc,0)=comms%nvctr_par(jproc,0)+&
                 nvctr_par(jproc,ikpt) 
            comms%nvctr_par(jproc,ikpt)=nvctr_par(jproc,ikpt)
         end do
      end do
    !!$  do ikpts=1,orbs%nkptsp
    !!$     ikpt=orbs%iskpts+ikpts!orbs%ikptsp(ikpts)
    !!$     do jproc=0,nproc-1
    !!$        comms%nvctr_par(jproc,ikpts)=nvctr_par(jproc,ikpt) 
    !!$     end do
    !!$  end do
    
      !with this distribution the orbitals and the components are ordered following k-points
      !there must be no overlap for the components
      !here we will print out the k-points components distribution, in the transposed and in the direct way
    
      do jproc=0,nproc-1
         comms%ncntd(jproc)=0
         do ikpts=1,orbs%nkpts
            comms%ncntd(jproc)=comms%ncntd(jproc)+&
                 nvctr_par(jproc,ikpts)*norb_par(iproc,ikpts)*orbs%nspinor
         end do
      end do
      comms%ndspld(0)=0
      do jproc=1,nproc-1
         comms%ndspld(jproc)=comms%ndspld(jproc-1)+comms%ncntd(jproc-1)
      end do
      !receive buffer
      do jproc=0,nproc-1
         comms%ncntt(jproc)=0
         do ikpts=1,orbs%nkpts
            comms%ncntt(jproc)=comms%ncntt(jproc)+&
                 nvctr_par(iproc,ikpts)*norb_par(jproc,ikpts)*orbs%nspinor
         end do
      end do
      comms%ndsplt(0)=0
      do jproc=1,nproc-1
         comms%ndsplt(jproc)=comms%ndsplt(jproc-1)+comms%ncntt(jproc-1)
      end do
    
      !print *,'iproc,comms',iproc,comms%ncntd,comms%ndspld,comms%ncntt,comms%ndsplt
    
      call f_free(nvctr_par)
      call f_free(norb_par)
      call f_free(mykpts)
    
      !calculate the dimension of the wavefunction
      !for the given processor (this is only the cubic strategy)
      orbs%npsidim_orbs=(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%norb_par(iproc,0)*orbs%nspinor
      orbs%npsidim_comp=sum(comms%ncntt(0:nproc-1))
        
    !!$  orbs%npsidim=max((lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*orbs%norb_par(iproc,0)*orbs%nspinor,&
    !!$       sum(comms%ncntt(0:nproc-1)))
    
    END SUBROUTINE orbitals_communicators



end module communications_init
