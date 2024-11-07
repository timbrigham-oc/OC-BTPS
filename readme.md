# OC-BTPS Module

## Overview

OC-BTPS provides a function for retrieving BeyondTrust Password Safe credentials programatically, and turn them into a PSCredential object.

## Installation

This module is available in via powershell gallery
`powershell Install-Module -Name oc-btps -Repository psgallery`

## Usage

Import the module into your PowerShell session, then pass the params as needed.
Note that the systemName value here doesn't nessarily - but can - match the name of the host being accessed.

```
powershell
Import-Module oc-btps
$systemName = "managedsystem"
$mySplat = @{
    AccountName     = 'username@example.com',
    systemName      =  $systemName,
    APIKey          = $env:BTAPIKEY,
    APIUser         = 'API-Checkout-User',
    APIDOMAIN       = 'yourorg.ps.beyondtrustcloud.com',
    DurationMinutes = 5
}
$creds = Get-BeyondTrustPassword @mySplat
$testScriptBlock = { whoami }
Invoke-Command -ScriptBlock $testScriptBlock -Credential $credsProd -ComputerName $computerName
```

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License.

## Contact

For any questions or issues, please open an issue on the GitHub repository.
