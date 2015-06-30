!> @file
!!  template to be used to add different items to a list
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS

!! included in dictionaries.f90
!header of routine
!!$  subroutine add(dict,val)
!!$    implicit none
!!$    type(dictionary), pointer :: dict
!!$    <generic>, intent(in) :: val
  !local variables
  integer :: length,isize

  isize=dict_size(dict)
  length=dict_len(dict)

  if (f_err_raise(isize > 0,'Add not allowed for this node',&
       err_id=DICT_INVALID_LIST)) return
  if (f_err_raise(length == -1,'Add not allowed for this node',&
       err_id=DICT_INVALID)) return

  call set(dict//length,val)

