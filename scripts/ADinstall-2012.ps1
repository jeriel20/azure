﻿ #requires -version 3


 $scriptver = "10.0"
 $reqlibver = "9.5"
 $title = "Active Directory Installation"
 
 
 # A value of 5 specifies Windows Server 2012
 $level = "5"
 
 ##########################################################################
 # Log filename used by the logging routine (Write-log)
 ##########################################################################
 
 $currdate = get-date -format "yyyyMMdd"
 $logfile = $ENV:COMPUTERNAME + "_install_" + $currdate + ".log"
 
 ##########################################################################
 # Include the library routines (DOT Source)
 ##########################################################################
 
 if(!(test-path "c:\Scripts\bccslib5r2.ps1"))
 {
     Clear
     Write-Host -foregroundcolor Yellow "`n Missing bccslib5r2.ps1 - Ensure this file is in the c:\Scripts Directory`n`n"
     Exit
 }
 
 set-location -Path C:\Scripts\
 
 . ./bccslib5r2.ps1
 
 
 if([int]$BCCSLibver -lt [int]$reqlibver)
 {
     Clear
     Write-Host -foregroundcolor Yellow "`n Incorrect BCCS Library - Must be Version $reqlibver or Higher`n`n"
     Exit
 }
 
 ##########################################################################
 #  Start Log
 ##########################################################################
 
 "===== START INSTALLATION - ADinstall-2012.ps1 =====" | Write-log
 
 ##########################################################################
 # START PROCESSING
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
 
 # checks for script in c:\scripts
 if(!(test-path "C:\Scripts\ADinstall-2012.ps1"))
 {
    Clear-Host
    Write-Host -foregroundcolor YELLOW "`n Script must be stored and executed from C:\Scripts directory!`n`n"
    "ERROR: ADinstall-2012.ps1 not in c:\scripts directory" | Write-Log
    "===== STOP INSTALLATION =====" | Write-log
    EXIT
 }
 
 "ADinstall-2012.ps1 location ok" | Write-log
 
 ##########################################################################
 # Verify Windows Server 2012 or 2016
 ##########################################################################
 
 $OSver = get-OS
 $versions = @("W2012R2","W2016")
 
 If($OSver -in $versions)
 {
    "OS VERSION: $OSver" | Write-log
 }
 else
 {
    Clear-Host
    Write-Host -foregroundcolor YELLOW "`n This script requires Windows Server 2012 R2 or Windows Server 2016`n`n"
    "INVALID OS: $OSver" | Write-log
    EXIT
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
 

    # -----------------------
    # Get PUBLIC NIC Settings
    # -----------------------
 
    Write-Host
    Write-Host "PUBLIC NIC Settings"
 
    $IPpublicAddress = "10.0.0.4"
    $IPpublicMask = "255.255.255.0"
    $defaultGW =  "10.0.0.1"
    # TODO: public default gw could be different from $defaultGW
    $IPpublicGateway =  $defaultGW 
 
    "IP Address: $IPpublicAddress" | Write-log
    "Netmask: $IPpublicMask" | Write-log
    "Gateway: $IPpublicGateway" | Write-log
 
    # ---------------------------
    # Get Domain NetBIOS and FQDN
    # ---------------------------
 
    Write-Host
    # TODO: add to anwswer file
    $DOMAIN_NAME = "2BDE7ID"
    Write-Host "DOMAIN Settings"
    $defaultfqdn = $DOMAIN_NAME + ".ARMY.MIL"
    $fqdn = $defaultfqdn
    "NetBIOS Name: $DOMAIN_NAME" | Write-log
    "FQDN: $fqdn" | Write-log
 
    # --------------------------------
    # Safe Mode Password
    # --------------------------------

    $pwd = "Fh5@#250@!1cgI#"
 
 {
 
   
 
    $gc  = "Y"
 
    # ------------
    # DNS Server ?
    # ------------
 
    $dns = "Y"
 
    # --------------------------------
    # SAFE MODE Password
    # --------------------------------
 
    
 
    if( $gc -ne "Y" ) { $gc  = $true  } else { $gc  = $false }
    if( $dns -ne "Y") { $dns = $false } else { $dns = $true  } 
    
    Write-host " "
 
 }
 
 $ADavail = (get-WindowsFeature AD-Domain-Services).InstallState
    
 
 
 if($ADavail -eq "Installed")
 {
    displayStatus 5
    "AD DOMAIN SERVICES Already Installed" | Write-log
 }
 elseif($ADavail -eq "Available")
 {
    $installResult = Install-WindowsFeature –Name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    If($installResult.ExitCode -ne "Success")
     {
         Write-Host "Successfully Installed AD"
     }
 }
 else
 {
    Write-Host "ERROR INSTALLING AD Domain Services ($ADavail)"
    "ERROR INSTALLING AD Domain Services ($ADavail)" | Write-log
    Exit
 }
 
 Import-Module ADDSDeployment
 
 sleep 5
 
 $firstDC = "Y"
 
 if($firstDC -eq "Y")
 {
    $newDC = New-Item c:\scripts\firstDC.txt -type file -force
    Write-Host "Configuring first DC"
    $installResult = Install-ADDSForest -SafeModeAdministratorPassword (ConvertTo-SecureString "$pwd" -AsPlainText -Force) -DomainMode "$level" -DomainName "$fqdn" -DomainNetbiosName "$netname" -ForestMode "$level" -InstallDns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
    If($installResult.Status -eq "Success") { displayStatus } else { displayStatus 2 }
 
 }
 else
 {
    displayMessage " Configuring SECONDARY Domain Controller " "CYAN"
    $fqdn = $env:userdnsdomain
    $installResult = Install-ADDSDomainController $pwd -DomainName "$fqdn" -NoGlobalCatalog:$gc -InstallDns:$dns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -Force
    If($installResult.Status -eq "Success") { displayStatus } else { displayStatus 2 }
 }
  
 