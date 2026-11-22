//ARSRUN   PROC HLQ=,SEASON=D2526
//*------------------------------------------------------------------*
//* ARSRUN - RUN GOALSTAT, THE ARSENAL GOAL REPORT                   *
//*                                                                  *
//* PARAMETERS                                                       *
//*   HLQ=     HIGH-LEVEL QUALIFIER OF THE ARSENAL LIBRARIES (REQ'D) *
//*   SEASON=  SUFFIX OF THE SEASON DATA SETS  (DEFAULT D2526 =      *
//*            2025-26). LOAD ANOTHER SEASON AS ...MATCHES.D2627 AND *
//*            ...GOALS.D2627, THEN RUN WITH SEASON=D2627.           *
//*                                                                  *
//* THE CALLER SUPPLIES THE QUERY BY OVERRIDING SYSIN IN STEP RUN:   *
//*   //QUERY    EXEC ARSRUN,HLQ=MYID                                *
//*   //RUN.SYSIN DD *                                               *
//*   PLAYER=SAKA                                                    *
//*   /*                                                             *
//* WITHOUT AN OVERRIDE, SYSIN IS EMPTY AND EVERY GOAL IS REPORTED.  *
//*                                                                  *
//* DD NAMES MATCH THE ASSIGN NAMES IN THE PROGRAM:                  *
//*   MATCHES  MATCH RECORDS (MATCHREC, LRECL=80)                    *
//*   GOALS    GOAL RECORDS  (GOALREC,  LRECL=100)                   *
//*   SYSIN    CONTROL CARDS (LRECL=80)                              *
//*   RPTOUT   THE REPORT    (LRECL=132)                             *
//*   SYSOUT   DISPLAY MESSAGES FROM THE PROGRAM                     *
//*   SORTMSG  DFSORT MESSAGES (SORT WORK SPACE IS ALLOCATED BY      *
//*            DFSORT ITSELF, SO NO SORTWKNN DDS ARE NEEDED)         *
//*------------------------------------------------------------------*
//RUN      EXEC PGM=GOALSTAT
//STEPLIB  DD DSN=&HLQ..ARSENAL.LOADLIB,DISP=SHR
//MATCHES  DD DSN=&HLQ..ARSENAL.MATCHES.&SEASON,DISP=SHR
//GOALS    DD DSN=&HLQ..ARSENAL.GOALS.&SEASON,DISP=SHR
//SYSIN    DD DUMMY,RECFM=FB,LRECL=80,BLKSIZE=80
//RPTOUT   DD SYSOUT=*,RECFM=FB,LRECL=132
//SYSOUT   DD SYSOUT=*
//SORTMSG  DD SYSOUT=*
//         PEND
