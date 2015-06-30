!> @file
!! Optimization of the orbitals (linear version)
!! @author
!!    Copyright (C) 2011-2012 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


subroutine optimizeDIIS(iproc, nproc, npsidim, orbs, nspin, lzd, hphi, phi, ldiis, experimental_mode)

  use module_base
  use module_types
  use module_interfaces, exceptThisOne => optimizeDIIS
  implicit none

  ! Calling arguments
  integer,intent(in):: iproc, nproc, nspin
  integer,intent(in):: npsidim
  type(orbitals_data),intent(in):: orbs
  type(local_zone_descriptors),intent(in):: lzd
  real(8),dimension(npsidim),intent(in):: hphi
  real(8),dimension(npsidim),intent(inout):: phi
  type(localizedDIISParameters),intent(inout):: ldiis
  logical,intent(in) :: experimental_mode                       


  ! Local variables
  integer:: iorb, jorb, ist, ilr, ncount, jst, i, j, mi, ist1, ist2, jlr, istat, info
  integer:: mj, jj, k, jjst, isthist, iall, ierr, iiorb, ispin, iispin
  real(8):: ddot
  real(8),dimension(:,:,:),allocatable:: totmat
  real(8),dimension(:,:),allocatable:: mat
  real(8),dimension(:),allocatable:: rhs
  integer,dimension(:),allocatable:: ipiv
  character(len=*),parameter:: subname='optimizeDIIS'

  call f_routine(id='optimizeDIIS')
  call timing(iproc,'optimize_DIIS ','ON')


  !!ist=0
  !!do iorb=1,orbs%norbp
  !!    iiorb=orbs%isorb+iorb
  !!    ilr=orbs%inwhichlocreg(iiorb)
  !!    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
  !!    do i=1,ncount
  !!        ist=ist+1
  !!        if (orbs%spinsgn(iiorb)>0.d0) then
  !!            write(3101,'(a,2i10,f8.1,2es16.7)') 'iiorb, ist, spin, vals', iiorb, ist, orbs%spinsgn(iiorb), phi(ist), hphi(ist)
  !!        else
  !!            write(3102,'(a,2i10,f8.1,2es16.7)') 'iiorb, ist, spin, val', iiorb, ist, orbs%spinsgn(iiorb), phi(ist), hphi(ist)
  !!        end if
  !!    end do
  !!end do


  ! Allocate the local arrays.
  mat = f_malloc((/ ldiis%isx+1, ldiis%isx+1 /),id='mat')
  rhs = f_malloc(ldiis%isx+1,id='rhs')
  !lwork=100*ldiis%isx
  !allocate(work(lwork), stat=istat)
  !call memocc(istat, work, 'work', subname)
  ipiv = f_malloc(ldiis%isx+1,id='ipiv')

  !!mat=0.d0
  !!rhs=0.d0
  call to_zero((ldiis%isx+1)**2, mat(1,1))
  call to_zero(ldiis%isx+1, rhs(1))

  ! Copy phi and hphi to history.
  ist=1
  do iorb=1,orbs%norbp
    jst=1
    do jorb=1,iorb-1
        !jlr=onWhichAtom(jorb)
        jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
        ncount=lzd%llr(jlr)%wfd%nvctr_c+7*lzd%llr(jlr)%wfd%nvctr_f
        jst=jst+ncount*ldiis%isx
    end do
    !ilr=onWhichAtom(iorb)
    ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
    jst=jst+(ldiis%mis-1)*ncount
    call vcopy(ncount, phi(ist), 1, ldiis%phiHist(jst), 1)
    call vcopy(ncount, hphi(ist), 1, ldiis%hphiHist(jst), 1)
    !!if (iproc==0 .and. iorb==1) write(*,*) 'copy to: jst, val', jst, ldiis%phiHist(jst)


    !ilr=onWhichAtom(iorb)
    ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
    ist=ist+ncount
  end do

  do iorb=1,orbs%norbp
    ! Shift the DIIS matrix left up if we reached the maximal history length.
    if(ldiis%is>ldiis%isx) then
       do i=1,ldiis%isx-1
          do j=1,i
             ldiis%mat(j,i,iorb)=ldiis%mat(j+1,i+1,iorb)
             !!write(3100+iproc,*) ldiis%mat(j,i,iorb)
          end do
       end do
    end if
  end do

  do iorb=1,orbs%norbp

    ! Calculate a new line for the matrix.
    i=max(1,ldiis%is-ldiis%isx+1)
    jst=1
    ist1=1
    do jorb=1,iorb-1
        !jlr=onWhichAtom(jorb)
        jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
        ncount=lzd%llr(jlr)%wfd%nvctr_c+7*lzd%llr(jlr)%wfd%nvctr_f
        jst=jst+ncount*ldiis%isx
        ist1=ist1+ncount
    end do
    !ilr=onWhichAtom(iorb)
    ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
    do j=i,ldiis%is
       mi=mod(j-1,ldiis%isx)+1
       ist2=jst+(mi-1)*ncount
       if(ist2>size(ldiis%hphiHist)) then
           write(*,'(a,7i8)') 'ERROR ist2: iproc, iorb, ldiis%is, mi, ncount, ist2, size(ldiis%hphiHist)', iproc, iorb, ldiis%is,&
                               mi, ncount, ist2, size(ldiis%hphiHist)
       end if
       ldiis%mat(j-i+1,min(ldiis%isx,ldiis%is),iorb)=ddot(ncount, hphi(ist1), 1, ldiis%hphiHist(ist2), 1)
       !!write(3000+iproc,*) ldiis%mat(j-i+1,min(ldiis%isx,ldiis%is),iorb)
       !!write(3200+iproc,'(4i8,2es20.12)') mi, ldiis%is, ist1, ist2, hphi(ist1), ldiis%hphiHist(ist2)
       ist2=ist2+ncount
    end do
  end do

  ! Sum up all partial matrices
  totmat = f_malloc0((/ldiis%isx,ldiis%isx,nspin/),id='totmat')

  do ispin=1,nspin
      do iorb=1,orbs%norbp
          iiorb=orbs%isorb+iorb
          if (orbs%spinsgn(iiorb)>0.d0) then
              iispin=1
          else
              iispin=2
          end if
          if (iispin==ispin) then
              totmat(:,:,ispin)=totmat(:,:,ispin)+ldiis%mat(:,:,iorb)
          end if
      end do
  end do

  if (nproc > 1) then
    call mpiallred(totmat(1,1,1), nspin*ldiis%isx**2, mpi_sum, bigdft_mpi%mpi_comm)
  end if


  do ispin=1,nspin
      ist=1
      do iorb=1,orbs%norbp

        iiorb=orbs%isorb+iorb
        if (orbs%spinsgn(iiorb)>0.d0) then
            iispin=1
        else
            iispin=2
        end if
        
        ! Copy the matrix to an auxiliary array and fill with the zeros and ones.
        do i=1,min(ldiis%isx,ldiis%is)
            mat(i,min(ldiis%isx,ldiis%is)+1)=1.d0
            rhs(i)=0.d0
            do j=i,min(ldiis%isx,ldiis%is)
                if (experimental_mode) then
                    !if (iproc==0) write(*,*) 'WARNING: TAKING ONE SINGLE MATRIX!!'
                    mat(i,j)=totmat(i,j,ispin)
                else
                    mat(i,j)=ldiis%mat(i,j,iorb)
                end if
                !if(iproc==0) write(*,'(a,2i8,es14.3)') 'i, j, mat(i,j)', i, j, mat(i,j)
                !!write(*,'(a,3i8,es14.3)') 'proc, i, j, mat(i,j)', iproc, i, j, mat(i,j)
            end do
        end do
        mat(min(ldiis%isx,ldiis%is)+1,min(ldiis%isx,ldiis%is)+1)=0.d0
        rhs(min(ldiis%isx,ldiis%is)+1)=1.d0

        !!if (iorb==1) then
        !!  do i=1,min(ldiis%isx,ldiis%is)
        !!    do j=1,min(ldiis%isx,ldiis%is)
        !!      if (iproc==0) write(*,'(a,2i6,es14.5)') 'i,j,mat(i,j)',i,j,mat(i,j)
        !!    end do
        !!  end do
        !!  write(*,*) '----------------------'
        !!end if

        !make the matrix symmetric (hermitian) to use DGESV (ZGESV) (no work array, more stable)
        do i=1,min(ldiis%isx,ldiis%is)+1
           do j=1,min(ldiis%isx,ldiis%is)+1
              mat(j,i) = mat(i,j)
           end do
        end do
        !!if (iorb==1) then
        !!  do i=1,min(ldiis%isx,ldiis%is)
        !!    do j=1,min(ldiis%isx,ldiis%is)
        !!      if (iproc==0) write(*,'(a,2i6,es14.5)') 'i,j,mat(i,j)',i,j,mat(i,j)
        !!    end do
        !!  end do
        !!end if
        ! solve linear system, supposing it is general. More stable, no need of work array
        if(ldiis%is>1) then
           call dgesv(min(ldiis%isx,ldiis%is)+1,1,mat(1,1),ldiis%isx+1,  & 
                         ipiv(1),rhs(1),ldiis%isx+1,info)
           if (info /= 0) then
              write(*,'(a,i0)') 'ERROR in dgesv (subroutine optimizeDIIS), info=', info
              stop
           end if
        else
           rhs(1)=1.d0
        endif


        ! Solve the linear system
        !!if(ldiis%is>1) then
        !!   call dsysv('u', min(ldiis%isx,ldiis%is)+1, 1, mat, ldiis%isx+1,  & 
        !!        ipiv, rhs(1), ldiis%isx+1, work, lwork, info)
        !!   
        !!   if (info /= 0) then
        !!      write(*,'(a,i0)') 'ERROR in dsysv (subroutine optimizeDIIS), info=', info
        !!      stop
        !!   end if
        !!else
        !!   rhs(1)=1.d0
        !!endif

        ! Make a new guess for the orbital.
        !ilr=onWhichAtom(iorb)
        ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
        ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
        if (iispin==ispin) then
            call to_zero(ncount, phi(ist))
        end if
        isthist=max(1,ldiis%is-ldiis%isx+1)
        jj=0
        jst=0
        do jorb=1,iorb-1
            !jlr=onWhichAtom(jorb)
            jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
            ncount=lzd%llr(jlr)%wfd%nvctr_c+7*lzd%llr(jlr)%wfd%nvctr_f
            jst=jst+ncount*ldiis%isx
        end do
        !!write(2000+iproc,'(a,i8,100es9.2)') 'iproc, rhs',iproc, rhs(1:(ldiis%is-isthist+1))
        do j=isthist,ldiis%is
            jj=jj+1
            mj=mod(j-1,ldiis%isx)+1
            !ilr=onWhichAtom(iorb)
            ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
            ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
            jjst=jst+(mj-1)*ncount
            !!if (iproc==0) write(*,*) 'jj, rhs(jj)', jj, rhs(jj)
            if (iispin==ispin) then
                do k=1,ncount
                    phi(ist+k-1) = phi(ist+k-1) + rhs(jj)*(ldiis%phiHist(jjst+k)-ldiis%hphiHist(jjst+k))
                    !!write(3300+ispin,'(a,3i8,4es14.7)') 'iorb, iiorb, k, phi(ist+k-1), rhs(jj), ldiis%phiHist(jjst+k), ldiis%hphiHist(jjst+k)', &
                    !!    iorb, iiorb, k, phi(ist+k-1), rhs(jj), ldiis%phiHist(jjst+k), ldiis%hphiHist(jjst+k)
                end do
            end if
        end do

        !ilr=onWhichAtom(iorb)
        ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
        ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
        ist=ist+ncount
      end do

  end do

  call f_free(totmat)

  call f_free(mat)
  call f_free(rhs)
  call f_free(ipiv)

  call timing(iproc,'optimize_DIIS ','OF')
  call f_release_routine()

  !!ist=0
  !!do iorb=1,orbs%norbp
  !!    iiorb=orbs%isorb+iorb
  !!    ilr=orbs%inwhichlocreg(iiorb)
  !!    ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
  !!    do i=1,ncount
  !!        ist=ist+1
  !!        if (orbs%spinsgn(iiorb)>0.d0) then
  !!            write(3201,'(a,2i10,f8.1,es16.7)') 'iiorb, ist, spin, val', iiorb, ist, orbs%spinsgn(iiorb), phi(ist)
  !!        else
  !!            write(3202,'(a,2i10,f8.1,es16.7)') 'iiorb, ist, spin, val', iiorb, ist, orbs%spinsgn(iiorb), phi(ist)
  !!        end if
  !!    end do
  !!end do

end subroutine optimizeDIIS


subroutine initializeDIIS(isx, lzd, orbs, ldiis)
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: isx
type(local_zone_descriptors),intent(in):: lzd
type(orbitals_data),intent(in):: orbs
type(localizedDIISParameters),intent(inout):: ldiis

! Local variables
integer:: iorb, ii, istat, ilr
character(len=*),parameter:: subname='initializeDIIS'


ldiis%isx=isx
ldiis%is=0
ldiis%switchSD=.false.
ldiis%trmin=1.d100
ldiis%trold=1.d100
ldiis%DIISHistMin=0
ldiis%DIISHistMax=isx
ldiis%icountSDSatur=0
ldiis%icountSwitch=0
ldiis%icountDIISFailureTot=0
ldiis%icountDIISFailureCons=0

ldiis%mat = f_malloc_ptr((/ldiis%isx,ldiis%isx,orbs%norbp/),id='ldiis%mat')

if (ldiis%isx**2*orbs%norbp>0) call to_zero(ldiis%isx**2*orbs%norbp,ldiis%mat(1,1,1))

ii=0
do iorb=1,orbs%norbp
    ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
    ii=ii+ldiis%isx*(lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f)
end do
ldiis%phiHist = f_malloc_ptr(ii,id='ldiis%phiHist')
ldiis%hphiHist = f_malloc_ptr(ii,id='ldiis%hphiHist')
ldiis%energy_hist = f_malloc_ptr(isx,id='ldiis%energy_hist')

end subroutine initializeDIIS



subroutine deallocateDIIS(ldiis)
use module_base
use module_types
implicit none

! Calling arguments
type(localizedDIISParameters),intent(inout):: ldiis

! Local variables
integer:: istat, iall
character(len=*),parameter:: subname='deallocateDIIS'

call f_free_ptr(ldiis%mat)
call f_free_ptr(ldiis%phiHist)
call f_free_ptr(ldiis%hphiHist)
call f_free_ptr(ldiis%energy_hist)

end subroutine deallocateDIIS




!!!subroutine initializeDIIS_inguess(isx, norbp, matmin, onWhichAtomp, ldiis)
!!!use module_base
!!!use module_types
!!!implicit none
!!!
!!!! Calling arguments
!!!integer,intent(in):: isx, norbp
!!!type(matrixMinimization),intent(in):: matmin
!!!integer,dimension(norbp):: onWhichAtomp
!!!type(localizedDIISParameters),intent(out):: ldiis
!!!
!!!! Local variables
!!!integer:: iorb, ii, istat, ilr
!!!character(len=*),parameter:: subname='initializeDIIS_inguess'
!!!
!!!
!!!ldiis%isx=isx
!!!ldiis%is=0
!!!ldiis%switchSD=.false.
!!!ldiis%trmin=1.d100
!!!ldiis%trold=1.d100
!!!allocate(ldiis%mat(ldiis%isx,ldiis%isx,norbp), stat=istat)
!!!call memocc(istat, ldiis%mat, 'ldiis%mat', subname)
!!!ii=0
!!!do iorb=1,norbp
!!!    ilr=onWhichAtomp(iorb)
!!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!!    !ii=ii+ldiis%isx*(lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f)
!!!    ii=ii+ldiis%isx*matmin%mlr(ilr)%norbinlr
!!!end do
!!!allocate(ldiis%phiHist(ii), stat=istat)
!!!call memocc(istat, ldiis%phiHist, 'ldiis%phiHist', subname)
!!!allocate(ldiis%hphiHist(ii), stat=istat)
!!!call memocc(istat, ldiis%hphiHist, 'ldiis%hphiHist', subname)
!!!
!!!!! Initialize the DIIS parameters 
!!!!icountSDSatur=0
!!!!icountSwitch=0
!!!!icountDIISFailureTot=0
!!!!icountDIISFailureCons=0
!!!!
!!!!! Assign the step size for SD iterations.
!!!!alpha=alphaSDx
!!!!alphaDIIS=alphaDIISx
!!!
!!!
!!!end subroutine initializeDIIS_inguess



!!subroutine optimizeDIIS_inguess(iproc, nproc, norbp, onWhichAtomp, matmin, lgrad, lcoeff, ldiis)
!!use module_base
!!use module_types
!!use module_interfaces, exceptThisOne => optimizeDIIS
!!implicit none
!!
!!! Calling arguments
!!integer,intent(in):: iproc, nproc, norbp
!!integer,dimension(norbp),intent(in):: onWhichAtomp
!!type(matrixMinimization),intent(in):: matmin
!!real(8),dimension(matmin%norbmax,norbp),intent(in):: lgrad
!!real(8),dimension(matmin%norbmax,norbp),intent(inout):: lcoeff
!!type(localizedDIISParameters),intent(inout):: ldiis
!!
!!! Local variables
!!integer:: iorb, jorb, ist, ilr, ncount, jst, i, j, mi, ist1, ist2, jlr, istat, lwork, info
!!integer:: mj, jj, jst2, k, jjst, isthist, ierr, iall
!!real(8):: ddot
!!real(8),dimension(:,:),allocatable:: mat
!!real(8),dimension(:),allocatable:: rhs, work
!!integer,dimension(:),allocatable:: ipiv
!!character(len=*),parameter:: subname='optimizeDIIS'
!!
!!! Allocate the local arrays.
!!allocate(mat(ldiis%isx+1,ldiis%isx+1), stat=istat)
!!call memocc(istat, mat, 'mat', subname)
!!allocate(rhs(ldiis%isx+1), stat=istat)
!!call memocc(istat, rhs, 'rhs', subname)
!!lwork=100*ldiis%isx
!!allocate(work(lwork), stat=istat)
!!call memocc(istat, work, 'work', subname)
!!allocate(ipiv(ldiis%isx+1), stat=istat)
!!call memocc(istat, ipiv, 'ipiv', subname)
!!
!!mat=0.d0
!!rhs=0.d0
!!
!!! Copy phi and hphi to history.
!!!ist=1
!!do iorb=1,norbp
!!    jst=1
!!    do jorb=1,iorb-1
!!        jlr=onWhichAtomp(jorb)
!!        !jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
!!        ncount=matmin%mlr(jlr)%norbinlr
!!        jst=jst+ncount*ldiis%isx
!!    end do
!!    ilr=onWhichAtomp(iorb)
!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!    ncount=matmin%mlr(ilr)%norbinlr
!!    jst=jst+(ldiis%mis-1)*ncount
!!    call vcopy(ncount, lcoeff(1,iorb), 1, ldiis%phiHist(jst), 1)
!!    call vcopy(ncount, lgrad(1,iorb), 1, ldiis%hphiHist(jst), 1)
!!
!!
!!    !ilr=onWhichAtom(iorb)
!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!    !ncount=lzd%llr(ilr)%wfd%nvctr_c+7*lzd%llr(ilr)%wfd%nvctr_f
!!    !ist=ist+ncount
!!end do
!!
!!do iorb=1,norbp
!!    ! Shift the DIIS matrix left up if we reached the maximal history length.
!!    if(ldiis%is>ldiis%isx) then
!!       do i=1,ldiis%isx-1
!!          do j=1,i
!!             ldiis%mat(j,i,iorb)=ldiis%mat(j+1,i+1,iorb)
!!          end do
!!       end do
!!    end if
!!end do
!!
!!
!!
!!do iorb=1,norbp
!!
!!    ! Calculate a new line for the matrix.
!!    i=max(1,ldiis%is-ldiis%isx+1)
!!    jst=1
!!    ist1=1
!!    do jorb=1,iorb-1
!!        jlr=onWhichAtomp(jorb)
!!        !jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
!!        ncount=matmin%mlr(jlr)%norbinlr
!!        jst=jst+ncount*ldiis%isx
!!        ist1=ist1+ncount
!!    end do
!!    ilr=onWhichAtomp(iorb)
!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!    ncount=matmin%mlr(ilr)%norbinlr
!!    do j=i,ldiis%is
!!       mi=mod(j-1,ldiis%isx)+1
!!       ist2=jst+(mi-1)*ncount
!!       if(ist2>size(ldiis%hphiHist)) then
!!           write(*,'(a,7i8)') 'ERROR ist2: iproc, iorb, ldiis%is, mi, ncount, ist2, size(ldiis%hphiHist)', iproc, iorb, ldiis%is,&
!!                               mi, ncount, ist2, size(ldiis%hphiHist)
!!       end if
!!       ldiis%mat(j-i+1,min(ldiis%isx,ldiis%is),iorb)=ddot(ncount, lgrad(1,iorb), 1, ldiis%hphiHist(ist2), 1)
!!       ist2=ist2+ncount
!!    end do
!!end do
!!
!!
!!ist=1
!!do iorb=1,norbp
!!    
!!    ! Copy the matrix to an auxiliary array and fill with the zeros and ones.
!!    do i=1,min(ldiis%isx,ldiis%is)
!!        mat(i,min(ldiis%isx,ldiis%is)+1)=1.d0
!!        rhs(i)=0.d0
!!        do j=i,min(ldiis%isx,ldiis%is)
!!            mat(i,j)=ldiis%mat(i,j,iorb)
!!        end do
!!    end do
!!    mat(min(ldiis%isx,ldiis%is)+1,min(ldiis%isx,ldiis%is)+1)=0.d0
!!    rhs(min(ldiis%isx,ldiis%is)+1)=1.d0
!!
!!
!!    ! Solve the linear system
!!    if(ldiis%is>1) then
!!       call dsysv('u', min(ldiis%isx,ldiis%is)+1, 1, mat, ldiis%isx+1,  & 
!!            ipiv, rhs(1), ldiis%isx+1, work, lwork, info)
!!       
!!       if (info /= 0) then
!!          write(*,'(a,i0)') 'ERROR in dsysv (subroutine optimizeDIIS), info=', info
!!          stop
!!       end if
!!    else
!!       rhs(1)=1.d0
!!    endif
!!
!!
!!    ! Make a new guess for the orbital.
!!    ilr=onWhichAtomp(iorb)
!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!    ncount=matmin%mlr(ilr)%norbinlr
!!    call to_zero(ncount, lcoeff(1,iorb))
!!    isthist=max(1,ldiis%is-ldiis%isx+1)
!!    jj=0
!!    jst=0
!!    do jorb=1,iorb-1
!!        jlr=onWhichAtomp(jorb)
!!        !jlr=orbs%inwhichlocreg(orbs%isorb+jorb)
!!        ncount=matmin%mlr(jlr)%norbinlr
!!        jst=jst+ncount*ldiis%isx
!!    end do
!!    do j=isthist,ldiis%is
!!        jj=jj+1
!!        mj=mod(j-1,ldiis%isx)+1
!!        ilr=onWhichAtomp(iorb)
!!        !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!        ncount=matmin%mlr(ilr)%norbinlr
!!        jjst=jst+(mj-1)*ncount
!!        do k=1,ncount
!!            !phi(ist+k-1) = phi(ist+k-1) + rhs(jj)*(ldiis%phiHist(jjst+k)-ldiis%hphiHist(jjst+k))
!!            lcoeff(k,iorb) = lcoeff(k,iorb) + rhs(jj)*(ldiis%phiHist(jjst+k)-ldiis%hphiHist(jjst+k))
!!        end do
!!    end do
!!
!!
!!    ilr=onWhichAtomp(iorb)
!!    !ilr=orbs%inwhichlocreg(orbs%isorb+iorb)
!!    ncount=matmin%mlr(ilr)%norbinlr
!!    ist=ist+ncount
!!end do
!!
!!
!!iall=-product(shape(mat))*kind(mat)
!!deallocate(mat, stat=istat)
!!call memocc(istat, iall, 'mat', subname)
!!
!!iall=-product(shape(rhs))*kind(rhs)
!!deallocate(rhs, stat=istat)
!!call memocc(istat, iall, 'rhs', subname)
!!
!!iall=-product(shape(work))*kind(work)
!!deallocate(work, stat=istat)
!!call memocc(istat, iall, 'work', subname)
!!
!!iall=-product(shape(ipiv))*kind(ipiv)
!!deallocate(ipiv, stat=istat)
!!call memocc(istat, iall, 'ipiv', subname)
!!
!!
!!
!!end subroutine optimizeDIIS_inguess

