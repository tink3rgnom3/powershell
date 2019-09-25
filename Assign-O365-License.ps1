cd C:\Source\Scripts
Import-Module .\Common-Functions.psm1
$ScriptParams = Import-Csv .\ADDS-O365-Synced-Params.csv

#Connect to MS Online
If (-Not (MSOLConnected)){
    MSOnlineConnect
}

#domain variables
$Domain = $ScriptParams.EmailDomain
$MSClient 
$MSDomain = "$MSClient.onmicrosoft.com"

#user variables
$UserFirstName = Read-Host -Prompt "Enter the user's first name"
$UserLastName = Read-Host -Prompt "Enter the user's last name"
$User = "$UserFirstname $UserLastName"
$UserAlias = $UserFirstName[0] + $UserLastName
$USR = Get-MsolUser | Where {$_.DisplayName -eq $User}
$UPN = $USR.UserPrincipalName
$UserObjId = $USR.ObjectId

function setO365License(){
    
    #This script will fetch license numbers and assign a license based on a chosen number.
    
    $Menu = @()
    $Licenses = Get-MsolAccountSku
    $Place = 0
    $ItemNumber = 1

    If($USR.UserPrincipalName -match "onmicrosoft.com"){
        Set-MsolUserPrincipalName -ObjectId $UserObjId -NewUserPrincipalName "$UserAlias@$Domain"
    }

    If($USR.UsageLocation -eq $Null){
        Set-MsolUser -ObjectId $UserObjId -UsageLocation "US"
    }

    ForEach($Account in $Licenses){
        
        $LicenseNumber = $Account.ActiveUnits - $Account.ConsumedUnits
        If($LicenseNumber -gt 0){
            $Menu += $Account.SkuPartNumber
            Write-Host "$ItemNumber : $Menu[$Place] ($LicenseNumber available)"
            $Place++
            $ItemNumber++
        }
        
    }

    If($Menu.Length){
        Do{

            [int]$Question = Read-Host -Prompt "Enter an item number"
            [int]$Answer = $Question - 1
    
            If(($Answer -gt $Menu.Length) -and ($answer -le 0)){

                Write-host "Sorry, that option isn't available"

            }
    
        } until(($Answer -lt $Menu.Length) -and ($answer -ge 0))

        $UserLicense = $MSClient+ ":" + $Menu[$Answer]
        Set-MsolUserLicense -ObjectId $UserObjId -AddLicenses $UserLicense
        Write-Host " Assigned $UserLicense to $User"
    }
    Else{
        Write-Host "No licenses available"
    }
}

function removeO365License(){
    Set-MsolUserLicense -UserPrincipalName $USR.UserPrincipalName -RemoveLicenses $USR.Licenses.AccountSkuId
}


    Write-Host "
    1. Set an Office 365 license
    2. Remove an Office 365 license 
    "
    [int]$licenseOption = Read-Host -Prompt "Enter a menu option"

    If($licenseOption -eq 1){
        setO365License
    }
    elseif($licenseOption -eq 2){
        removeO365License
    }

Write-Host ‘Type a menu number to get started’
