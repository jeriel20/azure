#requires -version 3
##########################################################################
# Script Name   : createAccounts-2008.ps1
# Version       : 9.5
# Creation Date : 1 October 2015
# Created By    : Software Engineering Center
#               : Aberdeen Proving Ground (APG), MD
# Prerequisites : W2K8 R2, PowerShell 3.0
# Files         : createAccounts-2008.ps1   (this file)
#               : bccslib5r2.ps1
#               : _BCCSgroups.csv, _BCCSaccounts.csv
# Paths         : Files must be located in C:\Scripts directory
##########################################################################

$scriptver = "9.5"
$reqlibver = "9.5"
$title = "Active Directory Account Creation"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_createAccounts_" + $currdate + ".log"

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
# Verify W2K8 R2
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

"===== START INSTALLATION - ADpostinstall.ps1 =====" | Write-log

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

if(!(test-path "C:\Scripts\createAccounts-2008.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: createAccounts-2008.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_BCCSaccounts.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tService Accounts CSV File Not Found (_BCCSaccounts.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO ACCOUNTS HAVE BEEN CREATED!`n`n"
   "ERROR: Accounts CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_BCCSgroups.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tGroups CSV File Not Found (_BCCSgroups.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO GROUPS HAVE BEEN CREATED!`n`n"
   "ERROR: Groups CSV File Missing" | Write-log
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
displayString "This script will create all the required BCCS security groups and service accounts."
Write-Host

$prereqs="The script only prompts for ONE PASSWORD which for ALL service accounts","The created OU is [Protected From Accidental Deletion]"
displayActionList "NOTES" $prereqs

$prereqs="You must have account creation permissions to Active Directory","Script must be run on a domain controller"
displayActionList "PREREQS" $prereqs

$prereqs="The script processes the .CSV files located in the C:\Scripts directory","Edit these files using NOTEPAD to make any desired changes"
displayActionList "INPUT" $prereqs

displayLine
Write-Host

##########################################################################

"===== START ACCOUNT CREATION AND REPORT =====" | Write-log
$report = New-Item -ItemType file C:\scripts\reportBCCS.txt -force

Write-host -foregroundcolor YELLOW " BCCS Service Accounts"
Write-Host

$UAL = Import-Csv “_BCCSaccounts.csv” # | Sort-Object Name

$ct = 1

foreach($UA in $UAL) {

   $name = $UA.Name
   
   if($name -ne "{CurrentUser}")
   {
      Write-host -foregroundcolor WHITE "`t$name" -nonewline
      $remainder = $ct % 5
      If($remainder -eq 0) { Write-host "`n" } ElseIf($name.Length -lt 8) { Write-Host "`t" -nonewline }
      $ct += 1
   }

}

"Displayed Account List - Sorted on Account" | Write-log

If($remainder -ne 0) { Write-host }

Write-Host
displayLine

##########################################################################
# Get Default Password
##########################################################################

show-PasswordWarning
$securepwd = get-Password "Default Password for Service Accounts" "CYAN" 
$pwd = ConvertTo-PlainText($securepwd) 

"Retrieved Default Password for Service Accounts" | Write-log

##########################################################################
# Create Service Accounts OU
##########################################################################

$OUname = get-Response "Service Accounts OU Name" "CYAN" "$defaultOU"

"OU NAME: $OUname" | Write-log

displayLine

displayMessage " Create OU ($OUname) "

$domain = $env:userdnsdomain

$result = get-ADOrganizationalUnit -filter "Name -eq `"$OUname`"" | Select-Object Name

if($result -eq $null)
{

   New-ADOrganizationalUnit -Name "$OUname" -Description "$OUname" -DisplayName "$OUname"
   displayStatus
   "CREATED OU: $OUname" | Write-log
}
else
{
   displayStatus 3
   "OU EXISTS: $OUname" | Write-log
}

add-content $report " OU: $OUname"

$info = New-Item -ItemType file C:\scripts\ou.txt -force
add-content $info $OUname

##########################################################################
# Build OU Path for ADGroup and ADUser Creation
##########################################################################

$fqdn = $domain.Split(".")

$OUpath = "OU=$OUname,"

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

displayMessage " Create Security Groups "

add-content $report " Security Groups "

$AnyExist = "N"

$groupFile = import-csv "c:\scripts\_BCCSgroups.csv"

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
                  -SamAccountName $cavline.GroupName `
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

##############################
# Build list of existing users
##############################

displayMessage " Create Service Accounts "

add-content $report " Service Accounts "

$AnyExist = "N"

$users = get-ADgroupmember "Domain Users" -recursive | Select-Object Name

$CurrentUser = $env:username
(Get-Content C:\Scripts\_BCCSaccounts.csv) | Foreach-Object {$_ -replace "{CurrentUser}", $CurrentUser} | Set-Content C:\Scripts\_BCCSaccounts.csv

$userFile = import-csv "c:\scripts\_BCCSaccounts.csv"

Foreach ($csvline IN $userFile)
{
   $exists = "N"

   $UserName = $csvline.Name

   foreach ($userLine IN $users)
   {
      if($userLine.Name -eq "$userName")
      {
         $exists = "Y"
         $AnyExist = "Y"
      }
   }

  If($exists -eq "N")
  {

     $upn = $csvline.Name + "@" + $domain

     new-ADuser -Name $csvline.Name `
                -AccountPassword (ConvertTo-SecureString "$pwd" -AsPlainText -force) `
                -Department $csvline.Department `
                -Description $csvline.Description `
                -DisplayName $csvline.DisplayName `
                -Enabled $TRUE `
                -PasswordNeverExpires $TRUE `
                -Path $OUpath `
                -SamAccountName $csvline.Name `
                -GivenName $csvline.GivenName `
                -Surname $csvline.Surname `
                -UserPrincipalName $upn


      "User: $UserName Created" | Write-log

      add-content $report "    CREATE: $username"

   }
   else
   {

      "User: $UserName Exists" | Write-log

      add-content $report "    EXISTS: $username"

   }

   $sgList = $csvline.GroupList

   If($sgList.length -gt 0)
   {

      $grpList = $sgList.Split(":")

      foreach ($grp IN $grpList)
      {

         $members = get-ADgroup "$grp" -Properties member | Select-Object member

         if($members.member -like "*$UserName*")
         {
            "$Username Already Member of $grp" | Write-Log
            add-content $report "       EXISTS: $username Member of $grp"
         }
         else
         {
            add-ADGroupMember "$grp" -Members $userName
            "$username Added to $grp" | Write-Log
            add-content $report "       ADD: $userName to $grp"
         }

      }

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

"===== COMPLETED SECURITY GROUP/ACCOUNT CREATION =====" | Write-log

##########################################################################

displayLine
Write-Host

$detailed = get-Response " View Detailed Report (Y/N)?" "CYAN" "N"

if($detailed -eq "Y")
{

   "Display Detailed Report" | Write-log

   $reportinfo = get-content c:\scripts\reportBCCS.txt

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

(Get-Content C:\Scripts\_BCCSaccounts.csv) | Foreach-Object {$_ -replace $CurrentUser, "{CurrentUser}"} | Set-Content C:\Scripts\_BCCSaccounts.csv

"DONE" | Write-log

##########################################################################

