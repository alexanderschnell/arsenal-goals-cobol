//GOALSTAT JOB (ACCT),'ARSENAL GOALS',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID
//*------------------------------------------------------------------*
//* GOALSTAT - ARSENAL PREMIER LEAGUE GOAL REPORT (2025-26)          *
//*                                                                  *
//* ILLUSTRATIVE z/OS JCL: SHOWS HOW THE PROGRAM WOULD BE COMPILED   *
//* AND RUN ON A MAINFRAME. THE DD NAMES MATCH THE ASSIGN NAMES IN   *
//* THE PROGRAM, WHICH run.ps1 / run.sh MAP TO LOCAL FILES THROUGH   *
//* DD_ ENVIRONMENT VARIABLES WHEN RUNNING UNDER GNUCOBOL.           *
//*                                                                  *
//* REPLACE HLQ WITH YOUR OWN HIGH-LEVEL QUALIFIER.                  *
//*------------------------------------------------------------------*
//         SET HLQ=HLQ
//*
//*------------------------------------------------------------------*
//* STEP 1: COMPILE AND LINK-EDIT (IBM ENTERPRISE COBOL PROC)        *
//*------------------------------------------------------------------*
//COMPILE  EXEC IGYWCL,PARM.COBOL='LIB,APOST'
//COBOL.SYSIN   DD DSN=&HLQ..ARSENAL.SOURCE(GOALSTAT),DISP=SHR
//COBOL.SYSLIB  DD DSN=&HLQ..ARSENAL.COPYLIB,DISP=SHR
//LKED.SYSLMOD  DD DSN=&HLQ..ARSENAL.LOADLIB(GOALSTAT),DISP=SHR
//*
//*------------------------------------------------------------------*
//* STEP 2: RUN THE REPORT (ONLY IF THE COMPILE WAS CLEAN)           *
//*------------------------------------------------------------------*
//REPORT   EXEC PGM=GOALSTAT,COND=(4,LT,COMPILE.LKED)
//STEPLIB  DD DSN=&HLQ..ARSENAL.LOADLIB,DISP=SHR
//MATCHES  DD DSN=&HLQ..ARSENAL.MATCHES.D2526,DISP=SHR
//GOALS    DD DSN=&HLQ..ARSENAL.GOALS.D2526,DISP=SHR
//SORTWK1  DD UNIT=SYSDA,SPACE=(CYL,(1,1))
//SYSOUT   DD SYSOUT=*,DCB=(RECFM=FB,LRECL=132)
//SYSIN    DD *
* SAKAAWAY - BUKAYO SAKA'S AWAY GOALS
PLAYER=SAKA
VENUE=A
/*
//
