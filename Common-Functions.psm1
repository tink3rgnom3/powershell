function CheckRunningAsAdmin(){
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConnectPremExch($MailServer,$LocalDomain){
    New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
}

function ExchConnected {
    Get-ExchangeServer -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

Function LogWrite {
   Param ([string]$logstring)
   $TimeStamp = get-date -uformat "%Y/%m/%d %H:%M"
   Add-content $Logfile -value "[$TimeStamp] $logstring"
}

function MSOLConnected {
    Get-MsolDomain -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

function MSOnlineConnect(){    
	$UserCredential = Get-Credential
    Write-Host "Enter Office 365 admin credentials when prompted"
	$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
	Connect-MsolService -Credential $UserCredential
	Import-PSSession $Session -AllowClobber
}

function setO365License($Domain,$MSClient,$MSDomain){

    If (-Not (MSOLConnected)){
        MSOnlineConnect
    }
    $USR = get-msoluser | Where-Object{(($_.Firstname -eq $Firstname) -and ($_.Lastname -eq $Lastname))}
    #This script will fetch license numbers and assign a license based on a chosen number.
    
    $Menu = @()
    $Licenses = Get-MsolAccountSku
    $Place = 0
    $ItemNumber = 1

    If($USR.UserPrincipalName -match "onmicrosoft.com"){
        Set-MsolUserPrincipalName -ObjectId $UserObjId -NewUserPrincipalName "$UserAlias@$Domain"
    }

    If(-Not ($USR.UsageLocation)){
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

function SyncADtoO365(){
    Set-ExecutionPolicy Unrestricted -Force
    Import-Module ADSync
    Try{
        Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
    }
    Catch [System.InvalidOperationException]{
        Write-Host "AAD is busy. Waiting 60 seconds to try again."
        Start-Sleep -Seconds 60
        Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
    }
    Catch{
        Write-Host "Could not run AD Sync at this time. Please try again later."
    }
}
