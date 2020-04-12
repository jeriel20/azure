##########################################################################
# Script Name   :  VARIES
# Version       :  1.0
# Creation Date :  1 October 2014
# Created By    :  Software Engineering Center (Aberdeen Proving Ground, MD)
# Prerequisites :  PowerShell 2.0
# Paths         :  Files must be located in C:\Scripts directory
##########################################################################
# Instructions: This script is used to execute either a -2008 or a
#				-2012 named version of itself depending on the current OS.
#
#				For example, if this script is named SQLInstall.ps1
#				it will execute SQLInstall-2008.ps1 in a 2008 environment
#				or the SQLInstall-2012.ps1 script in a 2012 environment.
##########################################################################

#Log the currently executing script name
$scriptName = ($MyInvocation.MyCommand.Name).trim()
#Remove the .ps1 extension
$scriptName = $scriptName.Substring(0,$scriptName.Length - 4)

Function get-OS()
{
   # This is for Windows 8.1/2012 R2
   # (Get-CimInstance Win32_OperatingSystem).Version

   $QueryOS = Gwmi Win32_OperatingSystem
   $QueryOS = $QueryOS.Version 

   If     ($QueryOS.contains("6.1.7601")) { $OS = "W2K8R2SP1" }
   elseif ($QueryOS.contains("6.1"))      { $OS = "W2K8R2"    }
   elseif ($QueryOS.contains("6.0"))      { $OS = "W2K8"      }
   elseif ($QueryOS.contains("6.2.9200")) { $OS = "W2012"     }
   elseif ($QueryOS.contains("6.3.9600")) { $OS = "W2012R2"   }
   else                                   { $OS = "Other"     }

   return $OS
}

#Get the current OS
$curOS = get-OS

#Is it 2012R2?
if ($curOS -eq "W2012R2")
{
	#Prepare the 2012R2 script
	$scriptToLaunch = "$scriptName-2012.ps1"
}
else
{
	#Launch the 2008R2 script
	$scriptToLaunch = "$scriptName-2008.ps1"
}

. ./"$scriptToLaunch"
