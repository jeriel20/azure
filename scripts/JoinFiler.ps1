##########################################################################
# Script Name   :  JoinFiler.ps1
# Version       :  7.0
# Creation Date :  15 April 2016
# Created By    :  Software Engineering Center (Aberdeen Proving Ground, MD)
# Prerequisites :  .NET FW 3.5, PowerShell 3.0
# Command Prompt:  powershell.exe -command "C:\Scripts\JoinFiler.ps1"
# Files         :  JoinFiler.ps1   (this file)
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
##########################################################################
#  Installation and Configuration Variables
##########################################################################

$scriptver = "7.0"
$reqlibver = "9.5"
$title = "Filer Domain Configuration"
$scriptFN = $MyInvocation.MyCommand.Name

##########################################################################
# Log filename used by the logging routine (Write-log)
##########################################################################

$currdate = get-date -format "yyyyMMdd"
$logfile = $ENV:COMPUTERNAME + "_JoinFiler_" + $currdate + ".log"

##########################################################################
# Include the library routines (DOT Source)
##########################################################################

if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
{
    Clear
    Write-Host -foregroundcolor Yellow "`n Missing BCCSLIB5R2.PS1 - Ensure this file is in the c:\Scripts Directory`n`n"
    Exit
}

. ./bccslib5r2.ps1


##########################################################################
#  Start Log
##########################################################################

"===== START INSTALLATION - $scriptFN =====" | Write-log

##########################################################################
# START PROCESSING
##########################################################################

$header = Set-Console $title
$header | Write-log
#setWindowSize

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

if(!(test-path ("C:\Scripts\$scriptFN")))
{
   Clear-Host
   Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
   "ERROR: JoinFiler.ps1 not in c:\scripts directory" | Write-Log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT
}

"JoinFiler.ps1 location ok" | Write-log


##########################################################################
# INTERNAL SCRIPT FUNCTIONS
##########################################################################

# This function will load ManageONTAP.dll library
function LoadAssembly
{
    $cur = (pwd).path;
    $library = $cur + "\ManageOntap.dll"
    if((test-path $library) -eq $true) {
        [System.Reflection.Assembly] $Assembly = [System.Reflection.Assembly]::LoadFrom($library);
        return;
    }
    $library = "ManageOntap.dll";
    if((test-path $library) -eq $true) {
        $parent = `split-path -path $cur`;
        $parent = `split-path -path $parent`;
        $parent = `split-path -path $parent`;
        $parent = $parent + "\lib\DotNet";
        $library = $parent + "\ManageOntap.dll";
    [System.Reflection.Assembly] $Assembly = [System.Reflection.Assembly]::LoadFrom($library);
    }
    else {
        write("ERROR:Unable to find ManageONTAP.dll.");
        exit(1);
    }
    trap [Exception] { 
      write-error $("ERROR:" + $_.Exception.Message); 
      exit(1); 
    }
}

##########################################################################
# Load the Assembly Library
##########################################################################

"Loading NetApp Assembly Library" | Write-log
Invoke-Expression LoadAssembly;

##########################################################################
# System Requirements
##########################################################################

displayMainHeader $title

displayString "This script will join a NetApp Filer to the domain.  To work properly, this script should be run on the primary Domain Controller VM after the ADpostinstall script has completed and rebooted the machine."
Write-Host

$prereqs="A Filer that has been configured on the public network","Filer CIFS Administrator credentials known","A configured Domain Controller","Domain login credentials"
displayActionList "Requirements" $prereqs

$prereqs="Synchronize the time on the Filer to this machine","Temporarily mount Filer share to local machine","Create DNS configuration files on the Filer share","Configure Filer for DNS connectivity","Run CIFS Setup on the Filer to join it to the domain"
displayActionList "This script will complete the following tasks" $prereqs

displayLine
Write-Host

##########################################################################
# See if the user wants to proceed with the installation
##########################################################################

$yn = get-Response "Do You Wish to Proceed (Y/N)?" "CYAN" "Y"

##########################################################################
# If YES than proceed with prompts and installation
##########################################################################

if($yn -ne "Y")
{ 
    Write-Host -foregroundcolor RED -backgroundcolor BLACK "`n`n *****     SNAP Installation Stopped !     *****`n`n"
    "USER EXIT: Did Not continue after Prereq Display" | Write-log
    "===== STOP INSTALLATION =====" | Write-log
    EXIT
}
else
{
    displayMainHeader $title
}

##########################################################################
# Prompt for Filer Login Information
##########################################################################

displaySubHeader "Filer Login Settings"
$loop = $true
while ( $loop )
{
	$fas = get-Response "Filer Hostname"

	displayMessage "Verifying host is reachable" CYAN

	if(get-PingStatus $fas) 
	{
		displayStatus
		"Filer hostname [$fas] is reachable" | Write-log
		$loop = $false
	}
	else
	{
		displayStatus 1
		displayString "$fas not reachable.  Verify that you can ping this hostname.  If you can ping by its IP address and not hostname, verify that a host record exists in DNS for this host." "Yellow"
		Write-Host
		"ERROR: Filer hostname [$fas] not reachable." | Write-Log
		"Re-prompt user for Filer hostname." | Write-Log
	}
}

$loop = $true
while ($loop)
{
    $loop = $false
    $fileruser = get-Response "Filer Username" "CYAN" "administrator"
    $securepwd = get-Password "Filer Password" "CYAN" "N"
    $filerpwd = ConvertTo-PlainText($securepwd)

    displayMessage "Verifying Filer credentials"
    "Checking Filer Credentials" | Write-log
    
    try
    {
        $s = New-Object NetApp.Manage.NaServer ($fas,"1","0");
        $s.SetAdminUser($fileruser,$filerpwd);

        $in = New-Object NetApp.Manage.NaElement("system-get-version");
        [NetApp.Manage.NaElement] $out = $s.InvokeElem($in); 
        $out = $s.InvokeElem($in); 
        $version = $out.GetChildContent("version");
    }
    catch
    {
        #Set the diaplay message to indicate an error
        displayStatus 2
        #Gather the error message
        $errResult = $_.Exception.Message
        #Print pretty messages for known error responses
        Write-Host -foregroundcolor YELLOW " Invalid credentials specified, please try again..."
        "Filer Credentials Entered Incorrectly" | Write-log
        #Set the loop flag back to true so we can keep looping
        $loop = $true
    }
}

displayStatus
"Filer Credentials Confirmed" | Write-log


##########################################################################
# Prompt for Network Information
##########################################################################

displaySubHeader "Domain Login Settings"

$fqdn = get-Response "Domain Address" "CYAN" $env:userdnsdomain

#If the DNS returned as a local loopback, we're running from a DC
# so we will recommend local machine IP instead
if (get-DNSip -eq "127.0.0.1")
{
	$dnsprimary = get-ipv4Response "Primary DNS IP" "CYAN" (get-Localip)
}
else
{
	$dnsprimary = get-ipv4Response "Primary DNS IP" "CYAN" (get-DNSip)
}

displayMessage "Verifying primary DNS availability " CYAN
if(get-PingStatus $dnsprimary)
{
	displayStatus
	"Primary DNS [$dnsprimary] is reachable" | Write-log
	$loop = $false
}
else
{
	displayStatus 1
	displayString " The primary DNS did not respond.  This script will continue to execute. If your filer does not properly join the domain upon completion, please check your DNS settings and either manually fix the settings or execute this script again with the proper primary DNS IP." "Yellow"
	Write-Host
	"Primary DNS [$dnsprimary] is not reachable.  Continuing anyway..." | Write-log
}

Write-Host -foregroundcolor "CYAN" " Secondary DNS IP (optional): " -nonewline
$dnssecondary = Read-Host

# If the user is providing additional DNS servers, keep allowing more (up to 8) 
# until they provide a blank entry and then stop asking for additional DNS servers.
if($dnssecondary)
{
	Write-Host
    Write-Host -foregroundcolor "CYAN" " Third DNS IP (optional): " -nonewline
    $dnsthird = Read-Host
}

$domainuser = get-Response "Domain Username" "CYAN" ("tsiadministrator" + '@' + $env:userdnsdomain)
$securepwd2 = get-Password "Domain Password" "CYAN"
$domainpwd = ConvertTo-PlainText($securepwd2)
"Domain Credentials Provided" | Write-log

##########################################################################
# Confirm Provided Information
##########################################################################

displayMainHeader $title

Write-Host -foregroundcolor WHITE " CONFIRM SETTINGS"
Write-Host -foregroundcolor GRAY  " ================"

Write-Host -foregroundcolor YELLOW "`n FILER Settings`n"
Write-Host -foregroundcolor WHITE  "`tHostname : $fas"
Write-Host -foregroundcolor WHITE  "`tUsername : $fileruser"

Write-Host -foregroundcolor YELLOW "`n DOMAIN Settings`n"
Write-Host -foregroundcolor WHITE  "`tDomain   : $fqdn"
Write-Host -foregroundcolor WHITE  "`tDNS IP   : $dnsprimary"
if ($dnssecondary) { Write-Host -foregroundcolor WHITE  "`tDNS IP 2 : $dnssecondary" }
if ($dnsthird) { Write-Host -foregroundcolor WHITE  "`tDNS IP 3 : $dnsthird" }
if ($dnsfourth) { Write-Host -foregroundcolor WHITE  "`tDNS IP 4 : $dnsfourth" }
if ($dnsfifth) { Write-Host -foregroundcolor WHITE  "`tDNS IP 5 : $dnsfifth" }
if ($dnssixth) { Write-Host -foregroundcolor WHITE  "`tDNS IP 6 : $dnssixth" }
if ($dnsseventh) { Write-Host -foregroundcolor WHITE  "`tDNS IP 7 : $dnsseventh" }
if ($dnseighth) { Write-Host -foregroundcolor WHITE  "`tDNS IP 8 : $dnseighth" }
Write-Host -foregroundcolor WHITE  "`tUsername : $domainuser"

displayLine

$go = get-Response "Do You Wish to Continue (Y/N)?" "CYAN" "Y"

If($go -ne "Y") 
{ 
   Write-Host "`n`n"
   "USER EXIT: Confirmation Display" | Write-log
   "===== STOP INSTALLATION =====" | Write-log
   EXIT 
}
"Settings Confirmed" | Write-log


##########################################################################
# Set the time on the Filer
##########################################################################

displayMainHeader $title

"Setting the time on the Filer" | Write-log
Write-Host
displayMessage "Synchronizing Filer time"
#Create a Unix formatted timestamp
$timeStamp = Get-Date -UFormat "%s"
#Clean up the timestamp by removing the extra microsecond values
$timeStamp = $timeStamp.Substring(0,$timeStamp.IndexOf("."))
"Local timestamp is $timeStamp" | Write-log
#Set the time on the Filer
$in = New-Object NetApp.Manage.NaElement("clock-set-clock");
$in.AddNewChild("is-utc-clock", "true")
$in.AddNewChild("time", "$timeStamp")
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);

# Trap any errors that occur
$errState = $false
trap [Exception]
{
    $errResult = $_.Exception.Message
    #Trap common warning message since it is not actually an exception
    if ($errResult.Contains("syncing source which will eventually override the time"))
    {
        continue
    }
    else  #An exception actually occurred!
    {
        $errState = $true
        displayStatus 2
        Write-Host
        Write-Host -foregroundcolor YELLOW " A fatal error has occurred!"
        Write-Host -foregroundcolor YELLOW " Reason: $errResult"
        exit
    }
}

if ($errState -eq $false)
{
    displayStatus
}

##########################################################################
# Check CIFS State (must be running to mount to a share)
##########################################################################

"Ensuring CIFS running in workgroup mode" | Write-log
$in = New-Object NetApp.Manage.NaElement("cifs-status");
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
$out = $s.InvokeElem($in);
$cifsstatus = $out.GetChildContent("status");

if($cifsstatus -eq "stopped") {
    displayMessage " Restarting CIFS"
    "CIFS Stopped: Restarting CIFS" | Write-log
    $in = New-Object NetApp.Manage.NaElement("cifs-start");
    [NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
    displayStatus
}


##########################################################################
# Create resolv.conf and nsswitch.conf files on the specified filer
##########################################################################

#First, ensure that there are no network sessions that may cause connection issues
net use * /delete /yes | out-null

displayMessage " Mounting Filer share to Z:\"
"Mounting Filer Share" | Write-log
$FASPath = "\\$fas\etc$"
$fascredential = new-object System.Management.Automation.PSCredential "$fas\$fileruser", $securepwd
$netpath = New-Object -com WScript.Network
$netpath.MapNetworkDrive("Z:", $FASPath, 0, "$fas\$fileruser", $fascredential.GetNetworkCredential().Password)
displayStatus

displayMessage " Generating resolv.conf on the Filer"
"Generating resolv.conf on the Filer" | Write-log
$fullresolvPath = "Z:\resolv.conf"
$info = New-Item -ItemType file "$fullresolvPath" -force
add-content $info "#Generated by the JoinFiler Script"
add-content $info ("nameserver " + $dnsprimary)
if ($dnssecondary) { add-content $info ("nameserver " + $dnssecondary) }
displayStatus

displayMessage " Generating nsswitch.conf on the Filer"
"Generating nsswitch.conf on the Filer" | Write-log
$fullnsswitchPath = "Z:\nsswitch.conf"
$info = New-Item -ItemType file "$fullnsswitchPath" -force
add-content $info "#Generated by the JoinFiler Script 
hosts: files dns dns 
passwd: files files files 
shadow: files files files 
group: files files files 
netgroup: files files files 
"
displayStatus

displayMessage " Unmounting Z:\ drive"
"Unmounting Filer Share" | Write-log
$netpath.RemoveNetworkDrive("Z:")
displayStatus


##########################################################################
# Set DNS options
##########################################################################

displayMessage " Setting DNS Options"
"Setting DNS Option - dns.domainname = $fqdn" | Write-log
$in = New-Object NetApp.Manage.NaElement("options-set");
$in.AddNewChild("name","dns.domainname")
$in.AddNewChild("value",$fqdn)
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
$out = $s.InvokeElem($in);

"Setting DNS Option - dns.enable = on" | Write-log
$in = New-Object NetApp.Manage.NaElement("options-set");
$in.AddNewChild("name","dns.enable")
$in.AddNewChild("value","on")
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
$out = $s.InvokeElem($in);

displayStatus


##########################################################################
# Check CIFS State (terminate if running)
##########################################################################

"Checking CIFS State" | Write-log
$in = New-Object NetApp.Manage.NaElement("cifs-status");
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
$out = $s.InvokeElem($in);
$cifsstatus = $out.GetChildContent("status");

if($cifsstatus -eq "started") {
   displayMessage " CIFS detected, terminating"
   "CIFS Running: Terminating CIFS" | Write-log
   $in = New-Object NetApp.Manage.NaElement("cifs-stop");
   [NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
   displayStatus
}


##########################################################################
# Execute CIFS Setup
##########################################################################

displayMessage " Running CIFS Setup"
"Running CIFS Setup" | Write-log

$in = New-Object NetApp.Manage.NaElement("cifs-setup");
$in.AddNewChild("auth-type", "ad")
$in.AddNewChild("domain-name", $fqdn)
$in.AddNewChild("login-user", $domainuser)
$in.AddNewChild("login-password", $domainpwd)
$in.AddNewChild("security-style", "multiprotocol")
$in.AddNewChild("server-name", $fas)
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
    
# Trap any errors that occur
$errState = $false
trap [Exception]
{
    #Set our error flag
    $errState = $true
    #Set the diaplay message to indicate an error
    displayStatus 2
    #Gather the error message
    $errResult = $_.Exception.Message
    #Print pretty messages for known error responses
    Write-Host -foregroundcolor YELLOW " "
    if ($errResult.Contains("password for this account is incorrect"))
    {
        Write-host -foregroundcolor YELLOW " CIFS has responded that your password was incorrect."
        Write-Host -foregroundcolor YELLOW " "
        Write-host -foregroundcolor WHITE " Please run this script again and provide the correct domain password."
    }
    elseif ($errResult.Contains("clocks are more than 5 minutes apart"))
    {
        "ERROR: Clock was not synchronized properly" | Write-log
        Write-host -foregroundcolor YELLOW " CIFS has responded that your filer and domain controller clocks are off."
        Write-Host -foregroundcolor YELLOW " "
        Write-Host -foregroundcolor WHITE " This script attempts to match the filer time to the domain controller"
        Write-Host -foregroundcolor WHITE " and must not be working correctly if you are seeing this error message."
        Write-Host -foregroundcolor WHITE " Sometimes the synchronization will not work on the first attempt and"
        Write-Host -foregroundcolor WHITE " running this script again may work the second time."
        Write-Host
        Write-host -foregroundcolor WHITE " If you see this error message multiple times, you may"
        Write-host -foregroundcolor WHITE " need to manually join this filer to your domain."
        Write-Host -foregroundcolor WHITE " "
        Write-Host -foregroundcolor WHITE " Please see the appendix of the BCCS Virtual Machine Deployment Guide"
        Write-Host -foregroundcolor WHITE " for instructions regarding this option."
    }
    else #Generic error response, unknown error message
    {
        "ERROR: $errResult" | Write-log
        Write-Host -foregroundcolor YELLOW " CIFS Setup returned error message: $errResult"
        Write-Host -foregroundcolor YELLOW " "
        Write-Host -foregroundcolor WHITE " If this error message does not help you identify the problem you"
        Write-Host -foregroundcolor WHITE " may need to manually join this Filer to your domain."
        Write-Host -foregroundcolor WHITE " "
        Write-Host -foregroundcolor WHITE " Please see the appendix of the BCCS Virtual Machine Deployment Guide"
        Write-Host -foregroundcolor WHITE " for instructions regarding this option."
    }
    continue
}
    
#If an error occurred, we're going to terminate this script
if ($errState -eq $true)
{
    Write-Host
    Write-Host -foregroundcolor RED " NOTE: Your Filer has NOT been joined to the domain!"
    exit
}
else
{
    displayStatus 0
}
    

##########################################################################
# Start CIFS (run it)
##########################################################################

displayMessage " Starting CIFS"
"Starting CIFS" | Write-log
$in = New-Object NetApp.Manage.NaElement("cifs-start");
[NetApp.Manage.NaElement] $out = $s.InvokeElem($in);
displayStatus 0

Write-Host -foregroundcolor WHITE ("`n Your Filer named " + $fas + " is now joined to domain " + $fqdn + "`n")
"===== INSTALLATION COMPLETE !!! =====" | Write-log
