Set-ExecutionPolicy RemoteSigned -Force

$PSVersionCheck = $PSVersionTable.PSVersion.Major
If($PSVersionCheck -ge 5){
    $MSOnlineCheck = Get-InstalledModule -Name MSOnline -ErrorAction SilentlyContinue
    
	If($MSOnlineCheck -eq $Null){
		Install-Module MSOnline -Confirm:$False
    }    
}
    
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Connect-MsolService -Credential $UserCredential
Import-PSSession $Session -AllowClobber


#End the session
function EndSession(){
    Remove-PSSession $Session
    Write-Host 'Session has ended. Type "exit" to close.'
}