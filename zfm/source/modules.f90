
module zonedata
  use precision
  implicit none
  save

  integer, parameter :: maxspecies=1, mass=-1, enthalpy=0, oxygen=1
  integer, parameter :: nitrogen=2, fuel=3, co=4, co2=5, soot=6	

  type zone_data
    real(kind=dd) :: temperature, density, volume, mass, o2index
    real(kind=dd), dimension(1:maxspecies) :: s_mass, s_con
  end type zone_data

  type flow_data
    real(kind=dd) :: mdot, qdot, temperature, density, rel_height, abs_height
    real(kind=dd), dimension(1:maxspecies) :: sdot
  	logical :: fromlower, fromupper, zeroflowflag
  end type flow_data

  type fire_data
    integer :: room_number, type
    real(kind=dd) :: heat_c, temp, x0,y0,z0,dz, time_rate, time_start
    real(kind=dd) :: mtotal, qtotal, qconvec, qrad, chi_rad
    real(kind=dd), pointer, dimension(:) :: times, q_pyrol
	  integer :: npoints
    type(flow_data) :: fire_flow, entrain_flow, plume_flow                    
  end type fire_data

  type wall_data
    integer :: dir,from,to,wallmatindex
    character(len=30) :: wallmat
    real(kind=dd) :: temp, area, qdot
  end type wall_data

  type room_data
    type(zone_data) :: layer(2)
    real(kind=dd) :: x0, y0, z0, &
                     dx, dy, dz, &
                     abs_pressure, rel_pressure, &
                     rel_layer_height, abs_layer_height, &
                     VU, VL, volume, volmax, volmin,    &
                     upper_area, lower_area, floor_area
    type(wall_data) :: wall(4)
  end type room_data
  type slab_data
    real(kind=dd) :: dp, height, bot, top, area
  	integer :: from, to
    type(flow_data) :: slab_flow, entrain_flow
  end type slab_data

  type hvac_data
    real(kind=dd) :: vfan, mfan, qfan, tfan, rhofan, dpfan, height
    real(kind=dd) :: rel_frombot, rel_tobot, rel_fromtop, rel_totop
    real(kind=dd) :: abs_frombot, abs_tobot, abs_fromtop, abs_totop
    real(kind=dd) :: fromupperfrac, fromlowerfrac
    real(kind=dd) :: toupperfrac, tolowerfrac
	  logical :: specifiedtemp
  	integer :: fromroom, toroom
  	type(slab_data) :: fromslab(2), toslab(2), totalslab
  end type hvac_data

  type vent_data
    integer :: nslabs, from, to, nneutrals,face
    real(kind=dd) :: relbot, reltop, width, offset
    real(kind=dd) :: absbot, abstop
    type(slab_data), dimension(6) :: slab
    real(kind=dd), dimension(7) :: abs_yelev, dpelev, dpslab
    real(kind=dd), dimension(3) :: yneutral
  end type vent_data

  integer, parameter :: lower=1, upper=2
  integer, parameter :: p_coldwall=-2, p_thinwall=-1, p_thickwall=0, p_nowall=-3
  integer, parameter :: p_ceiling=1, p_floor=2, p_wall=3
  logical :: printresid, debugprint
  type(room_data), allocatable, target, dimension(:) :: rooms
  type(vent_data), allocatable, target, dimension(:) :: vents
  type(fire_data), allocatable, target, dimension(:) :: fires
  type(hvac_data), allocatable, target, dimension(:) :: hvacs
  type(flow_data), allocatable, target, dimension(:,:) :: cflow, fflow, hflow, hvflow, totalflow

  type(flow_data) :: zeroflow

  real(kind=dd), parameter :: cp = 1004._dd, g=9.8_dd, cvent=0.7_dd
  real(kind=dd), parameter :: gamma=1.4_dd, cv=cp/gamma, rgas=cp-cv
  real(kind=dd), parameter :: pabs_ref=101325._dd
  real(kind=dd) :: tamb, pamb
  real(kind=dd), parameter :: twothirds=2.0_dd/3.0_dd, zero=0.0_dd
  real(kind=dd), parameter :: onethird=1.0_dd/3.0_dd
  real(kind=dd) :: rhoamb

  integer :: offset_p, offset_vu, offset_tl, offset_tu, offset_oxyl, offset_oxyu
  integer, parameter :: constant=1, tsquared=2, general=3
  real(kind=dd) :: tnow, tstart, tfinal, tprint, tdump, tplot, tout
  real(kind=dd) :: tstartprint, tstartplot, tstartdump
  integer :: iprint, iplot, idump
  real(kind=dd) :: dprint=1.0_dd, ddump=10.0_dd, dplot=10.0_dd
  real(kind=dd) :: heat_c, heat_o2, chi_rad, amb_oxy_con, o2limit
  integer :: nvents, nrooms, nspecies, nfires, noldfires, nhvacs, neq, lrw, liw
  real(kind=dd), dimension(:), allocatable :: rwork
  integer, dimension(:), allocatable :: iwork

  real(kind=dd), allocatable, dimension(:) :: vatol, vrtol, & 
         pprime, p, pdzero, delta, xpsolve, dummysoln, zerosoln
  real(kind=dd) :: aptol, rptol, atol, rtol
  character(len=128) :: smvfile, plotfile, csvfile
  integer, parameter :: smvunit=21, plotunit=22, csvunit=23

  !  overload +, -, * and = so that these operators will work with flows!

  interface operator(+)
    module procedure addflow
  end interface
  interface operator(-)
    module procedure subtractflow
  end interface
  interface operator(*)
    module procedure realtimesflow
    module procedure flowtimesreal
  end interface
  interface assignment(=)
    module procedure assignflow
  end interface


  contains

! --------------- addflow ----------------------

type(flow_data) function addflow(flow1,flow2)
    type(flow_data), intent(in) :: flow1, flow2
    real(kind=dd) :: total_mdot, total_qdot

  addflow%zeroflowflag = .false.
	if(flow1%zeroflowflag)then
	  addflow = flow2
	  return
	endif
	if(flow2%zeroflowflag)then
	  addflow = flow1
	  return
	endif

  total_mdot = flow1%mdot + flow2%mdot
  total_qdot = flow1%qdot + flow2%qdot
  addflow%mdot = total_mdot
  addflow%qdot = total_qdot
  addflow%sdot(1:nspecies) = flow1%sdot(1:nspecies) + flow2%sdot(1:nspecies)
	if(total_mdot.ne.zero)then
    addflow%temperature = total_qdot/(cp*total_mdot)
	 else
    addflow%temperature = zero
    addflow%zeroflowflag = .true.
	endif
	if(addflow%temperature.ne.zero)then
	  addflow%density = pabs_ref/(addflow%temperature*rgas)
	 else
	  addflow%density = zero
	endif
end function addflow


! --------------- subtractflow ----------------------

type(flow_data) function subtractflow(flow1,flow2)
    type(flow_data), intent(in) :: flow1, flow2
    real(kind=dd) :: total_mdot, total_qdot, x

  subtractflow%zeroflowflag = .false.
	if(flow1%zeroflowflag)then
	  x = -1._dd
	  subtractflow = x*flow2
	  return
	endif
	if(flow2%zeroflowflag)then
	  subtractflow = flow1
	  return
	endif

  total_mdot = flow1%mdot - flow2%mdot
  total_qdot = flow1%qdot - flow2%qdot
  subtractflow%mdot = total_mdot
  subtractflow%qdot = total_qdot
  subtractflow%sdot(1:nspecies) = flow1%sdot(1:nspecies) - flow2%sdot(1:nspecies)
	if(total_mdot.ne.zero)then
    subtractflow%temperature = total_qdot/(cp*total_mdot)
	 else
    subtractflow%zeroflowflag = .true.
    subtractflow%temperature = zero
	endif
	if(subtractflow%temperature.ne.zero)then
	  subtractflow%density = pabs_ref/(subtractflow%temperature*rgas)
	 else
	  subtractflow%density = zero
	endif
end function subtractflow

! --------------- realtimesflow ----------------------

type(flow_data) function realtimesflow(scale,flow1)
  type(flow_data), intent(in) :: flow1
	real(kind=dd), intent(in) :: scale

  if(scale.eq.0.0_dd)then
    realtimesflow%zeroflowflag = .true.
   else
    realtimesflow%zeroflowflag = flow1%zeroflowflag
  endif
  if(realtimesflow%zeroflowflag)return
  realtimesflow%mdot = scale*flow1%mdot
  realtimesflow%qdot = scale*flow1%qdot
  realtimesflow%sdot(1:nspecies) = scale*flow1%sdot(1:nspecies)
  realtimesflow%temperature = flow1%temperature
  realtimesflow%density = flow1%temperature

end function realtimesflow

! --------------- flowtimesreal ----------------------

type(flow_data) function flowtimesreal(flow1,scale)
  type(flow_data), intent(in) :: flow1
	real(kind=dd), intent(in) :: scale

  if(scale.eq.0.0_dd)then
    flowtimesreal%zeroflowflag = .true.
   else
    flowtimesreal%zeroflowflag = flow1%zeroflowflag
  endif
  if(flowtimesreal%zeroflowflag)return
  flowtimesreal%mdot = scale*flow1%mdot
  flowtimesreal%qdot = scale*flow1%qdot
  flowtimesreal%sdot(1:nspecies) = scale*flow1%sdot(1:nspecies)
  flowtimesreal%temperature = flow1%temperature
  flowtimesreal%density = flow1%temperature
end function flowtimesreal

! --------------- assignflow ----------------------

subroutine assignflow(flowout,flowin)
  type(flow_data), intent(out) :: flowout
  type(flow_data), intent(in) :: flowin

	if(flowin%zeroflowflag)then
	  flowout%zeroflowflag = .true.
	  return
	endif

  flowout%mdot = flowin%mdot
  flowout%qdot = flowin%qdot
  flowout%temperature = flowin%temperature
  flowout%density = flowin%density
  flowout%sdot(1:nspecies) = flowin%sdot(1:nspecies)
  flowout%zeroflowflag = flowin%zeroflowflag
end subroutine assignflow

end module zonedata

