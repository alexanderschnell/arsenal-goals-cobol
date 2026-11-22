#!/usr/bin/env bash
# Compiles GOALSTAT with GnuCOBOL and runs it against a control-card file.
#   ./run.sh                     all goals
#   ./run.sh cards/SAKAAWAY.txt  Saka's away goals
set -euo pipefail
cd "$(dirname "$0")"
card="${1:-cards/ALLGOALS.txt}"
mkdir -p bin reports

cobc -x -Wall -I copybooks -o bin/goalstat src/GOALSTAT.cbl

# GnuCOBOL maps each ASSIGN name to a file through DD_<name> environment
# variables, the same way JCL DD statements do on the mainframe.
name="$(basename "$card" .txt)"
export DD_MATCHES=data/MATCHES.DAT
export DD_GOALS=data/GOALS.DAT
export DD_SYSIN="$card"
export DD_SYSOUT="reports/$name.txt"

set +e
./bin/goalstat
rc=$?
set -e
cat "$DD_SYSOUT"
exit $rc
