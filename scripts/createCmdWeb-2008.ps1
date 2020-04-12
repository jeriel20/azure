#requires -version 3
##########################################################################
# Script Name   : createCmdWeb-2008.ps1
# Version       : 2.5
# Creation Date : 1 October 2015
# Created By    : Software Engineering Center
#               : Aberdeen Proving Ground (APG), MD
# Prerequisites : W2K8 R2, PowerShell 3.0
# Files         : createCmdWeb-2008.ps1   (this file)
#               : _CMDWEBgroups.csv
#               : _CMDWEBaccounts.csv
# Paths         : Files must be located in C:\Scripts directory
# History       : 2013/04/15 - Initial Release
#               : 2013/07/01 - Added account creation code and .csv
##########################################################################

$scriptver = "2.5"
$reqlibver = "9.5"
$title = "Command Web OU, Groups, and Accounts Creation"

$SITEID   = $env:userdomain
$CHILDOU1 = "commandweb"
$CHILDOU2 = "commandweb_role"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_createCmdWeb_" + $currdate + ".log"

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

if(!(test-path "C:\Scripts\createCmdWeb-2008.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: createCmdWeb-2008.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_CMDWEBgroups.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tGroups CSV File Not Found (_CMDWEBgroups.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO GROUPS HAVE BEEN CREATED!`n`n"
   "ERROR: Groups CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_CMDWEBaccounts.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tAccounts CSV File Not Found (_CMDWEBaccounts.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO ACCOUNTS HAVE BEEN CREATED!`n`n"
   "ERROR: Accounts CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

##########################################################################
# Load AD Module
##########################################################################

import-module ActiveDirectory

##########################################################################
# Instructions
##########################################################################

$prereqs = " This script will create the required OUs, groups, and accounts.`n`n"

$prereqs += " NOTES  : * The script prompts for a Parent OU that is created at`n"
$prereqs += "        : * Active Directory root and prefixed to the security groups. `n"
$prereqs += "          * The created OUs are [Protected From Accidental Deletion]`n`n"
$prereqs += " PREREQ : * You must have account creation permissions to Active Directory`n"
$prereqs += "          * Script must be run on a domain controller`n`n"

##########################################################################

"===== START ACCOUNT CREATION AND REPORT =====" | Write-log

$report = New-Item -ItemType file C:\scripts\reportCmdWeb.txt -force

##########################################################################

displayMainHeader $title

Write-Host -foregroundcolor WHITE $prereqs
displayLine "="
Write-Host
Write-host -foregroundcolor YELLOW "`n Command Web Accounts`n"

$UAL = Import-Csv “_CMDWEBaccounts.csv”

$ct = 1

foreach($UA in $UAL) {

   $name = $UA.Name

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
$securepwd = get-Password "Default Password for Accounts"
$pwd = ConvertTo-PlainText($securepwd) 

"Retrieved Default Password for Service Accounts" | Write-log

##########################################################################
# Site OU
##########################################################################

$SITEID = get-Response "Parent Organizational Unit (OU) " "CYAN" "$SITEID"
#$SITEID = $SITEID.Replace(" ","")
$SITEID = $SITEID.ToUpper()

"SITE ID : $SITEID"      | Write-log

##########################################################################
# Build OU Path for OU and Group Creation
##########################################################################

$domain = $env:userdnsdomain

$fqdn = $domain.Split(".")

$OUpath = "OU=$SITEID,"

foreach($dn IN $fqdn)
{
   $OUpath += "dc=" + $dn + ","
}

$OUpath = $OUpath.SubString(0,$OUpath.Length-1)

"OU Path: $OUpath" | Write-log

##########################################################################
# Create TOP OU
##########################################################################

Write-Host
displayLine

displayMessage "Create Top OU ($SITEID)"

$result = get-ADOrganizationalUnit -SearchScope OneLevel -filter "Name -eq `"$SITEID`"" | Select-Object Name

if($result -eq $null)
{

   New-ADOrganizationalUnit -Name "$SITEID" -Description "$SITEID" -DisplayName "$SITEID"
   displayStatus
   "CREATED TOP OU: $SITEID" | Write-log
   
}
else
{
   displayStatus 3
   "OU EXISTS: $SITEID" | Write-log
}

add-content $report " SITE ID / Parent OU : $SITEID"


##########################################################################
# Create Child OUs
##########################################################################

$anyExist = "N"

displayMessage "Create OU Structure"

$exists = Get-ADOrganizationalUnit -Filter "Name -eq `"$CHILDOU1`"" -Searchbase "$OUpath" | Select-Object Name

if($exists -eq $null)
{
   New-ADOrganizationalUnit -Name "$CHILDOU1" -Path "$ouPath"
   "OU: $CHILDOU1 OU Created" | Write-log
   add-content $report "    CREATE: $CHILDOU1"
}
else
{
   $anyExist = "Y"
   add-content $report "    EXISTS: $CHILDOU1"
   "OU: $CHILDOU1 OU Exists" | Write-log
}

$OUpath = "OU=" + $CHILDOU1 + "," + $OUpath

$exists = Get-ADOrganizationalUnit -Filter "Name -eq `"$CHILDOU2`"" -Searchbase "$OUpath" | Select-Object Name

if($exists -eq $null)
{
   New-ADOrganizationalUnit -Name "$CHILDOU2" -Path "$ouPath"
   "OU: $CHILDOU2 OU Created" | Write-log
   add-content $report "    CREATE: $CHILDOU2"
}
else
{
   $anyExist = "Y"
   add-content $report "    EXISTS: $CHILDOU2"
   "OU: $CHILDOU2 OU Exists" | Write-log
}

$OUpath = "OU=" + $CHILDOU2 + "," + $OUpath

if($AnyExist -eq "Y")
{
   displayStatus 3
}
else
{
   displayStatus
}

#################################################
# Update Groups and Accounts Files with Site Name
#################################################

(Get-Content C:\Scripts\_CMDWEBgroups.csv)   | Foreach-Object {$_ -replace "{SITENAME}", $SITEID} | Set-Content C:\Scripts\_CMDWEBgroups.csv
(Get-Content C:\Scripts\_CMDWEBaccounts.csv) | Foreach-Object {$_ -replace "{SITENAME}", $SITEID} | Set-Content C:\Scripts\_CMDWEBaccounts.csv

##############################################
# Build list of Global and Domain Local Groups
##############################################

$groups  = get-Adgroup -filter {GroupScope -eq "Global"}      | Select-Object Name
$groups += get-Adgroup -filter {GroupScope -eq "DomainLocal"} | Select-Object Name

####################
# Process groups.csv
####################

displayMessage "Create Security Groups"
add-content $report " Security Groups "
$AnyExist = "N"
$groupFile = import-csv "c:\scripts\_CMDWEBgroups.csv"
$groupPath = $OUpath

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
                  -Path $groupPath

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

"===== COMPLETED SECURITY GROUP CREATION =====" | Write-log

##############################
# Build list of existing users
##############################

displayMessage "Create Accounts"

add-content $report " Accounts "

$AnyExist = "N"

$users = get-ADgroupmember "Domain Users" -recursive | Select-Object Name

$userFile = import-csv "c:\scripts\_CMDWEBaccounts.csv"

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

"===== COMPLETED ACCOUNT CREATION =====" | Write-log

##########################################################################

##########################################################################

displayLine
Write-Host

$detailed = get-Response "View Detailed Report (Y/N)?" "CYAN" "N"

if($detailed -eq "Y")
{

   "Display Detailed Report" | Write-log

   $reportinfo = get-content c:\scripts\reportCmdWeb.txt

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
	  Write-Host
      Pause
   }
   
}

################################
# Set the input files to default
################################

(Get-Content C:\Scripts\_CMDWEBgroups.csv)   | Foreach-Object {$_ -replace $SITEID, "{SITENAME}"} | Set-Content C:\Scripts\_CMDWEBgroups.csv
(Get-Content C:\Scripts\_CMDWEBaccounts.csv) | Foreach-Object {$_ -replace $SITEID, "{SITENAME}"} | Set-Content C:\Scripts\_CMDWEBaccounts.csv

"DONE" | Write-log

