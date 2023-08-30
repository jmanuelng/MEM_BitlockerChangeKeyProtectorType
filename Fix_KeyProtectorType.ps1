
<#
.SYNOPSIS
    Main script to update BitLocker KeyProtector types for all volumes on a Windows device.

.DESCRIPTION
    This script checks all volumes on a Windows device and changes the KeyProtector Type from TpmPin to Tpm
    for all encrypted volumes. It uses two functions: Set-BitLockerKeyProtectorType and Get-BitLockerKeyProtectorInfo.

.NOTES
    Last Modified   : August 27th, 2023
    Author          : Manuel Nieto
    Prerequisite    : Run as Administrator

.LINK
    For more information, visit https://github.com/jmanuelng/MEM_ChangeBitlockerKeyProtectorType#readme
#>



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

    .LINK
        For more information, Github Readme
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



function Set-BitLockerKeyProtectorType {
    <#
    .SYNOPSIS
        Changes the BitLocker key protector type for a specified volume.

    .DESCRIPTION
        This function changes the BitLocker key protector type for a specified volume (MountPoint). 
        It supports TPM, TPMAndPIN, and RecoveryPassword as valid key protector types.

    .PARAMETER MountPoint
        The drive letter or mount point of the volume to modify. For example, "C:".

    .PARAMETER NewKeyProtectorType
        The new key protector type to set. Valid values are "TPM", "TPMAndPIN", and "RecoveryPassword".

    .PARAMETER ProtectorValue
        The value for the PIN or Recovery Password, depending on the NewKeyProtectorType.

    .EXAMPLE
        Set-BitLockerKeyProtectorType -MountPoint "C:" -NewKeyProtectorType "TPM"

    .EXAMPLE
        Set-BitLockerKeyProtectorType -MountPoint "D:" -NewKeyProtectorType "RecoveryPassword" -ProtectorValue "123456"

    .NOTES
        Prerequisite   : Run as Administrator
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$MountPoint,

        [Parameter(Mandatory=$true)]
        [ValidateSet("TPM", "TPMAndPIN", "RecoveryPassword")]
        [string]$NewKeyProtectorType,

        [Parameter(Mandatory=$false)]
        [string]$ProtectorValue
    )

    # Check if running as Administrator. Yes, I know, super redundant, its becuase I might move this functions around.
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "You must run this script as an Administrator."
        return
    }

    # Check if BitLocker is enabled on the specified MountPoint.
    try {
        $bitlockerInfo = Get-BitLockerVolume -MountPoint $MountPoint
    } catch {
        Write-Host "An error occurred while fetching BitLocker information: $_"
        return
    }

    if ($null -eq $bitlockerInfo) {
        Write-Host "BitLocker is not enabled on the specified MountPoint: $MountPoint"
        return
    }

    # Remove existing key protectors.
    try {
        $bitlockerInfo.KeyProtector | ForEach-Object {
            Remove-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $_.KeyProtectorID
        }
    } catch {
        Write-Host "An error occurred while removing existing key protectors: $_"
        return
    }

    # Add the new key protector type based on the input.
    try {
        switch ($NewKeyProtectorType) {
            "TPM" {
                Enable-BitLocker -MountPoint $MountPoint -TpmProtector
            }
            "TPMAndPIN" {
                if ([string]::IsNullOrEmpty($ProtectorValue)) {
                    Write-Host "PIN value is required for TPMAndPIN."
                    return
                }
                Enable-BitLocker -MountPoint $MountPoint -TpmAndPinProtector -Pin $ProtectorValue
            }
            "RecoveryPassword" {
                if ([string]::IsNullOrEmpty($ProtectorValue)) {
                    Write-Host "Recovery Password is required for RecoveryPassword."
                    return
                }
                Enable-BitLocker -MountPoint $MountPoint -RecoveryPasswordProtector -RecoveryPassword $ProtectorValue
            }
        }
    } catch {
        Write-Host "An error occurred while setting the new key protector: $_"
        return
    }

    Write-Host "Key protector type changed to $NewKeyProtectorType for $MountPoint."
}

function ResumeOrEnableBitLocker {
    <#
    .SYNOPSIS
        This function attempts to resume or enable BitLocker encryption on a specified drive.

    .DESCRIPTION
        The function first checks the current status of BitLocker on the specified drive.
        If BitLocker is off or suspended, it uses the Enable-BitLocker cmdlet to resume or start the encryption process.

    .PARAMETER DriveLetter
        The drive letter of the volume to enable BitLocker on, including the colon character.

    .EXAMPLE
        ResumeOrEnableBitLocker -DriveLetter "C:"

    .NOTES
        This script requires administrative privileges to modify BitLocker settings.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter
    )

    # Check if running as Administrator. Mega redundant so that function can be moved around.
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "You must run this script as an Administrator."
        return
    }

    try {
        # Check the current BitLocker status
        $bitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter

        # If BitLocker is off or suspended, enable it
        if ($bitlockerStatus.ProtectionStatus -eq "Off" -or $bitlockerStatus.ProtectionStatus -eq "Suspended") {
            Enable-BitLocker -MountPoint $DriveLetter -SkipHardwareTest
            Write-Host "BitLocker encryption initiated or resumed on drive $DriveLetter."
        } else {
            Write-Host "BitLocker already active on drive $DriveLetter."
        }
        
    } catch {
        # Handle exceptions and errors
        Write-Host "Error occurred trying to enable Bitlocker: $_"
    }
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


#region Main

# Initialize a variables and clear errors
$Error.Clear()
$executionSummary = ""
$execStatus = 0  # Initialize execution status. 0: OK, 1: FAIL, >0: WARNING

# Easier to read in log file
Write-Host "`n`n"

# Check if running as Administrator
# BitLocker settings requires administrative privileges.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "You must run this script as an Administrator."
    $executionSummary += "No admin rights. "
    $execStatus = 1
    WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary
}

# Fetch all volumes
# Identifies all the volumes that may need BitLocker KeyProtector type changes.
try {
    $volumes = Get-Volume
} catch {
    $executionSummary += "Error fetching volumes. "
    Write-Host $executionSummary
    $execStatus = 1
    WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary
}

# Loop through each volume to check and update BitLocker KeyProtector types.
# This is the core logic, each volume's BitLocker status is checked and updated if necessary.
foreach ($volume in $volumes) {
    if (($null -ne $volume.DriveLetter) -and ($volume.DriveType -eq "Fixed")) {
        $mountPoint = $volume.DriveLetter + ":"

        $bitlockerStatus = Get-BitLockerVolume -MountPoint $mountPoint
        if ($bitlockerStatus.ProtectionStatus -eq "On") {
            try {
                $keyProtectorTypes = Get-BitLockerKeyProtectorInfo -MountPoint $mountPoint
            } catch {
                $executionSummary += "Error fetching BitLocker info for $mountPoint. "
                $execStatus = -1
                continue
            }

            # Check if the volume is encrypted and has TpmPin as a KeyProtector type.
            # In this case, as this was my need at the time of writing, script only changes form TpmPin to Tpm.
            # Script and function do have the flexibility to treat the change differently.
            if ($keyProtectorTypes -contains "TpmPin") {
                try {
                    # Change the KeyProtector type from TpmPin to Tpm.
                    Set-BitLockerKeyProtectorType -MountPoint $mountPoint -NewKeyProtectorType "TPM"
                    $executionSummary += "Updated $mountPoint from TpmPin to Tpm. "
                } catch {
                    $executionSummary += "Error updating $mountPoint. "
                    $execStatus = 1
                    WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary
                }
                try {
                    # Check if Encryption is On, if not, turn it On
                    ResumeOrEnableBitLocker -DriveLetter $mountPoint
                    $executionSummary += "Bitlocker On for $mountPoint. "
                }
                catch {
                    $executionSummary += "Error turning Bitlocker On for $mountPoint. "
                    $execStatus = -2 # Only Warning will be logged. It is assumed that an Intune Policy will eventually turn Bitlocker On.
                }
            } elseif ($null -ne $keyProtectorTypes) {
                $executionSummary += "Skipped $mountPoint (No TpmPin). "
            } else {
                $executionSummary += "Skipped $mountPoint (Not encrypted). "
                $execStatus = -3
            }
        }
    }
}

# Display the detailed summary of execution.
# This provides a quick overview of what the script did for each volume.
WriteAndExitWithSummary -StatusCode $execStatus -Summary $executionSummary

#endregion Main
