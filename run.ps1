<#
.SYNOPSIS
    Compiles GOALSTAT with GnuCOBOL and runs it against a control-card file.
.EXAMPLE
    .\run.ps1                      # all goals
    .\run.ps1 cards\SAKAAWAY.txt   # Saka's away goals
#>
param([string]$Card = 'cards\ALLGOALS.txt')
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force bin, reports | Out-Null

# -D GNUCOBOL selects the PC file handling (see the >>IF blocks in the program).
# -fassign-clause=external treats ASSIGN names as DD names, like IBM COBOL.
cobc -x -Wall -D GNUCOBOL -fassign-clause=external -I copybooks -o bin\goalstat.exe src\GOALSTAT.cbl
if ($LASTEXITCODE -ne 0) { throw "Compile failed" }

# GnuCOBOL maps each ASSIGN name to a file through DD_<name> environment
# variables, the same way JCL DD statements do on the mainframe.
$name = [IO.Path]::GetFileNameWithoutExtension($Card)
$env:DD_MATCHES = 'data\MATCHES.DAT'
$env:DD_GOALS   = 'data\GOALS.DAT'
$env:DD_SYSIN   = $Card
$env:DD_RPTOUT  = "reports\$name.txt"

& .\bin\goalstat.exe
$rc = $LASTEXITCODE
Get-Content $env:DD_RPTOUT
exit $rc
