Set-ExecutionPolicy RemoteSigned -Force

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
    
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -AllowRedirection
#Connect-MsolService fails unless PS version is >= 5. Exchange cmdlets will be available but not MS Online
Try{
    Connect-ExchangeOnline -Credential $UserCredential -ShowProgress $true -ErrorAction Stop
}
Catch{
    Connect-MsolService -Credential $UserCredential
    Import-PSSession $Session -AllowClobber
}


#End the session
function EndSession(){
    Remove-PSSession $Session
    Write-Host 'Session has ended. Type "exit" to close.'
}