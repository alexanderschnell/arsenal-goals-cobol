//ARSCL    PROC HLQ=,MEMBER=,
//             COBLIB='IGY.V6R4M0.SIGYCOMP',
//             LEPFX='CEE'
//*------------------------------------------------------------------*
//* ARSCL - COMPILE AND LINK-EDIT ONE COBOL PROGRAM                  *
//*                                                                  *
//* PARAMETERS                                                       *
//*   HLQ=     HIGH-LEVEL QUALIFIER OF THE ARSENAL LIBRARIES (REQ'D) *
//*   MEMBER=  PROGRAM NAME IN HLQ.ARSENAL.SOURCE          (REQ'D)   *
//*   COBLIB=  ENTERPRISE COBOL COMPILER LIBRARY. THE DEFAULT IS     *
//*            V6.4; YOUR SITE MAY USE A DIFFERENT NAME.             *
//*   LEPFX=   LANGUAGE ENVIRONMENT PREFIX             (DEFAULT CEE) *
//*                                                                  *
//* STEPS                                                            *
//*   COBOL  - COMPILER (IGYCRCTL): SOURCE + COPYBOOKS -> OBJECT     *
//*            CODE IN A TEMPORARY DATA SET (&&OBJECT).              *
//*   LKED   - BINDER (IEWBLINK): OBJECT CODE + LANGUAGE ENVIRONMENT *
//*            RUNTIME -> LOAD MODULE IN HLQ.ARSENAL.LOADLIB.        *
//*            SKIPPED IF THE COMPILE ENDED WITH RC > 4.             *
//*------------------------------------------------------------------*
//*
//*------------------------------------------------------------------*
//* COMPILE                                                          *
//*------------------------------------------------------------------*
//COBOL    EXEC PGM=IGYCRCTL,REGION=0M
//STEPLIB  DD DSN=&COBLIB,DISP=SHR
//SYSIN    DD DSN=&HLQ..ARSENAL.SOURCE(&MEMBER),DISP=SHR
//SYSLIB   DD DSN=&HLQ..ARSENAL.COPYLIB,DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSLIN   DD DSN=&&OBJECT,DISP=(NEW,PASS),SPACE=(TRK,(5,5))
//* COMPILER WORK FILES (ENTERPRISE COBOL 6 USES SYSUT1-SYSUT15)
//SYSMDECK DD SPACE=(CYL,(1,1))
//SYSUT1   DD SPACE=(CYL,(1,1))
//SYSUT2   DD SPACE=(CYL,(1,1))
//SYSUT3   DD SPACE=(CYL,(1,1))
//SYSUT4   DD SPACE=(CYL,(1,1))
//SYSUT5   DD SPACE=(CYL,(1,1))
//SYSUT6   DD SPACE=(CYL,(1,1))
//SYSUT7   DD SPACE=(CYL,(1,1))
//SYSUT8   DD SPACE=(CYL,(1,1))
//SYSUT9   DD SPACE=(CYL,(1,1))
//SYSUT10  DD SPACE=(CYL,(1,1))
//SYSUT11  DD SPACE=(CYL,(1,1))
//SYSUT12  DD SPACE=(CYL,(1,1))
//SYSUT13  DD SPACE=(CYL,(1,1))
//SYSUT14  DD SPACE=(CYL,(1,1))
//SYSUT15  DD SPACE=(CYL,(1,1))
//*
//*------------------------------------------------------------------*
//* LINK-EDIT (BIND) - ONLY IF THE COMPILE WAS CLEAN (RC 0 OR 4)     *
//*------------------------------------------------------------------*
//LKED     EXEC PGM=IEWBLINK,COND=(4,LT,COBOL),
//             PARM='LIST,MAP,XREF',REGION=0M
//SYSLIB   DD DSN=&LEPFX..SCEELKED,DISP=SHR
//SYSLIN   DD DSN=&&OBJECT,DISP=(OLD,DELETE)
//SYSLMOD  DD DSN=&HLQ..ARSENAL.LOADLIB(&MEMBER),DISP=SHR
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD SPACE=(CYL,(1,1))
//         PEND
