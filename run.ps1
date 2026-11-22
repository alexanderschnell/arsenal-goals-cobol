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

cobc -x -Wall -I copybooks -o bin\goalstat.exe src\GOALSTAT.cbl
if ($LASTEXITCODE -ne 0) { throw "Compile failed" }

# GnuCOBOL maps each ASSIGN name to a file through DD_<name> environment
# variables, the same way JCL DD statements do on the mainframe.
$name = [IO.Path]::GetFileNameWithoutExtension($Card)
$env:DD_MATCHES = 'data\MATCHES.DAT'
$env:DD_GOALS   = 'data\GOALS.DAT'
$env:DD_SYSIN   = $Card
$env:DD_SYSOUT  = "reports\$name.txt"

& .\bin\goalstat.exe
$rc = $LASTEXITCODE
Get-Content $env:DD_SYSOUT
exit $rc
