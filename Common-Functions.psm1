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
    Start-ADSyncSyncCycle -PolicyType Delta
}
