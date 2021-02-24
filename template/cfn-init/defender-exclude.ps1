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
# 
# This PowerShell script disables user access control,
# adds and exclusion to Defender for the Q: drive
# and finally it enables UAC
#
# Disable UAC
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000

# Disable Defender Realtime Scanning on Q: drive SMB mount for Qumulo
Add-MpPreference -ExclusionPath "Q:\"

# Enable UAC
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000005