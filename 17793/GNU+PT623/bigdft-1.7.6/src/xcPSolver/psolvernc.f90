!> @file
!!   Routine to calculate the Poisson solver
!!  @todo Should be remove from src/xcPSolver
!!
!! @copyright
!!    Copyright (C) 2008-2013 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!>    Calculate the Poisson equation @f$\nabla^2 V(x,y,z)=-4 \pi \rho(x,y,z)@f$
!!    from a given @f$\rho@f$, for different boundary conditions an for different data distributions.
!!    Following the boundary conditions, it applies the Poisson Kernel previously calculated.
!! @warning
!!    The dimensions of the arrays must be compatible with geocode, datacode, nproc, 
!!    ixc and iproc. Since the arguments of these routines are indicated with the *, it
!!    is IMPERATIVE to use the PS_dim4allocation routine for calculation arrays sizes.
!!    Moreover, for the cases with the exchange and correlation the density must be initialised
!!    to 10^-20 and not to zero.
!! @author Luigi Genovese
!! @date   February 2007
subroutine PSolver(geocode,datacode,iproc,nproc,n01,n02,n03,xc,hx,hy,hz,&
     rhopot,karray,pot_ion,eh,exc,vxc,offset,sumpion,nspin)!,&
!     alpha,beta,gamma,quiet) !optional argument
  use module_base
  use module_types
  use module_xc
  use yaml_output
  use Poisson_Solver, except_dp => dp, except_gp => gp, except_wp => wp
  implicit none
  !Arguments
  character(len=1), intent(in) :: geocode  !< @copydoc poisson_solver::doc::geocode
  character(len=1), intent(in) :: datacode !< @copydoc poisson_solver::doc::datacode
  logical, intent(in) :: sumpion           !< Logical value which states whether to sum pot_ion to the final result or not
                                           !!  if .true. rhopot will be the Hartree potential + pot_ion+vxci
                                           !!            pot_ion will be untouched
                                           !!  if .false. rhopot will be only the Hartree potential
                                           !!            pot_ion will be the XC potential vxci
                                           !!  this value is ignored when ixc=0. In that case pot_ion is untouched
  integer, intent(in) :: iproc             !< Label of the process,from 0 to nproc-1
  integer, intent(in) :: nproc             !< Number of processors
  integer, intent(in) :: n01,n02,n03       !< Global dimension in the three directions. They are the same no matter if the 
                                           !! datacode is in 'G' or in 'D' position.
  type(xc_info), intent(in) :: xc               !< eXchange-Correlation code. Indicates the XC functional to be used 
                                           !! for calculating XC energies and potential. 
                                           !! ixc=0 indicates that no XC terms are computed. The XC functional codes follow
                                           !! the ABINIT convention.
  integer, intent(in) :: nspin             !< Value of the spin-polarisation
  real(gp), intent(in) :: hx,hy,hz         !< Grid spacings. For the isolated BC case for the moment they are supposed to 
                                           !! be equal in the three directions
  real(dp), intent(in) :: offset           !< Value of the potential at the point 1,1,1 of the grid.
                                           !! To be used only in the periodic case, ignored for other boundary conditions.
  real(dp), dimension(*), intent(in) :: karray !< Kernel of the poisson equation. It is provided in distributed case, with
                                           !! dimensions that are related to the output of the PS_dim4allocation routine
                                           !! it MUST be created by following the same geocode as the Poisson Solver.
  real(gp), intent(out) :: eh,exc,vxc      !< Hartree energy, XC energy and integral of @f$\rho V_{xc}@f$ respectively
  real(dp), dimension(*), intent(inout) :: rhopot !< Main input/output array.
                                           !! On input, it represents the density values on the grid points
                                           !! On output, it is the Hartree potential, namely the solution of the Poisson 
                                           !! equation PLUS (when ixc/=0 sumpion=.true.) the XC potential 
                                           !! PLUS (again for ixc/=0 and sumpion=.true.) the pot_ion array. 
                                           !! The output is non overlapping, in the sense that it does not
                                           !! consider the points that are related to gradient and WB calculation
  real(wp), dimension(*), intent(inout) :: pot_ion !< Additional external potential that is added to the output, 
                                           !! when the XC parameter ixc/=0 and sumpion=.true., otherwise it corresponds 
                                           !! to the XC potential Vxc.
                                           !! When sumpion=.true., it is always provided in the distributed form,
                                           !! clearly without the overlapping terms which are needed only for the XC part
                                           !! When sumpion=.false. it is the XC potential and therefore it has 
                                           !! the same distribution of the data as the potential
                                           !! Ignored when ixc=0.
!  character(len=3), intent(in), optional :: quiet
!  !triclinic lattice
!  real(dp), intent(in), optional :: alpha,beta,gamma
  !local variables
  character(len=*), parameter :: subname='PSolver'
  logical :: wrtmsg
  !n(c) integer, parameter :: nordgr=4 !the order of the finite-difference gradient (fixed)
  integer :: m1,m2,m3,md1,md2,md3,n1,n2,n3,nd1,nd2,nd3,i3s_fake,i3xcsh_fake
  integer :: ierr,ind,ind2,ind3,ind4,ind4sh,i,j
  integer :: i1,i2,i3,j2,istart,iend,i3start,jend,jproc,i3xcsh,is_step,ind2nd
  integer :: nxc,nwbl,nwbr,nxt,nwb,nxcl,nxcr,nlim,ispin,istden,istglo
  real(dp) :: scal,ehartreeLOC,eexcuLOC,vexcuLOC,pot,alphat,betat,gammat
  real(dp), dimension(6) :: strten
  real(wp), dimension(:,:,:,:), allocatable :: zfionxc
  real(dp), dimension(:,:,:), allocatable :: zf
  integer, dimension(:,:), allocatable :: gather_arr
  real(dp), dimension(:), allocatable :: rhopot_G
  real(gp), dimension(:), allocatable :: energies_mpi
  real(dp) :: detg

  call f_timing(TCAT_EXCHANGECORR,'ON')
  !call timing(iproc,'Exchangecorr  ','ON')

!!$  if (present(quiet)) then
!!$     if(quiet == 'yes' .or. quiet == 'YES') then
!!$        wrtmsg=.false.
!!$     else if(trim(quiet) == 'no' .or. trim(quiet) == 'NO') then
!!$        wrtmsg=.true.
!!$     else
!!$        call yaml_warning('ERROR: Unrecognised value for "quiet" option: ' // trim(quiet))
!!$        !write(*,*)'ERROR: Unrecognised value for "quiet" option:',quiet
!!$        stop
!!$     end if
!!$  else
     wrtmsg=.true.
!!$  end if

!!$  if (present(alpha) .and. present(beta) .and. present(gamma)) then
!!$     alphat = alpha
!!$     betat = beta
!!$     gammat = gamma
!!$  else
     alphat = 2.0_dp*datan(1.0_dp)
     betat = 2.0_dp*datan(1.0_dp)
     gammat = 2.0_dp*datan(1.0_dp)
!!$  end if


 
  detg = 1.0_dp - dcos(alphat)**2 - dcos(betat)**2 - dcos(gammat)**2 + 2.0_dp*dcos(alphat)*dcos(betat)*dcos(gammat)

  
  !calculate the dimensions wrt the geocode
  if (geocode == 'P') then
     if (iproc==0 .and. wrtmsg) call PSolver_yaml('periodic BC',n01,n02,n03,nproc,xc%ixc)
          !write(*,'(1x,a,3(i5),a,i5,a,i7,a)',advance='no')&
          !'PSolver, periodic BC, dimensions: ',n01,n02,n03,'   proc',nproc,'  ixc:',ixc,' ... '
     call P_FFT_dimensions(n01,n02,n03,m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,nproc,.false.)
  else if (geocode == 'S') then
     if (iproc==0 .and. wrtmsg) call PSolver_yaml('surfaces BC',n01,n02,n03,nproc,xc%ixc)
          !write(*,'(1x,a,3(i5),a,i5,a,i7,a)',advance='no')&
          !'PSolver, surfaces BC, dimensions: ',n01,n02,n03,'   proc',nproc,'  ixc:',ixc,' ... '
     call S_FFT_dimensions(n01,n02,n03,m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,nproc,0,.false.)
  else if (geocode == 'F') then
     if (iproc==0 .and. wrtmsg) call PSolver_yaml('free BC',n01,n02,n03,nproc,xc%ixc)
          !write(*,'(1x,a,3(i5),a,i5,a,i7,a)',advance='no')&
          !'PSolver, free  BC, dimensions: ',n01,n02,n03,'   proc',nproc,'  ixc:',ixc,' ... '
     call F_FFT_dimensions(n01,n02,n03,m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,nproc,0,.false.)
  else if (geocode == 'W') then
     if (iproc==0 .and. wrtmsg) call PSolver_yaml('wires BC',n01,n02,n03,nproc,xc%ixc)
          !write(*,'(1x,a,3(i5),a,i5,a,i7,a)',advance='no')&
          !'PSolver, wires  BC, dimensions: ',n01,n02,n03,'   proc',nproc,'  ixc:',ixc,' ... '
     call W_FFT_dimensions(n01,n02,n03,m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,nproc,0,.false.)
  else if (geocode == 'H') then
     if (iproc==0 .and. wrtmsg) call PSolver_yaml('Helmholtz Equation Solver',n01,n02,n03,nproc,xc%ixc)
          !write(*,'(1x,a,3(i5),a,i5,a,i7,a)',advance='no')&
          !'PSolver, Helmholtz Equation Solver, dimensions: ',n01,n02,n03,'   proc',nproc,'  ixc:',ixc,' ... '
     call F_FFT_dimensions(n01,n02,n03,m1,m2,m3,n1,n2,n3,md1,md2,md3,nd1,nd2,nd3,nproc,0,.false.)
  else
     stop 'PSolver: geometry code not admitted'
  end if

  !array allocations
  zf = f_malloc((/ md1, md3, md2/nproc /),id='zf')
  zfionxc = f_malloc((/ md1, md3, md2/nproc, nspin /),id='zfionxc')

  !dimension for exchange-correlation (different in the global or distributed case)
  !let us calculate the dimension of the portion of the rhopot array to be passed 
  !to the xc routine
  !this portion will depend on the need of calculating the gradient or not, 
  !and whether the White-Bird correction must be inserted or not 
  !(absent only in the LB ixc=13 case)
  
  !nxc is the effective part of the third dimension that is being processed
  !nxt is the dimension of the part of rhopot that must be passed to the gradient routine
  !nwb is the dimension of the part of rhopot in the wb-postprocessing routine
  !note: nxc <= nwb <= nxt
  !the dimension are related by the values of nwbl and nwbr
  !      nxc+nxcl+nxcr-2 = nwb
  !      nwb+nwbl+nwbr = nxt
  istart=iproc*(md2/nproc)
  iend=min((iproc+1)*md2/nproc,m2)

  call xc_dimensions(geocode,xc_isgga(xc),(xc%ixc/=13),istart,iend,m2,nxc,nxcl,nxcr,nwbl,nwbr,i3s_fake,i3xcsh_fake)
  nwb=nxcl+nxc+nxcr-2
  nxt=nwbr+nwb+nwbl

  if (datacode=='G') then
     !starting address of rhopot in the case of global i/o
     i3start=istart+2-nxcl-nwbl
     if((nspin==2 .and. nproc>1) .or. i3start <=0 .or. i3start+nxt-1 > n03 ) then
        !allocation of an auxiliary array for avoiding the shift of the density
        rhopot_G = f_malloc(m1*m3*nxt*2,id='rhopot_G')
        !here we should put the modulo of the results for the non-isolated GGA
        do ispin=1,nspin
           do i3=1,nxt
              do i2=1,m3
                 do i1=1,m1
                    i=i1+(i2-1)*m1+(i3-1)*m1*m3+(ispin-1)*m1*m3*nxt
                    j=i1+(i2-1)*n01+(modulo(i3start+i3-2,n03))*n01*n02+(ispin-1)*n01*n02*n03
                    rhopot_G(i)=rhopot(j)
                 end do
              end do
           end do
        end do
     end if
  else if (datacode == 'D') then
     !distributed i/o
     i3start=1
  else
     stop 'PSolver: datacode not admitted'
  end if

  !calculate the actual limit of the array for the zero padded FFT
  if (geocode == 'P' .or. geocode == 'W') then
     nlim=n2
  else if (geocode == 'S') then
     nlim=n2
  else if (geocode == 'F' .or. geocode == 'H') then
     nlim=n2/2
  end if

!!  print *,'density must go from',min(istart+1,m2),'to',iend,'with n2/2=',n2/2
!!  print *,'        it goes from',i3start+nwbl+nxcl-1,'to',i3start+nxc-1

  if (istart+1 <= m2) then 
     if(datacode=='G' .and. &
          ((nspin==2 .and. nproc > 1) .or. i3start <=0 .or. i3start+nxt-1 > n03 )) then
        !allocation of an auxiliary array for avoiding the shift 
        call xc_energy(geocode,m1,m3,md1,md2,md3,nxc,nwb,nxt,nwbl,nwbr,nxcl,nxcr,&
             xc%ixc,hx,hy,hz,rhopot_G,pot_ion,sumpion,zf,zfionxc,&
             eexcuLOC,vexcuLOC,nproc,nspin)
        do ispin=1,nspin
           do i3=1,nxt
              do i2=1,m3
                 do i1=1,m1
                    i=i1+(i2-1)*m1+(i3-1)*m1*m3+(ispin-1)*m1*m3*nxt
                    j=i1+(i2-1)*n01+(modulo(i3start+i3-2,n03))*n01*n02+(ispin-1)*n01*n02*n03
                    rhopot(j)=rhopot_G(i)
                 end do
              end do
           end do
        end do
        !!          do i1=1,m1*m3*nxt
        !!             rhopot(n01*n02*(i3start-1)+i1)=rhopot_G(i1)
        !!          end do
        !!          do i1=1,m1*m3*nxt
        !!             rhopot(n01*n02*(i3start-1)+i1+n01*n02*n03)=rhopot_G(i1+m1*m3*nxt)
        !!          end do
        call f_free(rhopot_G)
     else
        call xc_energy(geocode,m1,m3,md1,md2,md3,nxc,nwb,nxt,nwbl,nwbr,nxcl,nxcr,&
             xc%ixc,hx,hy,hz,rhopot(1+n01*n02*(i3start-1)),pot_ion,sumpion,zf,zfionxc,&
             eexcuLOC,vexcuLOC,nproc,nspin)
     end if
  else if (istart+1 <= nlim) then !this condition ensures we have performed good zero padding
     do i2=istart+1,min(nlim,istart+md2/nproc)
        j2=i2-istart
        do i3=1,md3
           do i1=1,md1
              zf(i1,i3,j2)=0.0_dp
           end do
        end do
     end do
     eexcuLOC=0.0_dp
     vexcuLOC=0.0_dp
  else
     eexcuLOC=0.0_dp
     vexcuLOC=0.0_dp
  end if

  !this routine builds the values for each process of the potential (zf), multiplying by scal 
  if(geocode == 'P') then
     !no powers of hgrid because they are incorporated in the plane wave treatment
     scal=1.0_dp/real(n1*n2*n3,dp)
     !call P_PoissonSolver(n1,n2,n3,nd1,nd2,nd3,md1,md2,md3,nproc,iproc,karray,zf(1,1,1),&
     !     scal,hx,hy,hz,offset)
  else if (geocode == 'S') then
     !only one power of hgrid 
     !factor of -4*pi for the definition of the Poisson equation
     scal=-16.0_dp*atan(1.0_dp)*real(hy,dp)/real(n1*n2*n3,dp)
     !call S_PoissonSolver(n1,n2,n3,nd1,nd2,nd3,md1,md2,md3,nproc,iproc,karray,zf(1,1,1),&
     !     scal) !,hx,hy,hz,ehartreeLOC)
  else if (geocode == 'F' .or. geocode == 'H') then
     !hgrid=max(hx,hy,hz)
     scal=hx*hy*hz/real(n1*n2*n3,dp)
     !call F_PoissonSolver(n1,n2,n3,nd1,nd2,nd3,md1,md2,md3,nproc,iproc,karray,zf(1,1,1),&
     !     scal)!,hgrid)!,ehartreeLOC)
  else if (geocode == 'W') then
     !only one power of hgrid 
     !factor of -1/(2pi) already included in the kernel definition
     scal=-2.0_dp*hx*hy/real(n1*n2*n3,dp)
  end if
  !here the case ncplx/= 1 should be added
  call G_PoissonSolver(iproc,nproc,bigdft_mpi%mpi_comm,0,MPI_COMM_NULL,geocode,1,n1,n2,n3,nd1,nd2,nd3,md1,md2,md3,karray,zf(1,1,1),&
       scal,hx,hy,hz,offset,strten)
    
  !the value of the shift depends on the distributed i/o or not
  if (datacode=='G') then
     i3xcsh=istart !beware on the fact that this is not what represents its name!!!
     is_step=n01*n02*n03
  else if (datacode=='D') then
     i3xcsh=nxcl+nwbl-1
     is_step=m1*m3*nxt
  end if
 
  !if (iproc == 0) print *,'n03,nxt,nxc,geocode,datacode',n03,nxt,nxc,geocode,datacode

  ehartreeLOC=0.0_dp
  !recollect the final data
  if (xc%ixc==0) then !without XC the spin does not exist
     do j2=1,nxc
        i2=j2+i3xcsh !in this case the shift is always zero for a parallel run
        ind3=(i2-1)*n01*n02
        do i3=1,m3
           ind2=(i3-1)*n01+ind3
           do i1=1,m1
              ind=i1+ind2
              pot=zf(i1,i3,j2)
              ehartreeLOC=ehartreeLOC+rhopot(ind)*pot
              rhopot(ind)=real(pot,wp)
           end do
        end do
     end do
  else if (sumpion) then
     do j2=1,nxc
        i2=j2+i3xcsh
        ind3=(i2-1)*n01*n02
        do i3=1,m3
           ind2=(i3-1)*n01+ind3
           do i1=1,m1
              ind=i1+ind2
              pot=zf(i1,i3,j2)
              ehartreeLOC=ehartreeLOC+rhopot(ind)*pot
              rhopot(ind)=real(pot,wp)+real(zfionxc(i1,i3,j2,1),wp)
           end do
        end do
     end do
     !in the spin-polarised case the potential is given contiguously
     if (nspin==2) then
        !this start the count in the other component of the global array
        if (datacode=='G') ind=i3xcsh*n01*n02+n01*n02*n03
        do j2=1,nxc
           i2=j2+i3xcsh
           ind3=(i2-1)*n01*n02
           do i3=1,m3
              ind2=(i3-1)*n01+ind3
              do i1=1,m1
                 ind2nd=i1+ind2+is_step
                 ind=ind+1
                 pot=zf(i1,i3,j2)
                 ehartreeLOC=ehartreeLOC+rhopot(ind2nd)*pot
                 rhopot(ind)=real(pot,wp)+real(zfionxc(i1,i3,j2,2),wp)
              end do
           end do
        end do
     end if
  else
     if (datacode == 'G') then
        ind4sh=n01*n02*i3xcsh
     else
        ind4sh=0
     end if
     do j2=1,nxc
        i2=j2+i3xcsh
        ind3=(i2-1)*n01*n02
        do i3=1,m3
           ind2=(i3-1)*n01+ind3
           do i1=1,m1
              ind=i1+(i3-1)*n01+(i2-1)*n01*n02
              ind4=i1+(i3-1)*n01+(j2-1)*n01*n02+ind4sh
              pot=zf(i1,i3,j2)
              ehartreeLOC=ehartreeLOC+rhopot(ind)*pot
              rhopot(ind)=real(pot,wp)
              pot_ion(ind4)=zfionxc(i1,i3,j2,1)
           end do
        end do
     end do
     !in the spin-polarised (distributed) case the potential is given contiguously
     if (nspin==2) then
        if (datacode == 'D') ind4sh=-n01*n02*(nxt-nxc)
        do j2=1,nxc
           i2=j2+i3xcsh
           ind3=(i2-1)*n01*n02
           do i3=1,m3
              ind2=(i3-1)*n01+ind3
              do i1=1,m1
                 ind=i1+(i3-1)*n01+(i2-1)*n01*n02+is_step
                 ind4=i1+(i3-1)*n01+(j2-1)*n01*n02+is_step+ind4sh
                 pot=zf(i1,i3,j2)
                 ehartreeLOC=ehartreeLOC+rhopot(ind)*pot
                 pot_ion(ind4)=zfionxc(i1,i3,j2,2)
              end do
           end do
        end do
     end if
  end if
  ehartreeLOC=ehartreeLOC*0.5_dp*hx*hy*hz

  call f_free(zf)
  call f_free(zfionxc)

  !gathering the data to obtain the distribution array
  !evaluating the total ehartree,eexcu,vexcu
  if (nproc > 1) then

     !this part should be passed to mpi wrapper
     energies_mpi = f_malloc(6,id='energies_mpi')

     energies_mpi(1)=ehartreeLOC
     energies_mpi(2)=eexcuLOC
     energies_mpi(3)=vexcuLOC
     call MPI_ALLREDUCE(energies_mpi(1),energies_mpi(4),3,mpidtypd,MPI_SUM,bigdft_mpi%mpi_comm,ierr)
     eh=energies_mpi(4)
     exc=energies_mpi(5)
     vxc=energies_mpi(6)

     call f_free(energies_mpi)

     if (datacode == 'G') then
        !building the array of the data to be sent from each process
        !and the array of the displacement

        gather_arr = f_malloc((/ 0.to.nproc-1, 1.to.2 /),id='gather_arr')
        do jproc=0,nproc-1
           istart=min(jproc*(md2/nproc),m2-1)
           jend=max(min(md2/nproc,m2-md2/nproc*jproc),0)
           gather_arr(jproc,1)=m1*m3*jend
           gather_arr(jproc,2)=m1*m3*istart
        end do

        !gather all the results in the same rhopot array
        istart=min(iproc*(md2/nproc),m2-1)

        istden=1+n01*n02*istart
        istglo=1
        do ispin=1,nspin
           if (ispin==2) then
              istden=istden+n01*n02*n03
              istglo=istglo+n01*n02*n03
           end if
!!$           call MPI_ALLGATHERV(rhopot(istden),gather_arr(iproc,1),mpidtypw,&
!!$                rhopot(istglo),gather_arr(0,1),gather_arr(0,2),mpidtypw,&
!!$                bigdft_mpi%mpi_comm,ierr)
           call MPI_ALLGATHERV(MPI_IN_PLACE,gather_arr(iproc,1),mpidtypw,&
                rhopot(istglo),gather_arr(0,1),gather_arr(0,2),mpidtypw,&
                bigdft_mpi%mpi_comm,ierr)

           !if it is the case gather also the results of the XC potential
           if (xc%ixc /=0 .and. .not. sumpion) then
!!$              call MPI_ALLGATHERV(pot_ion(istden),gather_arr(iproc,1),&
!!$                   mpidtypw,pot_ion(istglo),gather_arr(0,1),gather_arr(0,2),&
!!$                   mpidtypw,bigdft_mpi%mpi_comm,ierr)
              call MPI_ALLGATHERV(MPI_IN_PLACE,gather_arr(iproc,1),&
                   mpidtypw,pot_ion(istglo),gather_arr(0,1),gather_arr(0,2),&
                   mpidtypw,bigdft_mpi%mpi_comm,ierr)

           end if
        end do

        call f_free(gather_arr)

     end if

  else
     eh=real(ehartreeLOC,gp)
     exc=real(eexcuLOC,gp)
     vxc=real(vexcuLOC,gp)
  end if

  if(nspin==1 .and. xc%ixc /= 0) eh=eh*2.0_gp
  !if (iproc==0  .and. wrtmsg) write(*,'(a)')'done.'
  !call timing(iproc,'Exchangecorr  ','OF')
  call f_timing(TCAT_EXCHANGECORR,'OF')
contains

  subroutine PSolver_yaml(code,n01,n02,n03,nproc,ixc)
     use yaml_output
     implicit none
     integer, intent(in) :: n01,n02,n03,nproc,ixc
     character(len=*), intent(in) :: code
     call yaml_mapping_open('PSolver',flow=.true.)
        call yaml_map('Geometry',trim(code))
        call yaml_map('dim',(/ n01,n02,n03 /))
        call yaml_map('proc',nproc)
        call yaml_map('ixc',ixc)
     call yaml_mapping_close()
  end subroutine PSolver_yaml

END SUBROUTINE PSolver



!> Transforms a generalized spin density into a pointwise collinear spin density which is
!! then passed to the Poisson Solver (PSolver). 
!! @warning
!!    The dimensions of the arrays must be compatible with geocode, datacode, nproc, 
!!    ixc and iproc. Since the arguments of these routines are indicated with the *, it
!!    is IMPERATIVE to use the PS_dim4allocation routine for calculation arrays sizes.
!!    Moreover, for the cases with the exchange and correlation the density must be initialised
!!    to 10^-20 and not to zero.
!! @author Anders Bergman
!! @date   March 2008
subroutine PSolverNC(geocode,datacode,iproc,nproc,n01,n02,n03,n3d,xc,hx,hy,hz,&
     rhopot,karray,pot_ion,eh,exc,vxc,offset,sumpion,nspin)
  use module_base
  use module_xc
  use Poisson_Solver, except_dp => dp, except_gp => gp, except_wp => wp
  use dictionaries, only: f_err_raise
  use dynamic_memory
  implicit none
  !Arguments
  character(len=1), intent(in) :: geocode  !< @copydoc poisson_solver::doc::geocode
  character(len=1), intent(in) :: datacode !< @copydoc poisson_solver::doc::datacode
  logical, intent(in) :: sumpion           !< Logical value which states whether to sum pot_ion to the final result or not
                                           !!  if .true. rhopot will be the Hartree potential + pot_ion+vxci
                                           !!            pot_ion will be untouched
                                           !!  if .false. rhopot will be only the Hartree potential
                                           !!            pot_ion will be the XC potential vxci
                                           !!  this value is ignored when ixc=0. In that case pot_ion is untouched
  integer, intent(in) :: iproc             !< Label of the process,from 0 to nproc-1
  integer, intent(in) :: nproc             !< Number of processors
  integer, intent(in) :: n01,n02,n03       !< Global dimension in the three directions. They are the same no matter if the 
                                           !! datacode is in 'G' or in 'D' position.
  integer, intent(in) :: n3d               !< Third dimension of the density. For distributed data, it takes into account
                                           !! When there are too many processes and there is no room for the density n3d=0.
  type(xc_info), intent(in) :: xc               !< eXchange-Correlation code. Indicates the XC functional to be used 
                                           !! for calculating XC energies and potential. 
                                           !! ixc=0 indicates that no XC terms are computed. The XC functional codes follow
                                           !! the ABINIT convention.
  integer, intent(in) :: nspin             !< Value of the spin-polarisation
  real(gp), intent(in) :: hx,hy,hz         !< Grid spacings. For the isolated BC case for the moment they are supposed to 
                                           !! be equal in the three directions
  real(dp), intent(in) :: offset           !< Value of the potential at the point 1,1,1 of the grid.
                                           !! To be used only in the periodic case, ignored for other boundary conditions.
  real(dp), dimension(*), intent(in) :: karray !< Kernel of the poisson equation. It is provided in distributed case, with
                                           !! dimensions that are related to the output of the PS_dim4allocation routine
                                           !! it MUST be created by following the same geocode as the Poisson Solver.
  real(gp), intent(out) :: eh,exc,vxc      !< Hartree energy, XC energy and integral of @f$\rho V_{xc}@f$ respectively
  real(dp), dimension(*), intent(inout) :: rhopot !< Main input/output array.
                                           !! On input, it represents the density values on the grid points
                                           !! On output, it is the Hartree potential, namely the solution of the Poisson 
                                           !! equation PLUS (when ixc/=0 sumpion=.true.) the XC potential 
                                           !! PLUS (again for ixc/=0 and sumpion=.true.) the pot_ion array. 
                                           !! The output is non overlapping, in the sense that it does not
                                           !! consider the points that are related to gradient and WB calculation
  real(wp), dimension(*), intent(inout) :: pot_ion !< Additional external potential that is added to the output, 
                                           !! when the XC parameter ixc/=0 and sumpion=.true., otherwise it corresponds 
                                           !! to the XC potential Vxc.
                                           !! When sumpion=.true., it is always provided in the distributed form,
                                           !! clearly without the overlapping terms which are needed only for the XC part
                                           !! When sumpion=.false. it is the XC potential and therefore it has 
                                           !! the same distribution of the data as the potential
                                           !! Ignored when ixc=0.
  !local variables
  character(len=*), parameter :: subname='PSolverNC'
  real(dp) :: rhon,rhos,factor
  integer :: i1,i2,i3,idx,offs
  real(dp), dimension(:,:,:), allocatable :: m_norm
  real(dp), dimension(:,:,:,:), allocatable :: rho_diag

!!$  interface
!!$     subroutine PSolver(geocode,datacode,iproc,nproc,n01,n02,n03,ixc,hx,hy,hz,&
!!$          rhopot,karray,pot_ion,eh,exc,vxc,offset,sumpion,nspin,&
!!$          alpha,beta,gamma,quiet) !optional argument
!!$       use module_base
!!$       use module_types
!!$       implicit none
!!$       character(len=1), intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode
!!$       character(len=1), intent(in) :: datacode !< @copydoc poisson_solver::doc::datacode
!!$       logical, intent(in) :: sumpion
!!$       integer, intent(in) :: iproc,nproc,n01,n02,n03,ixc,nspin
!!$       real(gp), intent(in) :: hx,hy,hz
!!$       real(dp), intent(in) :: offset
!!$       real(dp), dimension(*), intent(in) :: karray
!!$       real(gp), intent(out) :: eh,exc,vxc
!!$       real(dp), dimension(*), intent(inout) :: rhopot
!!$       real(wp), dimension(*), intent(inout) :: pot_ion
!!$       character(len=3), intent(in), optional :: quiet
!!$       !triclinic lattice
!!$       real(dp), intent(in), optional :: alpha,beta,gamma
!!$     end subroutine PSolver
!!$  end interface

  call f_routine(id='PSolverNC')

  !only for nspin==4
  !if(nspin==4) then
  if (f_err_raise(nspin/=4,'Noncollinear Poisson Solver can only be called with nspin=4')) then
     return
  else
     !Allocate diagonal spin-density in real space
     if (n3d >0) then
        rho_diag = f_malloc((/ n01, n02, n3d, 2 /),id='rho_diag')
        m_norm = f_malloc((/ n01, n02, n3d /),id='m_norm')
        !           print *,'Rho Dims',shape(rhopot),shape(rho_diag)
        idx=1
        offs=n01*n02*n3d 
        do i3=1,n3d
           do i2=1,n02
              do i1=1,n01
                 !rho_diag(i1,i2,i3,1)=rhopot(i1,i2,i3,1)
                 m_norm(i1,i2,i3)=&
                      sqrt(rhopot(idx+offs)**2+rhopot(idx+2*offs)**2+rhopot(idx+3*offs)**2)
                 rho_diag(i1,i2,i3,1)=(rhopot(idx)+m_norm(i1,i2,i3))*0.5_dp+1.00e-20
                 rho_diag(i1,i2,i3,2)=(rhopot(idx)-m_norm(i1,i2,i3))*0.5_dp+1.00e-20
                 idx=idx+1
                 !m_norm(i1,i2,i3)=sqrt(rhopot(i1,i2,i3,2)**2+rhopot(i1,i2,i3,3)**2+rhopot(i1,i2,i3,4)**2)
                 !rho_diag(i1,i2,i3,1)=(rhopot(i1,i2,i3,1)+m_norm(i1,i2,i3))*0.5d0!+1.00e-20
                 !rho_diag(i1,i2,i3,2)=(rhopot(i1,i2,i3,1)-m_norm(i1,i2,i3))*0.5d0!+1.00e-20
              end do
           end do
        end do
     else
        rho_diag = f_malloc((/ 1, 1, 1, 2 /),id='rho_diag')
        m_norm = f_malloc((/ 1, 1, 1 /),id='m_norm')
        rho_diag=0.0_dp
        m_norm=0.0_dp
     end if
     !print *,'ciao',iproc     
     !substitution of the calling routine
     
     call PSolver(geocode,datacode,iproc,nproc,n01,n02,n03,xc,hx,hy,hz,&
          rho_diag,karray,pot_ion,eh,exc,vxc,offset,sumpion,2)
     !print *,'Psolver R',eh,exc,vxc
     !open(17)
     idx=1
     do i3=1,n3d
        do i2=1,n02
           do i1=1,n01
              rhon=(rho_diag(i1,i2,i3,1)+rho_diag(i1,i2,i3,2))*0.5_dp
              rhos=(rho_diag(i1,i2,i3,1)-rho_diag(i1,i2,i3,2))*0.5_dp
              if(m_norm(i1,i2,i3)>rhopot(idx)*4.0e-20_dp)then
                 !                 if(m_norm(i1,i2,i3)>rhopot(i1,i2,i3,1)*4.0e-20)then
                 factor=rhos/m_norm(i1,i2,i3)
              else
                 factor=0.0_dp
              end if
              !write(17,'(3(i0,1x),5(1pe12.5))')i1,i2,i3,rhon,rhos,rho_diag(i1,i2,i3,1),rho_diag(i1,i2,i3,2),factor
              rhopot(idx)=rhon+rhopot(idx+3*offs)*factor
              rhopot(idx+offs)=rhopot(idx+offs)*factor
              rhopot(idx+2*offs)=-rhopot(idx+2*offs)*factor
              rhopot(idx+3*offs)=rhon-rhopot(idx+3*offs)*factor
              idx=idx+1
              !                 rhopot(i1,i2,i3,1)=rhon+rhopot(i1,i2,i3,4)*factor
              !                 rhopot(i1,i2,i3,2)=rhopot(i1,i2,i3,2)*factor
              !                 rhopot(i1,i2,i3,3)=-rhopot(i1,i2,i3,3)*factor
              !                 rhopot(i1,i2,i3,4)=rhon-rhopot(i1,i2,i3,4)*factor
           end do
        end do
     end do
     !close(17)
     call f_free(rho_diag)
     call f_free(m_norm)
!!$  else
!!$     call PSolver(geocode,datacode,iproc,nproc,n01,n02,n03,ixc,hx,hy,hz,&
!!$          rhopot,karray,pot_ion,eh,exc,vxc,offset,sumpion,nspin)
  end if

  call f_release_routine()

END SUBROUTINE PSolverNC
