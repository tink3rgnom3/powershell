Write-host "
Available Commands:
O365Login - Log into Office 365 online
AzureADLogin - Log into Azure Active Directory

Type a command to start.

To close session, type 'exit'
"

#Office 365 Login
Function O365Login(){
    Set-ExecutionPolicy RemoteSigned
    $Global:UserCredential = Get-Credential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    Connect-MsolService -Credential $UserCredential
    Import-PSSession $Session
}

#Azure AD login
function AzureADLogin (){
    If($UserCredential -eq $Null){
        $AzureUserCred = Get-Credential
    } 

    Else{
        $AzureUserCred = $UserCredential
    }

    $ADSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    #Install-Module -Name AzureAD 
    Connect-MsolService -Credential $AzureUserCred
    Connect-AzureAD -Credential $AzureUserCred
    #(Get-Item C:\Windows\System32\WindowsPowerShell\v1.0\Modules\MSOnline\Microsoft.Online.Administration.Automation.PSModule.dll).VersionInfo.FileVersion
}

#End the session
function EndSession(){
    Remove-PSSession $Session
    Write-Host 'Session has ended. Type "exit" to close.'
}
