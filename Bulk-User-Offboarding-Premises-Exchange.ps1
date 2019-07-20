Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    exit
}
Import-Module ActiveDirectory

$Logfile = "C:\Source\Scripts\Bulk-User-Offboarding-Premises-Exchange-Log.log"

$UserList = Import-Csv .\Bulk-User-Offboarding-Premises-Exchange-List.csv
$ScriptParams = Import-Csv .\ADDS-Premises-Params.csv
$Server = $env:COMPUTERNAME
$PathTest = Test-Path \\$server\C$\PST
$MailServer = $ScriptParams.Mailserver
$DisabledUserPath = $ScriptParams.DisabledUserPath
$LocalDomain = $env:USERDNSDOMAIN

If (-Not (ExchConnected)){
    $ExchSession = New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
    Import-PSSession $ExchSession -AllowClobber
}

If ( $PathTest -eq $False ) { 
mkdir C:\PST
net share PST=C:\PST
}

ForEach ($UserToRemove in $Userlist){
    
    $Fname = $UsertoRemove.FirstName
    $Lname = $UserToRemove.LastName
    $FullName = "$Fname $Lname"
    $Username = Get-AdUser -Filter {(GivenName -eq $FName) -and (Surname -eq $LName)} | ForEach-Object{$_.SamAccountName}
    $FwAddress = $UsertoRemove.ForwardingAddress
    $UserMailbox = Get-Mailbox $Username -ErrorAction SilentlyContinue
    
    If(-Not ($UserMailbox)){
        Set-mailbox $Username -Type Shared -HiddenFromAddressListsEnabled:$True -Confirm:$False -ErrorAction SilentlyContinue
        If($FwAddress -ne ''){
            Set-Mailbox $Username -ForwardingAddress $FwAddress
            LogWrite "Forwarding $Username to $FwAddress"
        }
        New-MailboxExportRequest –Mailbox $Username -FilePath \\$Server\C$\PST\$Username.pst -ErrorAction SilentlyContinue
    }
    
    If(-Not ($DisabledUserPath)){
        $DisabledUserPath = Get-ADOrganizationalUnit -Filter * | Where-Object {($_.DistinguishedName -like "OU=Users,OU=Disabled*") -or ($_.Name -eq "Disabled Accounts" -or "Disabled Users")} | ForEach-Object{$_.DistinguishedName}
    }

    #Get AD Groups and remove from all but Domain Users
    LogWrite "Removing user $Username from groups:"
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where-Object {$_.Name -ne "Domain Users"}
    If (-Not ($JoinedGroups)){
        ForEach($Group in $JoinedGroups){
            $GroupName = $Group.name
            Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False 
            LogWrite "$GroupName"
        }
    }
    #Disable AD User
    Set-ADUser $Username -Enabled $False
    LogWrite "User $Username is disabled"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $Username has been moved to Disabled Users"
    
    Write-Host "User offboarding for $FullName is complete"
}

exit
