!> @file
!! Generate atomic electronic configuration
!! @author
!!    Alex Willand, under the supervision of Stefan Goedecker
!!    gpu accelerated routines by Raffael Widmer
!!    parts of this program were based on the fitting program by matthias krack
!!    http://cvs.berlios.de/cgi-bin/viewcvs.cgi/cp2k/potentials/goedecker/pseudo/v2.2/
!!
!!    Copyright (C) 2010-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Generation of the atomic electronic structure calculation
!! gatom modified version
subroutine gatom_modified(rprb,lmax,lpx,lpmx, noccmax,noccmx,occup,&
                  zion,alpz,gpot,alpl,hsep,alps,vh,xp,rmt,fact,nintp,&
                  aeval,ng,psi,&
                  Nsol, Labs, Ngrid,Ngrid_box,Egrid,rgrid,rw,rd,psigrid, Npaw, PAWpatch, &
                  psipsigrid, rcore, zcore, Ngrid_box_larger)
   implicit none
   !Arguments
   integer, intent(in) :: lmax,lpx,lpmx,noccmax,noccmx,nintp,ng
   integer, intent(in) :: Nsol, Labs, Ngrid, Ngrid_box, Npaw, Ngrid_box_larger
   real(kind=8), intent(in) :: rprb,zion,alpz,alpl,fact,rcore,zcore
   real(kind=8), dimension(lpmx), intent(in) :: alps
   real(kind=8), dimension(Ngrid, Nsol), intent(inout) :: psigrid
   real(kind=8), dimension(Ngrid, Nsol), intent(out) :: psipsigrid
   real(kind=8), dimension(0:ng,noccmax,lmax+1) :: psi
   real(kind=8), dimension(noccmx,lmax+1) :: aeval
   !real(kind=8), intent(in) :: rcov
   !real(kind=8), dimension(noccmx,lmax+1) :: res
   !real(kind=8), dimension(noccmx,lmax+1), intent(out) :: chrg
   !Local variables
   logical :: noproj, readytoexit
   integer, parameter :: n_int=1000
   real(kind=8), dimension(0:ng,0:ng) :: hh,ss
   real(kind=8), dimension(0:ng) :: eval
   real(kind=8), dimension(0:ng,0:ng) :: evec
   real(kind=8), dimension(3) :: gpot
   real(kind=8), dimension(6,lpmx) :: hsep
   real(kind=8), dimension(n_int,0:ng,0:ng,lmax+1) :: rmt
   real(kind=8), dimension(0:ng,lpx+1) :: pp1,pp2,pp3
   real(kind=8), dimension(0:ng,0:ng,lmax+1) :: rho
   real(kind=8), dimension(0:ng,0:ng,lmax+1) :: rhoold
   real(kind=8), dimension(n_int) :: xcgrd
   real(kind=8), dimension(n_int) :: rhogrd,excgrd
   real(kind=8), dimension(noccmx,lmax+1) :: occup
   real(kind=8), dimension(0:ng,0:ng,4,0:ng,0:ng,4) :: vh
   real(kind=8), dimension(0:ng) :: xp
   real(kind=8), dimension(Ngrid,Nsol) :: psigrid_naked,psigrid_not_fitted,psigrid_not_fitted_2,psigrid_naked_2
   real(kind=8), dimension(Ngrid,3) :: projgrid,ppgrid
   real(kind=8), dimension(Ngrid) :: rhogrid,rhogrid3,excgrid,potgrid,vxcgrid,rhocore_grid
   real(kind=8), dimension(Nsol) :: Egrid,Etofit,Egrid_tmp,Egrid_tmp_2,valuesatp
   real(kind=8), dimension(Nsol,Nsol) :: H,H_2,Hcorrected,Hadd,Soverlap,genS,genH,dumH
   real(kind=8), dimension(nsol*nsol*2) :: work
   real(kind=8), dimension(Nsol,Ngrid ) :: Tpsigrid,Tpsigrid_dum
   real(kind=8), dimension(Npaw,Npaw) :: PAWpatch,Spsitildes
   real(kind=8), dimension(nintp) :: rint,rint_d,rint_w,rhocore

   real(kind=8), dimension(Ngrid) :: rgrid,rd,rw
   !Local variables
   real(kind=8), parameter :: fourpi=16.d0*atan(1.d0)
   real(kind=8) :: ene_m, ene_p, rcond, fixfact, const,d,dr,dum,enexc,evsum,evsumold
   real(kind=8) :: fact_add,gml,gml1,gml2,gml3,r,Rbox,rmix,rr,rrb,sxp,tt,ttt
   real(kind=8), dimension(Ngrid), target :: dumgrid1,dumgrid2,dumgrid3
   logical :: dofit
   integer :: real_start, iocc, INFO, volta, i,igrid,iorder,iproj,isol,it,itype,ivolta,j,jsol
   integer :: k,l,lcx,LDWORK,n,ngrid_box_2,ngrid_box2,Nsol_used
   integer, dimension(Nsol) :: iwork
   character(len=1) :: EQUED
   real(kind=8), external :: gamma_restricted, ddot

  dofit=.false.
  if( Egrid(1).ne.0.0d0 .and. Egrid(2) .ne.0.0d0  .and. Npaw.ne.Nsol) then
     dofit=.true.
     Etofit=Egrid
     do isol=1, Nsol
        valuesatp(isol)= psigrid(Ngrid_box-10,isol)
     enddo
  endif

  if (nintp.ne.n_int) stop 'n_int><nintp xabs'
  dr=fact*rprb/real(n_int,kind=8)

  do k=1,n_int
     rint(k)=(real(k,kind=8)-.5d0)*dr
     rint_w(k)=dr
     rint_d(k)=1.0_8 / rint_w(k)
     rint_w(k)=rint_w(k)*fourpi*rint(k)**2
     if(rcore>0d0)then
        tt=zcore* (sqrt(0.125d0/atan(1d0))/rcore)**3
        rhocore(k)=tt*exp(-0.5d0*(rint(k)/rcore)**2)
     else
        tt =  zcore/(16d0*atan(1d0)*abs(rcore)**3)
        rhocore(k)=tt*(1d0+2d0*rint(k)/rcore)*exp(2d0*rint(k)/rcore)
     end if
  end do
  do k=1,Ngrid
     if(rcore>0d0)then
        tt=zcore* (sqrt(0.125d0/atan(1d0))/rcore)**3
        rhocore_grid(k)=tt*exp(-0.5d0*(rgrid(k)/rcore)**2)
     else
        tt =  zcore/(16d0*atan(1d0)*abs(rcore)**3)
        rhocore_grid(k)=tt*(1d0+2d0*rgrid(k)/rcore)*exp(2d0*rgrid(k)/rcore)
     end if
  end do


  do l=0,lmax
     if (occup(1,l+1).gt.0.d0) lcx=l
  end do
  !write(6,*) 'lcx',lcx
 
  noproj=.true.
  do l=1,lpx+1
     noproj = noproj .and. (alps(l) .eq. 0.d0)
  end do


  

! projectors, just in case
  if ( .not. noproj) then
     do l=0,lpx
        gml1=sqrt( gamma_restricted(real(l,kind=8)+1.5d0) / (2.d0*alps(l+1)**(2*l+3)) )
        gml2=sqrt( gamma_restricted(real(l,kind=8)+3.5d0) / (2.d0*alps(l+1)**(2*l+7)) )&
            /(real(l,kind=8)+2.5d0)
        gml3=sqrt( gamma_restricted(real(l,kind=8)+5.5d0) / (2.d0*alps(l+1)**(2*l+11)) )&
            /((real(l,kind=8)+3.5d0)*(real(l,kind=8)+4.5d0))
        tt=1.d0/(2.d0*alps(l+1)**2)
        do i=0,ng
           ttt=1.d0/(xp(i)+tt)
           pp1(i,l+1)=gml1*(sqrt(ttt)**(2*l+3))
           pp2(i,l+1)=gml2*ttt*(sqrt(ttt)**(2*l+3))
           pp3(i,l+1)=gml3*ttt**2*(sqrt(ttt)**(2*l+3))
        end do
        
        if(l.eq.Labs) then
           do iorder=1,3
              do igrid=1,Ngrid
                 r=rgrid(igrid)
                 projgrid(igrid,iorder) = (  exp( -r*r*tt)*(r**l *r) )* r**(2*(iorder-1))
              end do
              
              do igrid=1, Ngrid
                 dumgrid1(igrid) =   projgrid(igrid,iorder)*projgrid(igrid,iorder)
              enddo
              call integrate( dumgrid1, dumgrid2, rgrid, Ngrid)
              do igrid=1, Ngrid
                 projgrid(igrid,iorder) = projgrid(igrid,iorder) / sqrt( dumgrid2(Ngrid) ) 
              enddo
           enddo
        endif
     end do
  else
     pp1(:,:)=0.d0
     pp2(:,:)=0.d0
     pp3(:,:)=0.d0
     projgrid(:,:)=0.0d0
  end if

  do l=0,lmax
     do j=0,ng
        do i=0,ng
           rho(i,j,l+1)=0.d0
        end do
     end do
  end do


  do igrid=1,Ngrid
     rhogrid(igrid)=0.0d0
  enddo

  evsum=1.d30
  readytoexit=.false.
  big_loop: do it=1,50
     if(it.eq.50) readytoexit=.true.
     evsumold=evsum
     evsum=0.d0
     
! coefficients of charge density
     do l=0,lmax
        do j=0,ng
           do i=0,ng
              rhoold(i,j,l+1)=rho(i,j,l+1)
              rho(i,j,l+1)=0.d0        
           end do
        end do
     end do

     do l=0,lmax
        do iocc=1,noccmax
           !!! print *, "  l, iocc   ", l, iocc ,  occup(iocc,l+1)
           if (occup(iocc,l+1).gt.0.d0) then
              do j=0,ng
                 do i=0,ng
                    rho(i,j,l+1)=rho(i,j,l+1) + &
                         psi(i,iocc,l+1)*psi(j,iocc,l+1)*occup(iocc,l+1)
                 end do
              end do
           end if
        end do
     end do

     if( readytoexit) then

        do igrid=1,Ngrid
           r=rgrid(igrid)
           rhogrid(igrid)=0.0d0
           do l=0, lmax
              do iocc=1,noccmax
                 if (occup(iocc,l+1).gt.0.d0) then
                    dum=0.0d0
                    do j=0,ng
                       dum=dum + psi(j,iocc,l+1)*exp(-r*r *   xp(j) )* r**(l+1)
                    end do
                    rhogrid(igrid)=rhogrid(igrid)+dum*dum*occup(iocc,l+1)
                 end if
              end do
           enddo
           ! dum = rhogrid(igrid)/r/r *0.07957747154594768d0
           ! vxcgrid(igrid)=emuxc(dum) 
        end do
        rhogrid3=((rhogrid/rgrid)/rgrid )* 0.07957747154594768d0
        if(zcore>0d0) rhogrid3 = rhogrid3 + rhocore_grid

        call driveXC( 1 ,Ngrid,rgrid,rw,rd,rhogrid3,enexc,vxcgrid,excgrid)
     endif
  

     rmix=.5d0
     if (it.eq.1) rmix=1.d0
     do l=0,lmax
        do j=0,ng
           do i=0,ng
              tt=rmix*rho(i,j,l+1) + (1.d0-rmix)*rhoold(i,j,l+1)
              rho(i,j,l+1)=tt
           end do
        end do
     end do

! XC potential on grid
!        do k=1,n_int
!           xcgrd(k)=0.d0
!        end do
!        do l=0,lmax
!           do j=0,ng
!              do i=0,ng
!                 do k=1,n_int
!                    xcgrd(k)=xcgrd(k)+rmt(k,i,j,l+1)*rho(i,j,l+1)
!                 end do
!              end do
!           end do
!        end do
     call DGEMV('N',n_int,(lcx+1)*(ng+1)**2,1.d0,&
                rmt,n_int,rho,1,0.d0,xcgrd,1)
     ! _________________________________________________
     ! dr=fact*rprb/real(n_int,kind=8)
     ! do k=1,n_int
     !    r=(real(k,kind=8)-.5d0)*dr
     !    ! divide by 4 pi
     !    tt=xcgrd(k)*0.07957747154594768d0
     !    ! multiply with r^2 to speed up calculation of matrix elements
     !    xcgrd(k)=emuxc(tt)*r**2
     ! end do
     ! _____________________________________________________________



     call DGEMV('N',n_int,(lcx+1)*(ng+1)**2,1.d0,&
                rmt,n_int,rho,1,0.d0,rhogrd,1)
     ! divide by 4 pi
     rhogrd=rhogrd*0.07957747154594768d0
     if(zcore>0d0) rhogrd = rhogrd + rhocore
     !! call driveXC( 1 ,n_int,rint,rint_w,rint_d,rhogrd,enexc,xcgrd,excgrd)
     call driveXC( 1 ,n_int,rint,rint_w,rint_d,rhogrd,enexc,xcgrd,excgrd)
     do k=1,n_int
        xcgrd(k)=xcgrd(k)*rint(k)**2
     end do




     if(readytoexit) then
        
        do igrid=1, Ngrid
           r=rgrid(igrid)
           potgrid(igrid) =0.5d0*r*r  /    rprb**4 
           potgrid(igrid) = potgrid(igrid) - zion/r * derf( r/alpz/sqrt(2.0)   )
           rr = r/alpz
           potgrid(igrid) = potgrid(igrid) + exp(-0.5d0 * rr**2 )*( gpot(1)+gpot(2)*rr**2 + gpot(3)*rr**4 )
        enddo
        ! poisson per potgrid
        call integrate( rhogrid, dumgrid1, rgrid, Ngrid)
        do igrid=1, Ngrid
           potgrid(igrid)=potgrid(igrid)+dumgrid1(igrid)/rgrid(igrid)
        enddo
        
        do igrid=1, Ngrid
           dumgrid1(igrid) = rhogrid(igrid)/rgrid(igrid)
        enddo
        call integrate( dumgrid1, dumgrid2, rgrid, Ngrid)
        do igrid=1, Ngrid
           potgrid(igrid)=potgrid(igrid)-dumgrid2(igrid) + dumgrid2(Ngrid)
        enddo
     endif
! ------------------------------------------------------------------------------------

     ! do i=1,6
     !    do l=1, lmax
     !       print *, " i= ", i, " l =  ", l, "  " , hsep(i,l)
     !    end do
     ! end do
     ! do l=1, lpx+1
     !    print *, "  l =  ", l, "  " , alps(l)
     ! end do
     ! print *, "  alpz, alpl   " , alpz, alpl
     ! print *, "  fact, rprb  " , fact, rprb 
     ! print *, " gpot  " , gpot
     ! print *, "  ng      " ,  ng 

     ! do i=1,6
     !    do l=1, lmax
     !       print *, " i= ", i, " l =  ", l, "  " , hsep(i,l)
     !    end do
     ! end do
     ! do iocc=1, noccmax
     !    do l=0, lmax
     !       print *, " occup( ", iocc, ", ", l+1, ")=", occup(iocc,l+1)
     !    end do
     ! end do

     loop_l: do l=0,lmax
        gml=.5d0*gamma_restricted(.5d0+real(l,kind=8))

!  lower triangles only
        loop_i: do i=0,ng
           loop_j: do j=0,i
              d=xp(i)+xp(j)
              sxp=1.d0/d
              const=gml*sqrt(sxp)**(2*l+1)
! overlap
              ss(i,j)=const*sxp*(real(l,kind=8)+.5d0)
! kinetic energy
              hh(i,j)=.5d0*const*sxp**2* ( 3.d0*xp(i)*xp(j) +&
                   real(l,kind=8)*(6.d0*xp(i)*xp(j)-xp(i)**2-xp(j)**2) -&
                   real(l,kind=8)**2*(xp(i)-xp(j))**2  ) + .5d0*real(l,kind=8)*(real(l,kind=8)+1.d0)*const

! potential energy from parabolic potential
              hh(i,j)=hh(i,j) +&
                   .5d0*const*sxp**2*(real(l,kind=8)+.5d0)*(real(l,kind=8)+1.5d0)/rprb**4 

! hartree potential from ionic core charge
              tt=sqrt(1.d0+2.d0*alpz**2*d)
              if (l.eq.0) then
                 hh(i,j)=hh(i,j) -zion/(2.d0*d*tt)
              else if (l.eq.1) then
                 hh(i,j)=hh(i,j) -zion* &
                      (1.d0 + 3.d0*alpz**2*d)/(2.d0*d**2*tt**3)
              else if (l.eq.2) then
                 hh(i,j)=hh(i,j) -zion* &
                      (2.d0 + 10.d0*alpz**2*d + 15.d0*alpz**4*d**2)/(2.d0*d**3*tt**5)
              else if (l.eq.3) then
                 hh(i,j)=hh(i,j) -zion*3.d0* &
                      (2.d0 +14.d0*alpz**2*d +35.d0*alpz**4*d**2 +35.d0*alpz**6*d**3)/&
                      (2.d0*d**4*tt**7)
              else 
                 stop 'l too big'
              end if

! potential from repulsive gauss potential
              tt=alpl**2/(.5d0+d*alpl**2)
              if (1.eq.1) then
                 hh(i,j)=hh(i,j)+ gpot(1)*.5d0*gamma_restricted(1.5d0+real(l,kind=8))*tt**(1.5d0+real(l,kind=8))&
                      + (gpot(2)/alpl**2)*.5d0*gamma_restricted(2.5d0+real(l,kind=8))*tt**(2.5d0+real(l,kind=8))&
                      + (gpot(3)/alpl**4)*.5d0*gamma_restricted(3.5d0+real(l,kind=8))*tt**(3.5d0+real(l,kind=8))
              endif


! separable terms
              if (1.eq.1 .and. l.le.lpx) then
                 hh(i,j)=hh(i,j) + pp1(i,l+1)*hsep(1,l+1)*pp1(j,l+1)&
                      + pp1(i,l+1)*hsep(2,l+1)*pp2(j,l+1)&
                      + pp2(i,l+1)*hsep(2,l+1)*pp1(j,l+1)&
                      + pp2(i,l+1)*hsep(3,l+1)*pp2(j,l+1)&
                      + pp1(i,l+1)*hsep(4,l+1)*pp3(j,l+1)&
                      + pp3(i,l+1)*hsep(4,l+1)*pp1(j,l+1)&
                      + pp2(i,l+1)*hsep(5,l+1)*pp3(j,l+1)&
                      + pp3(i,l+1)*hsep(5,l+1)*pp2(j,l+1)&
                      + pp3(i,l+1)*hsep(6,l+1)*pp3(j,l+1)
              end if

! hartree potential from valence charge distribution
!              tt=0.d0
!              do lp=0,lcx
!                 do jp=0,ng
!                    do ip=0,ng
!                       tt=tt + vh(ip,jp,lp+1,i,j,l+1)*rho(ip,jp,lp+1)
!                    end do
!                 end do
!              end do
              tt=DDOT((lcx+1)*(ng+1)**2,vh(0,0,1,i,j,l+1),1,rho(0,0,1),1)
              hh(i,j)=hh(i,j) + tt

! potential from XC potential
              dr=fact*rprb/real(n_int,kind=8)
!              tt=0.d0
!              do k=1,n_int
!                 tt=tt+xcgrd(k)*rmt(k,i,j,l+1)
!              end do
              tt=DDOT(n_int,rmt(1,i,j,l+1),1,xcgrd(1),1)
              hh(i,j)=hh(i,j)+tt*dr

           end do loop_j
        end do loop_i

! ESSL
!        call DSYGV(1,hh,ng+1,ss,ng+1,eval,evec,ng+1,ng+1,aux,2*ng+2)
! LAPACK
        call DSYGV(1,'V','L',ng+1,hh,ng+1,ss,ng+1,eval,evec,(ng+1)**2,info)
        if (info.ne.0) write(6,*) 'LAPACK',info
        do iocc=0,noccmax-1
           do i=0,ng
              evec(i,iocc)=hh(i,iocc)
           end do
        end do

! end LAPACK
        do iocc=1,noccmax
           evsum=evsum+eval(iocc-1)
           aeval(iocc,l+1)=eval(iocc-1)
           do i=0,ng
              psi(i,iocc,l+1)=evec(i,iocc-1)
           end do
        end do
!        write(6,*) 'eval',l
!55      format(5(e14.7))
!        write(6,55) eval 
!        write(6,*) 'diff eval'
!        write(6,55) (eval(i)-eval(i-1),i=1,ng)
!        write(6,*) 'evec',l
!33      format(10(e9.2))
!        do i=0,ng
!           write(6,33) (evec(i,iocc),iocc=0,noccmax-1)
!        end do

     end do loop_l

     tt=abs(evsum-evsumold)
     ! write(6,*) 'evdiff',it,tt, readytoexit
     if (tt.lt.1.d-12) then
        if( readytoexit) then
           exit big_loop
        endif
        readytoexit=.true.
     end if
  end do big_loop
! End of the big loop
  
  !! print *, " aeval ist " , aeval
  
  !! open(unit=22,file='pot.dat')
  do igrid=1, ngrid
     r=rgrid(igrid)
     potgrid(igrid)=potgrid(igrid)+ 0.5d0*labs*(labs+1.0d0)/r/r
     !! write(22,*) r, potgrid(igrid)
  enddo
  !! close(unit=22)
  

  dumgrid1(:)=0.0d0
  do isol=1,nsol
      psigrid_naked(:,isol)=0.0d0
      call schro(Egrid(isol),rgrid,potgrid,dumgrid1,psigrid_naked(1,isol),ngrid_box,isol+labs,labs,zion)
      ! print *, Egrid(isol)
      ! stop

  enddo
  

  H(:,:)=0.0D0
  do i=1,Nsol
     H(i,i)=Egrid(i)
     do iproj=1,3
        do igrid=1,Ngrid
           dumgrid1(igrid)=psigrid_naked(igrid,i)*projgrid(igrid,iproj)
        enddo
        call integrate(dumgrid1,dumgrid2,rgrid,Ngrid)
        ppgrid(i,iproj)=dumgrid2(Ngrid)
     enddo
  enddo

  Rbox=rgrid(Ngrid_box)
  do i=1,Nsol
     do j=1, Nsol
        if ( labs.le.lpx) then
           H(i,j)=H(i,j)+ ppgrid(i,1)*hsep(1,labs+1)*ppgrid(j,1)&
                + ppgrid(i,1)*hsep(2,labs+1)*ppgrid(j,2)&
                + ppgrid(i,2)*hsep(2,labs+1)*ppgrid(j,1)&
                + ppgrid(i,2)*hsep(3,labs+1)*ppgrid(j,2)&
                + ppgrid(i,1)*hsep(4,labs+1)*ppgrid(j,3)&
                + ppgrid(i,3)*hsep(4,labs+1)*ppgrid(j,1)&
                + ppgrid(i,2)*hsep(5,labs+1)*ppgrid(j,3)&
                + ppgrid(i,3)*hsep(5,labs+1)*ppgrid(j,2)&
                + ppgrid(i,3)*hsep(6,labs+1)*ppgrid(j,3)
        endif
        do igrid=1,Ngrid
           dumgrid1(igrid)=psigrid_naked(igrid,i)*psigrid_naked(igrid,j)*vxcgrid(igrid)
        enddo
        call integrate(dumgrid1,dumgrid2,rgrid,Ngrid)
        H(i,j)=H(i,j)+dumgrid2(Ngrid)

        do igrid=1,Ngrid_box
           r=rgrid(igrid)
           rr = r/alpz
           rrb=r/Rbox
           dumgrid1(igrid)=psigrid_naked(igrid,i)*psigrid_naked(igrid,j) *exp(- 0.5d0 * rr**2 )
           !! 
           !!  *(  1.0-2*rrb+rrb**2 ) 
        enddo

        call integrate(dumgrid1,dumgrid2,rgrid,Ngrid_box)
        Hadd(i,j)=dumgrid2(Ngrid_box)
     enddo
  enddo

!!$  if(present(psipsigrid)) then
!!$     ngrid_box_2=psipsigrid(1,1)

     ngrid_box_2 = Ngrid_box_larger 
     dumgrid1(:)=0.0d0
     do isol=1,nsol
        psigrid_naked_2(:,isol)=0.0d0
        call schro(Egrid_tmp_2(isol),rgrid,potgrid,dumgrid1,psigrid_naked_2(1,isol),ngrid_box_2,isol+labs,labs,zion)
     enddo
     H_2(:,:)=0.0D0
     do i=1,Nsol
        H_2(i,i)=Egrid_tmp_2(i)
        do iproj=1,3
           do igrid=1,Ngrid
              dumgrid1(igrid)=psigrid_naked_2(igrid,i)*projgrid(igrid,iproj)
           enddo
           call integrate(dumgrid1,dumgrid2,rgrid,ngrid_box_2)
           ppgrid(i,iproj)=dumgrid2(ngrid_box_2)
        enddo
     enddo

     do i=1,Nsol
        do j=1, Nsol
           if ( labs.le.lpx) then
              H_2(i,j)=H_2(i,j)+ ppgrid(i,1)*hsep(1,labs+1)*ppgrid(j,1)&
                   + ppgrid(i,1)*hsep(2,labs+1)*ppgrid(j,2)&
                   + ppgrid(i,2)*hsep(2,labs+1)*ppgrid(j,1)&
                   + ppgrid(i,2)*hsep(3,labs+1)*ppgrid(j,2)&
                   + ppgrid(i,1)*hsep(4,labs+1)*ppgrid(j,3)&
                   + ppgrid(i,3)*hsep(4,labs+1)*ppgrid(j,1)&
                   + ppgrid(i,2)*hsep(5,labs+1)*ppgrid(j,3)&
                   + ppgrid(i,3)*hsep(5,labs+1)*ppgrid(j,2)&
                   + ppgrid(i,3)*hsep(6,labs+1)*ppgrid(j,3)
           endif
           do igrid=1,ngrid_box_2
              dumgrid1(igrid)=psigrid_naked_2(igrid,i)*psigrid_naked_2(igrid,j)*vxcgrid(igrid)
           enddo
           call integrate(dumgrid1,dumgrid2,rgrid,ngrid_box_2)
           H_2(i,j)=H_2(i,j)+dumgrid2(ngrid_box_2)
        enddo
     enddo
     call DSYEV('V','U', Nsol, H_2, Nsol,Egrid_tmp_2 , WORK, Nsol*Nsol*2, INFO)
     call  DGEMM('N','N',Ngrid ,Nsol,Nsol,1.0d0,psigrid_naked_2,Ngrid,&
          H_2 ,Nsol, 0.0D0 , psigrid_not_fitted_2 , Ngrid)


!!$  end if

  if(dofit) then

     print *, "doing the fit "
     Hcorrected=H-Hadd*0.000d0
     call DSYEV('V','U', Nsol, Hcorrected, Nsol,Egrid_tmp , WORK, Nsol*Nsol*2, INFO)

     real_start=-1
     do iocc=1, Nsol
        !! the conditio below relies on the fact that hgh fitted energies
        !! are good within 10**-3
        if((Etofit(iocc)+0.1).ge.Egrid_tmp(1)) then
           real_start = iocc
           exit
        endif
     enddo

     write(38,*)  "real start ", real_start
     Nsol_used=Nsol-( real_start-1  )

     if(.true. )  then
        write(6,*) " routine gatom_modified  ,  comparaison between  first 5 energies real and  pseudo-not_fitted "
        write(38,*) " routine gatom_modified  ,  comparaison between  energies real and  pseudo-not_fitted "
        do iocc=1, Nsol
           if(iocc.lt.real_start) then
              write(38,*)  iocc, Etofit(iocc) 
              if (iocc.le.5) write(6,*)  iocc, Etofit(iocc) 
           else
              write(38,*)  iocc, Etofit(iocc) , Egrid_tmp(iocc-real_start +1)
              if (iocc.le.5) write(6,*)  iocc, Etofit(iocc) , Egrid_tmp(iocc-real_start +1)
           endif
        enddo
     endif

     do isol=1,Nsol-real_start+1
        fact_add=0.0d0
        do  volta=1,4
           
           Hcorrected=H+Hadd*(-0.001d0+fact_add)
           call DSYEV('V','U', Nsol, Hcorrected, Nsol,Egrid_tmp , WORK, Nsol*Nsol*2, INFO)
           ene_m= Egrid_tmp(isol)

           Hcorrected=H+Hadd*(0.001d0+fact_add)
           call DSYEV('V','U', Nsol, Hcorrected, Nsol,Egrid_tmp , WORK, Nsol*Nsol*2, INFO)
           ene_p= Egrid_tmp(isol)
           
           fact_add = fact_add+(Etofit(isol+real_start-1 ) -(ene_p+ene_m)/2.0d0)/((ene_p-ene_m)/0.002d0)
           

        enddo
           
        Hcorrected=H+Hadd*fact_add
        call DSYEV('V','U', Nsol, Hcorrected, Nsol,Egrid_tmp , WORK, Nsol*Nsol*2, INFO)
        
        call  DGEMM('N','N',Ngrid,1,Nsol,1.0d0,psigrid_naked,Ngrid,&
             Hcorrected(1,isol),Nsol,0.0D0,psigrid(1,isol),Ngrid)
        Egrid(isol)=Egrid_tmp(isol)
        write(38,*) " Egrid , fact_add " ,  Egrid(isol) , fact_add
        
     enddo


     !! scale psigrid so that it matches AE wavefunctions close to the box border
     do isol=1,Nsol-real_start+1
        fixfact = valuesatp(isol+real_start-1)/ psigrid(Ngrid_box-10,isol)
        do igrid=1, Ngrid
           psigrid(igrid,isol)=psigrid(igrid,isol)*fixfact
        enddo
     enddo


        psipsigrid=psigrid
  

     !! this overlap matrix will be used to get the dual functions (ptildes)
     Soverlap=0.0d0
     do isol=1,Nsol-real_start+1
        do jsol=isol,Nsol-real_start+1
           do igrid=1,Ngrid_box
              dumgrid1(igrid)=psigrid(igrid,isol)*psigrid(igrid,jsol)
           enddo
           call integrate(dumgrid1,dumgrid2,rgrid,Ngrid_box)
           Soverlap(isol,jsol) = dumgrid2(Ngrid_box)
           Soverlap(jsol,isol) = dumgrid2(Ngrid_box)
        end do
     end do
     do isol=Nsol-real_start+2, Nsol
        !! completes the missing value. Anyway Npaw will be  used to limit the dimension
        Soverlap(isol,isol)=1.0d0
     enddo


     write(38,*)  ">>  Comparaison Egrid  Egrid_pseudo "
     write(6 ,*)  ">>  Comparaison betwenn first 5 Egrid and   Egrid_pseudo "
     do n=1, Nsol
        if((Etofit(n)+0.1).ge.Egrid(1)) then
           write(38,*) Etofit(n), Egrid(n -real_start+1)
           if (n.le.5) write(6 ,*) Etofit(n), Egrid(n -real_start+1)
        else
           write(38,*) Etofit(n)
           if (n.le.5) write(6 ,*) Etofit(n)
        endif
     enddo
     

     
     !! now get the dual
     get_duality: if(.true.) then
        !! Hcorrect/Hadd is used here as dummy work array
        !! dumgrid1 dumgrid2 and dumgrid3 too
        !! the latter is already dimensioned
        !! to Ngrid and this dimension must be larger than 3*Nsol
        !! as required by DPOSVX. This should be comfortable
        !! In any case we check
        if(Ngrid<3*Nsol) then
           stop  " Ngrid<3*Nsol for DPOSVX dummies in routine gatom_modified "
        endif
        Tpsigrid=transpose(psigrid)
        !! Nota bene :  we solve only Npaw equations and set preventively the result to zero 
        !! for the other lines of Tpsigrid_dum
        Tpsigrid_dum=0.0d0
        call DPOSVX( 'N', 'U' , Npaw , Ngrid , Soverlap, Nsol , Hadd, Nsol, EQUED, &
             dumgrid1 , Tpsigrid, Nsol , Tpsigrid_dum, Nsol, RCOND, dumgrid2 , dumgrid3, Hcorrected,&
             IWORK, INFO )
        write(*,'(A,1x,E10.4)') "DUALITY : CONDITION NUMBER FROM DPOSVX ", RCOND
        
        if (INFO.ne.0) then
           stop  " INFO.ne.0 from DPOSVX in routine gatom_modified "
        endif
        
        if(.true.) then
           !! here we check  the duality 
           do isol=1,Npaw
              do jsol=isol,Npaw
                 dumgrid1(:)=Tpsigrid_dum(isol,:)
                 dumgrid2=dumgrid1*psigrid(:,jsol)
                 call integrate(dumgrid2,dumgrid1, rgrid, Ngrid_box)
                 write(38,*) " duality ",isol,jsol, dumgrid1(Ngrid_box) 
              end do
           enddo
        endif
        
        !! The operation below has been postponed after the block below
        !! in order to use temporarily psigrid as auxiliary array
        !! psigrid will be the exit wavefunctions from the routine
        !!psigrid = transpose(Tpsigrid_dum)
        !! ------------------------------
        
        
        !! get the patch
        !! Resolve Htilde to get non-fitted eigenvectors.
        !! In this basis the action of Hnonpatched is given
        !! by the non-fitted eigenenergies.
        !! Get the Matrix M(i,j)=scalar(psinonfit(i), ptilde(j)).
        !! In terms of psinonfit the actions of Htilde on a ptilde(j)
        !! has coefficient MM(i,j)
        !!                Enonfit(i)  M(i,j)
        !!  
        !! The action MMM of Hnonfit in the ptilde basis satisfies
        !!
        !!         M*MMM = MM
        !! This will be solved here with  DPOSVX initialising 
        !! minus PAWpatch in place of MMM. We will then add
        !! the AE energies to the diagonal so that the obtained patch
        !! corresponds effectively to the difference between Hpaw
        !! and Htilde
        
        !!--  get non-fitted eigenvectors
        !!   H is still the non corrected matrix
        Hcorrected=H
        call DSYEV('V','U', Nsol, Hcorrected, Nsol,Egrid_tmp , WORK, Nsol*Nsol*2, INFO)

        call  DGEMM('N','N',Ngrid ,Nsol,Nsol,1.0d0,psigrid_naked,Ngrid,&
             Hcorrected ,Nsol, 0.0D0 , psigrid_not_fitted , Ngrid)
        


        if(.true.) then
           open(unit=22,file='numerov_pseudo_nonfitted.dat')
           do igrid=1, Ngrid
              write(22,'(200(f20.10,1x))') rgrid(igrid), (psigrid_not_fitted(igrid,j ), j=1,Nsol)   
           enddo
           close(unit=22)
        endif
        



        !! calculate overlap between psitilde isol and psigrid_notfitted  jsol 
        !! psigrid  is psitilde ( while ptilde is still stored in Tpsigrid_dum)
        do isol=1,Npaw
           do jsol=1,Nsol_used
              dumgrid2=psigrid(:,isol)*psigrid_not_fitted(:, jsol)
              call integrate(dumgrid2,dumgrid1, rgrid, Ngrid_box)
              Soverlap(isol,jsol) = dumgrid1(Ngrid_box)
           end do
        enddo

        do isol=1,Npaw
           do jsol=1,Nsol_used
              Hcorrected(jsol,isol)= Egrid_tmp(jsol)*Soverlap(isol,jsol)
           end do
        enddo

        call  DGEMM('N','N',Npaw ,Npaw,Nsol_used,1.0d0,Soverlap ,Nsol,&
             Hcorrected ,Nsol, 0.0D0 , PAWpatch , Npaw)
        
        if(INFO .ne. 0) then
           print *, "INFO ", info
           stop "INFO .ne. 0 in  DGESV"
        endif
        do isol=1,Npaw
           do jsol=1,Npaw
              PAWpatch(isol,jsol)=-PAWpatch(isol,jsol)
           enddo
           PAWpatch(isol,isol)=PAWpatch(isol,isol)+Egrid(isol)  
        enddo
        
        do ivolta=1,2
          if( ivolta==1 )then
             Ngrid_box2 = Ngrid_box_larger 
          else
             Ngrid_box2 = Ngrid_box
          endif
        if( .true. ) then
           !!! MEGA-check 
           !!    we have still in H the hgh hamiltonian
           !!    written in the psigrid_non_fitted basis
           !!  We are going to patch it with the patch
           !!  We are getting H' = H + Soverlap^T . Pawpatch . Soverlap
           !!   and we get also   S = Identity +   Soverlap^T . (Identity - Spsitildes  ). Soverlap
           !! Where Soverlap(isol,jsol) is overlap between >>Ptilde<< isol and psigrid_notfitted  jsol
           !!         Spsitildes is the overlap matrix between psitilde and psitilde
           !! Then we get the approximated eigenvalues resolving a generalised eigenproblem
           
           
           !! calculate overlap between ptilde isol and psigrid_notfitted  jsol.
           !! Ptilde is still stored in Tpsigrid_dum
           do isol=1,Npaw
              do jsol=1,Nsol_used

                 if(ivolta==1) then
                    dumgrid2=Tpsigrid_dum(isol, :)*psigrid_not_fitted_2(:, jsol)
                 else
                    dumgrid2=Tpsigrid_dum(isol, :)*psigrid_not_fitted(:, jsol)
                 end if
                 call integrate(dumgrid2,dumgrid1, rgrid, Ngrid_box2)
                 Soverlap(isol,jsol) = dumgrid1(Ngrid_box2)
              end do
           enddo
           
           call  DGEMM('N','N',Npaw,Nsol_used,Npaw,1.0d0,PAWpatch ,Npaw,&
                Soverlap ,Nsol, 0.0D0 , dumH , Nsol)


           call  DGEMM('T','N',Nsol_used,Nsol_used,Npaw,1.0d0,Soverlap ,Nsol,&
                dumH ,Nsol, 0.0D0 , genH , Nsol)

           do jsol=1,Nsol_used
              if(ivolta==1) then
                 genH(jsol,jsol) = genH(jsol,jsol)  +Egrid_tmp_2(jsol)   !! + H
              else
                 genH(jsol,jsol) = genH(jsol,jsol)  +Egrid_tmp(jsol)   !! + H                 
              endif
           end do


           Spsitildes=0.0d0
           do isol=1,Npaw
              do jsol=isol,Npaw
                 do igrid=1,Ngrid_box2
                    dumgrid1(igrid)=psigrid(igrid,isol)*psigrid(igrid,jsol)
                 enddo
                 call integrate(dumgrid1,dumgrid2,rgrid,Ngrid_box2)
                 Spsitildes(isol,jsol) = dumgrid2(Ngrid_box2)
                 Spsitildes(jsol,isol) = dumgrid2(Ngrid_box2)
              end do
              Spsitildes(isol,isol) =Spsitildes(isol,isol) -1.0
           end do



           
           call  DGEMM('N','N',Npaw,Nsol_used,Npaw,1.0d0,Spsitildes ,Npaw,&
                Soverlap ,Nsol, 0.0D0 , dumH , Nsol)

           call  DGEMM('T','N',Nsol_used,Nsol_used,Npaw,1.0d0,Soverlap ,Nsol,&
                dumH ,Nsol, 0.0D0 , genS , Nsol)

           do isol=1,Nsol_used
              do jsol=1,Nsol_used
                 genS(isol,jsol)=-genS(isol,jsol)
              end do
              genS(isol,isol) =1+ genS(isol,isol)
           end do


           ITYPE=1
           LDWORK=Ngrid
           CALL  DSYGV(ITYPE, "N", "U", Nsol_used, genH, Nsol, genS, Nsol , dumgrid2 , dumgrid3, &
                LDWORK, INFO)

           if(ivolta==1) then
              write(6,*) " first  eigenvalues  the larger Box"
              write(38,*) " first  eigenvalues on the larger Box"
           else
              write(6,*) " first  eigenvalues "
              write(38,*) " first  eigenvalues "              
           endif

           do i=1,max( 2*Npaw,10) 
              write(6,*) dumgrid2( i)
              write(38,*) dumgrid2( i)
           end do
        endif
     end do

!!$        if( present(psipsigrid) ) then
!!$
!!$           do isol=1,Npaw
!!$              do jsol=1,Nsol_used
!!$                 dumgrid2=Tpsigrid_dum(isol, :)*psigrid_not_fitted_2(:, jsol)
!!$                 call integrate(dumgrid2,dumgrid1, rgrid, Ngrid_box)
!!$                 Soverlap(isol,jsol) = dumgrid1(Ngrid_box)
!!$              end do
!!$           enddo
!!$           
!!$           call  DGEMM('N','N',Npaw,Nsol_used,Npaw,1.0d0,PAWpatch ,Npaw,&
!!$                Soverlap ,Nsol, 0.0D0 , dumH , Nsol)
!!$
!!$           call  DGEMM('T','N',Nsol_used,Nsol_used,Npaw,1.0d0,Soverlap ,Nsol,&
!!$                dumH ,Nsol, 0.0D0 , genH , Nsol)
!!$
!!$           do jsol=1,Nsol_used
!!$              genH(jsol,jsol) = genH(jsol,jsol)  +Egrid_tmp_2(jsol)   !! + H
!!$           end do
!!$           
!!$           call  DGEMM('N','N',Npaw,Nsol_used,Npaw,1.0d0,Spsitildes ,Npaw,&
!!$                Soverlap ,Nsol, 0.0D0 , dumH , Nsol)
!!$           call  DGEMM('T','N',Nsol_used,Nsol_used,Npaw,1.0d0,Soverlap ,Nsol,&
!!$                dumH ,Nsol, 0.0D0 , genS , Nsol)
!!$           do isol=1,Nsol_used
!!$              do jsol=1,Nsol_used
!!$                 genS(isol,jsol)=-genS(isol,jsol)
!!$              end do
!!$              genS(isol,isol) =1+ genS(isol,isol)
!!$           end do
!!$
!!$           ITYPE=1
!!$           LDWORK=Ngrid
!!$           CALL  DSYGV(ITYPE, "V", "U", Nsol_used, genH, Nsol, genS, Nsol , dumgrid2 , dumgrid3, &
!!$                LDWORK, INFO)
!!$           print *, " first  eigenvalues , INFO", INFO
!!$
!!$           do i=1,Npaw
!!$              print *, dumgrid2( i)
!!$           end do
!!$
!!$           call  DGEMM('N','N',Ngrid, Nsol_used,  Nsol_used  ,1.0d0,  psigrid_not_fitted_2    ,Ngrid,&
!!$              genH   ,Nsol, 0.0D0 , psipsigrid ,Ngrid )
!!$        endif


        !! these are the wavefunctions ptilde returned by the routine
        psigrid = transpose(Tpsigrid_dum)
        
     endif get_duality
  else
     call DSYEV('V','U', Nsol, H, Nsol,Egrid , WORK, Nsol*Nsol*2, INFO)
     call  DGEMM('N','N',Ngrid ,Nsol,   Nsol,1.0d0 ,psigrid_naked, Ngrid ,H,Nsol, 0.0D0 , psigrid , Ngrid)
  endif

!   call resid(lmax,lpx,noccmax,rprb,xp,aeval,psi,rho,ng,res,&
!              zion,alpz,alpl,gpot,pp1,pp2,pp3,alps,hsep,fact,n_int,&
!              potgrd,xcgrd,noproj)

! ! charge up to radius rcov
!   if (lmax.gt.3) stop 'cannot calculate chrg'
!   do l=0,lmax
!      do iocc=1,noccmax
!         chrg(iocc,l+1)=0.d0
!      end do
!   end do

!   do iocc=1,noccmax
!      do j=0,ng
!         do i=0,ng
!            d=xp(i)+xp(j)
!            sd=sqrt(d)
!            terf=derf(sd*rcov) 
!            texp=exp(-d*rcov**2)

!            tt=0.4431134627263791d0*terf/sd**3 - 0.5d0*rcov*texp/d
!            chrg(iocc,1)=chrg(iocc,1) + psi(i,iocc,1)*psi(j,iocc,1)*tt
!            if (lmax.eq.0) then
!               cycle
!            end if
!            tt=0.6646701940895686d0*terf/sd**5 + &
!               (-0.75d0*rcov*texp - 0.5d0*d*rcov**3*texp)/d**2
!            chrg(iocc,2)=chrg(iocc,2) + psi(i,iocc,2)*psi(j,iocc,2)*tt
!            if (lmax.eq.1) then
!                cycle
!            end if
!            tt=1.661675485223921d0*terf/sd**7 + &
!               (-1.875d0*rcov*texp-1.25d0*d*rcov**3*texp-.5d0*d**2*rcov**5*texp) &
!               /d**3
!            chrg(iocc,3)=chrg(iocc,3) + psi(i,iocc,3)*psi(j,iocc,3)*tt
!            if (lmax.eq.2) then
!               cycle
!            end if
!            tt=5.815864198283725d0*terf/sd**9 + &
!               (-6.5625d0*rcov*texp - 4.375d0*d*rcov**3*texp - &
!               1.75d0*d**2*rcov**5*texp - .5d0*d**3*rcov**7*texp)/d**4
!            chrg(iocc,4)=chrg(iocc,4) + psi(i,iocc,4)*psi(j,iocc,4)*tt
!         end do
!      end do
!   end do



! ! ------------------------------------------------
  


! ! -----------------------------------------------




! ! writing lines suppressed
! !!!        write(66,*)  lmax+1
! !!!        write(66,*) ' #LINETYPE{1324}' 
! !!!        write(66,*) ' $' 
! !!!  do l=0,lmax
! !!!           write(66,*) ' 161'
! !!!     r=0.d0
! !!!     do
! !!!        tt= wave(ng,l,xp,psi(0,1,l+1),r)
! !!!              write(66,*) r,tt
! !!!        r=r+.025d0
! !!!        if(r > 4.00001d0) exit
! !!!     end do
! !!!  end do
! ! writing lines suppressed
! !!!        write(67,*) min(lmax+1,3)
! !!!        write(67,*) ' #LINETYPE{132}'
! !!!        write(67,*) ' #TITLE{FOURIER}' 
! !!!        write(67,*) ' $'
!   dr=6.28d0/rprb/200.d0
! !!!        write(67,*) ' 200'
!   rk=0.d0
!   loop_rk1: do 
!      tt=0.d0
!      do i=0,ng
!         texp=exp(-.25d0*rk**2/xp(i))
! !        texp=exp(-.5d0*energy/xp(i))
!         sd=sqrt(xp(i))
!         tt=tt+psi(i,1,1)*0.4431134627263791d0*texp/sd**3
!      end do
! !!!           write(67,*) rk,tt
!      rk=rk+dr
!      if(rk > 6.28d0/rprb-.5d0*dr) exit loop_rk1
!   end do loop_rk1
!   if (lmax.ge.1) then
! !!!           write(67,*) ' 200'
!      rk=0.d0
!      loop_rk2: do 
!         tt=0.d0
!         do i=0,ng
!            texp=exp(-.25d0*rk**2/xp(i))
!            sd=sqrt(xp(i))
!            tt=tt+psi(i,1,2)*0.2215567313631895d0*rk*texp/sd**5
!         end do
! !!!              write(67,*) rk,tt
!         rk=rk+dr
!         if (rk > 6.28d0/rprb-.5d0*dr) exit loop_rk2
!      end do loop_rk2
!   end if
!   if (lmax.ge.2) then
! !!!           write(67,*) ' 200'
!      rk=0.d0
!      do 
!         tt=0.d0
!         do i=0,ng
!            texp=exp(-.25d0*rk**2/xp(i))
!            sd=sqrt(xp(i))
!            tt=tt+psi(i,1,3)*0.1107783656815948d0*rk**2*texp/sd**7
!         end do
! !!!              write(67,*) rk,tt
!         rk=rk+dr
!         if (rk > 6.28d0/rprb-.5d0*dr) exit
!      end do
!   end if
END SUBROUTINE gatom_modified


subroutine crtvh_paw(ng,lmax,xp,vh,rprb,fact,n_int,rmt)
  implicit none
  !Arguments
  integer, intent(in) :: ng,lmax,n_int
  real(kind=8), dimension(0:ng,0:ng,0:3,0:ng,0:ng,0:3), intent(out) :: vh
  real(kind=8), dimension(0:ng), intent(in) :: xp
  real(kind=8), dimension(n_int,0:ng,0:ng,lmax+1), intent(out) :: rmt
  real(kind=8), intent(in) :: fact,rprb
  !Local variables
  integer :: l,k,i,j,ip,jp
  real(kind=8) :: r,c,d,dr,scpd

  if (lmax.gt.3) stop 'crtvh'

  dr=fact*rprb/real(n_int,kind=8)
  do l=0,lmax
     do k=1,n_int
        r=(real(k,kind=8)-.5d0)*dr
        do j=0,ng
           do i=0,ng
              rmt(k,i,j,l+1)=(r**2)**l*exp(-(xp(i)+xp(j))*r**2)
           end do
        end do
     end do
  end do

  loop_j: do j=0,ng
     loop_i: do i=0,ng
        c=xp(i)+xp(j)
        loop_jp: do jp=0,ng
           loop_ip: do ip=0,ng
              d=xp(ip)+xp(jp)
              scpd=sqrt(c+d)
              vh(ip,jp,0,i,j,0)=0.2215567313631895d0/(c*d*scpd)
              vh(ip,jp,1,i,j,0)=&
                   .1107783656815948d0*(2.d0*c+3.d0*d)/(c*d**2*scpd**3)
              vh(ip,jp,2,i,j,0)=.05538918284079739d0*&
                   (8.d0*c**2+20.d0*c*d+15.d0*d**2)/(c*d**3*scpd**5)
              vh(ip,jp,3,i,j,0)=.0830837742611961d0*&
              (16.d0*c**3+56.d0*c**2*d+70.d0*c*d**2+35.d0*d**3)/&
                   (c*d**4*scpd**7)

              vh(ip,jp,0,i,j,1)=&
                   .1107783656815948d0*(3.d0*c+2.d0*d)/(c**2*d*scpd**3)
              vh(ip,jp,1,i,j,1)=&
                   .05538918284079739d0*(6.d0*c**2+15.d0*c*d+6.d0*d**2)/&
                   (c**2*d**2*scpd**5)
              vh(ip,jp,2,i,j,1)=.02769459142039869d0*&
                   (24.d0*c**3+84.d0*c**2*d+105.d0*c*d**2+30.d0*d**3)/&
                   (c**2*d**3*scpd**7)
              vh(ip,jp,3,i,j,1)=0.04154188713059803d0*&
                   (48.d0*c**4+216.d0*c**3*d+378.d0*c**2*d**2+&
                   315.d0*c*d**3+70.d0*d**4)/(c**2*d**4*scpd**9)

              vh(ip,jp,0,i,j,2)=&
                   .05538918284079739d0*(15.d0*c**2+20.d0*c*d+8.d0*d**2)/&
                   (c**3*d*scpd**5)
              vh(ip,jp,1,i,j,2)=.02769459142039869d0*&
                   (30.d0*c**3+105.d0*c**2*d+84.d0*c*d**2+24.d0*d**3)/&
                   (c**3*d**2*scpd**7)
              vh(ip,jp,2,i,j,2)=&
                   .2077094356529901d0*(8.d0*c**4+36.d0*c**3*d+63.d0*c**2*d**2+&
                   36.d0*c*d**3+8.d0*d**4)/(c**3*d**3*scpd**9)
              vh(ip,jp,3,i,j,2)=&
                   .1038547178264951d0*(48.d0*c**5+264.d0*c**4*d+594.d0*c**3*d**2+&
                   693.d0*c**2*d**3+308.d0*c*d**4+56.d0*d**5)/&
                   (c**3*d**4*scpd**11)

              vh(ip,jp,0,i,j,3)=.0830837742611961d0*&
                   (35.d0*c**3+70.d0*c**2*d+56.d0*c*d**2+16.d0*d**3)/&
                   (c**4*d*scpd**7)
              vh(ip,jp,1,i,j,3)=&
                   .04154188713059803d0*(70.d0*c**4+315.d0*c**3*d+378.d0*c**2*d**2+&
                   216.d0*c*d**3+48.d0*d**4)/(c**4*d**2*scpd**9)
              vh(ip,jp,2,i,j,3)=&
                   .1038547178264951d0*(56.d0*c**5+308.d0*c**4*d+693.d0*c**3*d**2+&
                   594.d0*c**2*d**3+264.d0*c*d**4+48.d0*d**5)/&
                   (c**4*d**3*scpd**11)
              vh(ip,jp,3,i,j,3)=&
                   1.090474537178198d0*(16.d0*c**6+104.d0*c**5*d+286.d0*c**4*d**2+&
                   429.d0*c**3*d**3+286.d0*c**2*d**4+104.d0*c*d**5+16.d0*d**6)/&
                   (c**4*d**4*scpd**13)
           end do loop_ip
        end do loop_jp
     end do loop_i
  end do loop_j

END SUBROUTINE crtvh_paw


subroutine integrate(f,fint,x,Nx)
  implicit none
  real(kind=8), intent(in) :: f(0:Nx-1), x(0:Nx-1)
  real(kind=8), intent(out):: fint(0:Nx-1)
  integer, intent(in):: Nx
  ! -------------------------
  real(kind=8) sfin, sgro
  integer i
  real(kind=8) d,h
  real(kind=8) p,q,r
  real(kind=8) fp,fq,fr
  
  
  
  if(Nx.lt.3) then
     print *, " error, Nx<3 in routine integrate "
     stop
  endif
  
  
  sfin=0.0d0
  sgro=0.0d0
  fint(0)=0.0d0
  
  do i=2, Nx-1,2
     sgro=sgro+ (f(i-2)+ f(i))*(x(i)-x(i-2))
     sfin=sfin+(f(i-2) + f(i-1))*(x(i-1)-x(i-2))
     sfin=sfin+(f(i-1)+f(i))*(x(i)-x(i-1))
     fint(i)=(4*sfin-sgro)/6.0d0
  enddo
  
  
  
  do i=1, Nx-1,2
     
     if( i .lt. Nx-1) then
        d=x(i)-x(i-1)
        h=x(i+1)-x(i)
        
        p=d*(2*d+3*h)/6/(d+h)
        q=d*(d+3*h)/6./h
        r=-d*d*d/6./h/(d+h)
        
        fp=f(i-1)
        fq=f(i)
        fr=f(i+1)
        
        fint(i)=fint(i-1)+p*fp+q*fq+r*fr
     else
        h=x(i-1)-x(i-2)
        d=x(i)-x(i-1)
        p=-d*d*d/6./h/(d+h)
        q=d*(d+3*h)/6./h
        r=d*(2*d+3*h)/6/(d+h)
        
        fp=f(i-2)
        fq=f(i-1)
        fr=f(i)
        fint(i)=fint(i-1)+p*fp+q*fq+r*fr
     endif
     
  enddo
  return
END SUBROUTINE integrate

!> Restricted version of the Gamma function
function gamma_restricted(x)
  implicit none
  !Arguments
  real(kind=8), intent(in) :: x
  real(kind=8) :: gamma_restricted
  !Local variables
  real(kind=8), parameter :: sqrpi = sqrt(3.141592653589793d0)
  integer :: ii,i

  if (x.le.0.d0) stop 'wrong argument for gamma_restricted'
  if (mod(x,1.d0).eq.0.d0) then
     ii=int(x)
     gamma_restricted=1.0d0
     do i=2,ii
        gamma_restricted=gamma_restricted*real(i-1,kind=8)
     end do
  else if (mod(x,.5d0).eq.0.d0) then
     ii=int(x-.5d0)
     gamma_restricted=sqrpi
     do i=1,ii
        gamma_restricted=gamma_restricted*(real(i,kind=8)-.5d0)
     end do
  else
     stop 'wrong argument for gamma_restricted'
  end if
end function gamma_restricted


function emuxc(rho)
  implicit none
  real(kind=8), intent(in) :: rho
  real(kind=8) :: emuxc
  real(kind=8), parameter :: &
       a0p=.4581652932831429d0,&
       a1p=2.217058676663745d0,&
       a2p=0.7405551735357053d0,&
       a3p=0.01968227878617998d0
  real(kind=8), parameter :: &
       b1p=1.0d0,&
       b2p=4.504130959426697d0,&
       b3p=1.110667363742916d0,&
       b4p=0.02359291751427506d0
  real(kind=8), parameter :: rsfac=.6203504908994000d0,ot=1.d0/3.d0
  real(kind=8), parameter :: &
       c1=4.d0*a0p*b1p/3.0d0,  &
       c2=5.0d0*a0p*b2p/3.0d0+a1p*b1p,&
       c3=2.0d0*a0p*b3p+4.0d0*a1p*b2p/3.0d0+2.0d0*a2p*b1p/3.0d0,&
       c4=7.0d0*a0p*b4p/3.0d0+5.0d0*a1p*b3p/3.0d0+a2p*b2p+a3p*b1p/3.0d0,&
       c5=2.0d0*a1p*b4p+4.0d0*a2p*b3p/3.0d0+2.0d0*a3p*b2p/3.0d0,&
       c6=5.0d0*a2p*b4p/3.0d0+a3p*b3p,c7=4.0d0*a3p*b4p/3.0d0
  real(kind=8) :: bot,rs,top

  if(rho.lt.1.d-24) then
    emuxc=0.d0
  else
    if(rho.lt.0.d0) write(6,*) ' rho less than zero',rho
    rs=rsfac*rho**(-ot)
    top=-rs*(c1+rs*(c2+rs*(c3+rs*(c4+rs*(c5+rs*(c6+rs*c7))))))
    bot=rs*(b1p+rs*(b2p+rs*(b3p+rs*b4p)))
    emuxc=top/(bot*bot)
  end if
end function emuxc


subroutine schro(E, r,  V,nonloc, y, NGRID, nsol, larg,  Z)
  implicit none
  !Arguments
  integer, intent(IN) :: nsol,ngrid,larg  
  real(kind=8), intent(in) ::  r(ngrid),v(ngrid), nonloc(ngrid)
  real(kind=8), intent(out) ::  E
  real(kind=8), intent(out) ::  y(ngrid)
  real(kind=8), intent(in) ::  Z
  ! -------------------------------
  real(kind=8) Elow, Ehigh, Eguess
  real(kind=8) pathh, pathl, fase
  integer :: i
  real(kind=8) :: Phase, but
  real(kind=8) :: PI, l

  l=larg

  PI=4.0*atan(1.0)
  Elow=0

  do i=1, NGRID
      if(V(i) .lt. Elow) Elow=V(i)
   enddo
  if( Elow .lt. -Z*Z) Elow = -Z*Z
  Elow=-Z*Z

  Ehigh = 0.0

  pathh = Phase(Ehigh,NGRID,r,v,nonloc,y,  l ,0, 0)
  pathl = Phase(Elow ,NGRID, r,v,nonloc,y,  l ,0, 0)
 

  ! print *, Ehigh, pathh
  ! print *, Elow, pathl

  but= PI*(nsol-l-1)

  if( pathl.gt.but)  then
     print *, " pathl>but " 
     print *, " Elow " , Elow
     print *, " but " , but
     print *, " pathl " , pathl
     print *, " now exiting , routine schro" 
     stop
  endif
  
      
  if(but .gt. pathh) then
     Ehigh = (but+1)*(but+1)/r(NGRID-1)/r(NGRID-1)
     do while( but .gt. Phase(Ehigh ,NGRID, r,V,nonloc,y,  l , 0, 0 ) )
         Ehigh =2*Ehigh
      enddo
   endif

   do while(1.gt.0) 

      Eguess = (Elow+Ehigh)/2

      fase=  Phase(Eguess ,NGRID, r,V,nonloc,y,  l , 0, 0)

      if( fase.gt.but) then
         Ehigh=Eguess
      else
         Elow=Eguess
      endif

      if(dabs(but-fase).lt.1.0e-8) exit
   enddo

   fase = Phase(Eguess,NGRID, r,v,nonloc,y, l,1 ,0)
   E=Eguess


END SUBROUTINE schro


function phase(E, N, rgrid, V, nonloc, y, l, normalize, onlyout)
   implicit none
   !Arguments
   integer :: N, normalize, onlyout
   real(kind=8) :: E,rgrid(N),V(N), nonloc(N), y(N),l
   real(kind=8) :: phase
   !Local variables
   integer :: ii, i,j
   real(kind=8) :: ypi
   
   integer :: yNcross, yflag
   real(kind=8)  :: dh,dl,dh2,dl2,dp,dl3,dhdl2,dh2dl,dh3,add1,add2,deno,num
   real(kind=8)  :: Gh,Gl,G0,Nlc,Nla,Nlb
   
   real(kind=8) :: Ga,Gb,Gc
   real(kind=8) :: ya,yb,yc
   real(kind=8) :: r, PI
   
   real(kind=8) :: fact,norm, func(N), funcdum(N), pow
   integer :: count
   
   PI=4*atan(1.0d0)
   
   phase=0
   yNcross=0
   yflag=0
   
   ! -- Calcul du point intermediaire o le V est minimum
   if( onlyout.eq.1 ) then
      ii=N-1  
   else
      ii=0
      do i=1 , N-1
         if(V(i+1).ge. V(i) )  then
            ii=i
            if(i.eq.1)  then
               ii=10
               if(ii.ge.N-3) then
                  print *, "  attention !!! if(I>=n-3) in phase"
                  stop
               endif
            endif
            exit
         endif
      enddo
      
      if(ii.eq.0) then 
         ii=N-10
         ! print *, " attention !!!I=N-1 in phase  "
         ! print *, " l est " ,  l
         ! stop
      endif
      
      !  if(I<100) I=100
      
      if(ii>N-10) ii=N-10
   
   endif
   
   ! print * , " propagation de 1 a " , ii
   
   ! //------------ Propagation de  1 a I  ----------------------
   
   do i=1,2
      if(rgrid(i).eq.0.0 .and. l.ne.-1) then
         y(i)=0
      else if (l.eq.-4) then
         y(i)=0.0d0
      else 
         y(i) = exp((l+1)*log(rgrid(i)))
      endif
   
   enddo
   
   do i=2,ii
      dh = rgrid(i+1)-rgrid(i)
      dl = rgrid(i)-rgrid(i-1)
      G0 = 2*(V(i)  -E)
      Nlb=nonloc(i)
      if(dabs(G0*dh*dl).lt.1.0)  then
         dh2= dh*dh
         dl2= dl*dl
         dp = dh*dl
         
         Gh = 2*(V(i+1)-E)
         Gl = 2*(V(i-1)-E)
         
         Nlc=nonloc(i+1)
         Nla=nonloc(i-1)
         
         R  = dh2 + dl2 + dp 
         
         dh3=dh2*dh
         dhdl2=dl*dp
         dh2dl=dh*dp
         dl3=dl*dl2
         
         ! // ********************************************************************************
         ! // ** 17 luglio 1998. Aggiunta della parte per il termine non locale.
         ! // ** Vedere file numerov.mathematica
         ! // ** ( h^3*(-Nla  + Nlb ) + l^3*(Nlb  - Nlc) + 
         ! // **      h^2*l*(Nla+4*Nlbd+Nlc)+h*l^2*(Nla+4*Nlb+Nlc))/l*(12-(h^2+h*l-l^2)*Gc))
         
         deno=(dl*(1.d0-Gh*(R-2*dl2)/12.d0))
         
         add1=( y(i)*(dh+(dl*Gh*(R-2*dl2)+G0*(dh+dl)*(R+2*dh*dl))/12) &
              -y(i-1)*dh*(1.-Gl*(R-2*dh2)/12.) &
              )/deno
         
         
         add2=( dh3*(-Nla  + Nlb ) + dl3*(Nlb  - Nlc) + &
              dh2dl*(Nla  + 4*Nlb + Nlc ) + dhdl2*(Nla + 4*Nlb + Nlc) )/deno/6
         
         y(i+1) = y(i)+add1+add2
   
      else
         
         print *, " needs taking smaller steps in the grid for the schroedinger equation ( in routine phase)"
         print *, " at point " , i, " of the grid " 
         print *, " V(i) = " , V(i) , " E= " ,  E
  
         stop
      endif
      
      if(dabs(y(i+1)).gt.1.0D40 .and. l.ne.-4) then 
         fact= 1./dabs(y(i+1)) 
         count =0
         do j=i+1,1,-1
            if(y(j).eq.0) then
               count=count+1
            else 
               count =0
            endif
            if(count .gt. 2) exit
            y(j)=y(j)*fact 
         enddo
      endif
      if( (i+1) .le.ii ) then !  // LA PHASE EST CALCULE EN I
         if((y(i)*y(i+1)).lt.0) yNcross=yNcross+1
         if(yflag.eq.1 .and. (y(i)*y(i+1)).eq.0)then
            yflag=1-yflag
            yNcross=yNcross+1
         endif
      endif
   enddo
   
   if( y(ii).eq.0.0) then 
      print *, " y[I] == 0.0 dans Schroedinger , in phase"
      stop
   endif
   
   !  // ypI=(y[I+1]*dl2-y[I-1]*dh2+y[I]*(dh2-dl2))/((dh+dl)*dl*dh); // vecchia maniera di calcolare yp
   !  // sostituita con la maniera seguente, presa dal metodo numerov (vedi numerov.nb)
   
   i=ii
   dh = rgrid(i+1)-rgrid(i)
   dl = rgrid(i  )-rgrid(i-1)
   
   Nlc=nonloc(i+1)
   Nla=nonloc(i-1)
   Nlb=nonloc(i)
   
   Gb = 2*(V(i)  -E)
   if(dabs(G0*dh*dl).gt.1.0) then
      print *, " problem with  fabs(G0*dh*dl)>1.0 in calculation  of yp in I , in phase"
      stop
   end if
   
   Gc = 2*(V(i+1)-E)
   Ga = 2*(V(i-1)-E)
   
   ya=y(ii-1)
   yb=y(ii)
   yc=y(ii+1)
   
   ypI=(dh*(Ga*pow(dl,2)*(-12*dh + Gc*pow(dh,3) - 6*dl + &
        Gc*pow(dh,2)*dl) - &
        6 *(-12*dh + Gc*pow(dh,3) - 12*dl + 2*Gc*pow(dh,2)*dl))*ya + &
        (dh + dl)*(Gb*pow(dl,2)* &
        (-24*dh + 2*Gc*pow(dh,3) - 6*dl + 3*Gc*pow(dh,2)*dl) + &
        6 *(-12*dh + Gc*pow(dh,3) + Gc*pow(dh,2)*dl - &
        Gc*dh*pow(dl,2) + Gc*pow(dl,3)))*yb)/&
        (6.*dh*dl*(dh + dl)*(-12 + Gc*(pow(dh,2) + dh*dl - pow(dl,2)))) 
   
   ! // *****************************************************************************
   ! // ** Termine aggiuntivo
   ! // **
   ! // 6*l^3*Nlc + 
   ! // Nla*(-12*h^2*l - 6*h*l^2 + h^3*l*(h + l)*Gc) + 
   ! // Nlb*(-24*h^2*l - 30*h*l^2 - 6*l^3 +      2*h^3*l*(h + l)*Gc + 3*h^2*l^2*(h + l)*Gc)
   ! // / al denominatore
   ! //
   ! //  6*h*(h + l)*(-12 + (h^2 + h*l - l^2)*Gc)
   
   deno= 6*dh*(dh + dl)*(-12 + (dh*dh + dh*dl - dl*dl)*Gc)
        
   num=  6*dl*dl*dl*Nlc&
        +Nla*(-12*dh*dh*dl-6*dh*dl*dl+dh*dh*dh*dl*(dh + dl)*Gc)&
        +Nlb*(-24*dh*dh*dl - 30*dh*dl*dl - &
        6*dl*dl*dl+2*dh*dh*dh*dl*(dh + dl)*Gc +3*dh*dh*dl*dl*(dh+dl)*Gc)
   
   ypI=ypI+num/deno
        
   
   if( onlyout.eq.1) then
      ypI = ypI+ dh*(  y(ii)*Gb  +y(ii+1)*Gc )/2 
      phase=ypI
      return
   endif
   
   
   if(dabs(y(ii)) .gt. dabs( ypI ) ) then
      phase=-atan(ypI/y(ii))
   else
      r = y(ii)/ypI 
      if(  r .gt.0.  ) then
         phase=-( PI/2.0 - atan(r) )
      else
         phase=- ( - PI/2. - atan( r ))
      endif
   endif
   
   
   if( dabs(y(ii) ) .gt. dabs(ypI)) then
      y(ii+1)=y(ii+1)/y(ii)
      do i=1, ii
         y(i)=y(i)/y(ii)
      enddo
   else
      do i=1, ii+1
         y(i)=y(i)/ypI
      enddo
   endif
   
   ! //------------ Propagation de I rinf --------------------------
   
   do i=N,N-1,-1 
      y(i)=N-i    ! //y[i]=exp(-sqrt(-2*E)*r[i]);
   enddo
   
   do i=N-1, ii,-1
      dh = rgrid(i)-rgrid(i-1)
      dl = rgrid(i+1)-rgrid(i)
      G0 = 2*(V(i)  -E)
      Nlb=nonloc(i)
      
      if(dabs(G0*dh*dl).lt.1.0) then
         dh2= dh*dh
         dl2=dl*dl
         dp = dh*dl
         
         Gh = 2*(V(i-1)-E)
         Gl = 2*(V(i+1)-E)
         
         Nlc=nonloc(i-1)
         Nla=nonloc(i+1)
   
         R  = dh2 + dl2 + dp 
   
         dh3=dh2*dh
         dhdl2=dl*dp
         dh2dl=dh*dp
         dl3=dl*dl2
         
         ! // ********************************************************************************
         ! // ** 17 luglio 1998. Aggiunta della parte per il termine non locale.
         ! // ** Vedere file numerov.mathematica
         ! // ** ( h^3*(-Nla  + Nlb ) + l^3*(Nlb  - Nlc) + 
         ! // **      h^2*l*(Nla+4*Nlbd+Nlc)+h*l^2*(Nla+4*Nlb+Nlc))/l*(12-(h^2+h*l-l^2)*Gc))
         
         deno=(dl*(1.-Gh*(R-2*dl2)/12.))
         
         add1=( y(i)*(dh+(dl*Gh*(R-2*dl2)+G0*(dh+dl)*(R+2*dh*dl))/12)&
              -y(i+1)*dh*(1.-Gl*(R-2*dh2)/12.) &
              )/deno
         
         add2=( dh3*(-Nla  + Nlb ) + dl3*(Nlb  - Nlc) + &
              dh2dl*(Nla  + 4*Nlb + Nlc ) + dhdl2*(Nla + 4*Nlb + Nlc) )/deno
   
         y(i-1) = y(i)+add1+add2
         
         ! /*  
         ! y[i-1] = y[i]+( y[i]*(dh+(dl*Gh*(R-2*dl2)+G0*(dh+dl)*(R+2*dh*dl))/12)
         ! -y[i+1]*dh*(1.-Gl*(R-2*dh2)/12.)
         ! )/
         ! (dl*(1.-Gh*(R-2*dl2)/12.));
         ! */
      else
         print *, "needs taking smaller steps in the grid for the schroedinger equation  , in phase "
         stop
      endif
   
      if(dabs(y(i-1)).gt.1.0D8) then 
         fact= 1./dabs(y(i-1)) 
         count =0
         do j=i-1, N 
            if(y(j).eq.0) then
               count=count+1
            else 
               count =0
            endif
            if(count.ne.0) exit
            y(j)=y(j)*fact 
         enddo
      endif
   
      if( (i-1) .ge.ii ) then!  // LA PHASE EST CALCULE EN I
         if((y(i)*y(i-1) ).lt.0) yNcross=yNcross+1
         if(yflag.eq.1 .and. (y(i)*y(i-1)).eq.0) then
            yflag=1-yflag
            yNcross=yNcross+1
         endif
      endif
   enddo
   !  // ypI=(y[I+1]*dh2-y[I-1]*dl2+y[I]*(dl2-dh2))/((dh+dl)*dl*dh);
   !  // sostituita con la maniera seguente, presa dal metodo numerov (vedi numerov.nb)
   ! {
   
   i=ii
   dh = rgrid(i+1)-rgrid(i)
   dl = rgrid(i  )-rgrid(i-1)
   
   Nlc=nonloc(i+1)
   Nla=nonloc(i-1)
   Nlb=nonloc(i)
   
   
   Gb = 2*(V(i)  -E)
   if(dabs(G0*dh*dl).gt.1.0) then
      print *, " problem with fabs(G0*dh*dl)>1.0 in calculation di yp in I , in phase"
      stop
   endif
   Gc = 2*(V(i+1)-E)
   Ga = 2*(V(i-1)-E)
   
   ya=y(ii-1)
   yb=y(ii)
   yc=y(ii+1)
   
   ypI=(dh*(Ga*pow(dl,2)*(-12*dh + Gc*pow(dh,3) - 6*dl + &
        Gc*pow(dh,2)*dl) - &
        6*(-12*dh + Gc*pow(dh,3) - 12*dl + 2*Gc*pow(dh,2)*dl))*ya + &
        (dh + dl)*(Gb*pow(dl,2)*&
        (-24*dh + 2*Gc*pow(dh,3) - 6*dl + 3*Gc*pow(dh,2)*dl) + &
        6*(-12*dh + Gc*pow(dh,3) + Gc*pow(dh,2)*dl - &
        Gc*dh*pow(dl,2) + Gc*pow(dl,3)))*yb)/&
        (6.*dh*dl*(dh + dl)*(-12 + Gc*(pow(dh,2) + dh*dl - pow(dl,2)))) 
   
   ! // *****************************************************************************
   !    // ** Termine aggiuntivo
   !    // **
   !    // 6*l^3*Nlc + 
   !    // Nla*(-12*h^2*l - 6*h*l^2 + h^3*l*(h + l)*Gc) + 
   !    // Nlb*(-24*h^2*l - 30*h*l^2 - 6*l^3 +      2*h^3*l*(h + l)*Gc + 3*h^2*l^2*(h + l)*Gc)
   !    // / al denominatore
   !    //
   !    //  6*h*(h + l)*(-12 + (h^2 + h*l - l^2)*Gc)
   
   deno= 6*dh*(dh + dl)*(-12 + (dh*dh + dh*dl - dl*dl)*Gc)
   
   num=  6*dl*dl*dl*Nlc &
        +Nla*(-12*dh*dh*dl-6*dh*dl*dl+dh*dh*dh*dl*(dh + dl)*Gc)&
        +Nlb*(-24*dh*dh*dl - 30*dh*dl*dl - &
        6*dl*dl*dl+2*dh*dh*dh*dl*(dh + dl)*Gc +3*dh*dh*dl*dl*(dh+dl)*Gc&
        )
   
   ypI=ypI+num/deno
   
   phase=phase+PI*yNcross 
   
   if(dabs(y(ii)) .gt. dabs( ypI ) ) Then
      phase =phase+atan(ypI/y(ii))
   else
      r = y(ii)/ypI 
      if(  r .gt.0.  ) then
         phase =phase+( PI/2. - atan(r) )
      else
         phase = phase+ ( - PI/2. - atan( r ))
      endif
   endif
   
   if( dabs(y(ii)) .gt. dabs(ypI)) then
      y(ii-1)=y(ii-1)/y(ii)
      do i=N,ii,-1
         y(i)=y(i)/y(ii)
      enddo
   else
      do i=N,ii-1,-1
         y(i)=y(i)/ypI
      enddo
   endif
   
   if(normalize.eq.1) then
      do i=1,N
         func(i)=y(i)*y(i)
      enddo
      
      call integrate(func,funcdum,rgrid,N)
      norm=sqrt(funcdum(N) )
      do i=1,N
         y(i)=y(i)/norm
      enddo
   endif
end function phase


function pow(x,n)
  implicit none
  !Arguments
  real(kind=8), intent(in) :: x
  integer, intent(in) :: n
  real(kind=8) :: pow
  pow=x**n
end function pow
