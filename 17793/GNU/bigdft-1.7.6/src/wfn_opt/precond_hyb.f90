!> @file
!!   Routines to do preconditioning on wavefunctions
!! @author
!!    Copyright (C) 2010-2011 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!> Solves (KE+cprecr*I)*xx=yy by conjugate gradient method
!! x is the right hand side on input and the solution on output
subroutine precong_per_hyb(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     ncong,cprecr,hx,hy,hz,x,ibyz,ibxz,ibxy)
  use module_base
  implicit none
integer , intent(in) :: n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,ncong
  integer ,intent(in), dimension(2,0:n2,0:n3) :: ibyz
  integer ,intent(in), dimension(2,0:n1,0:n3) :: ibxz
  integer ,intent(in), dimension(2,0:n1,0:n2) :: ibxy
  integer , intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer , dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer , dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), dimension(nvctr_c+7*nvctr_f), intent(inout) :: x
  ! local variables
  real(gp), dimension(0:8) :: scal
  real(wp) :: rmr,rmr_new,alpha,beta
  integer :: i
  real(wp), dimension(:), allocatable :: b,r,d

  ! work arrays for adaptive wavelet data structure
  ! x_c and y_c are taken from the FFT arrays
  real(wp), allocatable, dimension(:,:,:,:) :: x_f
  real(wp), allocatable, dimension(:) :: x_f1,x_f2,x_f3
  real(wp), allocatable, dimension(:,:,:,:) :: y_f

  ! work arrays for FFT
  real(wp), dimension(:), allocatable :: kern_k1,kern_k2,kern_k3
  real(wp), dimension(:,:,:), allocatable :: x_c! in and out of Fourier preconditioning
  real(wp), dimension(:,:,:,:,:), allocatable::z1,z3 ! work array for FFT

  integer :: nd1,nd2,nd3
  integer :: n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b
  integer :: nf

  call dimensions_fft(n1,n2,n3,nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)

  nf=(nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)

  call allocate_all

  ! initializes the wavelet scaling coefficients 
  call wscal_init_per(scal,hx,hy,hz,cprecr)
  !b=x
  call vcopy(nvctr_c+7*nvctr_f,x(1),1,b(1),1) 

  ! compute the input guess x via a Fourier transform in a cubic box.
  ! Arrays psifscf and ww serve as work arrays for the Fourier
  !        prec_fft_fast(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
  !    cprecr,hx,hy,hz,hpsi,&
  !  kern_k1,kern_k2,kern_k3,z1,z3,x_c,&
  !  nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b)
  call prec_fft_fast(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
       cprecr,hx,hy,hz,x,&
       kern_k1,kern_k2,kern_k3,z1,z3,x_c,&
       nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b)

  call apply_hp_hyb(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
       cprecr,hx,hy,hz,x,d,x_f,x_c,x_f1,x_f2,x_f3,y_f,z1,nfl1,nfl2,nfl3,nfu1,nfu2,nfu3,nf,ibyz,ibxz,ibxy)

  r=b-d

  call wscal_per(nvctr_c,nvctr_f,scal,r(1),r(nvctr_c+1),d(1),d(nvctr_c+1))
  !rmr=dot_product(r,d)
  rmr=dot(nvctr_c+7*nvctr_f,r(1),1,d(1),1)
  do i=1,ncong
     !write(*,*)i,rmr
     !  write(*,*)i,sqrt(rmr)

     call apply_hp_hyb(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
          cprecr,hx,hy,hz,d,b,x_f,x_c,x_f1,x_f2,x_f3,y_f,z1,nfl1,nfl2,nfl3,nfu1,nfu2,nfu3,nf,ibyz,ibxz,ibxy)

     !alpha=rmr/dot_product(d,b)
     alpha=rmr/dot(nvctr_c+7*nvctr_f,d(1),1,b(1),1)
     x=x+alpha*d
     r=r-alpha*b

     call wscal_per(nvctr_c,nvctr_f,scal,r(1),r(nvctr_c+1),b(1),b(nvctr_c+1))
     !rmr_new=dot_product(r,b)
     rmr_new=dot(nvctr_c+7*nvctr_f,r(1),1,b(1),1)

     beta=rmr_new/rmr
     d=b+beta*d
     rmr=rmr_new
  enddo

  call deallocate_all()

contains

  subroutine allocate_all
    b = f_malloc(nvctr_c+7*nvctr_f,id='b')
    r = f_malloc(nvctr_c+7*nvctr_f,id='r')
    d = f_malloc(nvctr_c+7*nvctr_f,id='d')
    kern_k1 = f_malloc(0.to.n1,id='kern_k1')
    kern_k2 = f_malloc(0.to.n2,id='kern_k2')
    kern_k3 = f_malloc(0.to.n3,id='kern_k3')
    z1 = f_malloc((/ 2, nd1b, nd2, nd3, 2 /),id='z1')
    z3 = f_malloc((/ 2, nd1, nd2, nd3f, 2 /),id='z3')
    x_c = f_malloc((/ 0.to.n1, 0.to.n2, 0.to.n3 /),id='x_c')
    x_f = f_malloc((/ 1.to.7, nfl1.to.nfu1, nfl2.to.nfu2, nfl3.to.nfu3 /),id='x_f')
    x_f1 = f_malloc(nf,id='x_f1')
    x_f2 = f_malloc(nf,id='x_f2')
    x_f3 = f_malloc(nf,id='x_f3')
    y_f = f_malloc((/ 1.to.7, nfl1.to.nfu1, nfl2.to.nfu2, nfl3.to.nfu3 /),id='y_f')

  END SUBROUTINE allocate_all

  subroutine deallocate_all

    call f_free(b)
    call f_free(r)
    call f_free(d)
    call f_free(z1)
    call f_free(z3)
    call f_free(kern_k1)
    call f_free(kern_k2)
    call f_free(kern_k3)
    call f_free(x_c)
    call f_free(x_f)
    call f_free(x_f1)
    call f_free(x_f2)
    call f_free(x_f3)
    call f_free(y_f)

  END SUBROUTINE deallocate_all

END SUBROUTINE precong_per_hyb


!> Applies the operator (KE+cprecr*I)*x=y
!! array x is input, array y is output
subroutine apply_hp_hyb(n1,n2,n3, &
     nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,x,y,x_f,x_c,x_f1,x_f2,x_f3,y_f,y_c,nfl1,nfl2,nfl3,nfu1,nfu2,nfu3,nf,ibyz,ibxz,ibxy)
  use module_base
  implicit none
  integer , intent(in) :: n1,n2,n3
  integer ,intent(in) :: ibyz(2,0:n2,0:n3),ibxz(2,0:n1,0:n3),ibxy(2,0:n1,0:n2)
  integer ,intent(in) :: nfl1,nfl2,nfl3,nfu1,nfu2,nfu3,nf
  integer , intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer , dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer , dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(in) :: x(nvctr_c+7*nvctr_f)  
  real(wp), intent(out) :: y(nvctr_c+7*nvctr_f)
  !work arrays 
  real(wp) :: x_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3)
  real(wp) :: x_c(0:n1,0:n2,0:n3)
  real(wp) :: x_f1(nf),x_f2(nf),x_f3(nf)
  real(wp) :: y_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3)
  real(wp) :: y_c(0:n1,0:n2,0:n3)

  real(gp) :: hgrid(3)

  call uncompress_per_f(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
       nseg_f,nvctr_f,keyg(1,nseg_c+min(1,nseg_f)),keyv(nseg_c+min(1,nseg_f)),   &
       x(1),x(nvctr_c+min(1,nvctr_f)),x_c,x_f,x_f1,x_f2,x_f3,&
       nfl1,nfu1,nfl2,nfu2,nfl3,nfu3)

  hgrid(1)=hx
  hgrid(2)=hy
  hgrid(3)=hz

  call convolut_kinetic_hyb_c(n1,n2,n3, &
       nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,  &
       hgrid,x_c,x_f,y_c,y_f,cprecr,x_f1,x_f2,x_f3,ibyz,ibxz,ibxy)

  call compress_per_f(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   & 
       nseg_f,nvctr_f,keyg(1,nseg_c+min(1,nseg_f)),keyv(nseg_c+min(1,nseg_f)), & 
       y_c,y_f,y(1),y(nvctr_c+min(1,nvctr_f)),nfl1,nfl2,nfl3,nfu1,nfu2,nfu3)

END SUBROUTINE apply_hp_hyb

