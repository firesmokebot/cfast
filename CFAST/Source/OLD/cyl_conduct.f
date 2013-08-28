      SUBROUTINE GETCYLTEMP(X,WTEMP,NX,RAD,TEMPX)
      IMPLICIT NONE
      real*8, INTENT(IN) :: X, RAD
      INTEGER, INTENT(IN) :: NX
      real*8, INTENT(IN), DIMENSION(NX) :: WTEMP
      real*8, INTENT(OUT) :: TEMPX
      
      real*8 :: DR, R, RINT, FACTOR
      INTEGER :: LEFT, RIGHT
      
      DR = RAD/NX
      R = RAD-X
      IF(R<=DR/2.0)THEN
        TEMPX = WTEMP(1)
        RETURN
      ENDIF
      IF(R>=RAD-DR/2.0)THEN
        TEMPX = WTEMP(NX)
        RETURN
      ENDIF
      RINT = R/DR-0.5
      LEFT = INT(RINT)+1
      LEFT=MAX(MIN(LEFT,NX),1)
      RIGHT = LEFT + 1
      RIGHT=MAX(MIN(RIGHT,NX),1)
      FACTOR = (RINT-INT(RINT))
      TEMPX = FACTOR*WTEMP(RIGHT) + (1.0-FACTOR)*WTEMP(LEFT)
      
      END SUBROUTINE GETCYLTEMP
      
      SUBROUTINE CYLCNDUCT(WTEMP,NX,WFLUXIN,DT,WK,WRHO,WSPEC,DIAM)
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     CNDUCT
C
C     Source File: CNDUCT.SOR
C
C     Functional Class:  
C
C     Description:  
C
C     Arguments: WTEMP    Wall temperature profile
C                NX       Number of nodes
C                WFLUXIN  Flux striking interior wall
C                DT       Time step interval from last valid solution point
C                WRHO     Wall density
C                DIAM     DIAMETER OF CABLE
C
C---------------------------- ALL RIGHTS RESERVED ----------------------------
C
      IMPLICIT NONE
      
      INTEGER, INTENT(IN) :: NX
      real*8, INTENT(IN)  :: DT,WRHO, WK, WSPEC, DIAM
      real*8, INTENT(IN)  :: WFLUXIN
      real*8, INTENT(INOUT), DIMENSION(NX) :: WTEMP

C*** DECLARE LOCAL VARIABLES

      INTEGER :: NN, I, II, NR, NITER, ITER
      PARAMETER (NN = 50)
      real*8, DIMENSION(NN) :: AIM1, AI, AIP1, TNEW
      real*8, DIMENSION(NN) :: CC, DD
      real*8 :: ALPHA, DR, FACTOR, DT_ITER
      
      
      NR = NN
      DR = (DIAM/2.0D0)/NR
      ALPHA = WK / (WSPEC*WRHO)
      DT_ITER = MIN(DT,0.1)
      NITER = DT/DT_ITER + 0.5
      DT_ITER=DT/NITER
      FACTOR = 2.0*ALPHA*DT_ITER/DR**2

      DO ITER=1,NITER     
      DO I = 1, NR
        CC(I)=FACTOR*(I-1.0D0)/(2.0D0*I-1.0D0)
        DD(I)=FACTOR*(I-0.0D0)/(2.0D0*I-1.0D0)
      END DO
        
      DO I = 1, NR-1
        AIM1(I) = -CC(I)
        AI(I) = 1.0D0 + FACTOR
        AIP1(I) = -DD(I)
        TNEW(I) = WTEMP(I)
      END DO

      AIM1(NR) = -CC(NR)
      AI(NR) = 1.0D0 + CC(NR)
      AIP1(NR) = -DD(NR)
      TNEW(NR) = WTEMP(NR) + DD(NR)*WFLUXIN*DR/WK

C      AIM1(NR) = -1.0
C      AI(NR) = 1.0D0
C      AIP1(NR) = 0.0
C      TNEW(NR) = WFLUXIN*DR/WK
C     
C*** NOW PERFORM AN L-U FACTORIZATION OF THIS MATRIX (see atkinson p.455)
C    NOTE: MATRIX IS DIAGONALLY DOMINANT SO WE DON'T HAVE TO PIVOT

C*** note we do the following in case a(1) is not 1

      AIP1(1) = AIP1(1) / AI(1)
      DO I = 2, NX - 1
        AI(I) = AI(I) - AIM1(I) * AIP1(I-1)
        AIP1(I) = AIP1(I) / AI(I)
      END DO
      AI(NX) = AI(NX) - AIM1(NX) * AIP1(NX-1)

C*** NOW CONSTRUCT GUESS AT NEW TEMPERATURE PROFILE

C*** FORWARD SUBSTITION

      TNEW(1) = TNEW(1) / AI(1)
      DO I = 2, NX
        TNEW(I) = (TNEW(I)-AIM1(I)*TNEW(I-1)) / AI(I)
      END DO

C*** BACKWARD SUBSTITION

      DO I = NX - 1, 1, -1
        TNEW(I) = TNEW(I) - AIP1(I) * TNEW(I+1)
      END DO

      DO I = 1, NX
        WTEMP(I) = TNEW(I)
      END DO
      end do
      RETURN
      END
      subroutine get_flux(t,temp_cable,temp_amb,temp_shroud,flux_out)
      
      real*8, intent(in) :: t,temp_cable,temp_amb
      real*8, intent(out) :: flux_out,temp_shroud
      
      real*8 :: factor, factor2, sigma, temp_gas
      
      sigma = 5.67/10.0**8

      if(t>=0.0.and.t<=70.0)then
        factor = (t-0.0)/70.0
        factor2 = ((t-0.0)*210.0 + (70.0-t)*24.0)/70.0
c      else if(t>70.0.and.t<=820.0)then
      else if(t>70.0)then
        factor = 1.0
        factor2 = 210.0
c      else if(t>820.0.and.t<=1240.0)then
c        factor = ((t-820.0)*0.62 + (1240.0-t)*1.0)/(1240.0-820.0)
c        factor2 = ((t-820.0)*150.0 + (1240.0-t)*210.0)/(1240.0-820.0)
c      else if(t>1240.0)then
c        factor = 0.62
c        factor2 = 150.0
      else
        factor = 0.0
        factor2 = 24.0
      endif
      
      temp_shroud = 273.0 + 24.0*(1.0-factor)+480.0*factor
      temp_gas = factor2 + 273.0
      flux_out = .95*sigma*(temp_shroud**4-temp_cable**4)
c      flux_out = flux_out + 10*(temp_shroud - temp_cable)
      
      end subroutine get_flux      
      
