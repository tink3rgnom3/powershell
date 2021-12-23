function CheckRunningAsAdmin(){
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConnectPremExch($MailServer,$LocalDomain){
    New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
}

function ExchConnected() {
    Get-ManagementRole -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

Function LogWrite([string]$logstring) {
   $Logtest = Test-Path $Logfile
   If(-Not ($Logtest)){
      New-Item $Logfile
   }
   #Param ([string]$logstring)
   $TimeStamp = get-date -uformat "%Y/%m/%d %H:%M"
   Try{
      Add-content $Logfile -value "[$TimeStamp] $logstring"
   }
   Catch{
      Write-Host $logstring
   }
}

function MSOLConnected {
    Get-MsolDomain -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

function MSOnlineConnect(){    
	
$PSVersionCheck = $PSVersionTable.PSVersion.Major
If($PSVersionCheck -ge 5){
    $MSEXOCheck = Get-InstalledModule -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue
    If(-Not $MSEXOCheck){
        Try{
            $webclient=New-Object System.Net.WebClient
            $webclient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
            [Net.ServicePointManager]::SecurityProtocol = "tls12"
            Install-Module ExchangeOnlineManagement -ErrorAction Stop
        }
        Catch{
            $MSOnlineCheck = Get-InstalledModule -Name MSOnline -ErrorAction SilentlyContinue
	        If(-Not $MSOnlineCheck){
		    Install-Module MSOnline -Confirm:$False
            }
        }
    }
}
    
#$UserCredential = Get-Credential

#Connect-MsolService fails unless PS version is >= 5. Exchange cmdlets will be available but not MS Online
Try{
    Connect-ExchangeOnline -ShowProgress $true -ErrorAction Stop
    Connect-MsolService -Credential $UserCredential
}
Catch{
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -AllowRedirection
    Connect-MsolService -Credential $UserCredential
    Import-PSSession $Session -AllowClobber
}
	
}

function setO365License($FirstName,$LastName,$Domain,$MSTenantName,$MSDomain){

    If (-Not (MSOLConnected)){
        MSOnlineConnect
    }
	
    $USR = get-msoluser | Where-Object{(($_.Firstname -eq $Firstname) -and ($_.Lastname -eq $Lastname))}
    $UserObjId = $USR.ObjectID
	
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
            $Menu += $Account.AccountSkuId
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

    $UserLicense = $Menu[$Answer]
    Set-MsolUserLicense -ObjectId $UserObjId -AddLicenses $UserLicense
    Write-Host " Assigned $UserLicense to $User"
}


function SyncADtoO365(){
    Set-ExecutionPolicy Unrestricted -Force
    If(-Not $RemoteADSync){
        Try{
            Import-Module ADSync
        }
        Catch{
            Write-Host "Could not import ADSync module"
        }

        Try{
		    Write-Host "Starting AD Sync..."
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
    Else{
        Try{
            Invoke-Command -ComputerName $ScriptParams.ADSyncSrv -ScriptBlock {C:\Source\Scripts\AD_Sync.ps1}
        }
        Catch{
            Write-Host "Remote AD Sync failed. Check that script is present and remote server has PS Remoting enabled"
        }
    }
}