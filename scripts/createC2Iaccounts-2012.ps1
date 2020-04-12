#requires -version 3
##########################################################################
# Script Name   : createC2Iaccounts-2012.ps1
# Version       : 1.0
# Creation Date : 1 October 2015
# Created By    : Software Engineering Center
#               : Aberdeen Proving Ground (APG), MD
# Prerequisites : Windows 2012, PowerShell 3.0
# Files         : createC2Iaccounts-2012.ps1   (this file)
#               : bccslib5r2.ps1
#               : _C2Igroups.csv
# Paths         : Files must be located in C:\Scripts directory
##########################################################################

$scriptver = "1.0"
$reqlibver = "9.5"
$title = "C2I Security Group Creation"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_createC2IAccounts-2012_" + $currdate + ".log"

##########################################################################
# Include the library routines (DOT Source)
##########################################################################

if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Missing bccslib5r2.ps1 - Ensure this file is in the c:\Scripts Directory`n`n"
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
# Verify .NET v4.5
##########################################################################

$net45 = $FALSE
$net45 = (get-WindowsFeature -Name NET-Framework-45-Features).Installed

if($net45)
{
   ".NET v4.5 Installed" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires .NET Framework v4.5 `n`n"
   "MISSING .NET FRAMEWORK v4.5" | Write-log
   EXIT
}

##########################################################################
# Verify Windows Server 2012
##########################################################################

$OSver = get-OS

If($OSver -eq "W2012R2")
{
   "OS VERSION: $OSver" | Write-log
}
else
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n This script requires Windows Server 2012 R2`n`n"
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

"===== START INSTALLATION - createC2Iaccounts-2012.ps1 =====" | Write-log

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

if (!(test-path '.\_C2Igroups.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tC2I Groups CSV File Not Found (_C2Igroups.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO ACCOUNTS HAVE BEEN CREATED!`n`n"
   "ERROR: Accounts CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

if (test-path '.\ou.txt')
{
   $defaultOU  = get-content c:\scripts\ou.txt
}
else
{
   $defaultOU = $env:userdomain + " Service Accounts"
}

##########################################################################
# Load AD Module
##########################################################################

import-module ActiveDirectory

##########################################################################
# Instructions
##########################################################################

displayMainHeader $title

displayString "This script will create all the required C2I Security Groups."
Write-Host

$prereqs="You must have account creation permissions to Active Directory","Script must be run on a domain controller"
displayActionList "PREREQS" $prereqs

displayLine
Write-Host


##########################################################################

"===== START ACCOUNT CREATION AND REPORT =====" | Write-log

$report = New-Item -ItemType file C:\scripts\reportC2I.txt -force

##########################################################################

Write-host -foregroundcolor YELLOW " C2I Security Groups`n"

$UAL = Import-Csv “_C2Igroups.csv”

$ct = 1

foreach($UA in $UAL) {

   $name = $UA.GroupName

   Write-host -foregroundcolor WHITE "`t$name" -nonewline

   $remainder = $ct % 5

   If($remainder -eq 0) { Write-host "`n" } ElseIf($name.Length -lt 8) { Write-Host "`t" -nonewline }

   $ct += 1

}

"Displayed Account List - Sorted on Account" | Write-log

If($remainder -ne 0) { Write-host }

Write-Host
displayLine
Write-Host

##########################################################################
# Get Default Password
##########################################################################

show-PasswordWarning
$securepwd = convertto-securestring "Fh5@#250@!1cgI#" -AsPlainText -Force
$pwd = ConvertTo-PlainText($securepwd) 

"Retrieved Default Password for C2I Security Groups" | Write-log

##########################################################################
# Build OU Path for ADGroup and ADUser Creation
##########################################################################

$domain = $env:userdnsdomain
$fqdn = $domain.Split(".")
$OUpath = "OU=$defaultOU,"

foreach($dn IN $fqdn)
{
   $OUpath += "dc=" + $dn + ","
}

$OUpath = $OUpath.SubString(0,$OUpath.Length-1)

"OU Path: $OUpath" | Write-log

##############################################
# Build list of Global and Domain Local Groups
##############################################

$groups  = get-Adgroup -filter {GroupScope -eq "Global"}      | Select-Object Name
$groups += get-Adgroup -filter {GroupScope -eq "DomainLocal"} | Select-Object Name

####################
# Process groups.csv
####################

Write-Host
displayMessage "Creating C2I Security Groups"

add-content $report " C2I Security Groups "

$AnyExist = "N"

$groupFile = import-csv "c:\scripts\_C2Igroups.csv"

Foreach ($csvline IN $groupFile)
{

   $exists = "N"

   $GroupName = $csvline.GroupName

   foreach ($groupLine IN $groups)
   {
      if($groupLine.Name -eq "$GroupName")
      {
         $exists = "Y"
         $AnyExist = "Y"
      }
   }

  If($exists -eq "N")
  {
      new-ADgroup -Name $csvline.GroupName `
                  -GroupScope $csvline.GroupScope `
                  -DisplayName $csvline.DisplayName `
                  -Description $csvline.Description `
                  -SamAccountName $csvline.GroupName `
                  -Path $OUpath

      "Group: $GroupName Created" | Write-log

      add-content $report "    CREATE: $GroupName"

   }
   else
   {

      "Group: $GroupName Exists" | Write-log

      add-content $report "    EXISTS: $GroupName"

   }

}

if($AnyExist -eq "Y")
{
   displayStatus 3
}
else
{
   displayStatus
}

#####################
# Refresh Groups list
#####################

$groups  = get-ADgroup -filter {GroupScope -eq "Global"}      | Select-Object Name
$groups += get-ADgroup -filter {GroupScope -eq "DomainLocal"} | Select-Object Name


"===== COMPLETED GROUP CREATION =====" | Write-log

##########################################################################

displayLine
Write-Host

$detailed = "N"

if($detailed -eq "Y")
{

   "Display Detailed Report" | Write-log

   $reportinfo = get-content c:\scripts\reportC2I.txt

   displayMainHeader $title

   foreach ($line IN $reportinfo)
   {
      if($line -like "*ADD:*")
      { 
         $color = "GREEN"
         $ptr = $line.IndexOf(":") + 1
      }
      elseif($line -like "*CREATE:*")
      { 
         $color = "CYAN"
         $ptr = $line.IndexOf(":") + 1
      }      
      elseif($line -like "*EXISTS:*")
      { 
         $color = "YELLOW"
         $ptr = $line.IndexOf(":") + 1
      }
      elseif($line -like "*OU:*")
      { 
         $color = "MAGENTA"
         $ptr = $line.IndexOf(":") + 1
      }
      else
      { 
         $color = "WHITE"
         $ptr = 0
      }

      $tag = $line.Substring(0,$ptr)
      $str = $line.Substring($ptr)

      Write-host -foregroundcolor $color "$tag" -nonewline
      Write-host -foregroundcolor WHITE  "$str"

   }
   
   If(!($calledBy -eq ""))
   {
      Write-Host
      displayLine
      Pause
   }
   
}
else
{
	Write-Host
	displayLine "="
	Write-Host
}


"DONE" | Write-log

##########################################################################

