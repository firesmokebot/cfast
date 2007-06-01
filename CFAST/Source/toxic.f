      SUBROUTINE TOXIC(DELTT)
C
C--------------------------------- NIST/BFRL ---------------------------------
C
C     Routine:     TOXIC
C
C     Source File: TOXIC.SOR
C
C     Functional Class:  CFAST
C
C     Description:  This routine is used tto calculate species concentrations
C                   (ppm), mass density (kg/m^3), opacity (1/m), 
C                   CT (g-min/m^3), heat flux to target on floor (W)
C
C     Arguments: DELTT  length of the latest time step (s)
C
C     Revision History:
C        5/26/1987 by WWJ, change ct calculation to g-m/m^3
C        11/20/1987 by WWJ, use sum of species to determine total mass used
C                           to calculate mass and volume fractions
C        3/30/1989 by WWJ, fix "ontarget" s*(t-ta)**4->s*(t**4-ta**4)
C        9/12/1989 by WWJ, set ontarget to 0 if < 1
C        11/20/92 by RDP, eliminated MINMAS as the check for minimum molar
C                 count used to calculate molar fraction.  Changed to
C                 1/Avagadro' number so you can't have less than 1 molecule
C                 of gas in a layer.
C	    02/15/02 by WWJ The smoke conversion factor has been changed from 3500 to 3817 
C                  to reflect the new value as reported by Mulholland in Fire and Materials, 24, 227(2000)

C---------------------------- ALL RIGHTS RESERVED ----------------------------

      include "precis.fi"
      include "cfast.fi"
      include "params.fi"
      include "cenviro.fi"
C
      DIMENSION AWEIGH(NS), AIR(2), V(2)
      LOGICAL PPMCAL(NS)
C
C     AWEIGH'S ARE MOLAR WEIGHTS OF THE SPECIES, AVAGAD IS THE RECIPROCAL
C     OF AVAGADRO'S NUMBER (SO YOU CAN'T HAVE LESS THAN AN ATOM OF A SPECIES
C
#ifdef pp_double
      DATA AWEIGH, AWEIGH7 /28.D0, 32.D0, 44.D0, 28.D0, 27.D0, 37.D0, 
     +    12.D0, 18.D0, 12.D0, 0.D0, 12.D0/
      DATA AVAGAD /1.66D-24/
#else
      DATA AWEIGH, AWEIGH7 /28., 32., 44., 28., 27., 37., 12., 18., 12.,
     +    0., 12./
      DATA AVAGAD /1.66E-24/
#endif
      DATA PPMCAL /3 * .FALSE., 3 * .TRUE., 4 * .FALSE./
      AWEIGH(7) = AWEIGH7 * (1.0D0+HCRATT)
      DO 90 I = 1, NM1
C
        V(UPPER) = ZZVOL(I,UPPER)
        V(LOWER) = ZZVOL(I,LOWER)
        DO 20 K = UPPER, LOWER
          AIR(K) = 0.0D0
          DO 10 LSP = 1, 9
            AIR(K) = AIR(K) + ZZGSPEC(I,K,LSP) / AWEIGH(LSP)
   10     CONTINUE
          AIR(K) = MAX(AVAGAD,AIR(K))
   20   CONTINUE
C
C     CALCLUATE THE MASS DENSITY IN KG/M^3
C
        DO 40 LSP = 1, NS
          IF (ACTIVS(LSP)) THEN
            DO 30 K = UPPER, LOWER
              PPMDV(K,I,LSP) = ZZGSPEC(I,K,LSP) / V(K)
   30       CONTINUE
          END IF
   40   CONTINUE
C
C     NOW CALCULATE THE MOLAR DENSITY
C
        DO 60 LSP = 1, 8
          IF (ACTIVS(LSP)) THEN
            DO 50 K = UPPER, LOWER
              IF (PPMCAL(LSP)) THEN
                TOXICT(I,K,LSP) = 1.D+6 * ZZGSPEC(I,K,LSP) / (AIR(K)*
     +              AWEIGH(LSP))
              ELSE
                TOXICT(I,K,LSP) = 100.D0 * ZZGSPEC(I,K,LSP) / (AIR(K)*
     +              AWEIGH(LSP))
              END IF
   50       CONTINUE
          END IF
   60   CONTINUE
C
C     OPACITY IS CALCULATED FROM SEDER'S WORK
C	Note: this value was change 2/15/2 from 3500 to 3817 to reflect the new value as reported yb
C     Mulholland in Fire and Materials, 24, 2227(2000)
C
        LSP = 9
        IF (ACTIVS(LSP)) THEN
          DO 70 K = UPPER, LOWER
            TOXICT(I,K,LSP) = PPMDV(K,I,LSP) * 3817.0D0
   70     CONTINUE
        END IF
C
C     CT IS THE TIME INTEGRATION OF SPECIES 10, "TOTAL TOXIC JUNK"
C
        LSP = 10
        IF (ACTIVS(LSP)) THEN
          DO 80 K = UPPER, LOWER
            TOXICT(I,K,LSP) = TOXICT(I,K,LSP) + PPMDV(K,I,LSP) * 
     +          1000.0D0 * DELTT / 60.0D0
   80     CONTINUE
        END IF
   90 CONTINUE
C
C     ONTARGET IS THE RADIATION RECEIVED ON A TARGET ON THE FLOOR
C
	DO 100 I = 1, NM1
        ONTARGET(I) = SIGM * (ZZTEMP(I,UPPER)**4-TAMB(I)**4)
        IF (ONTARGET(I).LT.1.0D0) ONTARGET(I) = 0.0D0
  100 CONTINUE
      RETURN
      END
