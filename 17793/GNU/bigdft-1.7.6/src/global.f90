!!  Minima hopping program
!! @author
!!    Copyright (C) 2008-2013 UNIBAS
!!    This file is not freely distributed.
!!    A licence is necessary from UNIBAS
!!    New modified version 17th Nov 2009 Sandip De


!> MINHOP
!!  Main program for the minima hopping
program MINHOP
  use module_base
  use bigdft_run
!  use module_types, only: input_variables,bigdft_run_id_toa,BIGDFT_SUCCESS
!  use module_interfaces
!  use module_input_dicts
!  use m_ab6_symmetry
  use yaml_output
  use module_atoms, only: deallocate_atoms_data,atoms_data,astruct_dump_to_file
  !implicit real(kind=8) (a-h,o-z) !!!dangerous when using modules!!!
  implicit none
  logical :: newmin,CPUcheck,occured,exist_poslocm,exist_posacc
  character(len=20) :: unitsp,atmn
  character(len=60) :: run_id
!  type(atoms_data) :: atoms,md_atoms
!  type(input_variables), target :: inputs_opt, inputs_md
!  type(restart_objects) :: rst
  !C parameters for minima hopping
  integer, parameter :: mdmin=2
  real(kind=8), parameter :: beta_S=1.10d0,beta_O=1.10d0,beta_N=1.d0/1.10d0
  real(kind=8), parameter :: alpha_A=1.d0/1.10d0,alpha_R=1.10d0
  real(kind=8), allocatable, dimension(:,:) ::vxyz,gg,poshop
  real(kind=8), allocatable, dimension(:) :: rcov,ksevals
  real(kind=8), dimension(:,:), pointer :: pos
  real(kind=8),allocatable, dimension(:) :: en_arr,ct_arr
  real(kind=8),allocatable, dimension(:,:) :: fp_arr
  real(kind=8),allocatable, dimension(:) :: fp,wfp,fphop
  real(kind=8),allocatable, dimension(:,:,:) :: pl_arr
  integer :: iproc,nproc,iat,ierr,infocode,nksevals,i,natoms,nrandoff,nsoften
  integer :: n_unique,n_nonuni,nputback,i_stat,ncount_bigdft,ngeopt,nid,nlmin,nlminx
  integer :: ilmin,ierror,natp,k,nvisit,kid,k_e,nlmin_old,ndfree,ndfroz,ixyz,nummax,nummin
  integer :: istepnext,istep
  character(len=*), parameter :: subname='global'
  character(len=41) :: filename
  character(len=4) :: fn4
  character(len=5) :: fn5
!  character(len=16) :: fn16
!  character(len=18) :: fn18
  character(len=50) :: comment
  character(len=128) :: msg
!  real(gp), parameter :: bohr=0.5291772108_gp !1 AU in angstroem
  integer :: nconfig
  !integer, dimension(4) :: mpi_info
  real(kind=4) :: tcpu1,ts,tcpu2,cpulimit
  real(kind=8) :: accepted,ediff,ekinetic,dt,av_ekinetic,av_ediff,escape,escape_sam
  real(kind=8) :: escape_old,escape_new,rejected,fp_sep,e_hop,count_sdcg,count_soft
  real(kind=8) :: count_md,count_bfgs,energyold,e_pos,tt,en_delta,fp_delta
  real(kind=8) :: t1,t2,t3,ebest_l,dmin,tleft,d,ss
  real(kind=8), external :: dnrm2
  real(kind=8), dimension(:,:), pointer :: rxyz_opt,rxyz_md
  
  type(run_objects) :: run_opt,run_md !< the two runs parameters
  type(DFT_global_output) :: outs
  type(dictionary), pointer :: user_inputs,options,run
  integer:: nposacc=0
  logical:: disable_hatrans

  call f_lib_initialize()

  call bigdft_command_line_options(options)
  call bigdft_init(options)
  if (bigdft_nruns(options) > 1) call f_err_throw('runs-file not supported for MINHOP executable')
  !temporary
  run => options // 'BigDFT' // 0

  
  !actual value of iproc
  iproc=bigdft_mpi%iproc+bigdft_mpi%igroup*bigdft_mpi%ngroup
   

   if (iproc==0) call print_logo_MH()

  !if (iproc == 0) write(*,'(a,2(1x,1pe10.3))') '(MH) predicted fraction accepted, rejected', & 
  !     ratio/(1.d0+ratio), 1.d0/(1.d0+ratio)
  accepted=0.0d0


  call cpu_time(tcpu1)

  !reset input and output positions of run
  call bigdft_get_run_properties(run,run_id=run_id)
  call bigdft_set_run_properties(run,run_id=trim(run_id)//trim(bigdft_run_id_toa()),&
       posinp='poscur'//trim(bigdft_run_id_toa()))

  call run_objects_init(run_opt,run)
  !then the unoptimized parameters
  call bigdft_set_run_properties(run,run_id='md'//trim(run_id)//trim(bigdft_run_id_toa()))

  call run_objects_init(run_md,run,source=run_opt)
  
  !options and run are not needed
  call dict_free(options)
  nullify(run)

  !at this point we have run_opt and run_md that are 
  !linked by the same restart objects (i.e. DFT wavefunctions)
  !and both have initial positions set to poscur.
  !however their atomic position are not shallow copied and have to be updated
  !before switching method

!!$  !for each of the configuration set the input files
!!$  !optimized input parameters
!!$  call dict_init(user_inputs)
!!$  call user_dict_from_files(user_inputs, trim(run_id)//trim(bigdft_run_id_toa()), &
!!$       & 'poscur'//trim(bigdft_run_id_toa()), bigdft_mpi)
!!$  call inputs_from_dict(inputs_opt, atoms, user_inputs)
!!$  call dict_free(user_inputs)
!!$
!!$  !unoptimized input parameters
!!$  call dict_init(user_inputs)
!!$  call user_dict_from_files(user_inputs, 'md'//trim(run_id)//trim(bigdft_run_id_toa()), &
!!$       & 'poscur'//trim(bigdft_run_id_toa()), bigdft_mpi)
!!$  call inputs_from_dict(inputs_md, md_atoms, user_inputs)
!!$  call dict_free(user_inputs)
!!$  !use only the atoms structure for the run
!!$  call deallocate_atoms_data(md_atoms) 

!   write(*,*) 'nat=',atoms%astruct%nat
  ! Create the DFT_global_output container.
  call init_global_output(outs, bigdft_nat(run_opt))

  !performs few checks
  if (run_opt%inputs%inguess_geopt .ne. run_md%inputs%inguess_geopt) then 
     write(*,*) "input guess methods in MD and OPT have to be identical"
     stop
  endif

  !associate the same output directory 
  if (run_opt%inputs%dir_output /= run_md%inputs%dir_output) then
     call deldir(trim(run_md%inputs%dir_output),len_trim(run_md%inputs%dir_output),ierr)
     if (ierr /=0) then
        call yaml_warning('Error found while deleting '//&
             trim(run_md%inputs%dir_output))
     end if
     run_md%inputs%dir_output=run_opt%inputs%dir_output
  end if

  !get number of atoms of the system, to allocate local arrays
  natoms=bigdft_nat(run_opt)!bigdft_get_number_of_atoms(atoms)

  !define pointers towards the atomic positions
  rxyz_md => bigdft_get_rxyz_ptr(run_md)
  rxyz_opt => bigdft_get_rxyz_ptr(run_opt)


  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) beta_S, beta_O, beta_N',(/beta_S,beta_O,beta_N/),fmt='(1pe11.4)')
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) alpha_A, alpha_R',(/alpha_A,alpha_R/),fmt='(1pe11.4)')
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) mdmin=',mdmin)

  ! allocate other arrays
  vxyz = f_malloc((/ 3, natoms /),id='vxyz')
  gg = f_malloc((/ 3, natoms /),id='gg')
  poshop = f_malloc((/ 3, natoms /),id='poshop')
  rcov = f_malloc(natoms,id='rcov')
  pos = f_malloc_ptr((/ 3, natoms /),id='pos')

  call give_rcov(bigdft_mpi%iproc,run_opt%atoms,natoms,rcov)

! read random offset
  open(unit=11,file='rand'//trim(bigdft_run_id_toa())//'.inp')
  read(11,*) nrandoff
  !        write(*,*) 'nrandoff ',nrandoff
  close(11)
  do i=1,nrandoff
     call random_number(ts)
  enddo

  inquire(file='disable_hatrans',exist=disable_hatrans)
  
  ! open output files
  if (bigdft_mpi%iproc==0) then 
     !open(unit=2,file='global'//trim(bigdft_run_id_toa())//'.mon',status='unknown',position='append')
     open(unit=2,file=trim(run_md%inputs%dir_output)//'global.mon',status='unknown',position='append')
     !open(unit=16,file='geopt'//trim(bigdft_run_id_toa())//'.mon',status='unknown')
     !open(unit=16,file=trim(inputs_md%dir_output)//'geopt.mon',status='unknown')
  endif

  ! read input parameters
  write(filename,'(a6,i3.3)') 'ioput'//trim(bigdft_run_id_toa()) !,bigdft_mpi%iproc
  open(unit=11,file='ioput'//trim(bigdft_run_id_toa()),status='old')
  read(11,*) ediff,ekinetic,dt,nsoften
  close(11)
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Input ediff, ekinetic, dt',(/ediff,ekinetic,dt/),fmt='(1pe10.3)')
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Input nsoften',nsoften,fmt='(i4)')

  n_unique=0
  n_nonuni=0
  av_ekinetic=0.d0
  av_ediff=0.d0
  escape=0.d0
  escape_sam=0.d0
  escape_old=0.d0
  escape_new=0.d0
  rejected=0.d0
  fp_sep=0.d0
  e_hop=1.d100

!C first local minimum
  count_sdcg=0.d0
  count_bfgs=0.d0
  count_soft=0.d0
  count_md=0.d0
  nputback=0

  run_opt%inputs%inputPsiId=0

!!$  call init_restart_objects(bigdft_mpi%iproc,inputs_opt,atoms,rst)
!!$  call nullify_run_objects(runObj)
!!$  call run_objects_associate(runObj, inputs_md, atoms, rst)
  !we start with md
  call call_bigdft(run_md,outs,infocode)


  energyold=1.d100
  ncount_bigdft=0

  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) calling conjgrad for the first time here. energy ',outs%energy)

  ngeopt=0
  do 
     write(fn4,'(i4.4)') ngeopt+1
     filename='poslocm_'//fn4//'_'//trim(bigdft_run_id_toa())//'.xyz'
!     write(*,*) 'filename: ',filename
     inquire(file=trim(filename),exist=exist_poslocm)
     if (exist_poslocm) then
        ngeopt=ngeopt+1
     else
        exit 
     endif
  enddo 
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) number of poslocm files that exist already ',ngeopt)

  nposacc=0
  do 
     write(fn4,'(i4.4)') nposacc+1
     filename='posacc_'//fn4//'_'//trim(bigdft_run_id_toa())//'.xyz'
!     write(*,*) 'filename: ',filename
     inquire(file=trim(filename),exist=exist_posacc)
     if (exist_posacc) then
        nposacc=nposacc+1
     else
        exit 
     endif
  enddo 
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) number of posacc files that exist already ',nposacc)

  call geopt(run_md, outs, bigdft_mpi%nproc,bigdft_mpi%iproc,ncount_bigdft)
!  call release_run_objects(runObj)
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Wvfnctn Opt. steps for approximate geo. rel of initial conf.',ncount_bigdft)
  count_sdcg=count_sdcg+ncount_bigdft

  ngeopt=ngeopt+1
!  if (bigdft_mpi%iproc == 0) then 
!     tt=dnrm2(3*natoms,ff,1)
!     write(fn4,'(i4.4)') ngeopt
!     write(comment,'(a,1pe10.3)')'fnrm= ',tt
!     call write_atomic_file('posimed_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
!      open(unit=864,file='ksemed_'//fn4//'_'//trim(bigdft_run_id_toa()))
!      do i=1,nksevals
!      write(864,*) ksevals(i)
!      enddo
!      close(864)
!  endif
! call yaml_map('Conditions for ha_trans',[bigdft_get_geocode(run_md)=='F',(.not. disable_hatrans)])


  if (bigdft_get_geocode(run_md)=='F' .and. (.not. disable_hatrans)) call ha_trans(bigdft_nat(run_md),rxyz_md)

!  if ( .not. atoms%astruct%geocode=='F') then 
!         write(*,*) 'Generating new input guess'
!          inputs_opt%inputPsiId=0
!          call run_objects_associate(runObj, inputs_opt, atoms, rst)
!          call call_bigdft(runObj,outs,bigdft_mpi%nproc,bigdft_mpi%iproc,infocode)
!          inputs_opt%inputPsiId=1
!  endif   
  !call run_objects_associate(runObj, inputs_opt, atoms, rst)
  !here the atomic positions of run_opt have to be updated
  call bigdft_set_rxyz(run_opt,rxyz=rxyz_md)!bigdft_get_rxyz_ptr(run_md))
  outs%fnoise = 0.0_gp !Bastian: reset noise from coarse level

  call geopt(run_opt, outs, bigdft_mpi%nproc,bigdft_mpi%iproc,ncount_bigdft)
  !call release_run_objects(runObj)
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Wvfnctn Opt. steps for accurate geo. rel of initial conf.',ncount_bigdft)
  count_bfgs=count_bfgs+ncount_bigdft
  e_pos = outs%energy
  call bigdft_get_rxyz(run_opt,rxyz=pos)
  !call f_memcpy(src=atoms%astruct%rxyz,dest=pos)
  if (bigdft_mpi%iproc == 0) then
     call yaml_map('(MH) INPUT(relaxed), e_pos ',outs%energy,fmt='(e17.10)')
  end if

  nid=natoms
  fp = f_malloc(nid,id='fp')
  wfp = f_malloc(nid,id='wfp')
  fphop = f_malloc(nid,id='fphop')
  
  call fingerprint(bigdft_mpi%iproc,bigdft_nat(run_opt),nid,pos,rcov,fp,&
       bigdft_get_geocode(run_opt),bigdft_get_cell(run_opt))

  !retrieve the eigenvalues from this run
  nksevals=bigdft_norb(run_opt)
  ksevals = f_malloc(nksevals,id='ksevals')
  call bigdft_get_eval(run_opt,ksevals)

  if (bigdft_mpi%iproc == 0 .and. nposacc==0) then
     tt=dnrm2(3*outs%fdim,outs%fxyz,1)
     nposacc=nposacc+1
     write(fn4,'(i4.4)')nposacc
     if(disable_hatrans)then
         write(comment,'(a,1pe10.3)')'ha_trans disabled, fnrm= ',tt
     else
         write(comment,'(a,1pe10.3)')'ha_trans enabled, fnrm= ',tt
     endif
     call bigdft_write_atomic_file(run_opt,outs,&
          'posacc_'//fn4//'_'//trim(bigdft_run_id_toa()),&
          trim(comment),cwd_path=.true.)
!!$     call write_atomic_file('posacc_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!!$          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
  endif

  if (bigdft_mpi%iproc == 0) then 
     tt=dnrm2(3*outs%fdim,outs%fxyz,1)
     write(fn4,'(i4.4)') ngeopt
     write(comment,'(a,1pe10.3)')'fnrm= ',tt
     call bigdft_write_atomic_file(run_opt,outs,&
          'poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()),&
          trim(comment),cwd_path=.true.)
!!$     call write_atomic_file('poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!!$          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
      open(unit=864,file='kseloc_'//fn4//'_'//trim(bigdft_run_id_toa()))
      do i=1,nksevals
      write(864,*) ksevals(i)
      enddo
      close(864)
  endif

! Read previously found energies and properties
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) name of enarr','enarr'//trim(bigdft_run_id_toa()))
  open(unit=12,file='enarr'//trim(bigdft_run_id_toa()),status='unknown')
   if (bigdft_mpi%iproc == 0) call yaml_map('(MH) name of idarr','idarr'//trim(bigdft_run_id_toa()))
  open(unit=14,file='idarr'//trim(bigdft_run_id_toa()),status='unknown')
  read(12,*) nlmin,nlminx
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) nlmin,nlminx',(/nlmin,nlminx/))
  if (nlmin.gt.nlminx) stop 'nlmin>nlminx'
  read(12,*) en_delta,fp_delta
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Delta energy, fingerprint',(/en_delta,fp_delta/))
  if (bigdft_mpi%iproc == 0 .and. nlmin.gt.nlminx) call yaml_scalar('nlmin>nlminx')
  if (nlmin.gt.nlminx) stop 'nlmin>nlminx'

  en_arr = f_malloc(nlminx,id='en_arr')
  ct_arr = f_malloc(nlminx,id='ct_arr')
  fp_arr = f_malloc((/ nid, nlminx /),id='fp_arr')
  pl_arr = f_malloc((/ 3, natoms, nlminx /),id='pl_arr')
  if (nlmin.eq.0) then 
     if (bigdft_mpi%iproc == 0) call yaml_map('(MH) New run with nlminx=',nlminx)
  else
     if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Restart run with nlmin, nlminx=',(/nlmin,nlminx/))
     do k=1,nlmin
        read(12,*) en_arr(k),ct_arr(k)
        if (en_arr(k).lt.en_arr(max(1,k-1))) stop 'wrong ordering in enarr.dat'
        if (nlmin.gt.0) read(14,*) (fp_arr(i,k),i=1,nid)
     enddo
  endif
  close(12)
  close(14)
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) read idarr','idarr'//trim(bigdft_run_id_toa()))
  
  ! If restart read previous poslocm's
  ! here we should use bigdft built-in routines to read atomic positions
  call f_err_open_try()
  ierr=0
  do ilmin=1,nlmin

     write(fn5,'(i5.5)') ilmin
     filename = 'poslow'//fn5//'_'//trim(bigdft_run_id_toa())!//'.xyz'
!!$     call f_file_exists(filename,exist_poslocm)
!!$     if (.not. exist_poslocm) then
!!$        write(*,*) bigdft_mpi%iproc,' COULD not read file ',filename
!!$        exit
!!$     end if
     call bigdft_get_rxyz(filename=filename,rxyz_add=pl_arr(1,1,ilmin))
     if (f_err_check()) then
        if (f_err_check(err_name='BIGDFT_INPUT_FILE_ERROR')) then
           write(*,*) bigdft_mpi%iproc,' COULD not read file ',filename
           exit
        else
           ierr = f_get_last_error(msg)
        end if
     end if
!!$     open(unit=192,file=filename,status='old',iostat=ierror)
!!$     if (ierror /= 0) then
!!$        write(*,*) bigdft_mpi%iproc,' COULD not read file ',filename
!!$        exit
!!$     end if
!!$     read(192,*) natp,unitsp,en_arr(ilmin)
!!$     if (natoms.ne.natp) stop   'nat <> natp'
!!$     if (trim(unitsp).ne.trim(atoms%astruct%units) .and. bigdft_mpi%iproc.eq.0) write(*,*)  & 
!!$          '(MH) different units in poslow and poscur file: ',trim(unitsp),' ',trim(atoms%astruct%units)
!!$     if (trim(unitsp).ne.trim(atoms%astruct%units) .and. bigdft_mpi%iproc.eq.0) call yaml_scalar( &
!!$          '(MH) different units in poslow and poscur file: '//trim(unitsp)//' , '//trim(atoms%astruct%units))
!!$     write(*,*) "Bohr_Ang",Bohr_Ang
!!$     read(192,*) 
!!$     do iat=1,natoms
!!$        read(192,*) atmn,t1,t2,t3
!!$        if (atoms%astruct%units=='angstroem' .or. atoms%astruct%units=='angstroemd0') then ! if Angstroem convert to Bohr
!!$           pl_arr(1,iat,ilmin)=t1/Bohr_Ang
!!$           pl_arr(2,iat,ilmin)=t2/Bohr_Ang
!!$           pl_arr(3,iat,ilmin)=t3/Bohr_Ang
!!$        else
!!$           pl_arr(1,iat,ilmin)=t1
!!$           pl_arr(2,iat,ilmin)=t2
!!$           pl_arr(3,iat,ilmin)=t3
!!$        endif
!!$     enddo
!!$     close(192)
     if (bigdft_mpi%iproc == 0) call yaml_scalar('(MH) read file '//trim(filename))
  end do
  call f_err_close_try()
  if (ierr /= 0) call f_err_throw(err_id = ierr, err_msg = msg)
             
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) number of read poslow files', nlmin)
  
  ebest_l=outs%energy 
  if (nlmin.eq.0) then !new run
     nlmin=1
     en_arr(1)=outs%energy
     ct_arr(1)=1.d0
     nvisit=1
     do i=1,nid
        fp_arr(i,1)=fp(i)
     enddo
     call bigdft_get_rxyz(run_opt,rxyz_add=pl_arr(1,1,1))
!!$     do iat=1,natoms
!!$        pl_arr(1,iat,1)=atoms%astruct%rxyz(1,iat) 
!!$        pl_arr(2,iat,1)=atoms%astruct%rxyz(2,iat) 
!!$        pl_arr(3,iat,1)=atoms%astruct%rxyz(3,iat) 
!!$     enddo

  else  ! continuation run, check whether the poscur file has been modified by hand
     call identical(bigdft_mpi%iproc,nlminx,nlmin,nid,e_pos,fp,en_arr,fp_arr,en_delta,fp_delta,&
          newmin,kid,dmin,k_e,n_unique,n_nonuni)
     if (newmin) then  
        if (bigdft_mpi%iproc == 0) call yaml_map('(MH) initial minimum is new, dmin= ',dmin)
        nlmin=nlmin+1
        if (nlmin.gt.nlminx) stop 'nlminx too small'
        !            add minimum to history list
        call insert(bigdft_mpi%iproc,nlminx,nlmin,nid,natoms,k_e,e_pos,fp,pos,en_arr,ct_arr,fp_arr,pl_arr)  
        k_e=k_e+1
        if (k_e .gt. nlminx .or. k_e .lt. 1) stop "k_e out of bounds"
        nvisit=int(ct_arr(k_e))
     else
        if (bigdft_mpi%iproc == 0) call yaml_map('(MH) initial minimum is old, dmin=',dmin)
        if (kid .gt. nlminx .or. kid .lt. 1) stop "kid out of bounds"
        nvisit=int(ct_arr(kid))
     endif
  endif

  if (bigdft_mpi%iproc == 0) then
          write(2,'((1x,f10.0),1x,1pe21.14,2(1x,1pe10.3),a,i5)')  &
          escape,e_pos,ediff,ekinetic,'  P ',nvisit 
          call f_utils_flush(2)
          !call bigdft_utils_flush(unit=2)
          !flush(2)
  end if

  nlmin_old=nlmin
  CPUcheck=.false.

  !equivalent methods
  call bigdft_get_rxyz(run_opt,rxyz=pos)
  !call f_memcpy(src=atoms%astruct%rxyz,dest=pos)
  !call vcopy(3*natoms, atoms%astruct%rxyz(1,1) , 1, pos(1,1), 1)

  !C outer (hopping) loop
   hopping_loop: do
  if (nlmin >= nlminx) then 
     if (bigdft_mpi%iproc == 0) then
        call yaml_map('(MH) nlminx collected by process'//trim(yaml_toa(bigdft_mpi%iproc)),nlmin)
     endif
     exit hopping_loop
  endif

5555 continue

  !C check whether CPU time exceeded
  tleft=1.d100
  call cpu_time(tcpu2)
  if(bigdft_mpi%iproc==0 .and. CPUcheck)then
     open(unit=55,file='CPUlimit_global',status='unknown')
     read(55,*,end=555) cpulimit 
     cpulimit=cpulimit*3600
     call yaml_mapping_open('(MH) CPUtime Check',flow=.true.)
     call yaml_map(' nlmin',nlmin)
     call yaml_map(' tcpu2-tcpu1,cpulimit',(/tcpu2-tcpu1,cpulimit/))
     call yaml_mapping_close(advance='yes')
     tleft=cpulimit-(tcpu2-tcpu1)
  end if
555 continue
  close(55)
  !maybe broadcast on comm_world?
  call mpibcast(tleft,1,comm=bigdft_mpi%mpi_comm)
  !call MPI_BCAST(tleft,1,MPI_DOUBLE_PRECISION,0,bigdft_mpi%mpi_comm,ierr)
  if (tleft < 0.d0) then
     call yaml_map('(MH) Process'//trim(yaml_toa(bigdft_mpi%iproc))//' has exceeded CPU time. Tleft',tleft)
     exit hopping_loop
  endif
  CPUcheck=.true.

  !call run_objects_associate(runObj, inputs_md, atoms, rst, pos(1,1))
  call bigdft_set_rxyz(run_md,rxyz=pos) !one could write here also rxyz=bigdft_get_rxyz_ptr(run_opt)
  escape=escape+1.d0
  call mdescape(nsoften,mdmin,ekinetic,gg,vxyz,dt,count_md, run_md, outs, &
                ngeopt,bigdft_mpi%nproc,bigdft_mpi%iproc)
  if (bigdft_mpi%iproc == 0) then 
     tt=dnrm2(3*outs%fdim,outs%fxyz,1)
     write(fn4,'(i4.4)') nint(escape)
     write(comment,'(a,1pe10.3)')'fnrm= ',tt
     
     call bigdft_write_atomic_file(run_md,outs,&
          'posaftermd_'//fn4//'_'//trim(bigdft_run_id_toa()),&
          trim(comment),cwd_path=.true.)

!!$     call write_atomic_file('posaftermd_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!!$          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
  endif

     if (bigdft_get_geocode(run_md) == 'F') &
          & call fixfrag_posvel(bigdft_mpi%iproc,bigdft_nat(run_md),rcov,rxyz_md,vxyz,1,occured)
     if (bigdft_get_geocode(run_md) == 'S') &
          & call fixfrag_posvel_slab(bigdft_mpi%iproc,bigdft_nat(run_md),rcov,rxyz_md,vxyz,1)
     
  av_ekinetic=av_ekinetic+ekinetic
  ncount_bigdft=0

  call geopt(run_md, outs, bigdft_mpi%nproc,bigdft_mpi%iproc,ncount_bigdft)
  !call release_run_objects(runObj)  

  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Wvfnctn Opt. steps for approximate geo. rel of MD conf.',ncount_bigdft)
     count_sdcg=count_sdcg+ncount_bigdft

  ngeopt=ngeopt+1
!  if (bigdft_mpi%iproc == 0) then 
!     tt=dnrm2(3*outs%fdim,outs%fxyz,1)
!     write(fn4,'(i4.4)') ngeopt
!     write(comment,'(a,1pe10.3)')'fnrm= ',tt
!     call write_atomic_file('posimed_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
!      open(unit=864,file='ksemed_'//fn4//'_'//trim(bigdft_run_id_toa()))
!      do i=1,nksevals
!      write(864,*) ksevals(i)
!      enddo
!      close(864)
!  endif

  if (bigdft_get_geocode(run_md)=='F' .and. (.not. disable_hatrans)) call ha_trans(bigdft_nat(run_md),rxyz_md)

!  if ( .not. atoms%astruct%geocode=='F') then 
!         write(*,*) 'Generating new input guess'
!          inputs_opt%inputPsiId=0
!          call run_objects_associate(runObj, inputs_opt, atoms, rst)
!          call call_bigdft(runObj,outs,bigdft_mpi%nproc,bigdft_mpi%iproc,infocode)
!          inputs_opt%inputPsiId=1
!  endif   
  !call run_objects_associate(runObj, inputs_opt, atoms, rst)
  call bigdft_set_rxyz(run_opt,rxyz=rxyz_md)
  outs%fnoise = 0.0_gp !Bastian: reset noise from coarse level
  call geopt(run_opt, outs, bigdft_mpi%nproc,bigdft_mpi%iproc,ncount_bigdft)
  !call release_run_objects(runObj)
  if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Wvfnctn Opt. steps for accurate geo. rel of MD conf',ncount_bigdft)
  count_bfgs=count_bfgs+ncount_bigdft
  
  call bigdft_get_eval(run_opt,ksevals)
!!$  if (i_stat /= BIGDFT_SUCCESS) then
!!$     write(*,*)'error(ksevals), i_stat',i_stat
!!$     if (bigdft_mpi%iproc == 0) call yaml_map('(MH) Number of Wvfnctn Opt. steps for accurate geo. rel of MD conf.', & 
!!$          ncount_bigdft)
!!$     stop
!!$  end if


  if (bigdft_mpi%iproc == 0) then 
     tt=dnrm2(3*outs%fdim,outs%fxyz,1)
     write(fn4,'(i4.4)') ngeopt
     write(comment,'(a,1pe10.3)')'fnrm= ',tt
     call bigdft_write_atomic_file(run_opt,outs,&
          'poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()),trim(comment),&
          cwd_path=.true.)

!!$     call write_atomic_file('poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!!$          outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
        open(unit=864,file='kseloc_'//fn4//'_'//trim(bigdft_run_id_toa()))
        do i=1,nksevals
          write(864,*) ksevals(i)
        enddo
        close(864)
  endif

  if (bigdft_mpi%iproc == 0) then 
     call yaml_mapping_open('(MH) GEOPT finished')
     call yaml_map('nlminx, nlmin',(/nlminx,nlmin/))
     call yaml_map('(MH) new e_pos, old e_pos',(/outs%energy,e_pos/))
     call yaml_mapping_close()
  endif

  call fingerprint(bigdft_mpi%iproc,bigdft_nat(run_opt),nid,rxyz_opt,rcov,wfp, & 
                   bigdft_get_geocode(run_opt),bigdft_get_cell(run_opt))

     if (abs(outs%energy-e_pos).lt.en_delta) then
     call fpdistance(nid,wfp,fp,d)
       if (bigdft_mpi%iproc == 0) call yaml_map('(MH) checking fpdistance',(/outs%energy-e_pos,d/),fmt='(e11.4)')
     if (d.lt.fp_delta) then ! not escaped
       escape_sam=escape_sam+1.d0
        fp_sep=max(fp_sep,d)
        ekinetic=ekinetic*beta_S
        if (bigdft_mpi%iproc == 0) then 
             call wtioput(ediff,ekinetic,dt,nsoften)
             write(2,'((1x,f10.0),1x,1pe21.14,2(1x,1pe10.3),3(1x,0pf5.2),a)')  &
             escape,outs%energy,ediff,ekinetic, &
             escape_sam/escape,escape_old/escape,escape_new/escape,'  S '
             call f_utils_flush(2)
             !call bigdft_utils_flush(unit=2)
             !flush(2)
             call yaml_map('(MH) no escape from current minimum.',(/outs%energy-e_pos,d/),fmt='(e11.4)')
        endif
        goto 5555
     endif
     endif


  !C continue since escaped
     if (outs%energy.lt.ebest_l) then
     ebest_l=outs%energy
     if (bigdft_mpi%iproc == 0) call yaml_map('(MH) new locally lowest ',ebest_l)
     endif

  !C  check whether new minimum
  call identical(bigdft_mpi%iproc,nlminx,nlmin,nid,outs%energy,wfp,en_arr,fp_arr,en_delta,fp_delta,&
       newmin,kid,dmin,k_e,n_unique,n_nonuni)
  if (newmin) then
      escape_new=escape_new+1.d0
      ekinetic=ekinetic*beta_N
      nlmin=nlmin+1
      call insert(bigdft_mpi%iproc,nlminx,nlmin,nid,bigdft_nat(run_opt),k_e,outs%energy,wfp,&
           rxyz_opt,en_arr,ct_arr,fp_arr,pl_arr)
! write intermediate results
      if (bigdft_mpi%iproc == 0) call yaml_comment('(MH) WINTER')
      if (bigdft_mpi%iproc == 0) call winter(natoms,bigdft_get_astruct_ptr(run_opt),nid,nlminx,nlmin,en_delta,fp_delta, &
           en_arr,ct_arr,fp_arr,pl_arr,ediff,ekinetic,dt,nsoften)
      if (bigdft_mpi%iproc == 0) then
         !call yaml_stream_attributes()
        call yaml_mapping_open('(MH) New minimum',flow=.true.)
        call yaml_map('(MH) has energy',outs%energy,fmt='(e14.7)')
        !if (dmin < 1.e100_gp) 
           call yaml_map('(MH) distance',dmin,fmt='(e11.4)')
        call yaml_mapping_close(advance='yes')
      endif
      nvisit=1
   else
      escape_old=escape_old+1.d0
      ekinetic=ekinetic*beta_O
      if (bigdft_mpi%iproc == 0) then
        call yaml_mapping_open('(MH) Revisited:',flow=.true.)
        call yaml_map('(MH) number',kid)
        call yaml_map('(MH) with energy',en_arr(kid),fmt='(e14.7)')
        call yaml_map('(MH) distance',dmin,fmt='(e11.4)')
        call yaml_mapping_close(advance='yes')
      endif
      ct_arr(kid)=ct_arr(kid)+1.d0
      nvisit=int(ct_arr(kid))
   endif


     if (bigdft_mpi%iproc == 0) then
          write(2,'((1x,f10.0),1x,1pe21.14,2(1x,1pe10.3),3(1x,0pf5.2),a,i5)')  &
          escape,outs%energy,ediff,ekinetic, &
          escape_sam/escape,escape_old/escape,escape_new/escape,'  I ',nvisit
          call f_utils_flush(2)
     endif

  !  hopp=hopp+1.d0
  if (outs%energy.lt.e_hop) then
     e_hop=outs%energy
     call bigdft_get_rxyz(run_opt,rxyz=poshop)
!!$     do iat=1,natoms
!!$        poshop(1,iat)=atoms%astruct%rxyz(1,iat) 
!!$        poshop(2,iat)=atoms%astruct%rxyz(2,iat) 
!!$        poshop(3,iat)=atoms%astruct%rxyz(3,iat)
!!$     enddo
     do i=1,nid
       fphop(i)=wfp(i)
     enddo
  endif

  !C master: Monte Carlo step for local minima hopping
  av_ediff=av_ediff+ediff
  if (e_hop-e_pos.lt.ediff) then 
     !C          local minima accepted -------------------------------------------------------
     accepted=accepted+1.d0
     e_pos=e_hop
     call f_memcpy(src=poshop,dest=pos)
!!$     do iat=1,natoms
!!$        pos(1,iat)=poshop(1,iat) 
!!$        pos(2,iat)=poshop(2,iat) 
!!$        pos(3,iat)=poshop(3,iat)
!!$     enddo
     do i=1,nid
        fp(i)=fphop(i)
     enddo
  if (bigdft_mpi%iproc == 0) then
     nposacc=nposacc+1
     write(fn4,'(i4.4)')nposacc
     if(disable_hatrans)then
         write(comment,'(a)')'ha_trans disabled'
     else
         write(comment,'(a)')'ha_trans enabled'
     endif
     call astruct_dump_to_file(bigdft_get_astruct_ptr(run_opt),&
          'posacc_'//fn4//'_'//trim(bigdft_run_id_toa()),&
          trim(comment),energy=e_pos,rxyz=pos)
!!$     call write_atomic_file('posacc_'//fn4//'_'//trim(bigdft_run_id_toa()),&
!!$          e_pos,pos,atoms%astruct%ixyz_int,atoms,trim(comment))
  endif

     if (bigdft_mpi%iproc == 0) then
        !call yaml_mapping_open('(MH) Write poscur file')
        call astruct_dump_to_file(bigdft_get_astruct_ptr(run_opt),&
             'poscur'//trim(bigdft_run_id_toa()),'',&
             energy=e_pos,rxyz=pos)
!!$       call write_atomic_file('poscur'//trim(bigdft_run_id_toa()),e_pos,pos,atoms%astruct%ixyz_int,atoms,'')
       call yaml_map('(MH) poscur.xyz for  RESTART written',.true.)

       write(2,'(1x,f10.0,1x,1pe21.14,2(1x,1pe10.3),3(1x,0pf5.2),a)')  &
              escape,e_hop,ediff,ekinetic, &
              escape_sam/escape,escape_old/escape,escape_new/escape,'  A '
       call f_utils_flush(2)
       !flush(2)
      endif

      e_hop=1.d100
      ediff=ediff*alpha_A
  else
     !C          local minima rejected -------------------------------------------------------
     run_opt%inputs%inputPsiId=0  !ALEX says: Better do an input guess for the next escape
     if (bigdft_mpi%iproc == 0) then 
          write(2,'((1x,f10.0),1x,1pe21.14,2(1x,1pe10.3),3(1x,0pf5.2),a,i5)')  &
          escape,outs%energy,ediff,ekinetic, &
          escape_sam/escape,escape_old/escape,escape_new/escape,'  R '
          call f_utils_flush(2)
          !flush(2)
          call yaml_map('(MH) rejected: ew-e>ediff',outs%energy-e_pos)
     endif

     rejected=rejected+1.d0
     ediff=ediff*alpha_R
  endif
     if (bigdft_mpi%iproc == 0) call wtioput(ediff,ekinetic,dt,nsoften)

end do hopping_loop

!3000 continue

  if (bigdft_mpi%iproc == 0) then
     call yaml_mapping_open('(MH) Final results')
     call yaml_map('(MH) Total number of minima found',nlmin)
     call yaml_map('(MH) Number of accepted minima',accepted)
     call winter(natoms,bigdft_get_astruct_ptr(run_opt),nid,nlminx,nlmin,en_delta,fp_delta, &
           en_arr,ct_arr,fp_arr,pl_arr,ediff,ekinetic,dt,nsoften)
  endif


  call cpu_time(tcpu2)
  if (bigdft_mpi%iproc == 0) then
     !C ratios from all the global counters
     call yaml_map('(MH) ratio stuck, same',escape_sam/escape)
     call yaml_map('(MH) ratio stuck, old',escape_old/escape)
     call yaml_map('(MH) ratio stuck, new',escape_new/escape)
     call yaml_map('(MH) ratio acc',accepted/(accepted+rejected))
     call yaml_map('(MH) ratio rej',rejected/(accepted+rejected))
     call yaml_map('(MH) count_md',count_md)
     call yaml_map('(MH) count_sdcg',count_sdcg)
     call yaml_map('(MH) count_bfgs',count_bfgs)
     call yaml_map('(MH) cpu(hrs)', (tcpu2-tcpu1)/3600.d0)
     call yaml_map('(MH) average ediff',av_ediff/(accepted+rejected))
     call yaml_map('(MH) average ekinetic',av_ekinetic/escape)
     call yaml_map('(MH) number of configurations for which atoms escaped ',nputback)

     tt=0.d0
     ss=0.d0
     do i=1,nlmin
        tt=max(tt,ct_arr(i))
        ss=ss+ct_arr(i)
     enddo
     call yaml_map('(MH)  most frequent visits ',tt)
     call yaml_map('(MH)   av. numb. visits per minimum',ss/nlmin)

     call yaml_map('(MH) ediff out',ediff)
     call yaml_map('(MH) ekinetic out',ekinetic)
     call yaml_map('(MH) dt out',dt)
     call yaml_mapping_close()
  endif
  close(2) 
  !deallocations as in BigDFT
  !call run_objects_free_container(runObj)

  !call free_restart_objects(rst)
  call release_run_objects(run_md)
  call free_run_objects(run_opt)
!!$  call deallocate_atoms_data(atoms)

  ! deallocation of global's variables

  call f_free_ptr(pos)
  call f_free(en_arr)
  call f_free(ct_arr)
  call f_free(fp_arr)
  call f_free(fp)
  call f_free(wfp)
  call f_free(vxyz)
  call f_free(gg)
  call f_free(pl_arr)
  call f_free(poshop)
  call f_free(fphop)
  call f_free(rcov)
  call f_free(ksevals)

  call deallocate_global_output(outs)
!!$  call free_input_variables(inputs_md)
!!$  call free_input_variables(inputs_opt)

  call bigdft_finalize(ierr)

  call f_lib_finalize()

contains


  !> Does a MD run with the atomic positions rxyz
  subroutine mdescape(nsoften,mdmin,ekinetic,gg,vxyz,dt,count_md, &
       runObj,outs,ngeopt,nproc,iproc)!  &
    use module_base
    use module_types
    use module_interfaces
    use m_ab6_symmetry
    implicit none !real*8 (a-h,o-z)
    integer :: nsoften,mdmin,ngeopt,iproc,nproc
    real(kind=8) :: ekinetic,dt,count_md
    type(run_objects), intent(inout) :: runObj
    type(DFT_global_output), intent(inout) :: outs
    real(kind=8), dimension(3,natoms) :: gg,vxyz
    character(len=4) :: fn4
    real(gp) :: e0,enmin1,en0000,econs_max,econs_min,rkin,enmin2
    real(kind=8) :: devcon,at1,at2,at3
    real(gp), dimension(:,:), pointer :: rxyz_run
    !type(wavefunctions_descriptors), intent(inout) :: wfd
    !real(kind=8), pointer :: psi(:), eval(:)

    if(iproc==0) call yaml_map('(MH) MINHOP start soften ',nsoften)

    !C initialize positions,velocities, forces
    e0 = outs%energy

    rxyz_run => bigdft_get_rxyz_ptr(runObj)

  !! Either random velocity distribution 
  !        call randdist(nat,rxyz,vxyz)
  !! or Gauss velocity distribution
  !! or exponential  velocity distribution
  !        call expdist(nat,rxyz,vxyz)
  !! or localized velocities
  !        call localdist(nat,rxyz,vxyz)
    call randdist(natoms,bigdft_get_geocode(runObj),rxyz_run,vxyz)

    !!! Put to zero the velocities for all boron atoms
    !!do iat=1,natoms
    !!    if (atoms%astruct%atomnames(atoms%astruct%iatype(iat))=='B') then
    !!        if (iproc==0) then
    !!            write(*,'(a,i0)') 'set velocities to zero for atom ',iat
    !!        end if
    !!        vxyz(:,iat)=0.d0
    !!    end if
    !!end do

  ! Soften previous velocity distribution
    call soften(nsoften,vxyz, runObj,outs,nproc,iproc)

    call frozen_dof(bigdft_get_astruct_ptr(runObj),vxyz,ndfree,ndfroz)
  ! normalize velocities to target ekinetic
    call velnorm(natoms,(ekinetic*ndfree)/(ndfree+ndfroz),vxyz)
    call to_zero(3*natoms,gg)

    if(iproc==0) call torque(natoms,rxyz_run,vxyz)

    if(iproc==0) call yaml_map('(MH) MINHOP start MD',(/ndfree,ndfroz/))
    !C inner (escape) loop
    nummax=0
    nummin=0
    enmin1=0.d0
    en0000=0.d0
    econs_max=-1.d100
    econs_min=1.d100
    istepnext=5
    md_loop: do istep=1,200

!C      Evolution of the system according to 'VELOCITY VERLET' algorithm
       call daxpy(3*natoms,dt,vxyz(1,1),1,rxyz_run,1)
       call daxpy(3*natoms,0.5_gp*dt*dt,gg(1,1),1,rxyz_run,1)

       rkin=dot(3*natoms,vxyz(1,1),1,vxyz(1,1),1)
       rkin=rkin*.5d0

       enmin2=enmin1
       enmin1=en0000
       !    if (iproc == 0) write(*,*) 'CLUSTER FOR  MD'
       runObj%inputs%inputPsiId=1
       call call_bigdft(runObj, outs,infocode)

       if (iproc == 0) then
          write(fn4,'(i4.4)') istep
          call bigdft_write_atomic_file(runObj,outs,'posmd_'//fn4,'')
!!$          call write_atomic_file(trim(inputs_md%dir_output)//'posmd_'//fn4,outs%energy,&
!!$              atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,'',forces=outs%fxyz)
       end if

       en0000=outs%energy-e0
       if (istep >= 3 .and. enmin1 > enmin2 .and. enmin1 > en0000)  nummax=nummax+1
       if (istep >= 3 .and. enmin1 < enmin2 .and. enmin1 < en0000)  nummin=nummin+1
!  write configuration file for data base
       if (istep >= 3 .and. enmin1 < enmin2 .and. enmin1 < en0000)  then
          ngeopt=ngeopt+1
          write(fn4,'(i4.4)') ngeopt
          write(comment,'(a,i3)')'nummin= ',nummin
          call bigdft_write_atomic_file(runObj,outs,&
               'poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()),&
               trim(comment),cwd_path=.true.)
!!$          call write_atomic_file('poslocm_'//fn4//'_'//trim(bigdft_run_id_toa()), & 
!!$               outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
       endif
       econs_max=max(econs_max,rkin+outs%energy)
       econs_min=min(econs_min,rkin+outs%energy)
       devcon=econs_max-econs_min
       !if (iproc == 0) writei17,'(a,i5,1x,1pe17.10,2(1x,i2))') 'MD ',&
       !     istep,e_rxyz,nummax,nummin
       if (iproc == 0) then
!          write(*,'(a,i5,1x,1pe17.10,2(1x,i2))') '# (MH) MD ',istep,e_rxyz,nummax,nummin
          call yaml_mapping_open('(MH) MD',flow=.true.)
            call yaml_map('Step',istep)
            call yaml_map('E (Ha)',outs%energy)
            call yaml_map('No. of Max and min',(/nummax,nummin/))
          call yaml_mapping_close(advance='yes') 
       endif
         if (nummin.ge.mdmin) then
          if (nummax.ne.nummin .and. iproc == 0) &
               call yaml_warning('nummin,nummax'//trim(yaml_toa((/nummax,nummin/))))
          exit md_loop
         endif
       do iat=1,natoms
          at1=outs%fxyz(1,iat)
          at2=outs%fxyz(2,iat)
          at3=outs%fxyz(3,iat)
          !C Evolution of the velocities of the system
!          if (.not. atoms%lfrztyp(iat)) then
             vxyz(1,iat)=vxyz(1,iat) + (.5d0*dt) * (at1 + gg(1,iat))
             vxyz(2,iat)=vxyz(2,iat) + (.5d0*dt) * (at2 + gg(2,iat))
             vxyz(3,iat)=vxyz(3,iat) + (.5d0*dt) * (at3 + gg(3,iat))
!          end if
          !C Memorization of old forces
          gg(1,iat) = at1
          gg(2,iat) = at2
          gg(3,iat) = at3
       end do

   if (bigdft_get_geocode(runObj) == 'S') then 
      call fixfrag_posvel_slab(iproc,bigdft_nat(runObj),rcov,rxyz_run,vxyz,2)
   else if (bigdft_get_geocode(runObj) == 'F') then
     if (istep == istepnext) then 
           call fixfrag_posvel(iproc,bigdft_nat(runObj),rcov,rxyz_run,vxyz,2,occured)
        if (occured) then 
          istepnext=istep+4
        else
          istepnext=istep+1
        endif
     endif
   endif

    end do md_loop
    if (istep >=200) then
       if (iproc == 0) call yaml_scalar('(MH) TOO MANY MD STEPS')
       dt=2.d0*dt
    end if
    !save the value of count_md for the moment
    count_md=count_md+real(istep,gp)

    !C MD stopped, now do relaxation

    !  if (iproc == 0) write(67,*) 'EXIT MD',istep
    
    ! adjust time step to meet precision criterion
    devcon=devcon/(3*bigdft_nat(runObj)-3)
    !if (iproc == 0) &
    !     write(66,'(a,2(1x,1pe11.4),1x,i5)')&
    !     'MD devcon ',devcon,devcon/ekinetic,istep
    if (devcon/ekinetic.lt.10.d-2) then
       !if (iproc == 0) write(66,*) 'MD:old,new dt',dt,dt*1.05d0
       dt=dt*1.05d0
    else
       !if (iproc == 0) write(66,*) 'MD:old,new dt',dt,dt/1.05d0
       dt=dt*(1.d0/1.05d0)
    endif
    
  END SUBROUTINE mdescape
  

  subroutine soften(nsoften,vxyz,runObj,outs,nproc,iproc)
    use module_base
    use bigdft_run
    use module_atoms, only: astruct_dump_to_file
!    use module_types
!    use module_interfaces
!    use m_ab6_symmetry
    implicit none
    !Arguments
    integer, intent(in) :: nsoften,nproc,iproc
    type(run_objects), intent(inout) :: runObj
    type(DFT_global_output), intent(inout) :: outs
    real(kind=8), dimension(3*natoms) :: vxyz
    !Local variables
    real(kind=8), dimension(3*natoms) :: pos0
    real(kind=8) :: alpha,curv,curv0,eps_vxyz,etot0,fd2,res,sdf,svxyz
    integer :: it
    real(gp), dimension(:,:), pointer :: rxyz_run

!    eps_vxyz=1.d-1*natoms
    alpha=runObj%inputs%betax

    rxyz_run => bigdft_get_rxyz_ptr(runObj)

    ! Save starting positions.
    !allocate(wpos(3,nat),fxyz(3,nat))
    call bigdft_get_rxyz(runObj,rxyz_add=pos0(1))
    !call vcopy(3*natoms, atoms%astruct%rxyz(1,1), 1, pos0(1), 1)

    runObj%inputs%inputPsiId=1
    if(iproc==0) call yaml_comment('(MH) soften initial step ',hfill='~')
    call call_bigdft(runObj,outs,infocode)
    etot0 = outs%energy

    ! scale velocity to generate dimer 

!    call atomic_dot(atoms,vxyz,vxyz,svxyz)
    call atomic_dot(bigdft_get_astruct_ptr(runObj),vxyz,vxyz,svxyz)
!!$    svxyz=0.d0
!!$    do i=1,3*natoms
!!$       iat=(i-1)/3+1
!!$       if (atoms%astruct%ifrztyp(iat) == 0) then
!!$          svxyz=svxyz+vxyz(i)**2
!!$       end if
!!$    enddo
    eps_vxyz=sqrt(svxyz)
    if(iproc == 0) call yaml_map('(MH)  eps_vxyz=',eps_vxyz)
    !if(iproc == 0) call yaml_map('(MH)  vxyz_test=',vxyz)
    !stop
    do it=1,nsoften
       
       !call vcopy(3*natoms, pos0(1), 1, bigdft_get_rxyz_ptr(runObj), 1)
       call bigdft_set_rxyz(runObj,rxyz_add=pos0(1))
       call daxpy(3*natoms, 1.d0, vxyz(1), 1,rxyz_run, 1)
       call call_bigdft(runObj,outs,infocode)
       fd2=2.d0*(outs%energy-etot0)/eps_vxyz**2

       call atomic_dot(bigdft_get_astruct_ptr(runObj),vxyz,vxyz,svxyz)
       call atomic_dot(bigdft_get_astruct_ptr(runObj),vxyz,outs%fxyz,sdf)

!!$       sdf=0.d0
!!$       svxyz=0.d0
!!$       do i=1,3*natoms
!!$          iat=(i-1)/3+1
!!$          if (atoms%astruct%ifrztyp(iat) == 0) then
!!$             sdf=sdf+vxyz(i)*outs%fxyz(i - 3 * (iat - 1),iat)
!!$             svxyz=svxyz+vxyz(i)*vxyz(i)
!!$          end if
!!$       end do
!       call atomic_dot(atoms,vxyz,vxyz,svxyz)
!       call atomic_dot(atoms,vxyz,fxyz,sdf)

       curv=-sdf/svxyz
       if (it == 1) curv0=curv

       call atomic_axpy(bigdft_get_astruct_ptr(runObj),curv,vxyz,outs%fxyz)
       call atomic_dot(bigdft_get_astruct_ptr(runObj),outs%fxyz,outs%fxyz,res)
!!$       res=0.d0
!!$       do i=1,3*natoms
!!$          iat=(i-1)/3+1
!!$          if (atoms%astruct%ifrztyp(iat) == 0) then
!!$             outs%fxyz(i - 3 * (iat - 1),iat)=outs%fxyz(i - 3 * (iat - 1),iat)+curv*vxyz(i)
!!$             res=res+outs%fxyz(i - 3 * (iat - 1),iat)**2
!!$          end if
!!$       end do
!       call atomic_axpy_forces(atoms,fxyz,curv,vxyz,fxyz)
!       call atomic_dot(atoms,fxyz,fxyz,res)
       res=sqrt(res)

       write(fn4,'(i4.4)') it
       write(comment,'(a,1pe10.3)')'res= ',res
       if (iproc == 0) &
            call bigdft_write_atomic_file(runObj,outs,'possoft_'//fn4,trim(comment))
       
!!$            call write_atomic_file(trim(inputs_md%dir_output)//'possoft_'//fn4,&
!!$            outs%energy,atoms%astruct%rxyz,atoms%astruct%ixyz_int,atoms,trim(comment),forces=outs%fxyz)
      
       if(iproc==0) then
          call yaml_mapping_open('(MH) soften',flow=.true.)
            call yaml_map('it',it)
            call yaml_map('curv',curv,fmt='(f12.5)')
            call yaml_map('fd2',fd2,fmt='(f12.5)')
            call yaml_map('dE',outs%energy-etot0,fmt='(f12.5)')
            call yaml_map('res',res,fmt='(f12.5)')
            call yaml_map('(MH) eps_vxyz',eps_vxyz,fmt='(f12.5)')
          call yaml_mapping_close(advance='yes')
       end if
       if (curv.lt.0.d0 .or. fd2.lt.0.d0) then
          if(iproc==0) call yaml_comment('(MH) NEGATIVE CURVATURE')
          exit
       end if
       if (outs%energy-etot0.lt.1.d-2) eps_vxyz=eps_vxyz*1.2d0

!       do iat=1,natoms
!          if (.not. atoms%lfrztyp(iat)) then
!             if (atoms%astruct%geocode == 'P') then
!                wpos(3*(iat-1)+1)=modulo(wpos(3*(iat-1)+1)+alpha*fxyz(3*(iat-1)+1),atoms%astruct%cell_dim(1))
!                wpos(3*(iat-1)+2)=modulo(wpos(3*(iat-1)+2)+alpha*fxyz(3*(iat-1)+2),atoms%astruct%cell_dim(2))
!                wpos(3*(iat-1)+3)=modulo(wpos(3*(iat-1)+3)+alpha*fxyz(3*(iat-1)+3),atoms%astruct%cell_dim(3))
!             else if (atoms%astruct%geocode == 'S') then
!                wpos(3*(iat-1)+1)=modulo(wpos(3*(iat-1)+1)+alpha*fxyz(3*(iat-1)+1),atoms%astruct%cell_dim(1))
!                wpos(3*(iat-1)+2)=       wpos(3*(iat-1)+2)+alpha*fxyz(3*(iat-1)+2)
!                wpos(3*(iat-1)+3)=modulo(wpos(3*(iat-1)+3)+alpha*fxyz(3*(iat-1)+3),atoms%astruct%cell_dim(3))
!             else if (atoms%astruct%geocode == 'F') then
!                wpos(3*(iat-1)+1)=wpos(3*(iat-1)+1)+alpha*fxyz(3*(iat-1)+1)
!                wpos(3*(iat-1)+2)=wpos(3*(iat-1)+2)+alpha*fxyz(3*(iat-1)+2)
!                wpos(3*(iat-1)+3)=wpos(3*(iat-1)+3)+alpha*fxyz(3*(iat-1)+3)
!             end if
!
!          end if
!       end do
!       call atomic_axpy_forces(atoms,wpos,alpha,fxyz,wpos)
        call daxpy(3*natoms,alpha,outs%fxyz(1,1),1,rxyz_run,1)
        !call vcopy(3*natoms, atoms%astruct%rxyz(1,1), 1, vxyz(1), 1)
        call bigdft_get_rxyz(runObj,rxyz_add=vxyz(1))

        call axpy(3*natoms, -1.d0, pos0(1), 1, vxyz(1), 1)
       write(comment,'(a,1pe10.3)')'curv= ',curv
       !is this writing really needed?
       if (iproc == 0) &
            call astruct_dump_to_file(bigdft_get_astruct_ptr(runObj),&
            trim(runObj%inputs%dir_output)//'posvxyz',&
            trim(comment),rxyz=vxyz,forces=outs%fxyz)
!!$            call write_atomic_file(trim(inputs_md%dir_output)//'posvxyz',0.d0,vxyz,atoms%astruct%ixyz_int,&
!!$                 atoms,trim(comment),forces=outs%fxyz)

       call elim_moment(natoms,vxyz)
       if (bigdft_get_geocode(runObj) == 'F') &
            call elim_torque_reza(natoms,pos0,vxyz)

       call atomic_dot(bigdft_get_astruct_ptr(runObj),vxyz,vxyz,svxyz)
!!$       svxyz=0.d0
!!$       do i=1,3*natoms
!!$          iat=(i-1)/3+1
!!$          if (atoms%astruct%ifrztyp(iat) == 0) then
!!$             svxyz=svxyz+vxyz(i)*vxyz(i)
!!$          end if
!!$       end do
!      call atomic_dot(atoms,vxyz,vxyz,svxyz)
       if (res <= curv*eps_vxyz*5.d-1) exit
       svxyz=eps_vxyz/dsqrt(svxyz)

       do i=1,3*natoms
          vxyz(i)=vxyz(i)*svxyz
       end do

    end do ! iter
    
    ! Put back initial coordinates.
    call bigdft_set_rxyz(runObj,rxyz_add=pos0(1))
    !call vcopy(3*natoms, pos0(1), 1, atoms%astruct%rxyz(1,1), 1)

    !        deallocate(wpos,fxyz)
  END SUBROUTINE soften

end program MINHOP




!> C x is in interval [xx(jlo),xx(jlow+1)[ ; xx(0)=-Infinity ; xx(n+1) = Infinity
subroutine hunt_g(xx,n,x,jlo)
  implicit none
  !Arguments
  integer :: jlo,n
  real(kind=8) :: x,xx(n)
  !Local variables
  integer :: inc,jhi,jm
  logical :: ascnd
  if (n.le.0) stop 'hunt_g'
  if (n == 1) then
     if (x.ge.xx(1)) then
        jlo=1
     else
        jlo=0
     endif
     return
  endif
  ascnd=xx(n).ge.xx(1)
  if(jlo.le.0.or.jlo.gt.n)then
     jlo=0
     jhi=n+1
     goto 3
  endif
  inc=1
  if(x.ge.xx(jlo).eqv.ascnd)then
1    continue
     jhi=jlo+inc
     if(jhi.gt.n)then
        jhi=n+1
     else if(x.ge.xx(jhi).eqv.ascnd)then
        jlo=jhi
        inc=inc+inc
        goto 1
     endif
  else
     jhi=jlo
2    continue
     jlo=jhi-inc
     if(jlo.lt.1)then
        jlo=0
     else if(x.lt.xx(jlo).eqv.ascnd)then
        jhi=jlo
        inc=inc+inc
        goto 2
     endif
  endif
3 continue
  if(jhi-jlo == 1)then
     if(x == xx(n))jlo=n
     if(x == xx(1))jlo=1
     return
  endif
  jm=(jhi+jlo)/2
  if(x.ge.xx(jm).eqv.ascnd)then
     jlo=jm
  else
     jhi=jm
  endif
  goto 3
END SUBROUTINE hunt_g


!> Assigns initial velocities for the MD escape part
subroutine velnorm(nat,ekinetic,vxyz)
  use module_base
!  use module_types
!  use m_ab6_symmetry
  implicit none
  !implicit real*8 (a-h,o-z)
  integer, intent(in) :: nat
  real(gp), intent(in) :: ekinetic
  !type(atoms_data), intent(in) :: at
  real(gp), dimension(3,nat), intent(inout) :: vxyz
  !local variables
  integer :: iat
  real(gp) :: rkin,rkinsum,sclvel

  !C      Kinetic energy of the initial velocities
  rkinsum= 0.d0      
  do iat=1,nat
!     if (.not. at%lfrztyp(iat)) then
        rkinsum= rkinsum+vxyz(1,iat)**2+vxyz(2,iat)**2+vxyz(3,iat)**2
!     end if
  end do
  rkin=.5d0*rkinsum/(3*nat-3)
  !       write(*,*) 'rkin,ekinetic',rkin,ekinetic

  !C      Rescaling of velocities to get reference kinetic energy
  sclvel= dsqrt(ekinetic/rkin)
  do iat=1,nat
!     if (.not. at%lfrztyp(iat)) then
        vxyz(1,iat)=vxyz(1,iat)*sclvel
        vxyz(2,iat)=vxyz(2,iat)*sclvel
        vxyz(3,iat)=vxyz(3,iat)*sclvel
!     end if
  end do

END SUBROUTINE velnorm


!> create a random displacement vector without translational and angular moment
subroutine randdist(nat,geocode,rxyz,vxyz)
  use BigDFT_API !,only: gp !module_base
  use yaml_output
  implicit none
  integer, intent(in) :: nat
  real(gp), dimension(3*nat), intent(in) :: rxyz
  real(gp), dimension(3*nat), intent(out) :: vxyz
  character(len=1) :: geocode
  !local variables
  integer :: i,idum=0
  real(kind=4) :: tt,builtin_rand
  do i=1,3*nat
     !call random_number(tt)
     !add built-in random number generator
     tt=builtin_rand(idum)
     vxyz(i)=real(tt-.5,gp)*3.e-1_gp
     !if (bigdft_mpi%iproc==0) print *,i,idum,vxyz(i)
  end do

  call elim_moment(nat,vxyz)
  !if (bigdft_mpi%iproc==0) call yaml_map('After mom',vxyz,unit=6)
  if (geocode == 'F') &
     & call elim_torque_reza(nat,rxyz,vxyz)
  !if (bigdft_mpi%iproc==0) call yaml_map('After torque',vxyz,unit=6)

END SUBROUTINE randdist


!>  generates 3*nat random numbers distributed according to  exp(-.5*vxyz**2)
subroutine gausdist(nat,geocode,rxyz,vxyz)
  implicit real*8 (a-h,o-z)
  real s1,s2
  character(len=1) :: geocode
  !C On Intel the random_number can take on the values 0. and 1.. To prevent overflow introduce eps
  parameter(eps=1.d-8)
  dimension vxyz(3*nat),rxyz(3*nat)

  do i=1,3*nat-1,2
     call random_number(s1)
     t1=eps+(1.d0-2.d0*eps)*dble(s1)
     call random_number(s2)
     t2=dble(s2)
     tt=sqrt(-2.d0*log(t1))
     vxyz(i)=tt*cos(6.28318530717958648d0*t2)
     vxyz(i+1)=tt*sin(6.28318530717958648d0*t2)
  enddo
  call random_number(s1)
  t1=eps+(1.d0-2.d0*eps)*dble(s1)
  call random_number(s2)
  t2=dble(s2)
  tt=sqrt(-2.d0*log(t1))
  vxyz(3*nat)=tt*cos(6.28318530717958648d0*t2)

  call elim_moment(nat,vxyz)
  if (geocode == 'F') &
           & call  elim_torque_reza(nat,rxyz,vxyz)
  return
END SUBROUTINE gausdist


!>  generates n random numbers distributed according to  exp(-x)
subroutine expdist(nat,geocode,rxyz,vxyz)
  implicit real*8 (a-h,o-z)
  real ss
  character(len=1) :: geocode
  !C On Intel the random_number can take on the values 0. and 1.. To prevent overflow introduce eps
  parameter(eps=1.d-8)
  dimension rxyz(3*nat),vxyz(3*nat)

  do i=1,3*nat
     call random_number(ss)
     tt=eps+(1.d0-2.d0*eps)*dble(ss)
     vxyz(i)=log(tt)
  enddo

  call elim_moment(nat,vxyz)
  if (geocode == 'F') &
     & call  elim_torque_reza(nat,rxyz,vxyz)

  return
END SUBROUTINE expdist


subroutine localdist(nat,rxyz,vxyz)
  use yaml_output
  implicit real*8 (a-h,o-z)
  real*4 ts
  parameter(nbix=20)
  dimension rxyz(3,nat), vxyz(3,nat),nbi(nbix)
  parameter( bondlength=2.7d0)

  nloop=0
100 continue
  nloop=nloop+1
  if (nloop.gt.2) write(*,*) 'nloop=',nloop
  if (nloop.gt.11) then
    call yaml_scalar('(MH) ERROR LOCALDIST')
    stop 'ERROR LOCALDIST'
  endif
  ! pick an atom iat randomly
  call random_number(ts)
  iat=min(nat,int(ts*nat+1.))
  !       write(*,*) 'iat=',iat

  ! find iat's neighbors
  inb=0
  do i=1,nat
     dd=(rxyz(1,iat)-rxyz(1,i))**2+(rxyz(2,iat)-rxyz(2,i))**2+(rxyz(3,iat)-rxyz(3,i))**2
     if (dd < bondlength**2 .and. i /= iat) then
        inb=inb+1; if (inb.gt.nbix) stop 'enlarge size of nbi' ; nbi(inb)=i
     endif
  enddo
  !        write(*,*) 'inb=',inb
  if (inb < 2 ) goto 100

  ! pick another atom jat that is a neighbor of iat
  call random_number(ts)
  j=min(inb,int(ts*inb+1.))
  jat=nbi(j)
  !       write(*,*) 'jat=',jat

  ! Choose velocities for remaining atoms (i.e. not iat and jat )
  ampl=2.d-1
  do i=1,nat
     call random_number(ts) ; ts=ts-.5
     vxyz(1,i)=dble(ts)*ampl
     call random_number(ts) ; ts=ts-.5
     vxyz(2,i)=dble(ts)*ampl
     call random_number(ts) ; ts=ts-.5
     vxyz(3,i)=dble(ts)*ampl
  enddo
  ! Finally choose velocities for iat and jat 
  ampl=2.d0
  i=iat
  call random_number(ts) ; ts=ts-.5
  vxyz(1,i)=dble(ts)*ampl
  call random_number(ts) ; ts=ts-.5
  vxyz(2,i)=dble(ts)*ampl
  call random_number(ts) ; ts=ts-.5
  vxyz(3,i)=dble(ts)*ampl
  i=jat
  call random_number(ts) ; ts=ts-.5
  vxyz(1,i)=dble(ts)*ampl
  call random_number(ts) ; ts=ts-.5
  vxyz(2,i)=dble(ts)*ampl
  call random_number(ts) ; ts=ts-.5
  vxyz(3,i)=dble(ts)*ampl

  !        write(*,'(i3,3(1pe12.4))') iat,(rxyz(i,iat)+.5d0*vxyz(i,iat),i=1,3)
  !        write(*,'(i3,3(1pe12.4))') jat,(rxyz(i,jat)+.5d0*vxyz(i,jat),i=1,3)

  return
END SUBROUTINE localdist


subroutine torque(nat,rxyz,vxyz)
  use module_base, only: gp
  use yaml_output
  implicit real*8 (a-h,o-z)
  dimension rxyz(3,nat),vxyz(3,nat)

  ! center of mass
  cmx=0.d0 ; cmy=0.d0 ; cmz=0.d0
  do iat=1,nat
     cmx=cmx+rxyz(1,iat)
     cmy=cmy+rxyz(2,iat)
     cmz=cmz+rxyz(3,iat)
  enddo
  cmx=cmx/real(nat,gp) 
  cmy=cmy/real(nat,gp) 
  cmz=cmz/real(nat,gp)

  ! torque
  tx=0.d0 ; ty=0.d0 ; tz=0.d0
  do iat=1,nat
     tx=tx+(rxyz(2,iat)-cmy)*vxyz(3,iat)-(rxyz(3,iat)-cmz)*vxyz(2,iat)
     ty=ty+(rxyz(3,iat)-cmz)*vxyz(1,iat)-(rxyz(1,iat)-cmx)*vxyz(3,iat)
     tz=tz+(rxyz(1,iat)-cmx)*vxyz(2,iat)-(rxyz(2,iat)-cmy)*vxyz(1,iat)
  enddo
  call yaml_map('(MH) torque',(/tx,ty,tz/),fmt='(1pe11.3)')

END SUBROUTINE torque


!subroutine elim_torque(nat,rxyz,vxyz)
!  implicit real*8 (a-h,o-z)
!  dimension rxyz(3,nat),vxyz(3,nat),t(3)
!
!  ! center of mass
!  cmx=0.d0 ; cmy=0.d0 ; cmz=0.d0
!  do iat=1,nat
!     cmx=cmx+rxyz(1,iat)
!     cmy=cmy+rxyz(2,iat)
!     cmz=cmz+rxyz(3,iat)
!  enddo
!  cmx=cmx/nat ; cmy=cmy/nat ; cmz=cmz/nat
!
!  do it=1,100
!
!     ! torque and radii in planes
!     t(1)=0.d0 ; t(2)=0.d0 ; t(3)=0.d0
!     sx=0.d0 ; sy=0.d0 ; sz=0.d0
!     do iat=1,nat
!        t(1)=t(1)+(rxyz(2,iat)-cmy)*vxyz(3,iat)-(rxyz(3,iat)-cmz)*vxyz(2,iat)
!        t(2)=t(2)+(rxyz(3,iat)-cmz)*vxyz(1,iat)-(rxyz(1,iat)-cmx)*vxyz(3,iat)
!        t(3)=t(3)+(rxyz(1,iat)-cmx)*vxyz(2,iat)-(rxyz(2,iat)-cmy)*vxyz(1,iat)
!        sx=sx+(rxyz(1,iat)-cmx)**2
!        sy=sy+(rxyz(2,iat)-cmy)**2
!        sz=sz+(rxyz(3,iat)-cmz)**2
!     enddo
!
!     if (t(1)**2+t(2)**2+t(3)**2.lt.1.d-22) return
!
!     ii=0
!     tmax=0.d0
!     do i=1,3
!        if (t(i)**2.gt.tmax**2) then 
!           ii=i
!           tmax=t(i)
!        endif
!     enddo
!
!     !         write(*,'(i4,3(1pe11.3))') ii,t
!
!     ! modify velocities
!     if (ii == 1) then 
!        cx=t(1)/(sz+sy)
!        do iat=1,nat
!           vxyz(2,iat)=vxyz(2,iat)+cx*(rxyz(3,iat)-cmz)
!           vxyz(3,iat)=vxyz(3,iat)-cx*(rxyz(2,iat)-cmy)
!        enddo
!     else if(ii == 2) then 
!        cy=t(2)/(sz+sx)
!        do iat=1,nat
!           vxyz(1,iat)=vxyz(1,iat)-cy*(rxyz(3,iat)-cmz)
!           vxyz(3,iat)=vxyz(3,iat)+cy*(rxyz(1,iat)-cmx)
!        enddo
!     else if(ii == 3) then 
!        cz=t(3)/(sy+sx)
!        do iat=1,nat
!           vxyz(1,iat)=vxyz(1,iat)+cz*(rxyz(2,iat)-cmy)
!           vxyz(2,iat)=vxyz(2,iat)-cz*(rxyz(1,iat)-cmx)
!        enddo
!     else
!        stop 'wrong ii'
!     endif
!
!  enddo
!  write(*,'(a,3(1pe11.3))') 'WARNING REMAINING TORQUE',t
!
!END SUBROUTINE elim_torque


subroutine moment(nat,vxyz)
  use yaml_output
  implicit real*8 (a-h,o-z)
  dimension vxyz(3,nat)

  sx=0.d0 ; sy=0.d0 ; sz=0.d0
  do iat=1,nat
     sx=sx+vxyz(1,iat)
     sy=sy+vxyz(2,iat)
     sz=sz+vxyz(3,iat)
  enddo
  write(*,'(a,3(1pe11.3))') 'momentum',sx,sy,sz
  call yaml_map('(MH) momentum',(/sx,sy,sz/),fmt='(1pe11.3)')

END SUBROUTINE moment


subroutine elim_moment(nat,vxyz)
  implicit real*8 (a-h,o-z)
  dimension vxyz(3,nat)

  sx=0.d0 ; sy=0.d0 ; sz=0.d0
  do iat=1,nat
     sx=sx+vxyz(1,iat)
     sy=sy+vxyz(2,iat)
     sz=sz+vxyz(3,iat)
  enddo
  sx=sx/nat ; sy=sy/nat ; sz=sz/nat
  do iat=1,nat
     vxyz(1,iat)=vxyz(1,iat)-sx
     vxyz(2,iat)=vxyz(2,iat)-sy
     vxyz(3,iat)=vxyz(3,iat)-sz
  enddo

END SUBROUTINE elim_moment


subroutine winter(nat,astruct,nid,nlminx,nlmin,en_delta,fp_delta, &
     en_arr,ct_arr,fp_arr,pl_arr,ediff,ekinetic,dt,nsoften)
  use module_base
  use bigdft_run, only: bigdft_run_id_toa
  use module_atoms, only: atomic_structure,astruct_dump_to_file
!!$  use module_types
!!$  use module_interfaces
!!$  use m_ab6_symmetry
  use yaml_output
  implicit none
  !Arguments
  integer, intent(in) :: nlminx,nlmin,nsoften,nid
  real(gp), intent(in) :: ediff,ekinetic,dt,en_delta,fp_delta
  type(atomic_structure), intent(in) :: astruct
  integer, intent(in) :: nat 
  real(gp), intent(in) :: en_arr(nlminx),ct_arr(nlminx),fp_arr(nid,nlminx),pl_arr(3,nat,nlminx)
  !local variables
  integer :: k,i
  !character(len=50) :: comment
  character(len=5) :: fn5

  call yaml_map('(MH) name of idarr','idarr'//trim(bigdft_run_id_toa()))

  ! write enarr file
  open(unit=12,file='enarr'//trim(bigdft_run_id_toa()),status='unknown')
  write(12,'(2(i10),a)') nlmin,nlmin+5,' # of minima already found, # of minima to be found in consecutive run'
  write(12,'(2(e24.17,1x),a)') en_delta,fp_delta,' en_delta,fp_delta'
  do k=1,nlmin
     write(12,'(e24.17,1x,e17.10)') en_arr(k),ct_arr(k)
  enddo
  call yaml_map('(MH) enarr for  RESTART written',.true.)
  close(12)

  ! write fingerprint file
  open(unit=14,file='idarr'//trim(bigdft_run_id_toa()),status='unknown')
  do k=1,nlmin
     write(14,'(10(1x,e24.17))') (fp_arr(i,k),i=1,nid)
  enddo
  close(14)
  call yaml_map('(MH) idarr for  RESTART written',.true.)

  ! write ioput file
  call  wtioput(ediff,ekinetic,dt,nsoften)
  call yaml_map('(MH) ioput for  RESTART written',.true.)

  ! write poslow files
  do k=1,nlmin 
     call yaml_mapping_open('(MH) Minima energies',flow=.true.)
     call yaml_map('k',k)
     call yaml_map('en_arr(k)',en_arr(k))
     call yaml_mapping_close(advance='yes')
     !C generate filename and open files
     write(fn5,'(i5.5)') k
     !        write(comment,'(a,1pe15.8)')'energy= ',en_arr(k)
     call astruct_dump_to_file(astruct,&
          'poslow'//fn5//'_'//trim(bigdft_run_id_toa()),'',&
          energy=en_arr(k),rxyz=pl_arr(:,:,k))
!!$     call  write_atomic_file('poslow'//fn5//'_'//trim(bigdft_run_id_toa()),en_arr(k),pl_arr(1,1,k),&
!!$           at%astruct%ixyz_int,at,'')
  end do

  call yaml_map('(MH) poslow files written',.true.)

END SUBROUTINE winter


subroutine wtioput(ediff,ekinetic,dt,nsoften)
  use bigdft_run, only: bigdft_run_id_toa
  implicit none
  !Arguments
  real(kind=8), intent(in) :: ediff,ekinetic,dt
  integer, intent(in) :: nsoften
  !Local variables
  integer, parameter :: iunit=11
  open(unit=iunit,file='ioput'//trim(bigdft_run_id_toa()),status='unknown')
  write(iunit,'(3(1x,1pe24.17)1x,i4,a)') ediff,ekinetic,dt,nsoften,' ediff, ekinetic dt and nsoften'
  close(unit=iunit)
END SUBROUTINE wtioput


!!subroutine wtpos(at,npminx,nlminx,nlmin,npmin,pos,earr,elocmin)
!!  use module_base
!!  use module_types
!!  use module_interfaces
!!  use m_ab6_symmetry
!!  use yaml_output
!!  implicit none
!!  !implicit real*8 (a-h,o-z)
!!  integer, intent(in) :: npminx,nlminx,nlmin,npmin
!!  type(atoms_data), intent(in) :: at
!!  real(gp), dimension(npminx), intent(in) :: elocmin
!!  real(gp), dimension(0:nlminx,2), intent(in) :: earr
!!  real(gp), dimension(3,at%astruct%nat,npminx), intent(in) :: pos
!!  !local variables
!!  character(len=5) :: fn
!!  integer :: k,kk,i
!!  
!!  write(*,*) '#(MH) nlmin,nlminx,npmin,npminx',nlmin,nlminx,npmin,npminx
!!  call yaml_map('(MH) nlmin,nlminx,npmin,npminx',(/nlmin,nlminx,npmin,npminx/))
!!  do i=1,min(40,nlmin,nlminx)
!!     write(*,'(i4,e24.17)') i,earr(i,1)
!!  enddo
!!
!!  do k=1,min(npmin,npminx)
!!     write(*,'(a,i4,e24.17)') '#(MH) k,elocmin(k)',k,elocmin(k)
!!     call yaml_mapping_open('(MH) Minima energies',flow=.true.)
!!     call yaml_map('k',k)
!!     call yaml_map('elocmin(k)',elocmin(k))
!!     call yaml_mapping_close(advance='yes')
!!
!!     
!!     !C Classify the configuration in the global ranking
!!     kk=0
!!     find_kk : do
!!        kk=kk+1
!!        if (kk > min(nlmin,nlminx)) then 
!!           write(*,*) '#(MH) ranking error for',k
!!           call yaml_map('(MH) ranking error for',k)
!!           stop 
!!        endif
!!        if (earr(kk,1) == elocmin(k)) exit find_kk
!!        !        if (abs(earr(kk,1) - elocmin(k)) .lt. 1.d-12 ) then 
!!        !             write(*,*) 'match ',abs(earr(kk,1) - elocmin(k))
!!        !             exit find_kk
!!        !        endif
!!     end do find_kk
!!
!!     if (kk <= npminx) then
!!        
!!        write(*,'(a,i4,i4,1x,1pe21.14)') '#(MH) k,kk,elocmin(k)',k,kk,elocmin(k)
!!        call yaml_mapping_open('(MH) Ranking and Energy',flow=.true.)
!!        call yaml_map('k kk',(/k,kk/))
!!        call yaml_map('elocmin(k)',elocmin(k))
!!        call yaml_mapping_close(advance='yes')
!!        
!!        !C generate filename and open files
!!        write(fn,'(i5.5)') kk
!!        call  write_atomic_file('poslow'//fn//'_'//trim(bigdft_run_id_toa()),elocmin(k),pos(1,1,k),at,'')
!!     endif
!!     
!!  end do
!!
!!END SUBROUTINE wtpos


function round(enerd,accur)
  implicit none
  real(kind=8) :: round
  real(kind=8), intent(in):: enerd,accur
  integer*8 :: ii
  ii=int(enerd/accur,kind=8)
  round=ii*accur
  !           write(*,'(a,1pe24.17,1x,i17,1x,1pe24.17)') 'enerd,ii,round',enerd,ii,round
  return
end function round


!subroutine rdposout(igeostep,rxyz,nat)
!  implicit none
!  integer, intent(in) :: igeostep,nat
!  real(kind=8), dimension(3,nat), intent(out) :: rxyz
!  !local variables
!  character(len=3) :: fn
!  character(len=20) :: filename
!  integer :: iat
!  write(fn,'(i3.3)') igeostep
!  !filename = 'posout_'//fn//'.ascii'
!  filename = 'posout_'//fn//'.xyz'
!  ! write(*,*)'(MH) reading unrelaxed structure from ',filename
!  open(unit=9,file=filename,status='old')
!  read(9,*)fn!no need for header
!  read(9,*)fn!same
!  do iat=1,nat
!     read(9,*)fn,rxyz(:,iat)!we know the atom types already
!  enddo
!  close(unit=9)
!END SUBROUTINE rdposout


!> routine for adjusting the dimensions with the center of mass in the middle
subroutine adjustrxyz(nat,alat1,alat2,alat3,rxyz)
  use module_base
  use yaml_output
  implicit none
  integer, intent(in) :: nat
  real(gp) ,intent(in) :: alat1,alat2,alat3
  real(gp), dimension(3,nat), intent(inout) :: rxyz
  !local variables
  integer :: iat,i 
  real(gp), dimension(3)  :: cent

  do i=1,3
     cent(i)=0.0_gp
  enddo
  do iat=1,nat
     do i=1,3
        cent(i)=cent(i)+rxyz(i,iat)
     enddo
  enddo
  do i=1,3
     cent(i)=cent(i)/real(nat,gp)
  enddo

!  call yaml_mapping_open('(MH) old CM, shift',flow=.true.)
    call yaml_map('(MH) Old CM',(/cent(1),cent(2),cent(3)/),fmt='(1pe9.2)')
    call yaml_map('(MH) Shift',(/-cent(1)+alat1*.5_gp,-cent(2)+alat2*.5_gp,-cent(3)+alat3*.5_gp/),fmt='(1pe9.2)')
!  call yaml_mapping_close(advance='yes')

  do iat=1,nat
     rxyz(1,iat)=rxyz(1,iat)-cent(1)+alat1*.5_gp
     rxyz(2,iat)=rxyz(2,iat)-cent(2)+alat2*.5_gp
     rxyz(3,iat)=rxyz(3,iat)-cent(3)+alat3*.5_gp
  enddo
END SUBROUTINE adjustrxyz


!subroutine fix_fragmentation(iproc,at,rxyz,nputback)
!  use module_base
!  use module_types
!  use m_ab6_symmetry
!  use yaml_output
!  implicit none
!  !implicit real*8 (a-h,o-z)
!  integer, intent(in) :: iproc
!  type(atoms_data), intent(in) :: at
!  integer, intent(inout) :: nputback
!  real(gp), dimension(3,at%astruct%nat) :: rxyz
!  !local variables
!  real(gp), parameter :: bondlength=8.0_gp
!  integer :: iat,nloop,ncluster,ii,jat,jj,kat,nadd,ierr
!  real(gp) :: xi,yi,zi,xj,yj,zj,ddmin,dd,d1,d2,d3,tt
!  ! automatic arrays
!  logical, dimension(at%astruct%nat) :: belong
!
!  nloop=1
!
!  fragment_loop: do
!
!     iat=1
!     belong(iat)=.true.
!     ncluster=1
!     do iat=2,at%astruct%nat
!        belong(iat)=.false.
!     enddo
!
!     !   ic=0
!     form_cluster: do
!        nadd=0
!        do iat=1,at%astruct%nat
!           xi=rxyz(1,iat) 
!           yi=rxyz(2,iat) 
!           zi=rxyz(3,iat)
!           if (belong(iat)) then 
!              do jat=1,at%astruct%nat
!                 xj=rxyz(1,jat) ; yj=rxyz(2,jat) ; zj=rxyz(3,jat)
!                 if ( (xi-xj)**2+(yi-yj)**2+(zi-zj)**2 <= (bondlength*1.25d0)**2) then 
!                    if (.not. belong(jat)) nadd=nadd+1
!                    belong(jat)=.true. 
!                 endif
!              end do
!           endif
!        end do
!        ncluster=ncluster+nadd
!        !     ic=ic+1 ; write(*,*) 'nadd,ncluster',ic,nadd,ncluster
!        if (nadd == 0) exit form_cluster
!     enddo form_cluster
!
!     if (ncluster == at%astruct%nat) then 
!        !   write(*,*) 'No fragmentation has occured',nloop
!        return
!
!     else
!        nputback=nputback+1
!
!        if (iproc == 0) then
!           write(*,*) '#MH fragmentation occured',nloop,ncluster
!           write(*,*) '(MH) fragmentation occured',nloop,ncluster
!           call yaml_map('(MH) fragmentation occured',(/nloop,ncluster/))
!           do kat=1,at%astruct%nat
!              write(444,*) ' LJ  ',rxyz(1,kat),rxyz(2,kat),rxyz(3,kat)
!           enddo
!        endif
!
!
!        ! make sure the part that flew away is smaller than the cluster
!        if (ncluster <= at%astruct%nat/2) then
!           !     write(*,*) 'FLIP'
!           do iat=1,at%astruct%nat
!              belong(iat)=.not. belong(iat)
!           enddo
!        endif
!
!        ! pull back the fragment of atoms that flew away
!        ii=-99999
!        do iat=1,at%astruct%nat
!           if (.not. belong(iat)) then
!              xi=rxyz(1,iat) 
!              yi=rxyz(2,iat) 
!              zi=rxyz(3,iat)
!              ddmin=1.e100_gp
!              jj=-99999
!              do jat=1,at%astruct%nat
!                 if (belong(jat)) then
!                    xj=rxyz(1,jat) 
!                    yj=rxyz(2,jat) 
!                    zj=rxyz(3,jat)
!                    dd= (xi-xj)**2+(yi-yj)**2+(zi-zj)**2 
!                    if (dd < ddmin) then 
!                       jj=jat
!                       ii=iat
!                       ddmin=dd
!                    endif
!                 endif
!              enddo
!           endif
!        enddo
!
!        d1=rxyz(1,ii)-rxyz(1,jj)
!        d2=rxyz(2,ii)-rxyz(2,jj)
!        d3=rxyz(3,ii)-rxyz(3,jj)
!        tt=bondlength/sqrt(d1**2+d2**2+d3**2)
!        do iat=1,at%astruct%nat
!           if (.not. belong(iat) ) then  !.and. .not. at%lfrztyp(iat)) then
!              if (at%astruct%geocode == 'P') then
!stop  '------ P ----------'
!                 rxyz(1,iat)=modulo(rxyz(1,iat)-d1*(tt),at%astruct%cell_dim(1))
!                 rxyz(2,iat)=modulo(rxyz(2,iat)-d2*(tt),at%astruct%cell_dim(2))
!                 rxyz(3,iat)=modulo(rxyz(3,iat)-d3*(tt),at%astruct%cell_dim(3))
!              else if (at%astruct%geocode == 'S') then
!stop  '------ S ----------'
!                 rxyz(1,iat)=modulo(rxyz(1,iat)-d1*(tt),at%astruct%cell_dim(1))
!                 rxyz(2,iat)=       rxyz(2,iat)-d2*(tt)
!                 rxyz(3,iat)=modulo(rxyz(3,iat)-d3*(tt),at%astruct%cell_dim(3))
!              else
!                 rxyz(1,iat)=rxyz(1,iat)-d1*(tt)
!                 rxyz(2,iat)=rxyz(2,iat)-d2*(tt)
!                 rxyz(3,iat)=rxyz(3,iat)-d3*(tt)
!              end if
!           endif
!        enddo
!
!        if (iproc == 0) then
!           write(444,*) at%astruct%nat, 'atomic ' 
!           write(444,*) ' fixed configuration ', nputback,sqrt(d1**2+d2**2+d3**2),ii,jj
!           do iat=1,at%astruct%nat
!              write(444,'(a5,3(e15.7),l1)') ' LJ  ',rxyz(1,iat),rxyz(2,iat),rxyz(3,iat),belong(iat)
!           enddo
!        endif
!        nloop=nloop+1
!     if (nloop.gt.4) then 
!          write(*,*)"#MH fragmentation could not be fixed",nloop
!          call MPI_ABORT(bigdft_mpi%mpi_comm,ierr)
!          write(*,*)"(MH) fragmentation could not be fixed",nloop
!          call yaml_map('(MH) fragmentation could not be fixed',nloop)
!  end do fragment_loop
!
!END SUBROUTINE fix_fragmentation



!    implicit real*8 (a-h,o-z)
!    integer option
!    logical occured
!    character(5) atomname
!    parameter(nat=12,iproc=0,option=1)
!    dimension pos(3,nat),vel(3,nat)
!
!
!    open(unit=1,file='T.xyz')
!    read(1,*) natp
!    if (nat .ne. natp) stop' natp'
!    read(1,*) 
!    do iat=1,nat
!    read(1,*) atomname,(pos(i,iat),i=1,3)
!    enddo
!    close(1)
! 
!
!    open(unit=444,file='t.xyz')
!    call fixfrag_posvel(iproc,nat,pos,vel,1,occured)
!    write(*,*) 'occured',occured
!    close(444)
!   
!    end
!


subroutine fixfrag_posvel(iproc,nat,rcov,pos,vel,option,occured)
!This subroutine can perform two tasks.
!ATTENTION: it will only work on free BC!!!
!
!option=1
!The atoms in pos are analyzed and, if there is a fragmentation occuring, the
!main fragment will be identified and all neighboring fragments will be moved towards the nearest
!atom of the main fragment. The array pos will then be updated and returned.
!
!option=2
!The fragments are identified and the center of mass of all fragments are computed separately.
!The center of mass of all cluster is also computed.
!Then, the velocities are modified in such a way that the projection of the velocities 
!along the vector pointing towards the center of mass of all fragments are inverted 
!!use module_base
!!use module_types
!!use m_ab6_symmetry
use yaml_output
use dynamic_memory
implicit none
integer, intent(in) :: iproc,nat
!type(atoms_data), intent(in) :: at
real(8),dimension(3,nat), INTENT(INOUT) :: pos
real(8),dimension(3,nat), INTENT(INOUT) :: vel
real(8),dimension(nat), INTENT(IN) :: rcov
integer, INTENT(IN):: option
integer :: nfrag, nfragold
logical :: occured,niter
real(8)::  dist, mindist, angle, vec(3), cmass(3), velcm(3), bondlength, bfactor,rnrmi,scpr
real(8):: ekin,vcm1,vcm2,vcm3,ekin0,scale
real(8), allocatable:: cm_frags(:,:), vel_frags(:,:)
integer::iat, jat, natfragx(1), imin(2),ifrag
integer, allocatable:: fragcount(:)
integer, allocatable:: nat_frags(:)
integer, dimension(nat):: fragarr
logical, allocatable:: invert(:)

!The bondlength (in atomic units) is read from file input.bondcut
! OPTION 1: System is considered to be fragmented if the minimal distance between two atoms in the fragment is more than 2.0*bondlength
!           The two fragment are then brought together such that the minimal distance equals 1.5*bondlength
! OPTION  : System is considered to be fragmented if the minimal distance between two atoms in the fragment is more than 2.0*bondlength
!           the velocities are then inverted
!open(unit=43,file="input.bondcut")
!read(43,*) bondlength
!close(43)

if (option == 1) then 
   bfactor=1.5d0
else if (option == 2) then 
   bfactor=2.d0
else
   stop 'wrong option'
endif



fragarr(:)=0                     !Array, which atom belongs to which fragment
nfrag=0                       !Number of fragments

!Check for correct input
if (option.ne.1 .and. option.ne.2) stop "Wrong option in fixfrag_refvels"

!Calculate number of fragments and fragmentlist of the atoms
loop_nfrag: do
   nfragold=nfrag
   do iat=1,nat                !Check the first atom that isn't part of a cluster yet
      if(fragarr(iat)==0) then
         nfrag=nfrag+1
         fragarr(iat)=nfrag
         exit 
      endif
   enddo
   if (nfragold==nfrag) exit loop_nfrag

7000 continue
   niter=.false.
   do iat=1,nat                !Check if all the other atoms are part of the current cluster
      do jat=1,nat
         bondlength=rcov(iat)+rcov(jat)
         if(nfrag==fragarr(iat) .AND. jat.ne.iat .AND. fragarr(jat)==0) then
            dist=(pos(1,iat)-pos(1,jat))**2+(pos(2,iat)-pos(2,jat))**2+(pos(3,iat)-pos(3,jat))**2
            if(dist<(bfactor*bondlength)**2) then
               fragarr(jat)=nfrag
               niter=.true.
            endif
         endif
      enddo
   enddo
   if(niter) then
      goto 7000
   endif
end do loop_nfrag


!   if(iproc==0) write(*,*) '(MH) nfrag=',nfrag
occured=.false.
if(nfrag.ne.1) then          !"if there is fragmentation..."
   occured=.true.
   if(iproc==0) then
      call yaml_mapping_open('(MH) FIX')
      call yaml_map('(MH) Number of Fragments counted with option', (/nfrag,option/))
   endif
   if (option==1) then !OPTION=1, FIX FRAGMENTATION
      !   if(nfrag.ne.1) then          !"if there is fragmentation..."

      !Find out which fragment is the main cluster
      fragcount = f_malloc(nfrag,id='fragcount')
      fragcount=0
      do ifrag=1,nfrag
         do iat=1,nat
            if(fragarr(iat)==ifrag) then
               fragcount(ifrag)=fragcount(ifrag)+1
            endif
         enddo
      enddo
      natfragx=maxloc(fragcount(:))
      if(iproc==0) call yaml_map('(MH) The main Fragment index is', natfragx(1))

      !Find the minimum distance between the clusters
      do ifrag=1,nfrag
         mindist=1.d100
         if(ifrag.ne.natfragx(1)) then
            do iat=1,nat
               if(fragarr(iat)==ifrag) then
                  do jat=1,nat
                     if(fragarr(jat)==natfragx(1)) then
                        dist=(pos(1,iat)-pos(1,jat))**2+(pos(2,iat)-pos(2,jat))**2+(pos(3,iat)-pos(3,jat))**2
                        if(dist<mindist**2) then
                           mindist=sqrt(dist)
                           imin(1)=jat  !Atom with minimal distance in main fragment
                           imin(2)=iat   !Atom with minimal distance in fragment ifrag
                        endif
                     endif
                  enddo
               endif
            enddo

            if (iproc == 0) then
               write(444,*) nat, 'atomic '
               write(444,*) 'A fragmented configuration ',imin(1),imin(2)
               do iat=1,nat
                  write(444,'(a5,3(e15.7),l1)') ' Mg  ',pos(1,iat),pos(2,iat),pos(3,iat)
               enddo
            endif


            vec(:)=pos(:,imin(1))-pos(:,imin(2))
            bondlength=rcov(imin(1))+rcov(imin(2))
            do iat=1,nat        !Move fragments back towards the main fragment 
               if(fragarr(iat)==ifrag) then
                  pos(:,iat)=pos(:,iat)+vec(:)*((mindist-1.5d0*bondlength)/mindist)
                  fragarr(iat)=natfragx(1)
               endif
            enddo


         endif
      enddo
      call f_free(fragcount)
      if(iproc==0) then
         call yaml_comment('(MH) FIX: Fragmentation fixed! Keep on hopping...')
         call yaml_mapping_close()
      end if
      if (iproc == 0) then
         write(444,*) nat, 'atomic '
         write(444,*) ' fixed configuration '
         do iat=1,nat
            write(444,'(a5,3(e15.7),l1)') ' Mg  ',pos(1,iat),pos(2,iat),pos(3,iat)
         enddo
      endif

      !   endif
   elseif(option==2) then !OPTION=2, INVERT VELOCITIES
      !   if(nfrag.ne.1) then          !"if there is fragmentation..."
      if(iproc==0) call yaml_map('(MH) FIX: Preparing to invert velocities, option:',option)
      !Compute center of mass of all fragments and the collectiove velocity of each fragment
      cm_frags = f_malloc((/ 3, nfrag /),id='cm_frags')
      vel_frags = f_malloc((/ 3, nfrag /),id='vel_frags')
      nat_frags = f_malloc(nfrag,id='nat_frags')
      invert = f_malloc(nfrag,id='invert')
      cm_frags(:,:)=0.d0
      vel_frags(:,:)=0.d0
      nat_frags(:)=0         !number of atoms per fragment
      cmass(:)=0.d0
      velcm(:)=0.d0
      do iat=1,nat
         ifrag=fragarr(iat)
         nat_frags(ifrag)=nat_frags(ifrag)+1
         cm_frags(:,ifrag)=cm_frags(:,ifrag)+pos(:,iat)
         vel_frags(:,ifrag)=vel_frags(:,ifrag)+vel(:,iat)
      enddo

      do ifrag=1,nfrag
         cm_frags(:,ifrag)=cm_frags(:,ifrag)/real(nat_frags(ifrag),8)
         vel_frags(:,ifrag)=vel_frags(:,ifrag)/real(nat_frags(ifrag),8)
         cmass(:)=cmass(:)+cm_frags(:,ifrag)*nat_frags(ifrag)/real(nat,8)
         velcm(:)=velcm(:)+vel_frags(:,ifrag)*nat_frags(ifrag)/real(nat,8)
      enddo
      if (iproc==0) call yaml_map('(MH) CM VELOCITY',sqrt(velcm(1)**2+velcm(2)**2+velcm(3)**2))
      if (velcm(1)**2+velcm(2)**2+velcm(3)**2.gt.1.d-24) then
         if (iproc==0) call yaml_comment('(MH) NONZERO CM VELOCITY')
      endif


      ! now cm_frags contains the unit vector pointing from the center of mass of the entire system to the center of mass of the fragment
      do ifrag=1,nfrag
         cm_frags(:,ifrag)=cm_frags(:,ifrag)-cmass(:)
         rnrmi=1.d0/sqrt(cm_frags(1,ifrag)**2+cm_frags(2,ifrag)**2+cm_frags(3,ifrag)**2)
         cm_frags(1,ifrag)=cm_frags(1,ifrag)*rnrmi
         cm_frags(2,ifrag)=cm_frags(2,ifrag)*rnrmi
         cm_frags(3,ifrag)=cm_frags(3,ifrag)*rnrmi
         angle=cm_frags(1,ifrag)*vel_frags(1,ifrag)+cm_frags(2,ifrag)*vel_frags(2,ifrag)+cm_frags(3,ifrag)*vel_frags(3,ifrag)
         rnrmi=1.d0/sqrt(vel_frags(1,ifrag)**2+vel_frags(2,ifrag)**2+vel_frags(3,ifrag)**2)
         angle=angle*rnrmi
         if (angle.gt.0.d0) then
            invert(ifrag)=.true.
         else
            invert(ifrag)=.false.
         endif
         if (iproc==0) then
           write(*,*) '(MH) ifrag, angle ',ifrag, angle,invert(ifrag)
           call yaml_mapping_open('(MH) Frag. Info',flow=.true.)
            call yaml_map('ifrag',ifrag)
            call yaml_map('angle',angle)
            call yaml_map('ifrag inverted',invert(ifrag))
           call yaml_mapping_close(advance='yes')
         endif
      enddo
      !Decompose each atomic velocity into an component parallel and perpendicular to the cm_frags  vector and inter the 
      !paralle part if it point away from the CM

      !Check kinetic energy before inversion
      ekin0=0.d0
      vcm1=0.d0
      vcm2=0.d0
      vcm3=0.d0
      do iat=1,nat
         ekin0=ekin0+vel(1,iat)**2+vel(2,iat)**2+vel(3,iat)**2
         vcm1=vcm1+vel(1,iat)
         vcm2=vcm2+vel(2,iat)
         vcm3=vcm3+vel(3,iat)
      enddo
      if (iproc==0) then
          write(*,'(a,e14.7,3(e10.3))') '(MH) EKIN CM before invert',ekin0,vcm1,vcm2,vcm3
!          call yaml_mapping_open(,flow=.true.)
          call yaml_map('(MH) EKIN CM before invert',(/ekin0,vcm1,vcm2,vcm3/),fmt='(e10.3)')
!          call yaml_mapping_close(advance='yes')
      endif
      if (iproc==0) call torque(nat,pos,vel)
      !Checkend kinetic energy before inversion

      do iat=1,nat
         ! inversions  by fragment group
         ifrag=fragarr(iat)
         if (invert(ifrag)) then
            scpr=cm_frags(1,ifrag)*vel(1,iat)+cm_frags(2,ifrag)*vel(2,iat)+cm_frags(3,ifrag)*vel(3,iat)
            vel(:,iat)=vel(:,iat)-scpr*cm_frags(:,ifrag)*2.d0
         endif
      enddo

      call elim_moment(nat,vel)
      call elim_torque_reza(nat,pos,vel)

      ! scale velocities to regain initial ekin0
      ekin=0.d0
      do iat=1,nat
         ekin=ekin+vel(1,iat)**2+vel(2,iat)**2+vel(3,iat)**2
      enddo
      scale=sqrt(ekin0/ekin)
      do iat=1,nat
         vel(1,iat)=vel(1,iat)*scale
         vel(2,iat)=vel(2,iat)*scale
         vel(3,iat)=vel(3,iat)*scale
      enddo

      !Check kinetic energy after inversion
      ekin=0.d0
      vcm1=0.d0
      vcm2=0.d0
      vcm3=0.d0
      do iat=1,nat
         ekin=ekin+vel(1,iat)**2+vel(2,iat)**2+vel(3,iat)**2
         vcm1=vcm1+vel(1,iat)
         vcm2=vcm2+vel(2,iat)
         vcm3=vcm3+vel(3,iat)
      enddo
      if (iproc==0) then
          write(*,'(a,e14.7,3(e10.3))') '(MH) EKIN CM after  invert',ekin,vcm1,vcm2,vcm3
          !call yaml_mapping_open('(MH) EKIN CM after invert',flow=.true.)
          call yaml_map('(MH) EKIN CM after invert',(/ekin0,vcm1,vcm2,vcm3/),fmt='(e10.3)')
          !call yaml_mapping_close(advance='yes')
      endif
      if (iproc==0) call torque(nat,pos,vel)
      !Checkend kinetic energy after inversion

      !Check angle  after inversion
      vel_frags(:,:)=0.d0
      do iat=1,nat
         ifrag=fragarr(iat)
         vel_frags(:,ifrag)=vel_frags(:,ifrag)+vel(:,iat)
      enddo
      do ifrag=1,nfrag
         angle=cm_frags(1,ifrag)*vel_frags(1,ifrag)+cm_frags(2,ifrag)*vel_frags(2,ifrag)+cm_frags(3,ifrag)*vel_frags(3,ifrag)
         rnrmi=1.d0/sqrt(vel_frags(1,ifrag)**2+vel_frags(2,ifrag)**2+vel_frags(3,ifrag)**2)
         angle=angle*rnrmi
         if (iproc==0) then
           call yaml_mapping_open('(MH) Frag',flow=.true.)
            call yaml_map('ifrag',ifrag)
            call yaml_map('angle a invert',angle)
           call yaml_mapping_close(advance='yes')
         endif
        
      enddo
      !Checkend kinetic energy after inversion


      call f_free(cm_frags)
      call f_free(vel_frags)
      call f_free(nat_frags)
      call f_free(invert)
      !   endif
      !else
      !   stop "Wrong option within ff-rv"
      if(iproc==0) write(*,*) "(MH) FIX: Velocity component towards the center of mass inverted! Keep on hopping..."
      if(iproc==0) call yaml_scalar('(MH) FIX: Velocity component towards the center of mass inverted! Keep on hopping...')
   endif
endif
end subroutine fixfrag_posvel




subroutine fixfrag_posvel_slab(iproc,nat,rcov,pos,vel,option)
!This subroutine points the velocities towards the surface if an atom is too far away from the surface with surface boundary conditions
!
implicit none
integer, intent(in) :: iproc,nat,option
!type(atoms_data), intent(in) :: at
real(8),dimension(3,nat), INTENT(INOUT) :: pos
real(8),dimension(3,nat), INTENT(INOUT) :: vel
real(8),dimension(nat), INTENT(IN) :: rcov
integer :: iat,i,ic,ib,ilow,ihigh,icen,mm,mj,jat
real(8) :: ymin, ylow,yhigh,dx,dy,dz,dl,dist,distmin,d

integer, dimension(-100:1000):: ygrid
logical ,dimension(nat) :: onsurface


! empty space = 0
    do i=-100,1000 
    ygrid(i)=0
    enddo

    ymin=1.d100 
    do iat=1,nat
        ymin=min(ymin,pos(2,iat)) 
    enddo

! occupied space= nonzero
    do iat=1,nat
        ic=nint((pos(2,iat)-ymin)*4.d0)  ! ygrid spacing=.25
         ib=nint(2.0d0*rcov(iat)*4.d0)
         if (ic-ib < -100) stop "#MH error fixfrag_slab -100"
         if (ic+ib > 1000) stop "#MH error fixfrag_slab 1000"
         do i=ic-ib,ic+ib
         ygrid(i)=ygrid(i)+1
         enddo
    enddo

! find center of slab
    mm=0
    do i=-100,1000
    if (ygrid(i) .gt. mm) then
        icen=i
        mm=ygrid(i)
    endif
    enddo

! find border between empty and occupied space
    do i=icen,-100,-1
    if (ygrid(i).eq.0) then
        ilow=i
        exit
    endif
    enddo

    do i=icen,1000
    if (ygrid(i).eq.0) then
        ihigh=i
        exit
    endif
    enddo


    ylow=ymin+ilow*.25d0
    yhigh=ymin+ihigh*.25d0
    if (iproc.eq.0) write(*,'(a,3(1x,e10.3))') "#MH ylow,ycen,yhigh",ylow,ymin+icen*.25d0,yhigh
!             write(1000+iproc,'(a,3(1x,e10.3))') "#MH ylow,ycen,yhigh",ylow,ymin+icen*.25d0,yhigh

if (option.eq.2) then

    do iat=1,nat
         if (pos(2,iat).lt.ylow-rcov(iat)) then 
             vel(2,iat)=abs(vel(2,iat))
             if (iproc.eq.0) write(*,*) "#MH velocity made positive for atom",iat
             write(1000+iproc,*) "#MH velocity made positive for atom",iat,pos(:,iat)
         endif
         if (pos(2,iat).gt.yhigh+rcov(iat)) then 
             vel(2,iat)=-abs(vel(2,iat))
             if (iproc.eq.0) write(*,*) "#MH velocity made negative for atom",iat
             write(1000+iproc,*) "#MH velocity made negative for atom",iat,pos(:,iat)
         endif
    enddo
    call f_utils_flush(1000+iproc)
    !call bigdft_utils_flush(unit=1000+iproc)
    !flush(1000+iproc) 

else if (option.eq.1) then
1000 continue
    do iat=1,nat
         if (pos(2,iat).lt.ylow-rcov(iat) .or. pos(2,iat).gt.yhigh+rcov(iat)) then 
         onsurface(iat)=.false.
         else
         onsurface(iat)=.true.
         endif
    enddo
    do iat=1,nat
         if (onsurface(iat) .eqv. .false.) then 
             distmin=1.d100
            do jat=1,nat
            if (jat.ne.iat .and. onsurface(jat)) then
              dist=(pos(1,iat)-pos(1,jat))**2+(pos(2,iat)-pos(2,jat))**2+(pos(3,iat)-pos(3,jat))**2
              dist=sqrt(dist)-1.25d0*rcov(iat)-1.25d0*rcov(jat)
              if (dist.lt.distmin) then 
                distmin=dist
                mj=jat
              endif
            endif
            enddo
            if (iproc.eq.0) write(*,*) iat,mj,distmin
            if (distmin.gt.0.d0) then
                dx=pos(1,iat)-pos(1,mj)
                dy=pos(2,iat)-pos(2,mj)
                dz=pos(3,iat)-pos(3,mj)
                dl=sqrt(dx**2+dy**2+dz**2)
                d=distmin+0.1d0*(rcov(iat)+rcov(mj))
                dx=dx*(d/dl)
                dy=dy*(d/dl)
                dz=dz*(d/dl)
                if (iproc.eq.0) write(*,*) "#MH moving atom",iat,pos(:,iat)
                pos(1,iat)=pos(1,iat)-dx
                pos(2,iat)=pos(2,iat)-dy
                pos(3,iat)=pos(3,iat)-dz
                if (iproc.eq.0) write(*,*) "#MH moved atom",iat,pos(:,iat)
                onsurface(iat)=.true.
                goto 1000
            endif
         endif
    enddo
else 
    stop "invalid option for fixfrag_slab"
endif

end subroutine fixfrag_posvel_slab




subroutine give_rcov(iproc,atoms,nat,rcov)
  !    use module_base
  use module_types
  use yaml_output
  implicit none
  !Arguments
  integer, intent(in) :: iproc,nat
  type(atoms_data), intent(in) :: atoms
  real(kind=8), intent(out) :: rcov(nat)
  !Local variables
  integer :: iat

  do iat=1,nat
     if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='H') then
        rcov(iat)=0.75d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='He') then
        rcov(iat)=0.75d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Li') then
        rcov(iat)=3.40d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Be') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='B' ) then
        rcov(iat)=1.55d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='C' ) then
        rcov(iat)=1.45d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='N' ) then
        rcov(iat)=1.42d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='O' ) then
        rcov(iat)=1.38d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='F' ) then
        rcov(iat)=1.35d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ne') then
        rcov(iat)=1.35d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Na') then
        rcov(iat)=3.40d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Mg') then
        rcov(iat)=2.65d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Al') then
        rcov(iat)=2.23d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Si') then
        rcov(iat)=2.09d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='P' ) then
        rcov(iat)=2.00d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='S' ) then
        rcov(iat)=1.92d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Cl') then
        rcov(iat)=1.87d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ar') then
        rcov(iat)=1.80d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='K' ) then
        rcov(iat)=4.00d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ca') then
        rcov(iat)=3.00d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Sc') then
        rcov(iat)=2.70d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ti') then
        rcov(iat)=2.70d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='V' ) then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Cr') then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Mn') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Fe') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Co') then
        rcov(iat)=2.40d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ni') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Cu') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Zn') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ga') then
        rcov(iat)=2.10d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ge') then
        rcov(iat)=2.40d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='As') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Se') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Br') then
        rcov(iat)=2.20d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Kr') then
        rcov(iat)=2.20d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Rb') then
        rcov(iat)=4.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Sr') then
        rcov(iat)=3.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Y' ) then
        rcov(iat)=3.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Zr') then
        rcov(iat)=3.00d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Nb') then
        rcov(iat)=2.92d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Mo') then
        rcov(iat)=2.83d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Tc') then
        rcov(iat)=2.75d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ru') then
        rcov(iat)=2.67d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Rh') then
        rcov(iat)=2.58d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Pd') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ag') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Cd') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='In') then
        rcov(iat)=2.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Sn') then
        rcov(iat)=2.66d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Sb') then
        rcov(iat)=2.66d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Te') then
        rcov(iat)=2.53d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='I' ) then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Xe') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Cs') then
        rcov(iat)=4.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ba') then
        rcov(iat)=4.00d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='La') then
        rcov(iat)=3.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ce') then
        rcov(iat)=3.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Pr') then
        rcov(iat)=3.44d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Nd') then
        rcov(iat)=3.38d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Pm') then
        rcov(iat)=3.33d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Sm') then
        rcov(iat)=3.27d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Eu') then
        rcov(iat)=3.21d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Gd') then
        rcov(iat)=3.15d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Td') then
        rcov(iat)=3.09d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Dy') then
        rcov(iat)=3.03d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ho') then
        rcov(iat)=2.97d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Er') then
        rcov(iat)=2.92d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Tm') then
        rcov(iat)=2.92d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Yb') then
        rcov(iat)=2.80d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Lu') then
        rcov(iat)=2.80d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Hf') then
        rcov(iat)=2.90d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ta') then
        rcov(iat)=2.70d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='W' ) then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Re') then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Os') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Ir') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Pt') then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Au') then
        rcov(iat)=2.70d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Hg') then
        rcov(iat)=2.80d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Tl') then
        rcov(iat)=2.50d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Pb') then
        rcov(iat)=3.30d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Bi') then
        rcov(iat)=2.90d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Po') then
        rcov(iat)=2.80d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='At') then
        rcov(iat)=2.60d0
     else if (trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))=='Rn') then
        rcov(iat)=2.60d0
     else
        call yaml_comment('(MH) no covalent radius stored for this atomtype '&
             //trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat))))
     endif
     if (iproc == 0) then
        call yaml_map('(MH) RCOV:'//trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat))),rcov(iat))
     endif
  enddo
end subroutine give_rcov

!> Display the logo of Minima Hopping 
subroutine print_logo_MH()
  use module_base
  use yaml_output
  implicit none

call yaml_comment('Minima Hopping ....',hfill='=')

call yaml_mapping_open('MH logo')

call yaml_scalar(' NEW ')
call yaml_scalar('      __  __ _ _  _ _   _  __  ___ ')
call yaml_scalar('     |  \/  |_| \| | |_| |/  \| _ \ ')
call yaml_scalar('     | |\/| |-|    |  _  | <> |  _/ ')
call yaml_scalar('     |_|  |_|_|_|\_|_| |_|\__/|_|     WITH')
call yaml_scalar('')
call yaml_scalar('')
call yaml_scalar('')
call print_logo()
call yaml_scalar('----> you can grep this file for (MH) to see Minima Hopping output')
call yaml_scalar(' (MH) NOTE: this version reads nspin, mpol from input.dat')
call yaml_mapping_close()
call yaml_map('Reference Paper','The Journal of Chemical Physics 120 (21): 9911-7 (2004)')

END SUBROUTINE print_logo_MH


subroutine identical(iproc,nlminx,nlmin,nid,e_wpos,wfp,en_arr,fp_arr,en_delta,fp_delta,newmin,kid,dmin,k_e_wpos,n_unique,n_nonuni)
  implicit real*8 (a-h,o-z)
  dimension fp_arr(nid,nlminx),wfp(nid),en_arr(nlminx)
  logical newmin

  !C  check whether new minimum
  call hunt_g(en_arr,min(nlmin,nlminx),e_wpos,k_e_wpos)
  newmin=.true.
  do i=1,nlmin
     if (iproc.eq.0) write(*,'(a,i3,5(e24.17))') '(MH) enarr ',i,en_arr(i),(fp_arr(l,i),l=1,2)
  enddo
  if (iproc.eq.0) write(*,'(a,e24.17,i3,5(e24.17))') '(MH) e_wpos,k_e_wpos ',e_wpos,k_e_wpos!,(wfp(l),l=1,2)

  ! find lowest configuration that might be identical
  klow=k_e_wpos
  do k=k_e_wpos,1,-1
     if (e_wpos-en_arr(k).lt.0.d0) stop 'zeroA'
     if (e_wpos-en_arr(k).gt.en_delta) exit
     klow=k
  enddo

  ! find highest  configuration that might be identical
  khigh=k_e_wpos+1
  do k=k_e_wpos+1,nlmin
     if (en_arr(k)-e_wpos.lt.0.d0) stop 'zeroB'
     if (en_arr(k)-e_wpos.gt.en_delta) exit
     khigh=k
  enddo

  nsm=0
  if (iproc.eq.0) write(*,*) '(MH) k bounds ',max(1,klow),min(nlmin,khigh)
  dmin=1.d100
  do k=max(1,klow),min(nlmin,khigh)
     call fpdistance(nid,wfp,fp_arr(1,k),d)
     if (iproc.eq.0) write(*,*) '(MH)  k,d',k,d
     if (iproc.eq.0) write(*,'(a,20(e10.3))') '(MH)    wfp', (wfp(i),i=1,nid)
     if (iproc.eq.0) write(*,'(a,20(e10.3))') '(MH) fp_arr', (fp_arr(i,k),i=1,nid)
     if (d.lt.fp_delta) then
        if (iproc.eq.0) write(*,*) '(MH) identical to ',k
        newmin=.false.
        nsm=nsm+1
        if (d.lt.dmin) then 
           dmin=d
           kid=k
        endif
     endif
  enddo
  if (iproc.eq.0) then
     write(*,*) '(MH)  newmin ',newmin
     write(*,*) ' ----------------------------------------------------'
     if (nsm.gt.1) write(*,*) '(MH) WARNING: more than one identical configuration found'
  endif
  !          if (nsm.gt.1) write(100+iproc,*) 'WARNING: more than one identical configuration found'
  if (nsm.eq.1) n_unique=n_unique+1
  if (nsm.gt.1) n_nonuni=n_nonuni+1

  return
end subroutine identical

subroutine insert(iproc,nlminx,nlmin,nid,nat,k_e_wpos,e_wpos,wfp,wpos,en_arr,ct_arr,fp_arr,pl_arr)
  ! inserts the energy e_wpos at position k_e_wpos and shifts up all other energies
  implicit real*8 (a-h,o-z)
  dimension ct_arr(nlminx),en_arr(nlminx),fp_arr(nid,nlminx),pl_arr(3,nat,nlminx),wfp(nid),wpos(3,nat)
  do k=nlmin-1,k_e_wpos+1,-1
     en_arr(k+1)=en_arr(k)
     ct_arr(k+1)=ct_arr(k)
     do i=1,nid
        fp_arr(i,k+1)=fp_arr(i,k)
     enddo
     do iat=1,nat
        pl_arr(1,iat,k+1)=pl_arr(1,iat,k)
        pl_arr(2,iat,k+1)=pl_arr(2,iat,k)
        pl_arr(3,iat,k+1)=pl_arr(3,iat,k)
     enddo
  enddo
  en_arr(k_e_wpos+1)=e_wpos
  ct_arr(k_e_wpos+1)=1.d0
  do i=1,nid
     fp_arr(i,k+1)=wfp(i)
  enddo
  do iat=1,nat
     pl_arr(1,iat,k+1)=wpos(1,iat)
     pl_arr(2,iat,k+1)=wpos(2,iat)
     pl_arr(3,iat,k+1)=wpos(3,iat)
  enddo
  if (iproc.eq.0) then
     write(*,*) '  -----   INSERT -----------'
     do k=1,nlmin
        write(*,'(a,i3,20(e10.3))') '(MH) fingerprint ',k,(fp_arr(i,k),i=1,nid)
     enddo
  endif
  return
end subroutine insert


!> x is in interval [xx(jlo),xx(jlow+1)[ ; xx(0)=-Infinity ; xx(n+1) = Infinity
subroutine hunt_orig(xx,n,x,jlo)
  integer :: jlo,n
  real*8 x,xx(n)
  integer :: inc,jhi,jm
  logical :: ascnd

  if (n.le.0) stop 'hunt_orig'
  if (n.eq.1) then
     if (x.ge.xx(1)) then
        jlo=1
     else
        jlo=0
     endif
     return
  endif
  ascnd=xx(n).ge.xx(1)

  if(jlo.le.0.or.jlo.gt.n)then
     jlo=0
     jhi=n+1
     goto 3
  endif
  inc=1

  if(x.ge.xx(jlo).eqv.ascnd) then
1    continue
     jhi=jlo+inc
     if(jhi.gt.n)then
        jhi=n+1
     else if(x.ge.xx(jhi).eqv.ascnd) then
        jlo=jhi
        inc=inc+inc
        goto 1
     endif
  else
     jhi=jlo
2    continue
     jlo=jhi-inc
     if(jlo.lt.1)then
        jlo=0
     else if(x.lt.xx(jlo).eqv.ascnd)then
        jhi=jlo
        inc=inc+inc
        goto 2
     endif
  endif

3 continue
  if(jhi-jlo.eq.1)then
     if(x.eq.xx(n))jlo=n
     if(x.eq.xx(1))jlo=1
     return
  endif
  jm=(jhi+jlo)/2
  if(x.ge.xx(jm).eqv.ascnd)then
     jlo=jm
  else
     jhi=jm
  endif
  goto 3

END subroutine hunt_orig



!        subroutine wtbest_l(iproc,nat,alat,energy,pos)
!        implicit real*8 (a-h,o-z)
!        character(59) filename
!        character(3) fn
!        dimension pos(3,nat),alat(3)
!
!
!!C generate filename and open files
!        write(fn,'(i3.3)') iproc
!        filename = 'posbest_l_'//fn//'.xyz'
!        open(unit=49,file=filename,status='unknown')
!        write(49,'(i4,e24.17)') nat,energy
!        write(49,*) nat
!        write(49,*) alat
!        do iat=1,nat
!        write(49,'(1x,a6,9x,3(8x,e24.17))') 'LJ  ',(pos(l,iat),l=1,3)
!        enddo
!
!        return
!        end



!       subroutine fingerprint(iproc,nat,nid,rxyz,rcov,fp)
!       implicit real*8 (a-h,o-z)
!       dimension rxyz(3,nat),fp(nid),rcov(nat)
!       real*8, allocatable, dimension(:,:) :: aa,work
!       allocate(aa(nat,nat),work(nat,nat))
!
!! Gaussian overlap
!     do iat=1,nat
!      do jat=iat,nat
!        d2=(rxyz(1,iat)-rxyz(1,jat))**2 +(rxyz(2,iat)-rxyz(2,jat))**2+(rxyz(3,iat)-rxyz(3,jat))**2
!        r=.5d0/(rcov(iat)**2 + rcov(jat)**2) 
!        ! with normalized GTOs:
!        aa(jat,iat)=sqrt(2.d0*r*(2.d0*rcov(iat)*rcov(jat)))**3 * exp(-d2*r)
!        enddo
!      enddo
!
!
!       call DSYEV('N','L',nat,aa,nat,fp,work,nat**2,info)
!       if (info.ne.0) stop 'info'
!       if (iproc.eq.0) write(*,'(a,20(e10.3))') '(MH) fingerprint ',(fp(i),i=1,nid)
!
!       deallocate(aa,work)
!       end subroutine fingerprint



subroutine fingerprint(iproc,nat,nid,rxyz,rcov,fp,geocode,alat)
! calculates an overlap matrix for atom centered GTO of the form:
!    s-type: 1/norm_s  exp(-(1/2)*(r/rcov)**2)
!   px type: 1/norm_p exp(-(1/2)*(r/rcov)**2) x/r  and analageously for py and pz
use dynamic_memory
implicit none !real*8 (a-h,o-z)
integer  nat,nid ,iproc,  info
real*8 :: rxyz(3,nat),fp(nid),rcov(nat),tau(3),alat(3)
real*8, allocatable, dimension(:,:) :: om,work

integer igto,jgto, iat, jat
integer i1,i2,i3, n1, n2, n3  
real*8  cutoff, d2, r
real*8  sji, xi,yi,zi, xji, yji, zji   ,tt 
real*8  sqrt8 ; parameter (sqrt8=sqrt(8.d0))
character(len=1) :: geocode


   ! WARNING! check convergence to ensure that the folloing cutoff is large enough
   !! exp(-0.5*cutoff^2/rcov^2) = 1E-16  ==> cutoff^2 = 2*16*log(10)*rcov^2 ==> cutoff ~=8.5 rcov 
   !cutoff=sqrt(2*16*log(10.d0)*maxval(rcov)**2)
   cutoff=9*maxval(rcov)
     !print*, cutoff; stop

   !with these settings the fingerprints have about 9 correct decimal places
     if (geocode == 'F') then       ! free boundary conditions
         n1=0 ; n2=0 ; n3=0
     else if (geocode == 'S') then  ! surface boundary conditions, non-periodic direction i s
         n1=nint(cutoff/alat(1))
         n2=0
         n3=nint(cutoff/alat(3))
     else if (geocode == 'P') then  ! periodic boundary conditions
         n1=nint(cutoff/alat(1))
         n2=nint(cutoff/alat(2))
         n3=nint(cutoff/alat(3))
     else
     stop 'unrecognized BC in fingerprint'
     endif
     if (n1+n2+n3.gt.30) write(*,*) 'Warning n1,n2,n3 too big ',n1,n2,n3

if(nid .ne. nat .and. nid .ne. 4*nat) stop ' nid should be either nat or  4*nat '


om = f_malloc((/nid,nid/),id='om')
work =  f_malloc((/nid,nid/),id='work')
om(:,:)=0.d0

    do i1=-n1,n1
    do i2=-n2,n2
    do i3=-n3,n3
    
       tau(1)=alat(1)*i1
       tau(2)=alat(2)*i2
       tau(3)=alat(3)*i3
    !   if (tau(1)*tau(1) + tau(2)*tau(2)+ tau(3)*tau(3)>cutoff*cutoff) cycle  ! to speedup
    
    ! Gaussian overlap
         !  <sj|si>
          do iat=1,nat
           xi=rxyz(1,iat) + tau(1) 
           yi=rxyz(2,iat) + tau(2)
           zi=rxyz(3,iat) + tau(3)
          
           do jat=iat,nat
             d2=(rxyz(1,jat) -xi)**2 +(rxyz(2,jat)-yi)**2+(rxyz(3,jat)-zi)**2
             r=.5d0/(rcov(iat)**2 + rcov(jat)**2)
             om(jat,iat)=om(jat,iat) + sqrt(4.d0*r*(rcov(iat)*rcov(jat)))**3 * exp(-d2*r)
             enddo
           enddo
    
    enddo !i3
    enddo !i2
    enddo !i1


!!  so far only s-s have been calculated  
if(nid == 4*nat) then  ! both s and p (nid = 4nat)

    do i1=-n1,n1
    do i2=-n2,n2
    do i3=-n3,n3
 
       tau(1)=alat(1)*i1
       tau(2)=alat(2)*i2
       tau(3)=alat(3)*i3

    !  <s|p>
    do iat=1,nat
      xi=rxyz(1,iat) + tau(1)
      yi=rxyz(2,iat) + tau(2)
      zi=rxyz(3,iat) + tau(3)

      do jat=1,nat   ! NOTE: do not use  jat=iat,nat becase all elements are on the same side of the diagonal

        xji=rxyz(1,jat) - xi
        yji=rxyz(2,jat) - yi 
        zji=rxyz(3,jat) - zi

        d2=xji*xji + yji*yji + zji*zji
        r=.5d0/(rcov(jat)**2 + rcov(iat)**2)

        sji= sqrt(4.d0*r*(rcov(jat)*rcov(iat)))**3 * exp(-d2*r)

    !  <pj|si>
        tt= sqrt8 *rcov(jat)*r * sji

        om(1+nat + (jat-1)*3 ,iat )=  om(1+nat + (jat-1)*3 ,iat ) + tt * xji 
        om(2+nat + (jat-1)*3 ,iat )=  om(2+nat + (jat-1)*3 ,iat ) + tt * yji 
        om(3+nat + (jat-1)*3 ,iat )=  om(3+nat + (jat-1)*3 ,iat ) + tt * zji 

   !! !  <sj|pi> no need, because they are on the other side of the diagonal of the symmetric matrix
   !!     tt=-sqrt8 *rcov(iat)*r * sji

   !!     om(jat, 1+nat + (iat-1)*3 )=  om(jat, 1+nat + (iat-1)*3 ) + tt * xji 
   !!     om(jat, 2+nat + (iat-1)*3 )=  om(jat, 2+nat + (iat-1)*3 ) + tt * yji 
   !!     om(jat, 3+nat + (iat-1)*3 )=  om(jat, 3+nat + (iat-1)*3 ) + tt * zji 

enddo
enddo


    ! <pj|pi> 
    do iat=1,nat
      xi=rxyz(1,iat) + tau(1)
      yi=rxyz(2,iat) + tau(2)
      zi=rxyz(3,iat) + tau(3)

      do jat=iat,nat

        xji=rxyz(1,jat) - xi
        yji=rxyz(2,jat) - yi 
        zji=rxyz(3,jat) - zi

        d2=xji*xji + yji*yji + zji*zji
        r=.5d0/(rcov(jat)**2 + rcov(iat)**2)

        sji= sqrt(4.d0*r*(rcov(jat)*rcov(iat)))**3 * exp(-d2*r)

        igto=nat+1 +(iat-1)*3 
        jgto=nat+1 +(jat-1)*3

        tt = -8.d0*rcov(iat)*rcov(jat) * r*r * sji 

        om(jgto   , igto  )=  om(jgto   , igto  ) + tt *(xji* xji - .5d0/r) 
        om(jgto   , igto+1)=  om(jgto   , igto+1) + tt *(yji* xji         ) 
        om(jgto   , igto+2)=  om(jgto   , igto+2) + tt *(zji* xji         ) 
        om(jgto+1 , igto  )=  om(jgto+1 , igto  ) + tt *(xji* yji         ) 
        om(jgto+1 , igto+1)=  om(jgto+1 , igto+1) + tt *(yji* yji - .5d0/r) 
        om(jgto+1 , igto+2)=  om(jgto+1 , igto+2) + tt *(zji* yji         ) 
        om(jgto+2 , igto  )=  om(jgto+2 , igto  ) + tt *(xji* zji         ) 
        om(jgto+2 , igto+1)=  om(jgto+2 , igto+1) + tt *(yji* zji         ) 
        om(jgto+2 , igto+2)=  om(jgto+2 , igto+2) + tt *(zji* zji - .5d0/r) 

     enddo
    enddo  

enddo  ! i3 
enddo  ! i2
enddo  ! i1

endif  ! both s and p 



 call DSYEV('N','L',nid,om,nid,fp,work,nid**2,info)
 if (info.ne.0) stop 'info'
 if (iproc.eq.0) write(*,'(a,20(e10.3))') '(MH) fingerprint ',(fp(i1),i1=1,nid)

call f_free(om)
call f_free(work)
end subroutine fingerprint


       subroutine fpdistance(nid,fp1,fp2,d)
       implicit real*8 (a-h,o-z)
       dimension fp1(nid),fp2(nid)

       d=0.d0
       do i=1,nid
       d = d + (fp1(i)-fp2(i))**2
       enddo
       d=sqrt(d/nid)

       end subroutine fpdistance



 subroutine ha_trans(nat,pos)
   use BigDFT_API, only:gp
   use yaml_output
   !implicit real*8 (a-h,o-z)
   implicit none
   integer, intent(in) :: nat
   real(gp), dimension(3,nat), intent(inout) :: pos
   !local variables
   integer, parameter :: lwork=100
   integer :: iat,info,j
   real(gp) :: haratio,p1,p2,p3
   integer, dimension(3) :: ipiv
   real(gp), dimension(3) :: pos_s,theta_e,maxt
   real(gp), dimension(lwork) :: work
   real(gp), dimension(3,3) :: theta
   !dimension pos(3,nat),pos_s(3)
   ! dimension theta(3,3),theta_e(3),work(lwork)

!   call yaml_map('Entering ha_trans',pos)

   ! positions relative to center of mass
   pos_s(1)=0.d0
   pos_s(2)=0.d0
   pos_s(3)=0.d0
   do iat=1,nat
      pos_s(1)=pos_s(1)+pos(1,iat)
      pos_s(2)=pos_s(2)+pos(2,iat)
      pos_s(3)=pos_s(3)+pos(3,iat)
   enddo
   pos_s(1)=pos_s(1)/real(nat,gp)
   pos_s(2)=pos_s(2)/real(nat,gp)
   pos_s(3)=pos_s(3)/real(nat,gp)  

   do iat=1,nat
      pos(1,iat)=pos(1,iat)-pos_s(1)
      pos(2,iat)=pos(2,iat)-pos_s(2)        
      pos(3,iat)=pos(3,iat)-pos_s(3)
   enddo

!   call yaml_map('Entering ha_trans2',pos)
   ! Calculate inertia tensor theta
   theta=0.0_gp
!!$   do 10,j=1,3
!!$   do 10,i=1,3
!!$10 theta(i,j)=0.d0

   do iat=1,nat
      theta(1,1)=theta(1,1) + pos(2,iat)*pos(2,iat) + &  
           pos(3,iat)*pos(3,iat)
      theta(2,2)=theta(2,2) + pos(1,iat)*pos(1,iat) + &  
           pos(3,iat)*pos(3,iat)
      theta(3,3)=theta(3,3) + pos(1,iat)*pos(1,iat) + &   
           pos(2,iat)*pos(2,iat)

      theta(1,2)=theta(1,2) - pos(1,iat)*pos(2,iat)
      theta(1,3)=theta(1,3) - pos(1,iat)*pos(3,iat)
      theta(2,3)=theta(2,3) - pos(2,iat)*pos(3,iat)
      theta(2,1)=theta(1,2)
      theta(3,1)=theta(1,3)
      theta(3,2)=theta(2,3)
   enddo
   ! diagonalize theta
   call DSYEV('V','U',3,theta(1,1),3,theta_e(1),work(1),lwork,info)        
   haratio=theta_e(3)/theta_e(1)

   !choose the sign of the eigenvector such that the component with the 
   ! maximum value should be positive
!!$   maxt=0.0_gp
!!$   do j=1,3
!!$      do i=1,3
!!$         if ( abs(maxt(j)) - abs(theta(i,j)) < 1.e-10_gp)then
!!$            maxt(j)=theta(i,j)
!!$         end if
!!$      end do
!!$      if (maxt(j) < 0.0_gp) then
!!$         theta(:,j)=-theta(:,j)
!!$      end if
!!$   end do
   !then choose a well-defined ordering for the modifications
   do j=1,3
      ipiv(j)=j
      maxt(j)=theta(3,j)+1.e3_gp*theta(2,j)+1.e6_gp*theta(1,j)
      if (maxt(j) < 0.0_gp) then
         theta(:,j)=-theta(:,j)
         maxt(j)=-maxt(j)
      end if
   end do
   if (maxt(1) <= maxt(2)) then
      if (maxt(2) > maxt(3)) then
         if (maxt(1) > maxt(3)) then
            !worst case, 3<1<2
            ipiv(1)=3
            ipiv(2)=1
            ipiv(3)=2
         else
            ! 1<3<2
            ipiv(2)=3
            ipiv(3)=2
         end if
      end if
   else
      if (maxt(1) > maxt(3)) then
         if (maxt(2) < maxt(3)) then
            !other worst case 2<3<1
            ipiv(1)=2
            ipiv(2)=3
            ipiv(3)=1
         else
            !  1>3<2, but 2<1 => 3<2<1
            ipiv(1)=3
            ipiv(3)=1
         end if
      else
         !2<1 and 3>1 => 2<1<3
         ipiv(1)=2
         ipiv(2)=1
      end if
   end if

   do iat=1,nat
      p1=pos(1,iat)
      p2=pos(2,iat)
      p3=pos(3,iat)
      pos(1,iat) = theta(1,ipiv(1))*p1+ theta(2,ipiv(1))*p2+ theta(3,ipiv(1))*p3
      pos(2,iat) = theta(1,ipiv(2))*p1+ theta(2,ipiv(2))*p2+ theta(3,ipiv(2))*p3
      pos(3,iat) = theta(1,ipiv(3))*p1+ theta(2,ipiv(3))*p2+ theta(3,ipiv(3))*p3
   enddo

!   call yaml_map('Exiting ha_trans',pos)

!!$   do j=1,3
!!$      call yaml_map('Thetaj',theta(:,j))
!!$   end do
!   stop
END SUBROUTINE ha_trans

!> put velocities for frozen degrees of freedom to zero
subroutine frozen_dof(astruct,vxyz,ndfree,ndfroz)
  use module_atoms, only: atomic_structure, move_this_coordinate
  implicit none
  type(atomic_structure), intent(in) :: astruct
  integer, intent(out) :: ndfree,ndfroz
  real(kind=8), dimension(3,astruct%nat), intent(inout) :: vxyz
  !local variables
  integer :: iat,ixyz

  ndfree=0
  ndfroz=0
  do iat=1,astruct%nat
     do ixyz=1,3
        if ( move_this_coordinate(astruct%ifrztyp(iat),ixyz) ) then
           ndfree=ndfree+1
        else
           ndfroz=ndfroz+1
           vxyz(ixyz,iat)=0.d0
        endif
     enddo
  enddo
end subroutine frozen_dof
