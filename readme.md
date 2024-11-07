# OC-BTPS Module

## Overview

OC-BTPS provides a function for retrieving BeyondTrust Password Safe credentials programatically, and turn them into a PSCredential object.

## Installation

This module is available in via powershell gallery. `Install-Module -Name oc-btps -Repository psgallery`

## Usage

Import the module into your PowerShell session, then pass the params as needed.
Note that the systemName value here doesn't nessarily - but can - match the name of the host being accessed.
For example, if this account is Active Directory joined, the system name here might be `yourdomain.com` instead of `server1`.

```
powershell
Import-Module OC-BTPS
$systemName = "server1"
$mySplat = @{
    AccountName     = 'exampleAccountName@example.com',
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

## Notes

First and foremost, this module expects that your instance of BeyondTrust be 22 or above in order to use the API.

This code also will default to retrieving an existing checkout for the same set of credentials if one exists.
This is to prevent multiple checkouts of the same account; depending on how scripts are written and the number of concurrent checkouts allowed in BeyondTrust this can cause a problem otherwise.

Additionally, the name passed here must match the name returned by the ManagedEndpoint API. This can be found in a few ways. I prefer to use the API to get the account name in Postman.
After authenticating with the API (example method embedded in this module), you can use the following GET request to locate the account name syntax.
Assuming `server1` as the host to test, we can find the account name syntax.

`GET https://$apidomain/BeyondTrust/api/public/v3/ManagedAccounts?systemName=server1`

The 'UserPrincipalName' field in the response is what you want to use for your calls. This is followed by the 'AccountName' field, which BeyondTrust PS uses as a if UPN is not present.

```
[
    {
        "PlatformID": 999,
        "SystemId": 12345,
        "SystemName": "server1",
...
        "DomainName": "example.com",
        "AccountId": 7890,
        "AccountName": "exampleAccountName",
        "UserPrincipalName": "exampleAccountName@example.com",
...
        "MaximumReleaseDuration": 60,
        "DefaultReleaseDuration": 60,
        "LastChangeDate": "2024-10-25T17:03:58.48",
...
    }
]
```

The account name located can be validated with the exact username syntax in the AccountName parameter with something like this.
`https://$apidomain/BeyondTrust/api/public/v3/ManagedAccounts?systemName=server1&accountName=exampleAccountName@example.com`
You should get back exactly _one_ account object. If you get more than one, you need to refine your search.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

## License

This project is licensed under the MIT License.

## Contact

For any questions or issues, please open an issue on the GitHub repository.
