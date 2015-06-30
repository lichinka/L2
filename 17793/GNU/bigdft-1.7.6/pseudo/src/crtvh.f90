!> @file
!! atomic program for generating and optimizing hgh pseudo-potentials.
!! @author
!!    Alex Willand, under the supervision of Stefan Goedecker
!!    gpu accelerated routines by Raffael Widmer
!!    parts of this program were based on the fitting program by Matthias Krack
!!    http://cvs.berlios.de/cgi-bin/viewcvs.cgi/cp2k/potentials/goedecker/pseudo/v2.2/
!!
!!    Copyright (C) 2010-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


subroutine crtvh(ng,lcx,lmax,xp,vh,nint,rmt,rmtg, ud,rr)
   implicit none
   !Arguments
   integer, intent(in) :: ng,lcx,lmax,nint
   real(kind=8), dimension(0:ng), intent(in) :: xp
   real(kind=8), dimension(((ng+1)*(ng+2))/2,0:lcx,((ng+1)*(ng+2))/2,0:lmax), intent(out) :: vh
   real(kind=8), dimension(nint,((ng+1)*(ng+2))/2,lmax+1), intent(out) :: rmt
   real(kind=8), dimension(nint,((ng+1)*(ng+2))/2,lmax+1), intent(out) :: rmtg
   real(kind=8), dimension(nint,((ng+1)*(ng+2))/2,lcx+1), intent(out) :: ud
   real(kind=8), dimension(nint), intent(in) :: rr
   !Local variables
   real(kind=8), parameter :: spi=1.772453850905516d0 !< sqrt(pi)
   real(kind=8) :: a,tt1,c,d,r,scpd,sd,tt,tx
   integer :: i,j,k,l,ij,ip,jp,ipjp

   ! print*,'entered crtvh'
   if (lcx > 3) stop 'crtvh:lcx>3'
   if (lmax > 3) stop 'crtvh:lmax>3'
       
   ! wavefunction products on grid
   do l=0,lmax
      do k=1,nint
         r=rr(k)  
         ij=0
         ! lower triangle
         do j=0,ng
            do i=j,ng
               ij=ij+1
               rmt(k,ij,l+1)=(r**2)**l*exp(-(xp(i)+xp(j))*r**2)
               a=xp(j)+xp(i)
               tt1=2.d0*(l-a*r**2)*(1.d0/r)
               rmtg(k,ij,l+1)=tt1*rmt(k,ij,l+1)
            end do
         end do
      end do
   end do

   ! Hartree potential on grid 
   do k=1,nint
      r=rr(k)
      ! lower triangle
      ij=0
      do j=0,ng
         do i=j,ng
            ij=ij+1
            d=xp(i)+xp(j)
            sd=sqrt(d)
            tx=exp(-d*r**2)
            tt=spi*Derf(sd*r)
            if (lcx.ge.0) ud(k,ij,0+1)=tt/(4.d0*sd**3*r)
            if (lcx.ge.1) ud(k,ij,0+2)=-tx/(4.d0*d**2) + 3.d0*tt/(8.d0*sd**5*r)
            if (lcx.ge.2) ud(k,ij,0+3)=-tx*(7.d0 + 2.d0*d*r**2)/(8.d0*d**3) + 15.d0*tt/(16.d0*sd**7*r)
            if (lcx.ge.3) ud(k,ij,0+4)=-tx*(57.d0+22.d0*d*r**2+4.d0*d**2*r**4)/(16.d0*d**4) + 105.d0*tt/(32.d0*sd**9*r)
         end do
      end do
   end do

   ! Coulombic integrals
   ! lower triangle
   ij=0
   do j=0,ng
      do i=j,ng
         ij=ij+1
         c=xp(i)+xp(j)
         ! lower triangle
         ipjp=0
         do jp=0,ng
            do ip=jp,ng
               ipjp=ipjp+1
               d=xp(ip)+xp(jp)
               scpd=sqrt(c+d)
               vh(ipjp,0,ij,0)=0.2215567313631895d0/(c*d*scpd)
               if (lcx > 0) vh(ipjp,1,ij,0)= 0.1107783656815948d0*(2.d0*c+3.d0*d)/(c*d**2*scpd**3)
               if (lcx > 1) vh(ipjp,2,ij,0)= 0.05538918284079739d0*(8.d0*c**2+20.d0*c*d+15.d0*d**2)/(c*d**3*scpd**5)
               if (lcx > 2) vh(ipjp,3,ij,0)= 0.0830837742611961d0 * &
                              & (16.d0*c**3+56.d0*c**2*d+70.d0*c*d**2+35.d0*d**3)/(c*d**4*scpd**7)

               if (lmax == 0) cycle

               vh(ipjp,0,ij,1)= 0.1107783656815948d0*(3.d0*c+2.d0*d)/(c**2*d*scpd**3)
               if (lcx > 0) vh(ipjp,1,ij,1)=  0.05538918284079739d0*(6.d0*c**2+15.d0*c*d+6.d0*d**2)/(c**2*d**2*scpd**5)
               if (lcx > 1) vh(ipjp,2,ij,1)= 0.02769459142039869d0 * &
                               & (24.d0*c**3+84.d0*c**2*d+105.d0*c*d**2+30.d0*d**3)/(c**2*d**3*scpd**7)
               if (lcx > 2) vh(ipjp,3,ij,1)= 0.04154188713059803d0 * &
                               & (48.d0*c**4+216.d0*c**3*d+378.d0*c**2*d**2+315.d0*c*d**3+70.d0*d**4)/(c**2*d**4*scpd**9)

               if (lmax == 1) cycle

               vh(ipjp,0,ij,2)= 0.05538918284079739d0*(15.d0*c**2+20.d0*c*d+8.d0*d**2)/ (c**3*d*scpd**5)
               if (lcx > 0) vh(ipjp,1,ij,2)= 0.02769459142039869d0*(30.d0*c**3+105.d0*c**2*d+84.d0*c*d**2+24.d0*d**3)/ &
                               & (c**3*d**2*scpd**7)
               if (lcx > 1) vh(ipjp,2,ij,2)= 0.2077094356529901d0*(8.d0*c**4+36.d0*c**3*d+63.d0*c**2*d**2+ &
                               & 36.d0*c*d**3+8.d0*d**4)/(c**3*d**3*scpd**9)
               if (lcx > 2) vh(ipjp,3,ij,2)= 0.1038547178264951d0*(48.d0*c**5+264.d0*c**4*d+594.d0*c**3*d**2+ &
                               & 693.d0*c**2*d**3+308.d0*c*d**4+56.d0*d**5)/(c**3*d**4*scpd**11)

               if (lmax == 2) cycle

               vh(ipjp,0,ij,3)= 0.0830837742611961d0* &
                    &   (35.d0*c**3+70.d0*c**2*d+56.d0*c*d**2+16.d0*d**3)/(c**4*d*scpd**7)
               if (lcx > 0) vh(ipjp,1,ij,3)= 0.04154188713059803d0 * (70.d0*c**4+315.d0*c**3*d &
                               & +378.d0*c**2*d**2+216.d0*c*d**3+48.d0*d**4)/(c**4*d**2*scpd**9)
               if (lcx > 1) vh(ipjp,2,ij,3)= 0.1038547178264951d0* &
                               & (56.d0*c**5+308.d0*c**4*d+693.d0*c**3*d**2+ &
                               & 594.d0*c**2*d**3+264.d0*c*d**4+48.d0*d**5)/(c**4*d**3*scpd**11)
               if (lcx > 2) vh(ipjp,3,ij,3)= 1.090474537178198d0*(16.d0*c**6+104.d0*c**5*d+286.d0*c**4*d**2+ &
                               & 429.d0*c**3*d**3+286.d0*c**2*d**4+104.d0*c*d**5+16.d0*d**6)/ &
                               & (c**4*d**4*scpd**13)

            end do
         end do
      end do
   end do

end subroutine crtvh
