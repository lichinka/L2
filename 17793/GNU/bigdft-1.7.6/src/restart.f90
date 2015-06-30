!> @file
!!  Routines to do restart of the calculation
!! @author
!!    Copyright (C) 2007-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!> Copy old wavefunctions from psi to psi_old
subroutine copy_old_wavefunctions(nproc,orbs,psi,&
     wfd_old,psi_old)
  use module_base
  use module_types
  use yaml_output
  implicit none
  integer, intent(in) :: nproc
  type(orbitals_data), intent(in) :: orbs
  type(wavefunctions_descriptors), intent(in) :: wfd_old
  real(wp), dimension(:), pointer :: psi,psi_old
  !Local variables
  character(len=*), parameter :: subname='copy_old_wavefunctions'
  !real(kind=8), parameter :: eps_mach=1.d-12
  integer :: iseg,j,ind1,iorb,oidx,sidx !n(c) nvctrp_old
  real(kind=8) :: tt
  call f_routine(id=subname)

  !add the number of distributed point for the compressed wavefunction
  !tt=dble(wfd_old%nvctr_c+7*wfd_old%nvctr_f)/dble(nproc)
  !n(c) nvctrp_old=int((1.d0-eps_mach*tt) + tt)

!  psi_old=&
!       f_malloc_ptr((wfd_old%nvctr_c+7*wfd_old%nvctr_f)*orbs%norbp*orbs%nspinor,!&
!       id='psi_old')
  psi_old = f_malloc_ptr((wfd_old%nvctr_c+7*wfd_old%nvctr_f)*orbs%norbp*orbs%nspinor,id='psi_old')

  do iorb=1,orbs%norbp
     tt=0.d0
     oidx=(iorb-1)*orbs%nspinor+1
     do sidx=oidx,oidx+orbs%nspinor-1
        do j=1,wfd_old%nvctr_c+7*wfd_old%nvctr_f
           ind1=j+(wfd_old%nvctr_c+7*wfd_old%nvctr_f)*(sidx-1)
           psi_old(ind1)= psi(ind1)
           tt=tt+real(psi(ind1),kind=8)**2
        enddo
     end do

     tt=sqrt(tt)
     if (abs(tt-1.d0) > 1.d-8) then
        call yaml_warning('wrong psi_old' // trim(yaml_toa(iorb)) // trim(yaml_toa(tt)))
        !write(*,*)'wrong psi_old',iorb,tt
        stop 
     end if
  enddo
  !deallocation
  call f_free_ptr(psi)

  call f_release_routine()

END SUBROUTINE copy_old_wavefunctions


!> Reformat wavefunctions if the mesh have changed (in a restart)
subroutine reformatmywaves(iproc,orbs,at,&
     hx_old,hy_old,hz_old,n1_old,n2_old,n3_old,rxyz_old,wfd_old,psi_old,&
     hx,hy,hz,n1,n2,n3,rxyz,wfd,psi)
  use module_base
  use module_types
  use yaml_output
  implicit none
  integer, intent(in) :: iproc,n1_old,n2_old,n3_old,n1,n2,n3
  real(gp), intent(in) :: hx_old,hy_old,hz_old,hx,hy,hz
  type(wavefunctions_descriptors), intent(in) :: wfd,wfd_old
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz,rxyz_old
  real(wp), dimension(wfd_old%nvctr_c+7*wfd_old%nvctr_f,orbs%nspinor*orbs%norbp), intent(in) :: psi_old
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,orbs%nspinor*orbs%norbp), intent(out) :: psi
  !Local variables
  character(len=*), parameter :: subname='reformatmywaves'
  logical :: reformat,perx,pery,perz
  integer :: iat,iorb,j,jj,j0,j1,ii,i0,i1,i2,i3,i,iseg,nb1,nb2,nb3,nvctrcj,n1p1,np,i0jj
  real(gp) :: tx,ty,tz,displ,mindist
  real(wp), dimension(:,:,:), allocatable :: psifscf
  real(wp), dimension(:,:,:,:,:,:), allocatable :: psigold

  !conditions for periodicity in the three directions
  perx=(at%astruct%geocode /= 'F')
  pery=(at%astruct%geocode == 'P')
  perz=(at%astruct%geocode /= 'F')

  !buffers related to periodicity
  !WARNING: the boundary conditions are not assumed to change between new and old
  call ext_buffers_coarse(perx,nb1)
  call ext_buffers_coarse(pery,nb2)
  call ext_buffers_coarse(perz,nb3)


  psifscf = f_malloc((/ -nb1.to.2*n1+1+nb1, -nb2.to.2*n2+1+nb2, -nb3.to.2*n3+1+nb3 /),id='psifscf')

  tx=0.0_gp 
  ty=0.0_gp
  tz=0.0_gp

  do iat=1,at%astruct%nat
     tx=tx+mindist(perx,at%astruct%cell_dim(1),rxyz(1,iat),rxyz_old(1,iat))**2
     ty=ty+mindist(pery,at%astruct%cell_dim(2),rxyz(2,iat),rxyz_old(2,iat))**2
     tz=tz+mindist(perz,at%astruct%cell_dim(3),rxyz(3,iat),rxyz_old(3,iat))**2
  enddo
  displ=sqrt(tx+ty+tz)
!  write(100+iproc,*) 'displacement',dis
!  write(100+iproc,*) 'rxyz ',rxyz
!  write(100+iproc,*) 'rxyz_old ',rxyz_old

  !reformatting criterion
  if (hx == hx_old .and. hy == hy_old .and. hz == hz_old .and. &
       wfd_old%nvctr_c  == wfd%nvctr_c .and. wfd_old%nvctr_f == wfd%nvctr_f .and.&
       n1_old  == n1  .and. n2_old == n2 .and. n3_old == n3  .and.  displ <  1.d-3  ) then
     reformat=.false.
     if (iproc==0) then
        call yaml_map('Reformating Wavefunctions',.false.)
      !write(*,'(1x,a)',advance='NO') 'The wavefunctions do not need reformatting and can be imported directly...'
      !  '-------------------------------------------------------------- Wavefunctions Restart'
     end if
  else
     reformat=.true.
     if (iproc==0) then
        call yaml_map('Reformating wavefunctions',.true.)
        call yaml_mapping_open('Reformatting for')
        !write(*,'(1x,a)') 'The wavefunctions need reformatting because:'
        if (hx /= hx_old .or. hy /= hy_old .or. hz /= hz_old) then 
           call yaml_mapping_open('hgrid modified',flow=.true.)
              call yaml_map('hgrid_old', (/ hx_old,hy_old,hz_old /),fmt='(1pe20.12)')
              call yaml_map('hgrid', (/ hx,hy,hz /), fmt='(1pe20.12)')
           call yaml_mapping_close()
           !write(*,"(4x,a,6(1pe20.12))") 'hgrid_old /= hgrid  ',hx_old,hy_old,hz_old,hx,hy,hz
        else if (wfd_old%nvctr_c /= wfd%nvctr_c) then
           call yaml_map('nvctr_c modified', (/ wfd_old%nvctr_c,wfd%nvctr_c /))
           !write(*,"(4x,a,2i8)") 'nvctr_c_old /= nvctr_c',wfd_old%nvctr_c,wfd%nvctr_c
        else if (wfd_old%nvctr_f /= wfd%nvctr_f)  then
           call yaml_map('nvctr_f modified', (/ wfd_old%nvctr_f,wfd%nvctr_f /))
           !write(*,"(4x,a,2i8)") 'nvctr_f_old /= nvctr_f',wfd_old%nvctr_f,wfd%nvctr_f
        else if (n1_old /= n1  .or. n2_old /= n2 .or. n3_old /= n3 )  then  
           call yaml_map('Cell size has changed ', (/ n1_old,n1  , n2_old,n2 , n3_old,n3 /))
           !write(*,"(4x,a,6i5)") 'cell size has changed ',n1_old,n1  , n2_old,n2 , n3_old,n3
        else
           call yaml_map('Molecule was shifted' ,  (/ tx,ty,tz /), fmt='(1pe19.12)')
           !write(*,"(4x,a,3(1pe19.12))") 'molecule was shifted  ' , tx,ty,tz
        endif
        !write(*,"(1x,a)",advance='NO') 'Reformatting...'
        call yaml_mapping_close()
     end if
     !calculate the new grid values
     
!check
!        write(100+iproc,'(1x,a)') 'The wavefunctions need reformatting because:'
!        if (hgrid_old.ne.hgrid) then 
!           write(100+iproc,"(4x,a,1pe20.12)") &
!                '  hgrid_old /= hgrid  ',hgrid_old, hgrid
!        else if (wfd_old%nvctr_c.ne.wfd%nvctr_c) then
!           write(100+iproc,"(4x,a,2i8)") &
!                'nvctr_c_old /= nvctr_c',wfd_old%nvctr_c,wfd%nvctr_c
!        else if (wfd_old%nvctr_f.ne.wfd%nvctr_f)  then
!           write(100+iproc,"(4x,a,2i8)") &
!                'nvctr_f_old /= nvctr_f',wfd_old%nvctr_f,wfd%nvctr_f
!        else if (n1_old.ne.n1  .or. n2_old.ne.n2 .or. n3_old.ne.n3 )  then  
!           write(100+iproc,"(4x,a,6i5)") &
!                'cell size has changed ',n1_old,n1  , n2_old,n2 , n3_old,n3
!        else
!           write(100+iproc,"(4x,a,3(1pe19.12))") &
!                'molecule was shifted  ' , tx,ty,tz
!        endif
!checkend
  end if

  do iorb=1,orbs%norbp*orbs%nspinor

     if (.not. reformat) then
        !write(100+iproc,*) 'no reformatting' 

        do j=1,wfd_old%nvctr_c
           psi(j,iorb)=psi_old(j, iorb)
        enddo
        do j=1,7*wfd_old%nvctr_f-6,7
           nvctrcj=wfd%nvctr_c+j
           psi(nvctrcj+0,iorb)=psi_old(nvctrcj+0,iorb)
           psi(nvctrcj+1,iorb)=psi_old(nvctrcj+1,iorb)
           psi(nvctrcj+2,iorb)=psi_old(nvctrcj+2,iorb)
           psi(nvctrcj+3,iorb)=psi_old(nvctrcj+3,iorb)
           psi(nvctrcj+4,iorb)=psi_old(nvctrcj+4,iorb)
           psi(nvctrcj+5,iorb)=psi_old(nvctrcj+5,iorb)
           psi(nvctrcj+6,iorb)=psi_old(nvctrcj+6,iorb)
        enddo

     else

        psigold = f_malloc((/ 0.to.n1_old, 1.to.2, 0.to.n2_old, 1.to.2, 0.to.n3_old, 1.to.2 /),id='psigold')

        call to_zero(8*(n1_old+1)*(n2_old+1)*(n3_old+1),psigold)

        n1p1=n1_old+1
        np=n1p1*(n2_old+1)
        ! coarse part
        do iseg=1,wfd_old%nseg_c
           jj=wfd_old%keyvloc(iseg)
           j0=wfd_old%keygloc(1,iseg)
           j1=wfd_old%keygloc(2,iseg)
           ii=j0-1
           i3=ii/np
           ii=ii-i3*np
           i2=ii/n1p1
           i0=ii-i2*n1p1
           i1=i0+j1-j0
           i0jj=jj-i0
           do i=i0,i1
              psigold(i,1,i2,1,i3,1) = psi_old(i+i0jj,iorb)
           enddo
        enddo

        ! fine part
        do iseg=1,wfd_old%nseg_f
           jj=wfd_old%keyvloc(wfd_old%nseg_c + iseg)
           j0=wfd_old%keygloc(1,wfd_old%nseg_c + iseg)
           j1=wfd_old%keygloc(2,wfd_old%nseg_c + iseg)
           ii=j0-1
           i3=ii/np
           ii=ii-i3*np
           i2=ii/n1p1
           i0=ii-i2*n1p1
           i1=i0+j1-j0
           i0jj=jj-i0-1
           do i=i0,i1
              psigold(i,2,i2,1,i3,1)=psi_old(wfd_old%nvctr_c+1+7*(i+i0jj), iorb)
              psigold(i,1,i2,2,i3,1)=psi_old(wfd_old%nvctr_c+2+7*(i+i0jj), iorb)
              psigold(i,2,i2,2,i3,1)=psi_old(wfd_old%nvctr_c+3+7*(i+i0jj), iorb)
              psigold(i,1,i2,1,i3,2)=psi_old(wfd_old%nvctr_c+4+7*(i+i0jj), iorb)
              psigold(i,2,i2,1,i3,2)=psi_old(wfd_old%nvctr_c+5+7*(i+i0jj), iorb)
              psigold(i,1,i2,2,i3,2)=psi_old(wfd_old%nvctr_c+6+7*(i+i0jj), iorb)
              psigold(i,2,i2,2,i3,2)=psi_old(wfd_old%nvctr_c+7+7*(i+i0jj), iorb)
           enddo
        enddo

!write(100+iproc,*) 'norm psigold ',dnrm2(8*(n1_old+1)*(n2_old+1)*(n3_old+1),psigold,1)

        call reformatonewave(displ,wfd,at,hx_old,hy_old,hz_old, & !n(m)
             n1_old,n2_old,n3_old,rxyz_old,psigold,hx,hy,hz,&
             n1,n2,n3,rxyz,psifscf,psi(1,iorb))

        call f_free(psigold)
     end if
  end do

  call f_free(psifscf)

  !if (iproc==0) write(*,"(1x,a)")'done.'

END SUBROUTINE reformatmywaves


integer function wave_format_from_filename(iproc, filename)
  use module_types
  use yaml_output
  implicit none
  integer, intent(in) :: iproc
  character(len=*), intent(in) :: filename

  integer :: isuffix

  wave_format_from_filename = WF_FORMAT_NONE

  isuffix = index(filename, ".etsf", back = .true.)
  if (isuffix > 0) then
     wave_format_from_filename = WF_FORMAT_ETSF
     if (iproc ==0) call yaml_comment('Reading wavefunctions in ETSF file format.')
     !if (iproc ==0) write(*,*) "Reading wavefunctions in ETSF file format."
  else
     isuffix = index(filename, ".bin", back = .true.)
     if (isuffix > 0) then
        wave_format_from_filename = WF_FORMAT_BINARY
        if (iproc ==0) call yaml_comment('Reading wavefunctions in BigDFT binary file format.')
        !if (iproc ==0) write(*,*) "Reading wavefunctions in BigDFT binary file format."
     else
        wave_format_from_filename = WF_FORMAT_PLAIN
        if (iproc ==0) call yaml_comment('Reading wavefunctions in plain text file format.')
        !if (iproc ==0) write(*,*) "Reading wavefunctions in plain text file format."
     end if
  end if
end function wave_format_from_filename


!> Reads wavefunction from file and transforms it properly if hgrid or size of simulation cell
!!  have changed
subroutine readmywaves(iproc,filename,iformat,orbs,n1,n2,n3,hx,hy,hz,at,rxyz_old,rxyz,  & 
     wfd,psi,orblist)
  use module_base
  use module_types
  use yaml_output
  use module_interfaces, except_this_one => readmywaves
  implicit none
  integer, intent(in) :: iproc,n1,n2,n3, iformat
  real(gp), intent(in) :: hx,hy,hz
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(orbitals_data), intent(inout) :: orbs
  type(atoms_data), intent(in) :: at
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz
  real(gp), dimension(3,at%astruct%nat), intent(out) :: rxyz_old
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,orbs%nspinor,orbs%norbp), intent(out) :: psi
  character(len=*), intent(in) :: filename
  integer, dimension(orbs%norb), optional :: orblist
  !Local variables
  character(len=*), parameter :: subname='readmywaves'
  logical :: perx,pery,perz
  integer :: ncount1,ncount_rate,ncount_max,iorb,ncount2,nb1,nb2,nb3,iorb_out,ispinor
  real(kind=4) :: tr0,tr1
  real(kind=8) :: tel
  real(wp), dimension(:,:,:), allocatable :: psifscf
  !integer, dimension(orbs%norb) :: orblist2

  call cpu_time(tr0)
  call system_clock(ncount1,ncount_rate,ncount_max)

  if (iformat == WF_FORMAT_ETSF) then
     !construct the orblist or use the one in argument
     !do nb1 = 1, orbs%norb
     !orblist2(nb1) = nb1
     !if(present(orblist)) orblist2(nb1) = orblist(nb1) 
     !end do

     call read_waves_etsf(iproc,filename // ".etsf",orbs,n1,n2,n3,hx,hy,hz,at,rxyz_old,rxyz,  & 
          wfd,psi)
  else if (iformat == WF_FORMAT_BINARY .or. iformat == WF_FORMAT_PLAIN) then
     !conditions for periodicity in the three directions
     perx=(at%astruct%geocode /= 'F')
     pery=(at%astruct%geocode == 'P')
     perz=(at%astruct%geocode /= 'F')

     !buffers related to periodicity
     !WARNING: the boundary conditions are not assumed to change between new and old
     call ext_buffers_coarse(perx,nb1)
     call ext_buffers_coarse(pery,nb2)
     call ext_buffers_coarse(perz,nb3)

     psifscf = f_malloc((/ -nb1.to.2*n1+1+nb1, -nb2.to.2*n2+1+nb2, -nb3.to.2*n3+1+nb3 /),id='psifscf')

     do iorb=1,orbs%norbp!*orbs%nspinor

!!$        write(f4,'(i4.4)') iorb+orbs%isorb*orbs%nspinor
!!$        if (exists) then
!!$           filename_ = filename//".bin."//f4
!!$           open(unit=99,file=filename_,status='unknown',form="unformatted")
!!$        else
!!$           filename_ = trim(filename)//"."//f4
!!$           open(unit=99,file=trim(filename_),status='unknown')
!!$        end if
!!$           call readonewave(99, .not.exists,iorb+orbs%isorb*orbs%nspinor,iproc,n1,n2,n3, &
!!$                & hx,hy,hz,at,wfd,rxyz_old,rxyz,&
!!$                psi(1,iorb),orbs%eval((iorb-1)/orbs%nspinor+1+orbs%isorb),psifscf)
        !print *,"filename = ", filename
        do ispinor=1,orbs%nspinor
           if(present(orblist)) then
              call open_filename_of_iorb(99,(iformat == WF_FORMAT_BINARY),filename, &
                   & orbs,iorb,ispinor,iorb_out, orblist(iorb+orbs%isorb))
           else
              call open_filename_of_iorb(99,(iformat == WF_FORMAT_BINARY),filename, &
                   & orbs,iorb,ispinor,iorb_out)
           end if           
           call readonewave(99, (iformat == WF_FORMAT_PLAIN),iorb_out,iproc,n1,n2,n3, &
                & hx,hy,hz,at,wfd,rxyz_old,rxyz,&
                psi(1,ispinor,iorb),orbs%eval(orbs%isorb+iorb),psifscf)
           close(99)
        end do
!!$        do i_all=1,wfd%nvctr_c+7*wfd%nvctr_f
!!$            write(700+iorb,*) i_all, psi(i_all,1,iorb)
!!$        end do

     end do

     call f_free(psifscf)

  else
     call yaml_warning('Unknown wavefunction file format from filename.')
     stop
  end if

  call cpu_time(tr1)
  call system_clock(ncount2,ncount_rate,ncount_max)
  tel=dble(ncount2-ncount1)/dble(ncount_rate)


  if (iproc == 0) then 
     call yaml_sequence_open('Reading Waves Time')
     call yaml_sequence(advance='no')
     call yaml_mapping_open(flow=.true.)
     call yaml_map('Process',iproc)
     call yaml_map('Timing',(/ real(tr1-tr0,kind=8),tel /),fmt='(1pe10.3)')
     call yaml_mapping_close()
     call yaml_sequence_close()
  end if
  !write(*,'(a,i4,2(1x,1pe10.3))') '- READING WAVES TIME',iproc,tr1-tr0,tel
END SUBROUTINE readmywaves


!> Verify the presence of a given file
subroutine verify_file_presence(filerad,orbs,iformat,nproc,nforb)
  use module_base
  use module_types
  use module_interfaces, except_this_one => verify_file_presence
  implicit none
  integer, intent(in) :: nproc
  character(len=*), intent(in) :: filerad
  type(orbitals_data), intent(in) :: orbs
  integer, intent(out) :: iformat
  integer, optional, intent(in) :: nforb
  !local variables
  character(len=500) :: filename
  logical :: onefile,allfiles
  integer :: iorb,ispinor,iorb_out
  
  allfiles=.true.

  !first try with plain files
  loop_plain: do iorb=1,orbs%norbp
     do ispinor=1,orbs%nspinor
        call filename_of_iorb(.false.,trim(filerad),orbs,iorb,ispinor,filename,iorb_out)
        inquire(file=filename,exist=onefile)
        ! for fragment calculations, this number could be less than the number of orbs - find a better way of doing this
        if (.not. present(nforb)) then
           allfiles=allfiles .and. onefile
        else if (iorb_out<=nforb) then
           allfiles=allfiles .and. onefile
        end if
        if (.not. allfiles) then
           exit loop_plain
        end if
     end do
  end do loop_plain
  !reduce the result among the other processors
  if (nproc > 1) call mpiallred(allfiles,1,MPI_LAND,bigdft_mpi%mpi_comm)
 
  if (allfiles) then
     iformat=WF_FORMAT_PLAIN
     return
  end if

  !Otherwise  test binary files.
  allfiles = .true.
  loop_binary: do iorb=1,orbs%norbp
     do ispinor=1,orbs%nspinor
        call filename_of_iorb(.true.,trim(filerad),orbs,iorb,ispinor,filename,iorb_out)

        inquire(file=filename,exist=onefile)
        ! for fragment calculations, this number could be less than the number of orbs - find a better way of doing this
        if (.not. present(nforb)) then
           allfiles=allfiles .and. onefile
        else if (iorb_out<=nforb) then
           allfiles=allfiles .and. onefile
        end if
        if (.not. allfiles) then
           exit loop_binary
        end if

     end do
  end do loop_binary
  !reduce the result among the other processors
  if (nproc > 1) call mpiallred(allfiles,1,MPI_LAND,bigdft_mpi%mpi_comm)

  if (allfiles) then
     iformat=WF_FORMAT_BINARY
     return
  end if

  !otherwise, switch to normal input guess
  iformat=WF_FORMAT_NONE

end subroutine verify_file_presence


!> Associate to the absolute value of orbital a filename which depends of the k-point and 
!! of the spin sign
subroutine filename_of_iorb(lbin,filename,orbs,iorb,ispinor,filename_out,iorb_out,iiorb)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename
  logical, intent(in) :: lbin
  integer, intent(in) :: iorb,ispinor
  type(orbitals_data), intent(in) :: orbs
  character(len=*) :: filename_out
  integer, intent(out) :: iorb_out
  integer, intent(in), optional :: iiorb
  !local variables
  character(len=1) :: spintype,realimag
  character(len=4) :: f3
  character(len=5) :: f4
  character(len=8) :: completename
  integer :: ikpt
  real(gp) :: spins

  !calculate k-point
  ikpt=orbs%iokpt(iorb)
  write(f3,'(a1,i3.3)') "k", ikpt !not more than 999 kpts

  !see if the wavefunction is real or imaginary
  if(modulo(ispinor,2)==0) then
     realimag='I'
  else
     realimag='R'
  end if
  !calculate the spin sector
  spins=orbs%spinsgn(orbs%isorb+iorb)
  if(orbs%nspinor == 4) then
     if (ispinor <=2) then
        spintype='A'
     else
        spintype='B'
     end if
  else
     if (spins==1.0_gp) then
        spintype='U'
     else
        spintype='D'
     end if
  end if
  !no spin polarization if nspin=1
  if (orbs%nspin==1) spintype='N'

  !calculate the actual orbital value
  iorb_out=iorb+orbs%isorb-(ikpt-1)*orbs%norb
  !print *,"iorb_out (filename_of_iorb) = ", iorb_out
  !print *,"ikpt (filename_of_iorb) = ", ikpt
  !print *,"orbs%isorb (filename_of_iorb) = ", orbs%isorb

  if(present(iiorb)) iorb_out = iiorb
  !purge the value from the spin sign
  if (spins==-1.0_gp) iorb_out=iorb_out-orbs%norbu

  !value of the orbital 
  write(f4,'(a1,i4.4)') "b", iorb_out

  !complete the information in the name of the orbital
  completename='-'//f3//'-'//spintype//realimag
  if (lbin) then
     filename_out = trim(filename)//completename//".bin."//f4
     !print *,'complete name <',trim(filename_out),'> end'
 else
     filename_out = trim(filename)//completename//"."//f4
     !print *,'complete name <',trim(filename_out),'> end'
 end if

  !print *,'filename: ',filename_out
end subroutine filename_of_iorb


!> Associate to the absolute value of orbital a filename which depends of the k-point and 
!! of the spin sign
subroutine open_filename_of_iorb(unitfile,lbin,filename,orbs,iorb,ispinor,iorb_out,iiorb)
  use module_base
  use module_types
  use module_interfaces, except_this_one => open_filename_of_iorb
  implicit none
  character(len=*), intent(in) :: filename
  logical, intent(in) :: lbin
  integer, intent(in) :: iorb,ispinor,unitfile
  type(orbitals_data), intent(in) :: orbs
  integer, intent(out) :: iorb_out
  integer, intent(in), optional :: iiorb
  !local variables
  character(len=500) :: filename_out

  if(present(iiorb)) then   
     call filename_of_iorb(lbin,filename,orbs,iorb,ispinor,filename_out,iorb_out,iiorb)
     !restore previous behaviour even though the wannier construction can be compromised
     !call filename_of_iorb(lbin,filename,orbs,iorb,ispinor,filename_out,iorb_out) 
  else
     call filename_of_iorb(lbin,filename,orbs,iorb,ispinor,filename_out,iorb_out)
  end if
  if (lbin) then
     open(unit=unitfile,file=trim(filename_out),status='unknown',form="unformatted")
  else
     open(unit=unitfile,file=trim(filename_out),status='unknown')
  end if

end subroutine open_filename_of_iorb


!> Write all my wavefunctions in files by calling writeonewave
subroutine writemywaves(iproc,filename,iformat,orbs,n1,n2,n3,hx,hy,hz,at,rxyz,wfd,psi)
  use module_types
  use module_base
  use yaml_output
  use module_interfaces, except_this_one => writeonewave, except_this_one_A => writemywaves
  implicit none
  integer, intent(in) :: iproc,n1,n2,n3,iformat
  real(gp), intent(in) :: hx,hy,hz
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  type(wavefunctions_descriptors), intent(in) :: wfd
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,orbs%nspinor,orbs%norbp), intent(in) :: psi
  character(len=*), intent(in) :: filename
  !Local variables
  integer :: ncount1,ncount_rate,ncount_max,iorb,ncount2,iorb_out,ispinor
  real(kind=4) :: tr0,tr1
  real(kind=8) :: tel

  if (iproc == 0) call yaml_map('Write wavefunctions to file', trim(filename) // '.*')
  !if (iproc == 0) write(*,"(1x,A,A,a)") "Write wavefunctions to file: ", trim(filename),'.*'
  if (iformat == WF_FORMAT_ETSF) then
     call write_waves_etsf(iproc,filename,orbs,n1,n2,n3,hx,hy,hz,at,rxyz,wfd,psi)
  else
     call cpu_time(tr0)
     call system_clock(ncount1,ncount_rate,ncount_max)

     ! Plain BigDFT files.
     do iorb=1,orbs%norbp
        do ispinor=1,orbs%nspinor
           call open_filename_of_iorb(99,(iformat == WF_FORMAT_BINARY),filename, &
                & orbs,iorb,ispinor,iorb_out)           
           call writeonewave(99,(iformat == WF_FORMAT_PLAIN),iorb_out,n1,n2,n3,hx,hy,hz, &
                at%astruct%nat,rxyz,wfd%nseg_c,wfd%nvctr_c,wfd%keygloc(1,1),wfd%keyvloc(1),  & 
                wfd%nseg_f,wfd%nvctr_f,wfd%keygloc(1,wfd%nseg_c+1),wfd%keyvloc(wfd%nseg_c+1), & 
                psi(1,ispinor,iorb),psi(wfd%nvctr_c+1,ispinor,iorb), &
                orbs%eval(iorb+orbs%isorb))
           close(99)
        end do
     enddo

     call cpu_time(tr1)
     call system_clock(ncount2,ncount_rate,ncount_max)
     tel=dble(ncount2-ncount1)/dble(ncount_rate)
     if (iproc == 0) then
        call yaml_sequence_open('Write Waves Time')
        call yaml_sequence(advance='no')
        call yaml_mapping_open(flow=.true.)
        call yaml_map('Process',iproc)
        call yaml_map('Timing',(/ real(tr1-tr0,kind=8),tel /),fmt='(1pe10.3)')
        call yaml_mapping_close()
        call yaml_sequence_close()
     end if
     !write(*,'(a,i4,2(1x,1pe10.3))') '- WRITE WAVES TIME',iproc,tr1-tr0,tel
     !write(*,'(a,1x,i0,a)') '- iproc',iproc,' finished writing waves'
  end if

END SUBROUTINE writemywaves


subroutine read_wave_to_isf(lstat, filename, ln, iorbp, hx, hy, hz, &
     & n1, n2, n3, nspinor, psiscf)
  use module_base
  use module_types
  use module_interfaces, except_this_one => read_wave_to_isf

  implicit none

  integer, intent(in) :: ln
  character, intent(in) :: filename(ln)
  integer, intent(in) :: iorbp
  integer, intent(out) :: n1, n2, n3, nspinor
  real(gp), intent(out) :: hx, hy, hz
  real(wp), dimension(:,:,:,:), pointer :: psiscf
  logical, intent(out) :: lstat

  character(len = 1024) :: filename_
  integer :: wave_format_from_filename, iformat, i
  
  write(filename_, "(A)") " "
  do i = 1, ln, 1
     filename_(i:i) = filename(i)
  end do

  ! Find format from name.
  iformat = wave_format_from_filename(1, trim(filename_))

  ! Call proper wraping routine.
  if (iformat == WF_FORMAT_ETSF) then
     call readwavetoisf_etsf(lstat, trim(filename_), iorbp, hx, hy, hz, &
          & n1, n2, n3, nspinor, psiscf)
  else
     call readwavetoisf(lstat, trim(filename_), (iformat == WF_FORMAT_PLAIN), hx, hy, hz, &
          & n1, n2, n3, nspinor, psiscf)
  end if
END SUBROUTINE read_wave_to_isf


!!$subroutine free_wave_to_isf(psiscf)
!!$  use module_base
!!$  implicit none
!!$  real(wp), dimension(:,:,:,:), pointer :: psiscf
!!$
!!$  integer :: i_all, i_stat
!!$
!!$  i_all=-product(shape(psiscf))*kind(psiscf)
!!$  deallocate(psiscf,stat=i_stat)
!!$  call memocc(i_stat,i_all,'psiscf',"free_wave_to_isf_etsf")
!!$END SUBROUTINE free_wave_to_isf


subroutine read_wave_descr(lstat, filename, ln, &
     & norbu, norbd, iorbs, ispins, nkpt, ikpts, nspinor, ispinor)
  use module_types
  implicit none
  integer, intent(in) :: ln
  character, intent(in) :: filename(ln)
  integer, intent(out) :: norbu, norbd, nkpt, nspinor
  integer, intent(out) :: iorbs, ispins, ikpts, ispinor
  logical, intent(out) :: lstat

  character(len = 1024) :: filename_
  integer :: wave_format_from_filename, iformat, i
  character(len = 1024) :: testf
  
  write(filename_, "(A)") " "
  do i = 1, ln, 1
     filename_(i:i) = filename(i)
  end do

  ! Find format from name.
  iformat = wave_format_from_filename(1, trim(filename_))

  ! Call proper wraping routine.
  if (iformat == WF_FORMAT_ETSF) then
     call readwavedescr_etsf(lstat, trim(filename_), norbu, norbd, nkpt, nspinor)
     iorbs = 1
     ispins = 1
     ikpts = 1
     ispinor = 1
  else
     call readwavedescr(lstat, trim(filename_), iorbs, ispins, ikpts, ispinor, nspinor, testf)
     norbu = 0
     norbd = 0
     nkpt = 0
  end if
END SUBROUTINE read_wave_descr


subroutine writeonewave_linear(unitwf,useFormattedOutput,iorb,n1,n2,n3,ns1,ns2,ns3,hx,hy,hz,locregCenter,&
     locrad,confPotOrder,confPotprefac,nat,rxyz, nseg_c,nvctr_c,keyg_c,keyv_c,  &
     nseg_f,nvctr_f,keyg_f,keyv_f, &
     psi_c,psi_f,eval,onwhichatom)
  use module_base
  use yaml_output
  implicit none
  logical, intent(in) :: useFormattedOutput
  integer, intent(in) :: unitwf,iorb,n1,n2,n3,ns1,ns2,ns3,nat,nseg_c,nvctr_c,nseg_f,nvctr_f,confPotOrder
  real(gp), intent(in) :: hx,hy,hz,locrad,confPotprefac
  real(wp), intent(in) :: eval
  integer, dimension(nseg_c), intent(in) :: keyv_c
  integer, dimension(nseg_f), intent(in) :: keyv_f
  integer, dimension(2,nseg_c), intent(in) :: keyg_c
  integer, dimension(2,nseg_f), intent(in) :: keyg_f
  real(wp), dimension(nvctr_c), intent(in) :: psi_c
  real(wp), dimension(7,nvctr_f), intent(in) :: psi_f
  real(gp), dimension(3,nat), intent(in) :: rxyz
  real(gp), dimension(3), intent(in) :: locregCenter
  integer, intent(in) :: onwhichatom
  !local variables
  integer :: iat,jj,j0,j1,ii,i0,i1,i2,i3,i,iseg,j,np,n1p1
  real(wp) :: tt,t1,t2,t3,t4,t5,t6,t7

  if (useFormattedOutput) then
     write(unitwf,*) iorb,eval
     write(unitwf,*) hx,hy,hz
     write(unitwf,*) n1,n2,n3
     write(unitwf,*) ns1,ns2,ns3
     write(unitwf,*) locregCenter(1),locregCenter(2),locregCenter(3),onwhichatom,locrad,&
          confPotOrder,confPotprefac
     write(unitwf,*) nat
     do iat=1,nat
        write(unitwf,'(3(1x,e24.17))') (rxyz(j,iat),j=1,3)
     enddo
     write(unitwf,*) nvctr_c, nvctr_f
  else
     write(unitwf) iorb,eval
     write(unitwf) hx,hy,hz
     write(unitwf) n1,n2,n3
     write(unitwf) ns1,ns2,ns3
     write(unitwf) locregCenter(1),locregCenter(2),locregCenter(3),onwhichatom,locrad,&
          confPotOrder,confPotprefac
     write(unitwf) nat
     do iat=1,nat
        write(unitwf) (rxyz(j,iat),j=1,3)
     enddo
     write(unitwf) nvctr_c, nvctr_f
  end if

  n1p1=n1+1
  np=n1p1*(n2+1)

  ! coarse part
  do iseg=1,nseg_c
     jj=keyv_c(iseg)
     j0=keyg_c(1,iseg)
     j1=keyg_c(2,iseg)
     ii=j0-1
     i3=ii/np
     ii=ii-i3*np
     i2=ii/n1p1
     i0=ii-i2*n1p1
     i1=i0+j1-j0
     do i=i0,i1
        tt=psi_c(i-i0+jj)
        if (useFormattedOutput) then
           write(unitwf,'(3(i4),1x,e19.12)') i,i2,i3,tt
        else
           write(unitwf) i,i2,i3,tt
        end if
     enddo
  enddo

  ! fine part
  do iseg=1,nseg_f
     jj=keyv_f(iseg)
     j0=keyg_f(1,iseg)
     j1=keyg_f(2,iseg)
     ii=j0-1
     i3=ii/np
     ii=ii-i3*np
     i2=ii/n1p1
     i0=ii-i2*n1p1
     i1=i0+j1-j0
     do i=i0,i1
        t1=psi_f(1,i-i0+jj)
        t2=psi_f(2,i-i0+jj)
        t3=psi_f(3,i-i0+jj)
        t4=psi_f(4,i-i0+jj)
        t5=psi_f(5,i-i0+jj)
        t6=psi_f(6,i-i0+jj)
        t7=psi_f(7,i-i0+jj)
        if (useFormattedOutput) then
           write(unitwf,'(3(i4),7(1x,e17.10))') i,i2,i3,t1,t2,t3,t4,t5,t6,t7
        else
           write(unitwf) i,i2,i3,t1,t2,t3,t4,t5,t6,t7
        end if
     enddo
  enddo

  if (verbose >= 2 .and. bigdft_mpi%iproc==0) call yaml_map('Wavefunction written No.',iorb)
  !if (verbose >= 2) write(*,'(1x,i0,a)') iorb,'th wavefunction written'

END SUBROUTINE writeonewave_linear


subroutine writeLinearCoefficients(unitwf,useFormattedOutput,nat,rxyz,&
           ntmb,norb,coeff,eval)
  use module_base
  use yaml_output
  implicit none
  logical, intent(in) :: useFormattedOutput
  integer, intent(in) :: unitwf,nat,ntmb,norb
  real(wp), dimension(ntmb,ntmb), intent(in) :: coeff
  real(wp), dimension(ntmb), intent(in) :: eval
  real(gp), dimension(3,nat), intent(in) :: rxyz
  !local variables
  integer :: iat,i,j,iorb
  real(wp) :: tt

  ! Write the Header
  if (useFormattedOutput) then
     write(unitwf,*) ntmb,norb
     write(unitwf,*) nat
     do iat=1,nat
     write(unitwf,'(3(1x,e24.17))') (rxyz(j,iat),j=1,3)
     enddo
     do iorb=1,ntmb
     write(unitwf,*) iorb,eval(iorb)
     enddo
  else
     write(unitwf) ntmb, norb
     write(unitwf) nat
     do iat=1,nat
     write(unitwf) (rxyz(j,iat),j=1,3)
     enddo
     do iorb=1,ntmb
     write(unitwf) iorb,eval(iorb)
     enddo
  end if

  ! Now write the coefficients
  do i = 1, ntmb
     ! first element always positive, for consistency when using for transfer integrals
     ! unless 1st element below some threshold, in which case first significant element
     do j=1,ntmb
        if (abs(coeff(j,i))>1.0e-1) then
           if (coeff(j,i)<0.0_gp) call dscal(ntmb,-1.0_gp,coeff(1,i),1)
           exit
        end if
     end do
     if (j==ntmb+1) stop 'Error finding significant coefficient!'

     do j = 1, ntmb
          tt = coeff(j,i)
          if (useFormattedOutput) then
             write(unitwf,'(2(i6,1x),e19.12)') i,j,tt
          else
             write(unitwf) i,j,tt
          end if
     end do
  end do  
  if (verbose >= 2 .and. bigdft_mpi%iproc==0) call yaml_map('Wavefunction coefficients written',.true.)

END SUBROUTINE writeLinearCoefficients


!> Write Hamiltonian, overlap and kernel matrices in tmb basis
subroutine write_linear_matrices(iproc,nproc,imethod_overlap,filename,iformat,tmb,at,rxyz)
  use module_types
  use module_base
  use yaml_output
  use module_interfaces, except_this_one => writeonewave
  use sparsematrix_base, only: sparsematrix_malloc_ptr, DENSE_FULL, assignment(=)
  use sparsematrix, only: uncompress_matrix
  implicit none
  integer, intent(in) :: iproc,nproc,imethod_overlap,iformat
  character(len=*), intent(in) :: filename 
  type(DFT_wavefunction), intent(inout) :: tmb
  type(atoms_data), intent(in) :: at
  real(gp),dimension(3,at%astruct%nat),intent(in) :: rxyz

  integer :: ispin, iorb, jorb, iat, jat
  !!integer :: i_stat, i_all
  character(len=*),parameter :: subname='write_linear_matrices'

  if (iproc==0) then
     if(iformat == WF_FORMAT_PLAIN) then
        open(99, file=filename//'hamiltonian.bin', status='unknown',form='formatted')
     else
        open(99, file=filename//'hamiltonian.bin', status='unknown',form='unformatted')
     end if

     tmb%linmat%ham_%matrix = sparsematrix_malloc_ptr(tmb%linmat%m, &
                              iaction=DENSE_FULL, id='tmb%linmat%ham_%matrix')

     call uncompress_matrix(iproc, tmb%linmat%m, &
          inmat=tmb%linmat%ham_%matrix_compr, outmat=tmb%linmat%ham_%matrix)

     do ispin=1,tmb%linmat%m%nspin
        do iorb=1,tmb%linmat%m%nfvctr
           iat=tmb%orbs%onwhichatom(iorb)
           do jorb=1,tmb%linmat%m%nfvctr
              jat=tmb%orbs%onwhichatom(jorb)
              if (iformat == WF_FORMAT_PLAIN) then
                 write(99,'(2(i6,1x),e19.12,2(1x,i6))') iorb,jorb,tmb%linmat%ham_%matrix(iorb,jorb,ispin),iat,jat
              else
                 write(99) iorb,jorb,tmb%linmat%ham_%matrix(iorb,jorb,ispin),iat,jat
              end if
           end do
        end do
     end do

     call f_free_ptr(tmb%linmat%ham_%matrix)

     close(99)

     if(iformat == WF_FORMAT_PLAIN) then
        open(99, file=filename//'overlap.bin', status='unknown',form='formatted')
     else
        open(99, file=filename//'overlap.bin', status='unknown',form='unformatted')
     end if

     !!allocate(tmb%linmat%ovrlp%matrix(tmb%linmat%ovrlp%nfvctr,tmb%linmat%ovrlp%nfvctr), stat=i_stat)
     !!call memocc(i_stat, tmb%linmat%ovrlp%matrix, 'tmb%linmat%ovrlp%matrix', subname)
     tmb%linmat%ovrlp_%matrix = sparsematrix_malloc_ptr(tmb%linmat%s, iaction=DENSE_FULL, &
                                id='tmb%linmat%ovrlp_%matrix')

     call uncompress_matrix(iproc, tmb%linmat%s, &
          inmat=tmb%linmat%ovrlp_%matrix_compr, outmat=tmb%linmat%ovrlp_%matrix)

     do ispin=1,tmb%linmat%s%nspin
        do iorb=1,tmb%linmat%s%nfvctr
           iat=tmb%orbs%onwhichatom(iorb)
           do jorb=1,tmb%linmat%s%nfvctr
              jat=tmb%orbs%onwhichatom(jorb)
              if (iformat == WF_FORMAT_PLAIN) then
                 write(99,'(2(i6,1x),e19.12,2(1x,i6))') iorb,jorb,tmb%linmat%ovrlp_%matrix(iorb,jorb,ispin),iat,jat
              else
                 write(99) iorb,jorb,tmb%linmat%ovrlp_%matrix(iorb,jorb,ispin),iat,jat
              end if
           end do
        end do
     end do

     !!i_all = -product(shape(tmb%linmat%ovrlp%matrix))*kind(tmb%linmat%ovrlp%matrix)
     !!deallocate(tmb%linmat%ovrlp%matrix,stat=i_stat)
     !!call memocc(i_stat,i_all,'tmb%linmat%ovrlp%matrix',subname)
     call f_free_ptr(tmb%linmat%ovrlp_%matrix)


     close(99)

     if(iformat == WF_FORMAT_PLAIN) then
        open(99, file=filename//'density_kernel.bin', status='unknown',form='formatted')
     else
        open(99, file=filename//'density_kernel.bin', status='unknown',form='unformatted')
     end if

     tmb%linmat%kernel_%matrix = sparsematrix_malloc_ptr(tmb%linmat%l,iaction=DENSE_FULL,id='tmb%linmat%kernel_%matrix')


     call uncompress_matrix(iproc,tmb%linmat%l, &
          inmat=tmb%linmat%kernel_%matrix_compr, outmat=tmb%linmat%kernel_%matrix)

     do ispin=1,tmb%linmat%l%nspin
        do iorb=1,tmb%linmat%l%nfvctr
           iat=tmb%orbs%onwhichatom(iorb)
           do jorb=1,tmb%linmat%l%nfvctr
              jat=tmb%orbs%onwhichatom(jorb)
              if (iformat == WF_FORMAT_PLAIN) then
                 write(99,'(2(i6,1x),e19.12,2(1x,i6))') iorb,jorb,tmb%linmat%kernel_%matrix(iorb,jorb,ispin),iat,jat
              else
                 write(99) iorb,jorb,tmb%linmat%kernel_%matrix(iorb,jorb,ispin),iat,jat
              end if
           end do
        end do
     end do

     call f_free_ptr(tmb%linmat%kernel_%matrix)

     close(99)

  end if

  ! calculate 'onsite' overlap matrix as well - needs double checking

  !!allocate(tmb%linmat%ovrlp%matrix(tmb%linmat%ovrlp%nfvctr,tmb%linmat%ovrlp%nfvctr), stat=i_stat)
  !!call memocc(i_stat, tmb%linmat%ovrlp%matrix, 'tmb%linmat%ovrlp%matrix', subname)
  tmb%linmat%ovrlp_%matrix = sparsematrix_malloc_ptr(tmb%linmat%s, iaction=DENSE_FULL, &
                             id='tmb%linmat%ovrlp_%matrix')

  call tmb_overlap_onsite(iproc, nproc, imethod_overlap, at, tmb, rxyz)
  !call tmb_overlap_onsite_rotate(iproc, nproc, at, tmb, rxyz)

  if (iproc==0) then
     if(iformat == WF_FORMAT_PLAIN) then
        open(99, file=filename//'overlap_onsite.bin', status='unknown',form='formatted')
     else
        open(99, file=filename//'overlap_onsite.bin', status='unknown',form='unformatted')
     end if

     do ispin=1,tmb%linmat%l%nspin
        do iorb=1,tmb%linmat%l%nfvctr
           iat=tmb%orbs%onwhichatom(iorb)
           do jorb=1,tmb%linmat%l%nfvctr
              jat=tmb%orbs%onwhichatom(jorb)
              if (iformat == WF_FORMAT_PLAIN) then
                 write(99,'(2(i6,1x),e19.12,2(1x,i6))') iorb,jorb,tmb%linmat%ovrlp_%matrix(iorb,jorb,ispin),iat,jat
              else
                 write(99) iorb,jorb,tmb%linmat%ovrlp_%matrix(iorb,jorb,ispin),iat,jat
              end if
           end do
        end do
     end do

  end if

  close(99)

  !!i_all = -product(shape(tmb%linmat%ovrlp%matrix))*kind(tmb%linmat%ovrlp%matrix)
  !!deallocate(tmb%linmat%ovrlp%matrix,stat=i_stat)
  !!call memocc(i_stat,i_all,'tmb%linmat%ovrlp%matrix',subname)
  call f_free_ptr(tmb%linmat%ovrlp_%matrix)

end subroutine write_linear_matrices


subroutine tmb_overlap_onsite(iproc, nproc, imethod_overlap, at, tmb, rxyz)

  use module_base
  use module_types
  use module_interfaces
  use module_fragments
  use communications_base, only: comms_linear_null, deallocate_comms_linear, TRANSPOSE_FULL
  use communications_init, only: init_comms_linear
  use communications, only: transpose_localized
  implicit none

  ! Calling arguments
  integer,intent(in) :: iproc, nproc, imethod_overlap
  type(atoms_data), intent(inout) :: at
  type(DFT_wavefunction),intent(inout):: tmb
  real(gp),dimension(3,at%astruct%nat),intent(in) :: rxyz

  ! Local variables
  logical :: reformat
  integer :: iorb,jstart,jstart_tmp
  integer :: iiorb,ilr,iiat,j,iis1,iie1,i1
  integer :: ilr_tmp,iiat_tmp,ndim_tmp,ndim,norb_tmp
  integer, dimension(3) :: ns,ns_tmp,n,n_tmp
  real(gp), dimension(3) :: centre_old_box, centre_new_box, da
  real(wp), dimension(:,:,:,:,:,:), allocatable :: phigold
  real(wp), dimension(:), pointer :: psi_tmp, psit_c_tmp, psit_f_tmp, norm
  integer, dimension(0:6) :: reformat_reason
  type(comms_linear) :: collcom_tmp
  type(local_zone_descriptors) :: lzd_tmp
  real(gp) :: tol
  character(len=*),parameter:: subname='tmb_overlap_onsite'
  type(fragment_transformation) :: frag_trans
  integer :: ierr, ncount, iroot, jproc
  integer,dimension(:),allocatable :: workarray

  ! move all psi into psi_tmp all centred in the same place and calculate overlap matrix
  tol=1.d-3
  reformat_reason=0

  !arbitrarily pick the middle one as assuming it'll be near the centre of structure
  !and therefore have large fine grid
  norb_tmp=tmb%orbs%norb/2
  ilr_tmp=tmb%orbs%inwhichlocreg(norb_tmp) 
  iiat_tmp=tmb%orbs%onwhichatom(norb_tmp)

  ! Find out which process handles TMB norb_tmp and get the keys from that process
  do jproc=0,nproc-1
      if (tmb%orbs%isorb_par(jproc)<norb_tmp .and. norb_tmp<=tmb%orbs%isorb_par(jproc)+tmb%orbs%norb_par(jproc,0)) then
          iroot=jproc
          exit
      end if
  end do
  if (iproc/=iroot) then
      ! some processes might already have it allocated
      call deallocate_wfd(tmb%lzd%llr(ilr_tmp)%wfd)
      call allocate_wfd(tmb%lzd%llr(ilr_tmp)%wfd)
  end if
  if (nproc>1) then
      ncount = tmb%lzd%llr(ilr_tmp)%wfd%nseg_c + tmb%lzd%llr(ilr_tmp)%wfd%nseg_f
      workarray = f_malloc(6*ncount,id='workarray')
      if (iproc==iroot) then
          call vcopy(2*ncount, tmb%lzd%llr(ilr_tmp)%wfd%keygloc(1,1), 1, workarray(1), 1)
          call vcopy(2*ncount, tmb%lzd%llr(ilr_tmp)%wfd%keyglob(1,1), 1, workarray(2*ncount+1), 1)
          call vcopy(ncount, tmb%lzd%llr(ilr_tmp)%wfd%keyvloc(1), 1, workarray(4*ncount+1), 1)
          call vcopy(ncount, tmb%lzd%llr(ilr_tmp)%wfd%keyvglob(1), 1, workarray(5*ncount+1), 1)
      end if
      call mpi_bcast(workarray(1), 6*ncount, mpi_integer, iroot, bigdft_mpi%mpi_comm, ierr)
      if (iproc/=iroot) then
          call vcopy(2*ncount, workarray(1), 1, tmb%lzd%llr(ilr_tmp)%wfd%keygloc(1,1), 1)
          call vcopy(2*ncount, workarray(2*ncount+1), 1, tmb%lzd%llr(ilr_tmp)%wfd%keyglob(1,1), 1)
          call vcopy(ncount, workarray(4*ncount+1), 1, tmb%lzd%llr(ilr_tmp)%wfd%keyvloc(1), 1)
          call vcopy(ncount, workarray(5*ncount+1), 1, tmb%lzd%llr(ilr_tmp)%wfd%keyvglob(1), 1)
      end if
      call f_free(workarray)
  end if

  ! find biggest instead
  !do ilr=1,tmb%lzr%nlr
  !  if (tmb%lzd%llr(ilr)%wfd%nvctr_c
  !end do

  ! Determine size of phi_old and phi
  ndim_tmp=0
  ndim=0
  do iorb=1,tmb%orbs%norbp
      iiorb=tmb%orbs%isorb+iorb
      ilr=tmb%orbs%inwhichlocreg(iiorb)
      ndim=ndim+tmb%lzd%llr(ilr)%wfd%nvctr_c+7*tmb%lzd%llr(ilr)%wfd%nvctr_f
      ndim_tmp=ndim_tmp+tmb%lzd%llr(ilr_tmp)%wfd%nvctr_c+7*tmb%lzd%llr(ilr_tmp)%wfd%nvctr_f
  end do

  ! should integrate bettwer with existing reformat routines, but restart needs tidying anyway
  psi_tmp = f_malloc_ptr(ndim_tmp,id='psi_tmp')

  jstart=1
  jstart_tmp=1
  do iorb=1,tmb%orbs%norbp
      iiorb=tmb%orbs%isorb+iorb
      ilr=tmb%orbs%inwhichlocreg(iiorb)
      iiat=tmb%orbs%onwhichatom(iiorb)

      n(1)=tmb%lzd%Llr(ilr)%d%n1
      n(2)=tmb%lzd%Llr(ilr)%d%n2
      n(3)=tmb%lzd%Llr(ilr)%d%n3
      n_tmp(1)=tmb%lzd%Llr(ilr_tmp)%d%n1
      n_tmp(2)=tmb%lzd%Llr(ilr_tmp)%d%n2
      n_tmp(3)=tmb%lzd%Llr(ilr_tmp)%d%n3
      ns(1)=tmb%lzd%Llr(ilr)%ns1
      ns(2)=tmb%lzd%Llr(ilr)%ns2
      ns(3)=tmb%lzd%Llr(ilr)%ns3
      ns_tmp(1)=tmb%lzd%Llr(ilr_tmp)%ns1
      ns_tmp(2)=tmb%lzd%Llr(ilr_tmp)%ns2
      ns_tmp(3)=tmb%lzd%Llr(ilr_tmp)%ns3

      !theta=0.d0*(4.0_gp*atan(1.d0)/180.0_gp)
      !newz=(/1.0_gp,0.0_gp,0.0_gp/)
      !centre_old(:)=rxyz(:,iiat)
      !centre_new(:)=rxyz(:,iiat_tmp)
      !shift(:)=centre_new(:)-centre_old(:)

      frag_trans=fragment_transformation_identity()
!!$      frag_trans%theta=0.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
!!$      frag_trans%rot_axis=(/1.0_gp,0.0_gp,0.0_gp/)
      frag_trans%rot_center(:)=rxyz(:,iiat)
      frag_trans%rot_center_new(:)=rxyz(:,iiat_tmp)

      call reformat_check(reformat,reformat_reason,tol,at,tmb%lzd%hgrids,tmb%lzd%hgrids,&
           tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%nvctr_c,&
           tmb%lzd%llr(ilr_tmp)%wfd%nvctr_c,tmb%lzd%llr(ilr_tmp)%wfd%nvctr_c,&
           n,n_tmp,ns,ns_tmp,frag_trans,centre_old_box,centre_new_box,da)  

      if (.not. reformat) then ! copy psi into psi_tmp
          do j=1,tmb%lzd%llr(ilr_tmp)%wfd%nvctr_c
              psi_tmp(jstart_tmp)=tmb%psi(jstart)
              jstart=jstart+1
              jstart_tmp=jstart_tmp+1
          end do
          do j=1,7*tmb%lzd%llr(ilr)%wfd%nvctr_f-6,7
              psi_tmp(jstart_tmp+0)=tmb%psi(jstart+0)
              psi_tmp(jstart_tmp+1)=tmb%psi(jstart+1)
              psi_tmp(jstart_tmp+2)=tmb%psi(jstart+2)
              psi_tmp(jstart_tmp+3)=tmb%psi(jstart+3)
              psi_tmp(jstart_tmp+4)=tmb%psi(jstart+4)
              psi_tmp(jstart_tmp+5)=tmb%psi(jstart+5)
              psi_tmp(jstart_tmp+6)=tmb%psi(jstart+6)
              jstart=jstart+7
              jstart_tmp=jstart_tmp+7
          end do
   
      else
          phigold = f_malloc((/ 0.to.n(1), 1.to.2, 0.to.n(2), 1.to.2, 0.to.n(3), 1.to.2 /),id='phigold')

          call psi_to_psig(n,tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%nvctr_f,&
               & tmb%lzd%llr(ilr)%wfd%nseg_c,tmb%lzd%llr(ilr)%wfd%nseg_f,&
               & tmb%lzd%llr(ilr)%wfd%keyvloc,tmb%lzd%llr(ilr)%wfd%keygloc,jstart,tmb%psi(jstart),phigold)

          call reformat_one_supportfunction(tmb%lzd%llr(ilr_tmp),tmb%lzd%llr(ilr),tmb%lzd%llr(ilr_tmp)%geocode,&
               & tmb%lzd%hgrids,n,phigold,tmb%lzd%hgrids,n_tmp,centre_old_box,centre_new_box,da,&
               & frag_trans,psi_tmp(jstart_tmp:))

          jstart_tmp=jstart_tmp+tmb%lzd%llr(ilr_tmp)%wfd%nvctr_c+7*tmb%lzd%llr(ilr_tmp)%wfd%nvctr_f
   
          call f_free(phigold)

      end if

  end do

  call print_reformat_summary(iproc,nproc,reformat_reason)

  ! now that they are all in one lr, need to calculate overlap matrix
  ! make lzd_tmp contain all identical lrs
  lzd_tmp%linear=tmb%lzd%linear
  lzd_tmp%nlr=tmb%lzd%nlr
  lzd_tmp%lintyp=tmb%lzd%lintyp
  lzd_tmp%ndimpotisf=tmb%lzd%ndimpotisf
  lzd_tmp%hgrids(:)=tmb%lzd%hgrids(:)

  call nullify_locreg_descriptors(lzd_tmp%glr)
  call copy_locreg_descriptors(tmb%lzd%glr, lzd_tmp%glr)

  iis1=lbound(tmb%lzd%llr,1)
  iie1=ubound(tmb%lzd%llr,1)
  allocate(lzd_tmp%llr(iis1:iie1))

  do i1=iis1,iie1
     call nullify_locreg_descriptors(lzd_tmp%llr(i1))
     call copy_locreg_descriptors(tmb%lzd%llr(ilr_tmp), lzd_tmp%llr(i1))
  end do

  !call nullify_comms_linear(collcom_tmp)
  collcom_tmp=comms_linear_null()
  call init_comms_linear(iproc, nproc, imethod_overlap, ndim_tmp, tmb%orbs, lzd_tmp, &
       tmb%linmat%m%nspin, collcom_tmp)

  psit_c_tmp = f_malloc_ptr(sum(collcom_tmp%nrecvcounts_c),id='psit_c_tmp')
  psit_f_tmp = f_malloc_ptr(7*sum(collcom_tmp%nrecvcounts_f),id='psit_f_tmp')

  call transpose_localized(iproc, nproc, ndim_tmp, tmb%orbs, collcom_tmp, &
       TRANSPOSE_FULL, psi_tmp, psit_c_tmp, psit_f_tmp, lzd_tmp)

  ! normalize psi
  norm = f_malloc_ptr(tmb%orbs%norb,id='norm')
  call normalize_transposed(iproc, nproc, tmb%orbs, tmb%linmat%s%nspin, collcom_tmp, psit_c_tmp, psit_f_tmp, norm)
  call f_free_ptr(norm)

  call calculate_pulay_overlap(iproc, nproc, tmb%orbs, tmb%orbs, collcom_tmp, collcom_tmp, &
       psit_c_tmp, psit_c_tmp, psit_f_tmp, psit_f_tmp, tmb%linmat%ovrlp_%matrix)

  call deallocate_comms_linear(collcom_tmp)
  call deallocate_local_zone_descriptors(lzd_tmp)

  call f_free_ptr(psit_c_tmp)
  call f_free_ptr(psit_f_tmp)

  call f_free_ptr(psi_tmp)

END SUBROUTINE tmb_overlap_onsite


!!subroutine tmb_overlap_onsite_rotate(iproc, nproc, at, tmb, rxyz)
!!
!!  use module_base
!!  use module_types
!!  use module_interfaces
!!  use module_fragments
!!  use communications_base, only: comms_linear_null, deallocate_comms_linear
!!  use communications_init, only: init_comms_linear
!!  use communications, only: transpose_localized
!!  implicit none
!!
!!  ! Calling arguments
!!  integer,intent(in) :: iproc, nproc
!!  type(atoms_data), intent(inout) :: at
!!  type(DFT_wavefunction),intent(in):: tmb
!!  real(gp),dimension(3,at%astruct%nat),intent(in) :: rxyz
!!
!!  ! Local variables
!!  logical :: reformat
!!  integer :: iorb,i_stat,i_all,istart,jstart
!!  integer :: iiorb,ilr,iiat,j,iis1,iie1,i1
!!  integer :: jlr,iiat_tmp,ndim_tmp,ndim,norb_tmp,iat,jjat,jjorb
!!  integer, dimension(3) :: ns,nsj,n,nj
!!  real(gp), dimension(3) :: centre_old_box, centre_new_box, da
!!  real(wp), dimension(:,:,:,:,:,:), allocatable :: phigold
!!  real(wp), dimension(:), pointer :: psi_tmp, psit_c_tmp, psit_f_tmp, norm
!!  integer, dimension(0:6) :: reformat_reason
!!  type(comms_linear) :: collcom_tmp
!!  type(local_zone_descriptors) :: lzd_tmp
!!  real(gp) :: tol
!!  character(len=*),parameter:: subname='tmb_overlap_onsite'
!!  type(fragment_transformation) :: frag_trans
!!  real(gp), dimension(:,:), allocatable :: rxyz4_new, rxyz4_ref, rxyz_new, rxyz_ref
!!  real(gp), dimension(:), allocatable :: dist
!!  integer, dimension(:), allocatable :: ipiv
!!
!!  ! move all psi into psi_tmp all centred in the same place and calculate overlap matrix
!!  tol=1.d-3
!!  reformat_reason=0
!!
!!  !arbitrarily pick the middle one as assuming it'll be near the centre of structure
!!  !and therefore have large fine grid
!!  norb_tmp=tmb%orbs%norb/2
!!  jlr=tmb%orbs%inwhichlocreg(norb_tmp) 
!!  iiat_tmp=tmb%orbs%onwhichatom(norb_tmp)
!!  jjorb=norb_tmp
!!  jjat=iiat_tmp
!!
!!  ! find biggest instead
!!  !do ilr=1,tmb%lzr%nlr
!!  !  if (tmb%lzd%llr(ilr)%wfd%nvctr_c
!!  !end do
!!
!!  ! Determine size of phi_old and phi
!!  ndim_tmp=0
!!  ndim=0
!!  do iorb=1,tmb%orbs%norbp
!!      iiorb=tmb%orbs%isorb+iorb
!!      ilr=tmb%orbs%inwhichlocreg(iiorb)
!!      ndim=ndim+tmb%lzd%llr(ilr)%wfd%nvctr_c+7*tmb%lzd%llr(ilr)%wfd%nvctr_f
!!      ndim_tmp=ndim_tmp+tmb%lzd%llr(jlr)%wfd%nvctr_c+7*tmb%lzd%llr(jlr)%wfd%nvctr_f
!!  end do
!!
!!  ! should integrate bettwer with existing reformat routines, but restart needs tidying anyway
!!  allocate(psi_tmp(ndim_tmp),stat=i_stat)
!!  call memocc(i_stat,psi_tmp,'psi_tmp',subname)
!!
!!  allocate(rxyz4_ref(3,min(4,at%astruct%nat)), stat=i_stat)
!!  call memocc(i_stat, rxyz4_ref, 'rxyz4_ref', subname)
!!  allocate(rxyz4_new(3,min(4,at%astruct%nat)), stat=i_stat)
!!  call memocc(i_stat, rxyz4_new, 'rxyz4_ref', subname)
!!
!!  allocate(rxyz_ref(3,at%astruct%nat), stat=i_stat)
!!  call memocc(i_stat, rxyz_ref, 'rxyz_ref', subname)
!!  allocate(rxyz_new(3,at%astruct%nat), stat=i_stat)
!!  call memocc(i_stat, rxyz_new, 'rxyz_ref', subname)
!!  allocate(dist(at%astruct%nat), stat=i_stat)
!!  call memocc(i_stat, dist, 'dist', subname)
!!  allocate(ipiv(at%astruct%nat), stat=i_stat)
!!  call memocc(i_stat, ipiv, 'ipiv', subname)
!!
!!  istart=1
!!  jstart=1
!!  do iorb=1,tmb%orbs%norbp
!!      iiorb=tmb%orbs%isorb+iorb
!!      ilr=tmb%orbs%inwhichlocreg(iiorb)
!!      iiat=tmb%orbs%onwhichatom(iiorb)
!!
!!      !do jjorb=1,tmb%orbs%norb
!!      !   !jlr=tmb%orbs%inwhichlocreg(jjorb)
!!      !   jjat=tmb%orbs%onwhichatom(jjorb)
!!
!!         n(1)=tmb%lzd%Llr(ilr)%d%n1
!!         n(2)=tmb%lzd%Llr(ilr)%d%n2
!!         n(3)=tmb%lzd%Llr(ilr)%d%n3
!!         nj(1)=tmb%lzd%Llr(jlr)%d%n1
!!         nj(2)=tmb%lzd%Llr(jlr)%d%n2
!!         nj(3)=tmb%lzd%Llr(jlr)%d%n3
!!         ns(1)=tmb%lzd%Llr(ilr)%ns1
!!         ns(2)=tmb%lzd%Llr(ilr)%ns2
!!         ns(3)=tmb%lzd%Llr(ilr)%ns3
!!         nsj(1)=tmb%lzd%Llr(jlr)%ns1
!!         nsj(2)=tmb%lzd%Llr(jlr)%ns2
!!         nsj(3)=tmb%lzd%Llr(jlr)%ns3
!!
!!         ! find fragment transformation using 3 nearest neighbours
!!         do iat=1,at%astruct%nat
!!            rxyz_new(:,iat)=rxyz(:,iat)
!!            rxyz_ref(:,iat)=rxyz(:,iat)
!!         end do
!!
!!         ! use atom position
!!         frag_trans%rot_center=rxyz(:,iiat)
!!         frag_trans%rot_center_new=rxyz(:,jjat)
!!
!!        ! shift rxyz wrt center of rotation
!!         do iat=1,at%astruct%nat
!!            rxyz_ref(:,iat)=rxyz_ref(:,iat)-frag_trans%rot_center
!!            rxyz_new(:,iat)=rxyz_new(:,iat)-frag_trans%rot_center_new
!!         end do
!!
!!         ! find distances from this atom, sort atoms into neighbour order and take atom and 3 nearest neighbours
!!         do iat=1,at%astruct%nat
!!            dist(iat)=-dsqrt(rxyz_ref(1,iat)**2+rxyz_ref(2,iat)**2+rxyz_ref(3,iat)**2)
!!         end do             
!!         call sort_positions(at%astruct%nat,dist,ipiv)
!!         do iat=1,min(4,at%astruct%nat)
!!            rxyz4_ref(:,iat)=rxyz_ref(:,ipiv(iat))
!!         end do
!!
!!         ! find distances from this atom, sort atoms into neighbour order and take atom and 3 nearest neighbours
!!         do iat=1,at%astruct%nat
!!            dist(iat)=-dsqrt(rxyz_new(1,iat)**2+rxyz_new(2,iat)**2+rxyz_new(3,iat)**2)
!!         end do             
!!         call sort_positions(at%astruct%nat,dist,ipiv)
!!         do iat=1,min(4,at%astruct%nat)
!!            rxyz4_new(:,iat)=rxyz_new(:,ipiv(iat))
!!         end do
!!
!!         call find_frag_trans(min(4,at%astruct%nat),rxyz4_ref,rxyz4_new,frag_trans)
!!
!!         write(*,'(A,4(I3,1x),3(F12.6,1x),F12.6)') 'iorb,jorb,iat,jat,rot_axis,theta',&
!!              iiorb,jjorb,iiat,jjat,frag_trans%rot_axis,frag_trans%theta/(4.0_gp*atan(1.d0)/180.0_gp)
!!
!!         !frag_trans%theta=0.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
!!         !frag_trans%rot_axis=(/1.0_gp,0.0_gp,0.0_gp/)
!!         !frag_trans%rot_center(:)=rxyz(:,iiat)
!!         !overwrite rot_center_new to account for llr_tmp being in different location
!!         frag_trans%rot_center_new(:)=rxyz(:,iiat_tmp)
!!
!!         call reformat_check(reformat,reformat_reason,tol,at,tmb%lzd%hgrids,tmb%lzd%hgrids,&
!!              tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%nvctr_c,&
!!              tmb%lzd%llr(jlr)%wfd%nvctr_c,tmb%lzd%llr(jlr)%wfd%nvctr_c,&
!!              n,nj,ns,nsj,frag_trans,centre_old_box,centre_new_box,da)  
!!
!!         if (.not. reformat) then ! copy psi into psi_tmp
!!            do j=1,tmb%lzd%llr(jlr)%wfd%nvctr_c
!!               psi_tmp(jstart)=tmb%psi(istart)
!!               istart=istart+1
!!               jstart=jstart+1
!!            end do
!!            do j=1,7*tmb%lzd%llr(ilr)%wfd%nvctr_f-6,7
!!               psi_tmp(jstart+0)=tmb%psi(istart+0)
!!               psi_tmp(jstart+1)=tmb%psi(istart+1)
!!               psi_tmp(jstart+2)=tmb%psi(istart+2)
!!               psi_tmp(jstart+3)=tmb%psi(istart+3)
!!               psi_tmp(jstart+4)=tmb%psi(istart+4)
!!               psi_tmp(jstart+5)=tmb%psi(istart+5)
!!               psi_tmp(jstart+6)=tmb%psi(istart+6)
!!               istart=istart+7
!!               jstart=jstart+7
!!            end do
!!         else
!!            allocate(phigold(0:n(1),2,0:n(2),2,0:n(3),2+ndebug),stat=i_stat)
!!            call memocc(i_stat,phigold,'phigold',subname)
!!
!!            call psi_to_psig(n,tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%nvctr_f,&
!!                 tmb%lzd%llr(ilr)%wfd%nseg_c,tmb%lzd%llr(ilr)%wfd%nseg_f,&
!!                 tmb%lzd%llr(ilr)%wfd%keyvloc,tmb%lzd%llr(ilr)%wfd%keygloc,istart,tmb%psi(jstart),phigold)
!!
!!            call reformat_one_supportfunction(tmb%lzd%llr(jlr),tmb%lzd%llr(ilr),tmb%lzd%llr(jlr)%geocode,&
!!                 tmb%lzd%hgrids,n,phigold,tmb%lzd%hgrids,nj,centre_old_box,centre_new_box,da,&
!!                 frag_trans,psi_tmp(jstart:))
!!
!!            jstart=jstart+tmb%lzd%llr(jlr)%wfd%nvctr_c+7*tmb%lzd%llr(jlr)%wfd%nvctr_f
!!   
!!            i_all=-product(shape(phigold))*kind(phigold)
!!            deallocate(phigold,stat=i_stat)
!!            call memocc(i_stat,i_all,'phigold',subname)
!!        end if
!!
!!     !end do
!!  end do
!!
!!
!!  i_all = -product(shape(ipiv))*kind(ipiv)
!!  deallocate(ipiv,stat=i_stat)
!!  call memocc(i_stat,i_all,'ipiv',subname)
!!  i_all = -product(shape(dist))*kind(dist)
!!  deallocate(dist,stat=i_stat)
!!  call memocc(i_stat,i_all,'dist',subname)
!!  i_all = -product(shape(rxyz_ref))*kind(rxyz_ref)
!!  deallocate(rxyz_ref,stat=i_stat)
!!  call memocc(i_stat,i_all,'rxyz_ref',subname)
!!  i_all = -product(shape(rxyz_new))*kind(rxyz_new)
!!  deallocate(rxyz_new,stat=i_stat)
!!  call memocc(i_stat,i_all,'rxyz_new',subname)
!!  i_all = -product(shape(rxyz4_ref))*kind(rxyz4_ref)
!!  deallocate(rxyz4_ref,stat=i_stat)
!!  call memocc(i_stat,i_all,'rxyz4_ref',subname)
!!  i_all = -product(shape(rxyz4_new))*kind(rxyz4_new)
!!  deallocate(rxyz4_new,stat=i_stat)
!!  call memocc(i_stat,i_all,'rxyz4_new',subname)
!!
!!  call print_reformat_summary(iproc,reformat_reason)
!!
!!  ! now that they are all in one lr, need to calculate overlap matrix
!!  ! make lzd_tmp contain all identical lrs
!!  lzd_tmp%linear=tmb%lzd%linear
!!  lzd_tmp%nlr=tmb%lzd%nlr
!!  lzd_tmp%lintyp=tmb%lzd%lintyp
!!  lzd_tmp%ndimpotisf=tmb%lzd%ndimpotisf
!!  lzd_tmp%hgrids(:)=tmb%lzd%hgrids(:)
!!
!!  call nullify_locreg_descriptors(lzd_tmp%glr)
!!  call copy_locreg_descriptors(tmb%lzd%glr, lzd_tmp%glr)
!!
!!  iis1=lbound(tmb%lzd%llr,1)
!!  iie1=ubound(tmb%lzd%llr,1)
!!  allocate(lzd_tmp%llr(iis1:iie1), stat=i_stat)
!!  do i1=iis1,iie1
!!     call nullify_locreg_descriptors(lzd_tmp%llr(i1))
!!     call copy_locreg_descriptors(tmb%lzd%llr(jlr), lzd_tmp%llr(i1))
!!  end do
!!
!!  !call nullify_comms_linear(collcom_tmp)
!!  collcom_tmp=comms_linear_null()
!!  call init_comms_linear(iproc, nproc, ndim_tmp, tmb%orbs, lzd_tmp, collcom_tmp)
!!
!!  allocate(psit_c_tmp(sum(collcom_tmp%nrecvcounts_c)), stat=i_stat)
!!  call memocc(i_stat, psit_c_tmp, 'psit_c_tmp', subname)
!!
!!  allocate(psit_f_tmp(7*sum(collcom_tmp%nrecvcounts_f)), stat=i_stat)
!!  call memocc(i_stat, psit_f_tmp, 'psit_f_tmp', subname)
!!
!!  call transpose_localized(iproc, nproc, ndim_tmp, tmb%orbs, collcom_tmp, &
!!       psi_tmp, psit_c_tmp, psit_f_tmp, lzd_tmp)
!!
!!  ! normalize psi
!!  allocate(norm(tmb%orbs%norb), stat=i_stat)
!!  call memocc(i_stat, norm, 'norm', subname)
!!  call normalize_transposed(iproc, nproc, tmb%orbs, collcom_tmp, psit_c_tmp, psit_f_tmp, norm)
!!  i_all = -product(shape(norm))*kind(norm)
!!  deallocate(norm,stat=i_stat)
!!  call memocc(i_stat,i_all,'norm',subname)
!!
!!  call calculate_pulay_overlap(iproc, nproc, tmb%orbs, tmb%orbs, collcom_tmp, collcom_tmp, &
!!       psit_c_tmp, psit_c_tmp, psit_f_tmp, psit_f_tmp, tmb%linmat%ovrlp%matrix)
!!
!!  call deallocate_comms_linear(collcom_tmp)
!!  call deallocate_local_zone_descriptors(lzd_tmp)
!!
!!  i_all = -product(shape(psit_c_tmp))*kind(psit_c_tmp)
!!  deallocate(psit_c_tmp,stat=i_stat)
!!  call memocc(i_stat,i_all,'psit_c_tmp',subname)
!!
!!  i_all = -product(shape(psit_f_tmp))*kind(psit_f_tmp)
!!  deallocate(psit_f_tmp,stat=i_stat)
!!  call memocc(i_stat,i_all,'psit_f_tmp',subname)
!!
!!  i_all = -product(shape(psi_tmp))*kind(psi_tmp)
!!  deallocate(psi_tmp,stat=i_stat)
!!  call memocc(i_stat,i_all,'psi_tmp',subname)
!!
!!END SUBROUTINE tmb_overlap_onsite_rotate


!> Write all my wavefunctions in files by calling writeonewave
subroutine writemywaves_linear(iproc,filename,iformat,npsidim,Lzd,orbs,nelec,at,rxyz,psi,coeff)
  use module_types
  use module_base
  use yaml_output
  use module_interfaces, except_this_one => writeonewave
  implicit none
  integer, intent(in) :: iproc,iformat,npsidim,nelec
  !integer, intent(in) :: norb   !< number of orbitals, not basis functions
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs         !< orbs describing the basis functions
  type(local_zone_descriptors), intent(in) :: Lzd
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz
  real(wp), dimension(npsidim), intent(in) :: psi  ! Should be the real linear dimension and not the global
  real(wp), dimension(orbs%norb,orbs%norb), intent(in) :: coeff
  character(len=*), intent(in) :: filename
  !Local variables
  integer :: ncount1,ncount_rate,ncount_max,iorb,ncount2,iorb_out,ispinor,ilr,shift,ii,iat
  integer :: jorb,jlr
  real(kind=4) :: tr0,tr1
  real(kind=8) :: tel

  if (iproc == 0) call yaml_map('Write wavefunctions to file', trim(filename)//'.*')
  !if (iproc == 0) write(*,"(1x,A,A,a)") "Write wavefunctions to file: ", trim(filename),'.*'

  if (iformat == WF_FORMAT_ETSF) then
      stop 'Linear scaling with ETSF writing not implemented yet'
!     call write_waves_etsf(iproc,filename,orbs,n1,n2,n3,hx,hy,hz,at,rxyz,wfd,psi)
  else
     call cpu_time(tr0)
     call system_clock(ncount1,ncount_rate,ncount_max)

     ! Write the TMBs in the Plain BigDFT files.
     ! Use same ordering as posinp and llr generation
     ii = 0
     do iat = 1, at%astruct%nat
        do iorb=1,orbs%norbp
           if(iat == orbs%onwhichatom(iorb+orbs%isorb)) then
              shift = 1
              do jorb = 1, iorb-1 
                 jlr = orbs%inwhichlocreg(jorb+orbs%isorb)
                 shift = shift + Lzd%Llr(jlr)%wfd%nvctr_c+7*Lzd%Llr(jlr)%wfd%nvctr_f
              end do
              ii = ii + 1
              ilr = orbs%inwhichlocreg(iorb+orbs%isorb)
              do ispinor=1,orbs%nspinor
                 call open_filename_of_iorb(99,(iformat == WF_FORMAT_BINARY),filename, &
                    & orbs,iorb,ispinor,iorb_out)
                 call writeonewave_linear(99,(iformat == WF_FORMAT_PLAIN),iorb_out,&
                    & Lzd%Llr(ilr)%d%n1,Lzd%Llr(ilr)%d%n2,Lzd%Llr(ilr)%d%n3,&
                    & Lzd%Llr(ilr)%ns1,Lzd%Llr(ilr)%ns2,Lzd%Llr(ilr)%ns3,& 
                    & Lzd%hgrids(1),Lzd%hgrids(2),Lzd%hgrids(3), &
                    & Lzd%Llr(ilr)%locregCenter,Lzd%Llr(ilr)%locrad, 4, 0.0d0, &  !put here the real potentialPrefac and Order
                    & at%astruct%nat,rxyz,Lzd%Llr(ilr)%wfd%nseg_c,Lzd%Llr(ilr)%wfd%nvctr_c,&
                    & Lzd%Llr(ilr)%wfd%keygloc,Lzd%Llr(ilr)%wfd%keyvloc, &
                    & Lzd%Llr(ilr)%wfd%nseg_f,Lzd%Llr(ilr)%wfd%nvctr_f,&
                    & Lzd%Llr(ilr)%wfd%keygloc(1,Lzd%Llr(ilr)%wfd%nseg_c+1), &
                    & Lzd%Llr(ilr)%wfd%keyvloc(Lzd%Llr(ilr)%wfd%nseg_c+1), &
                    & psi(shift),psi(Lzd%Llr(ilr)%wfd%nvctr_c+shift),orbs%eval(iorb+orbs%isorb),&
                    & orbs%onwhichatom(iorb+orbs%isorb))
                 close(99)
              end do
           end if
        enddo
     end do

    ! Now write the coefficients to file
    ! Must be careful, the orbs%norb is the number of basis functions
    ! while the norb is the number of orbitals.
    if(iproc == 0) then
      if(iformat == WF_FORMAT_PLAIN) then
         open(99, file=filename//'_coeff.bin', status='unknown',form='formatted')
      else
         open(99, file=filename//'_coeff.bin', status='unknown',form='unformatted')
      end if
      call writeLinearCoefficients(99,(iformat == WF_FORMAT_PLAIN),at%astruct%nat,rxyz,orbs%norb,&
           nelec,coeff,orbs%eval)
      close(99)
    end if
     call cpu_time(tr1)
     call system_clock(ncount2,ncount_rate,ncount_max)
     tel=dble(ncount2-ncount1)/dble(ncount_rate)
     if (iproc == 0) then
        call yaml_sequence_open('Write Waves Time')
        call yaml_sequence(advance='no')
        call yaml_mapping_open(flow=.true.)
        call yaml_map('Process',iproc)
        call yaml_map('Timing',(/ real(tr1-tr0,kind=8),tel /),fmt='(1pe10.3)')
        call yaml_mapping_close()
        call yaml_sequence_close()
     end if
     !write(*,'(a,i4,2(1x,1pe10.3))') '- WRITE WAVES TIME',iproc,tr1-tr0,tel
     !write(*,'(a,1x,i0,a)') '- iproc',iproc,' finished writing waves'
  end if

END SUBROUTINE writemywaves_linear

!possibly broken
subroutine readonewave_linear(unitwf,useFormattedInput,iorb,iproc,n,ns,&
     & hgrids,at,llr,rxyz_old,rxyz,locrad,locregCenter,confPotOrder,&
     & confPotprefac,psi,eval,onwhichatom,lr,glr,reformat_reason)
  use module_base
  use module_types
  use internal_io
  use module_interfaces
  use yaml_output
  use module_fragments
  implicit none
  logical, intent(in) :: useFormattedInput
  integer, intent(in) :: unitwf,iorb,iproc
  integer, dimension(3), intent(in) :: n,ns
  !type(wavefunctions_descriptors), intent(in) :: wfd
  type(locreg_descriptors), intent(in) :: llr
  type(atoms_data), intent(in) :: at
  real(gp), dimension(3), intent(in) :: hgrids
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz
  integer, intent(out) :: confPotOrder
  real(gp), intent(out) :: locrad, confPotprefac
  real(wp), intent(out) :: eval
  real(gp), dimension(3), intent(out) :: locregCenter
  real(gp), dimension(3,at%astruct%nat), intent(out) :: rxyz_old
  real(wp), dimension(:), pointer :: psi
  integer, dimension(*), intent(in) :: onwhichatom
  type(locreg_descriptors), intent(in) :: lr, glr
  integer, dimension(0:6), intent(out) :: reformat_reason

  !local variables
  character(len=*), parameter :: subname='readonewave_linear'
  character(len = 256) :: error
  logical :: lstat,reformat
  integer :: iorb_old,nvctr_c_old,nvctr_f_old,iiat
  integer :: i1,i2,i3,iel,onwhichatom_tmp
  integer, dimension(3) :: ns_old,n_old
  real(gp) :: tol
  real(gp), dimension(3) :: hgrids_old, centre_old_box, centre_new_box, da
  real(gp) :: tt,t1,t2,t3,t4,t5,t6,t7
  real(wp), dimension(:,:,:,:,:,:), allocatable :: psigold
  type(fragment_transformation) :: frag_trans
  ! DEBUG
  ! character(len=12) :: orbname
  ! real(wp), dimension(:), allocatable :: gpsi


  call io_read_descr_linear(unitwf, useFormattedInput, iorb_old, eval, n_old(1), n_old(2), n_old(3), &
       ns_old(1), ns_old(2), ns_old(3), hgrids_old, lstat, error, onwhichatom_tmp, locrad, &
       locregCenter, confPotOrder, confPotprefac, nvctr_c_old, nvctr_f_old, at%astruct%nat, rxyz_old)

  if (.not. lstat) call io_error(trim(error))
  if (iorb_old /= iorb) stop 'readonewave_linear'

  iiat=onwhichatom(iorb)
  tol=1.d-3

  !why these hard-coded values?
  frag_trans%theta=20.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
  frag_trans%rot_axis=(/1.0_gp,0.0_gp,0.0_gp/)
  frag_trans%rot_center(:)=(/7.8d0,11.8d0,11.6d0/)
  frag_trans%rot_center_new(:)=(/7.8d0,11.2d0,11.8d0/)

  call reformat_check(reformat,reformat_reason,tol,at,hgrids,hgrids_old,&
       nvctr_c_old,nvctr_f_old,llr%wfd%nvctr_c,llr%wfd%nvctr_f,&
       n_old,n,ns_old,ns,frag_trans,centre_old_box,centre_new_box,da)  

  if (.not. reformat) then
     call read_psi_compress(unitwf, useFormattedInput, nvctr_c_old, nvctr_f_old, psi, lstat, error)
     if (.not. lstat) call io_error(trim(error))
  else
     ! add derivative functions at a later date? (needs orbs and lzd)
     psigold = f_malloc((/ 0.to.n_old(1), 1.to.2, 0.to.n_old(2), 1.to.2, 0.to.n_old(3), 1.to.2 /),id='psigold')

     call to_zero(8*(n_old(1)+1)*(n_old(2)+1)*(n_old(3)+1),psigold)
     do iel=1,nvctr_c_old
        if (useFormattedInput) then
           read(unitwf,*) i1,i2,i3,tt
        else
           read(unitwf) i1,i2,i3,tt
        end if
        psigold(i1,1,i2,1,i3,1)=tt
     enddo
     do iel=1,nvctr_f_old
        if (useFormattedInput) then
           read(unitwf,*) i1,i2,i3,t1,t2,t3,t4,t5,t6,t7
        else
           read(unitwf) i1,i2,i3,t1,t2,t3,t4,t5,t6,t7
        end if
        psigold(i1,2,i2,1,i3,1)=t1
        psigold(i1,1,i2,2,i3,1)=t2
        psigold(i1,2,i2,2,i3,1)=t3
        psigold(i1,1,i2,1,i3,2)=t4
        psigold(i1,2,i2,1,i3,2)=t5
        psigold(i1,1,i2,2,i3,2)=t6
        psigold(i1,2,i2,2,i3,2)=t7
     enddo

     ! NB assuming here geocode is the same in glr and llr
     call reformat_one_supportfunction(llr,llr,at%astruct%geocode,hgrids_old,n_old,psigold,hgrids,n, &
         centre_old_box,centre_new_box,da,frag_trans,psi)

     call f_free(psigold)

  endif

  !! DEBUG - plot in global box - CHECK WITH REFORMAT ETC IN LRs
  !allocate (gpsi(glr%wfd%nvctr_c+7*glr%wfd%nvctr_f),stat=i_stat)
  !call memocc(i_stat,gpsi,'gpsi',subname)
  !
  !call to_zero(glr%wfd%nvctr_c+7*glr%wfd%nvctr_f,gpsi)
  !call Lpsi_to_global2(iproc, llr%%wfd%nvctr_c+7*lr%wfd%nvctr_f, glr%wfd%nvctr_c+7*glr%wfd%nvctr_f, &
  !     1, 1, 1, glr, lr, psi, gpsi)
  !
  !write(orbname,*) iorb
  !call plot_wf(trim(adjustl(orbname)),1,at,1.0_dp,glr,hgrids(1),hgrids(2),hgrids(3),rxyz,gpsi)
  !!call plot_wf(trim(adjustl(orbname)),1,at,1.0_dp,lr,hx,hy,hz,rxyz,psi)
  !
  !i_all=-product(shape(gpsi))*kind(gpsi)
  !deallocate(gpsi,stat=i_stat)
  !call memocc(i_stat,i_all,'gpsi',subname)
  !! END DEBUG 

END SUBROUTINE readonewave_linear


subroutine io_read_descr_linear(unitwf, formatted, iorb_old, eval, n_old1, n_old2, n_old3, &
       & ns_old1, ns_old2, ns_old3, hgrids_old, lstat, error, onwhichatom, locrad, locregCenter, &
       & confPotOrder, confPotprefac, nvctr_c_old, nvctr_f_old, nat, rxyz_old)
    use module_base
    use module_types
    use internal_io
    use yaml_output
    implicit none

    integer, intent(in) :: unitwf
    logical, intent(in) :: formatted
    integer, intent(out) :: iorb_old
    integer, intent(out) :: n_old1, n_old2, n_old3, ns_old1, ns_old2, ns_old3
    real(gp), dimension(3), intent(out) :: hgrids_old
    logical, intent(out) :: lstat
    real(wp), intent(out) :: eval
    real(gp), intent(out) :: locrad
    real(gp), dimension(3), intent(out) :: locregCenter
    character(len =256), intent(out) :: error
    integer, intent(out) :: onwhichatom
    integer, intent(out) :: confPotOrder
    real(gp), intent(out) :: confPotprefac
    ! Optional arguments
    integer, intent(out), optional :: nvctr_c_old, nvctr_f_old
    integer, intent(in), optional :: nat
    real(gp), dimension(:,:), intent(out), optional :: rxyz_old

    integer :: i, iat, i_stat, nat_
    real(gp) :: rxyz(3)

    lstat = .false.
    write(error, "(A)") "cannot read psi description."
    if (formatted) then
       read(unitwf,*,iostat=i_stat) iorb_old,eval
       if (i_stat /= 0) return
       read(unitwf,*,iostat=i_stat) hgrids_old(1),hgrids_old(2),hgrids_old(3)
       if (i_stat /= 0) return
       read(unitwf,*,iostat=i_stat) n_old1,n_old2,n_old3
       if (i_stat /= 0) return
       read(unitwf,*,iostat=i_stat) ns_old1,ns_old2,ns_old3
       if (i_stat /= 0) return
       read(unitwf,*,iostat=i_stat) (locregCenter(i),i=1,3),onwhichatom,&
            locrad,confPotOrder, confPotprefac
       if (i_stat /= 0) return
       !call yaml_map('Reading atomic positions',nat)
       !write(*,*) 'reading ',nat,' atomic positions' !*
       if (present(nat) .And. present(rxyz_old)) then
          read(unitwf,*,iostat=i_stat) nat_
          if (i_stat /= 0) return
          ! Sanity check
          if (size(rxyz_old, 2) /= nat) stop "Mismatch in coordinate array size."
          if (nat_ /= nat) stop "Mismatch in coordinate array size."
          do iat=1,nat
             read(unitwf,*,iostat=i_stat) (rxyz_old(i,iat),i=1,3)
             if (i_stat /= 0) return

          enddo
       else
          read(unitwf,*,iostat=i_stat) nat_
          if (i_stat /= 0) return
          do iat=1,nat_
             read(unitwf,*,iostat=i_stat)
             if (i_stat /= 0) return
          enddo
       end if
       if (present(nvctr_c_old) .and. present(nvctr_f_old)) then
          read(unitwf,*,iostat=i_stat) nvctr_c_old, nvctr_f_old
          if (i_stat /= 0) return
       else
          read(unitwf,*,iostat=i_stat) i, iat
          if (i_stat /= 0) return
       end if
    else
       read(unitwf,iostat=i_stat) iorb_old,eval
       if (i_stat /= 0) return

       read(unitwf,iostat=i_stat) hgrids_old(1),hgrids_old(2),hgrids_old(3)
       if (i_stat /= 0) return
       read(unitwf,iostat=i_stat) n_old1,n_old2,n_old3
       if (i_stat /= 0) return
       read(unitwf,iostat=i_stat) ns_old1,ns_old2,ns_old3
       if (i_stat /= 0) return
       read(unitwf,iostat=i_stat) (locregCenter(i),i=1,3),onwhichatom,&
            locrad,confPotOrder, confPotprefac
       if (i_stat /= 0) return
       if (present(nat) .And. present(rxyz_old)) then
          read(unitwf,iostat=i_stat) nat_
          if (i_stat /= 0) return
          ! Sanity check
          if (size(rxyz_old, 2) /= nat) stop "Mismatch in coordinate array size." 
          if (nat_ /= nat) stop "Mismatch in coordinate array size."
          do iat=1,nat
             read(unitwf,iostat=i_stat)(rxyz_old(i,iat),i=1,3)
             if (i_stat /= 0) return
          enddo
       else
          read(unitwf,iostat=i_stat) nat_
          if (i_stat /= 0) return
          do iat=1,nat_
             read(unitwf,iostat=i_stat) rxyz
             if (i_stat /= 0) return
          enddo
       end if
       if (present(nvctr_c_old) .and. present(nvctr_f_old)) then
          read(unitwf,iostat=i_stat) nvctr_c_old, nvctr_f_old
          if (i_stat /= 0) return
       else
          read(unitwf,iostat=i_stat) i, iat
          if (i_stat /= 0) return
       end if
    end if
    lstat = .true.

END SUBROUTINE io_read_descr_linear


subroutine io_read_descr_coeff(unitwf, formatted, norb_old, ntmb_old, &
       & lstat, error, nat, rxyz_old)
    use module_base
    use module_types
    use internal_io
    implicit none
    integer, intent(in) :: unitwf
    logical, intent(in) :: formatted
    integer, intent(out) :: norb_old, ntmb_old
    logical, intent(out) :: lstat
    character(len =256), intent(out) :: error
    ! Optional arguments
    integer, intent(in), optional :: nat
    real(gp), dimension(:,:), intent(out), optional :: rxyz_old

    integer :: i, iat, i_stat, nat_
    real(gp) :: rxyz(3)

    lstat = .false.
    write(error, "(A)") "cannot read coeff description."
    if (formatted) then
       read(unitwf,*,iostat=i_stat) ntmb_old, norb_old
       if (i_stat /= 0) return
       !write(*,*) 'reading ',nat,' atomic positions'
       if (present(nat) .And. present(rxyz_old)) then
          read(unitwf,*,iostat=i_stat) nat_
          if (i_stat /= 0) return
          ! Sanity check
          if (size(rxyz_old, 2) /= nat) stop "Mismatch in coordinate array size."
          if (nat_ /= nat) stop "Mismatch in coordinate array size."
          do iat=1,nat
             read(unitwf,*,iostat=i_stat) (rxyz_old(i,iat),i=1,3)
             if (i_stat /= 0) return
          enddo
       else
          read(unitwf,*,iostat=i_stat) nat_
          if (i_stat /= 0) return
          do iat=1,nat_
             read(unitwf,*,iostat=i_stat)
             if (i_stat /= 0) return
          enddo
       end if
       !read(unitwf,*,iostat=i_stat) i, iat
       !if (i_stat /= 0) return
    else
       read(unitwf,iostat=i_stat) ntmb_old, norb_old
       if (i_stat /= 0) return
       if (present(nat) .And. present(rxyz_old)) then
          read(unitwf,iostat=i_stat) nat_
          if (i_stat /= 0) return
          ! Sanity check
          if (size(rxyz_old, 2) /= nat) stop "Mismatch in coordinate array size." 
          if (nat_ /= nat) stop "Mismatch in coordinate array size."
          do iat=1,nat
             read(unitwf,iostat=i_stat)(rxyz_old(i,iat),i=1,3)
             if (i_stat /= 0) return
          enddo
       else
          read(unitwf,iostat=i_stat) nat_
          if (i_stat /= 0) return
          do iat=1,nat_
             read(unitwf,iostat=i_stat) rxyz
             if (i_stat /= 0) return
          enddo
       end if
       !read(unitwf,iostat=i_stat) i, iat
       !if (i_stat /= 0) return
    end if
    lstat = .true.
END SUBROUTINE io_read_descr_coeff


subroutine read_coeff_minbasis(unitwf,useFormattedInput,iproc,ntmb,norb_old,coeff,eval,nat,rxyz_old)
  use module_base
  use module_types
  use internal_io
  use module_interfaces, except_this_one => read_coeff_minbasis
  use yaml_output
  implicit none
  logical, intent(in) :: useFormattedInput
  integer, intent(in) :: unitwf,iproc,ntmb
  integer, intent(out) :: norb_old
  real(wp), dimension(ntmb,ntmb), intent(out) :: coeff
  real(wp), dimension(ntmb), intent(out) :: eval
  integer, optional, intent(in) :: nat
  real(gp), dimension(:,:), optional, intent(out) :: rxyz_old

  !local variables
  character(len = 256) :: error
  logical :: lstat
  integer :: i_stat
  integer :: ntmb_old, i1, i2,i,j,iorb,iorb_old
  real(wp) :: tt

  call io_read_descr_coeff(unitwf, useFormattedInput, norb_old, ntmb_old, &
       & lstat, error, nat, rxyz_old)
  if (.not. lstat) call io_error(trim(error))

  if (ntmb_old /= ntmb_old) then
     if (iproc == 0) write(error,"(A)") 'error in read coeffs, ntmb_old/=ntmb'
     call io_error(trim(error))
  end if

  ! read the eigenvalues
  if (useFormattedInput) then
     do iorb=1,ntmb
        read(unitwf,*,iostat=i_stat) iorb_old,eval(iorb)
        if (iorb_old /= iorb) stop 'read_coeff_minbasis'
     enddo
  else 
     do iorb=1,ntmb
        read(unitwf,iostat=i_stat) iorb_old,eval(iorb)
        if (iorb_old /= iorb) stop 'read_coeff_minbasis'
     enddo
     if (i_stat /= 0) stop 'Problem reading the eigenvalues'
  end if

  !if (iproc == 0) write(*,*) 'coefficients need NO reformatting'

  ! Now read the coefficients
  do i = 1, ntmb
     do j = 1, ntmb
        if (useFormattedInput) then
           read(unitwf,*,iostat=i_stat) i1,i2,tt
        else
           read(unitwf,iostat=i_stat) i1,i2,tt
        end if
        if (i_stat /= 0) stop 'Problem reading the coefficients'
        coeff(j,i) = tt  
     end do
  end do

  ! rescale so first significant element is +ve
  do i = 1, ntmb
     do j = 1, ntmb
        if (abs(coeff(j,i))>1.0e-1) then
           if (coeff(j,i)<0.0_gp) call dscal(ntmb,-1.0_gp,coeff(1,i),1)
           exit
        end if
     end do
     if (j==ntmb+1) stop 'Error finding significant coefficient!'
  end do

END SUBROUTINE read_coeff_minbasis


!> Reads wavefunction from file and transforms it properly if hgrid or size of simulation cell
!! have changed
subroutine readmywaves_linear_new(iproc,nproc,dir_output,filename,iformat,at,tmb,rxyz,&
       ref_frags,input_frag,frag_calc,orblist)
  use module_base
  use module_types
  use yaml_output
  use module_fragments
  use internal_io
  use module_interfaces, except_this_one => readmywaves_linear_new
  implicit none
  integer, intent(in) :: iproc, nproc
  integer, intent(in) :: iformat
  type(atoms_data), intent(in) :: at
  type(DFT_wavefunction), intent(inout) :: tmb
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz
  !real(gp), dimension(3,at%astruct%nat), intent(out) :: rxyz_old
  character(len=*), intent(in) :: dir_output, filename
  type(fragmentInputParameters), intent(in) :: input_frag
  type(system_fragment), dimension(input_frag%nfrag_ref), intent(inout) :: ref_frags
  logical, intent(in) :: frag_calc
  integer, dimension(tmb%orbs%norb), intent(in), optional :: orblist
  !Local variables
  integer :: ncount1,ncount_rate,ncount_max,ncount2
  integer :: iorb_out,ispinor,ilr,iorb_old
  integer :: confPotOrder,onwhichatom_tmp,unitwf
  real(gp) :: confPotprefac
!!$ real(gp), dimension(3) :: mol_centre, mol_centre_new
  real(kind=4) :: tr0,tr1
  real(kind=8) :: tel,eval
  character(len=256) :: error, full_filename
  logical :: lstat
  character(len=*), parameter :: subname='readmywaves_linear_new'
  ! to eventually be part of the fragment structure?
  integer :: ndim_old, iiorb, ifrag, ifrag_ref, isfat, iorbp, iforb, isforb, iiat, iat,ind
  type(local_zone_descriptors) :: lzd_old
  real(wp), dimension(:), pointer :: psi_old
  type(phi_array), dimension(:), pointer :: phi_array_old
  type(fragment_transformation), dimension(:), pointer :: frag_trans_orb, frag_trans_frag
  real(gp), dimension(:,:), allocatable :: rxyz_ref, rxyz_new, rxyz4_ref, rxyz4_new
  real(gp), dimension(:), allocatable :: dist
  integer, dimension(:), allocatable :: ipiv
  real(gp), dimension(:,:), allocatable :: rxyz_old !<this is read from the disk and not needed

  logical :: skip
!!$ integer :: ierr

  ! DEBUG
  ! character(len=12) :: orbname
  real(wp), dimension(:), allocatable :: gpsi

  call cpu_time(tr0)
  call system_clock(ncount1,ncount_rate,ncount_max)

  ! check file format
  if (iformat == WF_FORMAT_ETSF) then
     call f_err_throw('Linear scaling with ETSF writing not implemented yet')
  else if (iformat /= WF_FORMAT_BINARY .and. iformat /= WF_FORMAT_PLAIN) then
     call f_err_throw('Unknown wavefunction file format from filename.')
  end if

  rxyz_old=f_malloc([3,at%astruct%nat],id='rxyz_old')

  ! to be fixed
  if (present(orblist)) then
     call f_err_throw('orblist no longer functional in initialize_linear_from_file due to addition of fragment calculation')
  end if

  ! lzd_old => ref_frags(onwhichfrag)%frag_basis%lzd
  ! orbs_old -> ref_frags(onwhichfrag)%frag_basis%forbs ! <- BUT problem with it not being same type
  ! phi_array_old => ref_frags(onwhichfrag)%frag_basis%phi

  ! change parallelization later, for now all procs read the same number of tmbs as before
  ! initialize fragment lzd and phi_array_old for fragment, then allocate lzd_old which points to appropriate fragment entry
  ! for now directly using lzd_old etc - less efficient if fragments are used multiple times

  ! use above information to generate lzds
  call nullify_local_zone_descriptors(lzd_old)
  call nullify_locreg_descriptors(lzd_old%glr)
  lzd_old%nlr=tmb%orbs%norb
  allocate(lzd_old%Llr(lzd_old%nlr))
  do ilr=1,lzd_old%nlr
     call nullify_locreg_descriptors(lzd_old%llr(ilr))
  end do

  ! has size of new orbs, will possibly point towards the same tmb multiple times
  allocate(phi_array_old(tmb%orbs%norbp))
  do iorbp=1,tmb%orbs%norbp
     nullify(phi_array_old(iorbp)%psig)
  end do

  !allocate(frag_trans_orb(tmb%orbs%norbp))

  unitwf=99
  isforb=0
  isfat=0
  call timing(iproc,'tmbrestart','ON')
  do ifrag=1,input_frag%nfrag
     ! find reference fragment this corresponds to
     ifrag_ref=input_frag%frag_index(ifrag)
     ! loop over orbitals of this fragment
     loop_iforb: do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
        loop_iorb: do iorbp=1,tmb%orbs%norbp
           iiorb=iorbp+tmb%orbs%isorb
           !ilr = ref_frags(ifrag)%fbasis%forbs%inwhichlocreg(iiorb)
           ilr=tmb%orbs%inwhichlocreg(iiorb)
           iiat=tmb%orbs%onwhichatom(iiorb)

           ! check if this ref frag orbital corresponds to the orbital we want
           if (iiorb/=iforb+isforb) cycle
           do ispinor=1,tmb%orbs%nspinor
              ! if this is a fragment calculation frag%dirname will contain fragment directory, otherwise it will be empty
              ! bit of a hack to use orbs here not forbs, but different structures so this is necessary - to clean somehow
              full_filename=trim(dir_output)//trim(input_frag%dirname(ifrag_ref))//trim(filename)

              call open_filename_of_iorb(unitwf,(iformat == WF_FORMAT_BINARY),full_filename, &
                   & tmb%orbs,iorbp,ispinor,iorb_out,iforb)
                   !& ref_frags(ifrag_ref)%fbasis%forbs,iforb,ispinor,iorb_out)
  
              ! read headers, reading lzd info directly into lzd_old, which is otherwise nullified
              call io_read_descr_linear(unitwf, (iformat == WF_FORMAT_PLAIN), iorb_old, eval, &
                   Lzd_old%Llr(ilr)%d%n1,Lzd_old%Llr(ilr)%d%n2,Lzd_old%Llr(ilr)%d%n3, &
                   Lzd_old%Llr(ilr)%ns1,Lzd_old%Llr(ilr)%ns2,Lzd_old%Llr(ilr)%ns3, lzd_old%hgrids, &
                   lstat, error, onwhichatom_tmp, Lzd_old%Llr(ilr)%locrad, Lzd_old%Llr(ilr)%locregCenter, &
                   confPotOrder, confPotprefac, Lzd_old%Llr(ilr)%wfd%nvctr_c, Lzd_old%Llr(ilr)%wfd%nvctr_f, &
                   ref_frags(ifrag_ref)%astruct_frg%nat, rxyz_old(:,isfat+1:isfat+ref_frags(ifrag_ref)%astruct_frg%nat))
                   !ref_frags(ifrag_ref)%astruct_frg%nat, rxyz_old(1,isfat+1))

              ! in general this might point to a different tmb
              phi_array_old(iorbp)%psig = f_malloc_ptr((/ 0.to.Lzd_old%Llr(ilr)%d%n1 , 1.to.2 , &
                   0.to.Lzd_old%Llr(ilr)%d%n2 , 1.to.2 , &
                   0.to.Lzd_old%Llr(ilr)%d%n3 , 1.to.2 /),id='phi_array_old(iorbp)%psig')
              call timing(iproc,'tmbrestart','OF')

              !read phig directly
              call timing(iproc,'readtmbfiles','ON')
              call read_psig(unitwf, (iformat == WF_FORMAT_PLAIN), Lzd_old%Llr(ilr)%wfd%nvctr_c, Lzd_old%Llr(ilr)%wfd%nvctr_f, &
                   Lzd_old%Llr(ilr)%d%n1, Lzd_old%Llr(ilr)%d%n2, Lzd_old%Llr(ilr)%d%n3, phi_array_old(iorbp)%psig, lstat, error)
              if (.not. lstat) call io_error(trim(error))
              call timing(iproc,'readtmbfiles','OF')

              call timing(iproc,'tmbrestart','ON')

              ! DEBUG: print*,iproc,iorb,iorb+orbs%isorb,iorb_old,iorb_out

              !! define fragment transformation - should eventually be done automatically...
              !! first fragment is shifted only, hack here that second fragment should be rotated
              !if (ifrag==1) then
              !   frag_trans_orb(iorbp)%theta=0.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
              !   frag_trans_orb(iorbp)%rot_axis=(/1.0_gp,0.0_gp,0.0_gp/)
              !   frag_trans_orb(iorbp)%rot_center(:)=rxyz_old(:,iiat)
              !   frag_trans_orb(iorbp)%rot_center_new(:)=rxyz(:,iiat)
              !else
              !   ! unnecessary recalculation here, to be tidied later
              !   mol_centre=0.0d0
              !   mol_centre_new=0.0d0
              !   do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
              !      mol_centre(:)=mol_centre(:)+rxyz_old(:,isfat+iat)
              !      mol_centre_new(:)=mol_centre_new(:)+rxyz(:,isfat+iat)
              !   end do
              !   mol_centre=mol_centre/real(ref_frags(ifrag_ref)%astruct_frg%nat,gp)
              !   mol_centre_new=mol_centre_new/real(ref_frags(ifrag_ref)%astruct_frg%nat,gp)
              !   frag_trans_orb(iorbp)%theta=30.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
              !   frag_trans_orb(iorbp)%rot_axis=(/1.0_gp,0.0_gp,0.0_gp/)
              !   frag_trans_orb(iorbp)%rot_center(:)=mol_centre(:) ! take as average for now
              !   frag_trans_orb(iorbp)%rot_center_new(:)=mol_centre_new(:) ! to get shift, mol is rigidly shifted so could take any, rather than centre
              !end if
              !write(*,'(a,x,2(i2,x),4(f5.2,x),6(f7.3,x))'),'trans',ifrag,iiorb,frag_trans_orb(iorbp)%theta,&
              !     frag_trans_orb(iorbp)%rot_axis, &
              !     frag_trans_orb(iorbp)%rot_center,frag_trans_orb(iorbp)%rot_center_new

              if (.not. lstat) then
                 call yaml_warning(trim(error))
                 stop
              end if
              if (iorb_old /= iorb_out) then
                 call yaml_warning('Initialize_linear_from_file')
                 stop
              end if
              close(unitwf)
              
           end do
        end do loop_iorb
     end do loop_iforb
     isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
     isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat        
  end do

  ! reformat fragments
  nullify(psi_old)

  !if several fragments do this, otherwise find 3 nearest neighbours (use sort in time.f90) and send rxyz arrays with 4 atoms

  if (input_frag%nfrag>1) then
     ! Find fragment transformations for each fragment, then put in frag_trans array for each orb
     allocate(frag_trans_frag(input_frag%nfrag))

     isfat=0
     isforb=0
     do ifrag=1,input_frag%nfrag
        ! find reference fragment this corresponds to
        ifrag_ref=input_frag%frag_index(ifrag)

        ! check if we need this fragment transformation on this proc
        skip=.true.
        do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
           do iorbp=1,tmb%orbs%norbp
              iiorb=iorbp+tmb%orbs%isorb
              ! check if this ref frag orbital corresponds to the orbital we want
              if (iiorb==iforb+isforb) then
                 skip=.false.
                 exit
              end if
           end do
        end do

        if (skip) then
           isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat     
           isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
           cycle
        end if

        rxyz_ref = f_malloc((/ 3, ref_frags(ifrag_ref)%astruct_frg%nat /),id='rxyz_ref')
        rxyz_new = f_malloc((/ 3, ref_frags(ifrag_ref)%astruct_frg%nat /),id='rxyz_new')

        do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
           rxyz_new(:,iat)=rxyz(:,isfat+iat)
           rxyz_ref(:,iat)=rxyz_old(:,isfat+iat)
        end do

        ! use center of fragment for now, could later change to center of symmetry
        frag_trans_frag(ifrag)%rot_center=frag_center(ref_frags(ifrag_ref)%astruct_frg%nat,rxyz_ref)
        frag_trans_frag(ifrag)%rot_center_new=frag_center(ref_frags(ifrag_ref)%astruct_frg%nat,rxyz_new)

        ! shift rxyz wrt center of rotation
        do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
           rxyz_ref(:,iat)=rxyz_ref(:,iat)-frag_trans_frag(ifrag)%rot_center
           rxyz_new(:,iat)=rxyz_new(:,iat)-frag_trans_frag(ifrag)%rot_center_new
        end do

        call find_frag_trans(ref_frags(ifrag_ref)%astruct_frg%nat,rxyz_ref,rxyz_new,frag_trans_frag(ifrag))

        call f_free(rxyz_ref)
        call f_free(rxyz_new)

!!$        write(*,'(A,I3,1x,I3,1x,3(F12.6,1x),F12.6)') 'ifrag,ifrag_ref,rot_axis,theta',&
!!$             ifrag,ifrag_ref,frag_trans_frag(ifrag)%rot_axis,frag_trans_frag(ifrag)%theta/(4.0_gp*atan(1.d0)/180.0_gp)
!!$        call yaml_map('Rmat again',frag_trans_frag(ifrag)%Rmat)

        isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat     
        isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
     end do

     allocate(frag_trans_orb(tmb%orbs%norbp))

     isforb=0
     isfat=0
     do ifrag=1,input_frag%nfrag
        ! find reference fragment this corresponds to
        ifrag_ref=input_frag%frag_index(ifrag)
        ! loop over orbitals of this fragment
        do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
           do iorbp=1,tmb%orbs%norbp
              iiorb=iorbp+tmb%orbs%isorb
              ! check if this ref frag orbital corresponds to the orbital we want
              if (iiorb/=iforb+isforb) cycle

              frag_trans_orb(iorbp)%rot_center=frag_trans_frag(ifrag)%rot_center
              frag_trans_orb(iorbp)%rot_center_new=frag_trans_frag(ifrag)%rot_center_new

              !!!!!!!!!!!!!
              iiat=tmb%orbs%onwhichatom(iiorb)

              ! use atom position
              frag_trans_orb(iorbp)%rot_center=rxyz_old(:,iiat)
              frag_trans_orb(iorbp)%rot_center_new=rxyz(:,iiat)
              !!!!!!!!!!!!!

              frag_trans_orb(iorbp)%rot_axis=(frag_trans_frag(ifrag)%rot_axis)
              frag_trans_orb(iorbp)%theta=frag_trans_frag(ifrag)%theta
              frag_trans_orb(iorbp)%Rmat=frag_trans_frag(ifrag)%Rmat

              !write(*,'(a,x,2(i2,x),4(f5.2,x),6(f7.3,x))'),'trans2',ifrag,iiorb,frag_trans_orb(iorbp)%theta,&
              !     frag_trans_orb(iorbp)%rot_axis, &
              !     frag_trans_orb(iorbp)%rot_center,frag_trans_orb(iorbp)%rot_center_new
           end do
        end do
        isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
        isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat     
     end do

     deallocate(frag_trans_frag)
  else
     ! only 1 'fragment', calculate rotation/shift atom wise, using nearest neighbours
     allocate(frag_trans_orb(tmb%orbs%norbp))

     rxyz4_ref = f_malloc((/ 3, min(4, ref_frags(ifrag_ref)%astruct_frg%nat) /),id='rxyz4_ref')
     rxyz4_new = f_malloc((/ 3, min(4, ref_frags(ifrag_ref)%astruct_frg%nat) /),id='rxyz4_new')

     isforb=0
     isfat=0
     do ifrag=1,input_frag%nfrag
        ! find reference fragment this corresponds to
        ifrag_ref=input_frag%frag_index(ifrag)

        rxyz_ref = f_malloc((/ 3, ref_frags(ifrag_ref)%astruct_frg%nat /),id='rxyz_ref')
        rxyz_new = f_malloc((/ 3, ref_frags(ifrag_ref)%astruct_frg%nat /),id='rxyz_new')
        dist = f_malloc(ref_frags(ifrag_ref)%astruct_frg%nat,id='dist')
        ipiv = f_malloc(ref_frags(ifrag_ref)%astruct_frg%nat,id='ipiv')

        ! loop over orbitals of this fragment
        do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
           do iorbp=1,tmb%orbs%norbp
              iiorb=iorbp+tmb%orbs%isorb
              if (iiorb/=iforb+isforb) cycle

              do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
                 rxyz_new(:,iat)=rxyz(:,isfat+iat)
                 rxyz_ref(:,iat)=rxyz_old(:,isfat+iat)
              end do

              iiat=tmb%orbs%onwhichatom(iiorb)

              ! use atom position
              frag_trans_orb(iorbp)%rot_center=rxyz_old(:,iiat)
              frag_trans_orb(iorbp)%rot_center_new=rxyz(:,iiat)

              ! shift rxyz wrt center of rotation
              do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
                 rxyz_ref(:,iat)=rxyz_ref(:,iat)-frag_trans_orb(iorbp)%rot_center
                 rxyz_new(:,iat)=rxyz_new(:,iat)-frag_trans_orb(iorbp)%rot_center_new
              end do

              ! find distances from this atom
              do iat=1,ref_frags(ifrag_ref)%astruct_frg%nat
                   dist(iat)=-dsqrt(rxyz_ref(1,iat)**2+rxyz_ref(2,iat)**2+rxyz_ref(3,iat)**2)
              end do             

              ! sort atoms into neighbour order
              call sort_positions(ref_frags(ifrag_ref)%astruct_frg%nat,dist,ipiv)

              ! take atom and 3 nearest neighbours
              do iat=1,min(4,ref_frags(ifrag_ref)%astruct_frg%nat)
                 rxyz4_ref(:,iat)=rxyz_ref(:,ipiv(iat))
                 rxyz4_new(:,iat)=rxyz_new(:,ipiv(iat))
              end do

              call find_frag_trans(min(4,ref_frags(ifrag_ref)%astruct_frg%nat),rxyz4_ref,rxyz4_new,frag_trans_orb(iorbp))

!!$              print *,'transformation of the fragment, iforb',iforb
!!$              write(*,'(A,I3,1x,I3,1x,3(F12.6,1x),F12.6)') 'ifrag,iorb,rot_axis,theta',&
!!$                   ifrag,iiorb,frag_trans_orb(iorbp)%rot_axis,frag_trans_orb(iorbp)%theta/(4.0_gp*atan(1.d0)/180.0_gp)

           end do
        end do
        isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
        isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat     

        call f_free(ipiv)
        call f_free(dist)
        call f_free(rxyz_ref)
        call f_free(rxyz_new)

     end do

     call f_free(rxyz4_ref)
     call f_free(rxyz4_new)

  end if

  call timing(iproc,'tmbrestart','OF')
  call reformat_supportfunctions(iproc,nproc,&
       at,rxyz_old,rxyz,.false.,tmb,ndim_old,lzd_old,frag_trans_orb,&
       psi_old,trim(dir_output),input_frag,ref_frags,phi_array_old)
  call timing(iproc,'tmbrestart','ON')

  deallocate(frag_trans_orb)

  do iorbp=1,tmb%orbs%norbp
     !nullify/deallocate here as appropriate, in future may keep
     call f_free_ptr(phi_array_old(iorbp)%psig)
  end do

  deallocate(phi_array_old)
  call f_free(rxyz_old)
  call deallocate_local_zone_descriptors(lzd_old)

!!$  ! DEBUG - plot in global box - CHECK WITH REFORMAT ETC IN LRs
!!$  ind=1
!!$  gpsi=f_malloc(tmb%Lzd%glr%wfd%nvctr_c+7*tmb%Lzd%glr%wfd%nvctr_f,id='gpsi')
!!$  do iorbp=1,tmb%orbs%norbp
!!$     iiorb=iorbp+tmb%orbs%isorb
!!$     ilr = tmb%orbs%inwhichlocreg(iiorb)
!!$  
!!$     call to_zero(tmb%Lzd%glr%wfd%nvctr_c+7*tmb%Lzd%glr%wfd%nvctr_f,gpsi)
!!$     call Lpsi_to_global2(iproc, tmb%Lzd%Llr(ilr)%wfd%nvctr_c+7*tmb%Lzd%Llr(ilr)%wfd%nvctr_f, &
!!$          tmb%Lzd%glr%wfd%nvctr_c+7*tmb%Lzd%glr%wfd%nvctr_f, &
!!$          1, 1, 1, tmb%Lzd%glr, tmb%Lzd%Llr(ilr), tmb%psi(ind), gpsi)
!!$   
!!$     call plot_wf(trim(dir_output)//trim(adjustl(yaml_toa(iiorb))),1,at,1.0_dp,tmb%Lzd%glr,&
!!$          tmb%Lzd%hgrids(1),tmb%Lzd%hgrids(2),tmb%Lzd%hgrids(3),rxyz,gpsi)
!!$     !call plot_wf(trim(adjustl(orbname)),1,at,1.0_dp,tmb%Lzd%Llr(ilr),&
!!$     !     tmb%Lzd%hgrids(1),tmb%Lzd%hgrids(2),tmb%Lzd%hgrids(3),rxyz,tmb%psi)
!!$   
!!$     ind = ind + tmb%Lzd%Llr(ilr)%wfd%nvctr_c+7*tmb%Lzd%Llr(ilr)%wfd%nvctr_f
!!$  end do
!!$  call f_free(gpsi)
!!$  ! END DEBUG 


  ! Read the coefficient file for each fragment and assemble total coeffs
  ! coeffs should eventually go into ref_frag array and then point? or be copied to (probably copied as will deallocate frag)
  unitwf=99
  isforb=0
  do ifrag=1,input_frag%nfrag
     ! find reference fragment this corresponds to
     ifrag_ref=input_frag%frag_index(ifrag)

     full_filename=trim(dir_output)//trim(input_frag%dirname(ifrag_ref))//trim(filename)//'_coeff.bin'

     if(iformat == WF_FORMAT_PLAIN) then
        open(unitwf,file=trim(full_filename),status='unknown',form='formatted')
     else if(iformat == WF_FORMAT_BINARY) then
        open(unitwf,file=trim(full_filename),status='unknown',form='unformatted')
     else
        stop 'Coefficient format not implemented'
     end if

     !if (input_frag%nfrag>1) then
        call read_coeff_minbasis(unitwf,(iformat == WF_FORMAT_PLAIN),iproc,ref_frags(ifrag_ref)%fbasis%forbs%norb,&
             ref_frags(ifrag_ref)%nelec,ref_frags(ifrag_ref)%coeff,ref_frags(ifrag_ref)%eval)
             !tmb%orbs%eval(isforb+1:isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb))
             !tmb%orbs%eval(isforb+1)
        ! copying of coeffs from fragment to tmb%coeff now occurs after this routine
     !else
     !   call read_coeff_minbasis(unitwf,(iformat == WF_FORMAT_PLAIN),iproc,ref_frags(ifrag_ref)%fbasis%forbs%norb,&
     !        ref_frags(ifrag_ref)%nelec,tmb%coeff,tmb%orbs%eval)
     !end if
     close(unitwf)

     isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
  end do


  call cpu_time(tr1)
  call system_clock(ncount2,ncount_rate,ncount_max)
  tel=dble(ncount2-ncount1)/dble(ncount_rate)

  if (iproc == 0) then
     call yaml_sequence_open('Reading Waves Time')
     call yaml_sequence(advance='no')
     call yaml_mapping_open(flow=.true.)
     call yaml_map('Process',iproc)
     call yaml_map('Timing',(/ real(tr1-tr0,kind=8),tel /),fmt='(1pe10.3)')
     call yaml_mapping_close()
     call yaml_sequence_close()
  end if
  !write(*,'(a,i4,2(1x,1pe10.3))') '- READING WAVES TIME',iproc,tr1-tr0,tel
  call timing(iproc,'tmbrestart','OF')

END SUBROUTINE readmywaves_linear_new


!> Initializes onwhichatom, inwhichlocreg, locrad and locregcenter from file
subroutine initialize_linear_from_file(iproc,nproc,input_frag,astruct,rxyz,orbs,Lzd,iformat,&
     dir_output,filename,ref_frags,orblist)
  use module_base
  use module_types
  use module_defs
  use yaml_output
  use module_fragments
  use module_interfaces, except_this_one => initialize_linear_from_file
  use locregs, only: locreg_null
  implicit none
  integer, intent(in) :: iproc, nproc, iformat
  type(fragmentInputParameters),intent(in) :: input_frag
  type(atomic_structure), intent(in) :: astruct
  real(gp), dimension(3,astruct%nat), intent(in) :: rxyz
  type(orbitals_data), intent(inout) :: orbs  !< orbs related to the basis functions, inwhichlocreg and onwhichatom generated in this routine
  type(local_zone_descriptors), intent(inout) :: Lzd !< must already contain Glr and hgrids
  type(system_fragment), dimension(input_frag%nfrag_ref), intent(inout) :: ref_frags
  character(len=*), intent(in) :: filename, dir_output
  integer, dimension(orbs%norb), optional :: orblist

  !Local variables
  character(len=*), parameter :: subname='initialize_linear_from_file'
  character(len =256) :: error
  logical :: lstat
  integer :: ilr, iorb_old, iorb, ispinor, iorb_out, iforb, isforb, isfat, iiorb, iorbp, ifrag, ifrag_ref
  integer, dimension(3) :: n_old, ns_old
  integer :: confPotOrder, iat
  real(gp), dimension(3) :: hgrids_old
  real(kind=8) :: eval, confPotprefac
  real(gp), dimension(orbs%norb):: locrad
  real(gp), dimension(3) :: locregCenter
  real(kind=8), dimension(:), allocatable :: lrad
  real(gp), dimension(:,:), allocatable :: cxyz
  character(len=256) :: full_filename

  ! to be fixed
  if (present(orblist)) then
     stop 'orblist no longer functional in initialize_linear_from_file due to addition of fragment calculation'
  end if

  ! NOTES:
  ! The orbs%norb family must be all constructed before this routine
  ! This can be done from the input.lin since the number of basis functions should be fixed.
  ! Fragment structure must also be fully initialized, even if this is not a fragment calculation

  call to_zero(orbs%norb,locrad(1))
  call to_zero(orbs%norb,orbs%onwhichatom(1))

  if (iformat == WF_FORMAT_ETSF) then
     stop 'Linear scaling with ETSF writing not implemented yet'
  else if (iformat == WF_FORMAT_BINARY .or. iformat == WF_FORMAT_PLAIN) then
     ! loop over fragments in current system (will still be treated as one fragment in calculation, just separate for restart)
     isforb=0
     isfat=0
     do ifrag=1,input_frag%nfrag
        ! find reference fragment this corresponds to
        ifrag_ref=input_frag%frag_index(ifrag)
        ! loop over orbitals of this fragment
        loop_iforb: do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
           loop_iorb: do iorbp=1,orbs%norbp
              iiorb=iorbp+orbs%isorb
              ! check if this ref frag orbital corresponds to the orbital we want
              if (iiorb/=iforb+isforb) cycle
              do ispinor=1,orbs%nspinor

                 ! if this is a fragment calculation frag%dirname will contain fragment directory, otherwise it will be empty
                 ! bit of a hack to use orbs here not forbs, but different structures so this is necessary - to clean somehow
                 full_filename=trim(dir_output)//trim(input_frag%dirname(ifrag_ref))//trim(filename)

                 call open_filename_of_iorb(99,(iformat == WF_FORMAT_BINARY),full_filename, &
                      & orbs,iorbp,ispinor,iorb_out,iforb)
                      !& ref_frags(ifrag_ref)%fbasis%forbs,iforb,ispinor,iorb_out)

                 !print *,'before crash',iorbp,trim(full_filename),iiorb,iforb
  
                 call io_read_descr_linear(99,(iformat == WF_FORMAT_PLAIN), iorb_old, eval, n_old(1), n_old(2), n_old(3), &
                      ns_old(1), ns_old(2), ns_old(3), hgrids_old, lstat, error, orbs%onwhichatom(iiorb), &
                      locrad(iiorb), locregCenter, confPotOrder, confPotprefac)

                 orbs%onwhichatom(iiorb) = orbs%onwhichatom(iiorb) + isfat

                 if (.not. lstat) then
                    call yaml_warning(trim(error))
                    stop
                 end if
                 if (iorb_old /= iorb_out) then
                    call yaml_warning('Initialize_linear_from_file')
                    stop
                 end if
                 close(99)
              
              end do
           end do loop_iorb
        end do loop_iforb
        isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
        isfat=isfat+ref_frags(ifrag_ref)%astruct_frg%nat        
     end do
  else
     call yaml_warning('Unknown wavefunction file format from filename.')
     stop
  end if

  Lzd%nlr = orbs%norb

  ! Communication of the quantities
  if (nproc > 1)  call mpiallred(orbs%onwhichatom(1),orbs%norb,MPI_SUM,bigdft_mpi%mpi_comm)
  if (nproc > 1)  call mpiallred(locrad(1),orbs%norb,MPI_SUM,bigdft_mpi%mpi_comm)

  cxyz = f_malloc((/ 3, Lzd%nlr /),id='cxyz')
  lrad = f_malloc(Lzd%nlr,id='lrad')

  ! Put the llr in posinp order
  ilr=0
  do iat=1,astruct%nat
     do iorb=1,orbs%norb
        if(iat == orbs%onwhichatom(iorb)) then
           ilr = ilr + 1
           cxyz(1,ilr) = rxyz(1,iat)
           cxyz(2,ilr) = rxyz(2,iat)
           cxyz(3,ilr) = rxyz(3,iat)
           lrad(ilr) = locrad(iorb)
           orbs%inwhichlocreg(iorb) = ilr
        end if
     end do
  end do
  
  ! Allocate the array of localisation regions
  allocate(lzd%Llr(lzd%nlr))
  do ilr=1,lzd%nlr
     lzd%Llr(ilr)=locreg_null()
  end do
  do ilr=1,lzd%nlr
      lzd%llr(ilr)%locrad=lrad(ilr)
      lzd%llr(ilr)%locregCenter=cxyz(:,ilr)
  end do

  call f_free(cxyz)
  call f_free(lrad)

END SUBROUTINE initialize_linear_from_file


!> Copy old support functions from phi to phi_old
subroutine copy_old_supportfunctions(iproc,orbs,lzd,phi,lzd_old,phi_old)
  use module_base
  use module_types
  use yaml_output
  implicit none
  integer,intent(in) :: iproc
  type(orbitals_data), intent(in) :: orbs
  type(local_zone_descriptors), intent(in) :: lzd
  type(local_zone_descriptors), intent(inout) :: lzd_old
  real(wp), dimension(:), pointer :: phi,phi_old
  !Local variables
  character(len=*), parameter :: subname='copy_old_supportfunctions'
  integer :: iseg,j,ind1,iorb,ii,iiorb,ilr
  real(kind=8) :: tt

  ! First copy global quantities
  call nullify_locreg_descriptors(lzd_old%glr)

  lzd_old%glr%wfd%nvctr_c = lzd%glr%wfd%nvctr_c
  lzd_old%glr%wfd%nvctr_f = lzd%glr%wfd%nvctr_f
  lzd_old%glr%wfd%nseg_c  = lzd%glr%wfd%nseg_c
  lzd_old%glr%wfd%nseg_f  = lzd%glr%wfd%nseg_f

  !allocations
  call allocate_wfd(lzd_old%glr%wfd)

  do iseg=1,lzd_old%glr%wfd%nseg_c+lzd_old%glr%wfd%nseg_f
     lzd_old%glr%wfd%keyglob(1,iseg)    = lzd%glr%wfd%keyglob(1,iseg) 
     lzd_old%glr%wfd%keyglob(2,iseg)    = lzd%glr%wfd%keyglob(2,iseg)
     lzd_old%glr%wfd%keygloc(1,iseg)    = lzd%glr%wfd%keygloc(1,iseg)
     lzd_old%glr%wfd%keygloc(2,iseg)    = lzd%glr%wfd%keygloc(2,iseg)
     lzd_old%glr%wfd%keyvloc(iseg)      = lzd%glr%wfd%keyvloc(iseg)
     lzd_old%glr%wfd%keyvglob(iseg)     = lzd%glr%wfd%keyvglob(iseg)
  enddo
  !!!deallocation
  !!call deallocate_wfd(lzd%glr%wfd,subname)

  !!lzd_old%glr%d%n1 = lzd%glr%d%n1
  !!lzd_old%glr%d%n2 = lzd%glr%d%n2
  !!lzd_old%glr%d%n3 = lzd%glr%d%n3
  call copy_grid_dimensions(lzd%glr%d, lzd_old%glr%d)


  lzd_old%nlr=lzd%nlr
  nullify(lzd_old%llr)
  allocate(lzd_old%llr(lzd_old%nlr))
  do ilr=1,lzd_old%nlr
      call nullify_locreg_descriptors(lzd_old%llr(ilr))
  end do

  lzd_old%hgrids(1)=lzd%hgrids(1)
  lzd_old%hgrids(2)=lzd%hgrids(2)
  lzd_old%hgrids(3)=lzd%hgrids(3)
 
  !!ii=0
  !!do ilr=1,lzd_old%nlr

  !!    ! Now copy local quantities

  !!    lzd_old%llr(ilr)%wfd%nvctr_c = lzd%llr(ilr)%wfd%nvctr_c
  !!    lzd_old%llr(ilr)%wfd%nvctr_f = lzd%llr(ilr)%wfd%nvctr_f
  !!    lzd_old%llr(ilr)%wfd%nseg_c  = lzd%llr(ilr)%wfd%nseg_c
  !!    lzd_old%llr(ilr)%wfd%nseg_f  = lzd%llr(ilr)%wfd%nseg_f

  !!    !allocations
  !!    call allocate_wfd(lzd_old%llr(ilr)%wfd,subname)

  !!    do iseg=1,lzd_old%llr(ilr)%wfd%nseg_c+lzd_old%llr(ilr)%wfd%nseg_f
  !!       lzd_old%llr(ilr)%wfd%keyglob(1,iseg)    = lzd%llr(ilr)%wfd%keyglob(1,iseg) 
  !!       lzd_old%llr(ilr)%wfd%keyglob(2,iseg)    = lzd%llr(ilr)%wfd%keyglob(2,iseg)
  !!       lzd_old%llr(ilr)%wfd%keygloc(1,iseg)    = lzd%llr(ilr)%wfd%keygloc(1,iseg)
  !!       lzd_old%llr(ilr)%wfd%keygloc(2,iseg)    = lzd%llr(ilr)%wfd%keygloc(2,iseg)
  !!       lzd_old%llr(ilr)%wfd%keyvloc(iseg)      = lzd%llr(ilr)%wfd%keyvloc(iseg)
  !!       lzd_old%llr(ilr)%wfd%keyvglob(iseg)     = lzd%llr(ilr)%wfd%keyvglob(iseg)
  !!    enddo
  !!    !!!deallocation
  !!    !!call deallocate_wfd(lzd%llr(ilr)%wfd,subname)

  !!    !!lzd_old%llr(ilr)%d%n1 = lzd%llr(ilr)%d%n1
  !!    !!lzd_old%llr(ilr)%d%n2 = lzd%llr(ilr)%d%n2
  !!    !!lzd_old%llr(ilr)%d%n3 = lzd%llr(ilr)%d%n3
  !!    call copy_grid_dimensions(lzd%llr(ilr)%d, lzd_old%llr(ilr)%d)

  !!    ii = ii + lzd_old%llr(ilr)%wfd%nvctr_c + 7*lzd_old%llr(ilr)%wfd%nvctr_f

  !!end do

  ii=0
  do iorb=1,orbs%norbp
      iiorb=orbs%isorb+iorb
      ilr=orbs%inwhichlocreg(iiorb)
      call copy_locreg_descriptors(lzd%llr(ilr), lzd_old%llr(ilr))
      ii = ii + lzd_old%llr(ilr)%wfd%nvctr_c + 7*lzd_old%llr(ilr)%wfd%nvctr_f
  end do

  phi_old = f_malloc_ptr(ii,id='phi_old')

  ! Now copy the suport functions
  if (iproc==0) call yaml_map('Check the normalization of the support functions, tolerance',1.d-3,fmt='(1es12.4)')
  ind1=0
  do iorb=1,orbs%norbp
      tt=0.d0
      iiorb=orbs%isorb+iorb
      ilr=orbs%inwhichlocreg(iiorb)
      do j=1,lzd_old%llr(ilr)%wfd%nvctr_c+7*lzd_old%llr(ilr)%wfd%nvctr_f
          ind1=ind1+1
          phi_old(ind1)=phi(ind1)
          tt=tt+real(phi(ind1),kind=8)**2
      end do
      tt=sqrt(tt)
      if (abs(tt-1.d0) > 1.d-3) then
         !write(*,*)'wrong phi_old',iiorb,tt
         call yaml_warning('support function, value:'//trim(yaml_toa(iiorb,fmt='(i6)'))//trim(yaml_toa(tt,fmt='(1es18.9)')))
         !stop 
      end if
  end do
!  if (iproc==0) call yaml_mapping_close()

  !!!deallocation
  !!i_all=-product(shape(phi))*kind(phi)
  !!deallocate(phi,stat=i_stat)
  !!call memocc(i_stat,i_all,'phi',subname)

END SUBROUTINE copy_old_supportfunctions


subroutine copy_old_coefficients(norb_tmb, coeff, coeff_old)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in):: norb_tmb
  real(8),dimension(:,:),pointer:: coeff, coeff_old

  ! Local variables
  character(len=*),parameter:: subname='copy_old_coefficients'
!  integer:: istat,iall

  coeff_old = f_malloc_ptr((/ norb_tmb, norb_tmb /),id='coeff_old')

  call vcopy(norb_tmb*norb_tmb, coeff(1,1), 1, coeff_old(1,1), 1)

  !!iall=-product(shape(coeff))*kind(coeff)
  !!deallocate(coeff,stat=istat)
  !!call memocc(istat,iall,'coeff',subname)

END SUBROUTINE copy_old_coefficients


subroutine copy_old_inwhichlocreg(norb_tmb, inwhichlocreg, inwhichlocreg_old, onwhichatom, onwhichatom_old)
  use module_base
  implicit none

  ! Calling arguments
  integer,intent(in):: norb_tmb
  integer,dimension(:),pointer:: inwhichlocreg, inwhichlocreg_old, onwhichatom, onwhichatom_old

  ! Local variables
  character(len=*),parameter:: subname='copy_old_inwhichlocreg'
  !integer :: istat, iall

  inwhichlocreg_old = f_malloc_ptr(norb_tmb,id='inwhichlocreg_old')
  call vcopy(norb_tmb, inwhichlocreg(1), 1, inwhichlocreg_old(1), 1)
  !!iall=-product(shape(inwhichlocreg))*kind(inwhichlocreg)
  !!deallocate(inwhichlocreg,stat=istat)
  !!call memocc(istat,iall,'inwhichlocreg',subname)


  onwhichatom_old = f_malloc_ptr(norb_tmb,id='onwhichatom_old')
  call vcopy(norb_tmb, onwhichatom(1), 1, onwhichatom_old(1), 1)
  !!iall=-product(shape(onwhichatom))*kind(onwhichatom)
  !!deallocate(onwhichatom,stat=istat)
  !!call memocc(istat,iall,'onwhichatom',subname)

END SUBROUTINE copy_old_inwhichlocreg


!> Reformat wavefunctions if the mesh have changed (in a restart)
!! NB add_derivatives must be false if we are using phi_array_old instead of psi_old and don't have the keys
subroutine reformat_supportfunctions(iproc,nproc,at,rxyz_old,rxyz,add_derivatives,tmb,ndim_old,lzd_old,&
       frag_trans,psi_old,input_dir,input_frag,ref_frags,phi_array_old)
  use module_base
  use module_types
  use module_fragments
  use module_interfaces, except_this_one=>reformat_supportfunctions
  implicit none
  integer, intent(in) :: iproc,nproc
  integer, intent(in) :: ndim_old
  type(atoms_data), intent(in) :: at
  real(gp), dimension(3,at%astruct%nat), intent(in) :: rxyz,rxyz_old
  type(DFT_wavefunction), intent(inout) :: tmb
  type(local_zone_descriptors), intent(inout) :: lzd_old
  type(fragment_transformation), dimension(tmb%orbs%norbp), intent(in) :: frag_trans
  real(wp), dimension(:), pointer :: psi_old
  type(phi_array), dimension(tmb%orbs%norbp), optional, intent(in) :: phi_array_old
  logical, intent(in) :: add_derivatives
  character(len=*), intent(in) :: input_dir
  type(fragmentInputParameters), intent(in) :: input_frag
  type(system_fragment), dimension(:), intent(in) :: ref_frags
  !Local variables
  character(len=*), parameter :: subname='reformatmywaves'
  logical :: reformat
  integer :: iorb,j,jstart,jstart_old,iiorb,ilr,iiat
  integer:: idir,jstart_old_der,ncount,ilr_old
  !!integer :: i
  integer, dimension(3) :: ns_old,ns,n_old,n
  real(gp), dimension(3) :: centre_old_box,centre_new_box,da
  real(gp) :: tt,tol
  real(wp), dimension(:,:,:,:,:,:), pointer :: phigold
  real(wp), dimension(:), allocatable :: phi_old_der
  integer, dimension(0:6) :: reformat_reason
  character(len=12) :: orbname!, dummy
  real(wp), allocatable, dimension(:,:,:) :: psirold
  logical :: psirold_ok
  integer, dimension(3) :: nl, nr
  logical, dimension(3) :: per
  character(len=100) :: fragdir
  integer :: ifrag, ifrag_ref, iforb, isforb
  real(kind=gp), dimension(:,:,:), allocatable :: workarraytmp 

  real(gp), external :: dnrm2
!  integer :: iat

  reformat_reason=0
  tol=1.d-3

  ! Get the derivatives of the support functions
  if (add_derivatives) then
     phi_old_der = f_malloc(3*ndim_old,id='phi_old_der')
     if (.not. associated(psi_old)) stop 'psi_old not associated in reformat_supportfunctions'
     call get_derivative_supportfunctions(ndim_old, lzd_old%hgrids(1), lzd_old, tmb%orbs, psi_old, phi_old_der)
     jstart_old_der=1
  end if

  jstart_old=1
  jstart=1
  do iorb=1,tmb%orbs%norbp
      iiorb=tmb%orbs%isorb+iorb
      ilr=tmb%orbs%inwhichlocreg(iiorb)
      iiat=tmb%orbs%onwhichatom(iiorb)

      ilr_old=ilr

      n_old(1)=lzd_old%Llr(ilr_old)%d%n1
      n_old(2)=lzd_old%Llr(ilr_old)%d%n2
      n_old(3)=lzd_old%Llr(ilr_old)%d%n3
      n(1)=tmb%lzd%Llr(ilr)%d%n1
      n(2)=tmb%lzd%Llr(ilr)%d%n2
      n(3)=tmb%lzd%Llr(ilr)%d%n3
      ns_old(1)=lzd_old%Llr(ilr_old)%ns1
      ns_old(2)=lzd_old%Llr(ilr_old)%ns2
      ns_old(3)=lzd_old%Llr(ilr_old)%ns3
      ns(1)=tmb%lzd%Llr(ilr)%ns1
      ns(2)=tmb%lzd%Llr(ilr)%ns2
      ns(3)=tmb%lzd%Llr(ilr)%ns3

      !theta=frag_trans(iorb)%theta!0.0d0*(4.0_gp*atan(1.d0)/180.0_gp)
      !newz=frag_trans(iorb)%rot_axis!(/1.0_gp,0.0_gp,0.0_gp/)
      !centre_old(:)=frag_trans(iorb)%rot_center(:)!rxyz_old(:,iiat)
      !shift(:)=frag_trans(iorb)%dr(:)!rxyz(:,iiat)

      call reformat_check(reformat,reformat_reason,tol,at,lzd_old%hgrids,tmb%lzd%hgrids,&
           lzd_old%llr(ilr_old)%wfd%nvctr_c,lzd_old%llr(ilr_old)%wfd%nvctr_f,&
           tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%nvctr_f,&
           n_old,n,ns_old,ns,frag_trans(iorb),centre_old_box,centre_new_box,da)  
!reformat=.true. !!!!temporary hack
      ! just copy psi from old to new as reformat not necessary
      if (.not. reformat) then 

          ! copy from phi_array_old, can use new keys as they should be identical to old keys
          if (present(phi_array_old)) then 
             call compress_plain(n(1),n(2),0,n(1),0,n(2),0,n(3), &
                  tmb%lzd%llr(ilr)%wfd%nseg_c,tmb%lzd%llr(ilr)%wfd%nvctr_c,tmb%lzd%llr(ilr)%wfd%keygloc(1,1), &
                  tmb%lzd%llr(ilr)%wfd%keyvloc(1),tmb%lzd%llr(ilr)%wfd%nseg_f,tmb%lzd%llr(ilr)%wfd%nvctr_f,&
                  tmb%lzd%llr(ilr)%wfd%keygloc(1,tmb%lzd%llr(ilr)%wfd%nseg_c+min(1,tmb%lzd%llr(ilr)%wfd%nseg_f)),&
                  tmb%lzd%llr(ilr)%wfd%keyvloc(tmb%lzd%llr(ilr)%wfd%nseg_c+min(1,tmb%lzd%llr(ilr)%wfd%nseg_f)),   &
                  phi_array_old(iorb)%psig,tmb%psi(jstart),&
                  tmb%psi(jstart+tmb%lzd%llr(ilr)%wfd%nvctr_c+min(1,tmb%lzd%llr(ilr)%wfd%nvctr_f)-1))
             jstart=jstart+tmb%lzd%llr(ilr)%wfd%nvctr_c+7*tmb%lzd%llr(ilr)%wfd%nvctr_f

          ! directly copy psi_old to psi, first check psi_old is actually allocated
          else 
             if (.not. associated(psi_old)) stop 'psi_old not associated in reformat_supportfunctions'
             do j=1,lzd_old%llr(ilr_old)%wfd%nvctr_c
                tmb%psi(jstart)=psi_old(jstart_old)
                jstart=jstart+1
                jstart_old=jstart_old+1
             end do
             do j=1,7*lzd_old%llr(ilr_old)%wfd%nvctr_f-6,7
                tmb%psi(jstart+0)=psi_old(jstart_old+0)
                tmb%psi(jstart+1)=psi_old(jstart_old+1)
                tmb%psi(jstart+2)=psi_old(jstart_old+2)
                tmb%psi(jstart+3)=psi_old(jstart_old+3)
                tmb%psi(jstart+4)=psi_old(jstart_old+4)
                tmb%psi(jstart+5)=psi_old(jstart_old+5)
                tmb%psi(jstart+6)=psi_old(jstart_old+6)
                jstart=jstart+7
                jstart_old=jstart_old+7
            end do
         
         end if
      else
          ! Add the derivatives to the basis functions
          if (add_derivatives) then
             do idir=1,3
                 tt=rxyz(idir,iiat)-rxyz_old(idir,iiat)
                 ncount = lzd_old%llr(ilr_old)%wfd%nvctr_c+7*lzd_old%llr(ilr_old)%wfd%nvctr_f
                 call daxpy(ncount, tt, phi_old_der(jstart_old_der), 1, psi_old(jstart_old), 1)
                 jstart_old_der = jstart_old_der + ncount
             end do
          end if

!!$          print*, 'norm of read psi ',dnrm2(lzd_old%llr(ilr_old)%wfd%nvctr_c+7*lzd_old%llr(ilr_old)%wfd%nvctr_f,&
!!$               psi_old(jstart_old),1),&
!!$               lzd_old%llr(ilr_old)%wfd%nvctr_c,lzd_old%llr(ilr_old)%wfd%nvctr_f
!!$          print*, 'norm of read psic ',dnrm2(lzd_old%llr(ilr_old)%wfd%nvctr_c,psi_old(jstart_old),1)
!!$          print*, 'norm of read psif ',dnrm2(lzd_old%llr(ilr_old)%wfd%nvctr_f*7,&
!!$               psi_old(jstart_old-1+lzd_old%llr(ilr_old)%wfd%nvctr_c+min(1,lzd_old%llr(ilr_old)%wfd%nvctr_f)),1)


          ! uncompress or point towards correct phigold as necessary
          if (present(phi_array_old)) then
             phigold=>phi_array_old(iorb)%psig
          else
             phigold = f_malloc_ptr((/ 0.to.n_old(1), 1.to.2, 0.to.n_old(2), 1.to.2, 0.to.n_old(3), 1.to.2 /),id='phigold')
             call psi_to_psig(n_old,lzd_old%llr(ilr_old)%wfd%nvctr_c,lzd_old%llr(ilr_old)%wfd%nvctr_f,&
                  lzd_old%llr(ilr_old)%wfd%nseg_c,lzd_old%llr(ilr_old)%wfd%nseg_f,&
                  lzd_old%llr(ilr_old)%wfd%keyvloc,lzd_old%llr(ilr_old)%wfd%keygloc,&
                  jstart_old,psi_old(jstart_old),phigold)
          end if
   
          !write(100+iproc,*) 'norm phigold ',dnrm2(8*(n1_old+1)*(n2_old+1)*(n3_old+1),phigold,1)
          !write(*,*) 'iproc,norm phigold ',iproc,dnrm2(8*product(n_old+1),phigold,1)

          ! read psir_old directly from files (don't have lzd_old to rebuild it)
          psirold_ok=.true.

          ! allow for fragment calculation
          if (input_frag%nfrag>1) then
             isforb=0
             do ifrag=1,input_frag%nfrag
                ! find reference fragment this corresponds to
                ifrag_ref=input_frag%frag_index(ifrag)
                ! loop over orbitals of this fragment
                do iforb=1,ref_frags(ifrag_ref)%fbasis%forbs%norb
                   if (iiorb==iforb+isforb) exit
                end do
                if (iforb/=ref_frags(ifrag_ref)%fbasis%forbs%norb+1) exit
                isforb=isforb+ref_frags(ifrag_ref)%fbasis%forbs%norb
             end do
             write(orbname,*) iforb
             fragdir=trim(input_frag%dirname(ifrag_ref))
          else
             write(orbname,*) iiorb
             fragdir=trim(input_frag%dirname(1))
          end if

          !! first check if file exists
          !inquire(file=trim(input_dir)//trim(fragdir)//'tmbisf'//trim(adjustl(orbname))//'.dat',exist=psirold_ok)
          !if (.not. psirold_ok) print*,"psirold doesn't exist for reformatting",iiorb,&
          !     trim(input_dir)//'tmbisf'//trim(adjustl(orbname))//'.dat'

          !! read in psirold
          !if (psirold_ok) then
          !   call timing(iproc,'readisffiles','ON')
          !   open(99,file=trim(input_dir)//trim(fragdir)//'tmbisf'//trim(adjustl(orbname))//'.dat',&
          !        form="unformatted",status='unknown')
          !   read(99) dummy
          !   read(99) lzd_old%llr(ilr_old)%d%n1i,lzd_old%llr(ilr_old)%d%n2i,lzd_old%llr(ilr_old)%d%n3i
          !   read(99) lzd_old%llr(ilr_old)%nsi1,lzd_old%llr(ilr_old)%nsi2,lzd_old%llr(ilr_old)%nsi3
          !   psirold=f_malloc((/lzd_old%llr(ilr_old)%d%n1i,lzd_old%llr(ilr_old)%d%n2i,lzd_old%llr(ilr_old)%d%n3i/),id='psirold')
          !   do k=1,lzd_old%llr(ilr_old)%d%n3i
          !      do j=1,lzd_old%llr(ilr_old)%d%n2i
          !         do i=1,lzd_old%llr(ilr_old)%d%n1i
          !            read(99) psirold(i,j,k)
          !         end do
          !      end do
          !   end do
          !   close(99)
          !   call timing(iproc,'readisffiles','OF')
          !end if

          lzd_old%llr(ilr_old)%nsi1=2*lzd_old%llr(ilr_old)%ns1
          lzd_old%llr(ilr_old)%nsi2=2*lzd_old%llr(ilr_old)%ns2
          lzd_old%llr(ilr_old)%nsi3=2*lzd_old%llr(ilr_old)%ns3

          lzd_old%llr(ilr_old)%d%n1i=2*n_old(1)+31
          lzd_old%llr(ilr_old)%d%n2i=2*n_old(2)+31
          lzd_old%llr(ilr_old)%d%n3i=2*n_old(3)+31

          psirold_ok=.true.
          workarraytmp=f_malloc((2*n_old+31),id='workarraytmp')
          psirold=f_malloc((2*n_old+31),id='psirold')

          call to_zero((2*n_old(1)+31)*(2*n_old(2)+31)*(2*n_old(3)+31),psirold(1,1,1))
          call vcopy((2*n_old(1)+2)*(2*n_old(2)+2)*(2*n_old(3)+2),phigold(0,1,0,1,0,1),1,psirold(1,1,1),1)
          call psig_to_psir_free(n_old(1),n_old(2),n_old(3),workarraytmp,psirold)
          call f_free(workarraytmp)

          !write(*,*) 'iproc,norm psirold ',iproc,dnrm2(product(2*n_old+31),psirold,1),2*n_old+31
                    
          call timing(iproc,'Reformatting ','ON')
          if (psirold_ok) then
             !print*,'using psirold to reformat',iiorb
             ! recalculate centres
             !conditions for periodicity in the three directions
             per(1)=(at%astruct%geocode /= 'F')
             per(2)=(at%astruct%geocode == 'P')
             per(3)=(at%astruct%geocode /= 'F')

             !buffers related to periodicity
             !WARNING: the boundary conditions are not assumed to change between new and old
             call ext_buffers(per(1),nl(1),nr(1))
             call ext_buffers(per(2),nl(2),nr(2))
             call ext_buffers(per(3),nl(3),nr(3))

             ! centre of rotation with respect to start of box
             centre_old_box(1)=frag_trans(iorb)%rot_center(1)-0.5d0*lzd_old%hgrids(1)*(lzd_old%llr(ilr_old)%nsi1-nl(1))
             centre_old_box(2)=frag_trans(iorb)%rot_center(2)-0.5d0*lzd_old%hgrids(2)*(lzd_old%llr(ilr_old)%nsi2-nl(2))
             centre_old_box(3)=frag_trans(iorb)%rot_center(3)-0.5d0*lzd_old%hgrids(3)*(lzd_old%llr(ilr_old)%nsi3-nl(3))

             centre_new_box(1)=frag_trans(iorb)%rot_center_new(1)-0.5d0*tmb%lzd%hgrids(1)*(tmb%lzd%llr(ilr)%nsi1-nl(1))
             centre_new_box(2)=frag_trans(iorb)%rot_center_new(2)-0.5d0*tmb%lzd%hgrids(2)*(tmb%lzd%llr(ilr)%nsi2-nl(2))
             centre_new_box(3)=frag_trans(iorb)%rot_center_new(3)-0.5d0*tmb%lzd%hgrids(3)*(tmb%lzd%llr(ilr)%nsi3-nl(3))

             da=centre_new_box-centre_old_box-(lzd_old%hgrids-tmb%lzd%hgrids)*0.5d0

             call reformat_one_supportfunction(tmb%lzd%llr(ilr),lzd_old%llr(ilr_old),tmb%lzd%llr(ilr)%geocode,&
                  lzd_old%hgrids,n_old,phigold,tmb%lzd%hgrids,n,centre_old_box,centre_new_box,da,&
                  frag_trans(iorb),tmb%psi(jstart:),psirold)
             call f_free(psirold)
          else ! don't have psirold from file, so reformat using old way
             call reformat_one_supportfunction(tmb%lzd%llr(ilr),lzd_old%llr(ilr_old),tmb%lzd%llr(ilr)%geocode,&
                  lzd_old%hgrids,n_old,phigold,tmb%lzd%hgrids,n,centre_old_box,centre_new_box,da,&
                  frag_trans(iorb),tmb%psi(jstart:))
          end if
          call timing(iproc,'Reformatting ','OF')
          jstart=jstart+tmb%lzd%llr(ilr)%wfd%nvctr_c+7*tmb%lzd%llr(ilr)%wfd%nvctr_f

          if (present(phi_array_old)) then   
             nullify(phigold)
          else
             call f_free_ptr(phigold)
          end if

      end if

  end do

  if (add_derivatives) then
     call f_free(phi_old_der)
  end if

  call print_reformat_summary(iproc,nproc,reformat_reason)

END SUBROUTINE reformat_supportfunctions


!> Checks whether reformatting is needed based on various criteria and returns final shift and centres needed for reformat
subroutine reformat_check(reformat_needed,reformat_reason,tol,at,hgrids_old,hgrids,nvctr_c_old,nvctr_f_old,&
       nvctr_c,nvctr_f,n_old,n,ns_old,ns,frag_trans,centre_old_box,centre_new_box,da)  
  use module_base
  use module_types
  use module_fragments
  use yaml_output
  implicit none

  logical, intent(out) :: reformat_needed ! logical telling whether reformat is needed
  integer, dimension(0:6), intent(inout) :: reformat_reason ! array giving reasons for reformatting
  real(gp), intent(in) :: tol ! tolerance for rotations and shifts
  type(atoms_data), intent(in) :: at
  real(gp), dimension(3), intent(in) :: hgrids, hgrids_old
  integer, intent(in) :: nvctr_c, nvctr_f, nvctr_c_old, nvctr_f_old
  integer, dimension(3), intent(in) :: n, n_old, ns, ns_old
  real(gp), dimension(3), intent(out) :: centre_old_box, centre_new_box ! centres of rotation wrt box
  real(gp), dimension(3), intent(out) :: da ! shift to be used in reformat
  type(fragment_transformation), intent(in) :: frag_trans ! includes centres of rotation in global coordinates, shift and angle

  ! local variables 
  real(gp) :: displ, mindist
  integer, dimension(3) :: nb
  logical, dimension(3) :: per
  !real(gp), dimension(3) :: centre_new

  !conditions for periodicity in the three directions
  per(1)=(at%astruct%geocode /= 'F')
  per(2)=(at%astruct%geocode == 'P')
  per(3)=(at%astruct%geocode /= 'F')

  !buffers related to periodicity
  !WARNING: the boundary conditions are not assumed to change between new and old
  call ext_buffers_coarse(per(1),nb(1))
  call ext_buffers_coarse(per(2),nb(2))
  call ext_buffers_coarse(per(3),nb(3))

  ! centre of rotation with respect to start of box
  centre_old_box(1)=mindist(per(1),at%astruct%cell_dim(1),frag_trans%rot_center(1),hgrids_old(1)*(ns_old(1)-0.5_dp*nb(1)))
  centre_old_box(2)=mindist(per(2),at%astruct%cell_dim(2),frag_trans%rot_center(2),hgrids_old(2)*(ns_old(2)-0.5_dp*nb(2)))
  centre_old_box(3)=mindist(per(3),at%astruct%cell_dim(3),frag_trans%rot_center(3),hgrids_old(3)*(ns_old(3)-0.5_dp*nb(3)))

  centre_new_box(1)=mindist(per(1),at%astruct%cell_dim(1),frag_trans%rot_center_new(1),hgrids(1)*(ns(1)-0.5_dp*nb(1)))
  centre_new_box(2)=mindist(per(2),at%astruct%cell_dim(2),frag_trans%rot_center_new(2),hgrids(2)*(ns(2)-0.5_dp*nb(2)))
  centre_new_box(3)=mindist(per(3),at%astruct%cell_dim(3),frag_trans%rot_center_new(3),hgrids(3)*(ns(3)-0.5_dp*nb(3)))

  !print*,'rotated nb',trim(yaml_toa(rotate_vector(frag_trans%rot_axis,frag_trans%theta,hgrids*-0.5_dp*nb),fmt='(f12.8)'))
  !print*,'rotated centre old',trim(yaml_toa(rotate_vector(frag_trans%rot_axis,frag_trans%theta,centre_old_box),fmt='(f12.8)'))
  !print*,'rotated centre new',trim(yaml_toa(rotate_vector(frag_trans%rot_axis,-frag_trans%theta,centre_new_box),fmt='(f12.8)'))
  !Calculate the shift of the atom to be used in reformat
  !da(1)=mindist(per(1),at%astruct%cell_dim(1),centre_new_box(1),centre_old_box(1))
  !da(2)=mindist(per(2),at%astruct%cell_dim(2),centre_new_box(2),centre_old_box(2))
  !da(3)=mindist(per(3),at%astruct%cell_dim(3),centre_new_box(3),centre_old_box(3))
  da=centre_new_box-centre_old_box-(hgrids_old-hgrids)*0.5d0

  !print*,'reformat check',frag_trans%rot_center(2),ns_old(2),centre_old_box(2),&
  !     frag_trans%rot_center_new(2),ns(2),centre_new_box(2),da(2)
  !write(*,'(a,15I4)')'nb,ns_old,ns,n_old,n',nb,ns_old,ns,n_old,n
  !write(*,'(a,3(3(f12.8,x),3x))') 'final centre box',centre_old_box,centre_new_box,da
  !write(*,'(a,3(3(f12.8,x),3x))') 'final centre',frag_trans%rot_center,frag_trans%rot_center_new

  displ=sqrt(da(1)**2+da(2)**2+da(3)**2)

  !reformatting criterion
  if (hgrids(1) == hgrids_old(1) .and. hgrids(2) == hgrids_old(2) .and. hgrids(3) == hgrids_old(3) &
        .and. nvctr_c  == nvctr_c_old .and. nvctr_f  == nvctr_f_old &
        .and. n_old(1)==n(1)  .and. n_old(2)==n(2) .and. n_old(3)==n(3) &
        .and. abs(frag_trans%theta) <= tol .and. abs(displ) <= tol) then
      reformat_reason(0) = reformat_reason(0) + 1
      reformat_needed=.false.
  else
      reformat_needed=.true.
      if (hgrids(1) /= hgrids_old(1) .or. hgrids(2) /= hgrids_old(2) .or. hgrids(3) /= hgrids_old(3)) then 
         reformat_reason(1) = reformat_reason(1) + 1
      end if
      if (nvctr_c  /= nvctr_c_old) then
         reformat_reason(2) = reformat_reason(2) + 1
      end if
      if (nvctr_f  /= nvctr_f_old) then
         reformat_reason(3) = reformat_reason(3) + 1
      end if
      if (n_old(1) /= n(1)  .or. n_old(2) /= n(2) .or. n_old(3) /= n(3) )  then  
         reformat_reason(4) = reformat_reason(4) + 1
      end if
      if (abs(displ) > tol)  then  
         reformat_reason(5) = reformat_reason(5) + 1
      end if
      if (abs(frag_trans%theta) > tol)  then  
         reformat_reason(6) = reformat_reason(6) + 1
      end if
  end if

end subroutine reformat_check


!> Print information about the reformatting due to restart
subroutine print_reformat_summary(iproc,nproc,reformat_reason)
  use module_base
  use module_types
  use yaml_output
  implicit none

  integer, intent(in) :: iproc,nproc
  integer, dimension(0:6), intent(inout) :: reformat_reason ! array giving reasons for reformatting

  if (nproc > 1) call mpiallred(reformat_reason(0), 7, mpi_sum, bigdft_mpi%mpi_comm)

  if (iproc==0) then
        call yaml_mapping_open('Overview of the reformatting (several categories may apply)')
        call yaml_map('No reformatting required', reformat_reason(0))
        call yaml_map('Grid spacing has changed', reformat_reason(1))
        call yaml_map('Number of coarse grid points has changed', reformat_reason(2))
        call yaml_map('Number of fine grid points has changed', reformat_reason(3))
        call yaml_map('Box size has changed', reformat_reason(4))
        call yaml_map('Molecule was shifted', reformat_reason(5))
        call yaml_map('Molecule was rotated', reformat_reason(6))
        call yaml_mapping_close()
  end if

end subroutine print_reformat_summary


subroutine psi_to_psig(n,nvctr_c,nvctr_f,nseg_c,nseg_f,keyvloc,keygloc,jstart,psi,psig)
  use module_base
  implicit none

  integer, dimension(3), intent(in) :: n
  integer, intent(in) :: nseg_c, nseg_f, nvctr_c, nvctr_f
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyvloc
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keygloc
  integer, intent(inout) :: jstart
  real(wp), dimension(jstart:jstart+nvctr_c+7*nvctr_f), intent(in) :: psi
  real(wp), dimension(0:n(1),2,0:n(2),2,0:n(3),2), intent(out) :: psig

  ! local variables
  integer :: iseg, j0, j1, i, ii, i0, i1, i2, i3, n1p1, np

  call to_zero(8*(n(1)+1)*(n(2)+1)*(n(3)+1),psig(0,1,0,1,0,1))

  n1p1=n(1)+1
  np=n1p1*(n(2)+1)

  ! coarse part
  do iseg=1,nseg_c
     j0=keygloc(1,iseg)
     j1=keygloc(2,iseg)
     ii=j0-1
     i3=ii/np
     ii=ii-i3*np
     i2=ii/n1p1
     i0=ii-i2*n1p1
     i1=i0+j1-j0
     do i=i0,i1
        psig(i,1,i2,1,i3,1) = psi(jstart)
        jstart=jstart+1
     end do
  end do
   
  ! fine part
  do iseg=1,nseg_f
     j0=keygloc(1,nseg_c + iseg)
     j1=keygloc(2,nseg_c + iseg)
     ii=j0-1
     i3=ii/np
     ii=ii-i3*np
     i2=ii/n1p1
     i0=ii-i2*n1p1
     i1=i0+j1-j0
     do i=i0,i1
        psig(i,2,i2,1,i3,1)=psi(jstart+0)
        psig(i,1,i2,2,i3,1)=psi(jstart+1)
        psig(i,2,i2,2,i3,1)=psi(jstart+2)
        psig(i,1,i2,1,i3,2)=psi(jstart+3)
        psig(i,2,i2,1,i3,2)=psi(jstart+4)
        psig(i,1,i2,2,i3,2)=psi(jstart+5)
        psig(i,2,i2,2,i3,2)=psi(jstart+6)
        jstart=jstart+7
     end do
  end do

end subroutine psi_to_psig
