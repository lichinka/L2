!! @file
!! @author Stefan Goedecker and Bastian Schaefer
!! @section LICENCE
!!    Copyright (C) 2014 UNIBAS
!!    This file is not freely distributed.
!!    A licence is necessary from UNIBAS

module module_sbfgs
    implicit none
    private

    public :: modify_gradient
    public :: getSubSpaceEvecEval
    public :: findbonds
    public :: projectbond

contains

subroutine modify_gradient(nat,ndim,rrr,eval,res,fxyz,alpha,dd)
    use module_base
    implicit none
    !parameters
    integer, intent(in) :: nat
    integer, intent(in) :: ndim
    real(gp), intent(out) :: dd(3,nat)
    real(gp), intent(in) :: fxyz(3,nat)
    real(gp), intent(in) :: rrr(3,nat,ndim)
    real(gp), intent(in) :: eval(ndim)
    real(gp), intent(in) :: res(ndim)
    real(gp), intent(in) :: alpha
    !internal
    integer :: iat,i,l
    real(gp) :: scpr(ndim)
    real(gp) :: tt

    ! decompose gradient

    do iat=1,nat
        do l=1,3
            dd(l,iat)=-fxyz(l,iat)
        enddo
    enddo
    do i=1,ndim
        scpr(i)=0.0_gp
        do iat=1,nat
            do l=1,3
                scpr(i)=scpr(i)-fxyz(l,iat)*rrr(l,iat,i)
            enddo
        enddo
        do iat=1,nat
            do l=1,3
                dd(l,iat)=dd(l,iat)-scpr(i)*rrr(l,iat,i)
            enddo
        enddo
    enddo

    !simple sd in space orthogonal to relevant subspace
    do iat=1,nat
        do l=1,3
            dd(l,iat)=dd(l,iat)*alpha
        enddo
    enddo

    do i=1,ndim
    !quasi newton in relevant subspace
        tt=scpr(i)/sqrt(eval(i)**2+res(i)**2)
        do iat=1,nat
            do l=1,3
                dd(l,iat)=dd(l,iat)+tt*rrr(l,iat,i)
            enddo
        enddo
    enddo
end subroutine

subroutine getSubSpaceEvecEval(label,iproc,verbosity,nat,nhist,nhistx,ndim,cutoffratio,lwork,work,rxyz,&
                              &fxyz,aa,rr,ff,rrr,fff,eval,res,success)
    use module_base
    use yaml_output
    !hard-coded parameters:
    !threshold for linear dependency:
    !if (eval(idim)/eval(nhist).gt.1.e-4_gp) then
    implicit none
    !parameters
    integer, intent(in) :: iproc,verbosity,nat,nhist,nhistx,lwork
    character(len=*), intent(in) :: label
    integer, intent(out) :: ndim
    real(gp), intent(in) :: rxyz(3,nat,0:nhistx),fxyz(3,nat,0:nhistx)
    real(gp), intent(out) :: aa(nhistx,nhistx),eval(nhistx),work(lwork)
    real(gp), intent(out) :: rr(3,nat,0:nhistx), ff(3,nat,0:nhistx)
    real(gp), intent(out) :: rrr(3,nat,0:nhistx), fff(3,nat,0:nhistx)
    real(gp), intent(out) :: res(nhistx)
    real(gp), intent(in) :: cutoffratio
    logical, intent(out) :: success
    !internal
    integer :: i,j,l,iat,info,idim,jdim
    real(gp) :: tt
    real(gp) :: rnorm(nhistx)

    success=.false.

    ! calculate norms
    do i=1,nhist
        rnorm(i)=0.0_gp
         do iat=1,nat
             do l=1,3
                rnorm(i)=rnorm(i) + (rxyz(l,iat,i)-rxyz(l,iat,i-1))**2
             enddo
         enddo
         rnorm(i)=1.0_gp/sqrt(rnorm(i))
    enddo

    !find linear dependencies via diagonalization of overlap matrix   
    !build overlap matrix:
    do i=1,nhist
        do j=1,nhist
            aa(i,j)=0.0_gp
            do iat=1,nat
                do l=1,3
                aa(i,j)=aa(i,j) + (rxyz(l,iat,i)-rxyz(l,iat,i-1))&
                &*(rxyz(l,iat,j)-rxyz(l,iat,j-1))
                enddo
            enddo
            aa(i,j)=aa(i,j)*rnorm(i)*rnorm(j)
         enddo
    enddo

    call dsyev('V',"L",nhist,aa,nhistx,eval,work,lwork,info)
    if (info.ne.0) then
        call yaml_warning(trim(adjustl(label))//' 1st DSYEV (Overlapmatrix) in getSupSpaceEvecEval failed with info: '&
                          // trim(yaml_toa(info))//', iproc: '//trim(yaml_toa(iproc)))
        return
!        stop 'info'
    endif
    if(iproc==0 .and. verbosity>=3)then
        do i=1,nhist
            call yaml_scalar(trim(adjustl(label))//' Overlap eigenvalues: '//trim(yaml_toa(i))//' '//trim(yaml_toa(eval(i))))
        enddo
    endif

    do idim=1,nhist
        do iat=1,nat
            do l=1,3
                rr(l,iat,idim)=0.0_gp
                ff(l,iat,idim)=0.0_gp
            enddo
        enddo
    enddo

    ndim=0
    do idim=1,nhist
        !remove linear dependencies by using the overlap-matrix eigenvalues:
        if (eval(idim)/eval(nhist).gt.cutoffratio) then    ! HERE
            ndim=ndim+1

            do jdim=1,nhist
                do iat=1,nat
                    do l=1,3
                         rr(l,iat,ndim)=rr(l,iat,ndim)+&
                                       &aa(jdim,idim)*rnorm(jdim)*(rxyz(l,iat,jdim)-rxyz(l,iat,jdim-1))
                         ff(l,iat,ndim)=ff(l,iat,ndim)-&
                                       &aa(jdim,idim)*rnorm(jdim)*(fxyz(l,iat,jdim)-fxyz(l,iat,jdim-1))

                    enddo
                enddo
            enddo

            do iat=1,nat
                do l=1,3
                    rr(l,iat,ndim)=rr(l,iat,ndim)/sqrt(abs(eval(idim)))
                    ff(l,iat,ndim)=ff(l,iat,ndim)/sqrt(abs(eval(idim)))
                enddo
            enddo
        endif
    enddo

    ! Hessian matrix in significant orthogonal subspace
    do i=1,ndim
        do j=1,ndim
            aa(i,j)=0.0_gp
            do iat=1,nat
                do l=1,3
                    aa(i,j)=aa(i,j) + .5_gp*(rr(l,iat,i)*ff(l,iat,j)+&
                                      &rr(l,iat,j)*ff(l,iat,i))
                enddo
            enddo
        enddo
    enddo

    call dsyev('V',"L",ndim,aa,nhistx,eval,work,lwork,info)
    if (info.ne.0) then
        call yaml_warning(trim(adjustl(label))//' 2nd DSYEV (subpsace hessian) in getSupSpaceEvecEval failed with info: '&
                          // trim(yaml_toa(info))//', iproc:'//trim(yaml_toa(iproc)))
        return
!        stop 'info'
    endif

    ! calculate eigenvectors
    do i=1,ndim
        do iat=1,nat
            do l=1,3
                rrr(l,iat,i)=0.0_gp
                fff(l,iat,i)=0.0_gp
            enddo
        enddo
    enddo

    do i=1,ndim
        tt=0.0_gp
        do j=1,ndim
            do iat=1,nat
                do l=1,3
                    rrr(l,iat,i)=rrr(l,iat,i) + aa(j,i)*rr(l,iat,j)
                    fff(l,iat,i)=fff(l,iat,i) + aa(j,i)*ff(l,iat,j)
                enddo
            enddo
        enddo
        do iat=1,nat
            do l=1,3
                tt=tt+(fff(l,iat,i)-eval(i)*rrr(l,iat,i))**2
            enddo
        enddo
        !residuue according to Weinstein criterion
        res(i)=sqrt(tt)
        if(iproc==0 .and. verbosity>=3)&
            call yaml_scalar(trim(adjustl(label))//' i, eigenvalue, residue: '&
            //trim(yaml_toa(i))//' '//trim(yaml_toa(eval(i)))//&
            ' '//trim(yaml_toa(res(i))))
    enddo
    success=.true.
end subroutine

subroutine findbonds(label,iproc,verbosity,nat,rcov,pos,nbond,iconnect)
!has to be called before findsad (if operating in biomolecule mode)
    use module_base
    use yaml_output
    implicit none
    !parameters
    integer, intent(in) :: iproc,verbosity,nat
    character(len=*), intent(in) :: label
    real(gp), intent(in) :: rcov(nat)
    real(gp), intent(in) :: pos(3,nat)
    integer, intent(out) :: nbond
    integer, intent(out) :: iconnect(2,1000)
    !internal
    integer :: iat,jat
    real(gp) :: dist2
    nbond=0
    do iat=1,nat
        do jat=1,iat-1
            dist2=(pos(1,iat)-pos(1,jat))**2+&
                  (pos(2,iat)-pos(2,jat))**2+&
                  (pos(3,iat)-pos(3,jat))**2
            if (dist2.le.(1.2_gp*(rcov(iat)+rcov(jat)))**2) then
                nbond=nbond+1
                if (nbond.gt.1000) stop &
                     'nbond>1000, increase size of iconnect in routine which calls subroutine findbonds'
                iconnect(1,nbond)=iat
                iconnect(2,nbond)=jat
            endif
        enddo
    enddo
    if(iproc==0.and.verbosity>=2)call yaml_scalar(trim(adjustl(label))//&
                                 ' Found'//trim(yaml_toa(nbond))//' bonds.')
end subroutine

subroutine projectbond(nat,nbond,rat,fat,fstretch,iconnect,wold,alpha_stretch0,alpha_stretch)
    use module_base, only: gp
    implicit none
    integer, intent(in) :: nat
    integer, intent(in) :: nbond
    real(gp), intent(in) :: rat(3,nat)
    real(gp), intent(inout) :: fat(3,nat)
    real(gp), intent(inout) :: fstretch(3,nat)
    integer, intent(in) :: iconnect(2,nbond)
    real(gp), intent(inout) :: wold(nbond)
    real(gp), intent(in) :: alpha_stretch0
    real(gp), intent(inout) :: alpha_stretch
    !internal
    integer :: iat,jat,ibond,jbond,l,nsame,info
    real(gp) :: ss(nbond,nbond),w(nbond),vv(3,nat,nbond)
    real(gp) :: per
    !functions
    real(gp) :: ddot


    fstretch=0.0_gp

! set up positional overlap matrix
     vv=0.0_gp
     do ibond=1,nbond
     iat=iconnect(1,ibond)
     jat=iconnect(2,ibond)
     do l=1,3
     vv(l,iat,ibond)=rat(l,jat)-rat(l,iat)
     vv(l,jat,ibond)=rat(l,iat)-rat(l,jat)
     enddo
     enddo

     ss=0.0_gp
     w=0.0_gp
     do ibond=1,nbond
     do jbond=1,nbond
     ss(ibond,jbond)=ddot(3*nat,vv(1,1,ibond),1,vv(1,1,jbond),1)
     enddo
     w(ibond)=ddot(3*nat,vv(1,1,ibond),1,fat(1,1),1)
     enddo

     nsame=0
     do ibond=1,nbond
      if ( wold(ibond)*w(ibond).gt.0.0_gp) nsame=nsame+1
         wold(ibond)=w(ibond)
     enddo
     per=float(nsame)/nbond
     if (per.gt. .66_gp) then
         alpha_stretch=alpha_stretch*1.10_gp
     else
         alpha_stretch=max(1.e-2_gp*alpha_stretch0,alpha_stretch/1.10_gp)
     endif
!     write(555,'(f5.1,a,1x,es10.3)') 100*per,' percent of bond directions did
!     not switch sign',alpha_stretch

     call DPOSV('L', nbond, 1, ss, nbond, w, nbond, info )
     if (info.ne.0) then
        write(*,*)'info',info
        stop 'info DPOSV in minenergyforces'
     endif

! calculate projected force
     fstretch=0.0_gp
     do ibond=1,nbond
     do iat=1,nat
     do l=1,3
     fstretch(l,iat)=fstretch(l,iat)+w(ibond)*vv(l,iat,ibond)
     enddo
     enddo
     enddo
!     fnrmst=dnrm2(3*nat,fstretch,1)
     do iat=1,nat
     do l=1,3
     fat(l,iat)=fat(l,iat)-fstretch(l,iat)
     enddo
     enddo


end subroutine

end module
