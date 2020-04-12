﻿#requires -version 3
##########################################################################
# Script Name   : modSchema-2008.ps1
# Version       : 1.5
# Creation Date : 1 October 2015
# Created By    : Software Engineering Center
#               : Aberdeen Proving Ground (APG), MD
# Prerequisites : W2K8 R2, PowerShell 3.0
# Files         : createCmdWeb.ps1   (this file)
#               : _schemaTemplate.ldf
# Paths         : Files must be located in C:\Scripts directory
# History       : 2014/01/15 - Initial Release
##########################################################################

$scriptver = "1.5"
$reqlibver = "9.5"
$title = "DOD Schema Modifications"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_modSchema_" + $currdate + ".log"

##########################################################################
# Include the library routines (DOT Source)
##########################################################################

if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Missing bccslib5r2.PS1 - Ensure this file is in the c:\Scripts Directory`n`n"
    Exit
}

$calledBy = $MyInvocation.ScriptName


If($calledBy -eq "")
{
   . ./bccslib5r2.ps1
}
else
{
   "Script Invoked by $calledBy - bccslib5r2.ps1 already loaded" | Write-log
}

if([int]$BCCSLibver -lt [int]$reqlibver)
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Incorrect BCCS Library - Must be Version $reqlibver or Higher`n`n"
    Exit
}

##########################################################################
# Verify .NET v4
##########################################################################

$fwlist = get-Framework-Versions

if($fwlist -contains "4.0")
{
   ".NET v4 Installed" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires .NET Framework v4 `n`n"
   "MISSING .NET FRAMEWORK v4" | Write-log
   EXIT
}

##########################################################################
# Verify W2K8 R2 Service Pack 1
##########################################################################

$OSver = get-OS

If($OSver -eq "W2K8R2SP1")
{
   "OS VERSION: $OSver" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires Windows 2008 R2 with Service Pack 1`n`n"
   "INVALID OS: $OSver" | Write-log
   EXIT
}

##########################################################################
# Verify server is a domain controller
##########################################################################

$result = get-Service ADWS -EA SilentlyContinue

If($result -eq $null)
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script must be run on a Domain Controller !!!`n`n"
   "INVALID SERVER: Not a Domain Controller" | Write-log
   EXIT
}

##########################################################################
#  Start Log
##########################################################################

"===== START INSTALLATION - modSchema-2008.ps1 =====" | Write-log

##########################################################################
#  Start Processing
##########################################################################

$header = Set-Console $title
$header | Write-log
setWindowSize

##########################################################################
# Verify the C:\Scripts directory exists and set to default location
##########################################################################

if(!(test-path "C:\Scripts"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: Script not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

set-location "C:\Scripts"

if(!(test-path "C:\Scripts\modSchema-2008.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: modSchema-2008.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_schematemplate.ldf'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tSchema Modification Template Not Found (_schematemplate.ldf)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO LDF FILE FOUND!`n`n"
   "ERROR: LDF Template File Missing" | Write-log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

##########################################################################
# Instructions
##########################################################################

$prereqs = " This script will modify the Active Directory Schema.`n`n"

$prereqs += " NOTES  : * The script will add $ct new objects / attributes to the `n"
$prereqs += "        : * Active Directory User Account object class (dodUserOrgPerson). `n`n"
$prereqs += " PREREQ : * You must have domain admin permissions to Active Directory`n"
$prereqs += "          * Script must be run on the Schema Master domain controller`n`n"

##########################################################################

"===== START LDF MODIFICATIONS =====" | Write-log

##########################################################################

displayMainHeader $title

Write-Host -foregroundcolor WHITE $prereqs
displayLine "="
Write-Host

$go = get-Response "Do You Wish to Continue (Y/N)?" "CYAN" "Y"

If($go -ne "Y") 
{ 
   Write-Host "`n`n"
   "USER EXIT: Prequisites Display" | Write-log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT 
}

#########################
# Distinguished Name (DN)
#########################

Write-Host
displayLine
Write-Host
displayMessage " Extracting Distinguished Name "

$unitDN = ""
$domain = $env:userdnsdomain
$fqdn = $domain.Split(".")

foreach($dc IN $fqdn)
{
   $unitDN += "DC=" + $dc + ","
}

$unit = $unitDN.SubString(0,$unitDN.Length-1)
"UNIT DN: $unit" | Write-log
displayStatus

#################
# Update Template
#################

displayMessage " Generating LDF from Template "
if (test-path 'c:\scripts\_dodmods.ldf') { del c:\scripts\_dodmods.ldf | out-null }
(Get-Content C:\Scripts\_schematemplate.ldf) | Foreach-Object {$_ -replace "{_UNIT_DN_}", $unit} | Set-Content C:\Scripts\_dodmods.ldf
"Generated _dodmods.ldf file" | Write-log
displayStatus

##############################
# APPLY LDF FILE
##############################

displayMessage "Applying Active Directory Schema Mods"

& ldifde -i -k -f c:\scripts\_dodmods.ldf -v -j c:\scripts | out-null

if($LASTEXITCODE -eq 0) 
{ 
   displayStatus
   "DOD Mods applied SUCCESSFULLY" | Write-log 
} 
else 
{ 
   displayStatus 2 
   "ERROR APPLYING DOD MODS ($LASTEXITCODE)" | Write-log
}

displayLine "="
Write-Host
"DONE" | Write-log
