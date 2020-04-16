#requires -version 3
##########################################################################
# Script Name   :  ADinstall-2012-new.ps1
# Version       :  10.0
# Creation Date :  12-APR-2020
# Prerequisites :  Windows 2012, PowerShell 3.0, .NET 4.5
# Files         :  ADinstall-2012.ps1   (this file)
#               :  bccslib5r2.ps1
# Paths         :  Files must be located in C:\Scripts directory
# Version 10.0  :  2014/11/25
#                  DEL: dcpromo.exe code (all cmdlets)
##########################################################################
##########################################################################
# Forest/Domain Functional Level Values
# A value of 6 specifies Windows Server 2012R2
# A value of 7 specifies Windows Server 2016
##########################################################################
$runlocation = "c:\scripts"
mkdir $runlocation
cd $runlocation

$level = "6"
Write-Host "Setting Domain Information"
$netname = "3SBCT2ID"
$fqdn = $netname + ".ARMY.MIL"
##########################################################################
Write-Host "Setting Secure Password"
$securePWD = convertto-securestring "Fh5@#250@!1cgI#" -AsPlainText -Force
##########################################################################
Write-Host "Installing AD-Domain-Services"
Install-WindowsFeature –Name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
##########################################################################
Import-Module ADDSDeployment
sleep 5
Write-Host "Installing AD Forest & DNS"
Install-ADDSForest -SafeModeAdministratorPassword $securePWD -DomainMode "$level" -DomainName "$fqdn" -DomainNetbiosName "$netname" -ForestMode "$level" -InstallDns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -NoRebootOnCompletion -Force
Write-Host "Script Complete"
