      *================================================================*
      * PROGRAM:  GOALSTAT                                             *
      * AUTHOR:   ALEXANDER SCHNELL                                    *
      * WRITTEN:  2026-11-22                                           *
      *                                                                *
      * PURPOSE:  QUERY AND REPORT ON ARSENAL PREMIER LEAGUE GOALS.    *
      *           1. READS FILTER CONTROL CARDS FROM SYSIN.            *
      *           2. LOADS THE MATCHES FILE AND BUILDS THE SEASON      *
      *              RECORD (OVERALL / HOME / AWAY).                   *
      *           3. VALIDATES EVERY GOAL RECORD, SELECTS THE ONES     *
      *              THAT MATCH THE FILTERS AND LISTS THEM.            *
      *           4. SUMMARISES THE SELECTION: TOP SCORERS (SORTED),   *
      *              GOAL TIMING, HOME/AWAY AND GOAL TYPE.             *
      *           5. RECONCILES GOAL RECORDS AGAINST THE MATCH SCORES  *
      *              ROUND BY ROUND (CONTROL TOTALS).                  *
      *                                                                *
      * FILES:    MATCHES  (IN)   MATCHREC LRECL=80                    *
      *           GOALS    (IN)   GOALREC  LRECL=100                   *
      *           SYSIN    (IN)   CONTROL CARDS, KEYWORD=VALUE         *
      *           SYSOUT   (OUT)  REPORT, 132 COLUMNS                  *
      *                                                                *
      * CONTROL CARDS (ALL OPTIONAL, COMBINED WITH AND):               *
      *           PLAYER=SAKA          SCORER SURNAME (EXACT)          *
      *           OPPONENT=TOTTENHAM   OPPONENT NAME (STARTS WITH)     *
      *           VENUE=H | A          HOME OR AWAY                    *
      *           TYPE=N | P | O       NON-PENALTY, PENALTY, OWN GOAL  *
      *           MINUTE=76-90         MATCH MINUTE RANGE (90+N = 90)  *
      *           ROUND=20-38          MATCHWEEK RANGE                 *
      *           STOPPAGE=Y | N       ONLY / NO STOPPAGE-TIME GOALS   *
      *           * IN COLUMN 1 MARKS A COMMENT CARD                   *
      *                                                                *
      * RETURN CODES:                                                  *
      *            0  NORMAL COMPLETION                                *
      *            4  WARNING - INVALID RECORDS WERE SKIPPED           *
      *            8  ERROR   - CONTROL TOTALS DO NOT RECONCILE        *
      *           12  SEVERE  - BAD CONTROL CARD OR FILE ERROR         *
      *================================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. GOALSTAT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MATCH-FILE   ASSIGN TO 'MATCHES'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-MATCH-STATUS.
           SELECT GOAL-FILE    ASSIGN TO 'GOALS'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-GOAL-STATUS.
           SELECT CARD-FILE    ASSIGN TO 'SYSIN'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-CARD-STATUS.
           SELECT REPORT-FILE  ASSIGN TO 'SYSOUT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-RPT-STATUS.
           SELECT SORT-FILE    ASSIGN TO 'SORTWK1'.

       DATA DIVISION.
       FILE SECTION.
       FD  MATCH-FILE.
           COPY MATCHREC.

       FD  GOAL-FILE.
           COPY GOALREC.

       FD  CARD-FILE.
       01  CARD-REC                  PIC X(80).

       FD  REPORT-FILE.
       01  REPORT-LINE               PIC X(132).

       SD  SORT-FILE.
       01  SORT-REC.
           05  SR-GOALS              PIC 9(03).
           05  SR-NAME               PIC X(20).

       WORKING-STORAGE SECTION.
      *----------------------------------------------------------------*
      * FILE STATUS, SWITCHES AND RETURN CODE                          *
      *----------------------------------------------------------------*
       01  WS-FILE-STATUSES.
           05  WS-MATCH-STATUS       PIC X(02).
           05  WS-GOAL-STATUS        PIC X(02).
           05  WS-CARD-STATUS        PIC X(02).
           05  WS-RPT-STATUS         PIC X(02).

       01  WS-SWITCHES.
           05  WS-EOF-SW             PIC X(01) VALUE 'N'.
               88  WS-EOF                      VALUE 'Y'.
               88  WS-NOT-EOF                  VALUE 'N'.
           05  WS-SORT-EOF-SW        PIC X(01) VALUE 'N'.
               88  WS-SORT-EOF                 VALUE 'Y'.
           05  WS-SELECT-SW          PIC X(01).
               88  WS-SELECTED                 VALUE 'Y'.
               88  WS-NOT-SELECTED             VALUE 'N'.
           05  WS-FOUND-SW           PIC X(01).
               88  WS-FOUND                    VALUE 'Y'.
           05  WS-RANGE-OK-SW        PIC X(01).
               88  WS-RANGE-OK                 VALUE 'Y'.

       01  WS-RETURN-CODE            PIC 9(04) VALUE 0.

      *----------------------------------------------------------------*
      * SELECTION FILTERS (FROM CONTROL CARDS)                         *
      *----------------------------------------------------------------*
       01  WS-FILTERS.
           05  WS-F-PLAYER           PIC X(20) VALUE SPACES.
           05  WS-F-OPPONENT         PIC X(24) VALUE SPACES.
           05  WS-F-OPP-LEN          PIC 9(02) VALUE 0.
           05  WS-F-VENUE            PIC X(01) VALUE SPACE.
           05  WS-F-TYPE             PIC X(01) VALUE SPACE.
           05  WS-F-STOPPAGE         PIC X(01) VALUE SPACE.
           05  WS-F-MIN-FROM         PIC 9(03) VALUE 0.
           05  WS-F-MIN-TO           PIC 9(03) VALUE 999.
           05  WS-F-RND-FROM         PIC 9(02) VALUE 1.
           05  WS-F-RND-TO           PIC 9(02) VALUE 38.

      *----------------------------------------------------------------*
      * CONTROL CARD PARSING                                           *
      *----------------------------------------------------------------*
       01  WS-CARD-WORK.
           05  WS-CARD               PIC X(80).
           05  WS-KEY                PIC X(20).
           05  WS-VALUE              PIC X(60).
           05  WS-RANGE-LO           PIC X(10).
           05  WS-RANGE-HI           PIC X(10).
           05  WS-NUM-LO             PIC 9(03).
           05  WS-NUM-HI             PIC 9(03).
           05  WS-CARD-COUNT         PIC 9(03) VALUE 0.
           05  WS-CARD-ERRORS        PIC 9(03) VALUE 0.

       01  WS-CARD-LIST.
           05  WS-CARD-ENTRY         PIC X(80) OCCURS 20 TIMES.

       01  WS-CARD-ERROR-LIST.
           05  WS-CARD-ERROR-ENTRY   PIC X(80) OCCURS 10 TIMES.

      *----------------------------------------------------------------*
      * COUNTERS                                                       *
      *----------------------------------------------------------------*
       01  WS-COUNTERS.
           05  WS-MATCHES-READ       PIC 9(05) VALUE 0.
           05  WS-MATCHES-REJECTED   PIC 9(05) VALUE 0.
           05  WS-GOALS-READ         PIC 9(05) VALUE 0.
           05  WS-GOALS-VALID        PIC 9(05) VALUE 0.
           05  WS-GOALS-REJECTED     PIC 9(05) VALUE 0.
           05  WS-GOALS-SELECTED     PIC 9(05) VALUE 0.
           05  WS-SEL-HOME           PIC 9(05) VALUE 0.
           05  WS-SEL-AWAY           PIC 9(05) VALUE 0.
           05  WS-SEL-NON-PEN        PIC 9(05) VALUE 0.
           05  WS-SEL-PEN            PIC 9(05) VALUE 0.
           05  WS-SEL-OG             PIC 9(05) VALUE 0.
           05  WS-SEL-STOPPAGE       PIC 9(05) VALUE 0.
           05  WS-MISMATCHES         PIC 9(03) VALUE 0.

      *----------------------------------------------------------------*
      * SEASON RECORD: 1 = OVERALL, 2 = HOME, 3 = AWAY                 *
      *----------------------------------------------------------------*
       01  WS-RECORD-TABLE.
           05  WS-REC                OCCURS 3 TIMES.
               10  WS-R-P            PIC 9(03).
               10  WS-R-W            PIC 9(03).
               10  WS-R-D            PIC 9(03).
               10  WS-R-L            PIC 9(03).
               10  WS-R-GF           PIC 9(03).
               10  WS-R-GA           PIC 9(03).

       01  WS-RECORD-LABELS.
           05  FILLER                PIC X(08) VALUE 'OVERALL '.
           05  FILLER                PIC X(08) VALUE 'HOME    '.
           05  FILLER                PIC X(08) VALUE 'AWAY    '.
       01  WS-RECORD-LABEL-TBL REDEFINES WS-RECORD-LABELS.
           05  WS-RECORD-LABEL       PIC X(08) OCCURS 3 TIMES.

      *----------------------------------------------------------------*
      * ROUND TABLE: MATCH DETAILS AND GOALS COUNTED, FOR CROSS-CHECKS *
      *----------------------------------------------------------------*
       01  WS-ROUND-TABLE.
           05  WS-RND                OCCURS 38 TIMES.
               10  WS-RND-SEEN       PIC X(01).
               10  WS-RND-DATE       PIC 9(08).
               10  WS-RND-OPPONENT   PIC X(24).
               10  WS-RND-VENUE      PIC X(01).
               10  WS-RND-MATCH-GF   PIC 9(02).
               10  WS-RND-GOAL-CNT   PIC 9(02).

      *----------------------------------------------------------------*
      * SCORER TABLE (SELECTED GOALS)                                  *
      *----------------------------------------------------------------*
       01  WS-SCORER-TABLE.
           05  WS-PLAYER-COUNT       PIC 9(03) VALUE 0.
           05  WS-PLAYER             OCCURS 50 TIMES.
               10  WS-PL-NAME        PIC X(20).
               10  WS-PL-GOALS       PIC 9(03).

      *----------------------------------------------------------------*
      * GOAL TIMING BANDS (SELECTED GOALS)                             *
      *----------------------------------------------------------------*
       01  WS-BAND-LABELS.
           05  FILLER                PIC X(06) VALUE '01-15 '.
           05  FILLER                PIC X(06) VALUE '16-30 '.
           05  FILLER                PIC X(06) VALUE '31-45 '.
           05  FILLER                PIC X(06) VALUE '45+   '.
           05  FILLER                PIC X(06) VALUE '46-60 '.
           05  FILLER                PIC X(06) VALUE '61-75 '.
           05  FILLER                PIC X(06) VALUE '76-90 '.
           05  FILLER                PIC X(06) VALUE '90+   '.
       01  WS-BAND-LABEL-TBL REDEFINES WS-BAND-LABELS.
           05  WS-BAND-LABEL         PIC X(06) OCCURS 8 TIMES.

       01  WS-BAND-COUNTS.
           05  WS-BAND-COUNT         PIC 9(03) OCCURS 8 TIMES.

      *----------------------------------------------------------------*
      * REJECTED RECORDS                                               *
      *----------------------------------------------------------------*
       01  WS-REJECT-REASON          PIC X(40).
       01  WS-REJECT-LIST.
           05  WS-REJECT-ENTRY       OCCURS 20 TIMES.
               10  WS-REJ-FILE       PIC X(08).
               10  WS-REJ-RECNO      PIC 9(05).
               10  WS-REJ-REASON     PIC X(40).
       01  WS-REJECT-COUNT           PIC 9(03) VALUE 0.
       01  WS-REJECT-FILE            PIC X(08).

      *----------------------------------------------------------------*
      * WORK FIELDS                                                    *
      *----------------------------------------------------------------*
       01  WS-WORK.
           05  WS-IDX                PIC 9(03).
           05  WS-T                  PIC 9(01).
           05  WS-BAND-IX            PIC 9(01).
           05  WS-RANK               PIC 9(03).
           05  WS-BAR-LEN            PIC 9(03).
           05  WS-BAR-FULL           PIC X(40) VALUE ALL '#'.
           05  WS-MIN-Z              PIC ZZ9.
           05  WS-ADD-Z              PIC Z9.
           05  WS-COUNT-Z            PIC ZZZZ9.
           05  WS-RC-Z               PIC ZZZ9.
           05  WS-DATE-N             PIC 9(08).
           05  WS-DATE-X REDEFINES WS-DATE-N.
               10  WS-DATE-YYYY      PIC X(04).
               10  WS-DATE-MM        PIC X(02).
               10  WS-DATE-DD        PIC X(02).
           05  WS-DATE-DISP          PIC X(10).
           05  WS-CURRENT-DATE       PIC X(21).

       01  WS-LINE                   PIC X(132) VALUE SPACES.

      *----------------------------------------------------------------*
      * REPORT LINES                                                   *
      *----------------------------------------------------------------*
       01  WS-RULE                   PIC X(100) VALUE ALL '-'.

       01  WS-SUMMARY-HEAD.
           05  FILLER                PIC X(12) VALUE SPACES.
           05  FILLER                PIC X(40) VALUE
               '  P    W    D    L   GF   GA    GD   PTS'.

       01  WS-SUMMARY-LINE.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-LABEL              PIC X(08).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-P                  PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-W                  PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-D                  PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-L                  PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-GF                 PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-GA                 PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-GD                 PIC +++9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SL-PTS                PIC ZZZ9.

       01  WS-DETAIL-HEAD.
           05  FILLER                PIC X(50) VALUE
               '  RND  DATE        OPPONENT                  H/A'.
           05  FILLER                PIC X(40) VALUE
               ' SCORER                MIN    TYPE'.

       01  WS-DETAIL-LINE.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-ROUND              PIC Z9.
           05  FILLER                PIC X(03) VALUE SPACES.
           05  DL-DATE               PIC X(10).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-OPPONENT           PIC X(24).
           05  FILLER                PIC X(03) VALUE SPACES.
           05  DL-VENUE              PIC X(01).
           05  FILLER                PIC X(04) VALUE SPACES.
           05  DL-SCORER             PIC X(20).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  DL-MINUTE             PIC X(06).
           05  FILLER                PIC X(01) VALUE SPACES.
           05  DL-TYPE               PIC X(30).

       01  WS-SCORER-LINE.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SC-RANK               PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SC-NAME               PIC X(20).
           05  SC-GOALS              PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  SC-BAR                PIC X(40).

       01  WS-BAND-LINE.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  BL-LABEL              PIC X(06).
           05  FILLER                PIC X(02) VALUE SPACES.
           05  BL-COUNT              PIC ZZ9.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  BL-BAR                PIC X(40).

       01  WS-STAT-LINE.
           05  FILLER                PIC X(02) VALUE SPACES.
           05  ST-LABEL              PIC X(30).
           05  ST-VALUE              PIC ZZZZ9.

       PROCEDURE DIVISION.
      *================================================================*
       0000-MAIN.
      *================================================================*
           PERFORM 1000-INITIALIZE
           PERFORM 2000-READ-CONTROL-CARDS
           PERFORM 7100-WRITE-HEADER
           PERFORM 7200-WRITE-CONTROL-CARDS

           IF WS-RETURN-CODE < 12
               PERFORM 3000-LOAD-MATCHES
           END-IF
           IF WS-RETURN-CODE < 12
               PERFORM 7300-WRITE-SEASON-SUMMARY
               PERFORM 4000-PROCESS-GOALS
           END-IF
           IF WS-RETURN-CODE < 12
               PERFORM 5000-WRITE-SCORERS
               PERFORM 6000-WRITE-TIMING
               PERFORM 6100-WRITE-SPLITS
               PERFORM 6500-RECONCILE
           END-IF

           PERFORM 8000-FINISH
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *================================================================*
       1000-INITIALIZE.
      *================================================================*
           INITIALIZE WS-RECORD-TABLE
                      WS-ROUND-TABLE
                      WS-BAND-COUNTS
                      WS-CARD-LIST
                      WS-CARD-ERROR-LIST
           MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
           OPEN OUTPUT REPORT-FILE
           IF WS-RPT-STATUS NOT = '00'
               DISPLAY 'GOALSTAT: CANNOT OPEN SYSOUT, STATUS '
                       WS-RPT-STATUS
               MOVE 12 TO RETURN-CODE
               STOP RUN
           END-IF.

      *================================================================*
       2000-READ-CONTROL-CARDS.
      *    NO SYSIN (FILE NOT FOUND) MEANS NO FILTERS: SELECT ALL.     *
      *================================================================*
           OPEN INPUT CARD-FILE
           IF WS-CARD-STATUS NOT = '00'
               EXIT PARAGRAPH
           END-IF
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ CARD-FILE
                   AT END
                       SET WS-EOF TO TRUE
                   NOT AT END
                       PERFORM 2100-PARSE-CARD
               END-READ
           END-PERFORM
           CLOSE CARD-FILE.

      *----------------------------------------------------------------*
       2100-PARSE-CARD.
      *----------------------------------------------------------------*
           IF CARD-REC = SPACES OR CARD-REC(1:1) = '*'
               EXIT PARAGRAPH
           END-IF
           ADD 1 TO WS-CARD-COUNT
           IF WS-CARD-COUNT <= 20
               MOVE CARD-REC TO WS-CARD-ENTRY(WS-CARD-COUNT)
           END-IF

           MOVE FUNCTION UPPER-CASE(CARD-REC) TO WS-CARD
           MOVE SPACES TO WS-KEY WS-VALUE
           UNSTRING WS-CARD DELIMITED BY '='
               INTO WS-KEY WS-VALUE
           END-UNSTRING
           MOVE FUNCTION TRIM(WS-KEY)   TO WS-KEY
           MOVE FUNCTION TRIM(WS-VALUE) TO WS-VALUE

           EVALUATE WS-KEY
               WHEN 'PLAYER'
                   IF WS-VALUE = SPACES
                       PERFORM 2900-CARD-ERROR
                   ELSE
                       MOVE WS-VALUE TO WS-F-PLAYER
                   END-IF
               WHEN 'OPPONENT'
                   IF WS-VALUE = SPACES
                       PERFORM 2900-CARD-ERROR
                   ELSE
                       MOVE WS-VALUE TO WS-F-OPPONENT
                       COMPUTE WS-F-OPP-LEN = FUNCTION LENGTH(
                           FUNCTION TRIM(WS-F-OPPONENT))
                   END-IF
               WHEN 'VENUE'
                   IF WS-VALUE = 'H' OR 'A'
                       MOVE WS-VALUE TO WS-F-VENUE
                   ELSE
                       PERFORM 2900-CARD-ERROR
                   END-IF
               WHEN 'TYPE'
                   IF WS-VALUE = 'N' OR 'P' OR 'O'
                       MOVE WS-VALUE TO WS-F-TYPE
                   ELSE
                       PERFORM 2900-CARD-ERROR
                   END-IF
               WHEN 'STOPPAGE'
                   IF WS-VALUE = 'Y' OR 'N'
                       MOVE WS-VALUE TO WS-F-STOPPAGE
                   ELSE
                       PERFORM 2900-CARD-ERROR
                   END-IF
               WHEN 'MINUTE'
                   PERFORM 2200-PARSE-RANGE
                   IF WS-RANGE-OK
                       MOVE WS-NUM-LO TO WS-F-MIN-FROM
                       MOVE WS-NUM-HI TO WS-F-MIN-TO
                   ELSE
                       PERFORM 2900-CARD-ERROR
                   END-IF
               WHEN 'ROUND'
                   PERFORM 2200-PARSE-RANGE
                   IF WS-RANGE-OK AND WS-NUM-LO >= 1
                                  AND WS-NUM-HI <= 38
                       MOVE WS-NUM-LO TO WS-F-RND-FROM
                       MOVE WS-NUM-HI TO WS-F-RND-TO
                   ELSE
                       PERFORM 2900-CARD-ERROR
                   END-IF
               WHEN OTHER
                   PERFORM 2900-CARD-ERROR
           END-EVALUATE.

      *----------------------------------------------------------------*
       2200-PARSE-RANGE.
      *    ACCEPTS 'N' OR 'N-M'. SETS WS-NUM-LO / WS-NUM-HI.           *
      *----------------------------------------------------------------*
           MOVE 'N' TO WS-RANGE-OK-SW
           MOVE SPACES TO WS-RANGE-LO WS-RANGE-HI
           UNSTRING WS-VALUE DELIMITED BY '-'
               INTO WS-RANGE-LO WS-RANGE-HI
           END-UNSTRING
           IF WS-RANGE-HI = SPACES
               MOVE WS-RANGE-LO TO WS-RANGE-HI
           END-IF
           IF WS-RANGE-LO = SPACES
               EXIT PARAGRAPH
           END-IF
           IF FUNCTION TEST-NUMVAL(WS-RANGE-LO) = 0
              AND FUNCTION TEST-NUMVAL(WS-RANGE-HI) = 0
               COMPUTE WS-NUM-LO = FUNCTION NUMVAL(WS-RANGE-LO)
               COMPUTE WS-NUM-HI = FUNCTION NUMVAL(WS-RANGE-HI)
               IF WS-NUM-LO <= WS-NUM-HI
                   MOVE 'Y' TO WS-RANGE-OK-SW
               END-IF
           END-IF.

      *----------------------------------------------------------------*
       2900-CARD-ERROR.
      *----------------------------------------------------------------*
           ADD 1 TO WS-CARD-ERRORS
           MOVE 12 TO WS-RETURN-CODE
           IF WS-CARD-ERRORS <= 10
               MOVE CARD-REC TO WS-CARD-ERROR-ENTRY(WS-CARD-ERRORS)
           END-IF
           DISPLAY 'GOALSTAT: INVALID CONTROL CARD: '
                   FUNCTION TRIM(CARD-REC).

      *================================================================*
       3000-LOAD-MATCHES.
      *================================================================*
           OPEN INPUT MATCH-FILE
           IF WS-MATCH-STATUS NOT = '00'
               DISPLAY 'GOALSTAT: CANNOT OPEN MATCHES, STATUS '
                       WS-MATCH-STATUS
               MOVE 12 TO WS-RETURN-CODE
               EXIT PARAGRAPH
           END-IF
           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ MATCH-FILE
                   AT END
                       SET WS-EOF TO TRUE
                   NOT AT END
                       PERFORM 3100-TALLY-MATCH
               END-READ
           END-PERFORM
           CLOSE MATCH-FILE.

      *----------------------------------------------------------------*
       3100-TALLY-MATCH.
      *----------------------------------------------------------------*
           ADD 1 TO WS-MATCHES-READ
           MOVE SPACES TO WS-REJECT-REASON
           EVALUATE TRUE
               WHEN MT-ROUND IS NOT NUMERIC
                   MOVE 'ROUND NOT NUMERIC' TO WS-REJECT-REASON
               WHEN MT-ROUND < 1 OR MT-ROUND > 38
                   MOVE 'ROUND OUT OF RANGE' TO WS-REJECT-REASON
               WHEN MT-DATE IS NOT NUMERIC
                   MOVE 'DATE NOT NUMERIC' TO WS-REJECT-REASON
               WHEN NOT MT-VALID-VENUE
                   MOVE 'VENUE NOT H OR A' TO WS-REJECT-REASON
               WHEN MT-GF IS NOT NUMERIC OR MT-GA IS NOT NUMERIC
                   MOVE 'SCORE NOT NUMERIC' TO WS-REJECT-REASON
               WHEN WS-RND-SEEN(MT-ROUND) = 'Y'
                   MOVE 'DUPLICATE ROUND' TO WS-REJECT-REASON
               WHEN MT-GF > MT-GA AND NOT MT-WIN
                   MOVE 'RESULT FLAG DOES NOT MATCH SCORE'
                       TO WS-REJECT-REASON
               WHEN MT-GF = MT-GA AND NOT MT-DRAW
                   MOVE 'RESULT FLAG DOES NOT MATCH SCORE'
                       TO WS-REJECT-REASON
               WHEN MT-GF < MT-GA AND NOT MT-LOSS
                   MOVE 'RESULT FLAG DOES NOT MATCH SCORE'
                       TO WS-REJECT-REASON
           END-EVALUATE

           IF WS-REJECT-REASON NOT = SPACES
               ADD 1 TO WS-MATCHES-REJECTED
               MOVE 'MATCHES' TO WS-REJECT-FILE
               PERFORM 3900-RECORD-REJECT
               EXIT PARAGRAPH
           END-IF

           MOVE 'Y'         TO WS-RND-SEEN(MT-ROUND)
           MOVE MT-DATE     TO WS-RND-DATE(MT-ROUND)
           MOVE MT-OPPONENT TO WS-RND-OPPONENT(MT-ROUND)
           MOVE MT-VENUE    TO WS-RND-VENUE(MT-ROUND)
           MOVE MT-GF       TO WS-RND-MATCH-GF(MT-ROUND)

           MOVE 1 TO WS-T
           PERFORM 3200-ADD-TO-RECORD
           IF MT-HOME
               MOVE 2 TO WS-T
           ELSE
               MOVE 3 TO WS-T
           END-IF
           PERFORM 3200-ADD-TO-RECORD.

      *----------------------------------------------------------------*
       3200-ADD-TO-RECORD.
      *----------------------------------------------------------------*
           ADD 1     TO WS-R-P(WS-T)
           ADD MT-GF TO WS-R-GF(WS-T)
           ADD MT-GA TO WS-R-GA(WS-T)
           EVALUATE TRUE
               WHEN MT-WIN
                   ADD 1 TO WS-R-W(WS-T)
               WHEN MT-DRAW
                   ADD 1 TO WS-R-D(WS-T)
               WHEN OTHER
                   ADD 1 TO WS-R-L(WS-T)
           END-EVALUATE.

      *----------------------------------------------------------------*
       3900-RECORD-REJECT.
      *    LOGS A REJECTED RECORD. CALLER SETS WS-REJECT-REASON AND    *
      *    WS-REJECT-FILE ('MATCHES' OR 'GOALS').                      *
      *----------------------------------------------------------------*
           IF WS-RETURN-CODE < 4
               MOVE 4 TO WS-RETURN-CODE
           END-IF
           ADD 1 TO WS-REJECT-COUNT
           IF WS-REJECT-COUNT <= 20
               MOVE WS-REJECT-FILE
                   TO WS-REJ-FILE(WS-REJECT-COUNT)
               IF WS-REJECT-FILE = 'MATCHES'
                   MOVE WS-MATCHES-READ
                       TO WS-REJ-RECNO(WS-REJECT-COUNT)
               ELSE
                   MOVE WS-GOALS-READ
                       TO WS-REJ-RECNO(WS-REJECT-COUNT)
               END-IF
               MOVE WS-REJECT-REASON
                   TO WS-REJ-REASON(WS-REJECT-COUNT)
           END-IF
           DISPLAY 'GOALSTAT: ' FUNCTION TRIM(WS-REJECT-FILE)
                   ' RECORD REJECTED - '
                   FUNCTION TRIM(WS-REJECT-REASON).

      *================================================================*
       4000-PROCESS-GOALS.
      *================================================================*
           OPEN INPUT GOAL-FILE
           IF WS-GOAL-STATUS NOT = '00'
               DISPLAY 'GOALSTAT: CANNOT OPEN GOALS, STATUS '
                       WS-GOAL-STATUS
               MOVE 12 TO WS-RETURN-CODE
               EXIT PARAGRAPH
           END-IF

           MOVE ' SELECTED GOALS' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           WRITE REPORT-LINE FROM WS-DETAIL-HEAD

           SET WS-NOT-EOF TO TRUE
           PERFORM UNTIL WS-EOF
               READ GOAL-FILE
                   AT END
                       SET WS-EOF TO TRUE
                   NOT AT END
                       PERFORM 4100-HANDLE-GOAL
               END-READ
           END-PERFORM
           CLOSE GOAL-FILE

           IF WS-GOALS-SELECTED = 0
               MOVE '  NO GOALS MATCH THE SELECTION CRITERIA.'
                   TO WS-LINE
               PERFORM 9000-WRITE-LINE
           END-IF
           PERFORM 9000-WRITE-LINE
           MOVE 'TOTAL GOALS SELECTED .......' TO ST-LABEL
           MOVE WS-GOALS-SELECTED TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           PERFORM 9000-WRITE-LINE.

      *----------------------------------------------------------------*
       4100-HANDLE-GOAL.
      *----------------------------------------------------------------*
           ADD 1 TO WS-GOALS-READ
           PERFORM 4200-VALIDATE-GOAL
           IF WS-REJECT-REASON NOT = SPACES
               ADD 1 TO WS-GOALS-REJECTED
               MOVE 'GOALS' TO WS-REJECT-FILE
               PERFORM 3900-RECORD-REJECT
               EXIT PARAGRAPH
           END-IF

           ADD 1 TO WS-GOALS-VALID
           ADD 1 TO WS-RND-GOAL-CNT(GL-ROUND)

           PERFORM 4300-APPLY-FILTERS
           IF WS-SELECTED
               PERFORM 4400-ACCUMULATE
               PERFORM 4500-WRITE-DETAIL
           END-IF.

      *----------------------------------------------------------------*
       4200-VALIDATE-GOAL.
      *    FIELD EDITS, THEN A CROSS-CHECK AGAINST THE MATCHES FILE.   *
      *----------------------------------------------------------------*
           MOVE SPACES TO WS-REJECT-REASON
           EVALUATE TRUE
               WHEN GL-ROUND IS NOT NUMERIC
                   MOVE 'ROUND NOT NUMERIC' TO WS-REJECT-REASON
               WHEN GL-ROUND < 1 OR GL-ROUND > 38
                   MOVE 'ROUND OUT OF RANGE' TO WS-REJECT-REASON
               WHEN GL-DATE IS NOT NUMERIC
                   MOVE 'DATE NOT NUMERIC' TO WS-REJECT-REASON
               WHEN NOT GL-VALID-VENUE
                   MOVE 'VENUE NOT H OR A' TO WS-REJECT-REASON
               WHEN GL-SCORER = SPACES
                   MOVE 'SCORER MISSING' TO WS-REJECT-REASON
               WHEN GL-MINUTE IS NOT NUMERIC
                 OR GL-ADDED IS NOT NUMERIC
                   MOVE 'MINUTE NOT NUMERIC' TO WS-REJECT-REASON
               WHEN GL-MINUTE < 1 OR GL-MINUTE > 120
                   MOVE 'MINUTE OUT OF RANGE' TO WS-REJECT-REASON
               WHEN GL-ADDED > 0 AND GL-MINUTE NOT = 45
                                 AND GL-MINUTE NOT = 90
                   MOVE 'ADDED TIME ONLY AFTER 45 OR 90'
                       TO WS-REJECT-REASON
               WHEN NOT GL-VALID-TYPE
                   MOVE 'TYPE NOT N, P OR O' TO WS-REJECT-REASON
               WHEN GL-OWN-GOAL AND GL-OG-PLAYER = SPACES
                   MOVE 'OWN GOAL WITHOUT PLAYER'
                       TO WS-REJECT-REASON
               WHEN WS-RND-SEEN(GL-ROUND) NOT = 'Y'
                   MOVE 'NO MATCH RECORD FOR ROUND'
                       TO WS-REJECT-REASON
               WHEN GL-DATE     NOT = WS-RND-DATE(GL-ROUND)
                 OR GL-OPPONENT NOT = WS-RND-OPPONENT(GL-ROUND)
                 OR GL-VENUE    NOT = WS-RND-VENUE(GL-ROUND)
                   MOVE 'DOES NOT MATCH MATCHES FILE'
                       TO WS-REJECT-REASON
           END-EVALUATE.

      *----------------------------------------------------------------*
       4300-APPLY-FILTERS.
      *----------------------------------------------------------------*
           SET WS-SELECTED TO TRUE
           IF WS-F-PLAYER NOT = SPACES
              AND GL-SCORER NOT = WS-F-PLAYER
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF WS-F-OPP-LEN > 0
              AND GL-OPPONENT(1:WS-F-OPP-LEN)
                  NOT = WS-F-OPPONENT(1:WS-F-OPP-LEN)
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF WS-F-VENUE NOT = SPACE
              AND GL-VENUE NOT = WS-F-VENUE
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF WS-F-TYPE NOT = SPACE
              AND GL-TYPE NOT = WS-F-TYPE
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF GL-MINUTE < WS-F-MIN-FROM
              OR GL-MINUTE > WS-F-MIN-TO
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF GL-ROUND < WS-F-RND-FROM
              OR GL-ROUND > WS-F-RND-TO
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF WS-F-STOPPAGE = 'Y' AND GL-ADDED = 0
               SET WS-NOT-SELECTED TO TRUE
           END-IF
           IF WS-F-STOPPAGE = 'N' AND GL-ADDED > 0
               SET WS-NOT-SELECTED TO TRUE
           END-IF.

      *----------------------------------------------------------------*
       4400-ACCUMULATE.
      *----------------------------------------------------------------*
           ADD 1 TO WS-GOALS-SELECTED
           IF GL-HOME
               ADD 1 TO WS-SEL-HOME
           ELSE
               ADD 1 TO WS-SEL-AWAY
           END-IF
           EVALUATE TRUE
               WHEN GL-PENALTY
                   ADD 1 TO WS-SEL-PEN
               WHEN GL-OWN-GOAL
                   ADD 1 TO WS-SEL-OG
               WHEN OTHER
                   ADD 1 TO WS-SEL-NON-PEN
           END-EVALUATE
           IF GL-ADDED > 0
               ADD 1 TO WS-SEL-STOPPAGE
           END-IF

           EVALUATE TRUE
               WHEN GL-MINUTE = 45 AND GL-ADDED > 0
                   MOVE 4 TO WS-BAND-IX
               WHEN GL-MINUTE >= 90 AND GL-ADDED > 0
                   MOVE 8 TO WS-BAND-IX
               WHEN GL-MINUTE <= 15
                   MOVE 1 TO WS-BAND-IX
               WHEN GL-MINUTE <= 30
                   MOVE 2 TO WS-BAND-IX
               WHEN GL-MINUTE <= 45
                   MOVE 3 TO WS-BAND-IX
               WHEN GL-MINUTE <= 60
                   MOVE 5 TO WS-BAND-IX
               WHEN GL-MINUTE <= 75
                   MOVE 6 TO WS-BAND-IX
               WHEN OTHER
                   MOVE 7 TO WS-BAND-IX
           END-EVALUATE
           ADD 1 TO WS-BAND-COUNT(WS-BAND-IX)

           MOVE 'N' TO WS-FOUND-SW
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PLAYER-COUNT OR WS-FOUND
               IF WS-PL-NAME(WS-IDX) = GL-SCORER
                   ADD 1 TO WS-PL-GOALS(WS-IDX)
                   SET WS-FOUND TO TRUE
               END-IF
           END-PERFORM
           IF NOT WS-FOUND AND WS-PLAYER-COUNT < 50
               ADD 1 TO WS-PLAYER-COUNT
               MOVE GL-SCORER TO WS-PL-NAME(WS-PLAYER-COUNT)
               MOVE 1         TO WS-PL-GOALS(WS-PLAYER-COUNT)
           END-IF.

      *----------------------------------------------------------------*
       4500-WRITE-DETAIL.
      *----------------------------------------------------------------*
           MOVE GL-ROUND    TO DL-ROUND
           MOVE GL-DATE     TO WS-DATE-N
           PERFORM 9100-FORMAT-DATE
           MOVE WS-DATE-DISP TO DL-DATE
           MOVE GL-OPPONENT TO DL-OPPONENT
           MOVE GL-VENUE    TO DL-VENUE
           MOVE GL-SCORER   TO DL-SCORER

           MOVE SPACES TO DL-MINUTE
           MOVE GL-MINUTE TO WS-MIN-Z
           IF GL-ADDED > 0
               MOVE GL-ADDED TO WS-ADD-Z
               STRING FUNCTION TRIM(WS-MIN-Z) DELIMITED BY SIZE
                      '+'                     DELIMITED BY SIZE
                      FUNCTION TRIM(WS-ADD-Z) DELIMITED BY SIZE
                   INTO DL-MINUTE
               END-STRING
           ELSE
               MOVE FUNCTION TRIM(WS-MIN-Z) TO DL-MINUTE
           END-IF

           MOVE SPACES TO DL-TYPE
           EVALUATE TRUE
               WHEN GL-PENALTY
                   MOVE 'PENALTY' TO DL-TYPE
               WHEN GL-OWN-GOAL
                   STRING 'OWN GOAL BY '              DELIMITED BY SIZE
                          FUNCTION TRIM(GL-OG-PLAYER) DELIMITED BY SIZE
                       INTO DL-TYPE
                   END-STRING
               WHEN OTHER
                   MOVE SPACES TO DL-TYPE
           END-EVALUATE
           WRITE REPORT-LINE FROM WS-DETAIL-LINE.

      *================================================================*
       5000-WRITE-SCORERS.
      *    SORTS THE SCORER TABLE BY GOALS (HIGH TO LOW), THEN NAME.   *
      *================================================================*
           MOVE ' SCORERS (SELECTED GOALS)' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           IF WS-PLAYER-COUNT = 0
               MOVE '  NONE' TO WS-LINE
               PERFORM 9000-WRITE-LINE
           ELSE
               SORT SORT-FILE
                   ON DESCENDING KEY SR-GOALS
                   ON ASCENDING  KEY SR-NAME
                   INPUT  PROCEDURE IS 5100-RELEASE-SCORERS
                   OUTPUT PROCEDURE IS 5200-RETURN-SCORERS
           END-IF
           PERFORM 9000-WRITE-LINE.

      *----------------------------------------------------------------*
       5100-RELEASE-SCORERS.
      *----------------------------------------------------------------*
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-PLAYER-COUNT
               MOVE WS-PL-GOALS(WS-IDX) TO SR-GOALS
               MOVE WS-PL-NAME(WS-IDX)  TO SR-NAME
               RELEASE SORT-REC
           END-PERFORM.

      *----------------------------------------------------------------*
       5200-RETURN-SCORERS.
      *----------------------------------------------------------------*
           MOVE 'N' TO WS-SORT-EOF-SW
           MOVE 0 TO WS-RANK
           PERFORM UNTIL WS-SORT-EOF
               RETURN SORT-FILE
                   AT END
                       SET WS-SORT-EOF TO TRUE
                   NOT AT END
                       ADD 1 TO WS-RANK
                       MOVE WS-RANK  TO SC-RANK
                       MOVE SR-NAME  TO SC-NAME
                       MOVE SR-GOALS TO SC-GOALS
                       MOVE SR-GOALS TO WS-BAR-LEN
                       PERFORM 9200-FORMAT-BAR
                       MOVE WS-LINE(1:40) TO SC-BAR
                       MOVE SPACES TO WS-LINE
                       WRITE REPORT-LINE FROM WS-SCORER-LINE
               END-RETURN
           END-PERFORM.

      *================================================================*
       6000-WRITE-TIMING.
      *================================================================*
           MOVE ' GOAL TIMING (SELECTED GOALS)' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 8
               MOVE WS-BAND-LABEL(WS-IDX) TO BL-LABEL
               MOVE WS-BAND-COUNT(WS-IDX) TO BL-COUNT
               MOVE WS-BAND-COUNT(WS-IDX) TO WS-BAR-LEN
               PERFORM 9200-FORMAT-BAR
               MOVE WS-LINE(1:40) TO BL-BAR
               MOVE SPACES TO WS-LINE
               WRITE REPORT-LINE FROM WS-BAND-LINE
           END-PERFORM
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       6100-WRITE-SPLITS.
      *================================================================*
           MOVE ' VENUE AND GOAL TYPE (SELECTED GOALS)' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           MOVE 'HOME ......................' TO ST-LABEL
           MOVE WS-SEL-HOME TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'AWAY ......................' TO ST-LABEL
           MOVE WS-SEL-AWAY TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'NON-PENALTY ...............' TO ST-LABEL
           MOVE WS-SEL-NON-PEN TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'PENALTY ...................' TO ST-LABEL
           MOVE WS-SEL-PEN TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'OWN GOAL (BY OPPONENT) ....' TO ST-LABEL
           MOVE WS-SEL-OG TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'IN STOPPAGE TIME ..........' TO ST-LABEL
           MOVE WS-SEL-STOPPAGE TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       6500-RECONCILE.
      *    CONTROL TOTALS: GOAL RECORDS PER ROUND MUST EQUAL THE       *
      *    GOALS-FOR IN THAT ROUND'S MATCH RECORD.                     *
      *================================================================*
           MOVE ' CONTROL TOTALS' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE

           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 38
               IF WS-RND-SEEN(WS-IDX) NOT = 'Y'
                   ADD 1 TO WS-MISMATCHES
                   MOVE WS-IDX TO WS-COUNT-Z
                   STRING '  ROUND ' FUNCTION TRIM(WS-COUNT-Z)
                          ': NO MATCH RECORD'
                          DELIMITED BY SIZE INTO WS-LINE
                   END-STRING
                   PERFORM 9000-WRITE-LINE
               ELSE
                   IF WS-RND-GOAL-CNT(WS-IDX)
                      NOT = WS-RND-MATCH-GF(WS-IDX)
                       ADD 1 TO WS-MISMATCHES
                       MOVE WS-IDX TO WS-COUNT-Z
                       STRING '  ROUND ' FUNCTION TRIM(WS-COUNT-Z)
                              ': GOAL RECORDS DO NOT MATCH SCORE'
                              DELIMITED BY SIZE INTO WS-LINE
                       END-STRING
                       PERFORM 9000-WRITE-LINE
                   END-IF
               END-IF
           END-PERFORM

           MOVE 'MATCH RECORDS READ ........' TO ST-LABEL
           MOVE WS-MATCHES-READ TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'MATCH RECORDS REJECTED ....' TO ST-LABEL
           MOVE WS-MATCHES-REJECTED TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'GOAL RECORDS READ .........' TO ST-LABEL
           MOVE WS-GOALS-READ TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'GOAL RECORDS REJECTED .....' TO ST-LABEL
           MOVE WS-GOALS-REJECTED TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'GOALS FOR PER MATCHES FILE ' TO ST-LABEL
           MOVE WS-R-GF(1) TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE
           MOVE 'VALID GOAL RECORDS ........' TO ST-LABEL
           MOVE WS-GOALS-VALID TO ST-VALUE
           WRITE REPORT-LINE FROM WS-STAT-LINE

           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-REJECT-COUNT OR WS-IDX > 20
               MOVE WS-REJ-RECNO(WS-IDX) TO WS-COUNT-Z
               STRING '  REJECTED: '
                      FUNCTION TRIM(WS-REJ-FILE(WS-IDX))
                      ' RECORD ' FUNCTION TRIM(WS-COUNT-Z)
                      ' - ' FUNCTION TRIM(WS-REJ-REASON(WS-IDX))
                      DELIMITED BY SIZE INTO WS-LINE
               END-STRING
               PERFORM 9000-WRITE-LINE
           END-PERFORM

           IF WS-MISMATCHES = 0
              AND WS-GOALS-VALID = WS-R-GF(1)
               MOVE '  RECONCILIATION ............ AGREE' TO WS-LINE
           ELSE
               MOVE '  RECONCILIATION ............ DO NOT AGREE'
                   TO WS-LINE
               IF WS-RETURN-CODE < 8
                   MOVE 8 TO WS-RETURN-CODE
               END-IF
           END-IF
           PERFORM 9000-WRITE-LINE
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       7100-WRITE-HEADER.
      *================================================================*
           MOVE WS-CURRENT-DATE(1:8) TO WS-DATE-N
           PERFORM 9100-FORMAT-DATE
           WRITE REPORT-LINE FROM WS-RULE
           STRING ' GOALSTAT   ARSENAL FC  -  PREMIER LEAGUE 2025-26 '
                  'GOAL REPORT        RUN DATE ' WS-DATE-DISP
                  DELIMITED BY SIZE INTO WS-LINE
           END-STRING
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       7200-WRITE-CONTROL-CARDS.
      *================================================================*
           MOVE ' CONTROL CARDS (SYSIN)' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           IF WS-CARD-COUNT = 0
               MOVE '  NONE - ALL GOALS SELECTED' TO WS-LINE
               PERFORM 9000-WRITE-LINE
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-CARD-COUNT OR WS-IDX > 20
               STRING '  ' WS-CARD-ENTRY(WS-IDX)
                      DELIMITED BY SIZE INTO WS-LINE
               END-STRING
               PERFORM 9000-WRITE-LINE
           END-PERFORM
           PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > WS-CARD-ERRORS OR WS-IDX > 10
               STRING '  *** INVALID CARD: '
                      WS-CARD-ERROR-ENTRY(WS-IDX)
                      DELIMITED BY SIZE INTO WS-LINE
               END-STRING
               PERFORM 9000-WRITE-LINE
           END-PERFORM
           IF WS-CARD-ERRORS > 0
               MOVE '  *** RUN TERMINATED - CORRECT THE CARDS ABOVE'
                   TO WS-LINE
               PERFORM 9000-WRITE-LINE
           END-IF
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       7300-WRITE-SEASON-SUMMARY.
      *================================================================*
           MOVE ' SEASON RECORD (MATCHES FILE)' TO WS-LINE
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           WRITE REPORT-LINE FROM WS-SUMMARY-HEAD
           PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 3
               MOVE WS-RECORD-LABEL(WS-IDX) TO SL-LABEL
               MOVE WS-R-P(WS-IDX)  TO SL-P
               MOVE WS-R-W(WS-IDX)  TO SL-W
               MOVE WS-R-D(WS-IDX)  TO SL-D
               MOVE WS-R-L(WS-IDX)  TO SL-L
               MOVE WS-R-GF(WS-IDX) TO SL-GF
               MOVE WS-R-GA(WS-IDX) TO SL-GA
               COMPUTE SL-GD = WS-R-GF(WS-IDX) - WS-R-GA(WS-IDX)
               COMPUTE SL-PTS = WS-R-W(WS-IDX) * 3 + WS-R-D(WS-IDX)
               WRITE REPORT-LINE FROM WS-SUMMARY-LINE
           END-PERFORM
           PERFORM 9000-WRITE-LINE.

      *================================================================*
       8000-FINISH.
      *================================================================*
           MOVE WS-RETURN-CODE TO WS-RC-Z
           STRING ' END OF REPORT - RETURN CODE '
                  FUNCTION TRIM(WS-RC-Z)
                  DELIMITED BY SIZE INTO WS-LINE
           END-STRING
           PERFORM 9000-WRITE-LINE
           WRITE REPORT-LINE FROM WS-RULE
           CLOSE REPORT-FILE
           MOVE WS-GOALS-SELECTED TO WS-COUNT-Z
           DISPLAY 'GOALSTAT: ' FUNCTION TRIM(WS-COUNT-Z)
                   ' GOAL(S) SELECTED, RETURN CODE '
                   FUNCTION TRIM(WS-RC-Z).

      *================================================================*
      * UTILITIES                                                      *
      *================================================================*
       9000-WRITE-LINE.
           WRITE REPORT-LINE FROM WS-LINE
           MOVE SPACES TO WS-LINE.

       9100-FORMAT-DATE.
      *    WS-DATE-N (YYYYMMDD) -> WS-DATE-DISP (YYYY-MM-DD)
           STRING WS-DATE-YYYY '-' WS-DATE-MM '-' WS-DATE-DD
                  DELIMITED BY SIZE INTO WS-DATE-DISP
           END-STRING.

       9200-FORMAT-BAR.
      *    BUILDS A BAR OF WS-BAR-LEN '#' (MAX 40) IN WS-LINE(1:40)
           MOVE SPACES TO WS-LINE
           IF WS-BAR-LEN > 40
               MOVE 40 TO WS-BAR-LEN
           END-IF
           IF WS-BAR-LEN > 0
               MOVE WS-BAR-FULL(1:WS-BAR-LEN) TO WS-LINE(1:40)
           END-IF.
