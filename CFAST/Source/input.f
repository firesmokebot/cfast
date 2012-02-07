      SUBROUTINE readinputfile (IERROR)

!	Read the input file and set up the data for processing

      use iofiles
      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "params.fi"
      include "cshell.fi"
      include "cfin.fi"
      include "objects1.fi"
      include "thermp.fi"

!	Pretty pedestrian to use these names, but...
	integer numr, numc
      LOGICAL EXISTS
      CHARACTER*133 MESSG
      CHARACTER AVERSION*5
      DIMENSION YINTER(NR)
      EQUIVALENCE (YINTER,QFR)
      DIMENSION TEMPAREA(MXPTS), TEMPHGT(MXPTS)

!	Unit numbers defined in readop, openoutputfiles, readinputfiles
!
!      1 is for the solver.ini and data files (data file, tpp and objects) (IOFILI)
!      3 is for the log file  (LOGERR)
!      6 is output (IOFILO)
!     11 is the history file
!     12 is used to write the status file (project.status)
!     13 smokeview output (header) - note this is rewound each time the plot data is written)
!     14 smokeview output (plot data)
!     15 spreadsheet output (normal)
!     16 spreadsheet output (flow field)
!     17 spreadsheet output (species)
!     18 spreadsheet output (walls and targets)
!
!     switch (1) = CEILING PROPERTIES ARE DEFINED
!            (2) = FLOOR PROPERTIES ARE DEFINED
!            (3) = SIDE WALL PROPERTIES ARE DEFINED FOR UPPER WALLS
!            (4) = SIDE WALL PROPERTIES ARE DEFINED FOR LOWER WALLS

      IFAIL = 0
      XX0 = 0.0D0
	xx1 = 1.0d0

!	Deal with opening the data file and assuring ourselves that it is compatible

      CLOSE (IOFILI)
      OPEN (UNIT=IOFILI,FILE=inputfile,ERR=130,STATUS='OLD',iostat=ios)
	call readcsvformat(iofili,rarray,carray,nrow,ncol,1,numr,numc,
     . ierror)
	if (ierror.gt.0) then
		 write(logerr,5003)
		 return
	endif

	close (iofili)

!	aversion is the header name, ivers is the major version number read in, iversion is the major version number
!	from the internal version data. These need to be compatible

	aversion = carray(1,1)
	ivers = rarray(1,2)
!new version numbering 600->6000, so current version is 6100
	if (version.ge.1000) then
            iversion = version / 1000
      else
      	iversion = version / 100
      endif
	if (aversion.eq.heading.and.ivers.eq.iversion) then
		 write (logerr,5001) ivers
	else
		 write (logerr,5002) aversion,heading,ivers,iversion
		 ierror = 206
		 return
      END IF
	title = carray(1,3)

!     READ IN ALL SPECIFICATIONS

      DO 10 I = 1, NR
        YINTER(I) = -1.0D0
   10 CONTINUE
      
	call keywordcases (numr, numc, ierror)

!	wait until the input file is parsed before dieing on temperature
	if (exta.gt.373.15.or.exta.lt.223.15d0) then
		write(logerr,5022) exta
		ierror = 218
	endif
	if (ta.gt.373.15.or.ta.lt.223.15d0) then
		write(logerr,5022) ta
		ierror = 218
	endif

      IF (IERROR.NE.0) RETURN

!	We now know what output is going to be generated, so create the files

	call openoutputfiles

C     WE COME HERE FOR ANY CALL TO the keywordcases statement

      RA = PA / TA / RGAS
      EXRA = EXPA / EXTA / RGAS

!	Get the mainfire and set the species

	if (objnin(0).ne.' ') then
		call inputmainfire (iofili,ierror)
		if (debugging) call printfireparameters
		if (ierror.ne.0) return
	endif
	
      IF(LFBT.LT.0.OR.LFBT.GT.2) THEN
	   write(logerr,5101) lfbt
		IERROR = 201
         RETURN
      END IF

C     TURN ON THE SUBSIDIARY EQUATIONS IF THEY ARE NEEEDED - this is always true

         IF (ACTIVS(6)) HCLDEP = 1

C **** NOTE THAT SMOKE AGGLOMERATION IS NOT DONE, SO THE FOLLOWING
C **** FACTOR IS NEVER SET - THIS WILL PROVIDE FOR A SET OF SUBSIDARY
C **** EQUATION TO TRACK SMOKE NUMBER DENSITY AS WELL AS MASS DENSITY
C        IF (ACTIVS(9)) SMKAGL = 1

         NM1 = N - 1
         IF (NUMOBJL.GT.0) THEN
			do 19 i = 1, numobjl
			   CALL inputobject (objnin(i), i, iofili, ierror)
			   if (debugging) call printobjectparameters(i)
			   IF (IERROR.NE.0) RETURN
   19			continue
         END IF

!	Initialize the targets
         CALL INITTARG (IERROR)
          IF (IERROR.NE.0) RETURN
!     NOW CALCULATE THE OFFSETS - the order is important
         CALL OFFSET (IERROR)
		 IF (IERROR.NE.0) RETURN

C     FLOOR PLAN DEPENDENT PARAMETERS

         NM1 = N - 1
         DO 20 I = 1, NM1
            HRL(I) = HFLR(I)
            HRP(I) = HR(I) + HFLR(I)
   20    CONTINUE

C     CHECK AND/OR SET FPOS

         IF (LFBO.GT.0) THEN
            IF ((FPOS(1).LT.XX0).OR.(FPOS(1).GT.BR(LFBO))) THEN
               FPOS(1) = BR(LFBO) / 2.0D0
               IF (LOGERR.GT.0) WRITE (LOGERR,5000) FPOS(1)
            END IF
            IF ((FPOS(2).LT.XX0).OR.(FPOS(2).GT.DR(LFBO))) THEN
               FPOS(2) = DR(LFBO) / 2.0D0
               IF (LOGERR.GT.0) WRITE (LOGERR,5010) FPOS(2)
            END IF
            IF ((FPOS(3).LT.XX0).OR.(FPOS(3).GT.HR(LFBO))) THEN
               FPOS(3) = 0.0D0
               IF (LOGERR.GT.0) WRITE (LOGERR,5020) FPOS(3)
            END IF
         ENDIF

C     CHECK AND/OR SET heatf position

         IF (heatfl) THEN
            IF ((heatfp(1).LT.XX0).OR.(heatfp(1).GT.BR(heatfr))) THEN
               heatfp(1) = BR(heatfr) / 2.0D0
            END IF
            IF ((heatfp(2).LT.XX0).OR.(heatfp(2).GT.DR(heatfr))) THEN
               heatfp(2) = DR(heatfr) / 2.0D0
            END IF
            IF ((heatfp(3).LT.XX0).OR.(heatfp(3).GT.HR(heatfr))) THEN
               heatfp(3) = 0.0D0
            END IF
		   write(logerr,5021) heatfr,heatfp
         ENDIF

C     CHECK AND/OR SET POSITION OF OBJECTS

         DO 1300 I = 1, NUMOBJL
            IF((OBJPOS(1,I).LT.XX0).OR.
     .                 (OBJPOS(1,I).GT.BR(OBJRM(I)))) THEN
               OBJPOS(1,I) = BR(OBJRM(I)) / 2.0D0
               IF (LOGERR.GT.0) WRITE (LOGERR,5080) I, OBJPOS(1,I)
            END IF
            IF((OBJPOS(2,I).LT.XX0).OR.
     .                 (OBJPOS(2,I).GT.DR(OBJRM(I)))) THEN
               OBJPOS(2,I) = DR(OBJRM(I)) / 2.0D0
               IF (LOGERR.GT.0) WRITE (LOGERR,5090) I, OBJPOS(2,I)
            END IF
            IF((OBJPOS(3,I).LT.XX0).OR.
     .                 (OBJPOS(3,I).GT.HR(OBJRM(I)))) THEN
               OBJPOS(3,I) = XX0
               IF (LOGERR.GT.0) WRITE (LOGERR,5100) I, OBJPOS(3,I)
            END IF
 1300    CONTINUE
C    MAKE SURE HORIZONTAL VENT SPECIFICATIONS ARE CORRECT -  WE HAVE TO DO THIS
C    HERE RATHER THAN RIGHT AFTER NPUTQ BECAUSE HRL AND HRP WERE JUST DEFINED
C    ABOVE

         DO 40 ITOP = 1, NM1
           IF (NWV(ITOP,ITOP).NE.0) THEN
            IF (LOGERR.GT.0) WRITE (LOGERR,*) 
     +        ' A ROOM CAN NOT BE CONNECTED TO ITSELF'
            NWV(ITOP,ITOP) = 0
           END IF
           DO 30 IBOT = 1, ITOP - 1
             IF (NWV(ITOP,IBOT).NE.0.OR.NWV(IBOT,ITOP).NE.0) THEN

C    SEE WHICH ROOM IS ON TOP (IF ANY) - THIS IS LIKE A BUBBLE SORT

              DEPS1 = HRL(ITOP) - HRP(IBOT)
              DEPS2 = HRL(IBOT) - HRP(ITOP)
              IF (NWV(ITOP,IBOT).NE.1.OR.ABS(DEPS1).GE.VFMAXDZ) THEN
               IF (NWV(IBOT,ITOP).NE.1.OR.ABS(DEPS2).GE.VFMAXDZ) THEN
                IF (NWV(ITOP,IBOT).EQ.1.AND.ABS(DEPS2).LT.VFMAXDZ) THEN
                  IF (NWV(IBOT,ITOP).NE.0) THEN
                     WRITE (LOGERR,*) 'Vent ', IBOT, ITOP, 
     +                       ' is being redefined'
                  END IF
                  NWV(ITOP,IBOT) = 0
                  NWV(IBOT,ITOP) = 1
                  VVAREA(IBOT,ITOP) = VVAREA(ITOP,IBOT)
                  VSHAPE(IBOT,ITOP) = VSHAPE(ITOP,IBOT)
                  GO TO 30
                END IF
                IF (NWV(IBOT,ITOP).EQ.1.AND.ABS(DEPS1).LT.VFMAXDZ) THEN
                  IF (NWV(ITOP,IBOT).NE.0) THEN
                      WRITE (LOGERR,*) 'Vent ', ITOP, IBOT, 
     +                    ' is being redefined'
                  END IF
                  NWV(ITOP,IBOT) = 1
                  NWV(IBOT,ITOP) = 0
                  VVAREA(ITOP,IBOT) = VVAREA(IBOT,ITOP)
                  VSHAPE(ITOP,IBOT) = VSHAPE(IBOT,ITOP)
                  GO TO 30
                END IF
                NWV(ITOP,IBOT) = 0
                NWV(IBOT,ITOP) = 0
               END IF
              END IF
             END IF
   30      CONTINUE
   40    CONTINUE

         DO 50 I = 1, NM1
            AR(I) = BR(I) * DR(I)
            VR(I) = AR(I) * HR(I)
   50    CONTINUE


C*** CHECK ROOM TO ROOM HEAT TRANSFER PARAMETERS (CFCON COMMAND)
         NSWALL2 = NSWAL
         II = 0
         DO 200 I = 1, NSWAL
            IROOM1 = IZSWAL(I,1)
            IROOM2 = IZSWAL(I,3)

C*** ROOM NUMBERS MUST BE BETWEEN 1 AND NM1

            IF(IROOM1.LT.1.OR.IROOM2.LT.1.OR.
     .          IROOM1.GT.NM1+1.OR.IROOM2.GT.NM1+1)THEN
              IFAIL = 39
              WRITE (MESSG,201)IROOM1,IROOM2 
  201         FORMAT(' INVALID CFCON SPECIFICATION:',
     +         ' ONE OR BOTH OF ROOMS ',2I3, ' IS OUT OF BOUNDS')
              CALL XERROR(MESSG,0,1,1)
            ENDIF

C*** If room is connected to the outside then ignore it
C
            IF(IROOM1.EQ.NM1+1.OR.IROOM2.EQ.NM1+1)THEN
              NSWALL2 = NSWALL2 - 1
              GO TO 200
             ELSE
              II = II + 1
              IF(I.NE.II)THEN
                IZSWAL(II,1) = IZSWAL(I,1)
                IZSWAL(II,2) = IZSWAL(I,2)
                IZSWAL(II,3) = IZSWAL(I,3)
                IZSWAL(II,4) = IZSWAL(I,4)
              ENDIF
            ENDIF

C*** FLOOR OF ONE ROOM MUST BE ADJACENT TO CEILING OF THE OTHER

            DWALL1 = ABS(HRL(IROOM1) - HRP(IROOM2))
            DWALL2 = ABS(HRL(IROOM2) - HRP(IROOM1))
            IF(DWALL1.LT.VFMAXDZ.OR.DWALL2.LE.VFMAXDZ)THEN
               IF(DWALL1.LT.VFMAXDZ)THEN
                 IZSWAL(II,2) = 2
                 IZSWAL(II,4) = 1
                ELSE
                 IZSWAL(II,2) = 1
                 IZSWAL(II,4) = 2
               ENDIF
              ELSE
               IFAIL = 40
               WRITE (MESSG,202)IROOM1,IROOM2 
  202          FORMAT(' INVALID CFCON SPECIFICATION:'
     +                ' CEILING AND FLOOR OF ROOMS',
     +                2I3, ' ARE NOT CONNECTETD')
            ENDIF

C*** WALLS MUST BE TURNED ON, IE SWITCH MUST BE SET
C    FOR THE CEILING IN THE LOWER ROOM AND THE FLOOR OF
C    THE UPPER ROOM

            IWALL1 = IZSWAL(II,2)
            IWALL2 = IZSWAL(II,4)
            IF(.NOT.SWITCH(iwall1,IROOM1).OR.
     .         .NOT.SWITCH(iwall2,IROOM2))THEN
               WRITE (MESSG,203)
  203          FORMAT(' INVALID CFCON SPECIFICATION:')
               CALL XERROR(MESSG,0,1,1)
               IF(.NOT.SWITCH(iwall1,IROOM1))THEN
                  WRITE(MESSG,204)iwall1,IROOM1
  204             FORMAT(' WALL ',I2,' OF ROOM ',I2,' IS NOT TURNED ON')
                  CALL XERROR(MESSG,0,1,1)
               ENDIF
               IF(.NOT.SWITCH(iwall2,IROOM2))THEN
                  WRITE(MESSG,204)iwall2,IROOM2
                  CALL XERROR(MESSG,0,1,1)
               ENDIF
               IFAIL = 41
            ENDIF
  200    CONTINUE
         NSWAL = NSWALL2


C*** CHECK SHAFTS

         DO 205 IROOM = NM1 + 1, NR
            IF(IZSHAFT(IROOM).NE.0)THEN
               CALL XERROR(' INVALID SHAFT SPECIFICATION:',0,1,1)
               IFAIL = 42
               WRITE (MESSG,206)IROOM,NM1
  206          FORMAT(' Room ',I3,' must be less than or equal to ',I3)
               CALL XERROR(MESSG,0,1,1)
            ENDIF
  205    CONTINUE

C    INITIALIZE VARIABLES THAT WILL CHANGE WHEN AMBIENT CONDITIONS CHANGE

         CALL INITAMB(YINTER,1)

C     INITIALIZE THE MECHANICAL VENTILATION

         CALL HVINIT (IERROR)
         IF (IERROR.NE.0) RETURN

C*** CHECK DETECTOR STUFF

         DO 65 I = 1, NDTECT
            IROOM = IXDTECT(I,DROOM)
            IF(IROOM.LT.1.OR.IROOM.GT.NM1)THEN
              WRITE (MESSG,104)IROOM 
  104         FORMAT('Invalid DETECTOR specification: Room ',
     +              I3, ' is not a valid')
              IFAIL = 43
              CALL XERROR(MESSG,0,1,1)
            ENDIF
            RTI = XDTECT(I,DRTI)
            IF(RTI.LE.0.0D0.AND.IXDTECT(I,DTYPE).NE.SMOKED)THEN
              WRITE (MESSG,101)RTI 
  101         FORMAT('Invalid DETECTOR specification - RTI= ',
     +              E11.4, ' is not a valid.')
              IFAIL = 44
            ENDIF
            XLOC = XDTECT(I,DXLOC)
            YLOC = XDTECT(I,DYLOC)
            ZLOC = XDTECT(I,DZLOC)
            IF(XLOC.LT.0.0D0.OR.XLOC.GT.bR(IROOM).OR.
     .         YLOC.LT.0.0D0.OR.YLOC.GT.dR(IROOM).OR.
     .         ZLOC.LT.0.0D0.OR.ZLOC.GT.HRP(IROOM))THEN
               WRITE(MESSG,102)XLOC,YLOC,ZLOC
  102          FORMAT('Invalid DETECTOR specification - x,y,z,location',
     +               'x,y,z=',3E11.4,' is out of bounds')
               IFAIL = 45
            ENDIF
            IDTYPE = IXDTECT(I,DTYPE)
            IF(IDTYPE.LT.1.OR.IDTYPE.GT.3)THEN
              WRITE(MESSG,103)IDTYPE
  103         FORMAT('Invalid DETECTOR specification - TYPE= ',
     +              I2,' is not a valid')
              IFAIL = 46
            ENDIF
   65    CONTINUE

C     FIRE TYPE AND PARAMETERS: COME HERE DIRECTLY IF THIS IS A RESTART

      TFMAXT = 0.0D0
      DO 60 I = 1, LFMAX
        TFMAXT = MAX(TFMAXT,TFIRED(I))
   60 CONTINUE

C*** check room area specs and convert to volume

      DO 300 I = 1, NM1
        NPTS = IZRVOL(I)
        IF(NPTS.NE.0)THEN

c*** force first elevation to be at the floor; add a data point if necessary (same area as first entered data point)

          IF(ZZRHGT(1,I).NE.0.0D0)THEN
            TEMPAREA(1) = ZZRAREA(1,I)
            TEMPHGT(1) = 0.0D0
            IOFF = 1
           ELSE
            IOFF = 0
          ENDIF

c*** copy data to temporary arrays

          DO 310 J = 1, NPTS
            TEMPAREA(J+IOFF) = ZZRAREA(J,I)
            TEMPHGT(J+IOFF) = ZZRHGT(J,I)
  310     CONTINUE

c*** force last elevation to be at the ceiling (as defined by hr(i)

          IF(HR(I).NE.ZZRHGT(NPTS,I))THEN
              IOFF2 = 1
              TEMPAREA(NPTS+IOFF+IOFF2) = ZZRAREA(NPTS,I)
              TEMPHGT(NPTS+IOFF+IOFF2) = HR(I)
             ELSE
              IOFF2 = 0
          ENDIF

          NPTS = NPTS + IOFF + IOFF2
          IZRVOL(I) = NPTS

c*** copy temporary arrays to zzrhgt and zzrarea; define volume by integrating areas

          ZZRHGT(1,I) = 0.0D0
          ZZRVOL(1,I) = 0.0D0
          ZZRAREA(1,I) = TEMPAREA(1)
          J = 1
          DO 320 J = 2, NPTS
            ZZRHGT(J,I) = TEMPHGT(J)
            ZZRAREA(J,I) = TEMPAREA(J)
            DAREA = (ZZRAREA(J,I)+ZZRAREA(J-1,I))/2.0D0
            DHEIGHT = ZZRHGT(J,I) - ZZRHGT(J-1,I)
            ZZRVOL(J,I) = ZZRVOL(J-1,I) + DAREA*DHEIGHT
  320     CONTINUE

C*** re-define volume, area, breadth and depth arrays 
C        (vr, ar, br and dr ) according to room area - height
C        data read in.  HR remains the same, VR is defined
C        by integrating areas specified on the ROOMAREA command,
C        AR is then VR/HR, BR and DR are defined so that
C        BR*DR=AR and BR/DR remain the same as entered on
C        the WIDTH and DEPTH  commands.

          VR(I) = ZZRVOL(NPTS,I)
          AR(I) = VR(I)/HR(I)
          XX = bR(I)/dR(I)
          BR(I) = SQRT(AR(I)*XX)
          DR(I) = SQRT(AR(I)/XX)
        ENDIF
  300 CONTINUE


C*** room to room heat transfer 

C  The array IZHEAT may have one of three values, 0, 1, 2.  
C  0 = no room to room heat transfer
C  1 = fractions are determined by what rooms are connected by vents
C      For example, if room 1 is connected to rooms 2, 3, 4 and the outside
C      by vents then the first row of ZZHTFRAC will have the values
C      0. .25 .25 .25 .25

c***  force all rooms to transfer heat between connected rooms

      IF(IZHEAT(0).EQ.1)THEN
        DO 400 I = 1, NM1
          IZHEAT(I) = 1
  400   CONTINUE
      ENDIF
      DO 410 I = 1, NM1

c*** force heat transfer between rooms connected by vents.

        IF(IZHEAT(I).EQ.1)THEN
          DO 420 J = 1, NM1+1
            NVENTIJ = 0
            DO 430 K = 1, 4
              NVENTIJ = NVENTIJ + IJK(I,J,K)
  430       CONTINUE
            IF(NVENTIJ.NE.0)ZZHTFRAC(I,J) = 1.0D0

C*** if the back wall is not active then don't consider its contribution

				IF(J.LE.NM1.AND..NOT.SWITCH(3,J))ZZHTFRAC(I,J) = 0.0D0
  420     CONTINUE
        ENDIF

c*** normalize ZZHTFRAC fraction matrix so that rows sum to one

        IF(IZHEAT(I).NE.0)THEN
          SUM = 0.0D0
          DO 440 J = 1, NM1+1
            SUM = SUM + ZZHTFRAC(I,J)
  440     CONTINUE
          IF(SUM.LT.1.D-5)THEN
            DO 450 J = 1, NM1
              ZZHTFRAC(I,J) = 0.0D0
  450       CONTINUE
            ZZHTFRAC(I,NM1+1) = 1.0D0
           ELSE
            DO 460 J = 1, NM1+1
              ZZHTFRAC(I,J) = ZZHTFRAC(I,J)/SUM
  460       CONTINUE
          ENDIF
          JJ = 0
          DO 480 J = 1, NM1
            IF(ZZHTFRAC(I,J).NE.0.0D0)THEN
              IZHTFRAC(I,0) = IZHTFRAC(I,0) + 1
              JJ = JJ + 1
              IZHTFRAC(I,JJ) = J
            ENDIF
  480     CONTINUE
        ENDIF
  410 CONTINUE


C     GET GRAPHICS DISPLAY INFORMATION - NOT WITH THE PREDEFINED DATA

      IF(IFAIL.GT.0) THEN
        CALL XERROR('Input error in readinputfile',0,1,1)
        IERROR = IFAIL
        RETURN
      END IF
      CLOSE (IOFILI)
      RETURN

C     ERROR

  130 IF (LOGERR.GT.0) WRITE (LOGERR,5050) MOD(IOS,256)
	ierror = 99
      RETURN

 5000 FORMAT ('Setting X cood. of fire position to default ',F12.5)
 5001 format ('Opening a version ',i2,' file in normal mode')
 5002 format ('Not a compatible version ',2a8,2x,2i10)
 5003 format ('Too many lines in the main data file')
 5010 FORMAT ('Setting Y cood. of fire position to default ',F12.5)
 5020 FORMAT ('Setting Z cood. of fire position to default ',F12.5)
 5021 FORMAT ('The constant heat source (heatf) is in compartment ',i3,
     .        ' at ',3f12.5)
 5022 format (
     . 'Initial temperature outside of allowable range (-50 to +100)',
     . f5.2)

C     READ FORMAT LIST

 5030 FORMAT (A5,2X,I3,128A1)
 5050 FORMAT (' Error opening the input file = ',I6)

C     OUTPUT FOR OBJECTS

 5080 FORMAT (' Object no. ',I3,' X cood. set to ',F12.5)
 5090 FORMAT (' Object no. ',I3,' Y cood. set to ',F12.5)
 5100 FORMAT (' Object no. ',I3,' Z cood. set to ',F12.5)
 5101 FORMAT ('Not an allowed fire type ',i3)

      END

      SUBROUTINE keywordcases(xnumr,xnumc,IERROR)
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     NPUTQ
C
C     Source File: NPUTQ.SOR
C
C     Functional Class:  INPUT
C
C     Description:  Handles CFAST datafile keywords
C
C     Arguments: ISRSTR
C                IERROR  Returns error codes
C
C     Revision History:
C	Modified: 10/20/04 : assume default values for hvac expansion coefficient and areas
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C
      use iofiles
      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "cfin.fi"
      include "cshell.fi"
      include "thermp.fi"
      include "params.fi"
      include "objects1.fi"
      include "objects2.fi"
      include "solvprm.fi"
      include "fltarget.fi"
      include "opt.fi"
      include "vents.fi"
      include "wnodes.fi"
     
      PARAMETER (MAXIN = 37)
      LOGICAL LFUPDAT, eof, countargs
      INTEGER OBPNT,compartment,lrowcount,xnumr,xnumc,nx, i1, i2,
     + fannumber, iecfrom, iecto, mid
      DOUBLE PRECISION NTER(NR), initialopening, lrarray(ncol),
     + inter(nr), minpres, maxpres, heightfrom, heightto, areafrom, 
     + areato
      CHARACTER ORIENTYP*1, MESSG*133, lcarray*128(ncol), cjtype*1,
     + LABEL*5, TCNAME*64, METHOD*8, EQTYPE*3, venttype,
     + orientypefrom*1, orientypeto*1, compfrom*128, compto*128
      character*10 plumemodel(2)/'McCaffrey','Heskestad'/

      EQUIVALENCE (INTER,QFR)

!	Start with a clean slate
      xx0 = 0.0d0
      xx1 = 1.0d0
      xxm1= -1.0d0
      lfupdat=.false.
      iflgsetp = 0
      setpfile = ' '
      do i = 1, nr
          do j = 1, 4
              cname(j,i) = 'OFF'
              switch(j,i) = .false.
          end do
          compartment = 0
          ierror = 0
          lrowcount = 1
      end do

   10 CONTINUE

   40 lrowcount = lrowcount + 1
!	If we reach the end of the file, then we are done
	if (lrowcount.gt.xnumr) return

!	Copy a single row into local arrays for processing in readin; start with column two, assuming that the key word is the first entry!

      label = carray(lrowcount,1)
      if (label.eq.' ') go to 40
      do i = 2, xnumc
          lcarray(i-1) = carray(lrowcount,i)
          lrarray(i-1) = rarray(lrowcount,i)
      end do

!	Start the case statement for key words

      select case (label)
          
          ! TIMES total_simulation, print interval, history interval, smokeview interval, spreadsheet interval
          case ("TIMES")
              if (.not.countargs(label,5,lcarray, xnumc-1, nret)) then
		        ierror = 1
		        return
	        endif
              nsmax =  lrarray(1)
              lprint = lrarray(2)
              ldiago = lrarray(3)
	        if (ldiago.gt.0) ndumpr = 1
              ldiagp = lrarray(4)
              lcopyss =  lrarray(5)
              
          ! TAMB REFERENCE AMBIENT TEMPERATURE (C), REFERENCE AMBIENT PRESSURE, REFERENCE PRESSURE, relative humidity
          case ("TAMB")
              if (.not.countargs(label,4,lcarray, xnumc-1, nret)) then
		        ierror = 2
		        return
	        endif
	        ta = lrarray(1)
              pa = lrarray(2)
              sal = lrarray(3)
	        relhum = lrarray(4) * 0.01d0
              if (.not.exset) then
                  exta = ta
                  expa = pa
                  exra = ra
                  exsal = sal
              end if
              
          ! EAMB REFERENCE EXTERNAL AMBIENT TEMPERATURE (C), REFERENCE EXTERNAL AMBIENT PRESSURE, REFERENCE EXTERNAL AMBIENT HEIGHT
          case ("EAMB")
              if (.not.countargs(label,3,lcarray, xnumc-1, nret)) then
		        ierror = 3
                  return
	        endif
              exta = lrarray(1)
              expa = lrarray(2)
              exsal = lrarray(3)
              exset = .true.
              
          ! Limiting oxygen index
          case ("LIMO2")
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 4
		        return
	        endif
	        limo2 = lrarray(1) * 0.01d0 
              
          ! Rename the THERMAL DATA FILE
          case ("THRMF")
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 6
		        return
	        endif
	        thrmfile = lcarray(1)
          case ("MAINF")
              if (.not.countargs(label,5,lcarray, xnumc-1, nret)) then
		        ierror = 7
		        return
	        endif
	        objnin(0) = 'mainfire'
	        lfbo =      lrarray(1)
	        if(lfbo.lt.0.or.lfbo.gt.n-1) then
                  ierror = 64
		        return
	        endif
	        lfbt =      2
	        fpos(1) =   lrarray(2)
	        fpos(2) =   lrarray(3)
	        fpos(3) =   lrarray(4)
	        fplume(0) = lrarray(5)
	        if(fplume(0).lt.1.or.fplume(0).gt.2) then
	            write(logerr,5402) fplume(0)
	            ierror = 78
	            return 
	        end if
	        write(logerr,5403) plumemodel(fplume(0))
              
          ! Set the gaseous ignition temperature - this is a global parameter DJIGN
          case ('DJIGN')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        return
		        ierror = 4
	        endif
	        tgignt = lrarray(2)
              
          ! Set global chemistry parameters, CHEMIE.  With 2 parameters it's redundant with DJIGN and LIMO2. With more, it's part of a fire definition
          case ('CHEMI')
              if (countargs(label,2,lcarray,xnumc-1, nret)) then
                  limo2 = lrarray(1) * 0.01d0
	            tgignt = lrarray(2)
              else if (countargs(label,8,lcarray,xnumc-1,nret)) then
                  ! fire object CHEMI input here
              else
                  ierror = 4
                  return
              end if
          
          ! COMPA	name(c), width(f), depth(f), height(f), absolute position (f) (3), ceiling_material(c), floor_material(c), wall_material (c) 
          case ('COMPA')
              if (.not.countargs(label,10,lcarray,xnumc-1,nret)) then
		        ierror = 8
		        return
	        endif
	
	        compartment = compartment + 1
	        if (compartment.gt.nr) then
		        write (logerr, 5062) compartment
		        ierror = 9
		        return
	        endif

              ! Name
	        compartmentnames(compartment) = lcarray(1)
	
              ! Size
	        br(compartment) = lrarray(2)
	        dr(compartment) = lrarray(3)
	        hr(compartment) = lrarray(4)
	        cxabs(compartment) = lrarray(5)
	        cyabs(compartment) = lrarray(6)
	        hflr(compartment) = lrarray(7)
	
              ! Ceiling
              tcname = lcarray(8)
              if (tcname.ne.'OFF') then
		        switch(1,compartment) = .true.
		        cname(1,compartment) = tcname
                  ! keep track of the total number of thermal properties used
		        numthrm = numthrm + 1
              end if

              ! floor
              tcname = lcarray(9)
              if (tcname.ne.'OFF') then
		        switch(2,compartment) = .true.
		        cname(2,compartment) = tcname   
                  ! keep track of the total number of thermal properties used
		        numthrm = numthrm + 1
              end if

              ! walls
              tcname = lcarray(10)
              if (tcname.ne.'OFF') then
		        switch(3,compartment) = .true.
		        cname(3,compartment) = tcname
		        switch(4,compartment) = .true.
                  cname(4,compartment) = tcname
                  ! keep track of the total number of thermal properties used
		        numthrm = numthrm + 1
              END IF

              ! Reset this each time in case this is the last entry
	        n = compartment+1
	        nx = compartment

	        write (logerr,5063) compartment, compartmentnames(nx), br(nx),
     +        dr(nx), hr(nx),cxabs(nx),cyabs(nx),hflr(nx),
     +        (switch(i,nx),i=1,4),(cname(i,nx),i=1,4)
              
          ! HVENT 1st, 2nd, which_vent, width, soffit, sill, wind_coef, hall_1, hall_2, face, opening_fraction
!		    BW = width, HH = soffit, HL = sill, 
!		    HHP = ABSOLUTE HEIGHT OF THE soffit,HLP = ABSOLUTE HEIGHT OF THE sill, HFLR = ABSOLUTE HEIGHT OF THE FLOOR (not set here)
!		    WINDC = a wind coefficient which varies from -1 to +1 and is dimensionless
!		    Compartment offset for the HALL command (2 of these)
!		    VFACE = THE RELATIVE FACE OF THE VENT: 1-4 FOR X PLANE (-), Y PLANE (+), X PLANE (+), Y PLANE (-)
!		    Initial open fraction
          case ('HVENT')
              if (.not.countargs(label,11,lcarray,xnumc-1,nret)) then
		        ierror = 10
		        return
	        endif

              i = lrarray(1)
              j = lrarray(2)
              k = lrarray(3)
              imin = min(i,j)
              jmax = max(i,j)
              if (imin.gt.nr-1.or.jmax.gt.nr.or.imin.eq.jmax) then
                  write (logerr,5070) i, j
	            ierror = 78
                  return
              end if
              if (k.gt.mxccv) then
                  write (logerr,5080) i, j, k, nw(i,j)
	            ierror = 78
	            return
	        end if
              nventijk = nventijk + 1
	        if (nventijk.gt.mxvents) then
	            write(logerr,5081) i,j,k
	             ierror = 78
	            return
	        endif
	        ijk(i,j,k) = nventijk
              ijk(j,i,k) = ijk(i,j,k)
              iijk = ijk(i,j,k)
              jik = iijk
              koffst = 2 ** k
              if (iand(koffst,nw(i,j)).ne.0) write (iofilo,5090) i, j, k
              nw(i,j) = ior(nw(i,j),koffst)
              bw(iijk) = lrarray(4)
              hh(iijk) = lrarray(5)
              hl(iijk) = lrarray(6)
              windc(iijk) = lrarray(7)
              halldist(iijk,1) = lrarray(8)
              halldist(iijk,2) = lrarray(9)
	        vface(iijk) = lrarray(10)
	        initialopening = lrarray(11)
	
	        qcvh(2,iijk) = initialopening
	        qcvh(4,iijk) = initialopening

              hhp(iijk) = hh(iijk) + hflr(i)
              hlp(iijk) = hl(iijk) + hflr(i)

              ! connections are bidirectional

              nw(j,i) = nw(i,j)
              hh(jik) = min(hr(j),max(xx0,hhp(jik)-hflr(j)))
              hl(jik) = min(hh(jik),max(xx0,hlp(jik)-hflr(j)))

              ! assure ourselves that the connections are symmetrical

              hhp(jik) = hh(jik) + hflr(j)
              hlp(jik) = hl(jik) + hflr(j)
              hh(iijk) = min(hr(i),max(xx0,hhp(iijk)-hflr(i)))
              hl(iijk) = min(hh(iijk),max(xx0,hlp(iijk)-hflr(i)))
  
          ! EVENT - H First_Compartment     Second_Compartment	 Vent_Number Time Final_Fraction decay_time
          ! EVENT - V First_Compartment     Second_Compartment	 Not_Used	 Time Final_Fraction decay_time
          ! EVENT - M Not_Used				  Not_used				 M_ID        Time Final_Fraction decay_time
          ! EVENT - F Not_Used				  Not_used				 M_ID        Time Final_Fraction decay_time    
          case ('EVENT')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 11
		        return
	        endif

!	        Sort by event type, h, v, m, or f
	        venttype = lcarray(1)
		
	        select case (venttype)
	            case ('H')
		            if (.not.countargs(label,7,lcarray, xnumc-1, nret)) then
			            ierror = 11
			            return
		            endif
		            i = lrarray(2)
		            j = lrarray(3)
                      k = lrarray(4)
		            iijk = ijk(i,j,k)
		            qcvh(1,iijk) = lrarray(5)
		            qcvh(3,iijk) = lrarray(5) + lrarray(7)
		            qcvh(4,iijk) = lrarray(6)		 
	            case ('V')
		            if (.not.countargs(label,7,lcarray, xnumc-1, nret)) then
			            ierror = 11
			            return
		            endif
                      ! Sort these out in datacopy; we duplicate here so that readinputfile does not have to sort these as well
		            itop = lrarray(2)
                      ibot = lrarray(3)
		            qcvpp(1,itop,ibot) = lrarray(5)
		            qcvpp(3,itop,ibot) = lrarray(5) + lrarray(7)
		            qcvpp(4,itop,ibot) = lrarray(6)
                      qcvpp(1,ibot,itop) = lrarray(5)
		            qcvpp(3,ibot,itop) = lrarray(5) + lrarray(7)
		            qcvpp(4,ibot,itop) = lrarray(6)
	            case ('M')
		            if (.not.countargs(label,7,lcarray, xnumc-1, nret)) then
			            ierror = 11
			            return
		            endif
		            fannumber = lrarray(4)
		            qcvm(1,fannumber) = lrarray(5)
		            qcvm(3,fannumber) = lrarray(5) + lrarray(7)
		            qcvm(4,fannumber) = lrarray(6)
	            case ('F')
		            if (.not.countargs(label,7,lcarray, xnumc-1, nret)) then
			            ierror = 11
			            return
		            endif
		            fannumber = lrarray(4)
		            if (fannumber.gt.nfan) then
			            ierror = 82
			            write(logerr,5196) fannumber
			            return
		            endif
		            nfilter = nfilter + 1
		            qcvf(1,fannumber) = lrarray(5)
		            qcvf(3,fannumber) = lrarray(5) + lrarray(7)
		            qcvf(4,fannumber) = lrarray(6)
	            case default
		            ierror = 71
		            return
              end select 
              
          ! VVENT - from_compartment to_compartment area shape initial_fraction
          case ('VVENT')
              if (.not.countargs(label,5,lcarray, xnumc-1, nret)) then
		        ierror = 23
		        return
	        endif
              i = lrarray(1)
              j = lrarray(2)
              ! check for outside of compartment space; self pointers are covered in readinputfile
              if (i.gt.nr.or.j.gt.nr) then
                  write (logerr,5070) i, j
	            ierror = 79
	            return
              end if

              ! readinputfile will verify the orientation (i is on top of j)
              nwv(i,j) = 1
              vvarea(i,j) = lrarray(3)
              ! check the shape parameter. the default (1) is a circle)
	        if (lrarray(4).lt.1.or.lrarray(4).gt.2) then
		        vshape(i,j) = 1
	        else
	            vshape(i,j) = lrarray(4)
	        endif
	        qcvpp(2,i,j) = lrarray(5)
	        qcvpp(2,j,i) = lrarray(5)
	        qcvpp(4,i,j) = lrarray(5)
	        qcvpp(4,j,i) = lrarray(5)

          ! WIND - VELOCITY AT REFERENCE HEIGHT and EXPONENTIAL LAPSE RATE
          case ('WIND')
              if (.not.countargs(label,3,lcarray, xnumc-1, nret)) then
		        ierror = 24
		        return
	        endif
              windv = lrarray(1)
              windrf = lrarray(2)
              windpw = lrarray(3)
              
          ! INTER - Set the initial interface height only if it different than the default
          !         this key word takes arguements in pairs - compartment, height
          case ('INTER')
              if (.not.countargs(label,2,lcarray, xnumc-1, nret)) then
		        ierror = 25
		        return
	        endif
              if ((nret/2)*2.ne.nret) then   ! There have to be pairs of numbers
		        write (iofilo,5130) nret
		        ierror = 73
		        return
              end if
              do i = 1, nret - 1, 2
	            j = lrarray(i)
                  if (j.gt.n.or.j.lt.1) then
                      write (iofilo,5140) i, j
		            ierror = 26
		            return
                  else
		            xxlocal = lrarray(i+1)
		            if(xxlocal.lt.xx0.or.xxlocal.gt.hr(j)) then
			            ierror = 72
		                return
		            endif
		            inter(j) = xxlocal
                  end if
              end do
              
          ! MVENT - simplified mechanical ventilation

          ! (1) From_Compartment, (2) To_Compartment, (3) ID_Number
          ! (4-6) From_Opening_Orientation From_Center_Height From_Opening_Area 
          ! (7-9) To_Opening_Orientation To_Center_Height To_Opening_Area 
          ! (10-12) Flow Flow_Begin_Dropoff_Pressure Zero_Flow_Pressure
          ! (13) Initial fraction of the fan speed
          case ('MVENT')
              if (.not.countargs(label,13,lcarray,xnumc-1,nret)) then 
		        ierror = 12
		        return
	        endif
              mid = lrarray(3)
              iecfrom = lrarray(1)
              iecto = lrarray(2)
	        if (iecfrom.gt.n.or.iecto.gt.n) then
		        write(logerr,5191) iecfrom, iecto
		        ierror = 67
		        return
	        endif

              orientypefrom = lcarray(4)
              heightfrom = lrarray(5)
              areafrom = lrarray(6)
              orientypeto = lcarray(7)
              heightto = lrarray(8)
              areato = lrarray(9)
              minpres = lrarray(11)
              maxpres = lrarray(12)
	        fanfraction = lrarray(13)

              ! We start with two new nodes for the openings into the compartments for connections to the fan

              ! first compartment/node opening
              next = next + 1
              nnode = nnode + 1
              if (next.gt.mext.or.nnode.gt.mnode) then
		        write (logerr,5192) next,nnode
		        ierror = 68
		        return
              end if
              if (orientypefrom.eq.'V') then
                  hvorien(next) = 1
                  else
                  hvorien(next) = 2
              end if
              hvnode(1,next) = iecfrom
              hvnode(2,next) = nnode
              hvelxt(next) = heightfrom
              arext(next) = areafrom

          ! second compartment/node opening
              next = next + 1
              nnode = nnode + 1
              if (next.gt.mext.or.nnode.gt.mnode) then
		        write (logerr,5192) next,nnode
		        ierror = 68
		        return
              end if
              if (orientypeto.eq.'V') then
                  hvorien(next) = 1
              else
                  hvorien(next) = 2
              end if
              hvnode(1,next) = iecto
              hvnode(2,next) = nnode
              hvelxt(next) = heightto
              arext(next) = areato

              ! now connect nodes 1 and 2 with a fan

              if (minpres.gt.maxpres) then
                  write (logerr,5194) minpres,maxpres
	            ierror = 70
                  return
              end if

              nfan = nfan + 1
	        if (mid.ne.nfan) then
		        write(logerr,5193) mid,nfan
		        ierror = 68
		        return
	        endif

              nbr = nbr + 1
              if (nfan.gt.mfan.or.nbr.gt.mbr) then
		        write (iofilo,5195) mfan
		        ierror = 70
		         return
              end if
  
              nf(nbr) = nfan
              nfc(nfan) = 1
              na(nbr) = hvnode(2,next-1)
              ne(nbr) = hvnode(2,next)
              hvdvol(nbr) = xx0
              hmin(nfan) = minpres
              hmax(nfan) = maxpres
              hvbco(nfan,1) = lrarray(10)

              ! add a simple duct to connect the two nodes/fan - this is artificial since we do not worry about the species in the system
              ndt = ndt + 1
              
              ! to change from the zero volume calculation to a finite volume, use 1.0d1 (10 meter duct)
              ! the effect is in hvfrex. case 1 is the finite volume and case 2, the zero volume calculation for flow through the external nodes
              dl(ndt) = xx0 ! 1.0d1
              de(ndt) = lrarray(6)
              ibrd(ndt) = nbr

              ! finally, we set the initial fraction opening
	        qcvm(2,mid) = lrarray(13)
	        qcvm(4,mid) = lrarray(13)  
              
          ! OBJECT NAME ROOM POS(3) PLUME IGNITION_TYPE IGNITION_CRITERION NORMAL(3)
          case ('OBJEC')

              if (.not.countargs(label,11,lcarray, xnumc-1, nret)) then
		        ierror = 32
		        return
	        endif
	        if (numobjl.ge.mxoin) then
                  write(logerr,5300)
                  go to 10
              end if
              tcname = lcarray(1)
              iroom = lrarray(2)
              if (iroom.lt.1.or.iroom.gt.n-1) then
		        write(logerr,5320)iroom
                  ierror = 33
		        return
              end if
              obpnt = numobjl + 1
              numobjl = obpnt

              ! Only constrained fires
	        objtyp(numobjl) = 2
	        if (objtyp(numobjl).gt.2) then
		        write(logerr,5321) objtyp(numobjl)
		        ierror = 63
		        return
	        endif

              objpos(1,obpnt) = lrarray(3)
              objpos(2,obpnt) = lrarray(4)
              objpos(3,obpnt) = lrarray(5)
	        if (objpos(1,obpnt).gt.br(iroom).or.
     .            objpos(2,obpnt).gt.dr(iroom).or.
     .            objpos(3,obpnt).gt.hr(iroom)) then
		        write(logerr,5323) obpnt
		        ierror = 82
		        return
	        endif

	        fplume(numobjl) = lrarray(6)
	        if(fplume(numobjl).lt.1.or.fplume(numobjl).gt.2) then
	            write(logerr,5402) fplume(numobjl)
	            ierror = 78
	            return 
	        end if
	        write(logerr,5403) plumemodel(fplume(numobjl))	
              objign(obpnt) =   lrarray(7)
              tmpcond =         lrarray(8)
              objort(1,obpnt) = lrarray(9)
              objort(2,obpnt) = lrarray(10)
              objort(3,obpnt) = lrarray(11)
              ! Enforce sanity; normal pointing vector must be non-zero (blas routine)
	        if (dnrm2(3,objort(1,obpnt),1).le.0.0) then
		        write(logerr,5322)
		        ierror = 216
		        return
	        endif
              objrm(obpnt) = iroom
              objnin(obpnt) = tcname
              objld(obpnt) = .true.
              objon(obpnt) = .false.
              ! This is redudant but needed to be compatible with the object database format
	        objpnt(obpnt) = obpnt

              !!!!! Note that ignition type 1 is time, type 2 is temperature and 3 is flux !!!
              !!!!! The critiria for temperature and flux are stored backupwards - this is historical
              !!!!! See corresponding code in updobj
              if (tmpcond.gt.0.0d0) then
                  if (objign(obpnt).eq.1) then
                      objcri(1,obpnt) = tmpcond
                      objcri(2,obpnt) = 1.0d30
                      objcri(3,obpnt) = 1.0d30
                  else if (objign(obpnt).eq.2) then
                      objcri(1,obpnt) = 1.0d30
                      objcri(2,obpnt) = 1.0d30
                      objcri(3,obpnt) = tmpcond
                  else if (objign(obpnt).eq.3) then
                      objcri(1,obpnt) = 1.0d30
                      objcri(2,obpnt) = tmpcond
                      objcri(3,obpnt) = 1.0d30
                  else
                      write(logerr,5358) objign(obpnt)
		            ierror = 13
		            return
                  end if
	        else
                  objon(obpnt) = .true.
              end if
              if (option(fbtobj).eq.off.and.objign(obpnt).ne.1.) then
                  if (stpmax.gt.0.0d0) then
		            stpmax = min(stpmax,1.d0)
                  else
                      stpmax = 1.d0
                  end if
              end if
          
          ! CJET - Ceiling jet for walls, ceiling, all, or off
          case ('CJET')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 34
		        return
	        endif
              DO  I = 1, 5
                  cjeton(i) = .false.
              end do
              cjtype = lcarray(1)(1:1)
              if (cjtype.ne.' ') then
		        if (cjtype.eq.'C') then
			        cjeton(1) = .true.
			        cjeton(5) = .true.
		        else if (cjtype.eq.'W') then
		            cjeton(1) = .true.
			        cjeton(3) = .true.
			        cjeton(5) = .true.
		        else if (cjtype.eq.'A') then
			        cjeton(1) = .true.
			        cjeton(3) = .true.
			        cjeton(4) = .true.
			        cjeton(5) = .true.
	            endif
	        endif
	        write(logerr,5341) cjeton
              
          ! STPMAX # - set the maximum time step to #
          case ('STPMA')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 35
		        return
	        endif
              stpmax = lrarray(1)
      
          ! DETECT Type Compartment Activation_Temperature Width Depth Height RTI Suppression Spray_Density
          case ('DETEC')
              if (.not.countargs(label,9,lcarray, xnumc-1, nret)) then
		        ierror = 34
		        return
	        endif

              ndtect = ndtect + 1
	        if (ndtect.gt.mxdtect) then
		        write (logerr, 5338)
		        ierror = 81
		        return
	        endif

              i1 = lrarray(1)
	        i2 = lrarray(2)
              ! force to heat detector if out of range
	        if (i1.gt.3) i1 = heatd
	        ixdtect(ndtect,dtype) = i1
	        iroom = i2
	        ixdtect(ndtect,droom) = iroom
	        if(iroom.lt.1.or.iroom.gt.nr)then
	 	        write (logerr,5342) i2
	 	        ierror = 35
	 	        return
	        endif

              xdtect(ndtect,dtrig) = lrarray(3)
              xdtect(ndtect,dxloc) = lrarray(4)
              xdtect(ndtect,dyloc) = lrarray(5)
              xdtect(ndtect,dzloc) = lrarray(6)
              xdtect(ndtect,drti) =  lrarray(7)
              ixdtect(ndtect,dquench) = lrarray(8)
              xdtect(ndtect,dspray) = lrarray(9)*1000.d0
              ! if spray density is zero, then turn off the sprinkler
              if(xdtect(ndtect,dspray).eq.0.0d0)then
                  ixdtect(ndtect,dquench) = 0
              endif
              if(option(fbtdtect).eq.off.
     .            and.ixdtect(ndtect,dquench).gt.0)then
                  if (stpmax.gt.0) then
                      stpmax = min(stpmax,1.d0)
                  else
                      stpmax = 1.d0
                  end if
              end if
	        if (compartmentnames(i2).eq.' ') then
		        write(logerr,5344) i2
		        ierror = 36
		        return
	        else
		        write(logerr, 5343) i1,compartmentnames(i2)
	        endif

	        if (debugging) then
		        write(*,5400) (xdtect(ndtect,i),i=1,dtxcol)
		        write(*,5401) (ixdtect(ndtect,i),i=1,dticol)
		        write(*,*)
	        endif

	        if(xdtect(ndtect,dxloc).gt.br(i2).or.
     .            xdtect(ndtect,dyloc).gt.dr(i2).or.
     .            xdtect(ndtect,dzloc).gt.hr(i2)) then
                  write(logerr,5339) ndtect,compartmentnames(i2)
		        ierror = 80
		        return
              endif
     
          !     VHEAT top_compartment bottom_compartment
          case ('VHEAT')
              if (.not.countargs(label,2,lcarray, xnumc-1, nret)) then
		        ierror = 37
		        return
	        endif

              i1 = lrarray(1)
              i2 = lrarray(2)
	        if (i1.lt.1.or.i2.lt.1.or.i1.gt.n.or.i2.gt.n) then
		        write(logerr,5345) i1, i2
		        ierror = 38
		        return
	        endif

              nswal = nswal + 1
              izswal(nswal,1) = i1
              izswal(nswal,2) = 1
              izswal(nswal,3) = i2
              izswal(nswal,4) = 3
              
          ! ONEZ compartment number - This turns the compartment into a single zone
          case ('ONEZ')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
		        ierror = 39
		        return
	        endif

              iroom = lrarray(1)
              if(iroom.lt.1.or.iroom.gt.n)then
		        write(logerr, 5001) i1
		        ierror = 40
		        return
	        endif
              izshaft(iroom) = 1
          !	TARGET - Compartment position(3) normal(3) Material Method Equation_Type
          case ('TARGE')
              if (countargs(label,10,lcarray, xnumc-1, nret).or.
     .            countargs(label,11,lcarray, xnumc-1, nret)) then
                  if(ntarg+1.gt.mxtarg)then
		            write(logerr,5002) 
		            ierror = 42
		            return
	            else
		            ntarg = ntarg + 1
                  endif
        
                  ! The target can exist, now for the compartment
                  IROOM = lrarray(1)
                  IF(IROOM.LT.1.OR.IROOM.GT.N)THEN
		            write(logerr,5003) iroom
		            ierror = 43
		            return
	            endif

                  ! position and normal
                  ixtarg(trgroom,ntarg)=iroom
                  do i = 0, 2
                      xxtarg(trgcenx+i,ntarg) = lrarray(2+i)
                      xxtarg(trgnormx+i,ntarg) = lrarray(5+i)
                  end do
                  if (countargs(label,11,lcarray, xnumc-1, nret)) then
                      xxtarg(trginterior,ntarg) = lrarray(11)
                  else
                      xxtarg(trginterior,ntarg) = 0.5
                  end if

                  ! material type
	            tcname = lcarray(8)
	            if(tcname.eq.' ') tcname='DEFAULT'
                  cxtarg(ntarg) = tcname
                  ixtarg(trgwall,ntarg) = 0

                  ! solution method
                  method = ' '
                  method = lcarray(9)
                  call upperall(method,method)
                  if(method.ne.' ')then
                      if(method(1:3).eq.'STE') then
                          ixtarg(trgmeth,ntarg) = STEADY
                          method = ' '
                      elseif (method(1:3).eq.'IMP') then
                          ixtarg(trgmeth,ntarg) = MPLICIT
                      elseif (method(1:3).eq.'EXP') then
                          ixtarg(trgmeth,ntarg) = XPLICIT
                      else
                          write(logerr,912) method
                          ierror = 44
                          return
                      endif
                  endif

                  ! equation type
                  eqtype = ' '
                  eqtype = lcarray(10)
                  call upperall(eqtype,eqtype)
                  if(eqtype.ne.' '.and.method.ne.' ')then
                      if (eqtype(1:3).eq.'ODE') then
                          ixtarg(trgeq,ntarg) = ODE
                      elseif (eqtype(1:3).eq.'PDE') then
                          ixtarg(trgeq,ntarg) = PDE
                      elseif (eqtype(1:3).eq.'CYL') then
                          ixtarg(trgeq,ntarg) = CYLPDE
                      else
                          write(logerr,913) eqtype
                          ierror = 45
                          return
                      endif
                  endif
              else
		        ierror = 41
		        return
              endif
          ! HALL Compartment Velocity Depth Decay_Distance
          case ('HALL')
              if (.not.countargs(label,4,lcarray, xnumc-1, nret)) then
                  ierror = 46
                  return
              endif

              IROOM = lrarray(1)

              ! check that specified room is valid
              if(iroom.lt.0.or.iroom.gt.n)then
                  write(logerr,5346) iroom
                  ierror = 63
                  return
              endif

              izhall(iroom,ihroom) = 1
              izhall(iroom,ihvelflag) = 0
              izhall(iroom,ihdepthflag) = 0
              izhall(iroom,ihventnum) = 0
              zzhall(iroom,ihtime0) = -1.0d0
              zzhall(iroom,ihvel) = 0.0d0
              zzhall(iroom,ihdepth) = -1.0d0
              zzhall(iroom,ihhalf) = -1.0d0

              ! CORRIDOR velocity; not set if negative
              if(lrarray(2).ge.0) then
                  zzhall(iroom,ihvel) = lrarray(2)
                  izhall(iroom,ihvelflag) = 1
              endif

              ! CORRIDOR layer depth; not set if negative
              if (lrarray(3).ge.0) then
                  zzhall(iroom,ihdepth) = lrarray(3)
                  izhall(iroom,ihdepthflag) = 1
              endif

              ! CORRIDOR temperature decay distance (temperature decays by 0.50); if negative, not set
              if (lrarray(4).ge.0) then
                  zzhall(iroom,ihhalf) = lrarray(4)
                  izhall(iroom,ihhalfflag) = 1
                  izhall(iroom,ihmode) = ihbefore
              endif
              
          ! ROOMA Compartment Number_of_Area_Values Area_Values
          ! This provides for variable compartment floor areas; this should be accompanied by the roomh command
          case ('ROOMA')
              if (.not.countargs(label,2,lcarray, xnumc-1, nret)) then
                  ierror = 47
                  return
              endif

              IROOM = lrarray(1)

              ! make sure the room number is valid
              if(iroom.lt.1.or.iroom.gt.n)then
                  write(logerr,5347) iroom
                  ierror = 48
                  return
              endif

              ! make sure the number of points is valid
              npts = lrarray(2)
              if(npts.gt.mxpts.or.npts.le.0.or.npts.ne.nret-2) then
                  write (logerr,5347) npts
                  ierror = 49
                  return
              endif
              if(izrvol(iroom).ne.0) npts = min(izrvol(iroom),npts)
              izrvol(iroom) = npts

              ! make sure all data is positive 
              do  i = 1, npts
                  if(lrarray(i+2).lt.0.0d0)then
                      write(logerr,5348) lrarray(i+2)
                      ierror = 50
                      return
                  endif
              end do

              ! put the data in its place
              do i = 1, npts
                  zzrarea(i,iroom) = lrarray(i+2)
              end do
              write(logerr,5351) iroom, (zzrarea(iroom,i),i=1,npts)

          ! ROOMH Compartment Number_of_Height_Values Height_Values
          ! This companion to ROOMA, provides for variable compartment floor areas; this should be accompanied by the ROOMA command
          case ('ROOMH')
              if (.not.countargs(label,2,lcarray, xnumc-1, nret)) then
                  ierror = 51
                  return
              endif

              iroom = lrarray(1)

              ! make sure the room number is valid
              if(iroom.lt.1.or.iroom.gt.n)then
                  write(logerr,5349) iroom
                  ierror = 52
                  return
              endif

              ! make sure the number of points is valid
              npts = lrarray(2)
              if(npts.gt.mxpts.or.npts.lt.0.or.npts.ne.nret-2)then
                  write(logerr,5350) npts
                  ierror = 53
                  return
              endif
              if(izrvol(iroom).ne.0)npts = min(izrvol(iroom),npts)
              izrvol(iroom) = npts

              ! make sure all data is positive 
              do i = 1, npts
                  if(lrarray(i+2).lt.0.0d0)then
                      write(logerr,5348) lrarray(i+2)
                      ierror = 54
                      return
                  endif
              end do

              ! put the data in its place
              do i = 1, npts
                  zzrhgt(i,iroom) = lrarray(i+2)
              end do
              write(logerr,5352) iroom, (zzrhgt(iroom,i),i=1,npts)
              
          ! DTCHE Minimum_Time_Step Maximum_Iteration_Count
          case ('DTCHE')
              if (.not.countargs(label,2,lcarray, xnumc-1, nret)) then
                  ierror = 55
                  return
              endif

              zzdtcrit = abs(lrarray(1))
              izdtmax = abs(lrarray(2))
              ! a negative turns off the check
              if(lrarray(2).le.0)izdtflag = .false.
              
          ! SETP file_name
          case ('SETP')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
                  ierror = 56
                  return
              endif

              if (iflgsetp.gt.0) then
                  ierror = 57
                  write (logerr,5353) setpfile
                  return
              else
                  iflgsetp = 1
                  setpfile = lcarray(1)
                  write (logerr,5340) setpfile
              end if
              
          ! Horizontal heat flow, HHEAT First_Compartment Number_of_Parts N pairs of {Second_Compartment, Fraction}

          ! There are two forms of the command
          !   The first (single entry of the room number) - all connections based on horizontal flow
          !   The second is the compartment number followed by N pairs of compartments to which the heat will flow and the fraction of the vertical surface of the compartment that loses heat
          case ('HHEAT')
              if (.not.countargs(label,1,lcarray, xnumc-1, nret)) then
                  ierror = 58
                  return
              endif

              nto = 0
              ifrom = lrarray(1)

              if (nret.eq.1) then
                  izheat(ifrom) = 1
                  go to 10
              else
                  nto = lrarray(2)
                  if(nto.lt.1.or.nto.gt.n)then
                      write(logerr,5354) nto
                      ierror = 59
                      return
                  endif
                  izheat(ifrom) = 2
                  izheat(ifrom) = 2
              endif

              if (2*nto.ne.(nret-2)) then
                  write(logerr,	5355) ifrom, nto
                  ierror = 60
                  return
              endif

              do i = 1, nto
                  i1 = 2*i+1
                  i2 = 2*i+2
                  ito = lrarray(i1)
                  frac = lrarray(i2)
                  if(ito.lt.1.or.ito.eq.ifrom.or.ito.gt.n)then
                      write(logerr, 5356) ifrom,ito
                      ierror = 61
                      return
                  endif
                  if(frac.lt.0.0d0.or.frac.gt.1.0d0)then
                      write(logerr, 5357) ifrom,ito,frac
                      ierror = 62
                      return
                  endif
                  zzhtfrac(ifrom,ito) = frac
              end do
              
          ! FURN - no fire, heat walls according to a prescribed time temperature curve
          case ('FURN')
              nfurn=lrarray(1)+0.5
              do i = 1, nfurn
                  furn_time(i)=lrarray(2*i)
                  furn_temp(i)=lrarray(2*i+1)
              end do

          !  HEATF Special fire - heat source only; no mass
          case ('HEATF')
              if (.not.countargs(label,6,lcarray, xnumc-1, nret)) then
                  ierror = 65
                  return
              endif
              heatfr = lrarray(1)
              if(heatfr.lt.1.or.heatfr.gt.n-1) then
                  ierror = 66
                  return
              endif
              heatfl = .true.
              heatfp(1) = lrarray(2)
              heatfp(2) = lrarray(3)
              heatfp(3) = lrarray(4)
              heatfplume =  lrarray(5)
              ! This is a constant heat source only
              heatfq = lrarray(6)



     
          ! Outdated keywords
          case ('OBJFL','MVOPN','MVFAN')
              ierror = 5
	        return
 
        
          case default
              write(logerr, 5051) label
      end select
      go to 10 
	

!	

!	

!	

!	      

!	


  912 FORMAT ('Invalid TARGET METHOD:',A8,'. Valid choices are: ',
     +         'STEADY, IMPLICIT OR EXPLICIT')
  913 FORMAT('Invalid equation type specified in TARGET:',A3,
     +          ' Valid choices are:ODE, PDE or CYL')
 5000 FORMAT ('Keyword ',A5)
 5001	FORMAT ('ONEZ requires a defined compartment ',i3)
 5002 FORMAT ('Too many targets are being defined')
 5003 FORMAT ('The compartment specified by TARGET does not exist',i3)
 5030 FORMAT ('Thermal count does not match compartment count ',2I5)
 5051 FORMAT ('The key word ',a5,' is not recognized')
 5060 FORMAT ('THERE MUST BE SIX PARAMETERS TO SPECIFY A VENT',I5)
 5061 FORMAT ('NEED SIX PARAMETERS TO SPECIFY THE MAINFIRE',I5)
 5062 FORMAT ('Compartment number outside of allowable range',i5)
 5063 FORMAT ('Compartment ',i3,1x,a8,1x,6f6.1,4l,1x,4a10)
 5070 FORMAT ('VENT parameter(s) outside of allowable range',2I4)
 5080 FORMAT ('Too many pairwise horizontal connections',4I5)
 5081 format ('Too many horizontal connections ',3i5)
 5090 FORMAT ('The connection',3I3,' is being redefined')
 5100 FORMAT (' There must be at least 3 parameters to specify ',
     +        ' vertical flow (VVENT).',I4)
 5120 FORMAT ('NOT ENOUGH DATA FOR WIND INPUT ROUTINE ???')
 5130 FORMAT ('THE INTERFACE HEIGHT MUST BE SPECIFIED IN PAIRS',I4)
 5140 FORMAT ('Specification for interface height is outside of',
     +        ' allowable range',2I4)
 5170 FORMAT ('MVOPN must define both sides of a duct opening')
 5180 FORMAT ('Specified node number too large for this system',2I2)
 5191 format ('Compartments specified in MVENT have not been defined ',
     .        2i3)
 5192 format ('Exceeded maximum number of nodes/openings in MVENT ',2i3)
 5193 format ('MVENT(MID) is not consistent ',2i3)
 5194 format ('Pressure for zero flow must exceed the lower limit',
     .        f10.2)
 5195 format ('Too many fan systems',i3)
 5196 format ('Fan (MID) has not been defined for this filter ',i3)
 5200 FORMAT ('Redefinition for node ',2I3)
 5210 FORMAT ('Exceed max external connections',I3)
 5220 FORMAT ('Only ',I2,' specified for an mv duct, 5 required')
 5230 FORMAT ('Exceeded maximum number of mv ducts =',I2)
 5250 FORMAT ('Fan data in wrong format (>4)')
 5260 FORMAT ('Exceeded allowed number of fans',I3)
 5270 FORMAT ('Fan curve has incorrect specification',1P2G12.3)
 5271 FORMAT ('Fan between nodes:',i3,' and ',i3,' is being redefined')
 5272	FORMAT ('Define fan ',i2,' from ',i3,' to ',i3,
     +		  ' over the pressure range ',2f6.1,' with ',i2,
     +		  ' coefficients')
 5290 FORMAT ('Too many internal nodes specified')
 5300 FORMAT ('Too many objects defined in datafile')
 5310 FORMAT ('Incorrect number of parameters for OBJECT')
 5320 FORMAT ('Object specification error, room ',I4,' out of range')
 5321 FORMAT ('Object specification error, not an allowed fire type',i3)
 5322 FORMAT ('Object normal vector must be non-zero')
 5323 format ('Object ',i3,' is outside its compartment')
 5338 format ('Exceed allowed number of detectors')
 5339 format ('Detector ',i3,' is outside of compartment ',a)
 5340 FORMAT ('Set point file name is - ',A)
 5341	FORMAT ('Ceiling jet calculation has been set: ',5l2)
 5342	FORMAT ('Invalid DETECTOR specification - room ',i3)
 5343	FORMAT ('A type ',i3,' detector has been placed in ',a128)
 5344 FORMAT ('A referenced compartment is not yet defined ',i3)
 5345	FORMAT ('VHEAT has specified a non-existent compartment')
 5346 FORMAT ('HALL has specified a non-existent compartment',i3)
 5347 FORMAT ('Compartment specified by ROOMA does not exist ',i3)
 5348 FORMAT ('Data on the ROOMA (or H) line must be positive ',1pg12.3)
 5349 FORMAT ('Compartment specified by ROOMH is not defined ',i3)
 5350 FORMAT ('ROOMH error on data line ',i3)
 5351 FORMAT ('Compartment',i3,' has been redefined as a variable space'
     +        '- area: ',20f8.1)
 5352 FORMAT ('Compartment',i3,' has been redefined as a variable space'
     +        '- height: ',20f8.1)
 5353 FORMAT ('Trying to reset the point file name is - ',A)
 5354 FORMAT ('HHEAT to compartment out of bounds or not defined - ',i3)
 5355 FORMAT ('HHEAT fraction pairs is not consistent ',2i3)
 5356 FORMAT ('HHEAT specification error in compartment pairs: ',2i3)
 5357 FORMAT ('Error in fraction for HHEAT:',2i3,f5.3)
 5358 FORMAT ('Not a valid ignition criterion ',I5)
 5400 format ('xdtect = ',15f8.1)
 5401 format ('ixdtect = ',4i5)
 5402 format ('Plume index out of range ',i3)
 5403 format ('Plume model for this fire: ',a10)

      END SUBROUTINE keywordcases

	subroutine inputmainfire (iounit,errorcode)

!  This routine reads the "mainfire.o" file either from the current directory
!  or the directory for the executable. If it does not exist in either place, then
!  we quit

!  The order of species is 'N2', 'O2', 'CO2', 'CO', 'HCN', 'HCL', 'TUHC', 'H2O','OD', 'CT', 'TS'

      use iofiles
      include "precis.fi"
      include "cfast.fi"

	character*10 data_file /'mainfire.o' /, testpath*256 
	integer numr, numc, i, j, iounit, logerr/3/, errorcode
	logical exists, doesthefileexist
      data hcmax /5.0D7/, hcmin/1.31D+7/

! First we try the local directory
	testpath = trim (datapath) // data_file 
	exists = DoesTheFileExist(testpath)

! Then we try the executable root directory
	if (.not.exists) then
	  testpath = trim (exepath) // data_file 
	  exists = DoesTheFileExist(testpath)
	  if (.not.exists) then
! All is lost
			write (logerr, 5000) trim(testpath)
			errorcode = 200
			return
	  endif
	endif
	write (logerr, 5001) testpath
	
	close (iounit)
	open (unit=iounit,file=testpath,form='formatted')

!	ignore the header line and start with row 2

	call readcsvformat (iounit,rarray,carray,nrow,ncol,2,numr,numc,
     . errorcode)
	if (errorcode.gt.0) return

!	First, get the scalar data; for the mainfire, we do not check the name

	lfmax = rarray (1,1)
	xx1 = 1.0d0

!	Check array limits
	if (lfmax.gt.nv) then
		 ierror = 209
		 write(logerr,5002)
		 return
	endif

!	Note that we are fudging this; gmwf is in m/kg, but cfast is expecting m/g
	GMWF = rarray(2,1) * 1.0D3
	te = rarray(4,1)
!	Note that we are not using the heat of gasification at the moment

	radconsplit(0) = rarray(6,1)
!	Fires do not radiate below a fraction of 0.8
	if(radconsplit(0).gt.0.8d0) then
		write(logerr,5003) radconsplit(0)
		errorcode = 219
		return
	else if (radconsplit(0).gt.0.5d0) then
		write(logerr,5003) radconsplit(0)
	endif

	HCOMBA = rarray(11,1)

! This should not be important, but just in case

      do 300 i = 1, nv
      DO 300 II = 1, ns
      	MPRODR(I,II) = xx0
  300 CONTINUE
	
      DO 400 I = 1, NV
        HOCBMB(I) = HCOMBA
  400 CONTINUE

	do 1 i = 1, lfmax
	tfired(i) = rarray(i,2)
	qfired(i) = rarray(i,3)
	bfired(i) = rarray(i,4)
	hfired(i) = rarray(i,5)
	afired(i) = rarray(i,6)
      if (afired(i).eq.0.0) afired(i) = 0.05D0
      OCRATI(I) = rarray(i,7)
	hcratio(i) = rarray(i,8)
	COCO2(I) = rarray(i,9)
      CCO2(I) = rarray(i,10)
      HCNF(I) = rarray(i,11)
      HCLF(I) = rarray(i,12)
      hcrf(i) = rarray(i,14)
!	Note that CT, TUHC and TS are carried in the mprodr array - all other species have their own array
	mprodr(i,7) = xx1
	mprodr(i,10) = rarray(i,13)
	mprodr(i,11) = rarray(i,14)

    1	continue

	call sethoc (lfmax, bfired, qfired, hocbmb, hcomba)

	close (iounit)	

 5001 format ('Open mainfire object file ',a256)
 5000 format ('Cannot find the main object file in either the' 
     . ' executable path or the local directory ',/,a)
 5002	format ('Too many entries for the main fire')
 5003 format (
     . 'Radiation fraction for main fire is outside of a normal range',
     .  f7.2)

	end subroutine inputmainfire

	subroutine inputobject (objname, iobj, iounit, errorcode)

!  This routine reads the object files either from the current directory
!	or the directory for the executable. If it does not exist in either place, then
!	we quit

!  The object name is objname.  iobj is the counter in the main list of objects

!  The order of species is 'N2', 'O2', 'CO2', 'CO', 'HCN', 'HCL', 'TUHC', 'H2O','OD', 'CT', 'TS'

!  The minimum separation between an object an a wall is 1mm (minimumseparation)
!  The maximum heat release rate (see reference in the UG and TR) is 4 MW/m^3 (the actual value should be 2, 
!     but where we cut the user some slack

      use iofiles
      include "precis.fi"
      include "cfast.fi"
      include "objects2.fi"
      include "fltarget.fi"

	character testpath*256 , objname*(*)
	integer numr, numc, i, j, iounit, logerr/3/, errorcode, 
     . midpoint/1/, base/2/
	logical exists, doesthefileexist
      data hcmax /5.0D8/, hcmin/1.31D+7/
	double precision minimumheight/1.d-3/, maximumhrr, xx0, hrrpm3

! First we try the local directory

	testpath = trim (datapath) // trim(objname) // '.o'
	exists = DoesTheFileExist(testpath)

! Then we try the executable root directory

	if (.not.exists) then
	  testpath = trim (exepath) // trim(objname) // '.o'
	  exists = DoesTheFileExist(testpath)

! All is lost

	  if (.not.exists) then
			write (logerr, 5000) trim(testpath)
			errorcode = 215
			return
	  endif
	endif

! All is not lost

	write (logerr, 5001) testpath
	
	close (iounit)
	open (unit=iounit,file=testpath,form='formatted')

!	Unlike the main fire, we need the header information

	call readcsvformat (iounit,rarray,carray,nrow,ncol,1,numr,numc,
     . errorcode)
	if (errorcode.gt.0) return
! Make sure we are reading the object we think we should have
	if(carray(1,1).ne.objname) then
		 errorcode = 210
		 write(logerr,5004) objname, carray(1,1)
		 return
	endif
	if(numc.lt.14) then
		write(logerr,5108) numc
	endif

! Copy the data into the appropriate arrays
!!!!!! Note, we assume that there cannot be more objects to initialize than there are objects in a calculation 

	xx0 = 0.0d0
	xx1 = 1.0d0

      OBJLFM(IOBJ) = rarray(2,1)
      OBJGMW(IOBJ) = rarray(3,1) * 1.0D+3
      OBJVT(IOBJ) = rarray(5,1)
	radconsplit(iobj) = rarray(7,1)
	if(radconsplit(iobj).gt.0.8d0) then
		write(logerr,5103) radconsplit(iobj)
		errorcode = 219
		return
	else if (radconsplit(iobj).gt.0.5d0) then
		write(logerr,5103) radconsplit(iobj)
	endif

      OHCOMB = rarray(12,1)
      NTARG = NTARG + 1
      IF (NTARG.GT.MXTARG) THEN
      	write(logerr, 5002) 
      	IERROR = 201
      	RETURN
      END IF
      OBTARG(IOBJ) = NTARG
      CXTARG(NTARG) = carray(13,1)

      OBJMAS(IOBJ) = rarray(8,1)
      OBJXYZ(1,IOBJ) = rarray(9,1)
      OBJXYZ(2,IOBJ) = rarray(10,1)
      OBJXYZ(3,IOBJ) = rarray(11,1)

! Calculate the characteristic size of an object.
! This is a basic conceptual model for the physical extent for the heat release
	objcl(iobj) = objxyz(1,iobj) * objxyz(2,iobj) * objxyz(3,iobj)
	if(objcl(iobj).lt.1.0d-6) then
		write(logerr,5005) iobj,objcl(iobj)
		errorcode = 220
		return
	endif
	objcl(iobj) = objcl(iobj)**0.333d0

      OTIME(1,IOBJ) = xx0

	if(objlfm(iobj).gt.nv) then
		 errorcode = 208
		 write (logerr,5003)
		 return
	endif

! This should not be important, but just in case

      do 300 i = 1, nv
      DO 300 II = 1, ns
      	OMPRODR(I,II,IOBJ) = xx0
  300 CONTINUE

! Move the array data into the object arrays

	maximumhrr = xx0
      DO 400 II = 1, OBJLFM(IOBJ)
         OTIME(II,IOBJ) = rarray(ii+1,2)
         OQDOT(II,IOBJ) = rarray(ii+1,3)
	   maximumhrr = max(maximumhrr, oqdot(ii,iobj))
         OMASS(II,IOBJ) = rarray(ii+1,4)
! This is to stop dassl from an floating point underflow when it tries to extrapolate back.
! It only occurs for objects which are on the floor and ignite after t=0
         OHIGH(II,IOBJ) = rarray(ii+1,5)
         OAREA(II,IOBJ) = rarray(ii+1,6)
         if (OAREA(II,IOBJ).eq.0.0) OAREA(II,IOBJ) = 0.05D0
         OOC(II,IOBJ) = rarray(ii+1,7)
         OHCR(II,IOBJ) = rarray(ii+1,8)
         OCO(II,IOBJ) = rarray(ii+1,9)
         OOD(II,IOBJ) = rarray(ii+1,10)
         OMPRODR(II,5,IOBJ) = rarray(ii+1,11)
         OMPRODR(II,6,IOBJ) = rarray(ii+1,12)
	   omprodr(ii,7,iobj) = xx1
         OMPRODR(II,10,IOBJ) = rarray(ii+1,13)
	   omprodr(ii,11,iobj) = rarray(ii+1,14)
  400 CONTINUE

	OTFMAXT(IOBJ) = OTIME(OBJLFM(IOBJ),IOBJ)

!	set the heat of combustion - this is a problem if the qdot is zero and the mdot is zero as well
	call sethoc (objlfm(iobj), omass(1,iobj), oqdot(1,iobj), 
     +             objhc(1,iobj), ohcomb)

!	Position the object

	call positionobject(objpos,1,iobj,objrm(iobj),br,
     . midpoint,minimumheight,errorcode)
	if (errorcode.ne.0) return
	call positionobject(objpos,2,iobj,objrm(iobj),dr,
     . midpoint,minimumheight,errorcode)
	if (errorcode.ne.0) return
	call positionobject(objpos,3,iobj,objrm(iobj),hr,
     . base,minimumheight,errorcode)
	if (errorcode.ne.0) return
	
! Diagnostic - check for the maximum heat release per unit volume.
 
!	First, estimate the flame length - we want to get an idea of the size of the volume over which the energy will be released
	area = objxyz(1,iobj) * objxyz(2,iobj)
	d = max(0.33d0,sqrt(4.0/3.14*area))
	flamelength = d * (0.235d0*(maximumhrr/1.0d3)**0.4 - 1.02)
	flamelenght = max (xx0, flamelength)
!	Now the heat realease per cubic meter - we know that the size is larger than 1.0d-6 m^3 - enforced above
	hrrpm3 = maximumhrr/(area*(objxyz(3,iobj)+flamelength))
	if (hrrpm3.gt.4.0e+6) then
	  WRITE (LOGERR,5106) trim(objname),(OBJPOS(i,IOBJ),i=1,3),hrrpm3
	  errorcode = 221
	  return
	else if (hrrpm3.gt.2.0d+6) then
	  WRITE (LOGERR,5107) trim(objname),(OBJPOS(i,IOBJ),i=1,3),hrrpm3
	else 
	  WRITE (LOGERR,5100) trim(objname),(OBJPOS(i,IOBJ),i=1,3),hrrpm3
	endif

!	Initialize object target position

	CALL SETOBTRG (NTARG,IOBJ,IERROR)

	close (iounit)	

	return

 5000 format ('Cannot find the object fire file in either the' 
     . ' executable path or the local directory ',/,a)
 5001 format ('Open the object fire file ',a256)
 5002 FORMAT ('Too many targets are being defined in inputobject')
 5003 format ('Too many entries for the object file')
 5004 format ('Names do not match ',a8,2x,a8)
 5005 format ('Object # ',i3,' is too small. Volume = ',g10.3)
 5100 FORMAT ('Object ',a,' position set to ',3F7.3, 
     . '; Maximum HRR per m^3 is ',1pg10.3)
 5106 FORMAT ('Object ',a,' position set to ',3F7.3,
     . '; Maximum HRR per m^3 = ',1pg10.3,' exceeds physical limits')
 5107 FORMAT ('Object ',a,' position set to ',3F7.3,
     . '; Maximum HRR per m^3 = ',1pg10.3,' exceeds nominal limits')
 5103 format (
     . 'Radiation fraction for object fire is outside of a normal range'
     . f7.3)
 5108 format ('>>>Old fire object format - please update, count =',i3)


	end subroutine inputobject

	subroutine inputtpp (tppname, errorcode)

!  This routine reads the thermophysical properties file either from the current directory
!  or the directory for the executable. If it does not exist in either place, then we quit


      use iofiles
      include "precis.fi"
      include "cfast.fi"
      include "objects2.fi"
      include "fltarget.fi"
      include "thermp.fi"

	character testpath*256, tppname*(*)
	integer numr, numc, i, j, iounit, logerr/3/, errorcode
	logical exists

! First we try the local directory
	testpath = trim (datapath) // trim(tppname) // '.csv'
	inquire (file = testpath, exist = exists)
! Then we try the executable root directory
	if (.not.exists) then
	  testpath = trim (exepath) // trim(tppname) // '.csv'
	  inquire (file=testpath, exist=exists)
	  if (.not.exists) then
! All is lost
			write (logerr, 5000) trim(testpath)
			errorcode = 202
			return
	  endif
	endif
	write (logerr, 5001) testpath
	
	close (iounit)
	open (unit=iounit,file=testpath,form='formatted')

! The first entry is the first property, so start at the beginning

	call readcsvformat (iounit,rarray,carray,nrow,ncol,1,numr,numc,
     . errorcode)
      if (errorcode.gt.0) return

! Check to make sure we do not overwrite the tpp data structures

! Too many TPPs.
	if (numr.gt.nthmx) then
		 ierror = 203
		 return
	endif
! Data format is not correct
	if (numc.lt.14) then
		 ierror = 204
		 return
	endif
		
! Copy the data into the appropriate arrays

	do 10 i = 1, numr
	nlist(i) = carray(i,1)
	lnslb(i) = 1
	DO 30 K = 1, lNSLB(I)
	 	lFKW(K,I) = rarray(i,2)
	 	lCW(K,I) = rarray(i,3)
	 	lRW(K,I) = rarray(i,4)
	 	lFLW(K,I) = rarray(i,5)
   30 CONTINUE
      lEPW(I) = rarray(i,6)
      DO 40 K = 1, 7
   40 lHCLBF(K,I) = rarray(i,6+k)

   10 CONTINUE

! Finally we put in the default properties; this also becomes the size of the database
	maxct = numr + 1

      NLIST(maxct) = 'DEFAULT'
      LNSLB(maxct) = 1
      LFKW(1,maxct) = 0.120D0
      LCW(1,maxct) = 900.0D0
      LRW(1,maxct) = 800.0D0
      LFLW(1,maxct) = 0.0120D0
      LEPW(maxct) = 0.90D0
      DO 50 I = 1, 7
        LHCLBF(I,maxct) = 0.00D0
   50 CONTINUE

	close (iounit)	
	return

 5000 format ('Cannot find the thermophysical properties file in '
     . 'either the executable path or the local directory ',/,a)
 5001 format ('Open the thermophysical properties file ',a256)

	end subroutine inputtpp

      SUBROUTINE DREADIN(OUTPUT,IOUNIT,IERR,IVERS0)
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     DREADIN
C
C     Source File: DREADIN.SOR
C
C     Functional Class:  
C
C     Description:  Read routine for compacted history files
C
C     Arguments: OUTPUT   Starting location for I/O
C                LENF     Length of floating point section in words
C                IOUNIT   Logical unit assigned for read
C                IERR     Status of read (zero if OK)
C                IVERS0   Version number of history file
C
C     Revision History:
C        Created:  9/14/1993 at 10:05 by RDP
C        Modified: 9/5/1995 at 9:26 by PAR:
C                  Added support for IERROR and returning error codes to main
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C
 
      PARAMETER (MXDMP = 36000)
      LOGICAL CNVRT
      CHARACTER HEADER*6, RHEADER(2)*6
      INTEGER OUTPUT(*), INPUT(MXDMP), FLOP
      DATA RHEADER /'$$CFL$', '$$CFH$'/
C
      IERR = 0
      READ (IOUNIT,END=30,IOSTAT=IOS) HEADER, IVERS0
      IF (HEADER.EQ.RHEADER(1)) THEN
#ifdef pp_ibmpc
        CNVRT = .FALSE.
#else
        CNVRT = .TRUE.
#endif
      ELSE IF (HEADER.EQ.RHEADER(2)) THEN
#ifdef pp_ibmpc
        CNVRT = .TRUE.
#else
        CNVRT = .FALSE.
#endif
      ELSE
        IERR = 9999
        RETURN
      END IF
	IF (CNVRT) IVERS0 = FLOP(IVERS0)
      IF (CNVRT) THEN
        READ (IOUNIT,END=30,IOSTAT=IOS) INPUT(1), (INPUT(I),I = 2,
     +      FLOP(INPUT(1)))
        INPUT(1) = FLOP(INPUT(1))
      ELSE
        READ (IOUNIT,END=30,IOSTAT=IOS) INPUT(1), (INPUT(I),I = 2,
     +      INPUT(1))
      END IF
      IF (INPUT(1).GT.MXDMP) THEN
         CALL XERROR('DREADIN - overwrite input buffer; fatal error',
     .               0,1,1)
         IERR = 7
         RETURN
      END IF
      IF (CNVRT) THEN
        DO 10 I = 2, INPUT(1)
          INPUT(I) = FLOP(INPUT(I))
   10   CONTINUE
      END IF
      CALL UNPACK(INPUT,OUTPUT)
      IF (CNVRT) THEN
        CALL LENOCO(((IVERS0-1800)/10),ITOT,IFLT,IINT)
        DO 20 I = 1, IFLT / 2
          ITEMP = OUTPUT(2*I-1)
          OUTPUT(2*I-1) = OUTPUT(2*I)
          OUTPUT(2*I) = ITEMP
   20   CONTINUE
      END IF
   30 IF (IOS.NE.0) THEN
        IERR = IOS
      ELSE
        IERR = 0
      END IF
      RETURN
      END
 
      SUBROUTINE UNPACK(INPUT,OUTPUT)
 
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     UNPACK
C
C     Source File: DREADIN.SOR
C
C     Functional Class:  
C     
C     Description:  This routine is to uncrunch the packed binary history file.
C                   The length of the record is contained in the first word, 
C                   and does NOT include the first word itself.  
C                   See WRITEOT for the reference information.
C
C     Arguments: INPUT    Packed array
C                OUTPUT   Unpack array returned
C
C     Revision History:
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C
      INTEGER OUTPUT(*), INPUT(*)
      INTEGER I, INTGR, CNTR, MRKR, INLEN, INIDX, OUTIDX
 
      MRKR = 106
      INIDX = 1
      OUTIDX = 0
      INLEN = INPUT(1)
   10 IF (.TRUE.) THEN
        INIDX = INIDX + 1
        IF (INIDX.GT.INLEN) GO TO 30
        INTGR = INPUT(INIDX)
        IF (INTGR.EQ.MRKR) THEN
          INIDX = INIDX + 1
          IF (INIDX.GT.INLEN) GO TO 30
          INTGR = INPUT(INIDX)
          IF (INTGR.EQ.MRKR) THEN
            OUTIDX = OUTIDX + 1
            OUTPUT(OUTIDX) = INTGR
          ELSE
            INIDX = INIDX + 1
            IF (INIDX.GT.INLEN) GO TO 30
            CNTR = INPUT(INIDX)
            DO 20, I = 1, CNTR
              OUTIDX = OUTIDX + 1
              OUTPUT(OUTIDX) = INTGR
   20       CONTINUE
          END IF
        ELSE
          OUTIDX = OUTIDX + 1
          OUTPUT(OUTIDX) = INTGR
        END IF
        GO TO 10
      END IF
   30 RETURN
      END

      INTEGER FUNCTION FLOP(INUM)
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     FLOP
C
C     Source File: FCONV.FOR
C
C     Functional Class:  UTILITY
C
C     Description:  Flip bytes in an integer word PC - IRIS or back
C
C     Arguments: INUM
C
C     Revision History:
C        Created:  8/6/1993 at 14:08 by RDP
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C
      INTEGER*1 B(4), C(4)
      INTEGER I, J
      EQUIVALENCE (B,I), (C,J)
      I = INUM
      C(1) = B(4)
      C(2) = B(3)
      C(3) = B(2)
      C(4) = B(1)
      FLOP = J
      RETURN
      END

      subroutine readcf1 (errorcode)

!     Routines:    READCF1, 2 AND 3
!
!     Source File: READCF1.F
!
!     Functional Class:

! 	get the paths and project base name
! 	open the input file for reading (1)
! 	delete the output files
! 	open the log file (3)
! 	call the input routines

      use iofiles
      
      integer errorcode , lp, ld, lf, ios
      integer(2) filecount
      logical exists

      character*256 testpath, testproj 

! get the path and project names

      errorcode = 0
      call exehandle (exepath, datapath, project, errorcode)
      if (errorcode.gt.0) return

! form the file names

! datafiles: inputfile, outputfile, smvhead, smvdata, smvcsv, ssflow, ssnormal, ssspecies, sswall

      testpath = trim (datapath)
      lp = len_trim (testpath)
      testproj = trim (project)
      ld = len_trim (testproj)
      inputfile = testpath(1:lp) // testproj(1:ld) // '.in'
      outputfile = testpath(1:lp) // testproj(1:ld) // '.out'
      smvhead = testpath(1:lp) // testproj(1:ld) // '.smv'
      smvdata = testpath(1:lp) // testproj(1:ld) // '.plt'
      smvcsv = testpath(1:lp) // testproj(1:ld) // '_zone.csv'
      ssflow = testpath(1:lp) // testproj(1:ld) // '_f.csv'
      ssnormal = testpath(1:lp) // testproj(1:ld) // '_n.csv'
      ssspecies = testpath(1:lp) // testproj(1:ld) // '_s.csv'
      sswall = testpath(1:lp) // testproj(1:ld) // '_w.csv'
      errorlogging = testpath(1:lp) // testproj(1:ld) // '.log'
      stopfile = testpath(1:lp) // testproj(1:ld) // '.stop'
      historyfile = testpath(1:lp) // testproj(1:ld) // '.hi'
      queryfile = testpath(1:lp) // testproj(1:ld) // '.query'
      statusfile = testpath(1:lp) // testproj(1:ld) // '.status'
      kernelisrunning = testpath(1:lp) // testproj(1:ld) //
     * '.kernelisrunning'

      testpath = trim (exepath)
      lp = len_trim (testpath)
      solverini = testpath(1:lp) // 'solver.ini'

      open (unit=1, file=inputfile, action='read', status='old', 
     *      iostat=ios)

      call deleteoutputfiles (outputfile)
      call deleteoutputfiles (smvhead)	
      call deleteoutputfiles (smvdata)
      call deleteoutputfiles (smvcsv)
      call deleteoutputfiles (ssflow)
      call deleteoutputfiles (ssnormal)
      call deleteoutputfiles (ssspecies)
      call deleteoutputfiles (sswall)
      call deleteoutputfiles (errorlogging)
      call deleteoutputfiles (stopfile)
      call deleteoutputfiles (historyfile)
      call deleteoutputfiles (statusfile)
      call deleteoutputfiles (queryfile)
      call deleteoutputfiles (kernelisrunning)

! since we have reached this point, the output files are avaiable and stop has been turned off.
! open the log file and return the correct project name

      open (unit=3, file=errorlogging, action='write', iostat=ios, 
     *      status='new')

	project = testproj (1:ld)
	errorcode = ios

      return

      end

	SUBROUTINE SETP0(P0, IP0, PMXMN, IPMXMN, iounit, IERROR)

C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     SETP0
C
C     Source File: SETP0.SOR
C
C     Functional Class:  
C
C     Description:  
C
C      Arguments: P0      Array containing new set values for p vector
C                 IP0     Array of flags for variables that have changes in P0
C                 IERROR  Error flag
C
C     Revision History:
C        Created:  1/28/1998 at 9:57 by PAR
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------

      use iofiles
      include "precis.fi"
      include "cfast.fi"
      include "cshell.fi"
      include "cfin.fi"
      include "opt.fi"

      DIMENSION P0(*), IP0(0:*)
      DIMENSION PMXMN(MAXTEQ,2), IPMXMN(0:MAXTEQ,2)
      INTEGER iounit
      CHARACTER LABEL*5, TESTFILE*128, PLACE*1, MXMN*1, TOUPPER*1
	character testpath*256
      INTEGER ILOCAL(2)
	logical exists, doesthefileexist, eof

      DOUBLE PRECISION LOCAL(2)

      IP0(0) = OFF
      IERROR = 0
      DO 10 I = 1, MAXTEQ
      	P0(I) = 0.D0
	IP0(I) = OFF
   10 CONTINUE

      IF (SETPFILE.EQ.'   ') RETURN

! First we try the local directory

	testpath = trim (datapath) // trim(setpfile)
	exists = DoesTheFileExist(testpath)

! Then we try the executable root directory

	if (.not.exists) then
	  testpath = trim (exepath) // trim(setpfile)
	  exists = DoesTheFileExist(testpath)

! All is lost

	  if (.not.exists) then
			write (logerr, 5000) trim(setpfile)
			errorcode = 217
			return
	  endif
	endif

! All is not lost

	write (logerr, 5001) testpath
	
	close (iounit)
	open (unit=iounit,file=testpath,form='formatted')

      CALL READBF(IO, LABEL, eof)
      DO 30 I = 1, 5
        LABEL(I:I) = TOUPPER(LABEL(I:I))
   30 CONTINUE
      IF (LABEL(1:4).NE.'FILE') THEN
		IERROR = 75
		CLOSE(IO)
		RETURN
      END IF
      CALL READFL(TESTFILE)
      IF (TESTFILE.NE.NNFILE) THEN
        IERROR = 50
	CLOSE(IO)
	RETURN
      END IF

   20 CONTINUE

      CALL READBF(IO, LABEL, eof)
      DO 40 I = 1, 5
          LABEL(I:I) = TOUPPER(LABEL(I:I))
   40 CONTINUE

      CALL READIN(2,NRET,ILOCAL,LOCAL)
		IROOM = ILOCAL(1)
		X = LOCAL(2)
      CALL READFL(PLACE)
		PLACE = TOUPPER(PLACE)
      CALL READFL(MXMN)
		MXMN = TOUPPER(MXMN)
	
	IF (LABEL(1:4).EQ.'TEMP') THEN
	  IF (PLACE.EQ.'U') THEN
	    CALL DOP0(NOFTU,IROOM,MXMN,X,P0,IP0,PMXMN,IPMXMN)
	  ELSE IF (PLACE.EQ.'L') THEN
	    CALL DOP0(NOFTL,IROOM,MXMN,X,P0,IP0,PMXMN,IPMXMN)
	  ELSE
		 write(logerr,*) 'Parameter not supported by SETP'
		 ierror = 77
		 CLOSE(IO)
		 return
	  END IF
	ELSE IF (LABEL.EQ.'PRESS') THEN
		MXMN = PLACE
		CALL DOP0(NOFP,IROOM,MXMN,X,P0,IP0,PMXMN,IPMXMN)
	ELSE IF (LABEL.EQ.'INTER') THEN
		MXMN = PLACE
		X = (HR(IROOM) - X)*AR(IROOM)
		CALL DOP0(NOFVU,IROOM,MXMN,X,P0,IP0,PMXMN,IPMXMN)
	ELSE
		CLOSE(IO)
		RETURN
	END IF

      GOTO 20

 1000 CONTINUE
      write(logerr,*)'Error Reading the "SETP" file'
      IERROR = 76
      RETURN
 5000 format ('Cannot find the object fire file in either the' 
     . ' executable path or the local directory ',/,a)
 5001 format ('Open the SETPARAMETER file ',a)

      END

      SUBROUTINE DOP0(NOFLG, IROOM, MXMN, X, P0, IP0, PMXMN, IPMXMN)
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     DOP0
C
C     Source File: SETP0.SOR
C
C     Functional Class:  
C
C     Description:  
C
C      Arguments: NOFLG   Index into the P vector
C                 IROOM   Index of room
C                 MXMN    Character flag of max or min of value
C                 P0      Array containing new set values for p vector
C                 IP0     Array of flags for variables that have changes in P0
C                 PMXMN   Array containing new limits of values for p vector
C                 IPMXMN  Array of flags for limits that have
C                         been set in PMXMN
C
C     Revision History:
C        Created:  1/28/1998 at 9:57 by PAR
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------

      include "precis.fi"
      include "cfast.fi"
      include "cshell.fi"
      include "cfin.fi"
      include "opt.fi"

      DIMENSION P0(*), IP0(0:*)
      DIMENSION PMXMN(MAXTEQ,2), IPMXMN(0:MAXTEQ,2)
      CHARACTER MXMN*1

      IF (MXMN.EQ.'X') THEN
        IPMXMN(0,1) = ON
        PMXMN(NOFLG+IROOM,1) = X
        IPMXMN(NOFLG+IROOM,1) = ON
      ELSE IF (MXMN.EQ.'M') THEN
        IPMXMN(0,2) = ON
        PMXMN(NOFLG+IROOM,2) = X
        IPMXMN(NOFLG+IROOM,2) = ON
      ELSE
        IP0(0) = ON
        P0(NOFLG+IROOM) = X
        IP0(NOFLG+IROOM) = ON
      END IF

      RETURN
      END

      subroutine positionobject (xyz,index,opoint,rpoint,criterion,
     . defaultposition,minimumseparation,errorcode)

	integer index, defaultposition, opoint,rpoint, errorcode
	double precision xyz(3,0:*), xx0/0.d0/, minimumseparation,
     . criterion(*)

!       Position an object in a compartment
!		xyz is objposition (objpos)
!		index is 1, 2 or 3 for x, y or z
!		opoint is the object pointer
!		rpoint is the compartment
!		criterion is the maximum extent
!		defaultposition is to set to zero (base)(2) or midpoint(1)
!		minimumseparation is the closest the object can be to a wall

      IF((xyz(index,opoint).lt.xx0).or.
     .   (xyz(index,opoint).gt.criterion(rpoint))) THEN
		select case (defaultposition)
			case (1) 
				xyz(index,opoint) = criterion(rpoint)/2.0d0
			case (2) 
				xyz(index,opoint) = minimumseparation
			case default
				errorcode = 222
		end select
	else if (xyz(index,opoint).eq.xx0) then
		xyz(index,opoint) = minimumseparation
	else if (xyz(index,opoint).eq.criterion(rpoint)) then
		xyz(index,opoint) = criterion(rpoint)-minimumseparation
	END IF

	return

      end subroutine positionobject

      SUBROUTINE SETOBTRG (ITARG,IOBJ,IERROR)

C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     SETOBTRG
C
C     Source File: SETOBTRG.SOR
C
C     Functional Class:  INPUT
C
C     Description:  Takes information from OBJECTS and sets a target
C                   for each.
C
C     Arguments: ITARG
C                IOBJ
C                IERROR  Returns error codes
C
C     Revision History:
C        Created:  8/15/1995 at 14:54 by PAR
C        Modified: 9/5/1995 at 10:26 by PAR:
C                  Added support for IERROR and returning stops to main
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C

      include "precis.fi"
      include "cfast.fi"
      include "cenviro.fi"
      include "objects1.fi"
      include "objects2.fi"
      include "fltarget.fi"

	IXTARG(TRGROOM,ITARG) = OBJRM(IOBJ)
	DO 10 I = 0,2
	  XXTARG(TRGCENX+I,ITARG) = OBJPOS(1+I,IOBJ)
	  XXTARG(TRGNORMX+I,ITARG) = OBJORT(1+I,IOBJ)
   10 CONTINUE
   	IXTARG(TRGWALL,ITARG) = 0
   	IXTARG(TRGMETH,ITARG) = MPLICIT
!	Using ODE because of problems with PDE
!	IXTARG(TRGEQ,ITARG) = PDE
	IXTARG(TRGEQ,ITARG) = ODE
	RETURN
	END

      subroutine readcsvformat (iunit,x,c,numr,numc,nstart,maxr,maxc,
     . ierror)

c
c   reads a comma-delimited file as generated by Micorsoft Excel
c   program assumes that all the data is in the form of real numbers
c
c   Variables:
c     iunit  = logical unit, already open to .csv file
c     x      = array of dimension (numr,numc) for values in spreadsheet
c     c      = character array of same dimenaion as x for character values in spreadsheet
c     numr   = # of rows of array x
c     numc   = # of columns of array x
c     nstart = starting row of spreadsheet to read
c     maxr     = actual number of rows read
c     maxcc    = actual number of columns read
c

      include "cparams.fi"
      include "cshell.fi"

	double precision x(numr,numc)
	character in*10000,token*128, c(numr,numc)*(*)
	integer ierror

	maxr = 0
	maxc = 0
	ierror = 0
	do i=1,numr
	  do j=1,numc
	    x(i,j) = 0.
		c(i,j) = ' '
	  end do
	end do

! if we have header rows, then skip them

	if (nstart.gt.1) then
	  do  i=1,nstart-1
	    read (iunit,'(A)') in
        end do 
      end if

! read the data

	nrcurrent=0
20    read (iunit,'(A)',end=100) in

! Skip comments
	if (in(1:1).eq.'!'.or.in(1:1).eq.'#') then
		 go to 20
	endif

      nrcurrent=nrcurrent+1
	maxr=max(maxr,nrcurrent)

! Cannot exceed work array
	if(maxr.gt.numr) then
		 ierror = 207
		 return
	endif

      nc=0
      ic=1
30	icomma=index(in,',')
	if (icomma.ne.0) then
	  if (icomma.eq.ic) then
	    token=' '
	  else
	    token=in(ic:icomma-1)
	  end if
	  ic = icomma+1
	  nc = nc + 1
	  in(1:ic-1)=' '
	  if (nrcurrent.le.numr.and.nc.le.numc) then
		c(nrcurrent,nc) = token
	   read (token,'(f128.0)',iostat=ios) x(nrcurrent,nc)
		if (ios.ne.0) x(nrcurrent,nc) = 0
	  else
		write (logerr,*) 'Array exceeded (readcsv), r,c=',nrcurrent,nc
		ierror = 207
		return
	  end if
	  go to 30
	end if
	nc = nc + 1
	maxc=max(maxc,nc)
	token = in(ic:ic+100)
	c(nrcurrent,nc) = token
	read (token,'(f128.0)',iostat=ios) x(nrcurrent,nc)
	if (ios.ne.0) x(nrcurrent,nc) = 0
	go to 20

100   continue
	
      return
      end

      integer function rev_input
          
      INTEGER :: MODULE_REV
      CHARACTER(255) :: MODULE_DATE 
      CHARACTER(255), PARAMETER :: 
     * mainrev='$Revision$'
      CHARACTER(255), PARAMETER :: 
     * maindate='$Date$'
      
      WRITE(module_date,'(A)') 
     *    mainrev(INDEX(mainrev,':')+1:LEN_TRIM(mainrev)-2)
      READ (MODULE_DATE,'(I5)') MODULE_REV
      rev_input = module_rev
      WRITE(MODULE_DATE,'(A)') maindate
      return
      end function rev_input