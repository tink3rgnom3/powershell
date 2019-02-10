cd C:\Source\Scripts

$Logfile = "C:\Source\Scripts\Bulk-User-Offboarding-Log.log"
Function LogWrite
{
   Param ([string]$logstring)

   $TimeStamp = get-date -uformat "%Y/%m/%d %H:%M"

   Add-content $Logfile -value "[$TimeStamp] $logstring"
}

$UserList = Import-Csv .\Bulk-User-Offboarding-Premises-Exchange-List.csv
$Parameters = Import-Csv .\Bulk-User-Offboarding-Premises-Exchange-Params.csv
$Server = $env:COMPUTERNAME
$PathTest = Test-Path \\$server\C$\PST
$MailServer = $Parameters.Mailserver
$DisabledUserPath = $Parameters.DisabledUserPath

Import-Module ActiveDirectory
$ExchSession = New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"

Import-PSSession $ExchSession -AllowClobber

If ( $PathTest -eq $False ) { 
mkdir C:\PST
net share PST=C:\PST
}

ForEach ($UserToRemove in $Userlist){
    
    $Fname = $UsertoRemove.FirstName
    $Lname = $UserToRemove.LastName
    $FullName = "$Fname $Lname"
    $Username = Get-AdUser -Filter {(GivenName -eq $FName) -and (Surname -eq $LName)} | %{$_.SamAccountName}
    $FwAddress = $UsertoRemove.ForwardingAddress

    $UserMailbox = Get-Mailbox $Username -ErrorAction SilentlyContinue
    
    If($UserMailbox -ne $Null){
        Set-mailbox $Username -HiddenFromAddressListsEnabled:$True -Confirm:$False -ErrorAction SilentlyContinue
        New-MailboxExportRequest –Mailbox $Username -FilePath \\$Server\C$\PST\$Username.pst -ErrorAction SilentlyContinue
    }
    
    If($DisabledUserPath -eq $Null){
        $DisabledUserPath = Get-ADOrganizationalUnit -Filter * | Where {($_.DistinguishedName -like "OU=Users,OU=Disabled*") -or ($_.Name -eq "Disabled Accounts" -or "Disabled Users")} | %{$_.DistinguishedName}
    }

    #Get AD Groups and remove from all but Domain Users
    LogWrite "Removing user from groups:"
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where {$_.Name -ne "Domain Users"}
    If ($JoinedGroups -ne $Null){
        ForEach($Group in $JoinedGroups){ 
            Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False 
            LogWrite "$Group"
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
