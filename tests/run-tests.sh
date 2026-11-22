#!/usr/bin/env bash
# Regression tests for GOALSTAT. Runs each sample control card and checks the
# return code and the number of goals selected. Expected counts were worked
# out by hand from data/GOALS.DAT.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

check() {   # card  expected-rc  expected-goals (or - to skip)
    local card="$1" want_rc="$2" want_goals="$3"
    local out rc got
    out="$(./run.sh "cards/$card.txt" 2>&1)"
    rc=$?
    got="$(printf '%s\n' "$out" | sed -n 's/.*TOTAL GOALS SELECTED[ .]*\([0-9]*\)$/\1/p')"
    if [[ "$rc" != "$want_rc" ]]; then
        echo "FAIL  $card: return code $rc, expected $want_rc"; fail=1; return
    fi
    if [[ "$want_goals" != "-" && "$got" != "$want_goals" ]]; then
        echo "FAIL  $card: $got goals selected, expected $want_goals"; fail=1; return
    fi
    echo "PASS  $card (rc=$rc${got:+, goals=$got})"
}

check ALLGOALS 0 71
check SAKAAWAY 0 3
check PENALTY  0 4
check LATEGOAL 0 10
check NLDERBY  0 8
check RUNIN    0 3
check BADCARD 12 -

# The full run must reconcile goal records against match scores.
if ./run.sh cards/ALLGOALS.txt | grep -q 'RECONCILIATION ............ AGREE'; then
    echo "PASS  reconciliation agrees"
else
    echo "FAIL  reconciliation does not agree"; fail=1
fi

# A corrupted goals file must be caught: 3 rejects, totals disagree, rc=8.
tmp="$(mktemp -d)"
awk 'NR==1  { $0 = substr($0,1,41) "X" substr($0,43) }
     NR==6  { $0 = substr($0,1,67) "Q" substr($0,69) }
     NR==11 { $0 = substr($0,1,9) "20251231" substr($0,18) }
     { print }' data/GOALS.DAT > "$tmp/GOALS.DAT"
DD_MATCHES=data/MATCHES.DAT DD_GOALS="$tmp/GOALS.DAT" \
DD_SYSIN=cards/ALLGOALS.txt DD_SYSOUT="$tmp/report.txt" ./bin/goalstat >/dev/null
rc=$?
rejects="$(grep -c '  REJECTED: GOALS RECORD' "$tmp/report.txt")"
if [[ "$rc" == 8 && "$rejects" == 3 ]]; then
    echo "PASS  corrupted data caught (rc=8, 3 rejects)"
else
    echo "FAIL  corrupted data: rc=$rc rejects=$rejects, expected rc=8 rejects=3"; fail=1
fi
rm -rf "$tmp"

exit $fail
