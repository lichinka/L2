!> @file
!!  Module defining a dictionary
!! @author Luigi Genovese
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 


!> Module which defines a dictionary (à la python) and its basic usage rules
module dictionaries
   use exception_callbacks
   use dictionaries_base
   use yaml_strings, only: read_fraction_string,yaml_toa,f_strcpy
   implicit none

   private

   !> Public to be used in list_new() constructor.
   type, public :: list_container
      character(len=max_field_length) :: val=' '
      type(dictionary), pointer :: dict => null()
   end type list_container
   !> Public to be used in dict_new() constructor.
   type, public :: dictionary_container
      character(len=max_field_length) :: key=' '
      character(len=max_field_length) :: value=' '
     type(dictionary), pointer :: child => null()
   end type dictionary_container

   type, public :: f_dict 
      type(dictionary), pointer :: d =>null()
   end type f_dict

   !> Error codes
   integer, save, public :: DICT_KEY_ABSENT
   integer, save, public :: DICT_VALUE_ABSENT
   integer, save, public :: DICT_ITEM_NOT_VALID
   integer, save, public :: DICT_CONVERSION_ERROR
   integer, save, public :: DICT_INVALID_LIST
   integer, save, public :: DICT_INVALID

   !control the error enviromnment (see error_handling.f90)
   logical :: try_environment=.false.

   interface operator(.index.)
      module procedure find_index
   end interface

   interface operator(.item.)
      module procedure item_char,item_dict,item_dbl,item_int
   end interface

   interface operator(.is.)
      module procedure dict_cont_new_with_value, dict_cont_new_with_dict
      module procedure dict_cont_new_with_int,dict_cont_new_with_dbl
      module procedure dict_cont_new_with_int_v,dict_cont_new_with_dbl_v,dict_cont_new_with_value_v
   end interface 

   interface operator(.in.)
      module procedure key_in_dictionary
   end interface 

   interface operator(.notin.)
      module procedure key_notin_dictionary
   end interface 

   interface operator(.pop.)
      module procedure pop_key,pop_item
   end interface 

!   interface operator(.poplast.)
!      module procedure pop_last_item
!   end interface operator(.poplast.)


   interface operator(==)
      module procedure dicts_are_equal
   end interface

   interface operator(/=)
      module procedure dicts_are_not_equal
   end interface

   interface assignment(=)
      module procedure get_value,get_integer,get_real,get_double,get_long,get_lg
      module procedure get_rvec,get_dvec,get_ilvec,get_ivec,get_lvec,get_c1vec
      !safe getter from list_container
      module procedure safe_get_dict,safe_get_integer,safe_get_double,safe_get_real,safe_get_char
   end interface

   interface dict_remove
      module procedure remove_dict,remove_item
   end interface

   interface set
      module procedure put_child,put_value,put_list,put_integer,put_real,put_double,put_long,put_lg
      module procedure put_listd,put_listi
   end interface

   interface add
      module procedure add_char,add_dict,add_integer,add_real,add_double,add_long, add_log
   end interface

   !> Used to retrieve the pointer to the dictionary which has the key,
   !! if the keys exists. In the case it does not, it returns a nullified dictionary
   !! should be used in assignments, like for example val= dict .get. "key"
   interface operator(.get.)
      module procedure list_container_if_key_exists
   end interface

   interface dict_iter
      module procedure dict_iter, dict_iter_lc
   end interface


   interface list_new
      module procedure list_new,list_new_elems
   end interface

   interface dict_new
      module procedure dict_new,dict_new_elems
   end interface

   integer(kind=8), external :: f_loc

   !> Public routines
   public :: operator(//),operator(.index.),assignment(=)
   public :: set,dict_init,dict_free,append,prepend,add
   public :: dict_copy, dict_update,dict_remove,dict_remove_last
   !> Handle exceptions
   public :: find_key,dict_len,dict_size,dict_key,dict_item,dict_value,dict_next
   public :: dict_new,list_new,dict_iter,has_key,dict_keys
   !> Public elements of dictionary_base
   public :: operator(.is.),operator(.item.)
   public :: operator(.pop.),operator(.notin.)
   public :: operator(==),operator(/=),operator(.in.),operator(.get.)
   public :: dictionary,max_field_length,dict_get_num


   !> Header of error handling part
   !! Some parameters
   character(len=*), parameter :: ERRID='Id'
   character(len=*), parameter :: ERRMSG='Message'
   character(len=*), parameter :: ERRACT='Action'
   character(len=*), parameter :: ERRCLBK='Callback Procedure Address'
   character(len=*), parameter :: ERRCLBKADD='Callback Procedure Data Address'

   character(len=*), parameter :: ERRUNSPEC='UNSPECIFIED'
   character(len=*), parameter :: ERRUNDEF='UNKNOWN'

   character(len=*), parameter :: ERR_ADD_INFO='Additional Info'

   integer :: ERR_GENERIC,ERR_SUCCESS,ERR_NOT_DEFINED

   type(dictionary), pointer :: dict_errors=>null()        !< the global dictionaries of possible errors, nullified if not initialized
   type(dictionary), pointer :: dict_present_error=>null() !< local pointer of present error, nullified if success
  
   
   !> Stack of dict_present_error for nested try (opne and close)
   type, private :: error_stack
     type(dictionary), pointer :: current => null()   !< dict_present_error point to here.
     type(error_stack), pointer :: previous => null() !< previous error
   end type error_stack

   type(error_stack), pointer :: error_pipelines=>null() !< Stack of errors for try clause
 

   !> Public variables of the error handling module
   public :: f_err_initialize,f_err_finalize
   !!@todo Change the names into f_err_xxx
   public :: f_get_last_error,f_get_error_definitions,f_get_error_dict
   public :: f_err_define
   public :: f_err_check,f_err_raise,f_err_clean,f_err_pop,f_err_throw


   ! Public variables of the callback module
   public :: f_err_set_callback,f_err_unset_callback
   public :: f_err_open_try,f_err_close_try
   public :: f_err_severe,f_err_severe_override,f_err_severe_restore,f_err_ignore
   public :: f_loc,f_get_past_error,f_get_no_of_errors

   !for internal f_lib usage
   public :: dictionaries_errors,TYPE_DICT,TYPE_LIST


contains


   !> Define the errors of the dictionary module
   subroutine dictionaries_errors()
     implicit none

     !Initialize the dictionary with the generic case
     call f_err_define('SUCCESS','Operation has succeeded',ERR_SUCCESS,err_action='No action')
     call f_err_define('GENERIC_ERROR',errunspec,ERR_GENERIC,err_action=errundef)
     call f_err_define('ERR_NOT_DEFINED','The error id or name is invalid',ERR_NOT_DEFINED,&
          err_action='Control if the err id exists')

     !Initalize also error of dictionary part of the module
     call f_err_define('DICT_KEY_ABSENT',&
          'The dictionary has no key',DICT_KEY_ABSENT,&
          err_action='Internal error, contact developers')
     call f_err_define('DICT_ITEM_NOT_VALID',&
          'The item of this list is not correct',DICT_ITEM_NOT_VALID,&
          err_action='Internal error, contact developers')
     call f_err_define('DICT_VALUE_ABSENT',&
          'The value for this key/value is absent',DICT_VALUE_ABSENT)
     call f_err_define('DICT_INVALID',&
          'Dictionary is not associated',DICT_INVALID)
     call f_err_define('DICT_INVALID_LIST',&
          'Current node is not a list',DICT_INVALID_LIST)
     call f_err_define('DICT_CONVERSION_ERROR',&
          'Conversion error of the dictionary value',DICT_CONVERSION_ERROR,&
          err_action='Check the nature of the conversion')

   end subroutine dictionaries_errors

   !> Pop a subdictionary from a mother one. Returns the subdictionary.
   !! raise an error if the subdictionary does not exists.
   function pop_key(dict,key) result(subd)
     implicit none
     !> As Fortran norm says, here the intent is refererred to the 
     !! pointer association status
     type(dictionary), pointer, intent(in) :: dict 
     character(len=*), intent(in) :: key
     type(dictionary), pointer :: subd
     !local variables
     integer :: indx
     !type(dictionary), pointer :: dict_item

     nullify(subd)
     indx=-1

     !first, identify whether the subdictionary exists
     if (dict_size(dict) > 0) then !popping from a hash key
        subd=>find_key(dict,key)
     else if (dict_len(dict) > 0) then !popping from a list value
        indx=find_index(dict,key)
     end if
     
     !if something has been found, pop
     !!WARNING: here the usage of dict_remove is abused,
     !!as this routine frees dict if it is the last object
     !!therefore it changes the pointer association status of dict
     if (associated(subd)) then
        call dict_remove(dict,key,destroy=.false.)
     else if (indx > -1) then
        subd => pop_item(dict,indx)
     else
        call f_err_throw('Dictionary or list does not have "'//&
             trim(key)//'", pop not possible',&
             err_id=DICT_ITEM_NOT_VALID)
     end if

   end function pop_key

   !> Pop a subdictionary from a mother one. Returns the subdictionary.
   !! raise an error if the subdictionary does not exists.
   function pop_item(dict,item) result(subd)
     use yaml_strings, only: yaml_toa
     implicit none
     !> As Fortran norm says, here the intent is refererred to the 
     !! pointer association status
     type(dictionary), pointer, intent(in) :: dict 
     integer, intent(in) :: item
     type(dictionary), pointer :: subd
     !local variables
     !type(dictionary), pointer :: dict_item

     nullify(subd)

     !first, identify whether the subdictionary exists
     if (dict_size(dict) > 0) then !popping from a hash key
        call f_err_throw('Dictionary is not a list, pop of an item is not allowed',&
             err_id=DICT_ITEM_NOT_VALID)
        return
     else if (item > dict_len(dict)-1 .or. item < 0) then !popping from a list value
        call f_err_throw('Item outside range, length='//&
             trim(yaml_toa(dict_len(dict)))//' item='//&
             trim(yaml_toa(item)),err_id=DICT_ITEM_NOT_VALID)
        return
     end if
     
     !if something has been found, pop
     !!WARNING: here the usage of dict_remove is abused,
     !!as this routine frees dict if it is the last object
     !!therefore it changes the pointer association status of dict
     !call dict_init(dict_item)
     !call dict_copy(dict_item,dict//item)
     subd => dict//item
     call dict_remove(dict,item,destroy=.false.)

   end function pop_item

   !> Pop last item from a list
   !function pop_last_item(dict) result(subd)
   !  !> As Fortran norm says, here the intent is refererred to the 
   !  !! pointer association status
   !  type(dictionary), pointer, intent(in) :: dict 
   !  type(dictionary), pointer :: subd

   !  subd => pop_item(dict,dict_len(dict)-1)
   !end function pop_last_item



   !> Eliminate a key from a dictionary if it exists
   subroutine remove_dict(dict,key,destroy)
     implicit none
     type(dictionary), pointer :: dict 
     character(len=*), intent(in) :: key
     logical, intent(in), optional :: destroy
     !local variables
     logical :: dst

     dst=.true.
     if (present(destroy)) dst=destroy
     if (.not. associated(dict)) then
        call f_err_throw('Cannot remove keys from nullified dictionary',&
             err_id=DICT_INVALID)
        return
     end if
     !check if we are at the first level
     call pop_dict_(dict%child,key,dst)
     !if it is the last the dictionary should be empty
     if (.not. associated(dict%parent) .and. .not. associated(dict%child)) then
        call dict_free(dict)
     end if

   contains

     recursive subroutine pop_dict_(dict,key,dst)
       implicit none
       type(dictionary), intent(inout), pointer :: dict 
       character(len=*), intent(in) :: key
       logical, intent(in) :: dst
       !local variables
       type(dictionary), pointer :: dict_first !<in case of first occurrence

!!$       !$ logical :: key_found
!!$       !$ type(dictionary), pointer :: iter       !< iterator to avoid stack overflow
!!$       iter => dict
!!$       key_found=.false.
!!$       find_key: do while(associated(iter))
!!$          !follow the chain, stop at the first occurence
!!$          print *,'search',trim(key),trim(iter%data%key)
!!$          if (trim(iter%data%key) == trim(key)) then
!!$             if (associated(iter%parent)) then
!!$                iter%parent%data%nelems=iter%parent%data%nelems-1
!!$             else
!!$                iter%data%nelems=iter%data%nelems-1
!!$             end if
!!$             dict_first => dict_extract(iter)
!!$             if (dst) call dict_free(dict_first)
!!$             key_found=.true.
!!$             exit find_key
!!$          end if
!!$          iter => iter%next
!!$       end do find_key
!!$       if (.not. key_found) call f_err_throw(err_msg='Key is '//trim(key),&
!!$            err_id=DICT_KEY_ABSENT)

      if (associated(dict)) then
         !follow the chain, stop at the first occurence
         if (trim(dict%data%key) == trim(key)) then
            !          print *,'here',trim(key),associated(dict%next)
            if (associated(dict%parent)) then
               dict%parent%data%nelems=dict%parent%data%nelems-1
            else
               dict%data%nelems=dict%data%nelems-1
            end if
!!!!$             if (associated(dict%next)) then
!!!!$                call dict_free(dict%child)
!!!!$                dict_first => dict
!!!!$                !this is valid if we are not at the first element
!!!!$                if (associated(dict%previous)) then
!!!!$                   call define_brother(dict%previous,dict%next) 
!!!!$                   dict%previous%next => dict%next
!!!!$                else
!!!!$                   nullify(dict%next%previous)
!!!!$                   !the next should now become me
!!!!$                   dict => dict%next
!!!!$                end if
!!!!$                !eliminate the top of the tree
!!!!$                !but do not follow the nexts
!!!!$                call dict_destroy(dict_first)
!!!!$             else
!!!!$                call dict_free(dict)
!!!!$             end if
            dict_first => dict_extract(dict)
            if (dst) call dict_free(dict_first)

         else if (associated(dict%next)) then
            call pop_dict_(dict%next,key,dst)
         else
            call f_err_throw(err_msg='Key is '//trim(key),&
                 err_id=DICT_KEY_ABSENT)
            return
         end if
      else
         call f_err_throw(err_msg='Key is '//trim(key),&
              err_id=DICT_KEY_ABSENT)
         return
      end if

     end subroutine pop_dict_
   end subroutine remove_dict

   !>extract the dictionary from its present context
   !! in the case of a list renumber the items
   !! return an object which is ready to be freed
   function dict_extract(dict) result(dict_first)
     implicit none
     type(dictionary), pointer, intent(inout) :: dict
     type(dictionary), pointer :: dict_first
     !local variables
     type(dictionary), pointer :: dict_update

     !normal association initially
     dict_first => dict
     !then check if there are brothers which have to be linked
     if (associated(dict%next)) then
        !this is valid if we are not at the first element
        if (associated(dict%previous)) then
           call define_brother(dict%previous,dict%next) 
           dict%previous%next => dict%next
        else
           nullify(dict%next%previous)
           !the next should now become me
           dict => dict%next
        end if
        !in case we were in a list, renumber the other brothers
        ! Update data%item for all next.
        if (dict_first%data%item >= 0) then
           dict_update => dict_first%next
           do while( associated(dict_update) )
              dict_update%data%item = dict_update%data%item - 1
              dict_update => dict_update%next
           end do
        end if
     else
        nullify(dict)
     end if
     !never follow the brothers, the extracted dictionary is 
     !intended to be alone
     nullify(dict_first%next,dict_first%previous)
     dict_first%data%item=-1
     !the extraction should provide the child in the case of 
     !a dict value or otherwise a dictionary with only a value
     !in the case of a scalar value
     

   end function dict_extract

   

   !> Add to a list
   subroutine add_char(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_char
   subroutine add_dict(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     type(dictionary), pointer :: val
     include 'dict_add-inc.f90'
   end subroutine add_dict
   subroutine add_integer(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     integer, intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_integer
   subroutine add_real(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     real, intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_real
   subroutine add_double(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     double precision, intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_double
   subroutine add_long(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     integer(kind=8), intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_long
   subroutine add_log(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     logical, intent(in) :: val
     include 'dict_add-inc.f90'
   end subroutine add_log

   !> Defines a dictionary from a array of storage data
   function dict_new(dicts)
!     use yaml_output
!     type(storage), dimension(:), intent(in) :: st_arr
     type(dictionary_container), dimension(:), intent(in) :: dicts
     type(dictionary), pointer :: dict_new
     !local variables
     integer :: i_st,n_st
     type(dictionary), pointer :: dict_tmp

     !initialize dictionary
     call dict_init(dict_tmp)
     n_st=size(dicts)
     do i_st=1,n_st
        if (associated(dicts(i_st)%child)) then
           call set(dict_tmp//dicts(i_st)%key, dicts(i_st)%child)
        else
           call set(dict_tmp//dicts(i_st)%key, dicts(i_st)%value)
        end if
     end do
     dict_new => dict_tmp
   end function dict_new

   !> Defines a dictionary from a array of storage data
   function dict_new_elems(dict0, dict1, dict2, dict3, dict4, dict5, dict6, dict7, dict8, dict9, &
        & dict10, dict11, dict12, dict13, dict14, dict15, dict16, dict17, dict18, dict19)
     type(dictionary_container), intent(in), optional :: dict0, dict1, dict2, dict3, dict4
     type(dictionary_container), intent(in), optional :: dict5, dict6, dict7, dict8, dict9
     type(dictionary_container), intent(in), optional :: dict10, dict11, dict12, dict13, dict14
     type(dictionary_container), intent(in), optional :: dict15, dict16, dict17, dict18, dict19
     type(dictionary), pointer :: dict_new_elems
     !local variables
     type(dictionary), pointer :: dict_tmp

     call dict_init(dict_tmp)
     if (present(dict0)) call add_elem(dict_tmp, dict0)
     if (present(dict1)) call add_elem(dict_tmp, dict1)
     if (present(dict2)) call add_elem(dict_tmp, dict2)
     if (present(dict3)) call add_elem(dict_tmp, dict3)
     if (present(dict4)) call add_elem(dict_tmp, dict4)
     if (present(dict5)) call add_elem(dict_tmp, dict5)
     if (present(dict6)) call add_elem(dict_tmp, dict6)
     if (present(dict7)) call add_elem(dict_tmp, dict7)
     if (present(dict8)) call add_elem(dict_tmp, dict8)
     if (present(dict9)) call add_elem(dict_tmp, dict9)
     if (present(dict10)) call add_elem(dict_tmp, dict10)
     if (present(dict11)) call add_elem(dict_tmp, dict11)
     if (present(dict12)) call add_elem(dict_tmp, dict12)
     if (present(dict13)) call add_elem(dict_tmp, dict13)
     if (present(dict14)) call add_elem(dict_tmp, dict14)
     if (present(dict15)) call add_elem(dict_tmp, dict15)
     if (present(dict16)) call add_elem(dict_tmp, dict16)
     if (present(dict17)) call add_elem(dict_tmp, dict17)
     if (present(dict18)) call add_elem(dict_tmp, dict18)
     if (present(dict19)) call add_elem(dict_tmp, dict19)
     dict_new_elems => dict_tmp
   contains
     subroutine add_elem(dict, elem)
       implicit none
       type(dictionary_container), intent(in) :: elem
       type(dictionary), pointer :: dict

       if (associated(elem%child)) then
          call set(dict//elem%key, elem%child)
       else
          call set(dict//elem%key, elem%value)
       end if
     end subroutine add_elem
   end function dict_new_elems


   !> Defines a new dictionary from a key and a value
   !pure 
   function dict_cont_new_with_value(key, val) result(cont)
     implicit none
     character(len = *), intent(in) :: val
     include 'dict_cont-inc.f90'
   end function dict_cont_new_with_value

   pure function dict_cont_new_with_int(key, val) result(cont)
     implicit none
     integer, intent(in) :: val
     include 'dict_cont-inc.f90'
   end function dict_cont_new_with_int

   pure function dict_cont_new_with_dbl(key, val) result(cont)
     implicit none
     double precision, intent(in) :: val
     include 'dict_cont-inc.f90'
   end function dict_cont_new_with_dbl

   function dict_cont_new_with_dict(key, val)
     implicit none
     character(len = *), intent(in) :: key
     type(dictionary), pointer, intent(in) :: val
     type(dictionary_container) :: dict_cont_new_with_dict

     dict_cont_new_with_dict%key(1:max_field_length) = key
     dict_cont_new_with_dict%child => val

   end function dict_cont_new_with_dict

   !arrays
   function dict_cont_new_with_value_v(key, val) result(cont)
     implicit none
     character(len = *), dimension(:), intent(in) :: val
     include 'dict_cont_arr-inc.f90'
   end function dict_cont_new_with_value_v

   function dict_cont_new_with_dbl_v(key, val) result(cont)
     implicit none
     double precision, dimension(:), intent(in) :: val
     include 'dict_cont_arr-inc.f90'
   end function dict_cont_new_with_dbl_v

   function dict_cont_new_with_int_v(key, val) result(cont)
     implicit none
     integer, dimension(:), intent(in) :: val
     include 'dict_cont_arr-inc.f90'
   end function dict_cont_new_with_int_v


   !>initialize the iterator to be used with next
   function dict_iter(dict)
     implicit none
     type(dictionary), pointer, intent(in) :: dict
     type(dictionary), pointer :: dict_iter

     if (associated(dict)) then
        dict_iter=>dict%child
     else
        nullify(dict_iter)
     end if
   end function dict_iter

   !>version of the function to be used with list container
   !! to be used when .get. operator is called
   function dict_iter_lc(list)
     implicit none
     type(list_container), intent(in) :: list
     type(dictionary), pointer :: dict_iter_lc

     dict_iter_lc => dict_iter(list%dict)

   end function dict_iter_lc


   function dict_next(dict)
     implicit none
     type(dictionary), pointer, intent(in) :: dict
     type(dictionary), pointer :: dict_next

     if (associated(dict)) then
        if (associated(dict%parent)) then
           dict_next=>dict%next
        else
           dict_next=>dict%child
        end if
     else
        nullify(dict_next)
     end if
   end function dict_next

   function dicts_are_not_equal(dict1,dict2) result(notequal)
     use yaml_strings, only: is_atoi,is_atof,is_atol
     implicit none
     type(dictionary), pointer, intent(in) :: dict1,dict2
     logical :: notequal
     
     notequal= .not. dicts_are_equal(dict1,dict2)
   end function dicts_are_not_equal

   !> Function verifying the dictionaries are equal to each other
   !! this function is not checking whether the dictionary are deep copy of each other or not
   function dicts_are_equal(dict1,dict2) result(equal)
     use yaml_strings, only: is_atoi,is_atof,is_atol
     implicit none
     type(dictionary), pointer, intent(in) :: dict1,dict2
     logical :: equal
     
     !no next for the first level
     equal=nodes_are_equal(dict1,dict2)

     contains
       
       recursive function nodes_are_equal(dict1,dict2) result(yes)
         implicit none
         type(dictionary), pointer, intent(in) :: dict1,dict2
         logical :: yes
         !local variables
         logical :: l1,l2
         integer :: i1,i2
         double precision :: r1,r2

         
         !dictionaries associated
         yes = (associated(dict1) .eqv. associated(dict2))
         if (.not. yes .or. .not. associated(dict1)) return
         
         !same (type of) value
         yes = dict_value(dict1) == dict_value(dict2)
         !print *,'debug',dict_value(dict1),' and ',dict_value(dict2), 'also',&
         !     is_atof(dict_value(dict1)), is_atof(dict_value(dict2)),yes
         if (.not. yes) then 
            !investigate if the values are just written differenty
            !integer case
            if (is_atoi(dict_value(dict1)) .and. is_atoi(dict_value(dict2))) then
               i1=dict1
               i2=dict2
               yes=i1==i2
            else if (is_atof(dict_value(dict1)) .and. is_atof(dict_value(dict2))) then
               r1=dict1
               r2=dict2
               yes=r1==r2
            else if (is_atol(dict_value(dict1)) .and. is_atol(dict_value(dict2))) then
               l1=dict1
               l2=dict2
               yes=l1.eqv.l2
            end if
            if (.not. yes) return
         end if
         yes = (dict_size(dict1) == dict_size(dict2)) .and. & !both are (or not) mappings
              (dict_len(dict1) == dict_len(dict2)) !.and. & !both are (or not) lists
         !print *,'here',yes,dict_size(dict1),dict_size(dict2),dict_len(dict1),dict_len(dict2)
         if (.not. yes) return
         yes=dicts_are_equal_(dict1%child,dict2%child) 
       end function nodes_are_equal

       recursive function dicts_are_equal_(dict1,dict2) result(yess)
         implicit none
         type(dictionary), pointer, intent(in) :: dict1,dict2
         logical :: yess
         
         yess= nodes_are_equal(dict1,dict2)
         if (.not. yess .or. .not. associated(dict1) ) return

         yess=dicts_are_equal_(dict1%next,dict2%next) 
       end function dicts_are_equal_

 end function dicts_are_equal


   !> Returns the position of the name in the dictionary
   !! returns -1 if the dictionary is nullified or the name is absent
   function find_index(dict,name)
     implicit none
     type(dictionary), pointer, intent(in) :: dict
     character(len=*), intent(in) :: name
     integer :: find_index
     !local variables
     integer :: ind
     type(dictionary), pointer :: dict_tmp

     find_index =-1
     ind=-1
     if (associated(dict)) then
        dict_tmp=>dict_next(dict)
        loop_find: do while(associated(dict_tmp))
           ind=ind+1
           if (name_is(dict_tmp,name)) then
              find_index=ind
              exit loop_find
           end if
           dict_tmp=>dict_next(dict_tmp)
        end do loop_find
     end if

   end function find_index


   subroutine dict_remove_last(dict)
     implicit none
     type(dictionary), pointer :: dict 
     !local variables
     integer :: nitems

     nitems=dict_len(dict)

     if (f_err_raise(nitems <= 0,'Remove not allowed for this node',&
          err_id=DICT_ITEM_NOT_VALID)) then
        return
     else
        call remove_item(dict,nitems-1)
     end if

   end subroutine dict_remove_last


   subroutine remove_item(dict,item,destroy)
     implicit none
     type(dictionary), pointer :: dict 
     integer, intent(in) :: item
     logical, intent(in), optional :: destroy
     !local variables
     logical :: dst

     dst=.true.
     if (present(destroy)) dst=destroy
     if (.not. associated(dict)) then
        call f_err_throw('Cannot remove item from nullified dictionary',&
        err_id=DICT_INVALID)
        return
     end if

     !check if we are at the first level
 !!TEST   if (associated(dict%parent)) then
        call pop_item_(dict%child,item,dst)
        !if it is the last the dictionary should be empty
        if (.not. associated(dict%parent) .and. .not. associated(dict%child)) then
           call dict_free(dict)
        end if

!TTEST    else
!TTEST       call pop_item_(dict,item)
!TTEST    end if
   contains
     !> Eliminate a key from a dictionary if it exists
     recursive subroutine pop_item_(dict,item,dst)
       use yaml_strings, only: yaml_toa
       implicit none
       type(dictionary), intent(inout), pointer :: dict 
       integer, intent(in) :: item
       logical, intent(in) :: dst
       !local variables
       type(dictionary), pointer :: dict_first !<in case of first occurrence
!!$       type(dictionary), pointer :: dict_update !<dict to update data%item field

       if (associated(dict)) then
!          print *,dict%data%item,trim(dict%data%key)
          !follow the chain, stop at the first occurence
          if (dict%data%item == item) then
             if (associated(dict%parent)) then
                dict%parent%data%nitems=dict%parent%data%nitems-1
             end if
!!$             if (associated(dict%next)) then
!!$                call dict_free(dict%child)
!!$                dict_first => dict
!!$                !this is valid if we are not at the first element
!!$                if (associated(dict%previous)) then
!!$                   call define_brother(dict%previous,dict%next) 
!!$                   dict%previous%next => dict%next
!!$                else
!!$                   !the next should now become me
!!$                   dict => dict%next
!!$                end if
!!$                ! Update data%item for all next.
!!$                dict_update => dict_first%next
!!$                do while( associated(dict_update) )
!!$                   dict_update%data%item = dict_update%data%item - 1
!!$                   dict_update => dict_update%next
!!$                end do
!!$                call dict_destroy(dict_first)
!!$             else
!!$                call dict_free(dict)
!!$             end if
             dict_first => dict_extract(dict)
             if (dst) call dict_free(dict_first)
          else if (associated(dict%next)) then
             call pop_item_(dict%next,item,dst)
          else
             if (f_err_raise(err_msg='Item No. '//trim(yaml_toa(item)),&
                  err_id=DICT_ITEM_NOT_VALID)) return
          end if
       else
          if (f_err_raise(err_msg='Item No. '//trim(yaml_toa(item)),&
               err_id=DICT_ITEM_NOT_VALID)) return
       end if

     end subroutine pop_item_
   end subroutine remove_item


   !> Retrieve the pointer to the dictionary which has this key.
   !! If the key does not exists, search for it in the next chain 
   !! Key Must be already present, otherwise result is nullified
   recursive function find_key(dict,key) result (dict_ptr)
     implicit none
     type(dictionary), intent(in), pointer :: dict !< Hidden inout
     character(len=*), intent(in) :: key
     type(dictionary), pointer :: dict_ptr
     if (.not. associated(dict)) then
        nullify(dict_ptr)
        return
     end if

     if (.not. associated(dict%parent)) then
        dict_ptr => find_key(dict%child,key)
        return
     end if

     dict_ptr => get_dict_from_key(dict,key)
!!$     !print *,'here ',trim(key),', key ',trim(dict%data%key)
!!$     !follow the chain, stop at the first occurence
!!$     if (trim(dict%data%key) == trim(key)) then
!!$        dict_ptr => dict
!!$     else if (associated(dict%next)) then
!!$        dict_ptr => find_key(dict%next,key)
!!$     else 
!!$        nullify(dict_ptr)
!!$     end if

   end function find_key

   function dict_keys(dict)
     implicit none
     type(dictionary), intent(in) :: dict !<the dictionary must be associated
     character(len=max_field_length), dimension(dict%data%nelems) :: dict_keys
     !local variables
     integer :: ikey
     type(dictionary), pointer :: dict_tmp

     !if (associated(dict)) then
        ikey=0
        dict_tmp=>dict%child
        do while(associated(dict_tmp))
           ikey=ikey+1
           dict_keys(ikey)=dict_key(dict_tmp)
           dict_tmp=>dict_tmp%next
        end do
     !end if

   end function dict_keys

   function key_in_dictionary(key,dict)
     implicit none
     type(dictionary), intent(in), pointer :: dict 
     character(len=*), intent(in) :: key
     logical :: key_in_dictionary
     
     !if it is a list check the value
     if (dict_len(dict) > 0) then
        key_in_dictionary = (dict .index. key) >= 0
     else
        key_in_dictionary=has_key(dict,key)
     end if
   end function key_in_dictionary

   function key_notin_dictionary(key,dict)
     implicit none
     type(dictionary), intent(in), pointer :: dict 
     character(len=*), intent(in) :: key
     logical :: key_notin_dictionary

     key_notin_dictionary=.not. key_in_dictionary(key,dict)
   end function key_notin_dictionary


   !> Search in the dictionary if some of the child has the given
   !! If the key does not exists, search for it in the next chain 
   !! Key Must be already present 
   !! the search in the linked list can be performed
   !! by using the new scheme under implementation
   !! which is not using pointer associations
   function has_key(dict,key)
     implicit none
     type(dictionary), intent(in), pointer :: dict 
     character(len=*), intent(in) :: key
     logical :: has_key

     if (.not. associated(dict) .or. trim(key) == "") then
        has_key=.false.
        return
     end if
     has_key=associated(dict%child)
     !has_key_(dict%child,key)
     if (has_key) has_key=associated(get_dict_from_key(dict%child,key))

!!$   contains
!!$
!!$     recursive function has_key_(dict,key) result(has)
!!$       implicit none
!!$       type(dictionary), intent(in), pointer :: dict 
!!$       character(len=*), intent(in) :: key
!!$       logical :: has
!!$       if (.not. associated(dict)) then
!!$          has=.false.
!!$          return
!!$       end if
!!$
!!$       !print *,'here ',trim(key),', key ',trim(dict%data%key)
!!$       !follow the chain, stop at the first occurence
!!$       if (trim(dict%data%key) == trim(key)) then
!!$          has=.true.
!!$       else if (associated(dict%next)) then
!!$          has=has_key_(dict%next,key)
!!$       else 
!!$          has=.false.
!!$       end if
!!$
!!$     end function has_key_
   end function has_key


   !> Assign a child to the dictionary
   recursive subroutine put_child(dict,subd)
     implicit none
     type(dictionary), pointer :: dict
     type(dictionary), pointer :: subd

     !if the dictionary starts with a master tree, eliminate it and put the child
     if (.not. associated(subd%parent) .and. associated(subd%child)) then
        call put_child(dict,subd%child)
        nullify(subd%child)
        call dict_free(subd)
        return
     end if
     !here the treatment of the scalar dictionary can be 
     !inserted (left commented for the moment)
!!$     if (associated(subd)) then
!!$        !if the dictionary is a scalar free it
!!$        if (dict_len(subd) == 0 .and. dict_size(subd) == 0 .and. &
!!$             len_trim(dict_key(subd))==0) then 
!!$           call set(dict,dict_value(subd))
!!$           call dict_free(subd)
!!$           return
!!$        end if
!!$     end if

     if (f_err_raise(no_key(dict),err_id=DICT_KEY_ABSENT)) return
     
     call f_strcpy(src=' ',dest=dict%data%value)
     !call set_field(repeat(' ',max_field_length),dict%data%value)
     if ( .not. associated(dict%child,target=subd) .and. &
          associated(dict%child)) then
        call dict_free(dict%child)
     end if
     dict%child=>subd
     if (associated(subd%parent)) then
        !inherit the number of elements or items from subd's parent
        !which is guaranteed to be associated
        dict%data%nelems=subd%parent%data%nelems
        dict%data%nitems=subd%parent%data%nitems
     end if
     call define_parent(dict,dict%child)

   end subroutine put_child


   !> Append another dictionary
   recursive subroutine append(dict,brother)
     implicit none
     type(dictionary), pointer :: dict
     type(dictionary), pointer :: brother

     if (.not. associated(dict)) then
        !this should be verifyed by passing a dictionary which is not in the beginning
        if (associated(brother%parent)) then
           call dict_init(dict)
           call set(dict,brother)
        else
           dict=>brother
        end if
     else if (.not. associated(dict%parent)) then
        call append(dict%child,brother)
     else if (.not. associated(brother%parent)) then
        call append(dict,brother%child)
        nullify(brother%child)
        call dict_free(brother)
     else if (associated(dict%next)) then
        call append(dict%next,brother)
     else
        if (.not. associated(dict%parent,target=brother%parent)) &
             dict%parent%data%nelems=&
             dict%parent%data%nelems+brother%parent%data%nelems
        dict%next=>brother
        call define_parent(dict%parent,dict%next)
        call define_brother(dict,dict%next)
     end if
   end subroutine append


   !> Append another dictionary
   recursive subroutine prepend(dict,brother)
     implicit none
     type(dictionary), pointer :: dict
     type(dictionary), pointer :: brother
     !local variables
     type(dictionary), pointer :: dict_tmp

     if (.not. associated(brother)) return

     if (.not. associated(dict)) then
        if (associated(brother%parent)) then
           call dict_init(dict)
           call set(dict,brother)
        else
           dict=>brother
        end if
     else if (.not. associated(dict%parent)) then
        call prepend(dict%child,brother)
     else if (.not. associated(brother%parent)) then
        !increment the number of elements
        dict%parent%data%nelems=&
             dict%parent%data%nelems+brother%data%nelems
        call define_parent(dict%parent,brother%child)
        call prepend(dict,brother%child)
        nullify(brother%child)
        call dict_free(brother)
     else if (associated(dict%previous)) then
        call prepend(dict%previous,brother)
     else
        dict_tmp=>brother
        call append(brother,dict)
        dict=>dict_tmp
     end if
   end subroutine prepend


   !> Assign the value to the dictionary
   subroutine put_value(dict,val)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in) :: val
     if (f_err_raise(no_key(dict),err_id=DICT_KEY_ABSENT)) return
     !call check_key(dict)
     !raise an error if not a value is put
     if (trim(val) == NOT_A_VALUE) then
        call f_err_throw('Invalid assignment for key "'//&
             trim(dict%data%key)//'"',err_id=DICT_VALUE_ABSENT)
        return
     end if
     if (associated(dict%child)) call dict_free(dict%child)

     call f_strcpy(src=val,dest=dict%data%value)
     !call set_field(val,dict%data%value)

   end subroutine put_value


   !> Assign the value to the dictionary 
   subroutine put_list(dict,list)
     implicit none
     character(len=*), dimension(:), intent(in) :: list
     include 'set_arr-inc.f90'
   end subroutine put_list

   subroutine put_listd(dict,list)
     implicit none
     double precision, dimension(:), intent(in) :: list
     include 'set_arr-inc.f90'
   end subroutine put_listd

   subroutine put_listi(dict,list)
     implicit none
     integer, dimension(:), intent(in) :: list
     include 'set_arr-inc.f90'
   end subroutine put_listi


   elemental function item_char(val) result(elem)
     implicit none
     character(len=*), intent(in) :: val
     type(list_container) :: elem

     elem%val(1:max_field_length)=val

   end function item_char

   elemental function item_dbl(val) result(elem)
     implicit none
     double precision, intent(in) :: val
     type(list_container) :: elem

     elem%val(1:max_field_length)=yaml_toa(val)

   end function item_dbl

   elemental function item_int(val) result(elem)
     implicit none
     integer, intent(in) :: val
     type(list_container) :: elem

     elem%val(1:max_field_length)=yaml_toa(val)

   end function item_int



   function item_dict(val) result(elem)
     implicit none
     type(dictionary), pointer, intent(in) :: val
     type(list_container) :: elem

     elem%dict=>val
   end function item_dict
   
   !> Internal procedure for .get. operator interface
   function list_container_if_key_exists(dict,key) result(list)
     implicit none
     type(dictionary), pointer, intent(in) :: dict
     character(len=*), intent(in) :: key
     type(list_container) :: list
     
     !if the dictionary is not associated, the list container is empty
     if (trim(key) .in. dict) list%dict=>dict//trim(key)
     !one might add a functionalty which implements the scalar value in list%val

   end function list_container_if_key_exists

   !> Creates a list from a table of dictionaries
   function list_new(dicts)
     implicit none
     type(list_container), dimension(:) :: dicts
     type(dictionary), pointer :: list_new
     !local variables
     integer :: i_st,n_st
     type(dictionary), pointer :: dict_tmp

     !initialize dictionary
     call dict_init(dict_tmp)

     n_st=size(dicts)
     do i_st=1,n_st
        if (associated(dicts(i_st)%dict)) then
           call add(dict_tmp,dicts(i_st)%dict)
        else if (len_trim(dicts(i_st)%val) > 0) then
           call add(dict_tmp,dicts(i_st)%val)
        end if
     end do

     list_new => dict_tmp
   end function list_new


   !> Create a list from several optional values (string or dict).
   function list_new_elems(dict0, dict1, dict2, dict3, dict4, dict5, dict6, dict7, dict8, dict9)
     implicit none
     type(list_container), intent(in) :: dict0
     type(list_container), intent(in), optional :: dict1, dict2, dict3, dict4
     type(list_container), intent(in), optional :: dict5, dict6, dict7, dict8, dict9
     type(dictionary), pointer :: list_new_elems
     !local variables
     type(dictionary), pointer :: dict_tmp

     !initialize dictionary
     call dict_init(dict_tmp)
     call fill(dict_tmp, dict0)
     if (present(dict1)) call fill(dict_tmp, dict1)
     if (present(dict2)) call fill(dict_tmp, dict2)
     if (present(dict3)) call fill(dict_tmp, dict3)
     if (present(dict4)) call fill(dict_tmp, dict4)
     if (present(dict5)) call fill(dict_tmp, dict5)
     if (present(dict6)) call fill(dict_tmp, dict6)
     if (present(dict7)) call fill(dict_tmp, dict7)
     if (present(dict8)) call fill(dict_tmp, dict8)
     if (present(dict9)) call fill(dict_tmp, dict9)
     list_new_elems => dict_tmp
   contains
     subroutine fill(dict, elem)
       implicit none
       type(list_container), intent(in) :: elem
       type(dictionary), pointer :: dict

       if (associated(elem%dict)) then
          call add(dict, elem%dict)
       else if (len_trim(elem%val) > 0) then
          call add(dict, elem%val)
       end if
     end subroutine fill
   end function list_new_elems


   !! here the dictionary has to be associated
   recursive subroutine get_value(val,dict)
     implicit none
     character(len=*), intent(out) :: val
     type(dictionary), intent(in) :: dict
     val(1:len(val))=' '
     if (f_err_raise(no_key(dict),err_id=DICT_KEY_ABSENT)) return
     if (f_err_raise(no_value(dict),'The key is "'//trim(dict%data%key)//'"',err_id=DICT_VALUE_ABSENT)) return
     call f_strcpy(src=dict%data%value,dest=val)
     !call get_field(dict%data%value,val)

   end subroutine get_value


   !> Get the value from the dictionary
   !! This routine only works if the dictionary is associated
   !! the problem is solved if any of the routines have the dict variable as a pointer
   !subroutine get_dict(dictval,dict)
   !  implicit none
   !  type(dictionary), pointer, intent(out) :: dictval
   !  type(dictionary), pointer, intent(in) :: dict

   !  dictval=>dict

   !end subroutine get_dict


   !> Set and get routines for different types (this routine can be called from error_check also)
   recursive subroutine get_integer(ival,dict)
     use yaml_strings, only: is_atoi
     implicit none
     integer, intent(out) :: ival
     type(dictionary), intent(in) :: dict
     !local variables
     integer :: ierror
     character(len=max_field_length) :: val

     !take value
     val=dict
     !look at conversion
     read(val,*,iostat=ierror) ival
     !is the value existing?
     if (ierror/=0) then
        if (f_err_check(err_id=DICT_VALUE_ABSENT))then
           ival=0
           return
        end if
     end if
     if (f_err_raise(ierror/=0 .or. .not. is_atoi(val),'Value '//val,err_id=DICT_CONVERSION_ERROR)) return    
   end subroutine get_integer

   !> Set and get routines for different types
   subroutine get_long(ival,dict)
     implicit none
     integer(kind=8), intent(out) :: ival
     type(dictionary), intent(in) :: dict
     !local variables
     integer :: ierror
     character(len=max_field_length) :: val

     !take value
     val=dict
     !look at conversion
     read(val,*,iostat=ierror)ival

     if (f_err_raise(ierror/=0,'Value '//val,err_id=DICT_CONVERSION_ERROR)) return

   end subroutine get_long

   !> Routine to retrieve an array from a dictionary
   subroutine get_dvec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     double precision, dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     double precision :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_dvec

   !> Routine to retrieve an array from a dictionary
   subroutine get_rvec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     real, dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     real :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_rvec

   !> Routine to retrieve an array from a dictionary
   subroutine get_ivec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     integer, dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     integer :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_ivec

   !> Routine to retrieve an array from a dictionary
   subroutine get_ilvec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     integer(kind=8), dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     integer(kind=8) :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_ilvec

   !> Routine to retrieve an array from a dictionary
   subroutine get_lvec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     logical, dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     logical :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_lvec

   !> Routine to retrieve an array from a dictionary
   subroutine get_c1vec(arr,dict)
     use yaml_strings, only: yaml_toa
     implicit none
     character(len=1), dimension(:), intent(out) :: arr
     type(dictionary), intent(in) :: dict 
     !local variables
     character(len=1) :: tmp
     include 'dict_getvec-inc.f90'
   end subroutine get_c1vec


   !> Set and get routines for different types
   subroutine get_real(rval,dict)
     implicit none
     real(kind=4), intent(out) :: rval
     type(dictionary), intent(in) :: dict
     !local variables
     integer :: ierror
     double precision :: dval
     character(len=max_field_length) :: val

     !take value
     val=dict
     !look at conversion
     call read_fraction_string(val, dval, ierror)
     rval = real(dval)

     if (f_err_raise(ierror/=0,'Value '//val,err_id=DICT_CONVERSION_ERROR)) return

   end subroutine get_real


   !> Set and get routines for different types
   subroutine get_lg(ival,dict)
     logical, intent(out) :: ival
     type(dictionary), intent(in) :: dict
     !local variables
     character(len=max_field_length) :: val

     !take value
     val=dict
     if (any(index(trim(val),['Yes', 'yes', 'YES']) > 0) .or. any(index(trim(val),['True', 'true', 'TRUE']) > 0)) then
        ival=.true.
     else if (any(index(trim(val),['No', 'no', 'NO']) > 0) .or. any(index(trim(val),['False', 'false', 'FALSE']) > 0)) then
        ival=.false.
     else
        call f_err_throw('Value '//val,err_id=DICT_CONVERSION_ERROR)
        return
     end if

   end subroutine get_lg


   !> Set and get routines for different types
   subroutine get_double(dval,dict)
     real(kind=8), intent(out) :: dval
     type(dictionary), intent(in) :: dict
     !local variables
     integer :: ierror
     character(len=max_field_length) :: val

     !take value
     val=dict
     !look at conversion
     call read_fraction_string(val, dval, ierror)

     if (f_err_raise(ierror/=0,'Value '//val,err_id=DICT_CONVERSION_ERROR)) return

   end subroutine get_double

   !> Safe getter, uses list_container as generated from the .get. operator
   subroutine safe_get_dict(dict,el)
     implicit none
     type(dictionary), pointer, intent(inout) :: dict
     type(list_container), intent(in) :: el
     if (associated(el%dict)) then
        dict=>el%dict
     else
        nullify(dict)
     end if
   end subroutine safe_get_dict

   subroutine safe_get_integer(val,el)
     implicit none
     integer, intent(inout) :: val
     type(list_container), intent(in) :: el
     if (associated(el%dict)) val=el%dict
   end subroutine safe_get_integer

   subroutine safe_get_double(val,el)
     implicit none
     double precision, intent(inout) :: val
     type(list_container), intent(in) :: el
     if (associated(el%dict)) val=el%dict
   end subroutine safe_get_double

   subroutine safe_get_real(val,el)
     implicit none
     real, intent(inout) :: val
     type(list_container), intent(in) :: el
     if (associated(el%dict)) val=el%dict
   end subroutine safe_get_real

   subroutine safe_get_char(val,el)
     implicit none
     character(len=*), intent(inout) :: val
     type(list_container), intent(in) :: el
     if (associated(el%dict)) val=el%dict
   end subroutine safe_get_char


   !> Assign the value to the dictionary
   subroutine put_integer(dict,ival,fmt)
     use yaml_strings, only:yaml_toa
     implicit none
     type(dictionary), pointer :: dict
     integer, intent(in) :: ival
     character(len=*), optional, intent(in) :: fmt

     if (present(fmt)) then
        call put_value(dict,trim(adjustl(yaml_toa(ival,fmt=fmt))))
     else
        call put_value(dict,trim(adjustl(yaml_toa(ival))))
     end if

   end subroutine put_integer


   !> Assign the value to the dictionary
   subroutine put_double(dict,dval,fmt)
     use yaml_strings, only:yaml_toa
     implicit none
     type(dictionary), pointer :: dict
     real(kind=8), intent(in) :: dval
     character(len=*), optional, intent(in) :: fmt

     if (present(fmt)) then
        call put_value(dict,adjustl(trim(yaml_toa(dval,fmt=fmt))))
     else
        call put_value(dict,adjustl(trim(yaml_toa(dval))))
     end if

   end subroutine put_double


   !> Assign the value to the dictionary
   subroutine put_real(dict,rval,fmt)
     use yaml_strings, only:yaml_toa
     implicit none
     type(dictionary), pointer :: dict
     real(kind=4), intent(in) :: rval
     character(len=*), optional, intent(in) :: fmt

     if (present(fmt)) then
        call put_value(dict,adjustl(trim(yaml_toa(rval,fmt=fmt))))
     else
        call put_value(dict,adjustl(trim(yaml_toa(rval))))
     end if

   end subroutine put_real


   !> Assign the value to the dictionary
   subroutine put_long(dict,ilval,fmt)
     use yaml_strings, only:yaml_toa
     implicit none
     type(dictionary), pointer :: dict
     integer(kind=8), intent(in) :: ilval
     character(len=*), optional, intent(in) :: fmt

     if (present(fmt)) then
        call put_value(dict,adjustl(trim(yaml_toa(ilval,fmt=fmt))))
     else
        call put_value(dict,adjustl(trim(yaml_toa(ilval))))
     end if

   end subroutine put_long

   subroutine put_lg(dict,val,fmt)
     use yaml_strings, only:yaml_toa
     implicit none
     type(dictionary), pointer :: dict
     logical, intent(in) :: val
     character(len=*), optional, intent(in) :: fmt

     if (present(fmt)) then
        call put_value(dict,adjustl(trim(yaml_toa(val,fmt=fmt))))
     else
        call put_value(dict,adjustl(trim(yaml_toa(val))))
     end if

   end subroutine put_lg


   !> Merge subd into dict.
   subroutine dict_update(dict, subd)
     implicit none
     type(dictionary), pointer :: dict, subd

     if (.not.associated(dict)) then
        call dict_copy(dict, subd)
     else
        call update(dict, subd)
     end if

     contains

       recursive subroutine update(dict, subd)
         implicit none
         type(dictionary), pointer :: dict, subd

         integer :: i
         character(len = max_field_length), dimension(:), allocatable :: keys
         character(len = max_field_length) :: val

         if (dict_len(subd) > 0) then
            ! List case
            if (dict_size(dict) > 0) then
               ! Incompatible dict and subd.
               call f_err_throw()
               return
            end if
            ! Replace elements.
            do i = 0, min(dict_len(dict), dict_len(subd)) - 1, 1
               call update(dict // i, subd // i)
            end do
            ! Copy additional elements.
            do i = dict_len(dict), dict_len(subd) - 1, 1
               call dict_copy(dict // i, subd // i)
            end do
         else if (dict_size(subd) > 0) then
            if (dict_len(dict) > 0) then
               ! Incompatible dict and subd.
               call f_err_throw()
               return
            end if
            ! Dict case

            allocate(keys(dict_size(subd)))
            keys = dict_keys(subd)
            do i = 1, size(keys), 1
               call update(dict // keys(i), subd // keys(i))
            end do
            deallocate(keys)
         else if (associated(subd)) then
            ! Scalar case
            val = subd
            call set(dict, val)
         end if
       end subroutine update
   end subroutine dict_update


   subroutine dict_copy(dest, src)
     implicit none
     type(dictionary), pointer :: src, dest

     if (.not. associated(dest)) call dict_init(dest)
     call copy(dest, src)

     contains
       recursive subroutine copy(dict, ref)
         implicit none
         type(dictionary), pointer :: dict, ref

         integer :: i
         character(max_field_length), dimension(:), allocatable :: keys
         character(len = max_field_length) :: val

         if (dict_len(ref) > 0) then
            ! List case.
            do i = 0, dict_len(ref) - 1, 1
               call copy(dict // i, ref // i)
            end do
         else if (dict_size(ref) > 0) then
            ! Dictionary case
            allocate(keys(dict_size(ref)))
            keys = dict_keys(ref)
            do i = 1, size(keys), 1
               call copy(dict // keys(i), ref // keys(i))
            end do
            deallocate(keys)
         else if (associated(ref)) then
            ! Leaf case.
            val = ref
            call set(dict, val)
         end if
       end subroutine copy

   end subroutine dict_copy

   !include the module of error handling
   include 'error_handling.f90'

end module dictionaries
