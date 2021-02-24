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
# This PowerShell script enters A-records for the Qumulo Floating IP addresses with TTL=0 for Round Robin DNS
#
# It must be called with the name of the text file storing the A-record information in the format (one value per line, no padding):
#  ARecordName 	(DNS Name for the Record)
#  ZoneName 	(Domain Name, fully qualified)
#  TTL			(Time To Live, Zero for Round Robin)
#  IP0			(IP Addresses for Floating IPs, 3 per node, 4 nodes, 12 total)
#  IP1
#  IP2
#  IP3
#  IP4
#  IP5
#  IP6
#  IP7
#  IP8
#  IP9
#  IP10
#  IP11

[CmdletBinding()]
param(
  [Parameter(Mandatory=$True,Position=1)]
  [string]$ConfigFile
)

if (-not (Test-Path $ConfigFile))
{
    Throw "File '$ConfigFile' does not exist, exiting script"
}

$content = Get-Content $ConfigFile
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[3])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[4])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[5])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[6])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[7])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[8])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[9])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[10])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[11])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[12])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[13])" -TimeToLive "$($content[2])"
Add-DnsServerResourceRecordA -Name "$($content[0])" -ZoneName "$($content[1])" -AllowUpdateAny -IPv4Address "$($content[14])" -TimeToLive "$($content[2])"
