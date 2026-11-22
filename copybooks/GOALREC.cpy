      *----------------------------------------------------------------*
      * GOALREC - ONE ARSENAL PREMIER LEAGUE GOAL           LRECL=100 *
      *                                                                *
      * POS  LEN  FIELD          NOTES                                 *
      *   1    7  GL-SEASON      E.G. 2025-26                          *
      *   8    2  GL-ROUND       MATCHWEEK 01-38 (KEY TO MATCHREC)     *
      *  10    8  GL-DATE        YYYYMMDD                              *
      *  18   24  GL-OPPONENT    UPPER CASE, NO ACCENTS                *
      *  42    1  GL-VENUE       H = HOME, A = AWAY                    *
      *  43   20  GL-SCORER      SURNAME, OR 'OWN GOAL'                *
      *  63    3  GL-MINUTE      MATCH MINUTE (90 FOR 90+N)            *
      *  66    2  GL-ADDED       STOPPAGE-TIME MINUTE, 00 IF NONE      *
      *  68    1  GL-TYPE        N = NON-PENALTY, P = PENALTY,         *
      *                          O = OWN GOAL BY AN OPPONENT           *
      *  69   20  GL-OG-PLAYER   OPPONENT WHO SCORED THE OWN GOAL      *
      *  89   12  FILLER         RESERVED                              *
      *----------------------------------------------------------------*
       01  GOAL-REC.
           05  GL-SEASON             PIC X(07).
           05  GL-ROUND              PIC 9(02).
           05  GL-DATE               PIC 9(08).
           05  GL-OPPONENT           PIC X(24).
           05  GL-VENUE              PIC X(01).
               88  GL-HOME                     VALUE 'H'.
               88  GL-AWAY                     VALUE 'A'.
               88  GL-VALID-VENUE              VALUE 'H' 'A'.
           05  GL-SCORER             PIC X(20).
           05  GL-MINUTE             PIC 9(03).
           05  GL-ADDED              PIC 9(02).
           05  GL-TYPE               PIC X(01).
               88  GL-NON-PENALTY              VALUE 'N'.
               88  GL-PENALTY                  VALUE 'P'.
               88  GL-OWN-GOAL                 VALUE 'O'.
               88  GL-VALID-TYPE               VALUE 'N' 'P' 'O'.
           05  GL-OG-PLAYER          PIC X(20).
           05  FILLER                PIC X(12).
