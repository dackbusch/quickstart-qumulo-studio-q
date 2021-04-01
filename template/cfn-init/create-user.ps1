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
# This PowerShell script creates a user in an Active Directory Domain, and delegates the "add computers to the domain" rights to him
#
# It must be called with the name of the text file storing the user's information in the format (one value per line, no padding):
#   User
#   Password
#
[CmdletBinding()]
param(
  [Parameter(Mandatory=$True,Position=1)]
  [string]$UserFile,
  [int]$MaxComputersPerUser=100
)

if (-not (Test-Path $UserFile))
{
    Throw "File '$UserFile' does not exist, exiting script"
}

Import-Module ServerManager
Install-WindowsFeature RSAT-ADDS
$content = Get-Content $UserFile
$UserPS = $content[0]
$PassPS = ConvertTo-SecureString $content[1] -AsPlainText -Force
For ($i=1; $i -lt 21; $i++) {
	$UserName = $($UserPS) + $($i)
	New-ADUser -Name $UserName -AccountPassword $PassPS -PasswordNeverExpires:$false -ChangePasswordAtLogon:$true -Enabled:$true
}
