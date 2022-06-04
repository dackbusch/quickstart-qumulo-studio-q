# Copyright (c) 2020 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

[CmdletBinding()]
param(
  [Parameter(Mandatory=$True,Position=1)]
  [string]$WorkstationConf
)

if (-not (Test-Path $WorkstationConf))
{
    Throw "File '$WorkstationConf' does not exist, exiting script"
}

$content = Get-Content $WorkstationConf

$LOG_FILE = "C:\Teradici\provisioning.log"
$PCOIP_AGENT_LOCATION_URL = $content[0]
$PCOIP_AGENT_FILENAME = ""
$pcoip_registration_code = $content[1]
$admin_password = $content[2]
$ad_service_account_password = $content[3]
$domainname = $content[4]
$adServiceAccountUsername = $content[5]
$FloatDNSName = $content[6]
$SMBShareName = $content[7]

$global:restart = $false

# Retry function, defaults to trying for 5 minutes with 10 seconds intervals
function Retry ([scriptblock]$Action,$Interval = 10,$Attempts = 30) {
  $Current_Attempt = 0

  while ($true) {
    $Current_Attempt++
    $rc = $Action.Invoke()

    if ($?) { return $rc }

    if ($Current_Attempt -ge $Attempts) {
      Write-Error "Failed after $Current_Attempt attempt(s)." -InformationAction Continue
      throw
    }

    Write-Information "Attempt $Attempt failed. Retry in $Interval seconds..." -InformationAction Continue
    Start-Sleep -Seconds $Interval
  }
}

function PCoIP-Agent-is-Installed {
  Get-Service "PCoIPAgent"
  return $?
}

function PCoIP-Agent-Install {
  "################################################################"
  "Install PCoIP Agent"
  "################################################################"
  if (PCoIP-Agent-is-Installed) {
    "PCoIP Agent already installed."
    return
  }

  $agentInstallerDLDirectory = "C:\Teradici"
  if (![string]::IsNullOrEmpty($PCOIP_AGENT_FILENAME)) {
    "Using user-specified PCoIP Agent filename..."
    $agent_filename = $PCOIP_AGENT_FILENAME
  } else {
    "Using default latest PCoIP Agent..."
    $agent_latest = $PCOIP_AGENT_LOCATION_URL + "latest-graphics-agent.json"
    $wc = New-Object System.Net.WebClient

    "Checking for the latest PCoIP Agent version from $agent_latest..."
    $string = Retry -Action { $wc.DownloadString($agent_latest) }

    $agent_filename = $string | ConvertFrom-Json | Select-Object -ExpandProperty "filename"
  }
  $pcoipAgentInstallerUrl = $PCOIP_AGENT_LOCATION_URL + $agent_filename
  $destFile = $agentInstallerDLDirectory + '\' + $agent_filename
  $wc = New-Object System.Net.WebClient

  "Downloading PCoIP Agent from $pcoipAgentInstallerUrl..."
  Retry -Action { $wc.DownloadFile($pcoipAgentInstallerUrl,$destFile) }
  "Teradici PCoIP Agent downloaded: $agent_filename"

  "Installing agent..."
  Start-Process -FilePath $destFile -ArgumentList "/S /nopostreboot _?$destFile" -Passthru -Wait

  if (!(PCoIP-Agent-is-Installed)) {
    "ERROR: Failed to install PCoIP Agent"
    exit 1
  }

  "Teradici PCoIP Agent installed successfully"
  $global:restart = $true
}

function PCoIP-Agent-Register {
  "################################################################"
  "Register PCoIP Agent"
  "################################################################"
  Set-Location 'C:\Program Files\Teradici\PCoIP Agent'

  "Checking for existing PCoIP License..."
  & .\pcoip-validate-license.ps1
  if ($LastExitCode -eq 0) {
    "Valid license found."
    return
  }

  # License regisration may have intermittent failures
  $Interval = 10
  $Timeout = 600
  $Elapsed = 0

  do {
    $Retry = $false
    & .\pcoip-register-host.ps1 -RegistrationCode $pcoip_registration_code
    # the script already produces error message

    if ($LastExitCode -ne 0) {
      if ($Elapsed -ge $Timeout) {
        "Failed to register PCoIP Agent."
        exit 1
      }

      "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
      $Retry = $true
      Start-Sleep -Seconds $Interval
      $Elapsed += $Interval
    }
  } while ($Retry)

  "PCoIP Agent Registered Successfully"
}

function Join-Domain {
  "################################################################"
  "Join Domain"
  "################################################################"
  $obj = Get-WmiObject -Class Win32_ComputerSystem

  if ($obj.PartOfDomain) {
    if ($obj.Domain -ne "$domainname") {
      "ERROR: Trying to join '$domainname' but computer is already joined to '$obj.Domain'"
      exit 1
    }

    "Computer already part of the '$obj.Domain' domain."
    return
  }

  "Computer not part of a domain. Joining $domainname..."

  $username = "$adServiceAccountUsername" + "@" + "$domainname"
  $password = ConvertTo-SecureString $ad_service_account_password -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ($username,$password)

  # Read "Name" tag for hostname
  $host_name = hostname

  # Looping in case Domain Controller is not yet available
  $Interval = 10
  $Timeout = 1200
  $Elapsed = 0 

  do {
    try {
      $Retry = $false
      # Don't do -Restart here because there is no log showing the restart
      # Add-Computer -ComputerName $host_name -NewName $instance_id -DomainName $domainname -Credential $cred -Verbose -Force -ErrorAction Stop
      Add-Computer -ComputerName $host_name -DomainName $domainname -Credential $cred -Verbose -Force -ErrorAction Stop      
    }

    # The same Error, System.InvalidOperationException, is thrown in these cases:
    # - when Domain Controller not reachable (retry waiting for DC to come up)
    # - when password is incorrect (retry because user might not be added yet)
    # - when computer is already in domain
    catch [System.InvalidOperationException]{
      $PSItem

      # Sometimes domain join is successful but renaming the computer fails
      # if ($PSItem.FullyQualifiedErrorId -match "FailToRenameAfterJoinDomain,Microsoft.PowerShell.Commands.AddComputerCommand") {
      #  Retry -Action { Rename-Computer -NewName "$instance_id" -DomainCredential $cred }
      #  break
      # }

      if ($PSItem.FullyQualifiedErrorId -match "AddComputerToSameDomain,Microsoft.PowerShell.Commands.AddComputerCommand") {
        "WARNING: Computer already joined to domain."
        break
      }

      if ($Elapsed -ge $Timeout) {
        "Timeout reached, exiting ..."
        exit 1
      }

      "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
      $Retry = $true
      Start-Sleep -Seconds $Interval
      $Elapsed += $Interval
    }
    catch {
      $PSItem
      exit 1
    }
  } while ($Retry)

  $obj = Get-WmiObject -Class Win32_ComputerSystem
  if (!($obj.PartOfDomain) -or ($obj.Domain -ne "$domainname")) {
    "ERROR: failed to join '$domainname'"
    exit 1
  }

  "Successfully joined '$domainname'"
  $global:restart = $false
}


if (Test-Path $LOG_FILE) {
  Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

  "$LOG_FILE exists. Assume this startup script has run already."

  # TODO: Find out why DNS entry is not always added after domain join.
  # Sometimes the DNS entry for this workstation is not added in the Domain
  # Controller after joining the domain. Explicitly adding this machine to the DNS
  # after a reboot. Doing this before a reboot would add a DNS entry with the old
  # hostname.
  "Registering with DNS..."
  do {
    Start-Sleep -Seconds 5
    Register-DnsClient
  } while (!$?)
  "Successfully registered with DNS."

  exit 0
}

Start-Transcript -Path $LOG_FILE -Append -IncludeInvocationHeader

"Script running as user '$(whoami)'"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  "Running as Administrator"
} else {
  "Not running as Administrator"
}

"Changing Administrator Password"
net user Administrator $admin_password /active:yes

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#Now join the domain
Join-Domain

"Adding domain users to remote desktop users"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "Domain Users"
Add-LocalGroupmember -Group "Administrators" -Member "Domain Users"

#PCoIP-Agent-Install

#PCoIP-Agent-Register

"Install Chrome"
$Path = $env:TEMP
$Installer = "chrome_installer.exe"
Invoke-WebRequest "http://dl.google.com/chrome/chrome_installer.exe" -OutFile $Path\$Installer
Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait
Remove-Item $Path\$Installer

"Disable IE ESC"
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
Rundll32 iesetup.dll, IEHardenLMSettings,1,True
Rundll32 iesetup.dll, IEHardenUser,1,True
Rundll32 iesetup.dll, IEHardenAdmin,1,True

"Install S3 Browser"
$Path = $env:TEMP
$Installer = "s3browser-9-5-5.exe"
Invoke-WebRequest "https://netsdk.s3.amazonaws.com/s3browser/9.5.5/s3browser-9-5-5.exe" -OutFile $Path\$Installer
Start-Process -FilePath $Path\$Installer -Args "/VERYSILENT /install /NORESTART" -Verb RunAs -Wait
Remove-Item $Path\$Installer

"Install 7-Zip"
$Path = $env:TEMP
$Installer = "7z2107-x64.msi"
Invoke-WebRequest "https://www.7-zip.org/a/7z2107-x64.msi" -OutFile $Path\$Installer
Start-Process msiexec.exe -Wait -ArgumentList "/I $Path\$Installer /quiet" -Verb RunAs
Remove-Item $Path\$Installer

#Install Latest Nvidia Drivers
$PSScriptRoot
& $PSScriptRoot\install-gpu-drivers.ps1

"Enable Audio Service"
Set-Service -Name Audiosrv -StartupType Automatic -Status Running

"Add Link to Qumulo UI"
$WshShell = New-Object -comObject WScript.Shell
$path = "C:\Users\Public\Desktop\Qumulo-UI.url"
$targetpath = "https://" + $FloatDNSName + "." + $domainname
$iconlocation = "C:\cfn\install\qumulo.ico"
$iconfile = "IconFile=" + $iconlocation
$Shortcut = $WshShell.CreateShortcut($path)
$Shortcut.TargetPath = $targetpath
$Shortcut.Save()
Add-Content $path "HotKey=0"
Add-Content $path "$iconfile"
Add-Content $path "IconIndex=0"

"Add Link to Qumulo KB"
$WshShell2 = New-Object -comObject WScript.Shell
$path2 = "C:\Users\Public\Desktop\Qumulo-KB.url"
$targetpath2 = "https://care.qumulo.com"
$iconlocation2 = "C:\cfn\install\qumulo.ico"
$iconfile2 = "IconFile=" + $iconlocation2
$Shortcut2 = $WshShell2.CreateShortcut($path2)
$Shortcut2.TargetPath = $targetpath2
$Shortcut2.Save()
Add-Content $path2 "HotKey=0"
Add-Content $path2 "$iconfile2"
Add-Content $path2 "IconIndex=0"

"Add Link for SMB Share on Qumulo"
$WshShell3 = New-Object -comObject WScript.Shell
$path3 = "C:\Users\Public\Desktop\adobe-projects.url"
$targetpath3 = "\\" + $FloatDNSName + "\" + $SMBShareName
$iconlocation3 = "C:\cfn\install\disk.ico"
$iconfile3 = "IconFile=" + $iconlocation3
$Shortcut3 = $WshShell3.CreateShortcut($path3)
$Shortcut3.TargetPath = $targetpath3
$Shortcut3.Save()
Add-Content $path3 "HotKey=0"
Add-Content $path3 "$iconfile3"
Add-Content $path3 "IconIndex=0"

"Delete Extraneous Shortcuts"
Remove-Item "C:\Users\Public\Desktop\Teradici Website.url"

"Initialize, partition, and format the local NVME drive"

$disk = Get-Disk | where-object PartitionStyle -eq "RAW"  
Initialize-Disk -Number $disk.Number -PartitionStyle MBR -confirm:$false  
New-Partition -DiskNumber $disk.Number -UseMaximumSize -IsActive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "NVME Disk" -confirm:$False  
Set-Partition -DiskNumber $disk.Number -PartitionNumber 1 -NewDriveLetter D  

"Restarting Workstation"
Restart-Computer -Force
