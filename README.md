# Arsenal Goals: a COBOL Batch Reporting System

[![Build and test](https://github.com/alexanderschnell/arsenal-goals-cobol/actions/workflows/build.yml/badge.svg)](https://github.com/alexanderschnell/arsenal-goals-cobol/actions/workflows/build.yml)

A mainframe-style COBOL program for querying every goal Arsenal scored in the **2025–26 Premier League** title-winning season. Filters go in as JCL-style control cards, and the program writes a 132-column batch report with sorted scorer tables, goal timing, home/away splits and reconciled control totals.

It's built the way batch COBOL runs on z/OS: copybook record layouts, fixed-width data files, DD-name file assignment, `SORT` with input and output procedures, record validation, and return codes for the scheduler.

```
 SCORERS (SELECTED GOALS)
------------------------------------------------------------------
    1  GYOKERES             14  ##############
    2  EZE                   7  #######
    3  SAKA                  7  #######
    4  TROSSARD              6  ######
    5  ZUBIMENDI             5  #####

 SEASON RECORD (MATCHES FILE)
------------------------------------------------------------------
              P    W    D    L   GF   GA    GD   PTS
  OVERALL    38   26    7    5   71   27   +44    85
```

## Quick Start

Requires [GnuCOBOL](https://gnucobol.sourceforge.io/) 3.x.

```powershell
.\run.ps1                       # Windows: every goal of the season
.\run.ps1 cards\SAKAAWAY.txt    # Saka's away goals
```

```bash
./run.sh cards/NLDERBY.txt      # Linux/macOS: North London derby goals
tests/run-tests.sh              # regression tests
```

The script compiles `src/GOALSTAT.cbl`, runs it against a control-card file and prints the report, which is also saved in `reports/`.

## Writing a Query

A control-card file holds one `KEYWORD=VALUE` per line. Filters combine with AND, and a `*` in column 1 marks a comment.

| Card | Meaning | Example |
|---|---|---|
| `PLAYER=` | Scorer surname, exact match. `OWN GOAL` selects own goals | `PLAYER=SAKA` |
| `OPPONENT=` | Opponent name, starts-with match | `OPPONENT=TOTTENHAM` |
| `VENUE=` | `H` home or `A` away | `VENUE=A` |
| `TYPE=` | `N` non-penalty, `P` penalty, `O` own goal by an opponent | `TYPE=P` |
| `MINUTE=` | Match-minute range; stoppage time counts as 45 or 90 | `MINUTE=76-90` |
| `ROUND=` | Matchweek range, 1–38 | `ROUND=30-38` |
| `STOPPAGE=` | `Y` only stoppage-time goals, `N` none | `STOPPAGE=Y` |

Sample cards in `cards/`:

| Card | Question | Goals |
|---|---|---|
| `ALLGOALS` | Every league goal | 71 |
| `SAKAAWAY` | Bukayo Saka's away goals | 3 |
| `PENALTY` | Penalties scored | 4 |
| `LATEGOAL` | Goals in stoppage time | 10 |
| `NLDERBY` | Goals against Tottenham | 8 |
| `RUNIN` | Last 15 minutes of the title run-in (rounds 30–38) | 3 |
| `BADCARD` | Invalid cards, to show the error handling | RC 12 |

## The Report

1. **Control cards:** the cards that were read, with any invalid ones flagged.
2. **Season record:** played, won, drawn, lost, goals for and against, goal difference and points, overall and split home/away.
3. **Selected goals:** round, date, opponent, venue, scorer, minute and type for every goal that matches.
4. **Scorers:** ranked with the COBOL `SORT` verb (goals descending, then name).
5. **Goal timing:** goals in 15-minute bands, with first-half and second-half stoppage time shown separately.
6. **Venue and goal type:** home/away, penalty, own-goal and stoppage-time counts.
7. **Control totals:** record counts, rejected records with reasons, and a round-by-round check that the goal records add up to each match's score.

### Return codes

| RC | Meaning |
|---|---|
| 0 | Normal completion |
| 4 | Warning: invalid records were skipped |
| 8 | Error: goal records don't reconcile with match scores |
| 12 | Severe: invalid control card or a file couldn't be opened |

## Data Model

Both files are fixed-width, one record per line, described by the copybooks in `copybooks/`.

**`MATCHES.DAT`** (`MATCHREC`, 80 bytes): one record per league match.

| Pos | Len | Field | Notes |
|---|---|---|---|
| 1 | 7 | Season | `2025-26` |
| 8 | 2 | Round | Matchweek 01–38 |
| 10 | 8 | Date | YYYYMMDD |
| 18 | 24 | Opponent | Upper case |
| 42 | 1 | Venue | `H` / `A` |
| 43 | 2 | Goals for | |
| 45 | 2 | Goals against | |
| 47 | 1 | Result | `W` / `D` / `L` |

**`GOALS.DAT`** (`GOALREC`, 100 bytes): one record per Arsenal goal, keyed to its match by round.

| Pos | Len | Field | Notes |
|---|---|---|---|
| 1 | 7 | Season | |
| 8 | 2 | Round | |
| 10 | 8 | Date | Must match the match record |
| 18 | 24 | Opponent | Must match the match record |
| 42 | 1 | Venue | Must match the match record |
| 43 | 20 | Scorer | Surname, or `OWN GOAL` |
| 63 | 3 | Minute | `90` for 90+N |
| 66 | 2 | Added time | Stoppage-time minute, `00` if none |
| 68 | 1 | Type | `N` / `P` / `O` |
| 69 | 20 | Own-goal player | The opponent who scored it |

### Validation

Every record is checked before it's used: numeric fields, value ranges, venue and type codes, stoppage time only after the 45th or 90th minute, own goals naming the player, result flags agreeing with the score, and each goal agreeing with its match on date, opponent and venue. Rejected records are listed with a reason and the run ends with RC 4 or higher, never silently.

## Running on z/OS

The same source builds with IBM Enterprise COBOL on a mainframe. The JCL is written to IBM's documented syntax but hasn't been run on a real system yet. If you don't have a mainframe, IBM's free [IBM Z Xplore](https://www.ibm.com/products/z/resources/zxplore) learning program gives you a real z/OS account to try it on.

### The JCL

| Member | What it is |
|---|---|
| `jcl/ARSALLOC.jcl` | One-time setup job: creates the libraries and data sets with `IEFBR14` |
| `jcl/proclib/ARSCL.jcl` | Proc that compiles (`IGYCRCTL`) and link-edits (`IEWBLINK`) one program |
| `jcl/proclib/ARSRUN.jcl` | Proc that runs `GOALSTAT` with all its DD statements |
| `jcl/GOALSTAT.jcl` | The job: builds the program, then runs one query |

Most shops wrap their compile and run steps in in-house procs, so developers rarely see the raw IBM programs. `ARSCL` and `ARSRUN` play that role here. That keeps the job itself down to what's specific to one run:

```jcl
//BUILD    EXEC ARSCL,HLQ=&MYHLQ,MEMBER=GOALSTAT
//BUILDOK  IF (BUILD.COBOL.RC <= 4 AND BUILD.LKED.RC <= 4) THEN
//QUERY    EXEC ARSRUN,HLQ=&MYHLQ
//RUN.SYSIN DD *
PLAYER=SAKA
VENUE=A
/*
//         ENDIF
```

The `IF` only runs the report if both build steps ended cleanly. A step that was skipped never passes an RC test, so a failed compile also stops the report.

### Steps

1. In every JCL member, change `YOURID` to your high-level qualifier (usually your user ID).
2. Submit `ARSALLOC` to create the libraries and data sets.
3. Upload the files, for example with the Zowe Explorer extension for VS Code:

   | Local file | Upload to |
   |---|---|
   | `src/GOALSTAT.cbl` | `YOURID.ARSENAL.SOURCE(GOALSTAT)` |
   | `copybooks/*.cpy` | `YOURID.ARSENAL.COPYLIB(MATCHREC)`, `(GOALREC)` |
   | `jcl/proclib/*.jcl` | `YOURID.ARSENAL.PROCLIB(ARSCL)`, `(ARSRUN)` |
   | `data/MATCHES.DAT` | `YOURID.ARSENAL.MATCHES.D2526` |
   | `data/GOALS.DAT` | `YOURID.ARSENAL.GOALS.D2526` |

4. If your site's compiler library isn't `IGY.V6R4M0.SIGYCOMP`, add `COBLIB=` with your site's name to the `EXEC ARSCL` line.
5. Submit `GOALSTAT`. The report is in the `RPTOUT` output, the program's messages are in `SYSOUT`, and the compile listing is in `BUILD.COBOL.SYSPRINT`.

To ask a different question, change the cards under `RUN.SYSIN`. To report on another season, load its data as `...MATCHES.D2627` and `...GOALS.D2627` and add `SEASON=D2627` to the `EXEC ARSRUN` line.

### One source, two compilers

| | GnuCOBOL (PC and CI) | Enterprise COBOL (z/OS) |
|---|---|---|
| Files | `LINE SEQUENTIAL` text files | Fixed-length `SEQUENTIAL` data sets (`RECFM=FB`) |
| DD names | `DD_MATCHES` etc. environment variables | `//MATCHES DD` etc. in `ARSRUN` |
| Sort messages | Not applicable | Routed to their own `SORTMSG` DD |

The differences are handled with conditional compilation (`>>IF GNUCOBOL IS DEFINED`). The run scripts compile with `-D GNUCOBOL`, plus `-fassign-clause=external` so GnuCOBOL treats `ASSIGN TO MATCHES` as a DD name the way IBM COBOL does. The program's `ASSIGN` names are the DD names: `MATCHES`, `GOALS`, `SYSIN` and `RPTOUT` (the report). `SYSOUT` carries `DISPLAY` messages.

## Data Source and Limitations

Match results, scorers and minutes are transcribed from the match boxes on Wikipedia's [2025–26 Arsenal F.C. season](https://en.wikipedia.org/wiki/2025%E2%80%9326_Arsenal_F.C._season) article (text available under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)), read on 22 November 2026. The totals cross-check: 38 matches, 26 W, 7 D, 5 L, 71 goals for, 27 against, 85 points.

- **No assists.** The source doesn't record them consistently, so they aren't modelled rather than guessed.
- **Goal type is limited.** The source marks penalties and own goals only, so headers, free kicks and open-play goals are all `N` (non-penalty).
- **Names are upper case without accents** (e.g. `GYOKERES`, `ODEGAARD`), as fixed-width mainframe data usually is.

If you spot an error, please open an issue.

## Project Structure

```
├── src/GOALSTAT.cbl          the program
├── copybooks/                MATCHREC and GOALREC record layouts
├── data/                     MATCHES.DAT and GOALS.DAT
├── cards/                    sample control cards (queries)
├── jcl/                      z/OS jobs: ARSALLOC (setup), GOALSTAT (build and run)
│   └── proclib/              ARSCL (compile and link) and ARSRUN (run) procs
├── tests/run-tests.sh        regression tests
├── run.ps1, run.sh           compile and run
└── .github/workflows/        GitHub Actions: build and test on every push
```
