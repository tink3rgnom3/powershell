Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1
. .\ADDS-O365-Synced-Params.ps1

#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect.ps1
}

#$ScriptParams = Import-Csv .\ADDS-O365-Synced-Params.csv
$O365LicenseSkuTable = Import-Csv .\O365LicenseSkus.csv
#domain variables
#$Domain = $ScriptParams.EmailDomain
#$MSClient = $ScriptParams.MSTenantName
#$MSDomain = $ScriptParams.MSDomain

#user variables
$UserFirstName = $FirstName
If(-Not $UserFirstName){
    $UserFirstName = Read-Host -Prompt "Enter the user's first name"
}
$UserLastName = $LastName
If(-Not $UserLastName){
    $UserLastName = Read-Host -Prompt "Enter the user's last name"
}
$User = "$UserFirstname $UserLastName"
$UserAlias = $UserFirstName[0] + $UserLastName
$USR = Get-MsolUser | Where-Object{($_.FirstName -eq $UserFirstName) -and ($_.LastName -eq $UserLastName)}
#Need debugging for "User not found error", either offer to wait longer or abort
$UPN = $USR.UserPrincipalName
$UserObjId = $USR.ObjectId

function setO365License(){
    
    #This script will fetch license numbers and assign a license based on a chosen number.
    
    $Menu = @()
    $Licenses = Get-MsolAccountSku
    $Place = 0
    $ItemNumber = 1
    
    If($USR.UserPrincipalName -match "onmicrosoft.com"){
        Set-MsolUserPrincipalName -ObjectId $UserObjId -NewUserPrincipalName "$UserAlias@$EmailDomain"
    }

    If($USR.UsageLocation -eq $Null){
        Set-MsolUser -ObjectId $UserObjId -UsageLocation "US"
    }

    ForEach($Account in $Licenses){
        
        $LicenseNumber = $Account.ActiveUnits - $Account.ConsumedUnits
        $ItemName = $O365SkuTable.$($Account.SkuPartNumber)
        If($LicenseNumber -gt 0){
            $Menu += $Account.SkuPartNumber
            If($ItemName){
                Write-Host "$ItemNumber : $ItemName ($LicenseNumber available)"
            }
            Else{
                Write-Host "$ItemNumber : $Menu ($LicenseNumber available)"
            }
            $Place++
            $ItemNumber++
        }
        
    }

    Do{

        [int]$Question = Read-Host -Prompt "Enter an item number"
        [int]$Answer = $Question - 1
    
        If(($Answer -gt $Menu.Length) -and ($answer -le 0)){
            Write-host "Sorry, that option isn't available"
        }
    } until(($Answer -lt $Menu.Length) -and ($answer -ge 0))

    $UserLicense = $MSTenantName+ ":" + $Menu[$Answer]
    Try{
        Set-MsolUserLicense -ObjectId $UserObjId -AddLicenses $UserLicense -ErrorAction Stop
    }
    Catch{
        $UserLicense = "reseller-account:" + $Menu[$Answer]
        Set-MsolUserLicense -ObjectId $UserObjId -AddLicenses $UserLicense
    }
    If($?){
        Write-Host " Assigned $UserLicense to $User"
    }
}

setO365License