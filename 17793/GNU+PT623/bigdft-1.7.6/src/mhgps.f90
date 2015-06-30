!! @file
!! @author Bastian Schaefer
!! @section LICENCE
!!    Copyright (C) 2014 UNIBAS
!!    This file is not freely distributed.
!!    A licence is necessary from UNIBAS
program mhgps
    use module_base
    use module_types
    use module_interfaces
    use module_input_dicts
    use yaml_output
    use module_io
    use module_atoms, only: deallocate_atoms_data,&
                            deallocate_atomic_structure,&
                            atomic_structure,&
                            read_atomic_file=>set_astruct_from_file,&
                            astruct_dump_to_file
    
    use module_global_variables
    use module_init
    use module_energyandforces, only: energyandforces
    use module_ls_rmsd, only: superimpose
    use module_sbfgs, only: findbonds !for finding binds
    use module_freezingstring, only: get_ts_guess 
    use module_saddle, only: findsad
    use module_connect, only: connect_recursively, connect, connect_object,&
                              deallocate_connect_object,&
                              allocate_connect_object
    use module_fingerprints, only: fingerprint
    use module_hessian, only: cal_hessian_fd 
    use module_minimizers
    implicit none
    integer :: nend
    character(len=6) :: filename,filename2
    integer :: ifolder, ifile
    logical :: xyzexists,asciiexists
    character(len=60) :: run_id
    type(dictionary), pointer :: run
    integer :: ierr, nconfig
    real(gp), allocatable :: rcov(:)
    character(len=300)  :: comment
    logical :: converged=.false.
    type(connect_object) :: cobj
    type(dictionary), pointer :: options
    type(atomic_structure), target :: atom_struct
    integer :: nsad
    logical :: connected

    !simple atomic datastructre
    integer :: nat
    integer :: nid
    real(gp) :: alat(3)
    real(gp), allocatable :: rxyz(:,:),fxyz(:,:)
    real(gp), allocatable :: fat(:,:)
    real(gp), allocatable :: rxyz2(:,:),fxyz2(:,:)
    real(gp), allocatable :: tsguess(:,:),minmodeguess(:,:)
    real(gp), allocatable :: tsgforces(:,:)
    real(gp)              :: tsgenergy
    real(gp), allocatable :: fp(:),fp2(:)
    real(gp), allocatable :: rotforce(:,:),hess(:,:)
    real(gp), allocatable :: eval(:)
    real(gp) :: energy, energy2, ec, displ
    real(gp) :: fnoise, fnrm, fmax
    integer :: i,j,info
    integer :: idum=0
    real(kind=4) :: builtin_rand

    !functions
    real(gp) :: dnrm2

    !alanine stuff ......................START!>
    real(gp), allocatable :: rxyzdmy(:,:), fxyzdmy(:,:)
    character(len=5), allocatable :: atomnamesdmy(:)
    integer :: l_sat, nfnpdb
    character(len=11) :: fnpdb
    !alanine stuff ......................END!>

    ifolder=1
    ifile=1
    ef_counter=0.d0 !from module_global_variables
    isad=0  !from module_global_variables
    isadprob=0


    call f_lib_initialize()

    !read mhgps.inp
    call read_input()

    !initialize the energy and forces method
    isForceField=.false.
    if(efmethod=='BIGDFT')then
        isForceField=.false.
        call bigdft_command_line_options(options)
        call bigdft_init(options)!mpi_info,nconfig,run_id,ierr)
        if (bigdft_nruns(options) > 1) then
            call f_err_throw('runs-file not supported for MHGPS '//&
                              'executable')
        endif
        run => options // 'BigDFT' // 0
!        run = options // 0 // 'name'
        iproc=bigdft_mpi%iproc!mpi_info(1)
        nproc=bigdft_mpi%nproc!mpi_info(2)
        igroup=bigdft_mpi%igroup!mpi_info(3)
        !number of groups
        ngroups=bigdft_mpi%ngroup!mpi_info(4)
        !actual value of iproc
        iproc=iproc+igroup*ngroups
        if(iproc==0) call print_logo_mhgps()

        !reset input and output positions of run
        call bigdft_get_run_properties(run,run_id=run_id)
        write(currDir,'(a,i3.3)')'input',ifolder
        write(filename,'(a,i3.3)')'pos',ifile
        call bigdft_set_run_properties(run,run_id=trim(run_id)//&
             trim(bigdft_run_id_toa()),posinp=currDir//'/'//filename&
             //trim(bigdft_run_id_toa()))

        call run_objects_init(runObj,run)

        !options and run are not needed
        call dict_free(options)
        nullify(run)

        call init_global_output(outs, bigdft_nat(runObj))
        fdim=outs%fdim

        astruct_ptr => bigdft_get_astruct_ptr(runObj)

!        call dict_init(user_inputs)
!        write(currDir,'(a,i3.3)')'input',ifolder
!        write(filename,'(a,i3.3)')'pos',ifile
!        !LG: why not initialize only run_objects?
!        call user_dict_from_files(user_inputs, trim(run_id)//&
!             trim(bigdft_run_id_toa()),currDir//'/'//filename//&
!             trim(bigdft_run_id_toa()), bigdft_mpi)
!        call inputs_from_dict(inputs_opt, atoms, user_inputs)
!        call dict_free(user_inputs)
!        call init_global_output(outs, atoms%astruct%nat)
!        fdim=outs%fdim
!        call init_restart_objects(bigdft_mpi%iproc,inputs_opt,atoms,&
!                                 rst)
!        call nullify_run_objects(runObj)
!        call run_objects_associate(runObj, inputs_opt, atoms, rst)
!        call dict_free(options)
        !LG : to be wrapped again

        !set minimum number of wave function optimizations
!        if(runObj%inputs%itermin<5)then
!            itermin=5
!        else
            itermin=runObj%inputs%itermin
!        endif

    elseif(efmethod=='LJ' .or. efmethod=='LENSIc' .or. &
           efmethod=='LENSIb')then
        iproc=0
        isForceField=.true.
        write(currDir,'(a,i3.3)')'input',ifolder
        write(filename,'(a,i3.3)')'pos',ifile
        call deallocate_atomic_structure(atom_struct)
        call read_atomic_file(currDir//'/'//filename,iproc,&
                              atom_struct)
        astruct_ptr=>atom_struct
        fdim=astruct_ptr%nat
        call print_logo_mhgps()
!    elseif(efmethod=='AMBER')then
!        iproc=0
!        isForceField=.true.
!        write(currDir,'(a,i3.3)')'input',ifolder
!        write(filename,'(a,i3.3)')'pos',ifile
!        call deallocate_atomic_structure(atom_struct)
!        call read_atomic_file(currDir//'/'//filename,iproc,&
!                              atom_struct)
!        astruct=>atom_struct
!        fdim=astruct%nat
!        !alanine stuff ......................START!>
!          l_sat=5
!          allocate(atomnamesdmy(1000))
!          rxyzdmy = f_malloc((/ 1.to.3, 1.to.astruct%nat/),&
!                            id='rxyzdmy')
!          fxyzdmy = f_malloc((/ 1.to.3, 1.to.astruct%nat/),&
!                            id='fxyzdmy')
!          fnpdb='ald_new.pdb'
!          nfnpdb=len(trim(fnpdb));
!          call nab_init(astruct%nat,rxyzdmy,fxyzdmy,&
!                        trim(fnpdb),nfnpdb,l_sat,atomnamesdmy)
!          call f_free(rxyzdmy)
!          call f_free(fxyzdmy)
!          deallocate(atomnamesdmy)
!        !alanine stuff ......................END!>
!
!        call print_logo_mhgps()
    else
        call yaml_warning('Following method for evaluation of '//&
        'energies and forces is unknown: '//trim(adjustl(efmethod)))
        stop
    endif
    if(iproc==0) call print_input()

    nat = bigdft_nat(runObj)
    nid = nat !s-overlap fingerprints
    alat =bigdft_get_cell(runObj)!astruct_ptr%cell_dim
    
    !allocate more arrays
    lwork=1000+10*nat**2
    work = f_malloc((/1.to.lwork/),id='work')
    eval  = f_malloc((/ 1.to.3*nat/),id='eval')
    tsgforces     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='tsgforces')
    tsguess     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='tsguess')
    minmodeguess  = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='minmodeguess')
    minmode  = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='minmode')
    rxyz     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rxyz')
    fp       = f_malloc((/ 1.to.nid/),&
                id='fp')
    fp2      = f_malloc((/ 1.to.nid/),&
                id='fp2')
    fxyz     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='fxyz')
    rxyz2     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rxyz2')
    fxyz2     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='fxyz2')
    rcov     = f_malloc((/ 1.to.nat/),id='rcov')
    iconnect = f_malloc((/ 1.to.2, 1.to.1000/),id='iconnect')
    ixyz_int = f_malloc((/ 1.to.3,1.to.nat/),&
                id='nat')
    rotforce = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rotforce')
    hess     = f_malloc((/ 1.to.3*nat,&
                1.to.3*nat/),id='hess')
    rxyz_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='rxyz_rot')
    fxyz_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='fxyz_rot') 
    fxyzraw_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='fxyzraw_rot')
    rxyzraw_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='rxyzraw_rot')
    fstretch_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='fstretch_rot')
    eval_rot = f_malloc((/1.to.saddle_nhistx_rot/),id='eval_rot')
    res_rot = f_malloc((/1.to.saddle_nhistx_rot/),id='res_rot')
    rrr_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='rrr_rot')
    aa_rot = f_malloc((/1.to.saddle_nhistx_rot,&
             1.to.saddle_nhistx_rot/),id='aa_rot')
    ff_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='ff_rot')
    rr_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='rr_rot')
    dd_rot = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='dd_rot')
    fff_rot = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_rot/),id='fff_rot')
    scpr_rot = f_malloc((/ 1.to.saddle_nhistx_rot/),id='scpr_rot')
    rxyz_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='rxyz_trans')
    fxyz_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='fxyz_trans') 
    fxyzraw_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='fxyzraw_trans')
    rxyzraw_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='rxyzraw_trans')
    fstretch_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='fstretch_trans')
    eval_trans = f_malloc((/1.to.saddle_nhistx_trans/),&
                 id='eval_trans')
    res_trans = f_malloc((/1.to.saddle_nhistx_trans/),id='res_trans')
    rrr_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='rrr_trans')
    aa_trans = f_malloc((/1.to.saddle_nhistx_trans,&
                1.to.saddle_nhistx_trans/),id='aa_trans')
    ff_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='ff_trans')
    rr_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                0.to.saddle_nhistx_trans/),id='rr_trans')
    dd_trans = f_malloc((/ 1.to.3, 1.to.nat/),id='dd_trans')
    fff_trans = f_malloc((/ 1.to.3, 1.to.nat,&
                -1.to.saddle_nhistx_trans/),id='fff_trans')
    scpr_trans = f_malloc((/ 1.to.saddle_nhistx_trans/),&
                 id='scpr_trans')

    call allocate_connect_object(nat,nid,nsadmax,cobj)

!for debugging:
allocate(fat(3,nat))
    
    iconnect = 0
    ixyz_int = 0
    call give_rcov(astruct_ptr,nat,rcov)
    !if in biomode, determine bonds betweens atoms once and for all
    !(it isassuemed that all conifugrations over which will be
    !iterated have the same bonds)
    if(saddle_biomode)then
        call findbonds('(MHGPS)',iproc,mhgps_verbosity,nat,rcov,&
        astruct_ptr%rxyz,nbond,iconnect)
    endif
    wold_trans = f_malloc((/ 1.to.nbond/),id='wold_trans')
    wold_rot = f_malloc((/ 1.to.nbond/),id='wold_rot')

    do ifolder = 1,999
        write(currDir,'(a,i3.3)')'input',ifolder
        if(trim(adjustl(operation_mode))=='simple'.or.&
           trim(adjustl(operation_mode))=='hessian'.or.&
           trim(adjustl(operation_mode))=='minimize')then
            nend=999
        elseif(trim(adjustl(operation_mode))=='connect'.or.&
                       trim(adjustl(operation_mode))=='guessonly')then
            nend=999-1
        else
            call yaml_warning('(MHGPS) operation mode '//&
            trim(adjustl(operation_mode))//' unknown STOP')
            stop '(MHGPS) operation mode unknown STOP'
        endif

        do ifile = 1,nend

            !read (first) file
            write(filename,'(a,i3.3)')'pos',ifile
            inquire(file=currDir//'/'//filename//'.xyz',&
                    exist=xyzexists)
            inquire(file=currDir//'/'//filename//'.ascii',&
                    exist=asciiexists)
            if(.not.(xyzexists.or.asciiexists))exit
            !reallocating astruct is dangerous as it is a pointer to 
            !a internal object of bigdft, therefore it should only be used for reading
!!$            call deallocate_atomic_structure(astruct)
!!$            call read_atomic_file(currDir//'/'//filename,iproc,&
!!$                    astruct)
!!$            call vcopy(3 * nat,astruct%rxyz(1,1),1,rxyz(1,1), 1)
            call bigdft_get_rxyz(filename=currDir//'/'//filename,rxyz=rxyz)

            if(trim(adjustl(operation_mode))=='guessonly')then
                !read second file
                write(filename2,'(a,i3.3)')'pos',ifile+1
                inquire(file=currDir//'/'//filename2//'.xyz',&
                            exist=xyzexists)
                inquire(file=currDir//'/'//filename2//'.ascii',&
                            exist=asciiexists)
                if(.not.(xyzexists.or.asciiexists))exit
!!$                call deallocate_atomic_structure(astruct)
!!$                call read_atomic_file(currDir//'/'//filename2,iproc,&
!!$                            astruct)
!!$                call vcopy(3*nat,astruct%rxyz(1,1),1,&
!!$                           rxyz2(1,1),1)
                call bigdft_get_rxyz(filename=currDir//'/'//filename2,rxyz=rxyz2)

                isad=isad+1
                write(isadc,'(i5.5)')isad
                !rmsd alignment (optional in mhgps approach)
                call superimpose(nat,rxyz(1,1),rxyz2(1,1))
                call get_ts_guess(nat,alat,rxyz(1,1),rxyz2(1,1),&
                     tsguess(1,1),minmodeguess(1,1),tsgenergy,&
                     tsgforces(1,1))
                write(comment,'(a)')&
                     'TS guess; forces below give guessed '//&
                     'minimummode.'
                call astruct_dump_to_file(astruct_ptr,&
                     currDir//'/sad'//trim(adjustl(isadc))//'_ig_finalM',&
                     comment,&
                     tsgenergy,rxyz=tsguess,forces=minmodeguess)

                call astruct_dump_to_file(astruct_ptr,&
                     currDir//'/sad'//trim(adjustl(isadc))//'_ig_finalF',&
                     comment,&
                     tsgenergy,rxyz=tsguess,forces=tsgforces)
            else if(trim(adjustl(operation_mode))=='connect')&
                                                                 then
                !read second file
                write(filename2,'(a,i3.3)')'pos',ifile+1
                inquire(file=currDir//'/'//filename2//'.xyz',&
                            exist=xyzexists)
                inquire(file=currDir//'/'//filename2//'.ascii',&
                            exist=asciiexists)
                if(.not.(xyzexists.or.asciiexists))exit
!!$                call deallocate_atomic_structure(astruct)
!!$                call read_atomic_file(currDir//'/'//filename2,iproc,&
!!$                            astruct)
!!$                call vcopy(3*nat,astruct%rxyz(1,1),1,&
!!$                           rxyz2(1,1),1)
                call bigdft_get_rxyz(filename=currDir//'/'//filename2,rxyz=rxyz2)

                !Evalute energyies. They are needed in connect
                !for identification
                call energyandforces(nat,alat,rxyz,fat,fnoise,energy)
                call energyandforces(nat,alat,rxyz2,fat,fnoise,&
                         energy2)
                call fingerprint(nat,nid,alat,astruct_ptr%geocode,&
                         rcov,rxyz(1,1),fp(1))
                call fingerprint(nat,nid,alat,astruct_ptr%geocode,&
                         rcov,rxyz2(1,1),fp2(1))
                if(iproc==0)then
                    call yaml_comment('(MHGPS) Connect '//filename//&
                               ' and '//filename2//' ....',hfill='-')
                endif
                nsad=0
                connected=.true.
!                call connect(nat,nid,alat,rcov,nbond,&
!                     iconnect,rxyz,rxyz2,energy,energy2,fp,fp2,&
!                     nsad,cobj,connected)
               call connect_recursively(nat,nid,alat,rcov,nbond,&
                     iconnect,rxyz,rxyz2,energy,energy2,fp,fp2,&
                     nsad,cobj,connected)
                if(connected)then
                    if(iproc==0)call yaml_map('(MHGPS) '//&
                              'succesfully connected, intermediate'//&
                              ' transition states:',nsad)
                else
                    if(iproc==0)call yaml_comment('(MHGPS) '//&
                               'Connection not established within '//&
                                trim(adjustl(yaml_toa(nsad)))//&
                                ' transition state computations')
                endif
            else if(trim(adjustl(operation_mode))=='simple')then
                isad=isad+1
                write(isadc,'(i3.3)')isad
                if(random_minmode_guess)then
                    do i=1,nat
                        minmode(1,i)=2.0_gp*&
                                (real(builtin_rand(idum),gp)-0.5_gp)
                        minmode(2,i)=2.0_gp*&
                                (real(builtin_rand(idum),gp)-0.5_gp)
                        minmode(3,i)=2.0_gp*&
                                (real(builtin_rand(idum),gp)-0.5_gp)
                    enddo
                    call write_mode(nat,currDir//'/pos'//&
                    trim(adjustl(isadc))//'_mode',minmode)
                else
                    call read_mode(nat,currDir//'/pos'//&
                    trim(adjustl(isadc))//'_mode',minmode)
                endif
                !!call random_seed
                !!call random_number(minmode)
                !!minmode=2.d0*(minmode-0.5d0)
                !normalize
                minmode = minmode/dnrm2(3*nat,minmode(1,1),1)
                ec=0.0_gp
                displ=0.0_gp
                call findsad(nat,alat,rcov,nbond,iconnect,&
                rxyz(1,1),energy,fxyz(1,1),minmode(1,1),displ,ec,&
                rotforce(1,1),converged)
                    if(.not.converged)then
                        call yaml_warning('Saddle '//yaml_toa(isad)//&
                            ' not converged')
                    endif
                    call fnrmandforcemax(fxyz(1,1),fnrm,&
                                        fmax,nat)
                    if (iproc == 0) then
                        write(comment,'(a,1pe10.3,5x1pe10.3)')&
                       'ATTENTION! Forces below give no forces, '//&
                       'but the final minmode| '//&
                       'fnrm, fmax = ',fnrm,fmax

                        call astruct_dump_to_file(astruct_ptr,&
                             currDir//'/sad'//trim(adjustl(isadc))//&
                             '_finalM',&
                             comment,&
                             energy,rxyz=rxyz,forces=minmode)

                        write(comment,'(a,1pe10.3,5x1pe10.3)')&
                             'fnrm, fmax = ',fnrm,fmax
                        call astruct_dump_to_file(astruct_ptr,&
                             currDir//'/sad'//trim(adjustl(isadc))//&
                             '_finalF',&
                             comment,&
                             energy,rxyz=rxyz,forces=fxyz)
                        
                        call write_mode(nat,currDir//'/sad'//&
                        trim(adjustl(isadc))//'_mode_final',&
                        minmode(1,1),rotforce(1,1))
                    endif
            else if(trim(adjustl(operation_mode))=='minimize')then
                isad=isad+1
                write(isadc,'(i3.3)')isad
                ec=0.0_gp
                call energyandforces(nat,alat,rxyz,fxyz,fnoise,energy)
                call minimize(imode,nat,alat,nbond,iconnect,&
                rxyz(1,1),fxyz(1,1),fnoise,energy,ec,converged,'')
                if(.not.converged)then
                    call yaml_warning('Minimization '//yaml_toa(isad)&
                         //' not converged')
                endif
                call fnrmandforcemax(fxyz(1,1),fnrm,fmax,nat)
                if (iproc == 0) then
                    write(comment,'(a,1pe10.3,5x1pe10.3)')&
                         'fnrm, fmax = ',fnrm,fmax

                    call astruct_dump_to_file(astruct_ptr,&
                         currDir//'/min'//trim(adjustl(isadc))//&
                         '_final',&
                         comment,&
                         energy,rxyz=rxyz,forces=fxyz)

                    write(comment,'(a,1pe10.3,5x1pe10.3)')&
                   'fnrm, fmax = ',fnrm,fmax
                    call astruct_dump_to_file(astruct_ptr,&
                         currDir//'/sad'//trim(adjustl(isadc))//&
                         '_finalF',&
                         comment,&
                         energy,rxyz=rxyz,forces=fxyz)
                endif
            else if(trim(adjustl(operation_mode))=='hessian')then
                call cal_hessian_fd(iproc,nat,alat,rxyz,hess)
                if(iproc==0)then
                    write(*,*)'(hess) HESSIAN:'
                    write(*,*)hess
                endif
                call DSYEV('V','L',3*nat,hess,3*nat,eval,WORK,LWORK,&
                     INFO)
                if (info.ne.0) stop 'DSYEV'
                    if(iproc==0)then
                        write(*,*)'(hess) EIGENVECTORS:'
                        write(*,*) hess
                        write(*,'(a,1x,es9.2,1x,es24.17)') '(hess)'//&
                        ' ---   App. eigenvalues in exact --------'//&
                        '--- fnrm:',sqrt(sum(fxyz**2)),energy
                        do j=1,3*nat
                            write(*,*) '(hess) eval ',j,eval(j)
                        enddo
                    endif
            else
                call yaml_warning('(MHGPS) operation mode '//&
                trim(adjustl(operation_mode))//' unknown STOP')
                stop '(MHGPS) operation mode unknown STOP'
            endif
        enddo
    enddo

    !finalize (dealloctaion etc...)
    if(efmethod=='BIGDFT')then
!        call free_restart_objects(rst)
!        call deallocate_atoms_data(atoms)
        nullify(astruct_ptr)
        !call run_objects_free_container(runObj)
!        call release_run_objects(runObj)
        call free_run_objects(runObj)
!        call free_input_variables(inputs_opt)
        call deallocate_global_output(outs)
        call bigdft_finalize(ierr)
    elseif(efmethod=='LJ'.or.efmethod=='AMBER'.or.&
           efmethod=='LENSIc' .or. efmethod=='LENSIb')then
        call deallocate_atomic_structure(atom_struct)
        nullify(astruct_ptr)
    endif

    call f_free(work)
    call f_free(eval)
    call f_free(tsguess)
    call f_free(tsgforces)
    call f_free(minmodeguess)
    call f_free(minmode)
    call f_free(fp)
    call f_free(fp2)
    call f_free(rxyz)
    call f_free(fxyz) 
    call f_free(rxyz2)
    call f_free(fxyz2) 
    call f_free(rcov)
    call f_free(iconnect)
    call f_free(ixyz_int)
    call f_free(rotforce)
    call f_free(hess)
    call f_free(rxyz_rot)
    call f_free(fxyz_rot)
    call f_free(fxyzraw_rot)
    call f_free(rxyzraw_rot)
    call f_free(fstretch_rot)
    call f_free(eval_rot)
    call f_free(res_rot)
    call f_free(rrr_rot)
    call f_free(aa_rot)
    call f_free(ff_rot)
    call f_free(rr_rot)
    call f_free(dd_rot)
    call f_free(fff_rot)
    call f_free(scpr_rot)
    call f_free(rxyz_trans)
    call f_free(fxyz_trans)
    call f_free(fxyzraw_trans)
    call f_free(rxyzraw_trans)
    call f_free(fstretch_trans)
    call f_free(eval_trans)
    call f_free(res_trans)
    call f_free(rrr_trans)
    call f_free(aa_trans)
    call f_free(ff_trans)
    call f_free(rr_trans)
    call f_free(dd_trans)
    call f_free(fff_trans)
    call f_free(scpr_trans)
    call f_free(wold_trans)
    call f_free(wold_rot)
    call deallocate_connect_object(cobj)

    


    if(iproc==0)call yaml_map('(MHGPS) Total calls to energy and '//&
                               'forces',nint(ef_counter))
    if(iproc==0)call yaml_map('(MHGPS) Run finished at',&
                               yaml_date_and_time_toa())
    call f_lib_finalize()
end program
