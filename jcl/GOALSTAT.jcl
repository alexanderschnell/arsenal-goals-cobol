//GOALSTAT JOB (ACCT),'ARSENAL GOALS',CLASS=A,MSGCLASS=X,
//             MSGLEVEL=(1,1),NOTIFY=&SYSUID
//*------------------------------------------------------------------*
//* GOALSTAT - BUILD AND RUN THE ARSENAL 2025-26 GOAL REPORT         *
//*                                                                  *
//* BEFORE SUBMITTING: CHANGE EVERY "YOURID" TO YOUR HIGH-LEVEL      *
//* QUALIFIER. ONE-TIME SETUP IS JOB ARSALLOC (SEE THE README).      *
//*                                                                  *
//* THE PLUMBING LIVES IN TWO PROCS IN YOURID.ARSENAL.PROCLIB, THE   *
//* WAY MOST SHOPS WRAP THEIR BUILDS IN IN-HOUSE PROCS:              *
//*   ARSCL   COMPILE AND LINK-EDIT A PROGRAM                        *
//*   ARSRUN  RUN THE REPORT WITH ALL ITS DATA SETS                  *
//* SO THIS JOB ONLY SAYS WHAT IS SPECIFIC TO THIS RUN: WHICH        *
//* PROGRAM TO BUILD AND WHICH QUESTION TO ASK.                      *
//*------------------------------------------------------------------*
//         JCLLIB ORDER=YOURID.ARSENAL.PROCLIB
//         SET MYHLQ=YOURID
//*
//*------------------------------------------------------------------*
//* STEP 1: COMPILE AND LINK GOALSTAT INTO YOURID.ARSENAL.LOADLIB    *
//*------------------------------------------------------------------*
//BUILD    EXEC ARSCL,HLQ=&MYHLQ,MEMBER=GOALSTAT
//*
//*------------------------------------------------------------------*
//* STEP 2: RUN THE REPORT, ONLY IF BOTH BUILD STEPS ENDED WITH      *
//* RC 0 OR 4. A STEP THAT WAS SKIPPED NEVER PASSES AN RC TEST, SO A *
//* FAILED COMPILE (WHICH SKIPS LKED) ALSO SKIPS THE REPORT.         *
//*------------------------------------------------------------------*
//BUILDOK  IF (BUILD.COBOL.RC <= 4 AND BUILD.LKED.RC <= 4) THEN
//QUERY    EXEC ARSRUN,HLQ=&MYHLQ
//*        THE QUESTION: CONTROL CARDS FOR THIS RUN (SEE README)
//RUN.SYSIN DD *
* SAKAAWAY - BUKAYO SAKA'S AWAY GOALS
PLAYER=SAKA
VENUE=A
/*
//         ENDIF
