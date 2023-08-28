<#
.SYNOPSIS
    Script to detect BitLocker KeyProtector type = "TpmPin" on all volumes of a Windows device.
    Functions are flexible, can be easily modified to use it for different KeyProtectorType

.DESCRIPTION
    Scans all volumes on a Windows device to identify if any volume is encrypted with a BitLocker KeyProtector type of "TpmPin".
    Executes the following tasks:
    1. Checks if the script is running as an Administrator.
    2. Retrieves all volumes on the device.
    3. Iterates through each volume to check its BitLocker status.
    4. If any volume is found with a KeyProtector type of "TpmPin", the script exits with a status code of 1.

    Note: This script must be run as an Administrator to access BitLocker settings.

.NOTES
    Last Modified   : August 27th, 2023
    Author          : Manuel Nieto
    Prerequisite    : Run as Administrator

    Script was designed to be used as detection script in Microsoft Intune "Remediations".

.LINK
    For more information, visit https://github.com/jmanuelng/MEM_ChangeBitlockerKeyProtectorType#readme
#>

#region Initialize

# Initialize a variables and clean errors
$Error.Clear()
$executionSummary = ""
$execStatus = 0  # Initialize execution status. 0: OK, 1: TpmPin Found, -1: Error

#endregion Initialize

#Region Functions

function Get-BitLockerKeyProtectorInfo {
    <#
    .SYNOPSIS
        Retrieves the types of BitLocker key protectors for a given volume.

    .DESCRIPTION
        This function uses the Get-BitLockerVolume cmdlet to query the BitLocker configuration
        of a specified volume (MountPoint). It returns an array of key protector types in use
        for that volume.

    .PARAMETER MountPoint
        The drive letter or mount point of the volume to query. For example, "C:".

    .EXAMPLE
        Get-BitLockerKeyProtectorInfo -MountPoint "C:"
        Returns the key protector types for the C: drive.

    .EXAMPLE
        Get-BitLockerKeyProtectorInfo -MountPoint "D:"
        Returns the key protector types for the D: drive.

    .NOTES
        Prerequisite   : Run as Administrator

    #>
    [CmdletBinding()]
    Param (
        # The MountPoint parameter specifies the drive letter or mount point to query.
        [Parameter(Mandatory=$true)]
        [string]$MountPoint
    )

    # Initialize an empty array to hold the key protector types.
    $keyProtectorTypes = @()

    # Check if running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "You must run this script as an Administrator."
        return $keyProtectorTypes
    }

    # Use the Get-BitLockerVolume cmdlet to get BitLocker information for the specified MountPoint.
    try {
        $bitlockerInfo = Get-BitLockerVolume -MountPoint $MountPoint
    } catch {
        Write-Host "An error occurred while fetching BitLocker information: $_"
        return $keyProtectorTypes
    }

    # Check if BitLocker is enabled on the specified MountPoint.
    if ($null -eq $bitlockerInfo) {
        Write-Host "BitLocker is not enabled on the specified MountPoint: $MountPoint"
        return $keyProtectorTypes
    }

    # Loop through each key protector and add its type to the array.
    try {
        foreach ($keyProtector in $bitlockerInfo.KeyProtector) {
            $keyProtectorTypes += $keyProtector.KeyProtectorType
        }
    } catch {
        Write-Host "An error occurred while retrieving key protector types: $_"
        return $keyProtectorTypes
    }

    # Return the array of key protector types.
    return $keyProtectorTypes
}

function WriteAndExitWithSummary {
    <#
    .SYNOPSIS
        Writes a summary of the script's execution to the console and then exits the script with a specified status code.

    .DESCRIPTION
        This function takes a status code and a summary string as parameters. It writes the summary along with the current date and time to the console using Write-Host. 
        After writing the summary, it exits the script with the given status code. If the given status code is below 0 (negative) it changes exit status code to 0

    .PARAMETER StatusCode
        The exit status code to be used when exiting the script. 
        0: OK
        1: TpmPin Found
        Other: WARNING

    .PARAMETER Summary
        The summary string that describes the script's execution status. This will be written to the console.

    .EXAMPLE
        WriteAndExitWithSummary -StatusCode 0 -Summary "All volumes checked, no TpmPin found."
        Writes "All volumes checked, no TpmPin found." along with the current date and time to the console and exits with status code 0.

    .EXAMPLE
        WriteAndExitWithSummary -StatusCode 1 -Summary "TpmPin found on volume C:."
        Writes "TpmPin found on volume C:." along with the current date and time to the console and exits with status code 1.

    .NOTES
        Last Modified: August 27, 2023
        Author: Manuel Nieto
    #>

    param (
        [int]$StatusCode,
        [string]$Summary
    )
    
    # Combine the summary with the current date and time.
    $finalSummary = "$([datetime]::Now) = $Summary"
    
    # Determine the prefix based on the status code.
    $prefix = switch ($StatusCode) {
        0 { "OK" }
        1 { "FAIL" }
        default { "WARNING" }
    }
    
    # Easier to read in log file
    Write-Host "`n`n"

    # Write the final summary to the console.
    Write-Host "$prefix $finalSummary"
    
    # Easier to read in log file
    Write-Host "`n`n"

    # Exit the script with the given status code.
    if ($StatusCode -lt 0) {$StatusCode = 0}
    Exit $StatusCode
}


#endregion Functions

#region Main

# Easier to read in log file
Write-Host "`n`n"

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You must run this script as an Administrator."
    $executionSummary += "No admin rights. "
    $execStatus = 1
    WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary
}

# Fetch all volumes
try {
    $volumes = Get-Volume
} catch {
    $executionSummary += "Error fetching volumes. "
    $execStatus = 1
    WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary
}

# Loop through each volume to check BitLocker KeyProtector types.
foreach ($volume in $volumes) {
    # Only proceed if the volume has a DriveLetter and it's a Fixed drive
    if (($null -ne $volume.DriveLetter) -and ($volume.DriveType -eq "Fixed")) {
        $mountPoint = $volume.DriveLetter + ":"
        
        # Check if the volume is encrypted with BitLocker
        $bitlockerStatus = Get-BitLockerVolume -MountPoint $mountPoint
        if ($bitlockerStatus.ProtectionStatus -eq "On") {
            try {
                $keyProtectorTypes = Get-BitLockerKeyProtectorInfo -MountPoint $mountPoint
            } catch {
                $executionSummary += "Error fetching BitLocker info for $mountPoint. "
                $execStatus = -2
                continue
            }

            # Check if the volume has TpmPin as a KeyProtector type.
            if ($keyProtectorTypes -contains "TpmPin") {
                $executionSummary += "TpmPin found on $mountPoint. "
                $execStatus = 1
                break
            } else {
                $executionSummary += "$mountPoint does not use TpmPin. "
                $execStatus = 0
            }
        }
    }
}

# Final status log based on the execution status.
WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary

#endregion Main
