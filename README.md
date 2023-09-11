# MEM_BitlockerChangeKeyProtectorType

## Overview

This repository was created in response to a change in BitLocker policy within an organization. We transitioned to a policy that only allows the "TPM" KeyProtectorType for BitLocker-encrypted volumes. During this transition, it was discovered that many users had volumes encrypted with the "TpmPin" KeyProtectorType. Script were created to streamline the process of aligning devices with the new policy. Scripts are intended to be used as "Remediation" scripts in Microsoft Intune.

- **Detect_KeyProtectorType.ps1**: Script scans all volumes on a Windows device to identify if any volume is encrypted with a BitLocker KeyProtector type of "TpmPin".
  
- **Fix_KeyProtectorType.ps1**: The "Remedaition" script, it checks all volumes on a Windows device and changes the KeyProtector Type from "TpmPin" to "Tpm" for all encrypted volumes. In tests Bitlocker encryption was turned off or suspended after change, so script also checks and turns it on again.

## Usage

### Prerequisites

- Microsoft Intune subscription
- Devices enrolled in Intune
- Administrative privileges on the devices

### Instructions for Intune

#### Updated Usage of Remediations in Intune

As of June 2023, Proactive Remediations has been renamed to "Remediations" and is now available from Devices > Remediations in the Microsoft Intune console. For more details, you can refer to the [official Microsoft documentation](https://learn.microsoft.com/en-us/mem/intune/fundamentals/remediations).

1. **Upload the Scripts to Intune**: 
    - Go to the Intune console.
    - Navigate to `Devices > Remediations`.
    - Click on `+ New` to create a new Remediation profile.
    - Upload the PowerShell scripts from this repository.

2. **Configure Script Settings**:
    - Set the `Run this script using the logged-on credentials` to `No`.
    - Set the `Run script in 64-bit PowerShell` to `Yes`.

3. **Assign the Remediation to a Group**:
    - After the Remediation profile is created, assign it to a group of devices or users.

4. **Monitor the Remediation**:
    - You can monitor the status of the Remediation from the Intune console.

5. **Review Logs and Results**:
    - Logs and results can be viewed in the Intune console under the `Overview` and `Monitor` sections of the Remediation profile.

The idea behind these scripts is to ensure that the BitLocker KeyProtector type is set to TPM across all devices. The purpose is to adhere to the new security policy we configured in a specific environment.

## Functions
- `Get-BitLockerKeyProtectorInfo`: Retrieves the types of BitLocker key protectors for a given volume.
- `Set-BitLockerKeyProtectorType`: Changes the BitLocker key protector type for a specified volume.
- `WriteAndExitWithSummary`: Writes a summary of the script's execution to the console and then exits the script with a specified status code.


## Contributing
Contributions to the `MEM_ChangeBitlockerKeyProtectorType` repository are welcomed. If you have a feature request, bug report, or improvement to the script, please open an issue or submit a pull request.

## License
The `MEM_ChangeBitlockerKeyProtectorType` repository scripts are provided under the MIT License. The MIT License is a permissive free software license that puts only very limited restriction on reuse and has, therefore, high license compatibility. It permits users to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies.

## Disclaimer
This script is provided as-is with no warranties or guarantees of any kind. Always test scripts and tools in a controlled environment before deploying them in a production setting.

## Additional Resources
For more information, please refer to the official [Microsoft Intune Documentation](https://docs.microsoft.com/en-us/mem/intune/).

