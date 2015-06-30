!> template to be used to add different items to a list
!! included in dictionaries.f90
!header of routine
!!$   subroutine get_<template>(arr,dict)
!!$     use yaml_strings, only: yaml_toa
!!$     implicit none
!!$     <generic>, dimension(:), intent(out) :: arr
!!$     type(dictionary), intent(in) :: dict 
!!$     !local variables
!!$     <generic> :: tmp
  type(dictionary), pointer :: dict_tmp
  integer :: i

  !first check if the dictionary contains a scalar or a list
  if (dict%data%nitems > 0) then
     if (f_err_raise(dict%data%nitems/=size(arr),&
          'Array and dictionary differs in shape ( '//&
          trim(yaml_toa(size(arr)))//' and '//&
          trim(yaml_toa(dict%data%nitems))//')',&
          err_id=DICT_CONVERSION_ERROR)) return
     !start iterating in the list
     dict_tmp=>dict%child
     i=1
     do while(associated(dict_tmp))
        arr(i)=dict_tmp
        i=i+1
        dict_tmp=>dict_next(dict_tmp)
     end do
  else if (f_err_raise(dict%data%nelems > 0,&
       'Cannot convert mapping value in to arrays',&
       err_id=DICT_CONVERSION_ERROR)) then
     return
  else
     !scalar value, to be applied to all the values of the array
     tmp=dict
     arr=tmp
  end if

