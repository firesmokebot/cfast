
! --------------------------- types -------------------------------------------

module types
    use precision_parameters
    use cparams
!  room data structure

    type room_type
      real(eb) :: yflor, yceil
      real(eb) :: wall_center(10,3)
      real(eb) :: br, dr, hr
      real(eb) :: ar, vr, hrp, hrl, hflr
      real(eb) :: zzrelp, zzpabs
      real(eb) :: zzvol(2), zzhlay(2), zztemp(2), zzrho(2), zzmass(2)
      real(eb) :: zzgspec(2,ns), zzcspec(2,ns)
    end type room_type

! fire data structure

     type fire_type
     end type fire_type

! vent data structure

    type vent_type
        real(eb) :: sill, soffit, width
        real(eb) :: from_hall_offset, to_hall_offset
        real(eb) :: wind_dp
        integer :: from, to, counter
        integer :: is_from_hall, is_to_hall
        integer :: face
    end type vent_type
     
    
end module types

! --------------------------- cenviro -------------------------------------------

module cenviro
    
    use precision_parameters
    use types
    use cparams
    implicit none
    save
    
    integer :: jaccol, neqoff

    integer, parameter :: constvar = 1 ,odevara = 2 ,odevarb = 4, odevarc = 8
    integer, parameter :: eqp = 1, eqpmv = 2, eqtmv = 3, eqtu = 4, eqvu = 5, eqtl = 6, eqoxyl = 7, eqoxyu = 8, eqtt = 9, eqwt = 10

    ! index into izhall
    integer, parameter :: ihroom = 1, ihvelflag = 2, ihdepthflag = 3, ihventnum = 4, ihhalfflag = 5, ihmode = 6, ihxy = 7

    ! index into zzhall
    integer, parameter :: ihtime0 = 1, ihvel = 2, ihdepth = 3, ihmaxlen = 4, ihhalf = 5, ihtemp = 6, ihorg = 7, ihdist = 8

    ! index for hall models
    integer, parameter :: ihbefore = 1, ihduring = 2, ihafter = 3
    
    logical updatehall, izdtflag, izcon(nr), izhvac(nr)
    
    real(eb), dimension(nr) :: zzvmin, zzvmax
    real(eb), dimension(nr,2) :: zzftemp
    real(eb), dimension(nr,nwal) :: zzwspec
    real(eb), dimension(nr,nwal,2) :: zzwtemp
    real(eb), dimension(mxhvsys,ns) :: zzhvpr
    real(eb), dimension(mxhvsys) :: zzhvm
    real(eb), dimension(nr,4) :: zzwarea
    real(eb), dimension(nr,10) :: zzwarea2
    real(eb), dimension(nr,8) :: zzhall
    real(eb), dimension(mxpts,nr) :: zzrvol, zzrarea, zzrhgt
    real(eb), dimension(2,nr) :: zzabsb, zzbeam
    real(eb), dimension(0:nv+1) :: zzdisc
    real(eb), dimension(nr,nr) :: zzhtfrac
    real(eb) :: zzdtcrit
 
    integer, dimension(ns+2) :: izpmap
    integer, dimension(2,nr) :: izwmap
    integer, dimension(4,nr) :: izwmap2
    integer, dimension(nr,4) :: izswal
    integer, dimension(4*nr,5) :: izwall
    integer, dimension(mxtarg) :: iztarg
    integer, dimension(maxeq,2) :: izeqmap
    integer, dimension(nr) :: izrvol, iznwall(nr), izshaft(nr)
    integer, dimension(nr,7) :: izhall
    integer, dimension(0:nr) :: izheat
    integer, dimension(nr,0:nr) :: izhtfrac
    integer :: izdtnum,izdtmax, izndisc, nswal
    
    type(room_type), target :: roominfo(nr)

end module cenviro

! --------------------------- cfast_main -------------------------------------------

module cfast_main
    use precision_parameters
    use types
    use cparams
    use dsize
    implicit none
    save
    
    integer :: hvorien(mext), hvnode(2,mext), crdate(3), mpsdat(3), nwv(nr,nr), na(mbr), nofsets(17), &
        ncnode(mnode), ne(mbr), mvintnode(mnode,mcon), icmv(mnode,mcon), nfc(mfan), nw(nr,nr), nslb(nwal,nr), &
        nf(mbr), hcldep, smkagl, vshape(nr,nr), objrm(0:mxoin), objign(mxoin), numnode(mxslb+1,4,nr), &
        froom(0:mxfire), numobjl, ixtarg(trgirow,mxtarg), ixdtect(mxdtect,dticol), iquench(nr), idtpnt(nr,2), &
        ndtect, idset, ntarg, ifroom(mxfire), ifrpnt(nr,2), ibrd(mdt), nfire, ipntfsm, ijk(nr,nr,mxccv), &
        nventijk,nfopt,vface(mxvents),itermxx, fplume(0:mxfire), lcopyss,heatfr, nfilter, dmpoutput(4096),&
        deadroom(nr)
    
    integer :: nofp, nofpmv, noftmv, noftu, notvu, noftl, nofoxyl, nofoxyu, noftt, notwt, nofprd, nofhcl, nofsmkw, nofsmk, &
        nofhvpr, nequals, noffsm, nlspct, ivers, lfmax, lfbo, lfbt, nopmx, nrflow, lprint, nsmax, ldiagp, ldiago, itmmax, idiag, &
        nofvu, nofwt, nm1, n, n2, n3, n4, itmstp, nconfg, ndumpr, nrestr, ndt, next, nnode, nft, nfan, nbr
    
    equivalence (nofp,nofsets(1)), (nofpmv,nofsets(2)), (noftmv,nofsets(3)), (noftu,nofsets(4)), (nofvu,nofsets(5)), &
        (noftl,nofsets(6)), (nofoxyl,nofsets(7)), (nofoxyu,nofsets(8)),(noftt,nofsets(9)), (nofwt,nofsets(10)), (nofprd,nofsets(11)), &
        (nofhcl,nofsets(12)), (nofsmkw,nofsets(13)), (nofsmk,nofsets(14)), (nofhvpr,nofsets(15)), (nequals,nofsets(16)), (noffsm,nofsets(17))

    real(eb) :: mass(2,nr,ns), mprodr(nv,ns), mfiret(ns), minmas, limo2, qf(nr), p(maxteq), objmaspy(0:mxfire),tradio, &
        ss1(mxvents), sa1(mxvents), ss2(mxvents), sa2(mxvents), as1(mxvents), aa1(mxvents), as2(mxvents), aa2(mxvents), &
        sau1(mxvents), asl1(mxvents), sau2(mxvents), asl2(mxvents), qr(2,nr), qc(2,nr), heatup(nr), heatlp(nr), heatvf(nr), &
        emp(nr), ems(nr), eme(nr), aps(nr), vvarea(nr,nr), hwj(nwal,nr), hocbmb(nv), hveflo(2,mext), hveflot(2,mext), &
        bfired(nv), afired(nv), hfired(nv), tfired(nv), hhp(mxvents), bw(mxvents), hh(mxvents), hl(mxvents), windc(mxvents), &
        halldist(mxvents,2),qcvh(4,mxvents),qcvv(4,mxvv),qcvm(4,mfan), oplume(3,mxoin),  &
        vmflo(nr,nr,2), xdtect(mxdtect,dtxcol), qspray(0:mxfire,2), radio(0:mxfire), &
        xfire(mxfire,mxfirp), rdqout(4,nr),objxyz(4,mxoin), objstrt(2,mxoin),radconsplit(0:mxfire),heatfp(3),qcvf(4,mfan)

    real(eb) :: ppmdv(2,nr,ns), tamb(nr), ramb(nr), pamb(nr), eta(nr), era(nr), fkw(mxslb,nwal,nr), cw(mxslb,nwal,nr), &
        rw(mxslb,nwal,nr), epa(nr), flw(mxslb,nwal,nr), epw(nwal,nr), qfired(nv), twj(nn,nr,nwal), twe(nwal,nr), fopos(3,0:mxfire), &
        ontarget(nr),cco2(nv),toxict(nr,2,ns),femr(0:mxfire), hcratio(nv), coco2(nv), hlp(mxvents), hvextt(mext,2), &
        arext(mext), hvelxt(mext), ocrati(nv), objma1(mxoin), ce(mbr), hvdvol(mbr), tbr(mbr), rohb(mbr), bflo(mbr), &
        hvp(mnode), hvght(mnode), hmfnet(2,nr,nr), dpz(mnode,mcon), hvflow(mnode,mcon), hclbf(7,nwal,nr), &
        qmax(mfan), hmin(mfan), hmax(mfan), hvbco(mfan,mfcoe), dfmin(mfan), dfmax(mfan), qmin(mfan), de(mdt), da(mdt), &
        dl(mdt), rr(mdt), ductar(mdt), hvconc(mbr,ns),qcvpp(4,nr,nr), hvexcn(mext,ns,2),objpos(3,0:mxoin),fpos(3),hcnf(nv),hcrf(nv), &
        hclf(nv),femp(0:mxfire),fems(0:mxfire),fqf(0:mxfire), fqfc(0:mxfire), fqlow(0:mxfire), fqupr(0:mxfire),fqdj(nr), &
        farea(0:mxfire),xxtarg(trgxrow,mxtarg),cxabs(nr),cyabs(nr)

    real(eb) :: cp, deltat, heatfq, tracet(2,mext)
    real(eb) :: gamma, gmwf, hcomba, hvdelt, traces(2,mext)
    real(eb) :: hvgrav, hvrgas, pa, pofset, pref, qradrl
    real(eb) :: ra, relhum, rgas, sal, sal2, stime, ta, te
    real(eb) :: termxx, tfiret, tfmaxt, tgignt
    real(eb) :: tref, windpw, windrf, windv

    logical :: activs(ns), switch(nwal,nr), mvcalc, objon(0:mxoin), cjeton(nwal+1), heatfl

    character(128) :: title, compartmentnames(nr)
    
!            xfire(nfire,1) = objpos(1,iobj)
!            xfire(nfire,2) = objpos(2,iobj)
!            xfire(nfire,3) = objpos(3,iobj) + ohight
!            xfire(nfire,4) = oplume(3,iobj)
!            xfire(nfire,5) = oplume(1,iobj)
!            xfire(nfire,6) = oplume(2,iobj)
!            xfire(nfire,7) = qfc(1,iroom)
!            xfire(nfire,8) = xqfr
!            xfire(nfire,9) = heatlp(iroom) + heatup(iroom)
!            xfire(nfire,10) = heatlp(iroom)
!            xfire(nfire,11) = heatup(iroom)
!            xfire(nfire,12) = objhct
!            xfire(nfire,13) = y_soot
!            xfire(nfire,14) = y_co
!            !xfire(nfire,15) = hcratt
!            !xfire(nfire,16) = ocratt
!            !xfire(nfire,17) = clfrat
!            !xfire(nfire,18) = cnfrat
!            xfire(nfire,19) = objclen(iobj)
!            xfire(nfire,20) = oareat

     type(fire_type), target, dimension(mxfire)  :: fireinfo

end module cfast_main

! --------------------------- cfin -------------------------------------------

module cfin
    
    implicit none
    
    integer, parameter :: lbufln=1024
    character(lbufln) :: lbuf, cbuf
    
end module cfin

! --------------------------- cfio -------------------------------------------

module cfio

    use cfin    
    implicit none
    
    ! input/output data for readas, readin, ...
      integer :: start, first, last, count, type, ix
      logical :: valid
      character(lbufln) :: inbuf
      real :: xi

end module cfio

! --------------------------- cshell -------------------------------------------

module cshell

    implicit none
    save

    ! rundat is today's date, crdate is the creation date of the module, and is kept in the main cfast data module.  
    ! rundat is copied to mpsdat as soon as the model kernel is started. done in initfs and cfast body.
    ! trace determines the type of output (print file) for mechanical ventilation - current or total
    logical :: header=.false., nokbd=.false., initializeonly=.false., debugging=.false., trace=.false., validate=.false., netheatflux=.false.
    integer :: version, iofili=1, iofilo=6, outputformat=0, logerr=3
    integer, dimension(3) :: rundat
    character(128) :: thrmfile="thermal", setpfile
    character(60) :: nnfile=" ", dumpf=" ", datafile
    character(32) :: mpsdatc
    
end module cshell

! --------------------------- dervs -------------------------------------------

module dervs

    use precision_parameters
    use cparams    
    implicit none
    save

    logical :: produp
    real(eb), dimension(maxteq) :: pdold, pold
    real(eb) :: told, dt

end module dervs

! --------------------------- fltarget -------------------------------------------

module fltarget
    use precision_parameters
    use cparams
    implicit none
    save
    
    ! variables for calculation of flux to a target
      
    ! indices into floating point target data structure (XXTARG)      
    integer, parameter :: trgcenx = 1
    integer, parameter :: trgceny = 2
    integer, parameter :: trgcenz = 3
    integer, parameter :: trgnormx = 4
    integer, parameter :: trgnormy = 5
    integer, parameter :: trgnormz = 6
    integer, parameter :: trgk = 7
    integer, parameter :: trgrho = 8
    integer, parameter :: trgcp = 9
    integer, parameter :: trgl = 10
    integer, parameter :: trginterior = 11
    integer, parameter :: trgemis = 12
    integer, parameter :: trgtfluxf = 13
    integer, parameter :: trgtfluxb = 14
    integer, parameter :: trgnfluxf = 15
    integer, parameter :: trgnfluxb = 16

    ! indices into integer target data structure (IXTARG)
    integer, parameter :: trgroom = 1
    integer, parameter :: trglayer = 2
    integer, parameter :: trgwall = 3
    integer, parameter :: trgmeth = 4
    integer, parameter :: trgeq = 5
    integer, parameter :: trgback = 6
    
    integer, parameter :: ode = 1
    integer, parameter :: pde = 2
    integer, parameter :: cylpde = 3
    integer, parameter :: steady = 1
    integer, parameter :: mplicit = 2
    integer, parameter :: xplicit = 3
    integer, parameter :: int = 1
    integer, parameter :: ext =2

    character(8) :: cxtarg(mxtarg)

    real(eb), dimension(mxtarg,2) :: qtflux, qtcflux, qtfflux, qtwflux, qtgflux
    real(eb), dimension(mxtarg) :: tgtarg
    real(eb), dimension(mxtarg,5)  :: gtflux
    integer, dimension(3) :: neqtarg
end module fltarget

! --------------------------- iofiles -------------------------------------------

module  iofiles

    use precision_parameters
    implicit none
    save
    
!File descriptors for cfast

    character(6), parameter :: heading="VERSN"
    character(64) :: project
    character(256) :: datapath, exepath, inputfile, outputfile, smvhead, smvdata, smvcsv, &
        ssflow, ssnormal, ssspecies, sswall, errorlogging, stopfile, solverini, &
        historyfile, queryfile, statusfile, kernelisrunning

! Work arrays for the csv input routines

    integer, parameter :: nrow=200, ncol=200
    real(eb) :: rarray(nrow,ncol) 
    character(128) :: carray(nrow,ncol)

end module iofiles

! --------------------------- debug -------------------------------------------

module  debug

    use precision_parameters
    implicit none

    logical :: residprn, jacprn
    logical :: residfirst = .true.
    logical :: jacfirst = .true.
    logical :: prnslab
    integer :: ioresid, iojac, ioslab
    real(eb) ::   dbtime
    character(256) :: residfile, jacfile, residcsv, jaccsv, slabcsv

end module debug

! --------------------------- objects1 -------------------------------------------

module objects1

    use cparams
    implicit none
    save

    logical, dimension(0:mxoin) :: objld
    character(64), dimension(0:mxoin) :: odbnam
    character(256), dimension(0:mxoin) :: objnin
    integer, dimension(0:mxoin) :: objpnt

end module objects1

! --------------------------- objects2 -------------------------------------------

module objects2

    use precision_parameters
    use cparams
    implicit none
    save

    logical, dimension(0:mxoin) :: objdef
    character(60), dimension(mxoin) :: objnam(mxoin)
    character(60), dimension(0:mxoin) :: omatl
    integer, dimension(mxoin) :: objlfm,objtyp,obtarg, objset
    
    real(eb), dimension(mxoin) :: obj_c, obj_h, obj_o, obj_n, obj_cl
    real(eb), dimension(3,0:mxoin) :: objcri, objort
    real(eb), dimension(0:mxoin) :: objmas, objgmw, objvt, objclen
    real(eb), dimension(nv,0:mxoin) :: objhc, omass, oarea, ohigh, oqdot ,oco, ohcr, ood, ooc
    real(eb), dimension(nv,ns,mxoin) :: omprodr
    real(eb), dimension(nv,mxoin) :: otime
    real(eb), dimension(2,0:mxoin) :: obcond
    real(eb) :: objmint, objphi, objhgas, objqarea, pnlds, dypdt, dxpdt, dybdt, dxbdt, dqdt

end module objects2

! --------------------------- opt -------------------------------------------

module opt

    use precision_parameters
    use cparams
    implicit none
    save
    
    integer, parameter :: mxdebug = 19
    integer, parameter :: mxopt = 21

    integer, parameter :: off = 0
    integer, parameter :: on = 1

    integer, parameter :: fccfm = 1
    integer, parameter :: fcfast = 2

    integer, parameter :: ffire = 1
    integer, parameter :: fhflow = 2
    integer, parameter :: fentrain = 3
    integer, parameter :: fvflow = 4
    integer, parameter :: fcjet = 5
    integer, parameter :: fdfire = 6
    integer, parameter :: fconvec = 7
    integer, parameter :: frad = 8
    integer, parameter :: fconduc = 9
    integer, parameter :: fdebug = 10
    integer, parameter :: fode=11
    integer, parameter :: fhcl=12
    integer, parameter :: fmvent=13
    integer, parameter :: fkeyeval=14
    integer, parameter :: fpsteady=15
    integer, parameter :: fhvloss=16
    integer, parameter :: fmodjac=17
    integer, parameter :: fpdassl=18
    integer, parameter :: foxygen=19
    integer, parameter :: fbtdtect=20
    integer, parameter :: fbtobj=21
 
    integer, parameter :: d_jac = 17
    integer, parameter :: d_cnt = 1
    integer, parameter :: d_prn = 2
    integer, parameter :: d_mass = 1
    integer, parameter :: d_hvac = 2
    integer, parameter :: d_hflw = 3
    integer, parameter :: d_vflw = 4
    integer, parameter :: d_mvnt = 5
    integer, parameter :: d_dpdt = 18
    integer, parameter :: d_diag = 19

    integer, parameter :: verysm = -9
    integer, parameter :: verybg = 9

    integer, dimension(mxopt) :: option = &
        ! fire, hflow, entrain, vflow, cjet, door-fire, convec, rad, conduct, debug, exact ode,  hcl , mflow, keyboard, type of initialization,  mv heat loss, mod jac, dassl debug, oxygen dassl solve, back track on dtect, back track on objects
        (/ 2,   1,      1,       1,     2,    1,         1,      4,   1,       0,     1,          1,    1,     1,        1,                       0,            1,       0,           0,                  0,                   0/)
!*** in above change default rad option from 2 to 4
!*** this causes absorption coefs to take on constant default values rather than computed from data
    integer, dimension(mxopt) :: debug = 0
    
    real(eb) :: cutjac, stptime, prttime, tottime, ovtime, tovtime
    
    integer :: iprtalg = 0, jacchk = 0
    integer :: numjac = 0, numstep = 0, numresd = 0, numitr = 0, totjac = 0, totstep = 0, totresd = 0, totitr = 0
 
    integer(2), dimension(mxdebug,2,nr) :: dbugsw
    

      end module opt

! --------------------------- params -------------------------------------------

module params

    use precision_parameters
    use cparams
    implicit none
    save

!   these are temporary work arrays

!   ex... are the settings for the external ambient
!   qfr,... are the heat balance calculations for resid and cnduct. it is now indexed by fire rather than by compartment
!   the variables ht.. and hf.. are for vertical flow
!   the volume fractions volfru and volfrl are calculated by resid at the beginning of a time step
!   hvfrac is the fraction that a mv duct is in the upper or lower layer

    logical :: allowed(ns), exset
    integer :: mapltw(nwal), ihmlar(2,nr,nr), izhvmapi(mnode), izhvmape(mnode), izhvie(mnode), izhvsys(mnode), izhvbsys(mbr), nhvpvar, nhvtvar, nhvsys

    real(eb) :: qfr(mxfire), qfc(2,nr), qscnv(nwal,nr), qdout(nwal,nr), qsradw(nwal,nr), qdin(nwal,nr), qcvent(mxvents,nv), o2n2(ns), hwjdot(nwal,nr), exsal, &
        htot(nr), htflow(nr,2), hmflow(nr,2), htfnet(2,nr,nr), volfru(nr), volfrl(nr), hvfrac(2,mext), expa, exta, exra, &
        hcratt, chv(mbr), dhvprsys(mnode,ns), hvtm(mxhvsys), hvmfsys(mxhvsys),hvdara(mbr), hvt, ductcv

    !common exsal, qfr, qfc, qscnv, qdout, qsradw, hmflow, mapltw, qdin, expa, exta, exra, qcvent, o2n2, hwjdot, &
    !    htot, htflow, htfnet, volfru, volfrl, hvfrac, hcratt, ihmlar, hvmfsys,dhvprsys,hvtm,hvdara,hvt,chv,ductcv, &
    !    exset, allowed, izhvmapi,izhvmape,izhvie,nhvpvar,nhvtvar, izhvsys,izhvbsys,nhvsys

end module params

! --------------------------- smkview -------------------------------------------

module smkview

    use precision_parameters
    use cparams
    implicit none
    save

    integer :: smkunit, spltunit, flocal(mxfire+1)
    character(60) :: smkgeom, smkplot, smkplottrunc
    logical :: remapfiresdone
    real(eb), dimension(mxfire+1) :: fqlocal, fzlocal, fxlocal, fylocal, fhlocal
  
end module smkview

! --------------------------- solver_parameters -------------------------------------------

module solver_parameters

    use precision_parameters
    use cparams
    implicit none
    save
    
    real(eb), dimension(nt) :: pinit
    real(eb), dimension(1) :: rpar2
    integer, dimension(3) :: ipar2
    real(eb) :: aptol = 1.0e-6_eb        ! absolute pressure tolerance
    real(eb) :: rptol = 1.0e-6_eb        ! relative pressure tolerance
    real(eb) :: atol = 1.0e-5_eb         ! absolute other tolerance
    real(eb) :: rtol = 1.0e-5_eb         ! relative other tolerance
    real(eb) :: awtol = 1.0e-2_eb        ! absolute wall tolerance
    real(eb) :: rwtol = 1.0e-2_eb        ! relative wall tolerance
    real(eb) :: algtol = 1.0e-8_eb       ! initialization tolerance
    real(eb) :: ahvptol = 1.0e-6_eb      ! absolute HVAC pressure tolerance
    real(eb) :: rhvptol = 1.0e-6_eb      ! relative HVAC pressure tolerance
    real(eb) :: ahvttol = 1.0e-5_eb      ! absolute HVAC temperature tolerance
    real(eb) :: rhvttol = 1.0e-5_eb      ! relative HVAC temperature tolerance
    
    real(eb) :: stpmax = 1.0_eb        ! maximum solver time step, if negative, then solver will decide
    real(eb) :: dasslfts = 0.005_eb    ! first time step for DASSL

end module solver_parameters

! --------------------------- thermp -------------------------------------------

module thermp

    use precision_parameters
    use cparams
    implicit none
    save
    
    real(eb), dimension(mxslb,nthmax) :: lfkw, lcw, lrw, lflw
    real(eb), dimension(nthmax) :: lepw
    real(eb), dimension(7,nthmax) :: lhclbf

    logical, dimension(nwal,nr) :: thset
    integer maxct, numthrm
    integer, dimension(nthmax) :: lnslb
    character(8), dimension(nwal,nr) :: cname
    character(8), dimension(nthmax) :: nlist

end module thermp

! --------------------------- vents -------------------------------------------

module vents

    use precision_parameters
    use types
    use cparams, only: nr, mxvent
    implicit none
    save
    
    integer, dimension(mxvent,2) :: ivvent
    integer :: nvents, nvvent
    
    real(eb), dimension(nr,mxvent) :: zzventdist
    real(eb), dimension(2,mxvent) :: vss, vsa, vas, vaa, vsas, vasa
    
    type (vent_type), dimension(mxvent), target :: ventinfo
    
end module vents

! --------------------------- vent_slab -------------------------------------------

module vent_slab
    
    use precision_parameters
    implicit none
    save
    
    real(eb), dimension(10) :: yvelev, dpv1m2
    integer, dimension(10) ::  dirs12
    integer :: nvelev, ioutf
      
end module vent_slab

! --------------------------- wdervs -------------------------------------------

module wdervs

    implicit none
    save
    
    integer :: jacn1, jacn2, jacn3, jacdim
      
end module wdervs

! --------------------------- wnodes -------------------------------------------

module wnodes

    use precision_parameters
    use cparams
    implicit none
    save
    
    integer :: nwpts = 30                                   ! number of wall nodes
    integer :: iwbound = 3                                  !boundary condition type (1=constant temperature, 2=insulated 3=flux)
    real(eb), dimension(3) :: wsplit = (/0.50, 0.17, 0.33/)   ! computed values for boundary thickness, initially fractions for inner, middle and outer wall slab
    
    integer nwalls, nfurn
    real(eb), dimension (nr,4) :: wlength
    real(eb), dimension (nn,nr,4) :: walldx
    real(eb), dimension(nv) :: furn_time, furn_temp
    real(eb) :: qfurnout
      
end module wnodes