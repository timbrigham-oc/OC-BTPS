<#
    .SYNOPSIS
    This function is used to retrieve a password from a specific account in BeyondTrust using the API.
    .DESCRIPTION
    This function is used to retrieve a password from a specific account in BeyondTrust using the API.
    .PARAMETER AccountName
    The name of the account in BeyondTrust. The syntax matters here and varies by instance. See notes.
    .PARAMETER systemName
    The name of the system the account is linked to in BeyondTrust. 
    .PARAMETER APIKey
    The API key for the BeyondTrust API. This can be found in the BeyondTrust console under Settings -> API Keys.
    This key needs assigned to API acces account(s) with rights to check out the managed accounts in question passwords. 
    .PARAMETER APIUser
    The API user for the BeyondTrust API. This can be found in the group definition associated with the API Key registration above.
    .PARAMETER APIDOMAIN
    The domain for the BeyondTrust API. This is the domain name of the BeyondTrust instance.
    .PARAMETER DurationMinutes
    The duration in minutes for the password to be checked out. The default is 5 minutes. 
    Note that the maximum duration is dictated by the checkout period on the checked out account in the BeyondTrust console.
    .PARAMETER RotateOnCheckin
    A boolean value to determine if the password should be rotated on checkin. The default is false.
    .EXAMPLE
    $computerName = "managedsystem.example.com"
    $mySplat = @{
        AccountName     = 'username@example.com',
        systemName      = 'Managed System Name',    
        APIKey          = $env:BTAPIKEY,            
        APIUser         = 'API-Checkout-User',      
        APIDOMAIN       = 'yourorg.ps.beyondtrustcloud.com',
        DurationMinutes = 5
    }
    $creds = Get-BeyondTrustPassword @mySplat    
    $testScriptBlock = { whoami }
    Invoke-Command -ScriptBlock $testScriptBlock -Credential $credsProd -ComputerName $computerName
    .NOTES
    First and foremost, this module expects that your instance of BeyondTrust be 22 or above in order to use the API.

    This code also will default to retrieving an existing checkout for the same set of credentials if one exists. 
    This is to prevent multiple checkouts of the same account; depending on how scripts are written and the number 
    of concurrent checkouts allowed in BeyondTrust this can cause a problem otherwise. 

    Additionally, the name passed here must match the name returned by the ManagedEndpoint API. This can be found in a few ways. 
    I prefer to use the API to get the account name in Postman. 
    After authenticating with the API (example method embedded in this module), you can use the following GET request 
    to locate the account name syntax.
    GET https://$apidomain/BeyondTrust/api/public/v3/ManagedAccounts?systemName=ManagedSystemName 
    The 'UserPrincipalName' field in the response, contains 'username@example.com'. This is followed by the 'AccountName' field as a backup.
    The account name llocated can be validated with the exact username syntax in the AccountName parameter with something like this. 
    https://$apidomain/BeyondTrust/api/public/v3/ManagedAccounts?systemName=ManagedSystemName&accountName=username@example.com
    You should get back exactly *one* account object. If you get more than one, you need to refine your search.
#>
Function Get-BeyondTrustPassword {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$AccountName,
        [Parameter(Mandatory = $true)]
        [string]$systemName,
        [Parameter(Mandatory = $true)]
        [string]$APIKey,
        [Parameter(Mandatory = $true)]
        [string]$APIUser,
        [Parameter(Mandatory = $true)]
        [string]$APIDOMAIN,
        [Parameter(Mandatory = $false)]
        [int]$DurationMinutes = 5,
        [Parameter(Mandatory = $false)]
        [bool]$RotateOnCheckin = $false,
        $InformationPreference = 'Continue'
    )
    # Auth headers only needed for sign in 
    $AuthHeaders = @{
        'Authorization' = "PS-Auth key=$APIKey; runas=$APIUser"
    }
    # General headers for the rest of the API calls
    $GeneralHeaders = @{
        'Content-Type' = 'application/json'
    }
    # We need a web reqeust session for the API due to how the auth works here. 
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    # First sign in using the headers. 
    $URI = "https://$APIDOMAIN/BeyondTrust/api/public/v3/Auth/SignAppin"
    Write-Information "Signing in to BeyondTrust API for $APIDOMAIN"
    try {
        $response = Invoke-RestMethod -Uri $URI -Headers $AuthHeaders -Method Post -WebSession $session
    }
    catch {
        Throw "Error: $_"
    }

    # Before we go any further, we can see if we have an existing request for this account.
    # If we do, we can just return the password from that request.
    $URI = "https://$APIDOMAIN/BeyondTrust/api/public/v3/Requests"
    Write-Information "Checking for existing request for account $AccountName on system `'$systemName`'"
    try {
        $response = Invoke-RestMethod -Uri $URI -Method Get -WebSession $session -Headers $GeneralHeaders
    }
    catch {
        Throw "Error: $_"
    }

    # This will be used to store the request ID if we find one.
    $btRequestID = $null
    foreach ( $request in $response ) {
        if ( $AccountName -like "$($request.accountName)*" -and $request.managedSystemName -eq $systemName ) {
            $btRequestID = $request.RequestID
            Write-Information "Found existing request $btRequestID for account $AccountName on system `'$systemName`'"
            break
        }
    }
    # If we didn't find a request, we need to create one.
    if ( $null -eq $btRequestID ) {
        # Now get the user object using the existing session.
        $uri = "https://$APIDOMAIN/BeyondTrust/api/public/v3/ManagedAccounts?systemName=$systemName&accountName=$AccountName"
        Write-Information "Getting account $AccountName from system `'$systemName`'"
        try {
            $response = Invoke-RestMethod -Uri $URI -Method Get -WebSession $session -Headers $GeneralHeaders
        }
        catch {
            Throw "Error: $_"
        }
        $systemID = $response.systemID
        $accountID = $response.accountID
        Write-Information "System ID: $systemID"
        Write-Information "Account ID: $accountID"
        $uri = "https://$APIDOMAIN/BeyondTrust/api/public/v3/Requests"
        $body = @{
            "AccessType"             = "View"
            "SystemID"               = $systemID
            "AccountID"              = $accountID
            "DurationMinutes"        = $DurationMinutes
            "Reason"                 = "OC-BTPS Module Checkout"
            "AccessPolicyScheduleID" = $null
            "RotateOnCheckin"        = $RotateOnCheckin
        }
        Write-Information "Creating a checkout request for account $AccountName on system `'$systemName`' for $DurationMinutes minutes"
        try {
            $btRequestID = Invoke-RestMethod -Uri $URI -Method Post -WebSession $session -Body ($body | ConvertTo-Json) -Headers $GeneralHeaders
        }
        catch {
            Throw "Error: $_"
        }
    }

    Write-Information "Password Request ID is $btRequestID"
    # The response above is the ID number for the request. Now we need to access the password. 
    # Since $btRequestID already has the ID number we can just append it to the URI  
    # For example a get reqeust to https://$apidomain/BeyondTrust/api/public/v3/Credentials/4190
    $URI = "https://$APIDOMAIN/BeyondTrust/api/public/v3/Credentials/$($btRequestID)"
    Write-Information "Getting password for account $AccountName on system `'$systemName`'"
    try {
        $password = Invoke-RestMethod -Uri $URI -Method Get -WebSession $session -Headers $GeneralHeaders
    }
    catch {
        Throw "Error: $_"
    }

    # Now that we have the username and password create a pscredential object and return it. 
    # Note that this uses the passed in account name for the username.
    $creds = New-Object System.Management.Automation.PSCredential ($AccountName, (ConvertTo-SecureString $password -AsPlainText -Force))
    return $creds 
}
