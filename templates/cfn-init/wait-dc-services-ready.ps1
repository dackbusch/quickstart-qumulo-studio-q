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
# This PowerShell script waits for the NTDS (NT Domain Services) and DNS services to be Running on a Domain Controller
#

Import-Module ServerManager

$status = (Get-Service -Name NTDS -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
while ($status -ne "Running")
{
  "AD Server: Checking NTDS"
  Start-Sleep 10
  $status = (Get-Service -Name NTDS -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
}
"AD Server NTDS Alive"

$status = (Get-Service -Name dns -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
while ($status -ne "Running")
{
  "AD Server: Checking DNS"
  Start-Sleep 10
  $status = (Get-Service -Name dns -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
}
"AD Server DNS Alive"

$status = (Get-Service -Name ADWS -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
while ($status -ne "Running")
{
  "AD Server: Checking ADWS"
  Start-Sleep 10
  $status = (Get-Service -Name ADWS -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
}
"AD Server ADWS Alive"

$status = (Get-Service -Name kdc -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
while ($status -ne "Running")
{
  "AD Server: Checking KDC"
  Start-Sleep 10
  $status = (Get-Service -Name kdc -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
}
"AD Server KDC Alive"

$status = (Get-Service -Name netlogon -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
while ($status -ne "Running")
{
  "AD Server: Checking NetLogon"
  Start-Sleep 10
  $status = (Get-Service -Name netlogon -ErrorAction SilentlyContinue | Select -ExpandProperty Status)
}
"AD Server NetLogon Alive"

$status = (Get-ADDomainController -Discover -Service "GlobalCatalog" -ErrorAction SilentlyContinue | Select -ExpandProperty Name)
while ($status -ne "DC")
{
  "AD Server: Checking GlobalCatalog"
	Start-Sleep 10
	$status = (Get-ADDomainController -Discover -Service "GlobalCatalog" -ErrorAction SilentlyContinue | Select -ExpandProperty Name)
}
"AD Server GlobalCatalog Alive"

$status = (Get-ADComputer dc -ErrorAction SilentlyContinue | Select -ExpandProperty Name)
while ($status -ne "DC")
{
  "AD Server: Checking AD is up"
  Start-Sleep 10
  $status = (Get-ADComputer dc -ErrorAction SilentlyContinue | Select -ExpandProperty Name)
}
"AD Server is Alive"
