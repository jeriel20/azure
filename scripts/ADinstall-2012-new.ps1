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
# A value of 0 specifies Windows 2000
# A value of 2 specifies Windows Server 2003
# A value of 3 specifies Windows Server 2008
# A value of 4 specifies Windows Server 2008 R2
# A value of 5 specifies Windows Server 2012
##########################################################################
$level = "5"
##########################################################################
Write-Host "Running bccslib5r2.ps1"
. ./bccslib5r2.ps1
##########################################################################
Write-Host "Setting Domain Information"
$netname = "3SBCT2ID"
$defaultfqdn = $netname + ".ARMY.MIL"
$fqdn = "$defaultfqdn"
##########################################################################
Write-Host "Setting Secure Password"
$securepwd = "Fh5@#250@!1cgI#"
$pwd = ConvertTo-PlainText($securepwd)
##########################################################################
Write-Host "Installing Windows Feature: AD-Domain-Services"
$installResult = Install-WindowsFeature –Name AD-Domain-Services -IncludeManagementTools -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
If($installResult.ExitCode -ne "Success")
{
    Write-Host "`n`tAD Domain Services Installation FAILED`n`n"
    EXIT
}
##########################################################################
Import-Module ADDSDeployment
sleep 5
Write-Host "Installing AD Forest & DNS"
$installResult = Install-ADDSForest -SafeModeAdministratorPassword $securePWD -DomainMode "$level" -DomainName "$fqdn" -DomainNetbiosName "$netname" -ForestMode "$level" -InstallDns -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force
If($installResult.Status -eq "Success") { displayStatus } else {Write-Host "`n`tAD DC Install Failed`n`n"}
Write-Host "Script Complete"
