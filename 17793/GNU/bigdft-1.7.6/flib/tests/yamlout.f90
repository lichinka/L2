!> @file
!! Routine to tests yaml_output module
!! @author
!!    Copyright (C) 2013-2013 BigDFT group
!!    This file is distributed oneder the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> First yaml document
subroutine test_yaml_output1()
  use yaml_output
  implicit none
  !local variables

  call yaml_mapping_open("Test")
   call yaml_map("Short sentence",.true.)
  !      call yaml_stream_attributes(iflowlevel=i,ilevel=l,ilast=j,indent=d,flowrite=fl,indent_previous=ip,icursor=ic)
  !      print *,'iflowlevel',i,'ilevel',l,'ilast',j,'indent',d,'flowrite',fl,'indent_previous',ip,'icursor',ic
   call yaml_mapping_open("Foo",flow=.true.)
    call yaml_map("one",1)
    call yaml_map("two",2)
   call yaml_mapping_close()
  !     call yaml_stream_attributes(iflowlevel=i,ilevel=l,ilast=j,indent=d,flowrite=fl,indent_previous=ip,icursor=ic)
  !     print *,'iflowlevel',i,'ilevel',l,'ilast',j,'indent',d,'flowrite',fl,'indent_previous',ip,'icursor',ic
  !      call yaml_stream_attributes()
  !      call yaml_scalar("1.0")
   call yaml_mapping_open("toto",flow=.true.)
    call yaml_map("one",1)
    call yaml_map("two",2)
   call yaml_mapping_close()
  !      call yaml_stream_attributes(iflowlevel=i,ilevel=l,ilast=j,indent=d)
  !      print *,'iflowlevel',i,'ilevel',l,'ilast',j,'indent',d
  call yaml_mapping_close()

  !verify also other properties
  call yaml_map('Is 1.0 a real string',is_atof('1.0'))
  call yaml_map('Is 1.0 a integer string',is_atoi('1.0'))
  call yaml_map('Is 1.0 a logical string',is_atol('1.0'))

  call yaml_map('Is 1 a real string',is_atof('1'))
  call yaml_map('Is 1 a integer string',is_atoi('1'))
  call yaml_map('Is 1 a logical string',is_atol('1'))

  call yaml_map('Is Yes a real string',is_atof('Yes'))
  call yaml_map('Is Yes a integer string',is_atoi('Yes'))
  call yaml_map('Is Yes a logical string',is_atol('Yes'))

  call yaml_map('Is No a real string',is_atof('No'))
  call yaml_map('Is No a integer string',is_atoi('No'))
  call yaml_map('Is No a logical string',is_atol('No'))

  call yaml_map('Is ./ a real string',is_atof('./'))
  call yaml_map('Is ./ a integer string',is_atoi('./'))
  call yaml_map('Is ./ a logical string',is_atol('./'))

  call yaml_map('Is 0. a real string',is_atof(' 0.'))
  call yaml_map('Is 0. a integer string',is_atoi(' 0.'))

  call yaml_map('Is 0.000000000E+00 a real string',is_atof(' 0.0000000000000000'))
  call yaml_map('Is 0.000000000E+00 a integer string',is_atoi(' 0.0000000000000000'))

end subroutine test_yaml_output1


!> Second yaml document
subroutine test_yaml_output2()
  use yaml_output
  implicit none
  !local variables
  integer :: i

  call yaml_mapping_open("Test")
    call yaml_map("I have a very long sentence in order to test if yaml_output fails to print that",.true.)
      call yaml_mapping_open("Foo",flow=.true.)
      call yaml_map("one",1)
      call yaml_map("two",2)
      call yaml_mapping_close()
      !call yaml_comment('Bug at this level!: the indentation is not correct')
      !Works if the comment is uncommented!!
      call yaml_mapping_open("toto",flow=.true.)
      call yaml_map("one",1)
      call yaml_map("two",2)
      call yaml_mapping_close()
      !another long sentence minimcking the configure output
      call yaml_map('Build Configure line','$(top_builddir)/src/flib/libflib.a '//&
           '-labinit -lxc   -lOpenCL -lm -lstdc++ -letsf_io_utils -letsf_io -lnetcdff -lnetcdf '//&
           '-lscalapack-openmpi -lblacs-openmpi -lblacsF77init-openmpi -llapack '//&
           '-lblas -larchive   -lyaml -pthread -lgthread-2.0 -lrt -lgio-2.0 '//&
           '-lgobject-2.0 -lglib-2.0   -lgio-2.0 -lgobject-2.0 -lglib-2.0    ')
      call yaml_map('Build Configure line again',&
           'FC=/opt/openmpi-1.6.1/bin/mpif90 FCFLAGS=-O2 -i_dynamic -msse4.2'//&
           ' -heap-arrays 1024 -openmp '//&
           '--with-ext-linalg=/opt/intel/composer_xe_2011_sp1'//&
           '.11.339/mkl/lib/intel64/libmkl_scalapack_lp64.a'//&
           '  -Wl,--start-group  /opt/intel/composer_xe_2011_sp1.11.339'//&
           '/mkl/lib/intel64/libmkl_cdft_core.a /opt/intel/composer_xe'//&
           '_2011_sp1.11.339/mkl/lib/intel64/libmkl_intel_lp64.a'//&
           ' /opt/intel/composer_xe_2011_sp1.11.339/mkl/lib/intel64'//&
           '/libmkl_intel_thread.a /opt/intel/composer_xe_2011_sp1.11.'//&
           '339/mkl/lib/intel64/libmkl_core.a /opt/intel/composer_xe_2011'//&
           '_sp1.11.339/mkl/lib/intel64/libmkl_blacs_openmpi_lp64.a '//&
           '-Wl,--end-group -openmp -lpthread -lm')
      call yaml_map('Long string array',(/('compiler',i=1,10)/))
   call yaml_mapping_close()
!stop
end subroutine test_yaml_output2


!> Test of sequences
subroutine test_yaml_output_sequences1()
  use yaml_output
  implicit none
  !local variables
  integer :: i
  character(len=10), dimension(:), allocatable :: cv
  integer, dimension(:), allocatable :: iv
  real(kind=8), dimension(:), allocatable :: dv
  
  
  allocate(cv(0))
  allocate(iv(0))
  !This raises a bug for a vector which is too long
  allocate(dv(11))
  dv=3.d0

   call yaml_map('Vector of characters',cv)
   call yaml_map('Vector of integers',iv)
   !call yaml_stream_attributes()
   call yaml_mapping_open('Is it OK?',flow=.true.)
   call yaml_map('Maybe',.true.)
   call yaml_map('Maybe',.false.)
   call yaml_mapping_close(advance='yes')
   call yaml_sequence_open('Vector of double',flow=.true.)
      do i=1,size(dv)
         call yaml_sequence(trim(yaml_toa(dv(i),fmt='(1pe12.5)')))
   end do
   call yaml_sequence_close()

   call yaml_map('Vector of real(kind=8)',dv,fmt='(f3.0)')

   deallocate(cv)
   deallocate(iv)
   deallocate(dv)

end subroutine test_yaml_output_sequences1


!> Second test of sequences
subroutine test_yaml_output_sequences2()
  use yaml_output
  implicit none
  !local variables
  real(kind=8), dimension(:), allocatable :: dv

  allocate(dv(5))
  dv=1.d0

  !Check a comment
  call yaml_comment('This document checks the call yaml_comment().')
  call yaml_comment(trim(yaml_toa(dv, fmt='(f14.10)')))
  !Check a very long comment
  call yaml_comment('See if this very long comment is correctly treated:' // &
       & trim(yaml_toa(dv, fmt='(f14.10)')))
  call yaml_mapping_open('Map')
  call yaml_map('One',1)
  call yaml_comment('No blank characters'//repeat('x',500))
  !Check a message with blank characters
  call yaml_comment(repeat(' ',200))
  call yaml_comment(repeat('y',200),hfill='-')
  call yaml_comment(repeat('y',200),tabbing=9,hfill='-')
  call yaml_mapping_close()

  deallocate(dv)
end subroutine test_yaml_output_sequences2
