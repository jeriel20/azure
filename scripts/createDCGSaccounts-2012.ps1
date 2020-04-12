#requires -version 3
##########################################################################
# Script Name   : createDCGSaccounts-2012.ps1
# Version       : 4.0
# Creation Date : 1 October 2015
# Created By    : Software Engineering Center
#               : Aberdeen Proving Grounds (APG), MD
# Prerequisites : Windows 2012, PowerShell 3.0
# Files         : createDCGSaccounts-2012.ps1   (this file)
#               : bccslib5r2.ps1
#               : _DCGSgroups.csv, _DCGSaccounts.csv
# Paths         : Files must be located in C:\Scripts directory
#
# Version 1.0   : 2013/01/17 - Added Site Name OU
#                            - Modified .CSVs to insert site name
#                            - Force UserName to lowercase
#         2.0   : 2013/02/07 - Added "-SearchScope OneLevel" to 
#                              get-ADOrganizationalUnit query
#         3.0   : 2014/04/06 - Added additional users
#                            - Added Computers using .txt file
#         4.0   : 2014/05/19 - Updated for Windows 2012
##########################################################################

$scriptver = "4.0"
$reqlibver = "9.5"
$title = "DCGS-A OU, Computers, Groups, and Account Creation"

$DCGS_OUS = "Groups","Servers","ServiceUsers","Workstations"
$topOU = "DCGS-A"
$siteName = ""
$siteNameShort = ""
$topGroupOU = "Groups"
$topUserOU = "ServiceUsers"
$topServersOU = "Servers"

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_createDCGS_" + $currdate + ".log"

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
   "Script Invoked by $calledBy - bccslib5.ps1 already loaded" | Write-log
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

"===== START INSTALLATION - ADpostinstall-2012.ps1 =====" | Write-log

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

if(!(test-path "C:\Scripts\createDCGSaccounts-2012.ps1"))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: createAccounts-2012.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_DCGSaccounts.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tService Accounts CSV File Not Found (_DCGSaccounts.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO ACCOUNTS HAVE BEEN CREATED!`n`n"
   "ERROR: Accounts CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_DCGSgroups.csv'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tGroups CSV File Not Found (_DCGSgroups.csv)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO GROUPS HAVE BEEN CREATED!`n`n"
   "ERROR: Groups CSV File Missing" | Write-log
   "===== STOP POST INSTALLATION =====" | Write-log
   EXIT
}

if (!(test-path '.\_DCGScomputers.txt'))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n`tComptuers TXT File Not Found (_DCGScomputers.txt)`n"
   Write-Host -foregroundcolor YELLOW "`n`t         NO COMPUTERS HAVE BEEN CREATED!`n`n"
   "ERROR: Computers TXT File Missing" | Write-log
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

displayMainHeader $title

displayString "This script will create all the required DCGS-A OUs, computers, security groups and accounts."
Write-Host

$prereqs="The script prompts for ONE PASSWORD which is used for ALL service accounts","The script prompts for a Site Name used for a first child OU and inserted into","The security group names and prefixed to all the account names","The created OUs are [Protected From Accidental Deletion]"
displayActionList "NOTES" $prereqs

$prereqs="You must have account creation permissions to Active Directory","Script must be run on a domain controller"
displayActionList "PREREQS" $prereqs

$prereqs="The script processes the .CSV and .TXT files in the Scripts folder","Edit these files using NOTEPAD to make desired changes (CAREFUL of format)"
displayActionList "INPUT" $prereqs

displayLine
Write-Host

##########################################################################

"===== START ACCOUNT CREATION AND REPORT =====" | Write-log

$report = New-Item -ItemType file C:\scripts\reportDCGS.txt -force

##########################################################################
# Check for Servers
##########################################################################

$computerNames = get-content "_DCGScomputers.txt"

if ($computerNames -eq $NULL)
{
   $editList = get-Response "No Computers Specified - Edit List (Y/N)? " "CYAN" "N"
   if($editList -eq "Y")
   {
      Write-host -foregroundcolor "YELLOW" "`n Enter 1 server name per line - Save and Exit to Return to this script `n"
      Pause
      notepad "_DCGScomputers.txt" | out-null
   }
}

##########################################################################
# Get Default Password
##########################################################################

show-PasswordWarning
$securepwd = get-Password "Default Password for DCGS-A Accounts" "CYAN" 
$pwd = ConvertTo-PlainText($securepwd) 

"Retrieved Default Password for Service Accounts" | Write-log

##########################################################################
# Site OU
##########################################################################

$siteName = get-Response "Site Name "
$siteNameShort = $siteName.Replace(" ","")
$siteNameShort = $siteNameShort.ToLower()

##########################################################################
# Build OU Path for ADGroup and ADUser Creation
##########################################################################

$domain = $env:userdnsdomain

$fqdn = $domain.Split(".")

$OUpath = "OU=$topOU,"

foreach($dn IN $fqdn)
{
   $OUpath += "dc=" + $dn + ","
}

$OUpath = $OUpath.SubString(0,$OUpath.Length-1)

"OU Path: $OUpath" | Write-log

##########################################################################
# Create OU Structure
##########################################################################

"Top OU NAME: $topOU" | Write-log
"Site Name: $siteName" | Write-log
"Short Site Name : $siteNameShort" | Write-log

Write-Host
displayLine
Write-Host

displayMessage " Create Top OU ($topOU) "

$result = get-ADOrganizationalUnit -SearchScope OneLevel -filter "Name -eq `"$topOU`"" | Select-Object Name

if($result -eq $null)
{

   New-ADOrganizationalUnit -Name "$topOU" -Description "$topOU" -DisplayName "$topOU"
   displayStatus
   "CREATED OU: $topOU" | Write-log
   
}
else
{
   displayStatus 3
   "OU EXISTS: $topOU" | Write-log
}

add-content $report " Top OU: $topOU"


##########################################################################
# Create Site Name OU
##########################################################################

$exists = Get-ADOrganizationalUnit -Filter "Name -eq `"$siteName`"" -Searchbase "$OUpath" | Select-Object Name

if($exists -eq $null)
{
   New-ADOrganizationalUnit -Name "$siteName" -Path "$ouPath"
   "OU: $siteName OU Created" | Write-log
   add-content $report "    CREATE: $siteName"
}
else
{
   add-content $report "    EXISTS: $siteName"
   "OU: $siteName OU Exists" | Write-log
}

$OUpath = "OU=" + $siteName + "," + $OUpath

##########################################################################
# Create Child OUs
##########################################################################

displayMessage " Create OU Structure "

add-content $report " OU Structure "

$anyExist = "N"

Foreach ($ouLine IN $DCGS_OUS)
{
   $exists = Get-ADOrganizationalUnit -Filter "Name -eq `"$ouLine`"" -Searchbase "$OUpath" | Select-Object Name
   if($exists -eq $null)
   {
      New-ADOrganizationalUnit -Name "$ouLine" -Path "$ouPath"
      "OU: $ouLine Created" | Write-log
      add-content $report "    CREATE: $ouLine"
   }
   else
   {
      "OU: $ouLine Exists" | Write-log
      add-content $report "    EXISTS: $ouLine"
      $anyExist = "Y"
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

####################
# Create Computers
####################

$AnyExist = "N"

displayMessage " Create Computers "

add-content $report " Computers "

$computerFile = get-content "c:\scripts\_DCGScomputers.txt"

$computerPath = "OU=$topServersOU,$ouPath"

Foreach ($computerName IN $computerFile)
{

  $exists = get-ADComputer -Filter "Name -eq `"$computerName`""

  If($exists -eq $NULL)
  {
      new-ADcomputer -Name "$computerName" -DisplayName "$computerName" -Path "$computerPath"

      "Computers: $computerName Created" | Write-log

      add-content $report "    CREATE: $computerName"

   }
   else
   {
   
      $AnyExist = "Y"

      "Computers: $computerName Exists" | Write-log

      add-content $report "    EXISTS: $computerName"

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

#################################################
# Update Groups and Accounts Files with Site Name
#################################################

(Get-Content C:\Scripts\_DCGSgroups.csv) | Foreach-Object {$_ -replace "{SITENAME}", $siteName} | Set-Content C:\Scripts\_DCGSgroups.csv
(Get-Content C:\Scripts\_DCGSaccounts.csv) | Foreach-Object {$_ -replace "{SITENAME}", $siteName} | Set-Content C:\Scripts\_DCGSaccounts.csv
(Get-Content C:\Scripts\_DCGSaccounts.csv) | Foreach-Object {$_ -replace "{SITENAMESHORT}", $siteNameShort} | Set-Content C:\Scripts\_DCGSaccounts.csv

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

$groupFile = import-csv "c:\scripts\_DCGSgroups.csv"

$groupPath = "OU=$topGroupOU,$ouPath"

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

##############################
# Build list of existing users
##############################

displayMessage " Create Accounts "

add-content $report " Accounts "

$topUserGroupName = "DCGS-A " + $siteName + " Service Users"

# --------------------------------
# Get ID for the new Primary Group
# --------------------------------
$GroupSid = (Get-ADGroup -Identity $topUserGroupName -Properties PrimaryGroupID -ErrorAction Stop).SID
$PrimaryGroupID = $GroupSid.Value.Substring($groupsid.Value.LastIndexOf('-')+1)

$AnyExist = "N"

$defaultGroupPath = "CN=" + $topUserGroupName + ",OU=" + $topGroupOU + "," + $ouPath

$users = get-ADgroupmember "$defaultGroupPath" -recursive | Select-Object Name

$userPath = "OU=$topUserOU,$ouPath"

$userFile = import-csv "c:\scripts\_DCGSaccounts.csv"

Foreach ($csvline IN $userFile)
{
   $exists = "N"

   $UserName = $csvline.Name

   foreach ($userLine IN $users)
   {
      if($userLine.Name -eq "$UserName")
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
                -Path $userPath `
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

   If(($sgList.length -gt 0) -and ($exists -eq "N"))
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

   if($exists -eq "N")
   {
      # ------------------------
      # Change the Primary Group
      # ------------------------

      $UserDistinguishedName = (get-aduser -Identity $csvline.Name).DistinguishedName
      $set_result = Set-ADObject -Identity "$UserDistinguishedName" -replace @{PrimaryGroupID=$PrimaryGroupID}

      "Primary Group changed" | Write-log
   
      # -----------------------------------
      # Remove user from Domain Users Group
      # -----------------------------------

      $remove_result = remove-adgroupmember -Identity "Domain Users" -Members $csvline.Name -Confirm:$false    

      "User removed from Domain Users" | Write-log
   
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

$detailed = get-Response "View Detailed Report (Y/N)?" "CYAN" "N"

if($detailed -eq "Y")
{

   "Display Detailed Report" | Write-log

   $reportinfo = get-content c:\scripts\reportDCGS.txt

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

(Get-Content C:\Scripts\_DCGSgroups.csv) | Foreach-Object {$_ -replace $siteName, "{SITENAME}"} | Set-Content C:\Scripts\_DCGSgroups.csv
(Get-Content C:\Scripts\_DCGSaccounts.csv) | Foreach-Object {$_ -replace $siteName, "{SITENAME}"} | Set-Content C:\Scripts\_DCGSaccounts.csv
(Get-Content C:\Scripts\_DCGSaccounts.csv) | Foreach-Object {$_ -replace $siteNameShort, "{SITENAMESHORT}"} | Set-Content C:\Scripts\_DCGSaccounts.csv

"DONE" | Write-log

##########################################################################

