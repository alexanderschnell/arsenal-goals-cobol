      *----------------------------------------------------------------*
      * MATCHREC - ONE ARSENAL PREMIER LEAGUE MATCH         LRECL=080 *
      *                                                                *
      * POS  LEN  FIELD          NOTES                                 *
      *   1    7  MT-SEASON      E.G. 2025-26                          *
      *   8    2  MT-ROUND       MATCHWEEK 01-38                       *
      *  10    8  MT-DATE        YYYYMMDD                              *
      *  18   24  MT-OPPONENT    UPPER CASE, NO ACCENTS                *
      *  42    1  MT-VENUE       H = HOME, A = AWAY                    *
      *  43    2  MT-GF          GOALS FOR ARSENAL                     *
      *  45    2  MT-GA          GOALS AGAINST                         *
      *  47    1  MT-RESULT      W / D / L                             *
      *  48   33  FILLER         RESERVED                              *
      *----------------------------------------------------------------*
       01  MATCH-REC.
           05  MT-SEASON             PIC X(07).
           05  MT-ROUND              PIC 9(02).
           05  MT-DATE               PIC 9(08).
           05  MT-OPPONENT           PIC X(24).
           05  MT-VENUE              PIC X(01).
               88  MT-HOME                     VALUE 'H'.
               88  MT-AWAY                     VALUE 'A'.
               88  MT-VALID-VENUE              VALUE 'H' 'A'.
           05  MT-GF                 PIC 9(02).
           05  MT-GA                 PIC 9(02).
           05  MT-RESULT             PIC X(01).
               88  MT-WIN                      VALUE 'W'.
               88  MT-DRAW                     VALUE 'D'.
               88  MT-LOSS                     VALUE 'L'.
           05  FILLER                PIC X(33).
