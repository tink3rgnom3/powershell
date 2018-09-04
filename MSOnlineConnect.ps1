
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
    #Install-Module -Name AzureAD #Use this if needed
    Connect-MsolService -Credential $AzureUserCred
    Connect-AzureAD -Credential $AzureUserCred
    #(Get-Item C:\Windows\System32\WindowsPowerShell\v1.0\Modules\MSOnline\Microsoft.Online.Administration.Automation.PSModule.dll).VersionInfo.FileVersion
}

#End the session
function EndSession(){
    Remove-PSSession $Session
    Write-Host 'Session has ended. Type "exit" to close.'
}

do{
    Write-host "Available Commands:

1. O365Login - Log into Office 365 online
2. AzureADLogin - Log into Azure Active Directory

To start, type the command number and Enter

To close session, type 'exit'
    "
    $Answer = Read-Host
    If($Answer -eq '1'){
        O365Login
        break
    }
    If($Answer -eq '2'){
        AzureADLogin
        break
    }
    Else{Write-Host -ForegroundColor Red "
Sorry, that menu item is not valid
    "}
}
until($Answer -eq ('1' -or '2'))
