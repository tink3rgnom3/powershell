function ConnectPremExch($MailServer,$LocalDomain){
    New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
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
