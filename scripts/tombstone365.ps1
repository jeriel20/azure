#requires -version 3
##########################################################################
# Script Name   :  tombstone365.ps1
# Version       :  2.0
# Creation Date :  1 October 2015
# Created By    :  Software Engineering Center
#               :  Aberdeen Proving Ground (APG), MD
# Prerequisites :  W2K8 R2, PowerShell 2.0
# Files         :  tombstone365.ps1
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory 
#
# History       :  1.0 (2013/01/15)
#
##########################################################################

$scriptver = "2.0"
$reqlibver = "9.5"
$title = "Tombstone Lifetime (365)"

##########################################################################
# Include the library routines (DOT Source)
##########################################################################

if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Missing bccslib5r2.PS1 - Ensure this file is in the c:\Scripts Directory`n`n"
    Exit
}

. ./bccslib5r2.ps1

if([int]$BCCSLibver -lt [int]$reqlibver)
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Incorrect BCCS Library - Must be Version $reqlibver or Higher`n`n"
    Exit
}

$header = Set-Console "Tombstone Lifetime"

###########################################################################

displayMeanHeader $title

Write-Host -foregroundcolor WHITE " This script will set the Tombstone Lifetime to 365 Days `n" 
Write-Host -foregroundcolor YELLOW " MUST BE RUN ON A DOMAIN CONTROLLER !!!`n"

displayLine

$go = get-Response "Do You Wish to Continue (Y/N)?" "CYAN" "Y"

If($go -ne "Y") 
{ 
   Write-Host "`n`n"
   "USER EXIT: Confirmation Display" | Write-log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT 
}

##########################################################################
# Increase Tombstone Lifetime to 1 Year (365 Days)
##########################################################################

Write-Host
displayLine
Write-Host

displayMessage " Set Tombstone Lifetime to 365 Days "

import-module ActiveDirectory

$ADDomainName = Get-ADDomain

$ADname = $ADDomainName.DistinguishedName

Set-ADObject -Identity "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$ADname" -Partition "CN=Configuration,$ADname" -Replace @{tombstoneLifetime='365'}

displayStatus

displayLine "="
Write-Host

##########################################################################