!> @file
!! Test the dynamic memory allocation of the flib library
!! @author
!!    Copyright (C) 2013-2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Test the dynamic memory allocation (flib)
subroutine test_dynamic_memory()
   use yaml_output
   use dynamic_memory
   use dictionaries
   use metadata_interfaces, only: getdp2
   implicit none

   type :: dummy_type
      integer :: i
      double precision, dimension(:), pointer :: ptr
   end type dummy_type

   !logical :: fl
   integer :: i
   real(kind=8), dimension(:), allocatable :: density,rhopot,potential,pot_ion,xc_pot
   real(kind=8), dimension(:), pointer :: extra_ref
   real(kind=8), dimension(:,:), save, allocatable :: ab
   real(kind=8), dimension(:,:), allocatable :: b
   integer, dimension(:), allocatable :: i1_all,i1_src
   integer, dimension(:), pointer :: i1_ptr,ptr1
   integer, dimension(:), pointer :: ptr2

   integer,dimension(:,:,:),allocatable :: weight
   integer,dimension(:,:,:,:),allocatable :: orbital_id
   character(len=20), dimension(:), allocatable :: str_arr
   character(len=20), dimension(:), pointer :: str_ptr

   type(dummy_type) :: dummy_test
   external :: abort2
   real(kind=8) :: total
   integer :: ithread
   integer(kind=8) :: iadd
   !$ integer :: ierror
   !$ integer(kind=8) :: lock
   !$ integer, external :: omp_get_thread_num
   
   !$omp threadprivate(ab)

   ithread=0

   call yaml_comment('Routine-Tree creation example',hfill='~')
   !call dynmem_sandbox()

   i1_all=f_malloc(0,id='i1_all')
   call yaml_map('Address of first element',f_loc(i1_all))
!   call yaml_map('Address of first element, explicit',f_loc(i1_all(1)))

   nullify(ptr1,ptr2)
   call yaml_map('Associated',(/associated(ptr1),associated(ptr2)/))

   i1_ptr=f_malloc_ptr(0,id='i1_ptr')

   ptr1=>i1_ptr

   ptr2=>ptr1
   call yaml_map('Associated',(/associated(ptr1),associated(ptr2)/))

   call yaml_map('Address of first element',f_loc(i1_ptr))
   call yaml_map('Address of first element, explicit (1)',f_loc(ptr1))
   call yaml_map('Address of first element, explicit (2)',f_loc(ptr2))

   !also allocating the dummy structure
   dummy_test=dummy_init(10)

!call f_malloc_finalize(dump=.true.)
!stop
   !call init_dummy(10,dummy_test)
   call free_dummy(dummy_test)

   call f_free_ptr(ptr2) !this one would crash
   !call f_free_ptr(i1_ptr)

   call yaml_map('Associated',(/associated(ptr1),associated(ptr2),associated(i1_ptr)/))
!!$
!!$
!!$
!!$   call f_malloc_dump_status()
   call f_free(i1_all)


call yaml_comment('debug 1')
   call f_routine(id='PS_Check')
call yaml_comment('debug 2')
   call f_routine(id='Routine 0')
   !Density
   density=f_malloc(3*2,id='density')
   !Density then potential
   potential=f_malloc(3,id='potential')!0

   call f_release_routine()

   call f_routine(id='Routine A')
weight=f_malloc((/1.to.8,1.to.8,2.to.4/),id='weight')
weight(1,1,2)=5
call f_free(weight)
   call f_release_routine()

!!$   call yaml_mapping_open('TemporaryA')
!!$    call f_malloc_dump_status()
!!$    call yaml_mapping_close()
!!$
!!$
!!$   call f_routine(id='Routine A')
!!$weight=f_malloc((/1.to.8,1.to.8,2.to.4/),id='weight')
!!$weight(1,1,2)=5
!!$call f_free(weight)
!!$   call f_release_routine()
!!$
!!$   call yaml_mapping_open('TemporaryB')
!!$    call f_malloc_dump_status()
!!$    call yaml_mapping_close()


!!$   call f_release_routine()
!!$
!!$   call yaml_mapping_open('Temporary')
!!$    call f_malloc_dump_status()
!!$    call yaml_mapping_close()
!!$stop
!!$
!!$!   call f_malloc_dump_status()
!!$   call f_routine(id=subname)
!!$
!!$   ncommarr=f_malloc(lbounds=(/0,1/),ubounds=(/nproc-1,4/),id='ncommarr')
!!$   ncommarr=f_malloc((/0.to.nproc,1.to.4/),id='ncommarr')
!!$   ncommarr=f_malloc_ptr((/0.to.nproc-1,4/),id='ncommarr')
!!$   call f_release_routine()

   call f_routine(id='Routine D')
    call f_routine(id='SubCase 1')
    !test of copying data
    i1_src=f_malloc(63,id='i1_src')

    i1_src=(/(i+24,i=1,size(i1_src))/)
    call yaml_map('Source vector',i1_src)
    call yaml_map('Its shape',shape(i1_src))
    call yaml_map('Its rank',size(shape(i1_src)))
    i1_all=f_malloc(src=i1_src,id='i1_all')

    call yaml_map('Vector difference',i1_all-i1_src)

!!$    call yaml_map('Vector allocation',[allocated(i1_all),allocated(i1_src)])
!!$    call f_free(i1_src)
!!$    call yaml_map('Vector allocation',[allocated(i1_all),allocated(i1_src)])
!!$    call f_free(i1_all)
!!$    call yaml_map('Vector allocation',[allocated(i1_all),allocated(i1_src)])

    call f_free(i1_src,i1_all)
    call f_release_routine()
    call f_routine(id='Subcase 2')
     call f_routine(id='SubSubcase1')
     !test of copying data
     i1_ptr=f_malloc_ptr(34,id='i1_ptr')

     i1_ptr=(/(i+789,i=1,size(i1_ptr))/)
     call yaml_map('Source pointer',i1_ptr)
     call yaml_map('Its shape',shape(i1_ptr))
     call yaml_map('Its rank',size(shape(i1_ptr)))
     ptr1=f_malloc_ptr(src=i1_ptr,id='ptr1')

     call yaml_map('Pointer difference',i1_ptr-ptr1)
!!$     call yaml_map('Pointer association',[associated(i1_ptr),associated(ptr1)])
!!$     call f_free_ptr(i1_ptr)
!!$     call yaml_map('Pointer association',[associated(i1_ptr),associated(ptr1)])
!!$     call f_free_ptr(ptr1)
!!$     call yaml_map('Pointer association',[associated(i1_ptr),associated(ptr1)])

     !again, to see if the copy works
     i1_ptr=i1_ptr-1
     call yaml_map('Pointer difference again (should be -1)',i1_ptr-ptr1)
     !then copy
     !call f_memcpy(src=i1_ptr(1),dest=ptr1(1),n=size(i1_ptr))
     call f_memcpy(src=i1_ptr,dest=ptr1)
     call yaml_map('Pointer difference again (should be 0)',i1_ptr-ptr1)

     call f_free_ptr(i1_ptr,ptr1)
     call f_release_routine()

     !allocate and test string array
     str_arr=f_malloc0_str(len(str_arr),4,id='str_arr')

     do i=1,size(str_arr)
        str_arr(i)='hello, arr'//trim(yaml_toa(i))
     end do

     call yaml_map('String array values',str_arr)
     call yaml_map('loc of address and metadata',[f_loc(str_arr),f_loc(str_arr(1)),get_add_str(str_arr)])
     !then free array
     call f_free_str(len(str_arr),str_arr)

     !allocate and test string pointer
     str_ptr=f_malloc0_str_ptr(len(str_arr),4,id='str_ptr')

     do i=1,size(str_ptr)
        str_ptr(i)='hello, ptr'//trim(yaml_toa(i))
     end do

     call yaml_map('String pointer values',str_ptr)
     call yaml_map('loc of address and metadata',[f_loc(str_ptr),f_loc(str_ptr(1)),get_add_str(str_ptr)])
     !then free array
     call f_free_str_ptr(len(str_ptr),str_ptr)

     
    call f_release_routine()
    call f_routine(id='SubCase 3')
      weight    =f_malloc((/1.to.1,1.to.1,-1.to.-1/),id='weight')
      orbital_id=f_malloc((/1.to.1,1.to.1,1.to.7,0.to.0/),id='orbital_id')
    call f_malloc_dump_status()
      call f_free(weight)
      call f_free(orbital_id)
    call f_release_routine()
   call f_release_routine()
   !repeat it to see if it gives errors
   !the point is what to do with a subroutine which is called like the parent routine
   call yaml_comment('Test for debug')
   call f_routine(id='PS_Check')
   call f_release_routine()
   call yaml_comment('End test for debug')
   call f_routine(id='PS_Check')
   call f_release_routine()
   call yaml_comment('End test for debug2')
   !call f_malloc_dump_status()

   call f_routine(id='Routine E')
    call f_free(density)
   call f_release_routine()
   call f_routine(id='Routine F')

   ! call f_malloc_dump_status()

   !Allocations, considering also spin density
!!$   !ionic potential
   pot_ion=f_malloc(0,id='pot_ion')
   !XC potential
   xc_pot=f_malloc(3*2,id='xc_pot')

   !   call f_malloc_dump_status()
   extra_ref=f_malloc_ptr(0,id='extra_ref')

   rhopot=f_malloc(3*2,id='rhopot')

    call f_malloc_dump_status()

   call f_free(rhopot)
!!$
!!$   !   call f_free(density,potential,pot_ion,xc_pot,extra_ref)

   !use yaml_syntax to retrieve list element
   call retrieve_list_element('[ elem1, 1.d0, elem2, 3.d0]')

   call f_malloc_dump_status()
!   call f_malloc_finalize()
!   stop
   call f_free(pot_ion)
   call f_free(potential)
   call f_free(xc_pot)
   !   call f_malloc_dump_status()
   call f_free_ptr(extra_ref)
!!$   !   call yaml_mapping_open('Last')
!!$   !   call f_malloc_dump_status()
!!$   !   call yaml_mapping_close()

   call yaml_comment('Entering in OpenMP section if available',hfill='-')

   !!define the lock
   !$ call OMP_init_lock(lock)

   !open try-catch section
   call f_err_open_try()

   total=0.d0

   !Allocation in an omp section is not permissible
   !$omp parallel private(ithread,iadd,ierror,b) !firstprivate(ab)
   !$omp critical (allocate_critical1)
   !$ ithread=omp_get_thread_num()

   call getdp2(ab,iadd)
   call yaml_map('Entering Thread No.',ithread)
   call yaml_map('Address of metadata',iadd)

   !!$ call OMP_set_lock(lock)
   ab = f_malloc((/ 10, 10 /),id='ab')
   !!$ call OMP_unset_lock(lock)
   !allocate(ab(10,10),stat=ierror)
   !call allocate_array(ab,ierror)

   ab = 1.d0
   total=total+sum(ab)
   !$omp end critical (allocate_critical1)

   !verify is an error has occured
   !$omp barrier
   if ( .not. f_err_check()) then
      !$omp critical (deallocate_critical1)
      !!$ call OMP_set_lock(lock)
      call f_free(ab)
      !!$ call OMP_unset_lock(lock)
      !deallocate(ab)
      !$omp end critical (deallocate_critical1)
   end if

   !$omp barrier
   if (.not. f_err_check()) then
      if (ithread == 0) call yaml_map('Something to use ab',total)
   end if

   !$omp barrier

   !$omp critical (allocate_critical)
   !!$ call OMP_set_lock(lock)
   b = f_malloc((/ 10, 10 /),id='b')
   !!$ call OMP_unset_lock(lock)
   !allocate(b(10,10),stat=ierror)
   !call allocate_array(b,ierror)

   b = 1.d0
   total=total+sum(b)
   !$omp end critical (allocate_critical)

   !verify is an error has occured
   !$omp barrier
   if ( .not. f_err_check()) then
      !$omp critical (deallocate_critical)
      !!$ call OMP_set_lock(lock)
      call f_free(b)
      !!$ call OMP_unset_lock(lock)
      !deallocate(b)
      !$omp end critical (deallocate_critical)
   end if
   !$omp end parallel
   !$ call OMP_destroy_lock(lock)
   if (f_err_check()) then
      if (ithread == 0) then
         call yaml_map('Errors found while (de)allocating ab and b',f_get_no_of_errors())
         call f_dump_all_errors()
      end if
   else
      call yaml_map('Something to use b',total)
   end if

   call f_err_close_try()
!stop
   call f_release_routine()
   !stop
!call yaml_map('Total of the allocations',total)
   call f_routine(id='Routine A')
   call f_release_routine()

   call f_routine(id='Routine A')
   call f_release_routine()

   call f_routine(id='Routine A')
   call f_release_routine()


   call f_release_routine()

   call f_malloc_dump_status()

   contains

     function get_add_str(array)
       implicit none
       character(len=*), dimension(:), intent(in) :: array
       integer(kind=8) :: get_add_str

       get_add_str=f_loc(array(1))
     end function get_add_str

     !>routine to retrieve the list element from a string which is 
     !! compliant with yaml standard
     subroutine retrieve_list_element(string)
       use yaml_parse, only: yaml_parse_from_string
       implicit none
       !Arguments
       character(len=*), intent(in) :: string
       !local variables
       type(dictionary), pointer :: dict_string,loaded_string

       !first, parse the string
       call yaml_parse_from_string(loaded_string,string)
       !this will give us a dictionary with a list inside
       call yaml_map('Parsed string',loaded_string)

       dict_string => loaded_string .pop. 0

       call yaml_map('Associated after pop',associated(loaded_string))
       if (associated(loaded_string)) call dict_free(loaded_string)
       !this will give us a dictionary with a list inside
       call yaml_map('Loaded string',dict_string)

       call dict_free(dict_string)
     end subroutine retrieve_list_element

     subroutine allocate_array(array,ierror)
       implicit none
       real(kind=8), dimension(:,:), allocatable,  intent(inout) :: array
       integer, intent(out) :: ierror
       !local variables
       integer(kind=8) :: iadd
       logical :: in_omp
       !$ integer, external :: omp_get_thread_num
       !$ logical, external :: omp_in_parallel

       in_omp=.false.
       !$ in_omp=omp_in_parallel()
       !detect if we are in a parallel section
!       !$ if(in_omp) then
!       !$omp critical (f_malloc_critical)
!       !$ end if
       ierror=-12345
       call getdp2(array,iadd)
       call yaml_map('Metadata address inside the routine',iadd)
       call yaml_map('Parallel section',in_omp)
       !$ call yaml_map('Thread in the routine',omp_get_thread_num())
       call yaml_map('Array seems allocated',allocated(array))
       allocate(array(10,10),stat=ierror)
!       !$ if(in_omp) then
!       !$omp end critical (f_malloc_critical)
!       !$ end if
       call yaml_map('Array seems allocated after allocation',allocated(array))
       call yaml_map('Array allocation staus',ierror)

     end subroutine allocate_array
     
     function dummy_init(n) result(dummy)
       implicit none
       integer, intent(in) :: n
       type(dummy_type) :: dummy
       call init_dummy(n,dummy)
     end function dummy_init
     subroutine init_dummy(n,dummy)
       implicit none
       integer, intent(in) :: n
       type(dummy_type), intent(out) :: dummy
       
       dummy%i=n
       dummy%ptr=f_malloc_ptr(n,id='ptr')
       dummy%ptr=dble(n)
     end subroutine init_dummy
     subroutine free_dummy(dummy)
       implicit none
       type(dummy_type), intent(inout) :: dummy
       call f_free_ptr(dummy%ptr)
       dummy%i=0
     end subroutine free_dummy
end subroutine test_dynamic_memory

!> this subroutine performs random allocations and operations on different arrays 
!! in order to verify if the memory statis is in agreement with the process usage
subroutine verify_heap_allocation_status()
  use yaml_output
  use dynamic_memory
  use dictionaries, only: f_loc
  implicit none
  !local variables
  logical, parameter :: traditional=.true.
  character(len=*), parameter :: subname='verify_heap_allocation_status' 
  logical :: all
  integer :: maxnum,maxmem,i,nall,ndeall,nsize,ibuf
  real :: tt,total_time,t0,t1,tel
  double precision :: checksum,chk
  type :: to_alloc
     double precision, dimension(:), pointer :: buffer
  end type to_alloc
  type(to_alloc), dimension(:), allocatable :: pool
  call f_routine(id=subname)

  !decide total cpu time of the run (seconds)
  total_time=30.e0

  !maximum simultaenously allocated arrays
  maxnum=1000
  
  !maximum value of memory to be used, in MB
  maxmem=100

  !size of each chunk 
  nsize=int((int(maxmem,kind=8)*1024*1024/8)/maxnum)
  !start timer
  call cpu_time(t0)
  !elapsed time
  tel=0.e0
  !prepare the pool for allocations
  allocate(pool(maxnum))
  do i=1,maxnum
     nullify(pool(i)%buffer)
  end do

  checksum=0.d0
  nall=0
  ndeall=0
  do while (tel < total_time)

     !extract the allocation action
     call random_number(tt)
     all= (tt < 0.5e0) 
     ibuf=-1 !failsafe
     !find the first unallocated
     if (all) then
        do i=1,maxnum
           if (.not. associated(pool(i)%buffer)) then
              ibuf=i
              exit
           end if
        end do
        if (ibuf==-1) cycle !try again
        !allocate
        if (traditional) then
           allocate(pool(ibuf)%buffer(nsize))
           call f_update_database(int(nsize,kind=8),kind(1.d0),1,f_loc(pool(ibuf)%buffer),&
                'buf'//trim(adjustl(yaml_toa(ibuf))),subname)
        else
           pool(ibuf)%buffer=f_malloc_ptr(nsize,id='buf'//trim(adjustl(yaml_toa(ibuf))))
        end if
        do i=1,nsize
           call random_number(tt)
           pool(ibuf)%buffer(i)=dble(tt)
        end do
        chk=sum(pool(ibuf)%buffer)
        nall=nall+1
     else !find the first allocated
        do i=1,maxnum
           if (associated(pool(i)%buffer)) then
              ibuf=i
              exit
           end if
        end do
        if (ibuf==-1) cycle !try again
        chk=-sum(pool(ibuf)%buffer)
        if (traditional) then
           call f_purge_database(int(nsize,kind=8),kind(1.d0),f_loc(pool(ibuf)%buffer),&
                'buf'//trim(adjustl(yaml_toa(ibuf))),subname)
           deallocate(pool(ibuf)%buffer)
        else
           call f_free_ptr(pool(ibuf)%buffer)
        end if
        ndeall=ndeall+1
     end if
     checksum=checksum+chk
     call cpu_time(t1)
     tel=t1-t0
  end do

  !deallocate all the residual
  do i=1,maxnum
     call f_free_ptr(pool(i)%buffer)
  end do

  deallocate(pool)

  call yaml_map('Total elapsed time',tel)
  call yaml_map('Allocations, deallocations',[nall,ndeall])
  call yaml_map('Checksum value',checksum)

  call f_release_routine()
end subroutine verify_heap_allocation_status

subroutine dynmem_sandbox()
  use yaml_output
  use dictionaries, dict_char_len=> max_field_length
  type(dictionary), pointer :: dict2,dictA
  character(len=dict_char_len) :: routinename

  call yaml_comment('Sandbox')  
   !let used to imagine a routine-tree creation
   nullify(dict2)
   call dict_init(dictA)
   dict2=>dictA//'Routine Tree'
!   call yaml_map('Length',dict_len(dict2))
   call add_routine(dict2,'Routine 0')
   call close_routine(dict2,'Routine 0')
   call add_routine(dict2,'Routine A')
   call close_routine(dict2,'Routine A')
   call add_routine(dict2,'Routine B')
   call close_routine(dict2,'Routine B')
   call add_routine(dict2,'Routine C')
   call close_routine(dict2,'Routine C')
   call add_routine(dict2,'Routine D')

   call open_routine(dict2)
   call add_routine(dict2,'SubCase 1')
   call close_routine(dict2,'SubCase 1')

   call add_routine(dict2,'Subcase 2')
   call open_routine(dict2)
   call add_routine(dict2,'SubSubCase1')
   call close_routine(dict2,'SubSubCase1')

   call close_routine(dict2,'SubSubCase1')
   
!   call close_routine(dict2)
   call add_routine(dict2,'SubCase 3')
   call close_routine(dict2,'SubCase 3')
   call close_routine(dict2,'SubCase 3')

   call add_routine(dict2,'Routine E')
   call close_routine(dict2,'Routine E')

   call add_routine(dict2,'Routine F')
!   call yaml_comment('Look Below',hfill='v')

   call yaml_mapping_open('Test Case before implementation')
   call yaml_dict_dump(dictA)
   call yaml_mapping_close()
!   call yaml_comment('Look above',hfill='^')

   call dict_free(dictA)

 contains

   subroutine open_routine(dict)
     implicit none
     type(dictionary), pointer :: dict
     !local variables
     integer :: ival
     type(dictionary), pointer :: dict_tmp

     !now imagine that a new routine is created
     ival=dict_len(dict)-1
     routinename=dict//ival

     !call yaml_map('The routine which has to be converted is',trim(routinename))

     call dict_remove(dict,ival)

     dict_tmp=>dict//ival//trim(routinename)
     dict => dict_tmp
     nullify(dict_tmp)

   end subroutine open_routine

   subroutine close_routine(dict,name)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in), optional :: name
     !local variables
     logical :: jump_up
     type(dictionary), pointer :: dict_tmp

     if (.not. associated(dict)) stop 'ERROR, routine not associated' 

     !       call yaml_map('Key of the dictionary',trim(dict%data%key))

     if (present(name)) then
        !jump_up=(trim(dict%data%key) /= trim(name))
        jump_up=(trim(routinename) /= trim(name))
     else
        jump_up=.true.
     end if

     !       call yaml_map('Would like to jump up',jump_up)
     if (jump_up) then
        !now the routine has to be closed
        !we should jump at the upper level
        dict_tmp=>dict%parent 
        if (associated(dict_tmp%parent)) then
           nullify(dict)
           !this might be null if we are at the topmost level
           dict=>dict_tmp%parent
        end if
        nullify(dict_tmp)
     end if

     routinename=repeat(' ',len(routinename))
   end subroutine close_routine

   subroutine add_routine(dict,name)
     implicit none
     type(dictionary), pointer :: dict
     character(len=*), intent(in) :: name

     routinename=trim(name)
     call add(dict,trim(name))

   end subroutine add_routine

end subroutine dynmem_sandbox


