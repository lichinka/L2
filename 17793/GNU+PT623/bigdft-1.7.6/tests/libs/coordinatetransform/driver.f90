!>     program to convert CARTESIAN COORDINATES TO Z-MATRIX
program carint
  use module_base
  use bigdft_run
  use internal_coordinates
  use dynamic_memory
  use yaml_output
  implicit none

  real(kind=8),parameter :: degree = 57.295779513d0
  !integer,parameter :: nmax=100
  integer :: nat, iat, iproc, nproc
  character(len=4) :: test
  !!real(kind=8),dimension(3,nmax) :: xyz, geo
  !!integer,dimension(nmax) :: na, nb, nc
  real(kind=8),dimension(:,:),allocatable :: xyz_init, xyz, xyz_diff, geo
  integer,dimension(:),allocatable :: na, nb, nc
  real(kind=8) :: x, y, z, maxdiff
  integer :: numat, i, istat
  character(len=64) :: tt
!  integer, dimension(4) :: mpi_info
  character(len=60) :: run_id
  integer :: nconfig, ierr

  ! Initialize
  call f_lib_initialize()
  call bigdft_init()!mpi_info,nconfig,run_id,ierr)
  !just for backward compatibility
  iproc=bigdft_mpi%iproc!mpi_info(1)
  nproc=bigdft_mpi%nproc!mpi_info(2)

  if (iproc==0) then
      call yaml_comment('Program to check the coordinate transform routines',hfill='/')
  end  if


  open(unit=99,file='posinp.xyz')
  read(99,*) nat
  xyz_init = f_malloc((/ 3, nat /),id='xyz_init')
  xyz = f_malloc((/ 3, nat /),id='xyz')
  xyz_diff = f_malloc((/ 3, nat /),id='xyz_diff')
  na = f_malloc(nat,id='na')
  nb = f_malloc(nat,id='nb')
  nc = f_malloc(nat,id='nc')
  geo = f_malloc((/ 3, nat /),id='geo')
  read(99,*) tt
  do iat=1,nat
      read(99,*) tt, xyz_init(1,iat), xyz_init(2,iat), xyz_init(3,iat)
  end do
  close(unit=99)


  if (iproc==0) then
      call yaml_sequence_open('initial coordinates')
      do i=1,nat
         call yaml_sequence(advance='no')
         call yaml_mapping_open(flow=.true.)
         call yaml_map('id',i)
         call yaml_map('positions',xyz_init(1:3,i),fmt='(es14.6)')
         call yaml_mapping_close()
      end do
      call yaml_sequence_close()
  end if

  call get_neighbors(xyz_init,nat,na,nb,nc)
  call xyzint(xyz_init,nat,na,nb,nc,degree,geo)

  ! The bond angle must be modified (take 180 degrees minus the angle)
  geo(2:2,1:nat) = 180.d0 - geo(2:2,1:nat)

  if (iproc==0) then
      call yaml_sequence_open('internal coordinates')
      do i=1,nat
         call yaml_sequence(advance='no')
         call yaml_mapping_open(flow=.true.)
         call yaml_map('id',i)
         call yaml_map('refs',(/na(i),nb(i),nc(i)/))
         call yaml_map('vals',geo(1:3,i),fmt='(es14.6)')
         call yaml_mapping_close()
      end do
      call yaml_sequence_close()
  end if



  ! convert to rad
  geo(2:3,1:nat) = geo(2:3,1:nat) / degree
  call internal_to_cartesian(nat, na, nb, nc, geo, xyz)

  if (iproc==0) then
      call yaml_sequence_open('final coordinates')
      do i=1,nat
         call yaml_sequence(advance='no')
         call yaml_mapping_open(flow=.true.)
         call yaml_map('id',i)
         call yaml_map('positions',xyz(1:3,i),fmt='(es14.6)')
         call yaml_mapping_close()
      end do
      call yaml_sequence_close()
  end if

  xyz_diff = xyz_init-xyz

  if (iproc==0) then
      call yaml_sequence_open('difference')
      do i=1,nat
         call yaml_sequence(advance='no')
         call yaml_mapping_open(flow=.true.)
         call yaml_map('id',i)
         call yaml_map('positions',xyz_diff(1:3,i),fmt='(es14.6)')
         call yaml_mapping_close()
      end do
      call yaml_sequence_close()
  end if
  xyz_diff=abs(xyz_diff)
  maxdiff=maxval(xyz_diff)
  if (iproc==0) then
      call yaml_map('maximal difference',maxdiff)
  end if



  call f_free(xyz_init)
  call f_free(xyz)
  call f_free(xyz_diff)
  call f_free(geo)
  call f_free(na)
  call f_free(nb)
  call f_free(nc)

  if (iproc==0) call yaml_comment('checks finished',hfill='=')

  call bigdft_finalize(ierr)
  call f_lib_finalize()

end program carint

