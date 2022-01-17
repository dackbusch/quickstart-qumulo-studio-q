# 
# AWS CloudFormation Windows HPC Template
# 
# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
# 
#  http://aws.amazon.com/apache2.0
# 
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
# 

# 
# This PowerShell script changes the password of the local administrator 
#
# It must be called with the name of the text file storing the new password for the administrator
#
[CmdletBinding()]
param(
  [Parameter(Mandatory=$True,Position=1)]
  [string]$PasswordFile
)

if (-not (Test-Path $PasswordFile))
{
    Throw "File '$PasswordFile' does not exist, exiting script"
}

Import-Module ServerManager
Install-WindowsFeature RSAT-ADDS
$content = Get-Content $PasswordFile
$username = $content[0]
$password = ConvertTo-SecureString $content[1] -AsPlainText -Force

$status = ""
while ($status -ne "True")
{
  "Creating AD Service Account"
  New-AdUser -Name $username -AccountPassword $password -Enabled $True -PasswordNeverExpires $True
  Start-Sleep 10  
  $status = (Get-AdUser -Filter "Name -eq '$username'" -ErrorAction SilentlyContinue | select -ExpandProperty Enabled)  
}

Add-ADGroupMember -Identity "Domain Admins" -Members $username
