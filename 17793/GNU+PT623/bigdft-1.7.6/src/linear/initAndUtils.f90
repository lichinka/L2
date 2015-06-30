!> @file 
!!   Initializations
!! @author
!!   Copyright (C) 2011-2012 BigDFT group 
!!   This file is distributed under the terms of the
!!   GNU General Public License, see ~/COPYING file
!!   or http://www.gnu.org/copyleft/gpl.txt .
!!   For the list of contributors, see ~/AUTHORS 


subroutine allocateBasicArraysInputLin(lin, ntypes)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(linearInputParameters), intent(inout) :: lin
  integer, intent(in) :: ntypes
  
  ! Local variables
  character(len=*), parameter :: subname='allocateBasicArrays'

  call f_routine(id='allocateBasicArraysInputLin')
  
  lin%norbsPerType = f_malloc_ptr(ntypes,id='lin%norbsPerType')
  lin%potentialPrefac_ao = f_malloc_ptr(ntypes,id='lin%potentialPrefac_ao')
  lin%potentialPrefac_lowaccuracy = f_malloc_ptr(ntypes,id='lin%potentialPrefac_lowaccuracy')
  lin%potentialPrefac_highaccuracy = f_malloc_ptr(ntypes,id='lin%potentialPrefac_highaccuracy')
  !added a second dimension to include the low and high accuracy values
  lin%locrad_type = f_malloc_ptr((/ ntypes, 2 /),id='lin%locrad_type')
  lin%kernel_cutoff_FOE = f_malloc_ptr(ntypes,id='lin%kernel_cutoff_FOE')
  lin%kernel_cutoff = f_malloc_ptr(ntypes,id='lin%kernel_cutoff')

  call f_release_routine()

end subroutine allocateBasicArraysInputLin


subroutine allocate_extra_lin_arrays(lin,nspin,astruct)
  use module_atoms, only: atomic_structure
  use module_types, only: linearInputParameters
  use dynamic_memory
  implicit none
  integer,intent(in) :: nspin
  type(atomic_structure), intent(in) :: astruct
  type(linearInputParameters), intent(inout) :: lin
  !local variables
  character(len=*), parameter :: subname='allocate_extra_lin_arrays'
  integer :: nlr,iat,itype,iiorb,iorb
  !then perform extra allocations
  nlr=0
  do iat=1,astruct%nat
     itype=astruct%iatype(iat)
     nlr=nlr+nspin*lin%norbsPerType(itype)
  end do

  lin%locrad = f_malloc_ptr(nlr,id='lin%locrad')
  lin%locrad_kernel = f_malloc_ptr(nlr,id='lin%locrad_kernel')
  lin%locrad_mult = f_malloc_ptr(nlr,id='lin%locrad_mult')
  lin%locrad_lowaccuracy = f_malloc_ptr(nlr,id='lin%locrad_lowaccuracy')
  lin%locrad_highaccuracy = f_malloc_ptr(nlr,id='lin%locrad_highaccuracy')

  ! Assign the localization radius to each atom.
  iiorb=0
  do iat=1,astruct%nat
     itype=astruct%iatype(iat)
     do iorb=1,lin%norbsPerType(itype)
        iiorb=iiorb+1
        lin%locrad(iiorb)=lin%locrad_type(itype,1)
        lin%locrad_kernel(iiorb)=lin%kernel_cutoff(itype)
        lin%locrad_mult(iiorb)=lin%kernel_cutoff_FOE(itype)
        lin%locrad_lowaccuracy(iiorb)=lin%locrad_type(itype,1) 
        lin%locrad_highaccuracy(iiorb)=lin%locrad_type(itype,2)
     end do
  end do
end subroutine allocate_extra_lin_arrays


subroutine deallocateBasicArraysInput(lin)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  type(linearinputParameters), intent(inout) :: lin
  
  ! Local variables
  character(len=*), parameter :: subname='deallocateBasicArrays'

  call f_routine(id='deallocateBasicArraysInput')
 
  if(associated(lin%potentialPrefac_ao)) then
    call f_free_ptr(lin%potentialPrefac_ao)
    nullify(lin%potentialPrefac_ao)
  end if 
  if(associated(lin%potentialPrefac_lowaccuracy)) then
    call f_free_ptr(lin%potentialPrefac_lowaccuracy)
    nullify(lin%potentialPrefac_lowaccuracy)
  end if 
  if(associated(lin%potentialPrefac_highaccuracy)) then
    call f_free_ptr(lin%potentialPrefac_highaccuracy)
    nullify(lin%potentialPrefac_highaccuracy)
  end if 

  if(associated(lin%norbsPerType)) then
    call f_free_ptr(lin%norbsPerType)
    nullify(lin%norbsPerType)
  end if 

  if(associated(lin%locrad)) then
    call f_free_ptr(lin%locrad)
    nullify(lin%locrad)
  end if 

  if(associated(lin%locrad_kernel)) then
    call f_free_ptr(lin%locrad_kernel)
    nullify(lin%locrad_kernel)
  end if 

  if(associated(lin%locrad_mult)) then
    call f_free_ptr(lin%locrad_mult)
    nullify(lin%locrad_mult)
  end if 

  if(associated(lin%locrad_lowaccuracy)) then
    call f_free_ptr(lin%locrad_lowaccuracy)
    nullify(lin%locrad_lowaccuracy)
  end if 

  if(associated(lin%locrad_highaccuracy)) then
    call f_free_ptr(lin%locrad_highaccuracy)
    nullify(lin%locrad_highaccuracy)
  end if 

  if(associated(lin%locrad_type)) then
    call f_free_ptr(lin%locrad_type)
    nullify(lin%locrad_type)
  end if 

  if(associated(lin%kernel_cutoff_FOE)) then
    call f_free_ptr(lin%kernel_cutoff_FOE)
    nullify(lin%kernel_cutoff_FOE)
  end if 

  if(associated(lin%kernel_cutoff)) then
    call f_free_ptr(lin%kernel_cutoff)
    nullify(lin%kernel_cutoff)
  end if 

  call f_release_routine()

end subroutine deallocateBasicArraysInput



! lzd%llr already allocated, locregcenter and locrad already filled - could tidy this!
subroutine initLocregs(iproc, nproc, lzd, hx, hy, hz, astruct, orbs, Glr, locregShape, lborbs)
  use module_base
  use module_types
  use module_atoms, only: atomic_structure
  use module_interfaces, exceptThisOne => initLocregs
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(local_zone_descriptors), intent(inout) :: lzd
  real(kind=8), intent(in) :: hx, hy, hz
  type(atomic_structure), intent(in) :: astruct
  type(orbitals_data), intent(in) :: orbs
  type(locreg_descriptors), intent(in) :: Glr
  character(len=1), intent(in) :: locregShape
  type(orbitals_data),optional,intent(in) :: lborbs
  
  ! Local variables
  integer :: jorb, jjorb, jlr
  character(len=*), parameter :: subname='initLocregs'
  logical,dimension(:), allocatable :: calculateBounds

  call f_routine(id=subname)

  
  calculateBounds = f_malloc(lzd%nlr,id='calculateBounds')
  calculateBounds=.false.
  
  do jorb=1,orbs%norbp
     jjorb=orbs%isorb+jorb
     jlr=orbs%inWhichLocreg(jjorb)
     calculateBounds(jlr)=.true.
  end do

  if(present(lborbs)) then
     do jorb=1,lborbs%norbp
        jjorb=lborbs%isorb+jorb
        jlr=lborbs%inWhichLocreg(jjorb)
        calculateBounds(jlr)=.true.
     end do
  end if
  
  if(locregShape=='c') then
      stop 'locregShape c is deprecated'
  else if(locregShape=='s') then
      call determine_locregSphere_parallel(iproc, nproc, lzd%nlr, hx, hy, hz, &
           astruct, orbs, Glr, lzd%Llr, calculateBounds)
  end if
  
  call f_free(calculateBounds)
  
  !DEBUG
  !do ilr=1,lin%nlr
  !    if(iproc==0) write(*,'(1x,a,i0)') '>>>>>>> zone ', ilr
  !    if(iproc==0) write(*,'(3x,a,4i10)') 'nseg_c, nseg_f, nvctr_c, nvctr_f', lin%Llr(ilr)%wfd%nseg_c, lin%Llr(ilr)%wfd%nseg_f, lin%Llr(ilr)%wfd%nvctr_c, lin%Llr(ilr)%wfd%nvctr_f
  !    if(iproc==0) write(*,'(3x,a,3i8)') 'lin%Llr(ilr)%d%n1i, lin%Llr(ilr)%d%n2i, lin%Llr(ilr)%d%n3i', lin%Llr(ilr)%d%n1i, lin%Llr(ilr)%d%n2i, lin%Llr(ilr)%d%n3i
  !    if(iproc==0) write(*,'(a,6i8)') 'lin%Llr(ilr)%d%nfl1,lin%Llr(ilr)%d%nfu1,lin%Llr(ilr)%d%nfl2,lin%Llr(ilr)%d%nfu2,lin%Llr(ilr)%d%nfl3,lin%Llr(ilr)%d%nfu3',&
  !    lin%Llr(ilr)%d%nfl1,lin%Llr(ilr)%d%nfu1,lin%Llr(ilr)%d%nfl2,lin%Llr(ilr)%d%nfu2,lin%Llr(ilr)%d%nfl3,lin%Llr(ilr)%d%nfu3
  !end do
  !END DEBUG
  
  lzd%linear=.true.

  call f_release_routine()

end subroutine initLocregs



subroutine init_foe(iproc, nproc, input, orbs_KS, foe_obj, reset)
  use module_base
  use module_atoms, only: atomic_structure
  use module_types
  use foe_base, only: foe_data, foe_data_set_int, foe_data_set_real, foe_data_set_logical, foe_data_get_real, foe_data_null
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(input_variables), intent(in) :: input
  type(orbitals_data), intent(in) :: orbs_KS
  type(foe_data), intent(out) :: foe_obj
  logical, intent(in) :: reset
  
  ! Local variables
  character(len=*), parameter :: subname='init_foe'
  integer :: iorb
  real(kind=8) :: incr

  call timing(iproc,'init_matrCompr','ON')

  foe_obj = foe_data_null()

  if (reset) then
      foe_obj%ef = f_malloc0_ptr(input%nspin,id='(foe_obj%ef)')
      call foe_data_set_real(foe_obj,"ef",0.d0,1)
      if (input%nspin==2) then
          call foe_data_set_real(foe_obj,"ef",0.d0,2)
      end if
      foe_obj%evlow = f_malloc0_ptr(input%nspin,id='foe_obj%evlow')
      call foe_data_set_real(foe_obj,"evlow",input%lin%evlow,1)
      if (input%nspin==2) then
          call foe_data_set_real(foe_obj,"evlow",input%lin%evlow,2)
      end if
      foe_obj%evhigh = f_malloc0_ptr(input%nspin,id='foe_obj%evhigh')
      call foe_data_set_real(foe_obj,"evhigh",input%lin%evhigh,1)
      if (input%nspin==2) then
          call foe_data_set_real(foe_obj,"evhigh",input%lin%evhigh,2)
      end if
      foe_obj%bisection_shift = f_malloc0_ptr(input%nspin,id='foe_obj%bisection_shift')
      call foe_data_set_real(foe_obj,"bisection_shift",1.d-1,1)
      if (input%nspin==2) then
          call foe_data_set_real(foe_obj,"bisection_shift",1.d-1,2)
      end if
      call foe_data_set_real(foe_obj,"fscale",input%lin%fscale)
      call foe_data_set_real(foe_obj,"ef_interpol_det",input%lin%ef_interpol_det)
      call foe_data_set_real(foe_obj,"ef_interpol_chargediff",input%lin%ef_interpol_chargediff)
      foe_obj%charge = f_malloc0_ptr(input%nspin,id='foe_obj%charge')
      call foe_data_set_real(foe_obj,"charge",0.d0,1)
      do iorb=1,orbs_KS%norbu
          call foe_data_set_real(foe_obj,"charge",foe_data_get_real(foe_obj,"charge",1)+orbs_KS%occup(iorb),1)
      end do
      if (input%nspin==2) then
          call foe_data_set_real(foe_obj,"charge",0.d0,2)
          do iorb=orbs_KS%norbu+1,orbs_KS%norb
               call foe_data_set_real(foe_obj,"charge",foe_data_get_real(foe_obj,"charge",2)+orbs_KS%occup(iorb),2)
          end do
      end if
      call foe_data_set_int(foe_obj,"evbounds_isatur",0)
      call foe_data_set_int(foe_obj,"evboundsshrink_isatur",0)
      call foe_data_set_int(foe_obj,"evbounds_nsatur",input%evbounds_nsatur)
      call foe_data_set_int(foe_obj,"evboundsshrink_nsatur",input%evboundsshrink_nsatur)
      call foe_data_set_real(foe_obj,"fscale_lowerbound",input%fscale_lowerbound)
      call foe_data_set_real(foe_obj,"fscale_upperbound",input%fscale_upperbound)
      call foe_data_set_logical(foe_obj,"adjust_FOE_temperature",input%adjust_FOE_temperature)
  end if

  call timing(iproc,'init_matrCompr','OF')


end subroutine init_foe


subroutine check_linear_and_create_Lzd(iproc,nproc,linType,Lzd,atoms,orbs,nspin,rxyz)
  use module_base
  use module_types
  use module_xc
  use ao_inguess, only: atomic_info
  use locregs, only: locreg_null
  implicit none

  integer, intent(in) :: iproc,nproc,nspin
  type(local_zone_descriptors), intent(inout) :: Lzd
  type(atoms_data), intent(in) :: atoms
  type(orbitals_data), intent(inout) :: orbs
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: rxyz
  integer, intent(in) :: linType
!  real(gp), dimension(atoms%astruct%ntypes,3), intent(in) :: radii_cf
  !Local variables
  character(len=*), parameter :: subname='check_linear_and_create_Lzd'
  logical :: linear
  real(gp) :: rcov
  integer :: iat,ityp,nspin_ig,ilr
  real(gp), dimension(:), allocatable :: locrad
  logical,dimension(:), allocatable :: calculateBounds

  !default variables
  Lzd%nlr = 1

  if (nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=nspin
  end if

  linear  = .true.
  if (linType == INPUT_IG_FULL) then
     Lzd%nlr=atoms%astruct%nat
     locrad = f_malloc(Lzd%nlr,id='locrad')
     ! locrad read from last line of  psppar
     do iat=1,atoms%astruct%nat
        ityp = atoms%astruct%iatype(iat)
        call atomic_info(atoms%nzatom(ityp),atoms%nelpsp(ityp),rcov=rcov)
        locrad(iat) =  rcov * 10.0_gp ! locrad(iat) = atoms%rloc(ityp,1)
     end do  
     call timing(iproc,'check_IG      ','ON')
     call check_linear_inputguess(iproc,Lzd%nlr,rxyz,locrad,&
          Lzd%hgrids(1),Lzd%hgrids(2),Lzd%hgrids(3),&
          Lzd%Glr,linear) 
     call timing(iproc,'check_IG      ','OF')
     if(nspin >= 4) linear = .false. 
  end if

  ! If we are using cubic code : by choice or because locregs are too big
  Lzd%linear = .true.
  if (linType == INPUT_IG_LIG .or. linType == INPUT_IG_OFF .or. .not. linear) then
     Lzd%linear = .false.
     Lzd%nlr = 1
  end if


  if(linType /= INPUT_IG_TMO) then
     allocate(Lzd%Llr(Lzd%nlr))
     do ilr=1,Lzd%nlr
        Lzd%Llr(ilr)=locreg_null()
     end do
     !for now, always true because we want to calculate the hamiltonians for all locregs
     if(.not. Lzd%linear) then
        Lzd%lintyp = 0
        !copy Glr to Llr(1)
        call nullify_locreg_descriptors(Lzd%Llr(1))
        call copy_locreg_descriptors(Lzd%Glr,Lzd%Llr(1))
     else 
        Lzd%lintyp = 1
        ! Assign orbitals to locreg (for LCAO IG each orbitals corresponds to an atomic function. WILL NEED TO CHANGE THIS)
        call assignToLocreg(iproc,nproc,orbs%nspinor,nspin_ig,atoms,orbs,Lzd)

        ! determine the localization regions
        ! calculateBounds indicate whether the arrays with the bounds (for convolutions...) shall also
        ! be allocated and calculated. In principle this is only necessary if the current process has orbitals
        ! in this localization region.
        calculateBounds = f_malloc(lzd%nlr,id='calculateBounds')
        calculateBounds=.true.
!        call determine_locreg_periodic(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,Lzd%Glr,Lzd%Llr,calculateBounds)
        call determine_locreg_parallel(iproc,nproc,Lzd%nlr,rxyz,locrad,&
             Lzd%hgrids(1),Lzd%hgrids(2),Lzd%hgrids(3),Lzd%Glr,Lzd%Llr,&
             orbs,calculateBounds)  
        call f_free(calculateBounds)
        call f_free(locrad)

        ! determine the wavefunction dimension
        call wavefunction_dimension(Lzd,orbs)
     end if
  else
     Lzd%lintyp = 2
  end if
  
!DEBUG
!!if(iproc==0)then
!!print *,'###################################################'
!!print *,'##        General information:                   ##'
!!print *,'###################################################'
!!print *,'Lzd%nlr,linear, ndimpotisf :',Lzd%nlr,Lzd%linear,Lzd%ndimpotisf
!!print *,'###################################################'
!!print *,'##        Global box information:                ##'
!!print *,'###################################################'
!!write(*,'(a24,3i4)')'Global region n1,n2,n3:',Lzd%Glr%d%n1,Lzd%Glr%d%n2,Lzd%Glr%d%n3
!!write(*,*)'Global fine grid: nfl',Lzd%Glr%d%nfl1,Lzd%Glr%d%nfl2,Lzd%Glr%d%nfl3
!!write(*,*)'Global fine grid: nfu',Lzd%Glr%d%nfu1,Lzd%Glr%d%nfu2,Lzd%Glr%d%nfu3
!!write(*,*)'Global inter. grid: ni',Lzd%Glr%d%n1i,Lzd%Glr%d%n2i,Lzd%Glr%d%n3i
!!write(*,'(a27,f6.2,f6.2,f6.2)')'Global dimension (1x,y,z):',Lzd%Glr%d%n1*hx,Lzd%Glr%d%n2*hy,Lzd%Glr%d%n3*hz
!!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*hx*Lzd%Glr%d%n2*hy*Lzd%Glr%d%n3*hz
!!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
!!print *,'###################################################'
!!print *,'##        Local boxes information:               ##'
!!print *,'###################################################'
!!do i_stat =1, Lzd%nlr
!!   write(*,*)'=====> Region:',i_stat
!!   write(*,'(a24,3i4)')'Local region n1,n2,n3:',Lzd%Llr(i_stat)%d%n1,Lzd%Llr(i_stat)%d%n2,Lzd%Llr(i_stat)%d%n3
!!   write(*,*)'Local fine grid: nfl',Lzd%Llr(i_stat)%d%nfl1,Lzd%Llr(i_stat)%d%nfl2,Lzd%Llr(i_stat)%d%nfl3
!!   write(*,*)'Local fine grid: nfu',Lzd%Llr(i_stat)%d%nfu1,Lzd%Llr(i_stat)%d%nfu2,Lzd%Llr(i_stat)%d%nfu3
!!   write(*,*)'Local inter. grid: ni',Lzd%Llr(i_stat)%d%n1i,Lzd%Llr(i_stat)%d%n2i,Lzd%Llr(i_stat)%d%n3i
!!   write(*,'(a27,f6.2,f6.2,f6.2)')'Local dimension (1x,y,z):',Lzd%Llr(i_stat)%d%n1*hx,Lzd%Llr(i_stat)%d%n2*hy,&
!!            Lzd%Llr(i_stat)%d%n3*hz
!!   write(*,'(a17,f12.2)')'Local volume: ',Lzd%Llr(i_stat)%d%n1*hx*Lzd%Llr(i_stat)%d%n2*hy*Lzd%Llr(i_stat)%d%n3*hz
!!   print *,'Local wfd statistics:',Lzd%Llr(i_stat)%wfd%nseg_c,Lzd%Llr(i_stat)%wfd%nseg_f,Lzd%Llr(i_stat)%wfd%nvctr_c,&
!!            Lzd%Llr(i_stat)%wfd%nvctr_f
!!end do
!!end if
!!call mpi_finalize(i_stat)
!!stop
!END DEBUG

end subroutine check_linear_and_create_Lzd


subroutine create_LzdLIG(iproc,nproc,nspin,linearmode,hx,hy,hz,Glr,atoms,orbs,rxyz,nl,Lzd)
  use module_base
  use module_types
  use module_xc
  use ao_inguess, only: atomic_info
  use locregs, only: locreg_null
  implicit none

  integer, intent(in) :: iproc,nproc,nspin
  real(gp), intent(in) :: hx,hy,hz
  type(locreg_descriptors), intent(in) :: Glr
  type(atoms_data), intent(in) :: atoms
  type(orbitals_data), intent(inout) :: orbs
  integer, intent(in) :: linearmode
  real(gp), dimension(3,atoms%astruct%nat), intent(in) :: rxyz
  type(local_zone_descriptors), intent(inout) :: Lzd
  type(DFT_PSP_projectors), intent(inout) :: nl
  !  real(gp), dimension(atoms%astruct%ntypes,3), intent(in) :: radii_cf
  !Local variables
  character(len=*), parameter :: subname='check_linear_and_create_Lzd'
  logical :: linear
  integer :: iat,ityp,nspin_ig,ilr
  real(gp) :: rcov
  real(gp), dimension(:), allocatable :: locrad
  logical,dimension(:), allocatable :: calculateBounds,lr_mask

  call f_routine(id=subname)
  !default variables
  Lzd%nlr = 1

  Lzd%hgrids(1)=hx
  Lzd%hgrids(2)=hy
  Lzd%hgrids(3)=hz

  if (nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=nspin
  end if

  linear  = .true.
  if (linearmode == INPUT_IG_LIG .or. linearmode == INPUT_IG_FULL) then
     Lzd%nlr=atoms%astruct%nat
     locrad=f_malloc(Lzd%nlr,id='locrad')
     ! locrad read from last line of  psppar
     do iat=1,atoms%astruct%nat
        ityp = atoms%astruct%iatype(iat)
        call atomic_info(atoms%nzatom(ityp),atoms%nelpsp(ityp),rcov=rcov)
        locrad(iat) =  rcov * 10.0_gp ! atoms%rloc(ityp,1)
        !locrad(iat)=18.d0
     end do
     call timing(iproc,'check_IG      ','ON')
     call check_linear_inputguess(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,&
          Glr,linear) 
     call timing(iproc,'check_IG      ','OF')
     if(nspin >= 4) linear = .false. 
  end if

  ! If we are using cubic code : by choice or because locregs are too big
  if (linearmode == INPUT_IG_OFF .or. .not. linear) then
     linear = .false.
     Lzd%nlr = 1
  end if

  Lzd%linear = .true.
  if (.not. linear)  Lzd%linear = .false.

  !  print *,'before Glr => Lzd%Glr'
  call nullify_locreg_descriptors(Lzd%Glr)
  call copy_locreg_descriptors(Glr,Lzd%Glr)

  if(linearmode /= INPUT_IG_TMO) then
     allocate(Lzd%Llr(Lzd%nlr))
     do ilr=1,Lzd%nlr
        Lzd%Llr(ilr)=locreg_null()
     end do
     !for now, always true because we want to calculate the hamiltonians for all locregs

     if(.not. Lzd%linear) then
        Lzd%lintyp = 0
        call nullify_locreg_descriptors(Lzd%Llr(1))
        call copy_locreg_descriptors(Glr,Lzd%Llr(1))
     else 
        Lzd%lintyp = 1
        ! Assign orbitals to locreg (for LCAO IG each orbitals corresponds to an atomic function. WILL NEED TO CHANGE THIS)
        call assignToLocreg(iproc,nproc,orbs%nspinor,nspin_ig,atoms,orbs,Lzd)

        ! determine the localization regions
        ! calculateBounds indicate whether the arrays with the bounds (for convolutions...) shall also
        ! be allocated and calculated. In principle this is only necessary if the current process has orbitals
        ! in this localization region.
        calculateBounds=f_malloc(lzd%nlr,id='calculateBounds')
        calculateBounds=.true.
        !        call determine_locreg_periodic(iproc,Lzd%nlr,rxyz,locrad,hx,hy,hz,Glr,Lzd%Llr,calculateBounds)
        call determine_locreg_parallel(iproc,nproc,Lzd%nlr,rxyz,locrad,&
             hx,hy,hz,Glr,Lzd%Llr,&
             orbs,calculateBounds)  
        call f_free(calculateBounds)
        call f_free(locrad)

        ! determine the wavefunction dimension
        call wavefunction_dimension(Lzd,orbs)
        !in this case update the projector descriptor to be compatible with the locregs
        lr_mask=f_malloc0(Lzd%nlr,id='lr_mask')
        call update_lrmask_array(Lzd%nlr,orbs,lr_mask)
        !when the new tmbs are created the projector descriptors can be updated
        call update_nlpsp(nl,Lzd%nlr,Lzd%llr,Lzd%Glr,lr_mask)
        if (iproc == 0) call print_nlpsp(nl)
       
        call f_free(lr_mask)
     end if
  else
     Lzd%lintyp = 2
  end if

  call f_release_routine()

  !DEBUG
  !!if(iproc==0)then
  !!print *,'###################################################'
  !!print *,'##        General information:                   ##'
  !!print *,'###################################################'
  !!print *,'Lzd%nlr,linear, Lpsidimtot, ndimpotisf, Lnprojel:',Lzd%nlr,Lzd%linear,Lzd%ndimpotisf
  !!print *,'###################################################'
  !!print *,'##        Global box information:                ##'
  !!print *,'###################################################'
  !!write(*,'(a24,3i4)')'Global region n1,n2,n3:',Lzd%Glr%d%n1,Lzd%Glr%d%n2,Lzd%Glr%d%n3
  !!write(*,*)'Global fine grid: nfl',Lzd%Glr%d%nfl1,Lzd%Glr%d%nfl2,Lzd%Glr%d%nfl3
  !!write(*,*)'Global fine grid: nfu',Lzd%Glr%d%nfu1,Lzd%Glr%d%nfu2,Lzd%Glr%d%nfu3
  !!write(*,*)'Global inter. grid: ni',Lzd%Glr%d%n1i,Lzd%Glr%d%n2i,Lzd%Glr%d%n3i
  !!write(*,'(a27,f6.2,f6.2,f6.2)')'Global dimension (1x,y,z):',Lzd%Glr%d%n1*hx,Lzd%Glr%d%n2*hy,Lzd%Glr%d%n3*hz
  !!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*hx*Lzd%Glr%d%n2*hy*Lzd%Glr%d%n3*hz
  !!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
  !!write(*,'(a17,f12.2)')'Global volume: ',Lzd%Glr%d%n1*input%hx*Lzd%Glr%d%n2*input%hy*Lzd%Glr%d%n3*input%hz
  !!print *,'Global wfd statistics:',Lzd%Glr%wfd%nseg_c,Lzd%Glr%wfd%nseg_f,Lzd%Glr%wfd%nvctr_c,Lzd%Glr%wfd%nvctr_f
  !!print *,'###################################################'
  !!print *,'##        Local boxes information:               ##'
  !!print *,'###################################################'
  !!do i_stat =1, Lzd%nlr
  !!   write(*,*)'=====> Region:',i_stat
  !!   write(*,'(a24,3i4)')'Local region n1,n2,n3:',Lzd%Llr(i_stat)%d%n1,Lzd%Llr(i_stat)%d%n2,Lzd%Llr(i_stat)%d%n3
  !!   write(*,*)'Local fine grid: nfl',Lzd%Llr(i_stat)%d%nfl1,Lzd%Llr(i_stat)%d%nfl2,Lzd%Llr(i_stat)%d%nfl3
  !!   write(*,*)'Local fine grid: nfu',Lzd%Llr(i_stat)%d%nfu1,Lzd%Llr(i_stat)%d%nfu2,Lzd%Llr(i_stat)%d%nfu3
  !!   write(*,*)'Local inter. grid: ni',Lzd%Llr(i_stat)%d%n1i,Lzd%Llr(i_stat)%d%n2i,Lzd%Llr(i_stat)%d%n3i
  !!   write(*,'(a27,f6.2,f6.2,f6.2)')'Local dimension (1x,y,z):',Lzd%Llr(i_stat)%d%n1*hx,Lzd%Llr(i_stat)%d%n2*hy,&
  !!            Lzd%Llr(i_stat)%d%n3*hz
  !!   write(*,'(a17,f12.2)')'Local volume: ',Lzd%Llr(i_stat)%d%n1*hx*Lzd%Llr(i_stat)%d%n2*hy*Lzd%Llr(i_stat)%d%n3*hz
  !!   print *,'Local wfd statistics:',Lzd%Llr(i_stat)%wfd%nseg_c,Lzd%Llr(i_stat)%wfd%nseg_f,Lzd%Llr(i_stat)%wfd%nvctr_c,&
  !!            Lzd%Llr(i_stat)%wfd%nvctr_f
  !!end do
  !!end if
  !call mpi_finalize(i_stat)
  !stop
  !END DEBUG

end subroutine create_LzdLIG





subroutine init_orbitals_data_for_linear(iproc, nproc, nspinor, input, astruct, rxyz, lorbs)
  use module_base
  use module_types
  use module_interfaces, except_this_one => init_orbitals_data_for_linear
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, nproc, nspinor
  type(input_variables), intent(in) :: input
  type(atomic_structure), intent(in) :: astruct
  real(kind=8),dimension(3,astruct%nat), intent(in) :: rxyz
  type(orbitals_data), intent(out) :: lorbs
  
  ! Local variables
  integer :: norb, norbu, norbd, ityp, iat, ilr, iorb, nlr, iiat, ispin
  integer, dimension(:), allocatable :: norbsPerLocreg, norbsPerAtom
  real(kind=8),dimension(:,:), allocatable :: locregCenter
  character(len=*), parameter :: subname='init_orbitals_data_for_linear'

  call timing(iproc,'init_orbs_lin ','ON')

  call f_routine(id='init_orbitals_data_for_linear')
  
  call nullify_orbitals_data(lorbs)
 
  ! Count the number of basis functions.
  norbsPerAtom = f_malloc(astruct%nat*input%nspin,id='norbsPerAtom')
  norbu=0
  nlr=0
  iiat=0
  do ispin=1,input%nspin
      do iat=1,astruct%nat
          iiat=iiat+1
          ityp=astruct%iatype(iat)
          norbsPerAtom(iiat)=input%lin%norbsPerType(ityp)
          if (ispin==1) then
              norbu=norbu+input%lin%norbsPerType(ityp)
          end if
          !nlr=nlr+input%lin%norbsPerType(ityp)
      end do
  end do

  ! For spin polarized systems, use twice the number of basis functions (i.e. norbd=norbu)
  if (input%nspin==1) then
      norbd=0
  else
      norbd=norbu
  end if
  norb=norbu+norbd

  nlr=norb

 
  ! Distribute the basis functions among the processors.
  call orbitals_descriptors(iproc, nproc, norb, norbu, norbd, input%nspin, nspinor,&
       input%gen_nkpt, input%gen_kpt, input%gen_wkpt, lorbs,.true.) !simple repartition

  locregCenter = f_malloc((/ 3, nlr /),id='locregCenter')

  
  ! this loop does not take into account the additional TMBs required for spin polarized systems
  ilr=0
  do iat=1,astruct%nat
      ityp=astruct%iatype(iat)
      do iorb=1,input%lin%norbsPerType(ityp)
          ilr=ilr+1
          locregCenter(:,ilr)=rxyz(:,iat)
          ! DEBUGLR write(10,*) iorb,locregCenter(:,ilr)
      end do
  end do

  ! Correction for spin polarized systems. For non polarized systems, norbu=norb and the loop does nothing.
  do iorb=lorbs%norbu+1,lorbs%norb
      locregCenter(:,iorb)=locregCenter(:,iorb-lorbs%norbu)
  end do

 
  norbsPerLocreg = f_malloc(nlr,id='norbsPerLocreg')
  norbsPerLocreg=1 !should be norbsPerLocreg
    
  call f_free_ptr(lorbs%inWhichLocreg)
  call assignToLocreg2(iproc, nproc, lorbs%norb, lorbs%norbu, lorbs%norb_par, astruct%nat, nlr, &
       input%nspin, norbsPerLocreg, lorbs%spinsgn, locregCenter, lorbs%inwhichlocreg)

  call f_free_ptr(lorbs%onwhichatom)
  call assignToLocreg2(iproc, nproc, lorbs%norb, lorbs%norbu, lorbs%norb_par, astruct%nat, astruct%nat, &
       input%nspin, norbsPerAtom, lorbs%spinsgn, rxyz, lorbs%onwhichatom)

  
  lorbs%eval = f_malloc_ptr(lorbs%norb,id='lorbs%eval')
  lorbs%eval=-.5d0
  
  call f_free(norbsPerLocreg)
  call f_free(locregCenter)
  call f_free(norbsPerAtom)

  call f_release_routine()

  call timing(iproc,'init_orbs_lin ','OF')

end subroutine init_orbitals_data_for_linear


! initializes locrad and locregcenter
subroutine lzd_init_llr(iproc, nproc, input, astruct, rxyz, orbs, lzd)
  use module_base
  use module_types
  use module_interfaces
  use locregs, only: locreg_null
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(input_variables), intent(in) :: input
  type(atomic_structure), intent(in) :: astruct
  real(kind=8),dimension(3,astruct%nat), intent(in) :: rxyz
  type(orbitals_data), intent(in) :: orbs
  type(local_zone_descriptors), intent(inout) :: lzd
  
  ! Local variables
  integer :: iat, ityp, ilr, istat, iorb, iilr
  real(kind=8),dimension(:,:), allocatable :: locregCenter
  character(len=*), parameter :: subname='lzd_init_llr'
  real(8):: t1, t2

  call timing(iproc,'init_locregs  ','ON')

  call f_routine(id='lzd_init_llr')

  t1=mpi_wtime()
  
  nullify(lzd%llr)

  lzd%nlr=orbs%norb

  locregCenter = f_malloc((/ 3, orbs%norbu /),id='locregCenter')
  
  ilr=0
  do iat=1,astruct%nat
      ityp=astruct%iatype(iat)
      do iorb=1,input%lin%norbsPerType(ityp)
          ilr=ilr+1
          locregCenter(:,ilr)=rxyz(:,iat)
      end do
  end do

  ! Allocate the array of localisation regions
  allocate(lzd%Llr(lzd%nlr),stat=istat)
  do ilr=1,lzd%nlr
     lzd%llr(ilr)=locreg_null()
  end do
  do ilr=1,lzd%nlr
      iilr=mod(ilr-1,orbs%norbu)+1 !correct value for a spin polarized system
      !!write(*,*) 'ilr, iilr', ilr, iilr
      lzd%llr(ilr)%locrad=input%lin%locrad(iilr)
      lzd%llr(ilr)%locrad_kernel=input%lin%locrad_kernel(iilr)
      lzd%llr(ilr)%locrad_mult=input%lin%locrad_mult(iilr)
      lzd%llr(ilr)%locregCenter=locregCenter(:,iilr)
      !!if (iproc==0) then
      !!    write(*,'(a,i3,3x,es10.3,3x,es10.3,3x,es10.3,3x,3es10.3)') 'ilr, locrad, locrad_kernel, locrad_mult, locregCenter', &
      !!    ilr, lzd%llr(ilr)%locrad, lzd%llr(ilr)%locrad_kernel, &
      !!    lzd%llr(ilr)%locrad_mult, lzd%llr(ilr)%locregCenter
      !!end if
  end do

  call f_free(locregCenter)
  
  t2=mpi_wtime()
  !if(iproc==0) write(*,*) 'in lzd_init_llr: time',t2-t1

  call f_release_routine()

  call timing(iproc,'init_locregs  ','OF')

end subroutine lzd_init_llr


subroutine update_locreg(iproc, nproc, nlr, locrad, locrad_kernel, locrad_mult, locregCenter, glr_tmp, &
           useDerivativeBasisFunctions, nscatterarr, hx, hy, hz, astruct, input, &
           orbs_KS, orbs, lzd, npsidim_orbs, npsidim_comp, lbcomgp, lbcollcom, lfoe, lbcollcom_sr)
  use module_base
  use module_types
  use module_interfaces, except_this_one => update_locreg
  use communications_base, only: p2pComms, comms_linear_null, p2pComms_null, allocate_p2pComms_buffer
  use communications_init, only: init_comms_linear, init_comms_linear_sumrho, &
                                 initialize_communication_potential
  use foe_base, only: foe_data, foe_data_null
  use locregs, only: locreg_null
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, nproc, nlr
  integer, intent(out) :: npsidim_orbs, npsidim_comp
  logical,intent(in) :: useDerivativeBasisFunctions
  integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
  real(kind=8), intent(in) :: hx, hy, hz
  type(atomic_structure), intent(in) :: astruct
  type(input_variables), intent(in) :: input
  real(kind=8),dimension(nlr), intent(in) :: locrad, locrad_kernel, locrad_mult
  type(orbitals_data), intent(in) :: orbs_KS, orbs
  real(kind=8),dimension(3,nlr), intent(in) :: locregCenter
  type(locreg_descriptors), intent(in) :: glr_tmp
  type(local_zone_descriptors), intent(inout) :: lzd
  type(p2pComms), intent(inout) :: lbcomgp
  type(foe_data), intent(inout),optional :: lfoe
  type(comms_linear), intent(inout) :: lbcollcom
  type(comms_linear), intent(inout),optional :: lbcollcom_sr

  
  ! Local variables
  integer :: iorb, ilr, npsidim, istat
  real(kind=8),dimension(:,:), allocatable :: locreg_centers
  character(len=*), parameter :: subname='update_locreg'

  call timing(iproc,'updatelocreg1','ON') 

  call f_routine(id='update_locreg')

  !if (present(lfoe)) call nullify_foe(lfoe)
  if (present(lfoe)) lfoe = foe_data_null()
  !call nullify_comms_linear(lbcollcom)
  lbcollcom=comms_linear_null()
  if (present(lbcollcom_sr)) then
      !call nullify_comms_linear(lbcollcom_sr)
      lbcollcom_sr=comms_linear_null()
  end if
  lbcomgp = p2pComms_null()
  call nullify_local_zone_descriptors(lzd)
  !!tag=1

  ! Allocate the array of localisation regions
  lzd%nlr=nlr
  allocate(lzd%Llr(lzd%nlr),stat=istat)
  do ilr=1,lzd%nlr
     lzd%Llr(ilr)=locreg_null()
  end do
  do ilr=1,lzd%nlr
      lzd%llr(ilr)%locrad=locrad(ilr)
      lzd%llr(ilr)%locrad_kernel=locrad_kernel(ilr)
      lzd%llr(ilr)%locrad_mult=locrad_mult(ilr)
      lzd%llr(ilr)%locregCenter=locregCenter(:,ilr)
  end do
  call timing(iproc,'updatelocreg1','OF') 
  call initLocregs(iproc, nproc, lzd, hx, hy, hz, astruct, orbs, glr_tmp, 's')!, llborbs)
  call timing(iproc,'updatelocreg1','ON') 
  call nullify_locreg_descriptors(lzd%glr)
  call copy_locreg_descriptors(glr_tmp, lzd%glr)
  lzd%hgrids(1)=hx
  lzd%hgrids(2)=hy
  lzd%hgrids(3)=hz

  npsidim = 0
  do iorb=1,orbs%norbp
   ilr=orbs%inwhichlocreg(iorb+orbs%isorb)
   npsidim = npsidim + lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
  end do

  npsidim_orbs=max(npsidim,1)
  ! set npsidim_comp here too?!
  npsidim_comp=1

!  ! don't really want to keep this unless we do so right from the start, but for now keep it to avoid updating refs
!  orbs%eval=-.5d0

  call timing(iproc,'updatelocreg1','OF') 

  if (present(lfoe)) then
      locreg_centers = f_malloc((/3,lzd%nlr/),id='locreg_centers')
      do ilr=1,lzd%nlr
          locreg_centers(1:3,ilr)=lzd%llr(ilr)%locregcenter(1:3)
      end do
      call init_foe(iproc, nproc, input, orbs_KS, lfoe, .true.)
      call f_free(locreg_centers)
  end if

  call init_comms_linear(iproc, nproc, input%imethod_overlap, npsidim_orbs, orbs, lzd, input%nspin, lbcollcom)
  if (present(lbcollcom_sr)) then
      call init_comms_linear_sumrho(iproc, nproc, lzd, orbs, input%nspin, nscatterarr, lbcollcom_sr)
  end if

  call initialize_communication_potential(iproc, nproc, nscatterarr, orbs, lzd, input%nspin, lbcomgp)
  call allocate_p2pComms_buffer(lbcomgp)

  call f_release_routine()

end subroutine update_locreg


subroutine update_ldiis_arrays(tmb, subname, ldiis)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(DFT_wavefunction), intent(in) :: tmb
  character(len=*), intent(in) :: subname
  type(localizedDIISParameters), intent(inout) :: ldiis

  ! Local variables
  integer :: ii, iorb, ilr

  call f_free_ptr(ldiis%phiHist)
  call f_free_ptr(ldiis%hphiHist)

  ii=0
  do iorb=1,tmb%orbs%norbp
      ilr=tmb%orbs%inwhichlocreg(tmb%orbs%isorb+iorb)
      ii=ii+ldiis%isx*(tmb%lzd%llr(ilr)%wfd%nvctr_c+7*tmb%lzd%llr(ilr)%wfd%nvctr_f)
  end do

  ldiis%phiHist = f_malloc_ptr(ii,id='ldiis%phiHist')
  ldiis%hphiHist = f_malloc_ptr(ii,id='ldiis%hphiHist')

end subroutine update_ldiis_arrays


subroutine allocate_auxiliary_basis_function(npsidim, subname, lphi, lhphi)
  use module_base
  implicit none

  ! Calling arguments
  integer, intent(in) :: npsidim
  real(kind=8),dimension(:), pointer,intent(out) :: lphi, lhphi
  character(len=*), intent(in) :: subname

  lphi = f_malloc_ptr(npsidim,id='lphi')
  lhphi = f_malloc_ptr(npsidim,id='lhphi')

  call to_zero(npsidim, lphi(1))
  call to_zero(npsidim, lhphi(1))

end subroutine allocate_auxiliary_basis_function


subroutine deallocate_auxiliary_basis_function(subname, lphi, lhphi)
  use module_base
  implicit none

  ! Calling arguments
  real(kind=8),dimension(:), pointer :: lphi, lhphi
  character(len=*), intent(in) :: subname

  call f_free_ptr(lphi)
  call f_free_ptr(lhphi)

end subroutine deallocate_auxiliary_basis_function


subroutine destroy_new_locregs(iproc, nproc, tmb)
  use module_base
  use module_types
  use module_interfaces, except_this_one => destroy_new_locregs
  use communications_base, only: deallocate_comms_linear, deallocate_p2pComms
  use communications, only: synchronize_onesided_communication
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(DFT_wavefunction), intent(inout) :: tmb

  ! Local variables
  character(len=*), parameter :: subname='destroy_new_locregs'

  !!call wait_p2p_communication(iproc, nproc, tmb%comgp)
  call synchronize_onesided_communication(iproc, nproc, tmb%comgp)
  call deallocate_p2pComms(tmb%comgp)

  call deallocate_local_zone_descriptors(tmb%lzd)
  call deallocate_orbitals_data(tmb%orbs)

  call deallocate_comms_linear(tmb%collcom)
  call deallocate_comms_linear(tmb%collcom_sr)

end subroutine destroy_new_locregs


subroutine destroy_DFT_wavefunction(wfn)
  use module_base
  use module_types
  use module_interfaces, except_this_one => destroy_DFT_wavefunction
  use communications_base, only: deallocate_comms_linear, deallocate_p2pComms
  use sparsematrix_base, only: deallocate_sparse_matrix, allocate_matrices, deallocate_matrices
  use foe_base, only: foe_data_deallocate
  implicit none
  
  ! Calling arguments
  type(DFT_wavefunction), intent(inout) :: wfn

  ! Local variables
  character(len=*), parameter :: subname='destroy_DFT_wavefunction'
  integer :: ispin, i

!  call f_routine(id=subname)

  call f_free_ptr(wfn%psi)
  call f_free_ptr(wfn%psit_c)
  call f_free_ptr(wfn%psit_f)

  call deallocate_p2pComms(wfn%comgp)
  if (associated(wfn%linmat%ks)) then
      do ispin=1,wfn%linmat%l%nspin
          call deallocate_sparse_matrix(wfn%linmat%ks(ispin))
      end do
      deallocate(wfn%linmat%ks)
  end if
  if (associated(wfn%linmat%ks_e)) then
      do ispin=1,wfn%linmat%l%nspin
          call deallocate_sparse_matrix(wfn%linmat%ks_e(ispin))
      end do
      deallocate(wfn%linmat%ks_e)
  end if
  call deallocate_sparse_matrix(wfn%linmat%s)
  call deallocate_sparse_matrix(wfn%linmat%m)
  call deallocate_sparse_matrix(wfn%linmat%l)
  call deallocate_matrices(wfn%linmat%ovrlp_)
  call deallocate_matrices(wfn%linmat%ham_)
  call deallocate_matrices(wfn%linmat%kernel_)
  do i=1,size(wfn%linmat%ovrlppowers_)
      call deallocate_matrices(wfn%linmat%ovrlppowers_(i))
  end do
  call deallocate_orbitals_data(wfn%orbs)
  call deallocate_comms_linear(wfn%collcom)
  call deallocate_comms_linear(wfn%collcom_sr)
  call deallocate_local_zone_descriptors(wfn%lzd)
  call foe_data_deallocate(wfn%foe_obj)

  call f_free_ptr(wfn%coeff)

!  call f_release_routine()

end subroutine destroy_DFT_wavefunction


subroutine update_wavefunctions_size(lzd,npsidim_orbs,npsidim_comp,orbs,iproc,nproc)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(local_zone_descriptors), intent(in) :: lzd
  type(orbitals_data), intent(in) :: orbs
  integer, intent(in) :: iproc, nproc
  integer, intent(out) :: npsidim_orbs, npsidim_comp

  ! Local variables
  character(len = *), parameter :: subname = "update_wavefunctions_size"
  integer :: npsidim, ilr, iorb
  integer :: nvctr_tot,jproc
  integer, allocatable, dimension(:) :: ncntt 
  integer, allocatable, dimension(:,:) :: nvctr_par

  call f_routine(id='update_wavefunctions_size')

  npsidim = 0
  do iorb=1,orbs%norbp
   ilr=orbs%inwhichlocreg(iorb+orbs%isorb)
   npsidim = npsidim + lzd%Llr(ilr)%wfd%nvctr_c+7*lzd%Llr(ilr)%wfd%nvctr_f
  end do
  npsidim_orbs=max(npsidim,1)

  nvctr_tot = 1
  do iorb=1,orbs%norbp
     ilr=orbs%inwhichlocreg(iorb+orbs%isorb)
     nvctr_tot = max(nvctr_tot,lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f)
  end do
  if (nproc > 1) then
     call mpiallred(nvctr_tot, 1, mpi_max, bigdft_mpi%mpi_comm)
  end if

  nvctr_par = f_malloc((/ 0.to.nproc-1, 1.to.1 /),id='nvctr_par')

  call kpts_to_procs_via_obj(nproc,1,nvctr_tot,nvctr_par)

  ncntt = f_malloc(0.to.nproc-1,id='ncntt')

  ncntt(:) = 0
  do jproc=0,nproc-1
     ncntt(jproc)=ncntt(jproc)+&
          nvctr_par(jproc,1)*orbs%norbp*orbs%nspinor
  end do

  npsidim_comp=sum(ncntt(0:nproc-1))

  call f_free(nvctr_par)

  call f_free(ncntt)

  call f_release_routine()

end subroutine update_wavefunctions_size


subroutine create_large_tmbs(iproc, nproc, KSwfn, tmb, denspot,nlpsp,input, at, rxyz, lowaccur_converged)
  use module_base
  use module_types
  use module_interfaces, except_this_one => create_large_tmbs
  implicit none

  ! Calling arguments
  integer, intent(in):: iproc, nproc
  type(DFT_Wavefunction), intent(inout):: KSwfn, tmb
  type(DFT_local_fields), intent(in):: denspot
  type(DFT_PSP_projectors), intent(inout) :: nlpsp
  type(input_variables), intent(in):: input
  type(atoms_data), intent(in):: at
  real(8),dimension(3,at%astruct%nat), intent(in):: rxyz
  logical,intent(in):: lowaccur_converged

  ! Local variables
  integer:: iorb, ilr, istat
  logical, dimension(:), allocatable :: lr_mask
  real(8),dimension(:,:), allocatable:: locrad_tmp
  real(8),dimension(:,:), allocatable:: locregCenter
  character(len=*), parameter:: subname='create_large_tmbs'

  call f_routine(id=subname)

  locregCenter=f_malloc((/3,tmb%lzd%nlr/),id='locregCenter')
  locrad_tmp=f_malloc((/tmb%lzd%nlr,3/),id='locrad_tmp')
  lr_mask=f_malloc0(tmb%lzd%nlr,id='lr_mask')

  do iorb=1,tmb%orbs%norb
      ilr=tmb%orbs%inwhichlocreg(iorb)
      locregCenter(:,ilr)=tmb%lzd%llr(ilr)%locregCenter
  end do
  do ilr=1,tmb%lzd%nlr
      locrad_tmp(ilr,1)=tmb%lzd%llr(ilr)%locrad+8.d0*tmb%lzd%hgrids(1)
      locrad_tmp(ilr,2)=tmb%lzd%llr(ilr)%locrad_kernel
      locrad_tmp(ilr,3)=tmb%lzd%llr(ilr)%locrad_mult
  end do

  !temporary,  moved from update_locreg
  tmb%orbs%eval=-0.5_gp
  call update_locreg(iproc, nproc, tmb%lzd%nlr, locrad_tmp(:,1), locrad_tmp(:,2), locrad_tmp(:,3), locregCenter, tmb%lzd%glr, &
       .false., denspot%dpbox%nscatterarr, tmb%lzd%hgrids(1), tmb%lzd%hgrids(2), tmb%lzd%hgrids(3), &
       at%astruct, input, KSwfn%orbs, tmb%orbs, tmb%ham_descr%lzd, tmb%ham_descr%npsidim_orbs, tmb%ham_descr%npsidim_comp, &
       tmb%ham_descr%comgp, tmb%ham_descr%collcom)

  call allocate_auxiliary_basis_function(max(tmb%ham_descr%npsidim_comp,tmb%ham_descr%npsidim_orbs), subname, &
       tmb%ham_descr%psi, tmb%hpsi)

  tmb%ham_descr%can_use_transposed=.false.
  !!nullify(tmb%ham_descr%psit_c)
  !!nullify(tmb%ham_descr%psit_f)
  allocate(tmb%confdatarr(tmb%orbs%norbp), stat=istat)

  if(.not.lowaccur_converged) then
      call define_confinement_data(tmb%confdatarr,tmb%orbs,rxyz,at,&
           & tmb%ham_descr%lzd%hgrids(1),tmb%ham_descr%lzd%hgrids(2),tmb%ham_descr%lzd%hgrids(3),&
           & 4,input%lin%potentialPrefac_lowaccuracy,tmb%ham_descr%lzd,tmb%orbs%onwhichatom)
  else
      call define_confinement_data(tmb%confdatarr,tmb%orbs,rxyz,at,&
           & tmb%ham_descr%lzd%hgrids(1),tmb%ham_descr%lzd%hgrids(2),tmb%ham_descr%lzd%hgrids(3),&
           & 4,input%lin%potentialPrefac_highaccuracy,tmb%ham_descr%lzd,tmb%orbs%onwhichatom)
  end if

  call f_free(locregCenter)
  call f_free(locrad_tmp)

  call update_lrmask_array(tmb%lzd%nlr,tmb%orbs,lr_mask)

  !when the new tmbs are created the projector descriptors can be updated
  call update_nlpsp(nlpsp,tmb%ham_descr%lzd%nlr,tmb%ham_descr%lzd%llr,KSwfn%Lzd%Glr,lr_mask)
  if (iproc == 0) call print_nlpsp(nlpsp)
  call f_free(lr_mask)
  call f_release_routine()
end subroutine create_large_tmbs

!>create the masking array to determine which localization regions have to be 
!! calculated
subroutine update_lrmask_array(nlr,orbs,lr_mask)
  use module_types, only: orbitals_data
  implicit none
  integer, intent(in) :: nlr
  type(orbitals_data), intent(in) :: orbs
  !> array of the masking, prior initialized to .false.
  logical, dimension(nlr), intent(inout) :: lr_mask
  !local variables
  integer :: ikpt,isorb,ieorb,nspinor,ilr,iorb

  !create the masking array according to the locregs which are known by the task
  if (orbs%norbp>0) then
      ikpt=orbs%iokpt(1)
      loop_kpt: do
         call orbs_in_kpt(ikpt,orbs,isorb,ieorb,nspinor)

         !activate all the localization regions which are present in the orbitals
         do iorb=isorb,ieorb
            ilr=orbs%inwhichlocreg(iorb+orbs%isorb)
            lr_mask(ilr)=.true.
         end do
         !last k-point has been treated
         if (ieorb == orbs%norbp) exit loop_kpt
         ikpt=ikpt+1
      end do loop_kpt
  end if
 
end subroutine update_lrmask_array

subroutine set_optimization_variables(input, at, lorbs, nlr, onwhichatom, confdatarr, &
     convCritMix, lowaccur_converged, nit_scc, mix_hist, alpha_mix, locrad, target_function, nit_basis, &
     convcrit_dmin, nitdmin, conv_crit_TMB)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: nlr
  type(orbitals_data), intent(in) :: lorbs
  type(input_variables), intent(in) :: input
  type(atoms_data), intent(in) :: at
  integer, dimension(lorbs%norb), intent(in) :: onwhichatom
  type(confpot_data),dimension(lorbs%norbp), intent(inout) :: confdatarr
  real(kind=8), intent(out) :: convCritMix, alpha_mix, convcrit_dmin, conv_crit_TMB
  logical, intent(in) :: lowaccur_converged
  integer, intent(out) :: nit_scc, mix_hist, nitdmin
  real(kind=8), dimension(nlr), intent(out) :: locrad
  integer, intent(out) :: target_function, nit_basis

  ! Local variables
  integer :: iorb, ilr, iiat, iilr


  if(lowaccur_converged) then
      do iorb=1,lorbs%norbp
          iiat=onwhichatom(lorbs%isorb+iorb)
          confdatarr(iorb)%prefac=input%lin%potentialPrefac_highaccuracy(at%astruct%iatype(iiat))
      end do
      target_function=TARGET_FUNCTION_IS_ENERGY
      nit_basis=input%lin%nItBasis_highaccuracy
      nit_scc=input%lin%nitSCCWhenFixed_highaccuracy
      mix_hist=input%lin%mixHist_highaccuracy
      do ilr=1,nlr
          iilr=mod(ilr-1,lorbs%norbu)+1 !correct value for a spin polarized system
          locrad(ilr)=input%lin%locrad_highaccuracy(iilr)
      end do
      alpha_mix=input%lin%alpha_mix_highaccuracy
      convCritMix=input%lin%convCritMix_highaccuracy
      convcrit_dmin=input%lin%convCritDmin_highaccuracy
      nitdmin=input%lin%nItdmin_highaccuracy
      conv_crit_TMB=input%lin%convCrit_lowaccuracy
  else
      do iorb=1,lorbs%norbp
          iiat=onwhichatom(lorbs%isorb+iorb)
          confdatarr(iorb)%prefac=input%lin%potentialPrefac_lowaccuracy(at%astruct%iatype(iiat))
      end do
      target_function=TARGET_FUNCTION_IS_TRACE
      nit_basis=input%lin%nItBasis_lowaccuracy
      nit_scc=input%lin%nitSCCWhenFixed_lowaccuracy
      mix_hist=input%lin%mixHist_lowaccuracy
      do ilr=1,nlr
          locrad(ilr)=input%lin%locrad_lowaccuracy(ilr)
      end do
      alpha_mix=input%lin%alpha_mix_lowaccuracy
      convCritMix=input%lin%convCritMix_lowaccuracy
      convcrit_dmin=input%lin%convCritDmin_lowaccuracy
      nitdmin=input%lin%nItdmin_lowaccuracy
      conv_crit_TMB=input%lin%convCrit_highaccuracy
  end if

  !!! new hybrid version... not the best place here
  !!if (input%lin%nit_highaccuracy==-1) then
  !!    do iorb=1,lorbs%norbp
  !!        ilr=lorbs%inwhichlocreg(lorbs%isorb+iorb)
  !!        iiat=onwhichatom(lorbs%isorb+iorb)
  !!        confdatarr(iorb)%prefac=input%lin%potentialPrefac_lowaccuracy(at%astruct%iatype(iiat))
  !!    end do
  !!    wfnmd%bs%target_function=TARGET_FUNCTION_IS_HYBRID
  !!    wfnmd%bs%nit_basis_optimization=input%lin%nItBasis_lowaccuracy
  !!    wfnmd%bs%conv_crit=input%lin%convCrit_lowaccuracy
  !!    nit_scc=input%lin%nitSCCWhenFixed_lowaccuracy
  !!    mix_hist=input%lin%mixHist_lowaccuracy
  !!    do ilr=1,nlr
  !!        locrad(ilr)=input%lin%locrad_lowaccuracy(ilr)
  !!    end do
  !!    alpha_mix=input%lin%alpha_mix_lowaccuracy
  !!end if

end subroutine set_optimization_variables



subroutine adjust_locregs_and_confinement(iproc, nproc, hx, hy, hz, at, input, &
           rxyz, KSwfn, tmb, denspot, nlpsp,ldiis, locreg_increased, lowaccur_converged, locrad)
  use module_base
  use module_types
  use module_interfaces, except_this_one => adjust_locregs_and_confinement
  use yaml_output
  use communications_base, only: deallocate_comms_linear, deallocate_p2pComms
  use communications, only: synchronize_onesided_communication
  use sparsematrix_base, only: sparse_matrix_null, deallocate_sparse_matrix, allocate_matrices, deallocate_matrices
  use sparsematrix_init, only: init_sparse_matrix, check_kernel_cutoff, init_matrix_taskgroups
  use foe_base, only: foe_data_deallocate
  implicit none
  
  ! Calling argument
  integer, intent(in) :: iproc, nproc
  real(8), intent(in) :: hx, hy, hz
  type(atoms_data), intent(in) :: at
  type(input_variables), intent(in) :: input
  real(8),dimension(3,at%astruct%nat), intent(in):: rxyz
  type(DFT_wavefunction), intent(inout) :: KSwfn, tmb
  type(DFT_local_fields), intent(inout) :: denspot
  type(DFT_PSP_projectors), intent(inout) :: nlpsp
  type(localizedDIISParameters), intent(inout) :: ldiis
  logical, intent(out) :: locreg_increased
  logical, intent(in) :: lowaccur_converged
  real(8), dimension(tmb%lzd%nlr), intent(inout) :: locrad

  ! Local variables
  integer :: ilr, npsidim_orbs_tmp, npsidim_comp_tmp, ispin, i
  real(kind=8),dimension(:,:), allocatable :: locregCenter
  real(kind=8),dimension(:), allocatable :: lphilarge, locrad_kernel, locrad_mult
  type(local_zone_descriptors) :: lzd_tmp
  character(len=*), parameter :: subname='adjust_locregs_and_confinement'

  call f_routine(id='adjust_locregs_and_confinement')

  locreg_increased=.false.
  if(lowaccur_converged ) then
      do ilr = 1, tmb%lzd%nlr/input%nspin !for a spin polarized calculation, the remaining elements of input%lin%locrad_high/lowaccuracy are not meaningful
         if(input%lin%locrad_highaccuracy(ilr) /= input%lin%locrad_lowaccuracy(ilr)) then
             !!if(iproc==0) write(*,'(1x,a)') 'Increasing the localization radius for the high accuracy part.'
             if (iproc==0) call yaml_map('Increasing the localization radius for the high accuracy part',.true.)
             locreg_increased=.true.
             exit
         end if
      end do
  end if
  if (iproc==0) then
      if (locreg_increased) then
          call yaml_map('Locreg increased',.true.)
      else
          call yaml_map('Locreg increased',.false.)
      end if
  end if

  if(locreg_increased) then
     !tag=1
     !call wait_p2p_communication(iproc, nproc, tmb%comgp)
     call synchronize_onesided_communication(iproc, nproc, tmb%comgp)
     call deallocate_p2pComms(tmb%comgp)

     call deallocate_comms_linear(tmb%collcom)
     call deallocate_comms_linear(tmb%collcom_sr)

     call nullify_local_zone_descriptors(lzd_tmp)
     call copy_local_zone_descriptors(tmb%lzd, lzd_tmp, subname)
     call deallocate_local_zone_descriptors(tmb%lzd)
     
     call foe_data_deallocate(tmb%foe_obj)

     npsidim_orbs_tmp = tmb%npsidim_orbs
     npsidim_comp_tmp = tmb%npsidim_comp


     !call deallocate_sparse_matrix(tmb%linmat%denskern_large)
     !call deallocate_sparse_matrix(tmb%linmat%inv_ovrlp_large)
     !call deallocate_sparse_matrix(tmb%linmat%ovrlp)
     !!call deallocate_sparse_matrix(tmb%linmat%ham)

     if (associated(tmb%linmat%ks)) then
         do ispin=1,tmb%linmat%l%nspin
             call deallocate_sparse_matrix(tmb%linmat%ks(ispin))
         end do
         deallocate(tmb%linmat%ks)
     end if
     if (associated(tmb%linmat%ks_e)) then
         do ispin=1,tmb%linmat%l%nspin
             call deallocate_sparse_matrix(tmb%linmat%ks_e(ispin))
         end do
         deallocate(tmb%linmat%ks_e)
     end if
     call deallocate_sparse_matrix(tmb%linmat%s)
     call deallocate_sparse_matrix(tmb%linmat%m)
     call deallocate_sparse_matrix(tmb%linmat%l)
     call deallocate_matrices(tmb%linmat%ovrlp_)
     call deallocate_matrices(tmb%linmat%ham_)
     call deallocate_matrices(tmb%linmat%kernel_)
     do i=1,size(tmb%linmat%ovrlppowers_)
         call deallocate_matrices(tmb%linmat%ovrlppowers_(i))
     end do

     locregCenter = f_malloc((/ 3, lzd_tmp%nlr /),id='locregCenter')
     locrad_kernel = f_malloc(lzd_tmp%nlr,id='locrad_kernel')
     locrad_mult = f_malloc(lzd_tmp%nlr,id='locrad_mult')
     do ilr=1,lzd_tmp%nlr
        locregCenter(:,ilr)=lzd_tmp%llr(ilr)%locregCenter
        locrad_kernel(ilr)=lzd_tmp%llr(ilr)%locrad_kernel
        locrad_mult(ilr)=lzd_tmp%llr(ilr)%locrad_mult
     end do


     !temporary,  moved from update_locreg
     tmb%orbs%eval=-0.5_gp
     call update_locreg(iproc, nproc, lzd_tmp%nlr, locrad, locrad_kernel, locrad_mult, locregCenter, lzd_tmp%glr, .false., &
          denspot%dpbox%nscatterarr, hx, hy, hz, at%astruct, input, KSwfn%orbs, tmb%orbs, tmb%lzd, &
          tmb%npsidim_orbs, tmb%npsidim_comp, tmb%comgp, tmb%collcom, tmb%foe_obj, tmb%collcom_sr)

     call f_free(locregCenter)
     call f_free(locrad_kernel)
     call f_free(locrad_mult)

     ! calculate psi in new locreg
     lphilarge = f_malloc(tmb%npsidim_orbs,id='lphilarge')
     call to_zero(tmb%npsidim_orbs, lphilarge(1))
     call small_to_large_locreg(iproc, npsidim_orbs_tmp, tmb%npsidim_orbs, lzd_tmp, tmb%lzd, &
          tmb%orbs, tmb%psi, lphilarge)

     call deallocate_local_zone_descriptors(lzd_tmp)
     call f_free_ptr(tmb%psi)
     call f_free_ptr(tmb%psit_c)
     call f_free_ptr(tmb%psit_f)
     tmb%psi = f_malloc_ptr(tmb%npsidim_orbs,id='tmb%psi')
     tmb%psit_c = f_malloc_ptr(tmb%collcom%ndimind_c,id='tmb%psit_c')
     tmb%psit_f = f_malloc_ptr(7*tmb%collcom%ndimind_f,id='tmb%psit_f')

     call vcopy(tmb%npsidim_orbs, lphilarge(1), 1, tmb%psi(1), 1)
     call f_free(lphilarge)
     
     call update_ldiis_arrays(tmb, subname, ldiis)

     ! Emit that lzd has been changed.
     if (tmb%c_obj /= 0) then
        call kswfn_emit_lzd(tmb, iproc, nproc)
     end if

     ! Now update hamiltonian descriptors
     !call destroy_new_locregs(iproc, nproc, tmblarge)

     ! to eventually be better sorted - replace with e.g. destroy_hamiltonian_descriptors
     call synchronize_onesided_communication(iproc, nproc, tmb%ham_descr%comgp)
     call deallocate_p2pComms(tmb%ham_descr%comgp)
     call deallocate_local_zone_descriptors(tmb%ham_descr%lzd)
     call deallocate_comms_linear(tmb%ham_descr%collcom)

     call deallocate_auxiliary_basis_function(subname, tmb%ham_descr%psi, tmb%hpsi)
     if(tmb%ham_descr%can_use_transposed) then
        !call f_free_ptr(tmb%ham_descr%psit_c)
        !call f_free_ptr(tmb%ham_descr%psit_f)
        tmb%ham_descr%can_use_transposed=.false.
     end if
     
     deallocate(tmb%confdatarr)

     call create_large_tmbs(iproc, nproc, KSwfn, tmb, denspot,nlpsp, input, at, rxyz, lowaccur_converged)
     call f_free_ptr(tmb%ham_descr%psit_c)
     call f_free_ptr(tmb%ham_descr%psit_f)
     tmb%ham_descr%psit_c = f_malloc_ptr(tmb%ham_descr%collcom%ndimind_c,id='tmb%ham_descr%psit_c')
     tmb%ham_descr%psit_f = f_malloc_ptr(7*tmb%ham_descr%collcom%ndimind_f,id='tmb%ham_descr%psit_f')

     ! check the extent of the kernel cutoff (must be at least shamop radius)
     call check_kernel_cutoff(iproc, tmb%orbs, at, tmb%lzd)

     ! Update sparse matrices
     call init_sparse_matrix_wrapper(iproc, nproc, input%nspin, tmb%orbs, tmb%ham_descr%lzd, at%astruct, &
          input%store_index, imode=1, smat=tmb%linmat%m)
     call allocate_matrices(tmb%linmat%m, allocate_full=.false., &
          matname='tmb%linmat%ham_', mat=tmb%linmat%ham_)
     !!call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
     !!     tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%ham)
     call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
          tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%m)

     call init_sparse_matrix_wrapper(iproc, nproc, input%nspin, tmb%orbs, tmb%lzd, at%astruct, &
          input%store_index, imode=1, smat=tmb%linmat%s)
     call allocate_matrices(tmb%linmat%s, allocate_full=.false., &
          matname='tmb%linmat%ovrlp_', mat=tmb%linmat%ovrlp_)
     !call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
     !     tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%ovrlp)
     call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
          tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%s)

     call check_kernel_cutoff(iproc, tmb%orbs, at, tmb%lzd)
     call init_sparse_matrix_wrapper(iproc, nproc, input%nspin, tmb%orbs, tmb%lzd, at%astruct, &
          input%store_index, imode=2, smat=tmb%linmat%l)
     call allocate_matrices(tmb%linmat%l, allocate_full=.false., &
          matname='tmb%linmat%kernel_', mat=tmb%linmat%kernel_)
     do i=1,size(tmb%linmat%ovrlppowers_)
         call allocate_matrices(tmb%linmat%l, allocate_full=.false., &
              matname='tmb%linmat%ovrlppowers_(i)', mat=tmb%linmat%ovrlppowers_(i))
     end do
     !!call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
     !!     tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%denskern_large)
     call init_matrixindex_in_compressed_fortransposed(iproc, nproc, tmb%orbs, &
          tmb%collcom, tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%l)

     !tmb%linmat%inv_ovrlp_large=sparse_matrix_null()
     !call sparse_copy_pattern(tmb%linmat%l, tmb%linmat%inv_ovrlp_large, iproc, subname)

     call init_matrix_taskgroups(iproc, nproc, input%enable_matrix_taskgroups, &
          tmb%collcom, tmb%collcom_sr, tmb%linmat%s)
     call init_matrix_taskgroups(iproc, nproc, input%enable_matrix_taskgroups, &
          tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%m)
     call init_matrix_taskgroups(iproc, nproc, input%enable_matrix_taskgroups, &
          tmb%ham_descr%collcom, tmb%collcom_sr, tmb%linmat%l)


     nullify(tmb%linmat%ks)
     nullify(tmb%linmat%ks_e)
     if (input%lin%scf_mode/=LINEAR_FOE .or. input%lin%pulay_correction .or.  input%lin%new_pulay_correction .or. &
         (input%lin%plotBasisFunctions /= WF_FORMAT_NONE) .or. input%lin%diag_end) then
         call init_sparse_matrix_for_KSorbs(iproc, nproc, KSwfn%orbs, input, input%lin%extra_states, &
              tmb%linmat%ks, tmb%linmat%ks_e)
     end if



  else ! no change in locrad, just confining potential that needs updating

     call define_confinement_data(tmb%confdatarr,tmb%orbs,rxyz,at,&
          & tmb%ham_descr%lzd%hgrids(1),tmb%ham_descr%lzd%hgrids(2),tmb%ham_descr%lzd%hgrids(3),&
          & 4,input%lin%potentialPrefac_highaccuracy,tmb%ham_descr%lzd,tmb%orbs%onwhichatom)

  end if

  call f_release_routine()

end subroutine adjust_locregs_and_confinement



subroutine adjust_DIIS_for_high_accuracy(input, denspot, lowaccur_converged, ldiis_coeff_hist, ldiis_coeff_changed)
  use module_base
  use module_types
  use module_interfaces, except_this_one => adjust_DIIS_for_high_accuracy
  implicit none
  
  ! Calling arguments
  type(input_variables), intent(in) :: input
  type(DFT_local_fields), intent(inout) :: denspot
  logical, intent(in) :: lowaccur_converged
  integer, intent(inout) :: ldiis_coeff_hist
  logical, intent(out) :: ldiis_coeff_changed  

  if(lowaccur_converged) then
     if (input%lin%scf_mode==LINEAR_DIRECT_MINIMIZATION) then
        ! check whether ldiis_coeff_hist arrays will need reallocating due to change in history length
        if (ldiis_coeff_hist /= input%lin%dmin_hist_highaccuracy) then
           ldiis_coeff_changed=.true.
        else
           ldiis_coeff_changed=.false.
        end if
        ldiis_coeff_hist=input%lin%dmin_hist_highaccuracy
     end if
  else
     if (input%lin%scf_mode==LINEAR_DIRECT_MINIMIZATION) then
        ldiis_coeff_changed=.false.
     end if
  end if
  
end subroutine adjust_DIIS_for_high_accuracy


subroutine check_whether_lowaccuracy_converged(itout, nit_lowaccuracy, lowaccuracy_convcrit, &
     lowaccur_converged, pnrm_out)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer, intent(in) :: itout
  integer, intent(in) :: nit_lowaccuracy
  real(8), intent(in) :: lowaccuracy_convcrit
  logical, intent(inout) :: lowaccur_converged
  real(kind=8), intent(in) :: pnrm_out
  
  if(.not.lowaccur_converged .and. &
       (itout>=nit_lowaccuracy+1 .or. pnrm_out<lowaccuracy_convcrit)) then
     lowaccur_converged=.true.
     !cur_it_highaccuracy=0
  end if 

end subroutine check_whether_lowaccuracy_converged



subroutine set_variables_for_hybrid(nlr, input, at, orbs, lowaccur_converged, confdatarr, &
           target_function, nit_basis, nit_scc, mix_hist, locrad, alpha_mix, convCritMix, &
           conv_crit_TMB)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  integer, intent(in) :: nlr
  type(input_variables), intent(in) :: input
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  logical,intent(out) :: lowaccur_converged
  type(confpot_data),dimension(orbs%norbp), intent(inout) :: confdatarr
  integer, intent(out) :: target_function, nit_basis, nit_scc, mix_hist
  real(kind=8),dimension(nlr), intent(out) :: locrad
  real(kind=8), intent(out) :: alpha_mix, convCritMix, conv_crit_TMB

  ! Local variables
  integer :: iorb, ilr, iiat

  lowaccur_converged=.false.
  do iorb=1,orbs%norbp
      ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
      iiat=orbs%onwhichatom(orbs%isorb+iorb)
      confdatarr(iorb)%prefac=input%lin%potentialPrefac_lowaccuracy(at%astruct%iatype(iiat))
  end do
  target_function=TARGET_FUNCTION_IS_HYBRID
  nit_basis=input%lin%nItBasis_lowaccuracy
  nit_scc=input%lin%nitSCCWhenFixed_lowaccuracy
  mix_hist=input%lin%mixHist_lowaccuracy
  do ilr=1,nlr
      locrad(ilr)=input%lin%locrad_lowaccuracy(ilr)
  end do
  alpha_mix=input%lin%alpha_mix_lowaccuracy
  convCritMix=input%lin%convCritMix_lowaccuracy
  conv_crit_TMB=input%lin%convCrit_lowaccuracy

end subroutine set_variables_for_hybrid




subroutine increase_FOE_cutoff(iproc, nproc, lzd, astruct, input, orbs_KS, orbs, foe_obj, init)
  use module_base
  use module_types
  use module_interfaces, except_this_one => increase_FOE_cutoff
  use yaml_output
  use foe_base, only: foe_data
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(local_zone_descriptors), intent(in) :: lzd
  type(atomic_structure), intent(in) :: astruct
  type(input_variables), intent(in) :: input
  type(orbitals_data), intent(in) :: orbs_KS, orbs
  type(foe_data), intent(out) :: foe_obj
  logical,intent(in) :: init
  ! Local variables
  integer :: ilr
  real(kind=8),save :: cutoff_incr
  real(kind=8),dimension(:,:), allocatable :: locreg_centers

  call f_routine(id='increase_FOE_cutoff')

  ! Just initialize the save variable
  if (init) then
      cutoff_incr=0.d0
      call f_release_routine()
      return
  end if


  ! How much should the cutoff be increased
  cutoff_incr=cutoff_incr+1.d0

  if (iproc==0) then
      call yaml_newline()
      call yaml_map('Need to re-initialize FOE cutoff',.true.)
      call yaml_newline()
      call yaml_map('Total increase of FOE cutoff wrt input values',cutoff_incr,fmt='(f5.1)')
  end if

  ! Re-initialize the foe data
  locreg_centers = f_malloc((/3,lzd%nlr/),id='locreg_centers')
  do ilr=1,lzd%nlr
      locreg_centers(1:3,ilr)=lzd%llr(ilr)%locregcenter(1:3)
  end do
  call init_foe(iproc, nproc, input, orbs_KS, foe_obj, reset=.false.)
  call f_free(locreg_centers)

  call f_release_routine()

end subroutine increase_FOE_cutoff


!> Set negative entries to zero
subroutine clean_rho(iproc, nproc, npt, rho)
  use module_base
  use yaml_output
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc, npt
  real(kind=8),dimension(npt), intent(inout) :: rho

  ! Local variables
  integer :: ncorrection, ipt
  real(kind=8) :: charge_correction

  if (iproc==0) then
      call yaml_newline()
      call yaml_map('Need to correct charge density',.true.)
      call yaml_warning('set to 1.d-20 instead of 0.d0')
  end if

  ncorrection=0
  charge_correction=0.d0
  do ipt=1,npt
      if (rho(ipt)<0.d0) then
          if (rho(ipt)>=-1.d-9) then
              ! negative, but small, so simply set to zero
              charge_correction=charge_correction+rho(ipt)
              !rho(ipt)=0.d0
              rho(ipt)=1.d-20
              ncorrection=ncorrection+1
          else
              ! negative, but non-negligible, so issue a warning
              call yaml_warning('considerable negative rho, value: '//trim(yaml_toa(rho(ipt),fmt='(es12.4)'))) 
              charge_correction=charge_correction+rho(ipt)
              !rho(ipt)=0.d0
              rho(ipt)=1.d-20
              ncorrection=ncorrection+1
          end if
      end if
  end do

  if (nproc > 1) then
      call mpiallred(ncorrection, 1, mpi_sum, bigdft_mpi%mpi_comm)
      call mpiallred(charge_correction, 1, mpi_sum, bigdft_mpi%mpi_comm)
  end if

  if (iproc==0) then
      call yaml_newline()
      call yaml_map('number of corrected points',ncorrection)
      call yaml_newline()
      call yaml_map('total charge correction',abs(charge_correction),fmt='(es14.5)')
      call yaml_newline()
  end if
  
end subroutine clean_rho

subroutine corrections_for_negative_charge(iproc, nproc, KSwfn, at, input, tmb, denspot)
  use module_types
  use module_interfaces
  use yaml_output
  use dynamic_memory
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc
  type(DFT_wavefunction), intent(in) :: KSwfn
  type(atoms_data), intent(in) :: at
  type(input_variables), intent(in) :: input
  type(DFT_wavefunction), intent(inout) :: tmb
  type(DFT_local_fields), intent(inout) :: denspot

  call f_routine(id='corrections_for_negative_charge')

  if (iproc==0) call yaml_warning('No increase of FOE cutoff')
  call clean_rho(iproc, nproc, denspot%dpbox%ndimrhopot, denspot%rhov)

  call f_release_routine()

end subroutine corrections_for_negative_charge


subroutine determine_sparsity_pattern(iproc, nproc, orbs, lzd, nnonzero, nonzero)
      use module_base
      use module_types
      use module_interfaces, except_this_one => determine_sparsity_pattern
      implicit none
    
      ! Calling arguments
      integer, intent(in) :: iproc, nproc
      type(orbitals_data), intent(in) :: orbs
      type(local_zone_descriptors), intent(in) :: lzd
      integer, intent(out) :: nnonzero
      integer, dimension(:,:), pointer,intent(out) :: nonzero
    
      ! Local variables
      integer :: iorb, jorb, ioverlaporb, ilr, jlr, ilrold
      integer :: iiorb, ii
      !!integer :: istat
      logical :: isoverlap
      integer :: onseg
      logical, dimension(:,:), allocatable :: overlapMatrix
      integer, dimension(:), allocatable :: noverlapsarr
      integer, dimension(:,:), allocatable :: overlaps_op
      !character(len=*), parameter :: subname='determine_overlap_from_descriptors'

      call f_routine('determine_sparsity_pattern')
    
      overlapMatrix = f_malloc((/orbs%norbu,maxval(orbs%norbu_par(:,0))/),id='overlapMatrix')
      noverlapsarr = f_malloc(orbs%norbup,id='noverlapsarr')
    
      overlapMatrix=.false.
      do iorb=1,orbs%norbup
         ioverlaporb=0 ! counts the overlaps for the given orbital.
         iiorb=orbs%isorbu+iorb
         ilr=orbs%inWhichLocreg(iiorb)
         do jorb=1,orbs%norbu
            jlr=orbs%inWhichLocreg(jorb)
            call check_overlap_cubic_periodic(lzd%Glr,lzd%llr(ilr),lzd%llr(jlr),isoverlap)
            if(isoverlap) then
               ! From the viewpoint of the box boundaries, an overlap between ilr and jlr is possible.
               ! Now explicitely check whether there is an overlap by using the descriptors.
               call check_overlap_from_descriptors_periodic(lzd%llr(ilr)%wfd%nseg_c, lzd%llr(jlr)%wfd%nseg_c,&
                    lzd%llr(ilr)%wfd%keyglob, lzd%llr(jlr)%wfd%keyglob, &
                    isoverlap, onseg)
               if(isoverlap) then
                  ! There is really an overlap
                  overlapMatrix(jorb,iorb)=.true.
                  ioverlaporb=ioverlaporb+1
               else
                  overlapMatrix(jorb,iorb)=.false.
               end if
            else
               overlapMatrix(jorb,iorb)=.false.
            end if
         end do
         noverlapsarr(iorb)=ioverlaporb
      end do


      overlaps_op = f_malloc((/maxval(noverlapsarr),orbs%norbup/),id='overlaps_op')
    
      ! Now we know how many overlaps have to be calculated, so determine which orbital overlaps
      ! with which one. This is essentially the same loop as above, but we use the array 'overlapMatrix'
      ! which indicates the overlaps.
      iiorb=0
      ilrold=-1
      do iorb=1,orbs%norbup
         ioverlaporb=0 ! counts the overlaps for the given orbital.
         iiorb=orbs%isorbu+iorb
         do jorb=1,orbs%norbu
            if(overlapMatrix(jorb,iorb)) then
               ioverlaporb=ioverlaporb+1
               overlaps_op(ioverlaporb,iorb)=jorb
            end if
         end do 
      end do


      nnonzero=0
      do iorb=1,orbs%norbup
          nnonzero=nnonzero+noverlapsarr(iorb)
      end do
      nonzero = f_malloc_ptr((/2,nnonzero/),id='nonzero')
      ii=0
      do iorb=1,orbs%norbup
          iiorb=orbs%isorbu+iorb
          do jorb=1,noverlapsarr(iorb)
              ii=ii+1
              nonzero(1,ii)=overlaps_op(jorb,iorb)
              nonzero(2,ii)=iiorb
          end do
      end do

      call f_free(overlapMatrix)
      call f_free(noverlapsarr)
      call f_free(overlaps_op)
    
      call f_release_routine()

end subroutine determine_sparsity_pattern



subroutine determine_sparsity_pattern_distance(orbs, lzd, astruct, cutoff, nnonzero, nonzero)
  use module_base
  use module_types
  implicit none

  ! Calling arguments
  type(orbitals_data), intent(in) :: orbs
  type(local_zone_descriptors), intent(in) :: lzd
  type(atomic_structure), intent(in) :: astruct
  real(kind=8),dimension(lzd%nlr), intent(in) :: cutoff
  integer, intent(out) :: nnonzero
  integer, dimension(:,:), pointer,intent(out) :: nonzero

  ! Local variables
  integer :: iorb, iiorb, ilr, iwa, itype, jjorb, jlr, jwa, jtype, ii
  real(kind=8) :: tt, cut

  call f_routine('determine_sparsity_pattern_distance')

      nnonzero=0
      do iorb=1,orbs%norbup
         iiorb=orbs%isorbu+iorb
         ilr=orbs%inwhichlocreg(iiorb)
         iwa=orbs%onwhichatom(iiorb)
         itype=astruct%iatype(iwa)
         do jjorb=1,orbs%norbu
            jlr=orbs%inwhichlocreg(jjorb)
            jwa=orbs%onwhichatom(jjorb)
            jtype=astruct%iatype(jwa)
            tt = (lzd%llr(ilr)%locregcenter(1)-lzd%llr(jlr)%locregcenter(1))**2 + &
                 (lzd%llr(ilr)%locregcenter(2)-lzd%llr(jlr)%locregcenter(2))**2 + &
                 (lzd%llr(ilr)%locregcenter(3)-lzd%llr(jlr)%locregcenter(3))**2
            cut = cutoff(ilr)+cutoff(jlr)!+2.d0*incr
            tt=sqrt(tt)
            if (tt<=cut) then
               nnonzero=nnonzero+1
            end if
         end do
      end do
      !call mpiallred(nnonzero, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      nonzero = f_malloc_ptr((/2,nnonzero/),id='nonzero')

      ii=0
      do iorb=1,orbs%norbup
         iiorb=orbs%isorbu+iorb
         ilr=orbs%inwhichlocreg(iiorb)
         iwa=orbs%onwhichatom(iiorb)
         itype=astruct%iatype(iwa)
         do jjorb=1,orbs%norbu
            jlr=orbs%inwhichlocreg(jjorb)
            jwa=orbs%onwhichatom(jjorb)
            jtype=astruct%iatype(jwa)
            tt = (lzd%llr(ilr)%locregcenter(1)-lzd%llr(jlr)%locregcenter(1))**2 + &
                 (lzd%llr(ilr)%locregcenter(2)-lzd%llr(jlr)%locregcenter(2))**2 + &
                 (lzd%llr(ilr)%locregcenter(3)-lzd%llr(jlr)%locregcenter(3))**2
            cut = cutoff(ilr)+cutoff(jlr)!+2.d0*incr
            tt=sqrt(tt)
            if (tt<=cut) then
               ii=ii+1
               nonzero(1,ii)=jjorb
               nonzero(2,ii)=iiorb
            end if
         end do
      end do

  call f_release_routine()

end subroutine determine_sparsity_pattern_distance


subroutine init_sparse_matrix_wrapper(iproc, nproc, nspin, orbs, lzd, astruct, store_index, imode, smat)
  use module_base
  use module_types
  use sparsematrix_init, only: init_sparse_matrix
  use module_interfaces, except_this_one => init_sparse_matrix_wrapper
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc, nspin, imode
  type(orbitals_data), intent(in) :: orbs
  type(local_zone_descriptors), intent(in) :: lzd
  type(atomic_structure), intent(in) :: astruct
  logical,intent(in) :: store_index
  type(sparse_matrix), intent(out) :: smat
  
  ! Local variables
  integer :: nnonzero, nnonzero_mult, ilr
  integer, dimension(:,:), pointer :: nonzero, nonzero_mult
  real(kind=8),dimension(:), allocatable :: cutoff
  integer, parameter :: KEYS=1
  integer, parameter :: DISTANCE=2

  call f_routine(id='init_sparse_matrix_wrapper')

  cutoff = f_malloc(lzd%nlr,id='cutoff')

  do ilr=1,lzd%nlr
      cutoff(ilr)=lzd%llr(ilr)%locrad_mult
  end do

  if (imode==KEYS) then
      call determine_sparsity_pattern(iproc, nproc, orbs, lzd, nnonzero, nonzero)
  else if (imode==DISTANCE) then
      call determine_sparsity_pattern_distance(orbs, lzd, astruct, lzd%llr(:)%locrad_kernel, nnonzero, nonzero)
  else
      stop 'wrong imode'
  end if
  call determine_sparsity_pattern_distance(orbs, lzd, astruct, lzd%llr(:)%locrad_mult, nnonzero_mult, nonzero_mult)
  call init_sparse_matrix(iproc, nproc, nspin, orbs%norb, orbs%norbp, orbs%isorb, &
       orbs%norbu, orbs%norbup, orbs%isorbu, store_index, &
       nnonzero, nonzero, nnonzero_mult, nonzero_mult, smat)
  call f_free_ptr(nonzero)
  call f_free_ptr(nonzero_mult)
  call f_free(cutoff)

  call f_release_routine()

end subroutine init_sparse_matrix_wrapper


!> Initializes a sparse matrix type compatible with the ditribution of the KS orbitals
subroutine init_sparse_matrix_for_KSorbs(iproc, nproc, orbs, input, nextra, smat, smat_extra)
  use module_base
  use module_types
  use module_interfaces, except_this_one => init_sparse_matrix_for_KSorbs
  use sparsematrix_base, only: sparse_matrix
  use sparsematrix_init, only: init_sparse_matrix
  use sparsematrix_base, only: sparse_matrix_null
  implicit none

  ! Calling arguments
  integer, intent(in) :: iproc, nproc, nextra
  type(orbitals_data), intent(in) :: orbs
  type(input_variables), intent(in) :: input
  type(sparse_matrix),dimension(:),pointer,intent(out) :: smat, smat_extra

  ! Local variables
  integer :: i, iorb, iiorb, jorb, ind, norb, norbp, isorb, ispin
  integer,dimension(:,:),allocatable :: nonzero
  type(orbitals_data) :: orbs_aux
  character(len=*), parameter :: subname='init_sparse_matrix_for_KSorbs'

  call f_routine('init_sparse_matrix_for_KSorbs')


  allocate(smat(input%nspin))
  allocate(smat_extra(input%nspin))


  ! First the type for the normal KS orbitals distribution
  do ispin=1,input%nspin

      smat(ispin) = sparse_matrix_null()
      smat_extra(ispin) = sparse_matrix_null()

      if (ispin==1) then
          norb=orbs%norbu
          norbp=orbs%norbup
          isorb=orbs%isorbu
      else
          norb=orbs%norbd
          norbp=orbs%norbdp
          isorb=orbs%isorbd
      end if

      nonzero = f_malloc((/2,norb*norbp/), id='nonzero')
      i=0
      do iorb=1,norbp
          iiorb=isorb+iorb
          do jorb=1,norb
              i=i+1
              ind=(iiorb-1)*norb+jorb
              nonzero(1,i)=jorb
              nonzero(2,i)=iiorb
          end do
      end do
      call init_sparse_matrix(iproc, nproc, input%nspin, orbs%norb, orbs%norbp, orbs%isorb, &
           norb, norbp, isorb, input%store_index, &
           norb*norbp, nonzero, norb, nonzero, smat(ispin), print_info_=.false.)
      call f_free(nonzero)


      !SM: WARNING: not tested whether the spin works here! Mainly just to create a
      !spin down part and make the compiler happy at another location.
      ! Now the distribution for the KS orbitals including the extr states. Requires
      ! first to calculate a corresponding orbs type.
      call nullify_orbitals_data(orbs_aux)
      call orbitals_descriptors(iproc, nproc, norb+nextra, norb+nextra, 0, input%nspin, orbs%nspinor,&
           input%gen_nkpt, input%gen_kpt, input%gen_wkpt, orbs_aux, .false.)
      nonzero = f_malloc((/2,orbs_aux%norbu*orbs_aux%norbup/), id='nonzero')
      !write(*,*) 'iproc, norb, norbp, norbu, norbup', iproc, orbs_aux%norb, orbs_aux%norbp, orbs_aux%norbu, orbs_aux%norbup
      i=0
      do iorb=1,orbs_aux%norbup
          iiorb=orbs_aux%isorbu+iorb
          do jorb=1,orbs_aux%norbu
              i=i+1
              ind=(iiorb-1)*orbs_aux%norbu+jorb
              nonzero(1,i)=jorb
              nonzero(2,i)=iiorb
          end do
      end do
      !!call init_sparse_matrix(iproc, nproc, input%nspin, orbs_aux%norb, orbs_aux%norbp, orbs_aux%isorb, &
      !!     orbs%norbu, orbs%norbup, orbs%isorbu, input%store_index, &
      !!     orbs_aux%norbu*orbs_aux%norbup, nonzero, orbs_aux%norbu, nonzero, smat_extra, print_info_=.false.)
      !!call init_sparse_matrix(iproc, nproc, input%nspin, orbs_aux%norb, orbs_aux%norbp, orbs_aux%isorb, &
      !!     norb, norbp, isorb, input%store_index, &
      !!     orbs_aux%norbu*orbs_aux%norbup, nonzero, orbs_aux%norbu, nonzero, smat_extra(ispin), print_info_=.false.)
      call init_sparse_matrix(iproc, nproc, input%nspin, orbs_aux%norb, orbs_aux%norbp, orbs_aux%isorb, &
           orbs_aux%norb, orbs_aux%norbp, orbs_aux%isorb, input%store_index, &
           orbs_aux%norbu*orbs_aux%norbup, nonzero, orbs_aux%norbu, nonzero, smat_extra(ispin), print_info_=.false.)
      call f_free(nonzero)
      call deallocate_orbitals_data(orbs_aux)

  end do

  call f_release_routine()

end subroutine init_sparse_matrix_for_KSorbs
