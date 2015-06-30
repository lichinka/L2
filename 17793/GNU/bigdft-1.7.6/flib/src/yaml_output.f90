!> @file
!! Define the modules (yaml_strings and yaml_output) and the methods to write yaml output
!! yaml: Yet Another Markup Language -> Y Ain't a Markup Language (Human readable ML)
!! @author
!!    Copyright (C) 2011-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Module defining the routines used to write the yaml output
module yaml_output
  use yaml_strings
  use dictionaries
  !use error_handling
  implicit none
  private

  !> Yaml events for dump routine
  integer, parameter :: NONE                   = -1000
  integer, parameter :: DOCUMENT_START         = -1001
  integer, parameter :: DOCUMENT_END           = -1002
  integer, parameter :: MAPPING_START          = -1003
  integer, parameter :: MAPPING_END            = -1004
  integer, parameter :: SEQUENCE_START         = -1005
  integer, parameter :: SEQUENCE_END           = -1006
  integer, parameter :: SCALAR                 = -1007
  integer, parameter :: COMMENT                = -1008
  integer, parameter :: MAPPING                = -1009
  integer, parameter :: SEQUENCE_ELEM          = -1010
  integer, parameter :: NEWLINE                = -1011
  integer, parameter :: COMMA_TO_BE_PUT        =  10

  integer, parameter :: tot_max_record_length=95   !< Max record length by default
  integer, parameter :: tot_max_flow_events=500    !< Max flow events
  integer, parameter :: tot_streams=10             !< Max total number of streams
  integer, parameter :: tab=5                      !< Default number for tabbing

  integer :: active_streams=0  !< Number of active streams (stdout always active after init)
  integer :: default_stream=1  !< Id of the default stream

  !parameter of the document
  type :: yaml_stream
     logical :: document_closed=.true.  !< Put the starting of the document if new_document is called
     logical :: pp_allowed=.true.       !< Pretty printing allowed
     integer :: unit=6                  !< Unit for the stdout
     integer :: max_record_length=tot_max_record_length
     logical :: flowrite=.false.        !< Write in flow (.false.=no .true.=yes)
     integer :: Wall=-1                 !< Warning messages of level Wall stop the program (-1 : none)
     integer :: indent=1                !< Blank spaces indentations for Yaml output level identification
     integer :: indent_previous=0       !< Indent level prior to flow writing
     integer :: indent_step=2           !< Indentation level
     integer :: tabref=40               !< Position of tabular in scalar assignment (single column output)
     integer :: icursor=1               !< Running position of the cursor on the line
     integer :: itab_active=0           !< Number of active tabbings for the line in flowrite
     integer :: itab=0                  !< Tabbing to have a look on
     integer :: ilevel=0                !< Number of opened levels
     integer :: iflowlevel=0            !< Levels of flowrite simoultaneously enabled
     integer :: ilast=0                 !< Last level with flow==.false.
     integer :: icommentline=0          !< Active if the line being written is a comment
     integer, dimension(tot_max_record_length/tab) :: linetab=0   !< Value of the tabbing in the line
     integer :: ievt_flow=0                                       !< Events which track is kept of in the flowrite
     integer, dimension(tot_max_flow_events) :: flow_events=0     !< Set of events in the flow
     type(dictionary), pointer :: dict_warning=>null()            !< Dictionary of warnings emitted in the stream
     !character(len=tot_max_record_length), dimension(:), pointer :: buffer !<
  end type yaml_stream

  type(yaml_stream), dimension(tot_streams), save :: streams    !< Private array containing the streams
  integer, dimension(tot_streams) :: stream_units=6             !< Default units unless otherwise specified
  type(dictionary), pointer :: stream_files

  logical :: module_initialized=.false.  !< Tells if the module has been already referenced or not

  ! Error ids
  integer :: YAML_STREAM_ALREADY_PRESENT !< Trying to create a stream already present
  integer :: YAML_STREAM_NOT_FOUND       !< Trying to seach for a absent unit
  integer :: YAML_UNIT_INCONSISTENCY     !< Internal error, unit inconsistency
  integer :: YAML_INVALID                !< Invalid action, unit inconsistency

  !> Generic routine to create a yaml map as 'foo: 1\\n' is call yaml_map('foo',1)
  !! @ingroup FLIB_YAML
  !! @param mapname  @copydoc doc::mapname
  !! @param mapvalue @copydoc doc::mapvalue
  !! @param label    (optional) @copydoc doc::label
  !! @param advance  (optional) @copydoc doc::advance
  !! @param unit     (optional) @copydoc doc::unit
  !! @param fmt      (optional) format for the value
  interface yaml_map
     !general scalar
     module procedure yaml_map,yaml_map_dict
     !other scalars
     module procedure yaml_map_i,yaml_map_li,yaml_map_f,yaml_map_d,yaml_map_l
     !vectors
     module procedure yaml_map_iv,yaml_map_dv,yaml_map_cv,yaml_map_rv,yaml_map_lv,yaml_map_liv
     !matrices (rank2)
     module procedure yaml_map_dm,yaml_map_rm,yaml_map_im,yaml_map_lm
  end interface

 
  !> Fake structure needed to document common arguments of the module
  type, private :: doc
     !> integer indicating the value of the column where the following 
     !! data have to be aligned. This is used when the field is opened with 
     !! flow=.true. so that the output is forced to start from the columns indicated
     !! by the value of tabbing. Should the cursor be already above this value,
     !! then the field is ignored.
     integer :: tabbing
     !> unit of the yaml_stream to be used for output. 
     !! its value is specified by the user according to the specification of the @link yaml_output::yaml_set_stream @endlink routine
     integer:: unit
     !> key of the mapping (or sequence). It represents the identifier of the value field which is associated to it
     character(len=1) :: mapname
     !> logical variable controlling the flow of the output. Default is .false..
     !! When .true., the output is written in compact yaml flow style. See yaml specifications in
     !! http://www.yaml.org/spec/1.2/spec.html#id2759963 . Of course also nested field inside will be written
     !! in compact flow style, until the mapping or sequencing is closed.
     logical :: flow 
     !> define a anchor of the mapping, which can be used to deepcopy its value in another mapping
     !! see http://www.yaml.org/spec/1.2/spec.html#id2760395.
     character(len=1) :: label 
     !> define whether the i/o should be advancing (advance='yes') or not (advance='no').
     !! if the mapping (in the case of @link yaml_output::yaml_mapping_open @endlink) or sequencing @link yaml_output::yaml_sequence_open @endlink)
     !!has been opened with the value of flow  = .true.
     !! (or if the flow has been opened at a upper level) the output is always non-advancing
     !! (See @link yaml_output::yaml_newline @endlink for add a line in a output of a flow mapping).
     !! Otherwise, if absent, the output is always advancing.
     !! non-advancing i/o is useful for example when one wants to leave a comment after the end of a mapping.
     character(len=1) :: advance 
     !> tag description. Unused and should be probably removed
     character(len=1) :: tag 
     !> scalar value of the mapping may be of any scalar type
     !! it is internally converted to character with the usage of @link yaml_output::yaml_toa @endlink function
     character(len=1) :: mapvalue
  end type doc


  !> @addtogroup FLIB_YAML
  !!@{ Public routines (API of the module).@n
  !! Here follows the routines which are important for the usage of the yaml_output module
  !! which is a part of flib library.@n
  !! By clicking the links below you should be redirected to the documentation of the important routines
  !! @link yaml_output::yaml_new_document @endlink,  @link yaml_output::yaml_release_document @endlink, 
  !! @link yaml_output::yaml_map @endlink, 
  !! @link yaml_output::yaml_mapping_open @endlink,      @link yaml_output::yaml_mapping_close @endlink, 
  !! @link yaml_output::yaml_sequence @endlink, 
  !! @link yaml_output::yaml_sequence_open @endlink, @link yaml_output::yaml_sequence_close @endlink, 
  !! @link yaml_output::yaml_comment @endlink, 
  !! @link yaml_output::yaml_warning @endlink, 
  !! @link yaml_output::yaml_scalar @endlink, 
  !! @link yaml_output::yaml_newline @endlink, 
  !! @link yaml_output::yaml_toa @endlink, 
  !! @link yaml_output::yaml_date_and_time_toa @endlink, @link yaml_output::yaml_date_toa @endlink, @link yaml_output::yaml_time_toa @endlink.
  !! @n@n
  !! There are also @link yaml_output::yaml_set_stream routine @endlink, @link yaml_output::yaml_set_default_stream @endlink, 
  !!                @link yaml_output::yaml_close_stream @endlink,       @link yaml_output::yaml_swap_stream @endlink, 
  !!                @link yaml_output::yaml_get_default_stream @endlink, @link yaml_output::yaml_stream_attributes @endlink, 
  !!                @link yaml_output::yaml_close_all_streams @endlink,  @link yaml_output::yaml_dict_dump @endlink, 
  !!                @link yaml_output::yaml_dict_dump_all @endlink
  !! @} 

 
  
  !all the public routines below should be documented
  public :: yaml_new_document,yaml_release_document
  public :: yaml_map,yaml_mapping_open,yaml_mapping_close
  public :: yaml_sequence,yaml_sequence_open,yaml_sequence_close
  public :: yaml_comment,yaml_warning,yaml_scalar,yaml_newline
  public :: yaml_toa,yaml_date_and_time_toa,yaml_date_toa,yaml_time_toa
  public :: yaml_set_stream,yaml_flush_document,yaml_stream_connected
  public :: yaml_set_default_stream,yaml_close_stream,yaml_swap_stream
  public :: yaml_get_default_stream,yaml_stream_attributes,yaml_close_all_streams
  public :: yaml_dict_dump,yaml_dict_dump_all
  public :: is_atoi,is_atof,is_atol

  !for internal f_lib usage
  public :: yaml_output_errors

contains

  !> Initialize the stream to default values
  function stream_null() result(strm)
    implicit none
    type(yaml_stream) :: strm

    strm%document_closed=.true.
    strm%pp_allowed=.true.
    strm%unit=6
    strm%max_record_length=tot_max_record_length
    strm%flowrite=.false.
    strm%Wall=-1
    strm%indent=1
    strm%indent_previous=0
    strm%indent_step=2
    strm%tabref=40
    strm%icursor=1
    strm%itab_active=0
    strm%itab=0
    strm%ilevel=0
    strm%iflowlevel=0
    strm%ilast=0
    strm%icommentline=0
    strm%linetab=0
    strm%ievt_flow=0
    strm%flow_events=0
    nullify(strm%dict_warning)
  end function stream_null

  !> Initialize the variables of the module, like error definitions.
  !! should be called only once unless the module has been closed by close_all_streams
  subroutine assure_initialization()
     implicit none
     if (.not. module_initialized) module_initialized=associated(f_get_error_definitions())
     
     if (.not. module_initialized) then
        stop 'yaml_output module not initialized, f_lib_initialize not called'
        !module_initialized=.true.
        !call yaml_output_errors()
     end if

  end subroutine assure_initialization
  
  !> Set new_unit as the new default unit and return the old default unit.
  subroutine yaml_swap_stream(new_unit, old_unit, ierr)
    implicit none
    integer, intent(in) :: new_unit  !< new unit
    integer, intent(out) :: old_unit !< old unit
    integer, intent(out) :: ierr     !< error code

    call yaml_get_default_stream(old_unit)
    call yaml_set_default_stream(new_unit, ierr)
  end subroutine yaml_swap_stream

  !> Initialize the error messages
  subroutine yaml_output_errors()
    implicit none
    !initialize error messages
    call f_err_define('YAML_INVALID','Generic error of yaml module, invalid operation',&
         YAML_INVALID)
    call f_err_define('YAML_STREAM_ALREADY_PRESENT','The stream is already present',&
         YAML_STREAM_ALREADY_PRESENT)
    call f_err_define('YAML_STREAM_NOT_FOUND','The stream has not been found',&
         YAML_STREAM_NOT_FOUND)
    call f_err_define('YAML_UNIT_INCONSISTENCY',&
         'The array of the units is not in agreement with the array of the streams',&
         YAML_UNIT_INCONSISTENCY,&
         err_action='This is an internal error of yaml_output module, contact developers')
    !the module is ready for usage
    call dict_init(stream_files)
    module_initialized=.true.
  end subroutine yaml_output_errors

!!$  function stream_next_free_unit()
!!$    integer :: stream_next_free_unit
!!$    logical :: unit_is_open
!!$    integer :: ierr
!!$
!!$    stream_next_free_unit = 75214
!!$    unit_is_open = .true.
!!$    do while (unit_is_open)
!!$       stream_next_free_unit = stream_next_free_unit + 1
!!$       inquire(unit=stream_next_free_unit,opened=unit_is_open,iostat=ierr)
!!$       if (f_err_raise(ierr /=0,'error in unit inquiring, ierr='//trim(yaml_toa(ierr)),&
!!$            YAML_INVALID)) return
!!$    end do
!!$  end function stream_next_free_unit
  
  !> Set the default stream of the module. Return  a STREAM_ALREADY_PRESENT errcode if
  !! The stream has not be initialized.
  subroutine yaml_set_default_stream(unit,ierr)
    implicit none
    integer, intent(in) :: unit  !< stream unit
    integer, intent(out) :: ierr !< error code
    !local variables
    integer :: istream

    !check if the stream is present
    call get_stream(unit,istream,istat=ierr)
    if (ierr==0) then
       default_stream=istream
    end if

  end subroutine yaml_set_default_stream


  !> Get the default stream unit
  pure subroutine yaml_get_default_stream(unit)
    implicit none
    integer, intent(out) :: unit

    unit=stream_units(default_stream)

  end subroutine yaml_get_default_stream


  !> Get the unit associated to filename, if it is currently connected.
  subroutine yaml_stream_connected(filename, unit, istat)
    implicit none
    character(len=*), intent(in) :: filename !< Filename of the stream to inquire
    integer, intent(out)         :: unit     !< File unit specified by the user.(by default 6) Returns a error code if the unit
    integer, optional, intent(out) :: istat  !< Status, zero if suceeded. When istat is present this routine is non-blocking, i.e. it does not raise exceptions.

    integer, parameter :: NO_ERRORS           = 0

    !check that the module has been initialized
    call assure_initialization()

    if (present(istat)) istat = NO_ERRORS !so far

    unit = 0
    if (has_key(stream_files, trim(filename))) then
       unit = stream_files // trim(filename)
    else
       if (present(istat)) istat = YAML_STREAM_NOT_FOUND
    end if
  end subroutine yaml_stream_connected

  !> Set all the output from now on to the file indicated by stdout
  !! therefore the default stream is now the one indicated by unit
  subroutine yaml_set_stream(unit,filename,istat,tabbing,record_length,position,setdefault)
    use f_utils, only: f_utils_recl,f_get_free_unit
    implicit none
    integer, optional, intent(in) :: unit              !< File unit specified by the user.(by default 6) Returns a error code if the unit
                                                       !! is not 6 and it has already been opened by the processor
    integer, optional, intent(in) :: tabbing           !< Indicate a tabbing for the stream (0 no tabbing, default)
    integer, optional, intent(in) :: record_length     !< Maximum number of columns of the stream (default @link yaml_output::yaml_stream::tot_max_record_length @endlink)
    character(len=*), optional, intent(in) :: filename !< Filename of the stream
    character(len=*), optional, intent(in) :: position !< specifier of the position while opening the unit (all fortran values of position specifier in open statement are valid)
    integer, optional, intent(out) :: istat            !< Status, zero if suceeded. When istat is present this routine is non-blocking, i.e. it does not raise exceptions.
    logical, optional, intent(in) :: setdefault        !< decide if the new stream will be set as default stream. True if absent
                                                       !! it is up the the user to deal with error signals sent by istat

    !local variables
    integer, parameter :: NO_ERRORS           = 0
    logical :: unit_is_open,set_default
    integer :: istream,unt,ierr
    !integer(kind=8) :: recl_file
    integer :: recl_file
    character(len=15) :: pos
        
    !check that the module has been initialized
    call assure_initialization()

    if (present(istat)) istat=NO_ERRORS !so far

    if (present(unit)) then
       unt=unit
    else
       if (present(filename)) then
          if (has_key(stream_files, trim(filename))) then
             unt=stream_files // trim(filename)
          else
             unt=f_get_free_unit()!stream_next_free_unit()
          end if
       else
          unt=6
       end if
    end if

    !open fortran unit if needed
    recl_file=0
    if (present(filename) .and. unt /= 6) then
       !inquire whether unit exists already
       inquire(unit=unt,opened=unit_is_open,iostat=ierr)
       if (f_err_raise(ierr /=0,'error in unit inquiring, ierr='//trim(yaml_toa(ierr)),&
               YAML_INVALID)) return
       if (unit_is_open) then
          if(present(istat)) then
             istat=YAML_STREAM_ALREADY_PRESENT
          else
             call f_err_throw('The unit '//trim(yaml_toa(unt))//' is already present',&
                  YAML_STREAM_ALREADY_PRESENT)
          end if
       end if
       if (present(position)) then
          pos(1:len(pos))=position
       else
          pos(1:len(pos))='append'
       end if
       if (.not. unit_is_open) then
          !inquire also file opening
          inquire(file=trim(filename),opened=unit_is_open,iostat=ierr)
          if (f_err_raise(ierr /=0,'error in file inquiring, ierr='//trim(yaml_toa(ierr)),&
               YAML_INVALID)) return
          if (unit_is_open) then
             if(present(istat)) then
                istat=YAML_STREAM_ALREADY_PRESENT
             else
                call f_err_throw('The file '//trim(filename)//' is already connected',&
                     YAML_STREAM_ALREADY_PRESENT)
             end if
          end if
          open(unit=unt,file=trim(filename),status='unknown',position=trim(pos),iostat=ierr)
          if (present(istat)) then
             istat = ierr
          else
             if (f_err_raise(ierr /=0,'error in file opening, ierr='//trim(yaml_toa(ierr)),&
                  YAML_INVALID)) return
          end if
       end if
       if (ierr == 0 .and. .not. unit_is_open) then
          !inquire the record length for the unit
          !inquire(unit=unt,recl=recl_file)
          if (present(record_length)) call f_utils_recl(unt,record_length,recl_file)
          call set(stream_files // trim(filename), trim(yaml_toa(unt)))
       end if
    end if

    if (present(setdefault)) then
       set_default=setdefault
    else
       set_default=.true.
    end if

    !check if unit has been already assigned
    do istream=1,active_streams
       if (unt==stream_units(istream)) then
          !raise error if istat is not present
          if (f_err_raise(.not. present(istat),&
               'Unit '//trim(yaml_toa(unt))//' already present',&
               err_id=YAML_STREAM_ALREADY_PRESENT)) then
             return
          else
             istat=YAML_STREAM_ALREADY_PRESENT
             return
          end if
       end if
    end do

    !if there is no active streams setdefault cannot be false.
    !at least open the stdout
    if (.not. set_default .and. active_streams==0) then
       !this is equivalent to yaml_set_streams(record_length=92)
       !assign the unit to the new stream
       active_streams=active_streams+1
       !initalize the stream
       streams(active_streams)=stream_null()
       streams(active_streams)%unit=6
       stream_units(active_streams)=6
       streams(active_streams)%max_record_length=92
    end if

    !assign the unit to the new stream
    active_streams=active_streams+1
    !initalize the stream
    streams(active_streams)=stream_null()
    streams(active_streams)%unit=unt
    stream_units(active_streams)=unt

    ! set last opened stream as default stream
    if (set_default) default_stream=active_streams

    if (present(tabbing)) then
       streams(active_streams)%tabref=tabbing
       if (tabbing==0) streams(active_streams)%pp_allowed=.false.
    end if
    !protect the record length to be lower than the maximum allowed by the processor
    if (present(record_length)) then
       if (recl_file<=0) recl_file=record_length!int(record_length,kind=8)
       streams(active_streams)%max_record_length=recl_file!int(min(int(record_length,kind=8),recl_file))
    end if
  end subroutine yaml_set_stream


  !> Get the attributes of the stream at present
  !! Display is dump=.true.
  subroutine yaml_stream_attributes(unit,stream_unit,&
       icursor,flowrite,itab_active,iflowlevel,ilevel,ilast,indent,indent_previous,&
       record_length)
    implicit none
    integer, intent(in) , optional :: unit            !< File unit to display
    integer, intent(in) , optional :: stream_unit     !< Stream Id
    logical, intent(out), optional :: flowrite        !< @copydoc yaml_stream::flowrite
    integer, intent(out), optional :: icursor         !< @copydoc yaml_stream::icursor
    integer, intent(out), optional :: itab_active     !< @copydoc yaml_stream::itab_active
    integer, intent(out), optional :: iflowlevel      !< @copydoc yaml_stream::iflowlevel
    integer, intent(out), optional :: ilevel          !< @copydoc yaml_stream::ilevel
    integer, intent(out), optional :: ilast           !< @copydoc yaml_stream::ilast
    integer, intent(out), optional :: indent          !< @copydoc yaml_stream::indent
    integer, intent(out), optional :: indent_previous !< @copydoc yaml_stream::indent_previous
    integer, intent(out), optional :: record_length   !< Maximum number of columns of the stream (default @link yaml_output::yaml_stream::tot_max_record_length @endlink)
    !local variables
    logical :: dump,flowritet
    integer :: sunt,unt,strm,icursort,itab_activet
    integer :: iflowlevelt,ilevelt,ilastt,indentt
    integer :: indent_previoust,record_lengtht
    integer, dimension(tot_max_record_length/tab) :: linetab

    !writing unit
    unt=0
    if (present(unit)) unt=unit
    !stream to be analyzed
    sunt=0
    if (present(stream_unit)) sunt=unit
    call get_stream(sunt,strm)

    !copy the values
    icursort=streams(strm)%icursor
    flowritet=streams(strm)%flowrite
    iflowlevelt=streams(strm)%iflowlevel
    ilevelt=streams(strm)%ilevel
    ilastt=streams(strm)%ilast
    itab_activet=streams(strm)%itab_active
    linetab=streams(strm)%linetab
    indentt=streams(strm)%indent
    indent_previoust=streams(strm)%indent_previous
    record_lengtht=streams(strm)%max_record_length

    dump=.true.
    !check if the variables have to be imported or not
    if (present(icursor)) then
       icursor=icursort
       dump=.false.
    end if
    if (present(flowrite)) then
       flowrite=flowritet
       dump=.false.
    end if
    if (present(indent)) then
       indent=indentt
       dump=.false.
    end if
    if (present(indent_previous)) then
       indent_previous=indent_previoust
       dump=.false.
    end if
    if (present(itab_active)) then
       itab_active=itab_activet
       dump=.false.
    end if
    if (present(iflowlevel)) then
       iflowlevel=iflowlevelt
       dump=.false.
    end if
    if (present(ilevel)) then
       ilevel=ilevelt
       dump=.false.
    end if
    if (present(ilast)) then
       ilast=ilastt
       dump=.false.
    end if
    if (present(record_length)) then
       record_length=record_lengtht
       dump=.false.
    end if


    if (dump) then
       call yaml_newline(unit=unt)
       call yaml_mapping_open('Attributes of the Stream',unit=unt)
       call yaml_map('Cursor position',icursort,unit=unt)
       call yaml_map('Max. Record Length',record_lengtht,unit=unt)
       call yaml_map('Indent value',indentt,unit=unt)
       call yaml_map('Indent value Saved',indent_previoust,unit=unt)
       call yaml_map('Write in Flow',flowritet,unit=unt)
       call yaml_map('Flow Level',iflowlevelt,unit=unt)
         call yaml_map('Level',ilevelt,unit=unt)
         call yaml_map('Last Level (flow==.false.)',ilastt,unit=unt)
       call yaml_map('Active Tabulars',itab_activet,unit=unt)
       if (itab_activet>0) call yaml_map('Tabular Values',linetab(1:itab_activet),unit=unt)
       call yaml_mapping_close(unit=unt)
       call yaml_newline(unit=unt)
    end if
  end subroutine yaml_stream_attributes


  !> Create a new document
  !! Put document_closed to .false.
  !! Check if already used before yaml_release_document by testing document_closed
  !! In this case, do nothing
  subroutine yaml_new_document(unit)
    implicit none
    integer, optional, intent(in) :: unit !< @copydoc doc::unit
    !local variables
    integer :: unt,strm

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    if (streams(strm)%document_closed) then
       !Check all indentation
       if (streams(strm)%indent /= 1) then
          call yaml_warning("Indentation error. Yaml Document has not been closed correctly",unit=stream_units(strm))
          streams(strm)%indent=1
       end if
       call dump(streams(strm),'---',event=DOCUMENT_START)
       streams(strm)%flow_events=NONE
       streams(strm)%document_closed=.false.
    end if

  end subroutine yaml_new_document

  !> Flush the content of the document. 
  !! @ingroup FLIB_YAML
  subroutine yaml_flush_document(unit)
    implicit none
    integer, optional, intent(in) :: unit  !< @copydoc doc::unit
    !local variables
    integer :: unt,strm

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    !call the flush routine which
    call f_utils_flush(streams(strm)%unit)
  end subroutine yaml_flush_document


  !> Release the document. if a new_document is opened, the symbol of START_DOCUMENT "---"
  !! will be displayed on the corresponding unit
  !! After this routine is called, the new_document will become effective again
  !! @ingroup FLIB_YAML
  subroutine yaml_release_document(unit)
    implicit none
    integer, optional, intent(in) :: unit  !< @copydoc doc::unit
    !local variables
    integer :: unt,strm,unit_prev

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    !here we should print the warnings which have been obtained
    if (associated(streams(strm)%dict_warning)) then
       call yaml_newline()
       call yaml_comment('Warnings obtained during the run, check their relevance!',hfill='-')
       call yaml_dict_dump(streams(strm)%dict_warning,flow=.false.)
       call dict_free(streams(strm)%dict_warning)
    end if

    !Initialize the stream, keeping the file unit
    unit_prev=streams(strm)%unit
    streams(strm)=stream_null()
    streams(strm)%unit=unit_prev

  end subroutine yaml_release_document

  !< close one stream and free its place
  !! should this stream be the default stream, stdout becomes the default
  subroutine yaml_close_stream(unit,istat)
    implicit none
    integer, optional, intent(in) :: unit   !< @copydoc doc::unit
    integer, optional, intent(out) :: istat !<error code, zero if suceeded
    !local variables
    integer :: unt,istatus,strm,funt
    type(dictionary), pointer :: iter

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm,istat=istatus)

    !unit 6 cannot be closed
    if (f_err_raise(unt==6,'Stream of unit 6 cannot be closed',&
         err_id=YAML_INVALID)) return

    if (present(istat)) then
       istat=istatus
       if (istatus==YAML_STREAM_NOT_FOUND) return
    else
       !if the stream has not been found raise an error
       if (f_err_raise(istatus==YAML_STREAM_NOT_FOUND,&
            'Unit '//trim(yaml_toa(unt))//' not found',&
            err_id=YAML_STREAM_NOT_FOUND)) return
    end if
    
    !as far as the unit has been found close the stream
    !check if there is no unit inconsistency 
    !(this is an internal error therefore istat is ignored)
    if (f_err_raise(stream_units(strm) /= unt,&
         'Unit '//trim(yaml_toa(unt))//' inconsistent',&
         err_id=YAML_UNIT_INCONSISTENCY)) return

    !release all the documents to print out warnings and free warning dictionary if it existed
    call yaml_release_document(unit=unt)

    !close files which are not stdout and remove them from stream_files
    if (unt /= 6) close(unt)
    iter => dict_iter(stream_files)
    do while (associated(iter))
       funt = iter
       if (funt == unt) then
          if (dict_size(stream_files) == 1) then
             call dict_remove(stream_files, dict_key(iter))
             call dict_init(stream_files)
          else
             call dict_remove(stream_files, dict_key(iter))
          end if
          exit
       end if
       iter => dict_next(iter)
    end do
    !reset the stream information
    !reduce the active_stream
    if (strm /= active_streams) then
       streams(strm)=streams(active_streams)
       stream_units(strm)=stream_units(active_streams)
    end if

    !in case the active stream is the last one move at the place of this one
    if (default_stream==active_streams) then
       default_stream=strm
    else if (default_stream==strm) then
       default_stream=1
    end if

    streams(active_streams)=stream_null()
    stream_units(active_streams)=6
    active_streams=active_streams-1
    
  end subroutine yaml_close_stream

  !> Close all the streams of all opened units
  !! The module will come back to its initial status
  subroutine yaml_close_all_streams()
    implicit none

    !local variables
    integer :: istream,unt
!!$    integer :: unts

    do istream=1,active_streams
       unt=stream_units(istream)
       !unit 6 cannot be closed
       if (unt /= 6) then
          call yaml_close_stream(unit=unt)
          !but its document can be released
       else
          call yaml_release_document(unit=unt)
       end if
    end do
    call dict_free(stream_files)
    stream_units=6
    active_streams=1 !stdout is always kept active
    default_stream=1
    module_initialized=.false.
  end subroutine yaml_close_all_streams


  !> Display a warning (yaml comment starting with '\#WARNING: ')
  subroutine yaml_warning(message,level,unit)
    implicit none
    character(len=*), intent(in) :: message !< Warning message
    integer, optional, intent(in) :: level  !< Level of the message (if < Wall then abort)
    integer, optional, intent(in) :: unit   !< @copydoc doc::unit
    !local variables
    integer :: unt,strm
!!$    integer :: item
!!$    type(dictionary), pointer :: dict_tmp

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

!    call dump(streams(strm),' #WARNING: '//trim(message))
    call yaml_comment('WARNING: '//trim(message),unit=unt)
    !here we should add a collection of all the warning which are printed out in the code.
    if (.not. streams(strm)%document_closed) then
!!$       if (.not. associated(streams(strm)%dict_warning)) then
!!$          call dict_init(streams(strm)%dict_warning)
!!$          call set(streams(strm)%dict_warning//'WARNINGS'//0,trim(message))
!!$       else
!!$          !add the warning as a list
!!$          dict_tmp=>streams(strm)%dict_warning//'WARNINGS'
!!$          item=dict_tmp%data%nitems
!!$          call set(dict_tmp//item,trim(message))
!!$       end if
       if (.not. associated(streams(strm)%dict_warning)) &
            call dict_init(streams(strm)%dict_warning)
       !add the warning as a list
       call add(streams(strm)%dict_warning//'WARNINGS',trim(message))

    end if
    if (present(level)) then
       if (level <= streams(strm)%Wall) then
          call dump(streams(strm),' Critical warning level reached, aborting...')
          call yaml_release_document(unit=unt)
          stop
       end if
    end if
  end subroutine yaml_warning


  !> Write a yaml comment (#......).
  !! Split the comment if too long
  subroutine yaml_comment(message,advance,unit,hfill,tabbing)
    implicit none
    character(len=*), intent(in) :: message           !< The given comment (without #)
    character(len=*), optional, intent(in) :: advance !< @copydoc doc::advance
    integer, optional, intent(in) :: unit             !< @copydoc doc::unit
    character(len=1), optional, intent(in) :: hfill   !< If present fill the line with the given character
    integer, optional, intent(in) :: tabbing          !< Number of space for tabbing
    !Local variables
    integer :: unt,strm,msg_lgt,tb,ipos
    integer :: lstart,lend,lmsg,lspace,hmax
    character(len=3) :: adv
    character(len=tot_max_record_length) :: towrite

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    !comment to be written
    if (present(advance)) then
       adv=advance
    else
       adv='yes'
    end if

    !Beginning of the message
    lstart=1
    !Length of the message to write (without blank characters)
    lmsg=len_trim(message)

    !Split the message if too long
    do
       !Position of the cursor
       ipos=max(streams(strm)%icursor,streams(strm)%indent)

       msg_lgt=0
       if (present(tabbing)) then
          tb=max(tabbing-ipos-1,1)
          call buffer_string(towrite,len(towrite),repeat(' ',tb),msg_lgt)
          ipos=ipos+tb
       end if

       !Detect the last character of the message
       lend=len_trim(message(lstart:))
       if (lend+msg_lgt+2 > streams(strm)%max_record_length) then
          !We have an error from buffer_string so we split it!
          !-1 to be less and -2 for the character '#'
          lend=streams(strm)%max_record_length-msg_lgt-2
          !We are looking for the first ' ' from the end
          lspace=index(message(lstart:lstart+lend-1),' ',back=.true.)
          if (lspace /= 0) then
             lend = lspace
          end if
       end if
       call buffer_string(towrite,len(towrite),message(lstart:lstart+lend-1),msg_lgt)

       !print *,'there',trim(towrite),lstart,lend
       

       !Check if possible to hfill
       hmax = max(streams(strm)%max_record_length-ipos-len_trim(message)-3,0)
       !print *,'hmax',hmax,streams(strm)%max_record_length,ipos,lmsg
       if (present(hfill) .and. hmax > 0) then
          !Fill with the given character and dump
          call dump(streams(strm),repeat(hfill,hmax)//' '//towrite(1:msg_lgt),advance=adv,event=COMMENT)
       else
          !Dump the string towrite into the stream
          !print *,'dumping here',msg_lgt,towrite(1:msg_lgt)
          call dump(streams(strm),towrite(1:msg_lgt),advance=adv,event=COMMENT)
       end if

       !Check if all the message is written
       !So we start from iend+1
       lstart=lstart+lend
       if (lstart>lmsg) then
          exit
       end if
    end do

  end subroutine yaml_comment


  !> Write a scalar variable, takes care of indentation only
  subroutine yaml_scalar(message,advance,unit,hfill)
    implicit none
    character(len=1), optional, intent(in) :: hfill   !< If present fill the line with the given character
    character(len=*), intent(in) :: message           !< the message to be printed
    integer, optional, intent(in) :: unit             !< @copydoc doc::unit
    character(len=*), intent(in), optional :: advance !< @copydoc doc::advance
    !local variables
    integer :: unt,strm
    character(len=3) :: adv

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    !comment to be written
    if (present(advance)) then
       adv=advance
    else
       adv='yes'
    end if
    if (present(hfill)) then
       call dump(streams(strm),&
            repeat(hfill,&
            max(streams(strm)%max_record_length-&
            max(streams(strm)%icursor,streams(strm)%indent)-&
            len_trim(message)-3,0))//' '//trim(message),&
            advance=adv,event=COMMENT)
    else
       call dump(streams(strm),trim(message),advance=adv,event=SCALAR)
    end if

  end subroutine yaml_scalar


  !> Opens a yaml mapping field.
  !! Essentially, a mapping field can be thought as a dictionary of mappings.
  !! See yaml spec at <a href="http://www.yaml.org/spec/1.2/spec.html#id2760395"> this page </a>
  !! Therefore the yaml_mapping_open routine is necessary each time that
  !! the value of a map is another map. See also @link yaml_output::yaml_map @endlink and @link yaml_output::yaml_mapping_close @endlink routines
  !! @ingroup FLIB_YAML
  subroutine yaml_mapping_open(mapname,label,tag,flow,tabbing,advance,unit)
    implicit none
    character(len=*), optional, intent(in) :: mapname !< Key of the sequence. @copydoc doc::mapname
    character(len=*), optional, intent(in) :: label   !< @copydoc doc::label
    character(len=*), optional, intent(in) :: tag     !< @copydoc doc::tag
    logical, optional, intent(in) :: flow             !< @copydoc doc::flow
    character(len=*), optional, intent(in) :: advance !< @copydoc doc::advance
    integer, optional, intent(in) :: unit             !< @copydoc doc::unit
    integer, optional, intent(in) :: tabbing          !< @copydoc doc::tabbing
    include 'yaml_open-inc.f90'
!!$    integer, optional, intent(in) :: unit !< @copydoc doc::unit
!!$    integer, optional, intent(in) :: tabbing !< @copydoc doc::tabbing
!!$    character(len=*), optional, intent(in) :: mapname !< @copydoc doc::mapname
!!$    logical, optional, intent(in) :: flow !< @copydoc doc::flow
!!$    character(len=*), optional, intent(in) :: label !< @copydoc doc::label
!!$    character(len=*), optional, intent(in) :: tag !< @copydoc doc::tag
!!$    !local variables
!!$    logical :: doflow
!!$    integer :: msg_lgt
!!$    integer :: unt,strm
!!$    character(len=3) :: adv
!!$    character(len=tot_max_record_length) :: towrite
!!$
!!$    unt=0
!!$    if (present(unit)) unt=unit
!!$    call get_stream(unt,strm)
!!$
!!$    doflow=streams(strm)%flowrite
!!$    !override if already active
!!$    if (present(flow)) doflow=flow .or. doflow
!!$
!!$    msg_lgt=0
!!$    !put the message
!!$    if (present(mapname)) then
!!$       call buffer_string(towrite,len(towrite),trim(mapname),msg_lgt)
!!$       !put the semicolon
!!$       call buffer_string(towrite,len(towrite),':',msg_lgt)
!!$    end if
!!$    !put the optional tag description
!!$    if (present(tag) .and. len_trim(tag) > 0) then
!!$       call buffer_string(towrite,len(towrite),' !',msg_lgt)
!!$       call buffer_string(towrite,len(towrite),trim(tag),msg_lgt)
!!$    end if
!!$    !put the optional name
!!$    if (present(label) .and. len_trim(label) > 0) then
!!$       call buffer_string(towrite,len(towrite),' &',msg_lgt)
!!$       call buffer_string(towrite,len(towrite),trim(label),msg_lgt)
!!$    end if
!!$
!!$    call open_level(streams(strm),doflow)
!!$
!!$    if (doflow .or. msg_lgt==0) then
!!$       adv='no '
!!$    else
!!$       adv='yes'
!!$    end if

    call dump(streams(strm),towrite(1:msg_lgt),advance=trim(adv),event=MAPPING_START)

  end subroutine yaml_mapping_open


  !> Close the mapping. The mapping should have been previously opened by @link yaml_output::yaml_mapping_open @endlink
  !! @ingroup FLIB_YAML
  subroutine yaml_mapping_close(advance,unit)
    implicit none
    integer, optional, intent(in) :: unit !< @copydoc doc::unit
    character(len=*), optional, intent(in) :: advance !<@copydoc doc::advance
    !local variables
    integer :: unt,strm
    character(len=3) :: adv
    logical :: doflow

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    if (streams(strm)%iflowlevel > 1) then
       adv='no'
    else
       adv='yes'
    end if
    if (present(advance)) adv=advance

    call dump(streams(strm),' ',advance=trim(adv),event=MAPPING_END)

    doflow = (streams(strm)%flowrite)
    call close_level(streams(strm),doflow)

  end subroutine yaml_mapping_close


  !> Open a yaml sequence
  subroutine yaml_sequence_open(mapname,label,tag,flow,tabbing,advance,unit)
    implicit none
    character(len=*), optional, intent(in) :: mapname !< Key of the sequence. @copydoc doc::mapname
    character(len=*), optional, intent(in) :: label   !< @copydoc doc::label
    character(len=*), optional, intent(in) :: tag     !< @copydoc doc::tag
    logical, optional, intent(in) :: flow             !< @copydoc doc::flow
    character(len=*), optional, intent(in) :: advance !< @copydoc doc::advance
    integer, optional, intent(in) :: unit             !< @copydoc doc::unit
    integer, optional, intent(in) :: tabbing          !< @copydoc doc::tabbing
    include 'yaml_open-inc.f90'
    call dump(streams(strm),towrite(1:msg_lgt),advance=trim(adv),event=SEQUENCE_START)

  end subroutine yaml_sequence_open


  !> Close a yaml sequence
  subroutine yaml_sequence_close(advance,unit)
    implicit none
    character(len=*), optional, intent(in) :: advance
    integer, optional, intent(in) :: unit
    !local variables
    integer :: unt,strm
    character(len=3) :: adv
    logical :: doflow

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    if (streams(strm)%iflowlevel > 1) then
       adv='no'
    else
       adv='yes'
       if (present(advance)) adv=advance
    end if

    call dump(streams(strm),' ',advance=trim(adv),event=SEQUENCE_END)

    doflow = (streams(strm)%flowrite)
    call close_level(streams(strm),doflow)

  end subroutine yaml_sequence_close


  !> Add a new line in the flow
  !! This routine has a effect only if a flow writing is active
  !! Otherwise its effect is ignored
  subroutine yaml_newline(unit)
    implicit none
    integer, optional, intent(in) :: unit !< @copydoc doc::unit
    !local variables
    integer :: unt,strm

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    if (streams(strm)%icursor > 1) then
    !if (streams(strm)%flowrite .and. streams(strm)%icursor > 1) then
       call dump(streams(strm),' ',advance='yes',event=NEWLINE)
    end if
  end subroutine yaml_newline


  !> Write directly a yaml sequence, i.e. en element of a list
  subroutine yaml_sequence(seqvalue,label,advance,unit,padding)
    implicit none
    integer, optional, intent(in) :: unit               !<@copydoc doc::unit
    character(len=*), optional, intent(in) :: label     !<@copydoc doc::label
    character(len=*), optional, intent(in) :: seqvalue  !< value of the sequence
    character(len=*), optional, intent(in) :: advance   !<@copydoc doc::advance
    integer, intent(in), optional :: padding            !<pad the seqvalue with blanks to have more readable output
    !local variables
    integer :: msg_lgt,unt,strm,tb
    character(len=3) :: adv
    character(len=tot_max_record_length) :: towrite

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    adv='def' !default value
    if (present(advance)) adv=advance

    msg_lgt=0
    !put the optional name
    if (present(label)) then
       call buffer_string(towrite,len(towrite),' &',msg_lgt)
       call buffer_string(towrite,len(towrite),trim(label)//' ',msg_lgt)
    end if
    !put the value
    if (present(seqvalue)) &
         call buffer_string(towrite,len(towrite),trim(seqvalue),msg_lgt)

    if (present(padding)) then
       tb=padding-len_trim(seqvalue)
       if (tb > 0) call buffer_string(towrite,len(towrite),repeat(' ',tb),msg_lgt)
    end if

    call dump(streams(strm),towrite(1:msg_lgt),advance=trim(adv),event=SEQUENCE_ELEM)
  end subroutine yaml_sequence


  !> Create a yaml map with a scalar value
  subroutine yaml_map(mapname,mapvalue,label,tag,advance,unit)
    implicit none
    character(len=*), intent(in) :: mapname             !< @copydoc doc::mapname
    character(len=*), intent(in) :: mapvalue            !< scalar value of the mapping may be of any scalar type
                                                        !! it is internally converted to character with the usage of @link yaml_output::yaml_toa @endlink function
    character(len=*), optional, intent(in) :: label     !< @copydoc doc::label
    character(len=*), optional, intent(in) :: tag       !< @copydoc doc::tag
    character(len=*), optional, intent(in) :: advance   !< @copydoc doc::advance
    integer, optional, intent(in) :: unit               !< @copydoc doc::unit
    !local variables
    logical :: cut,redo_line
    integer :: msg_lgt,strm,unt,icut,istr,ierr,msg_lgt_ck,idbg
    character(len=3) :: adv
    character(len=tot_max_record_length) :: towrite

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    adv='def' !default value
    if (present(advance)) adv=advance

    msg_lgt=0

    !put the message
    call buffer_string(towrite,len(towrite),trim(mapname),msg_lgt)
    !put the semicolon
    call buffer_string(towrite,len(towrite),':',msg_lgt)
    !put the optional tag
    if (present(tag) .and. len_trim(tag) > 0) then
       call buffer_string(towrite,len(towrite),' !',msg_lgt)
       call buffer_string(towrite,len(towrite),trim(tag),msg_lgt)
    end if
    !put the optional name
    if (present(label) .and. len_trim(label) > 0) then
       call buffer_string(towrite,len(towrite),' &',msg_lgt)
       call buffer_string(towrite,len(towrite),trim(label),msg_lgt)
    end if
    !put a space
    call buffer_string(towrite,len(towrite),' ',msg_lgt)

    !while putting the message verify that the string is not too long
    msg_lgt_ck=msg_lgt
    !print *, 'here'
    if (len_trim(mapvalue) == 0) then
       call buffer_string(towrite,len(towrite),"null",msg_lgt,istat=ierr)
    else
       call buffer_string(towrite,len(towrite),trim(mapvalue),msg_lgt,istat=ierr)
    end if
    !print *, 'here2',ierr
    if (ierr ==0) then
       call dump(streams(strm),towrite(1:msg_lgt),advance=trim(adv),event=MAPPING,istat=ierr)
    end if
    !print *, 'here2b',ierr
    redo_line=ierr/=0
    if (redo_line) then
       !print *, 'here3',ierr,msg_lgt_ck,msg_lgt
       if (streams(strm)%flowrite) then
          call dump(streams(strm),towrite(1:msg_lgt_ck),advance=trim(adv),event=SCALAR)
       else
          if (present(label)) then
             call yaml_mapping_open(mapname,label=label,unit=unt)
          else
             call yaml_mapping_open(mapname,unit=unt)
          end if
       end if
!       if (streams(strm)%flowrite) call yaml_newline(unit=unt)
       icut=len_trim(mapvalue)
       istr=1
       cut=.true.
       msg_lgt=0
       idbg=0
       cut_line: do while(cut)
          idbg=idbg+1
          !print *,'hereOUTPU',cut,icut,idbg
       !verify where the message can be cut
          cut=.false.
          cut_message :do while(icut > streams(strm)%max_record_length - &
               max(streams(strm)%icursor,streams(strm)%indent))
             icut=index(trim((mapvalue(istr:istr+icut-1))),' ',back=.true.)
             !print *,'test',icut,streams(strm)%max_record_length,&
             !     max(streams(strm)%icursor,streams(strm)%indent),&
             !     streams(strm)%max_record_length - &
             !     max(streams(strm)%icursor,streams(strm)%indent),istr
             cut=.true.
          end do cut_message
          !if the first line is too long cut it abruptly
          if (icut == 0) icut = streams(strm)%max_record_length - &
               max(streams(strm)%icursor,streams(strm)%indent)+1
          call buffer_string(towrite,len(towrite),mapvalue(istr:istr+icut-1),msg_lgt)
          if (streams(strm)%flowrite .and. .not. cut) &
               call buffer_string(towrite,len(towrite),',',msg_lgt)
          call dump(streams(strm),towrite(1:msg_lgt),advance='yes',event=SCALAR)
          istr=istr+icut
          icut=len_trim(mapvalue)-istr+1
          !print *,'icut',istr,icut,mapvalue(istr:istr+icut-1),cut,istr+icut-1,len_trim(mapvalue)
          msg_lgt=0
         if (idbg==1000) exit cut_line !to avoid infinite loops
       end do cut_line
       if (.not.streams(strm)%flowrite) call yaml_mapping_close(unit=unt)
    end if

  end subroutine yaml_map

  !> Create a yaml map with a scalar value
  subroutine yaml_map_dict(mapname,mapvalue,label,unit,flow)
    implicit none
    character(len=*), intent(in) :: mapname             !< @copydoc doc::mapname
    type(dictionary), pointer, intent(in) :: mapvalue   !< scalar value of the mapping may be of any scalar type
                                                        !! it is internally converted to character with the usage of @link yaml_output::yaml_toa @endlink function
    character(len=*), optional, intent(in) :: label     !< @copydoc doc::label
    integer, optional, intent(in) :: unit               !< @copydoc doc::unit
    logical, optional, intent(in) :: flow               !< @copydoc doc::flow
    !local variables
    integer :: strm,unt
    character(len=max_field_length) :: lbl

    unt=0
    if (present(unit)) unt=unit
    call get_stream(unt,strm)

    lbl(1:len(lbl))=' '
    if (present(label)) lbl(1:len(lbl))=label

    if (associated(mapvalue)) then
       if (present(flow)) then
          call yaml_mapping_open(mapname,label=lbl,flow=flow,unit=unt)
          call yaml_dict_dump(mapvalue,unit=unt,flow=flow)
       else
          call yaml_mapping_open(mapname,label=lbl,unit=unt)
          call yaml_dict_dump(mapvalue,unit=unt)
       end if
       call yaml_mapping_close(unit=unt)
    else
       call yaml_map(mapname,'<nullified dictionary>',label=lbl,unit=unt)
    end if
  end subroutine yaml_map_dict

  subroutine yaml_map_li(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    integer(kind=8), intent(in) :: mapvalue
    include 'yaml_map-inc.f90'
  end subroutine yaml_map_li

  subroutine yaml_map_i(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    integer, intent(in) :: mapvalue
    include 'yaml_map-inc.f90'
  end subroutine yaml_map_i

  subroutine yaml_map_f(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real, intent(in) :: mapvalue
    include 'yaml_map-inc.f90'
  end subroutine yaml_map_f

  subroutine yaml_map_d(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real(kind=8), intent(in) :: mapvalue
    include 'yaml_map-inc.f90'
  end subroutine yaml_map_d

  subroutine yaml_map_l(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    logical,  intent(in) :: mapvalue
    include 'yaml_map-inc.f90'
  end subroutine yaml_map_l

  subroutine yaml_map_dv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real(kind=8), dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_dv

  subroutine yaml_map_rv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real, dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_rv


  !> Character vector
  subroutine yaml_map_cv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    character(len=*), dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_cv

  subroutine yaml_map_lv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    logical, dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_lv

  subroutine yaml_map_liv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    integer(kind=8), dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_liv

  subroutine yaml_map_iv(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    integer, dimension(:), intent(in) :: mapvalue
    include 'yaml_map-arr-inc.f90'
  end subroutine yaml_map_iv

  !> double-precision rank2 matrix
  subroutine yaml_map_dm(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real(kind=8), dimension(:,:), intent(in) :: mapvalue
    include 'yaml_map-mat-inc.f90'
  end subroutine yaml_map_dm

  subroutine yaml_map_rm(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    real, dimension(:,:), intent(in) :: mapvalue
    include 'yaml_map-mat-inc.f90'
  end subroutine yaml_map_rm

  subroutine yaml_map_im(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    integer, dimension(:,:), intent(in) :: mapvalue
    include 'yaml_map-mat-inc.f90'
  end subroutine yaml_map_im

  subroutine yaml_map_lm(mapname,mapvalue,label,advance,unit,fmt)
    implicit none
    logical, dimension(:,:), intent(in) :: mapvalue
    include 'yaml_map-mat-inc.f90'
  end subroutine yaml_map_lm

  
  !> Get the stream, initialize if not already present (except if istat present)
  subroutine get_stream(unt,strm,istat)
    implicit none
    integer, intent(in) :: unt
    integer, intent(out) :: strm
    integer, optional, intent(out) :: istat
    !local variables
    logical :: stream_found
    integer :: istream,prev_def,ierr

    !check that the module has been initialized
    call assure_initialization()

    if (present(istat)) istat=0

    if (unt==0) then
       !if there are no active streams activate them (to circumvent g95 bug)
       if (active_streams==0) call yaml_set_stream(record_length=92,istat=ierr)
       strm=default_stream
    else
       !it is assumed that the unit exists
       stream_found=.false.
       do istream=1,active_streams
          if (stream_units(istream)==unt) then
             strm=istream
             stream_found=.true.
             exit
          end if
       end do
       if (.not. stream_found) then
          if (present(istat)) then
             istat=YAML_STREAM_NOT_FOUND
          else
             !otherwise initialize it, no pretty printing, not default stream
             !if it is the first activate stdout first
             if (active_streams==0 .and. unt /=6) call yaml_set_stream(record_length=92,istat=ierr)
             prev_def=default_stream
             call yaml_set_stream(unit=unt,tabbing=0)
             strm=default_stream
             !but do not change default stream
             default_stream=prev_def
          end if
       end if
    end if

  end subroutine get_stream


  !> This routine is the key of the module, handling the events and
  !! writing into the stream.
  subroutine dump(stream,message,advance,event,istat)
    implicit none
    type(yaml_stream), intent(inout) :: stream          !< Stream to handle
    character(len=*), intent(in) :: message             !< Message to dump
    character(len=*), intent(in), optional :: advance   !< Advance option
    integer, intent(in), optional :: event              !< Event to handle
    integer, intent(out), optional :: istat             !< Status error
    !local variables
    logical :: ladv,change_line,reset_line,pretty_print
    logical :: reset_tabbing,comma_postponed,extra_line
    integer :: evt,indent_lgt,msg_lgt,shift_lgt,prefix_lgt
    integer :: towrite_lgt
    character(len=1) :: anchor
    character(len=3) :: adv
    character(len=5) :: prefix
    character(len=stream%max_record_length) :: towrite

    if(present(istat)) istat=0 !no errors

    if (present(event)) then
       evt=event
    else !default event: scalar value
       evt=SCALAR
    end if

    !decide whether to write advanced or not
    !decide if advanced output or not
    ladv=.not.stream%flowrite
    if (present(advance)) then
       if (trim(advance)=='no' .or. trim(advance)=='NO') then
          ladv=.false.
       else if (trim(advance)=='yes' .or. trim(advance)=='YES') then
          ladv=.true.
       end if
    end if
    if (ladv) then
       adv='yes'
    else
       adv='no '
    end if

    !decide whether the line has to be reset (no by default)
    reset_line=.false.

    !decide whether the line has to be continuated (no by default)
    change_line=.false.

    !possible indentation (depending of the event) and of the cursor
    indent_lgt=indent_value(stream,evt)
    !write(*,fmt='(a,i0,a)',advance="no") '(lgt ',indent_lgt,')'

    !calculate the number of objects to be written before
    !these objects should go to the active line in case of a new line
    !string length, and message body
    !initialize it
    towrite=repeat(' ',len(towrite))
    msg_lgt=0
    !a empty message is not written
!    print *,'thisone'
    if (.not. present(istat)) then
       if (len_trim(message) > 0) &
            call buffer_string(towrite,len(towrite),message,msg_lgt)
    else
       call buffer_string(towrite,len(towrite),message,msg_lgt,istat=istat)
    end if
!    print *,'not really'
    prefix_lgt=0
    !initialize it
    prefix=repeat(' ',len(prefix))
    !write(stdout,*)'NOT DONE',icomma,flowrite,iflowlevel
    !msg_lgt should be added to the function
    if (put_comma(stream,evt)) then!stream%icomma==1 .and. stream%flowrite) then
       call buffer_string(prefix,len(prefix),', ',prefix_lgt)
    end if
    !next time comma should be postponed
    comma_postponed=comma_not_needed(evt) .or. (flow_is_ending(evt) .and. stream%iflowlevel ==1)

    !no pretty printing by default
    pretty_print=.false.
    shift_lgt=0

    !reset_tabbing is disabled
    reset_tabbing=.false.

    !set module variables according to the event
    select case(evt)

    case(SEQUENCE_START)

       if (.not.stream%flowrite) then
          call open_indent_level(stream)
       else
          call buffer_string(towrite,len(towrite),' [',msg_lgt)
          !comma has to be written afterwards, if there is a message
          !stream%flowrite=-1
          stream%flowrite=.true.
          !added for pretty printing
          reset_tabbing=.true.
       end if

    case(SEQUENCE_END)
       !print *,'here',prefix_lgt,prefix,icomma,flowrite,iflowlevel

       if (.not.stream%flowrite) then
          call close_indent_level(stream)
       else
          if (stream%iflowlevel > 1 .and. ladv) then
             call buffer_string(prefix,len(prefix),']',prefix_lgt,back=.true.)
             !stream%flowrite=-1
             stream%flowrite=.true.
          else
             call buffer_string(prefix,len(prefix),']',prefix_lgt)
          end if
          reset_line=ladv
       end if

    case(MAPPING_START)

       if (.not.stream%flowrite) then
          call open_indent_level(stream)
       else
          !write(stdout,*)'here',prefix,'there',icomma,flowrite,iflowlevel
          call buffer_string(towrite,len(towrite),' {',msg_lgt)
          !stream%flowrite=-1
          stream%flowrite=.true.
          reset_tabbing=.true.
       end if
       !write(*,fmt='(a,i0,a,a,a)',advance='no') '|',stream%indent,'|',trim(towrite),'|'

       !pretty_print=.true. .and. stream%pp_allowed

    case(MAPPING_END)

       if (.not.stream%flowrite) then
          call close_indent_level(stream)
       else
          if (stream%iflowlevel > 1 .and. ladv) then
             call buffer_string(prefix,len(prefix),'}',prefix_lgt,back=.true.)
             !flowrite=-1
             reset_line=.true.
          else
             call buffer_string(prefix,len(prefix),'}',prefix_lgt)
          end if
          reset_line=ladv
       end if

    case(COMMENT)
       if (stream%icommentline==0) then !no comment active
          call buffer_string(prefix,len(prefix),' #',prefix_lgt)
       end if
       if (.not. ladv) then
          stream%icommentline=1
       else
          reset_line=.true.
       end if

    case(MAPPING)

       pretty_print=.true. .and. stream%pp_allowed
       anchor=':'

    case(SEQUENCE_ELEM)

       if (.not.stream%flowrite) then
          !lower indent and update prefix
          indent_lgt=indent_lgt-2
          call buffer_string(prefix,len(prefix),'- ',prefix_lgt)
       else
          if (msg_lgt>0) comma_postponed=.false.
          !just added to change the line
          pretty_print=.true. .and. stream%pp_allowed
          anchor='.'
       end if

    case(SCALAR)

    case(NEWLINE)

       if (stream%flowrite) then
          !print *,'NEWLINE:',stream%flowrite
          change_line=.true.
          !stream%flowrite=-1
          stream%flowrite=.true.
          reset_line=ladv
          msg_lgt=0
       else
          change_line=.true.
          reset_line=.true.
          msg_lgt=0
       end if

    end select

    !adjust the towrite string to match with the closest tabular
    if (pretty_print) then
       call pretty_printing(stream%flowrite,anchor,towrite,&
            stream%icursor,indent_lgt,prefix_lgt,&
            msg_lgt,stream%max_record_length,shift_lgt,change_line)
    end if

    !standard writing,
    !if (change_line)  print *,'change_line',change_line,'prefix',prefix_lgt,msg_lgt,shift_lgt
    extra_line=.false.
    if (change_line) then
       !first write prefix, if needed
       if (prefix_lgt>0) then
          write(stream%unit,'(a)')prefix(1:prefix_lgt)
       else if (msg_lgt >0 .or. evt == NEWLINE) then
          !change line, only if istat is not present
          if (.not. present(istat)) then
             write(stream%unit,*)
          else
             extra_line=.true.
          end if
       end if
       stream%icursor=1
       towrite_lgt=msg_lgt+shift_lgt
    else
       call shiftstr(towrite,prefix_lgt)
       if (prefix_lgt > 0)towrite(1:prefix_lgt)=prefix(1:prefix_lgt)
       towrite_lgt=prefix_lgt+msg_lgt+shift_lgt
    end if
    !print *,'adv',trim(adv),towrite_lgt,stream%icursor,extra_line,msg_lgt,towrite_lgt
    !here we should check whether the size of the string exceeds the maximum length
    if (towrite_lgt > 0) then
       if (towrite_lgt > stream%max_record_length) then
          if (present(istat)) then
             istat=-1
             return
          else
             !crop the writing
             towrite_lgt=stream%max_record_length
             !stop 'ERROR (dump): writing exceeds record size'
          end if
       else
          if (extra_line) write(stream%unit,*)
          !write(*,fmt='(a,i0,a)',advance="no") '(indent_lgt ',indent_lgt,')'
          write(stream%unit,'(a)',advance=trim(adv))&
               repeat(' ',max(indent_lgt,0))//towrite(1:towrite_lgt)
       end if
    end if

    !if advancing i/o cursor is again one
    if (ladv) then
       stream%icursor=1
    else
       !cursor after writing
       stream%icursor=stream%icursor+indent_lgt+towrite_lgt
    end if

    if (reset_tabbing) then
       stream%itab_active=0
       stream%itab=0
    end if

    if (reset_line) call carriage_return(stream)

    !keep history of the event for a flowrite
    !needed for the comma
    if (stream%flowrite) then
       stream%ievt_flow=modulo(stream%ievt_flow,tot_max_flow_events)+1 !to avoid boundary problems
       if (comma_postponed) then
          stream%flow_events(stream%ievt_flow)=evt
       else
          stream%flow_events(stream%ievt_flow)=COMMA_TO_BE_PUT
       end if
    else
       stream%ievt_flow=0
    end if

  contains

    subroutine pretty_printing(rigid,anchor,message,icursor,&
         indent_lgt,prefix_lgt,msg_lgt,max_lgt,shift_lgt,change_line)
      implicit none
      logical, intent(in) :: rigid
      integer, intent(in) :: icursor,prefix_lgt,msg_lgt,max_lgt
      integer, intent(inout) :: indent_lgt
      character(len=*), intent(in) :: anchor
      character(len=*), intent(inout) :: message
      logical, intent(out) :: change_line
      integer, intent(out) :: shift_lgt
      !local variables
      integer :: iscpos,ianchor_pos,tabeff

      change_line=.false.
      iscpos=index(message,anchor)
      shift_lgt=0

      !alternative strategy, anchor to the first position
      !if (iscpos==0) return !no anchor, no pretty printing

      ianchor_pos=icursor+prefix_lgt+indent_lgt+iscpos-1
      call closest_tab(ianchor_pos,tabeff)
      !first attempt to see if the line enters
      shift_lgt=tabeff-ianchor_pos
      !print *, 'there',shift_lgt,msg_lgt,prefix_lgt,indent_lgt,icursor,max_lgt
      !print *,'condition',icursor+msg_lgt+prefix_lgt+indent_lgt+shift_lgt >= max_lgt
      !see if the line enters
      
      if (icursor+msg_lgt+prefix_lgt+indent_lgt+shift_lgt >= max_lgt) then
         !restart again
         change_line=.true.
         !reset newly created tab
         if (stream%itab==stream%itab_active .and. stream%itab > 1)&
              stream%itab_active=max(stream%itab_active-1,0)
         stream%itab=1
         if (indent_lgt==0) indent_lgt=1
         ianchor_pos=indent_lgt+iscpos
         call closest_tab(ianchor_pos,tabeff)

         shift_lgt=tabeff-ianchor_pos
      end if
      !print *, 'here',tabeff,itab,ianchor_pos,shift_lgt,change_line
      !at this point we know the size of the message.
      !we know also whether to write it or to pass to the following line
      !once the tabbing has been decided, adjust the message to the anchor
      call align_message(rigid,len(message),shift_lgt+iscpos,anchor,message)

    end subroutine pretty_printing


    !> Calculate the reference tabular value
    subroutine closest_tab(ianchor_pos,tabeff)
      implicit none
      integer, intent(in) :: ianchor_pos
      integer, intent(out) :: tabeff

      if (stream%flowrite) then
         !first check that the tabbing is already done, otherwise add another tab
         if (stream%itab < stream%itab_active) then
            !realign the value to the tabbing
            do
               if (ianchor_pos <= stream%linetab(stream%itab) .or. &
                    stream%itab==stream%itab_active) exit
               stream%itab=modulo(stream%itab,tot_max_record_length/tab)+1
            end do
         end if

         if (stream%itab < stream%itab_active .and. stream%itab>0) then
            tabeff=stream%linetab(stream%itab)
         else
            tabeff=ianchor_pos
            stream%itab=modulo(stream%itab,tot_max_record_length/tab)+1
            stream%itab_active=modulo(stream%itab_active,tot_max_record_length/tab)+1
            stream%linetab(stream%itab_active)=tabeff
         end if
      else
         !for the moment do not check compatibility of the line
         tabeff=max(stream%tabref,ianchor_pos)
      end if
    end subroutine closest_tab

    function indent_value(stream,evt)
      implicit none
      integer, intent(in) :: evt
      type(yaml_stream), intent(in) :: stream
      integer :: indent_value

      !write(*,fmt='(a,i0,i3,a)',advance="no") '(stream_indent ',stream%indent,stream%flowrite,')'
      if (.not.stream%flowrite .and. stream%icursor==1) then
         indent_value=stream%indent!max(stream%indent,0) !to prevent bugs
      !if first time in the flow recuperate the saved indent
      else if (stream%icursor==1 .and. stream%iflowlevel==1 &
           .and. stream%ievt_flow==0) then
         indent_value=stream%indent_previous
      else
         indent_value=0!1
         if (stream%icursor==1) indent_value=1
      end if

      if (evt==DOCUMENT_START) indent_value=0

!      if (stream%icursor > 1) then
!         indent_value=0
!      else if(.not.stream%flowrite) then !other conditions have to be added here
!         indent_value=max(stream%indent,0) !to prevent bugs
!      else
!         indent_value=stream%indent_previous
!      end if

    end function indent_value

    !> Decide whether comma has to be put
    function put_comma(stream,evt)
      implicit none
      integer, intent(in) :: evt
      type(yaml_stream), intent(inout) :: stream
      logical :: put_comma

      put_comma=stream%flowrite .and. stream%ievt_flow>0

      if (stream%ievt_flow > 0) then
         put_comma=stream%flow_events(stream%ievt_flow) == COMMA_TO_BE_PUT
         if (.not. put_comma .and. comma_potentially_needed(evt)) then
            !print *,'event'
            !control whether there is a ending flow
            !if (stream%iflowlevel > 1 .and.
         end if
      end if
      !in any case the comma should not be put before a endflow
      if (flow_is_ending(evt)) put_comma=.false.

    end function put_comma

  end subroutine dump


  function flow_is_starting(evt)
    implicit none
    integer, intent(in) :: evt
    logical flow_is_starting

    flow_is_starting=(evt==MAPPING_START .or. evt == SEQUENCE_START)

  end function flow_is_starting


  function flow_is_ending(evt)
    implicit none
    integer, intent(in) :: evt
    logical flow_is_ending

    flow_is_ending=(evt==MAPPING_END .or. evt == SEQUENCE_END)

  end function flow_is_ending


  pure function comma_not_needed(evt)
    implicit none
    integer, intent(in) :: evt
    logical :: comma_not_needed

    comma_not_needed=evt==NONE           .or. &
                     evt==MAPPING_START  .or. &
                     evt==SEQUENCE_START .or. &
                     evt==SCALAR         .or. &
                     evt==COMMENT        .or. &
                     evt==SEQUENCE_ELEM  .or. &
                     evt==NEWLINE
  end function comma_not_needed


  pure function comma_potentially_needed(evt)
    implicit none
    integer, intent(in) :: evt
    logical :: comma_potentially_needed

    comma_potentially_needed=evt==MAPPING_START  .or. &
                             evt==SEQUENCE_START .or. &
                             evt==SCALAR

  end function comma_potentially_needed


!!$  subroutine write_prefix(prefix_lgt,prefix,event)
!!$    implicit none
!!$    integer, intent(in) :: prefix_lgt,event
!!$    character(len=prefix_lgt), intent(out) :: prefix
!!$    !local variables
!!$    logical :: write_comma
!!$    integer :: iflw,nopen,nclose,ievt
!!$    if (flowrite==0) then
!!$       write_comma=.false.
!!$    else
!!$       nopen=0
!!$       nclose=0
!!$       do iflw=1,ievt_flow
!!$          ievt=flow_events(iflw)
!!$          if (ievt == MAPPING_START .or. ievt == SEQUENCE_START) nopen=nopen+1
!!$          if (ievt == MAPPING_END .or. ievt == SEQUENCE_END) nclose=nclose+1
!!$       end do
!!$       write_comma=(nopen > nclose)
!!$    end if
!!$
!!$  end subroutine write_prefix


  !> Reset the line control quantities, and reset the indentation
  subroutine carriage_return(stream)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    !if a yaml_comment is called put the has in front
    stream%icommentline=0
    !beginining of the line
    stream%icursor=1
    !no tabbing decided yet
    stream%itab_active=0
    stream%itab=0
    !all needed commas are placed in the previous line
  end subroutine carriage_return


  !> Open a level
  subroutine open_level(stream,doflow)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    logical, intent(in) :: doflow
    stream%ilevel = stream%ilevel + 1
    if(doflow) then
       call open_flow_level(stream)
    else
       stream%ilast = stream%ilevel
    end if
  end subroutine open_level


  !> Open a flow level (Indent more)
  subroutine open_flow_level(stream)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    if (.not.stream%flowrite) then
       if (stream%iflowlevel==0) stream%indent_previous=stream%indent
       stream%indent=1
    end if
    stream%iflowlevel=stream%iflowlevel+1
    if (.not.stream%flowrite) stream%flowrite=.true. !start to write
  end subroutine open_flow_level

  !> Close a level
  subroutine close_level(stream,doflow)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    logical, intent(in) :: doflow
    stream%ilevel = stream%ilevel - 1
    if(doflow) then
       call close_flow_level(stream)
    else
       stream%ilast = min(stream%ilevel,stream%ilast)
    end if
  end subroutine close_level


  !> Close a flow level (Indent less)
  subroutine close_flow_level(stream)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    !lower the flowlevel
    stream%iflowlevel=stream%iflowlevel-1
    if (stream%iflowlevel==0) then
       stream%indent=stream%indent_previous
       stream%flowrite=.false.
       !reset the events in the flow
       stream%flow_events=NONE
       stream%ievt_flow=0
    else
       stream%indent=1
       stream%flowrite=.true.
    end if

  end subroutine close_flow_level

  !> Increase the indentation of the strean without changing the flow level
  subroutine open_indent_level(stream)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    stream%indent=stream%indent+stream%indent_step
  end subroutine open_indent_level


  !> Decrease the indentation of the strean without changing the flow level
  subroutine close_indent_level(stream)
    implicit none
    type(yaml_stream), intent(inout) :: stream
    stream%indent=max(stream%indent-stream%indent_step,0) !to prevent bugs
  end subroutine close_indent_level
  
  !> Dump a dictionary
  subroutine yaml_dict_dump(dict,unit,flow,verbatim)
    implicit none
    type(dictionary), pointer, intent(in) :: dict !< Dictionary to dump
    logical, intent(in), optional :: flow         !< @copydoc doc::flow
    logical, intent(in), optional :: verbatim     !< if .true. print as comments the calls performed
    integer, intent(in), optional :: unit         !< unit in which the dump has to be 
    !local variables
    logical :: flowrite,verb,default_flow
    integer :: unt

    flowrite=.false.
    default_flow=.true.
    if (present(flow)) then
       flowrite=flow
       default_flow=.false.
    end if
    unt=0
    if (present(unit)) unt=unit
    verb=.false.
    if (present(verbatim)) verb=verbatim

    if (.not. associated(dict)) then
       call scalar('null')
    else if (associated(dict%child)) then
       call yaml_dict_dump_(dict%child)
    else
       call scalar(dict_value(dict))
    end if

  contains

    !> determine if we are at the last level of the dictionary
    function last_level(dict)
      implicit none
      type(dictionary), pointer, intent(in) :: dict
      logical :: last_level
      !local variables
      type(dictionary), pointer :: dict_tmp
      
      !we should have a sequence of only scalar values
      last_level = dict_len(dict) > 0
      if (last_level) then
         dict_tmp=>dict_next(dict%child)
         do while(associated(dict_tmp))
            if (dict_len(dict_tmp) > 0 .or. dict_size(dict_tmp) > 0) then
               last_level=.false.
               nullify(dict_tmp)
            else
               dict_tmp=>dict_next(dict_tmp)
            end if
         end do
      end if
    end function last_level

    function switch_flow(dict)
      implicit none
      type(dictionary), pointer, intent(in) :: dict
      logical :: switch_flow
      
      switch_flow=default_flow .and. last_level(dict) .and. dict_len(dict) <=5 .and. dict_len(dict) > 1
      
    end function switch_flow


    recursive subroutine yaml_dict_dump_(dict)
      implicit none
      type(dictionary), pointer, intent(in) :: dict

      if (.not. associated(dict)) return
      !here we iterate over dict_value which is dict%child if empty
      if (associated(dict%child)) then
         !see whether the child is a list or not
         if (dict_item(dict) >= 0) call sequence(adv='no')
         if (dict_len(dict) > 0) then
            !use flowrite in the case of the last level if no flow option is forced
            if (switch_flow(dict)) flowrite=.true.
            call open_seq(dict_key(dict))
            call yaml_dict_dump_(dict%child)
            call close_seq()
            !restoe normal flowriting if it has been changed before
            if (switch_flow(dict)) flowrite=.false.
         else
            if (dict_item(dict) >= 0) then
               call yaml_dict_dump_(dict%child)
            else
               call open_map(dict_key(dict))
               call yaml_dict_dump_(dict%child)
               call close_map()
            end if
         end if
      else
         if (dict_item(dict) >= 0) then
            call sequence(val=dict_value(dict))
         else
            call map(dict_key(dict),dict_value(dict))
         end if
      end if
      call yaml_dict_dump_(dict_next(dict))

    end subroutine yaml_dict_dump_


    subroutine scalar(val)
      implicit none
      character(len=*), intent(in) :: val
      if (verb) then
         call yaml_comment('call yaml_scalar("'//trim(val)//'",advance="'//trim(advc(flowrite))//&
              '",unit='//trim(adjustl(yaml_toa(unt)))//')')
      else
         call yaml_scalar(trim(val),advance=advc(flowrite),unit=unt)
      end if
    end subroutine scalar

    subroutine map(key,val)
      implicit none
      character(len=*), intent(in) :: key,val
      if (verb) then
         call yaml_comment('call yaml_map("'//trim(key)//'","'//trim(val)//&
              '",unit='//trim(adjustl(yaml_toa(unt)))//'")')
      else
         call yaml_map(trim(key),trim(val),unit=unt)
      end if
    end subroutine map

    subroutine sequence(adv,val)
      implicit none
      character(len=*), intent(in), optional :: val,adv

      if (present(val) .and. present(adv)) then
         if (verb) then
            call yaml_comment('call yaml_sequence("'//trim(val)//&
                 '",advance="'//trim(adv)//&
                 ',unit='//trim(adjustl(yaml_toa(unt)))//'")')
         else
            call yaml_sequence(trim(val),advance=adv,unit=unt)
         end if
      else if (present(adv)) then
         if (verb) then
            call yaml_comment('call yaml_sequence(advance="'//trim(adv)//&
                 ',unit='//trim(adjustl(yaml_toa(unt)))//'")')
         else
            call yaml_sequence(advance=adv,unit=unt)
         end if
      else if (present(val)) then
         if (verb) then
            call yaml_comment('call yaml_sequence("'//trim(val)//&
                 ',unit='//trim(adjustl(yaml_toa(unt)))//'")')
         else
            call yaml_sequence(trim(val),unit=unt)
         end if
      end if
    end subroutine sequence

    subroutine open_seq(key)
      implicit none
      character(len=*), intent(in) :: key
      if (verb) then
         call yaml_comment('call yaml_sequence_open("'//trim(key)//&
              '",flow='//trim(flw(flowrite))//&
              ',unit='//trim(adjustl(yaml_toa(unt)))//')')
      else
         call yaml_sequence_open(trim(key),flow=flowrite,unit=unt)
      end if
    end subroutine open_seq

    subroutine close_seq()
      implicit none
      if (verb) then
         call yaml_comment('call yaml_sequence_close('//&
              'unit='//trim(adjustl(yaml_toa(unt)))//')')
      else
         call yaml_sequence_close(unit=unt)
      end if
    end subroutine close_seq

    subroutine open_map(key)
      implicit none
      character(len=*), intent(in) :: key
      if (verb) then
         call yaml_comment('call yaml_mapping_open("'//trim(key)//&
              '",flow='//trim(flw(flowrite))//&
              ',unit='//trim(adjustl(yaml_toa(unt)))//')')
      else
         call yaml_mapping_open(trim(key),flow=flowrite,unit=unt)
      end if
    end subroutine open_map

    subroutine close_map()
      implicit none
      if (verb) then
         call yaml_comment('call yaml_mapping_close('//&
              'unit='//trim(adjustl(yaml_toa(unt)))//')')
      else
         call yaml_mapping_close(unit=unt)
      end if
    end subroutine close_map

    function flw(flow_tmp)
      implicit none
      logical, intent(in) :: flow_tmp
      character(len=7) :: flw

      if (flow_tmp) then
         flw='.true.'
      else
         flw='.false.'
      end if
    end function flw

    function advc(flow_tmp)
      implicit none
      logical, intent(in) :: flow_tmp
      character(len=3) :: advc

      if (flow_tmp) then
         advc='no '
      else
         advc='yes'
      end if

    end function advc


  end subroutine yaml_dict_dump


  !> Dump all the documents in the dictionary
  !! Works with a list of documents
  !! Suppose that each element of the list is a separate document
  subroutine yaml_dict_dump_all(dict,unit,flow,verbatim)
    implicit none
    type(dictionary), pointer, intent(in) :: dict   !< Dictionary to dump
    logical, intent(in), optional :: flow           !< if .true. inline
    logical, intent(in), optional :: verbatim       !< if .true. print as comments the calls performed
    integer, intent(in), optional :: unit           !< unit in which the dump has to be 
    !local variables
    logical :: flowrite,verb
    integer :: unt,idoc

    if (f_err_raise(dict_len(dict) == 0,'The dictionary is not a list',&
         err_name='YAML_STREAM_NOT_FOUND')) return

    flowrite=.false.
    if (present(flow)) flowrite=flow
    unt=0
    if (present(unit)) unt=unit
    verb=.false.
    if (present(verbatim)) verb=verbatim

    do idoc=0,dict_len(dict)-1
       if (verb) then
          call yaml_comment('call yaml_new_document('//&
              ',unit='//trim(adjustl(yaml_toa(unt)))//')')
       else
          call yaml_new_document(unit=unt)
       end if
       call yaml_dict_dump(dict//idoc,unit=unt,flow=flow,verbatim=verb)
       call yaml_release_document(unit=unt)
    end do

  end subroutine yaml_dict_dump_all

end module yaml_output
