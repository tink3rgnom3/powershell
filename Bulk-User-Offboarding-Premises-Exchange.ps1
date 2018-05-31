cd C:\source\Scripts
$UserList = Import-Csv .\Remove_Users.csv
$Server = $env:COMPUTERNAME
$PathTest = Test-Path \\$server\C$\PST

If ( $PathTest -eq $False ) { 
mkdir C:\PST
net share PST=C:\PST
}

ForEach ($UserToRemove in $Userlist){
    $Fname = $UsertoRemove.FirstName
    $Lname = $UserToRemove.LastName
    $Username = $Fname[0] + $LName
    $FwdAddress = $UserToRemove.ForwardingAddress
    
    $UserMailbox = Get-Mailbox $Username -ErrorAction SilentlyContinue
    $MailboxAlias = $Usermailbox.alias
    If($UserMailbox -ne $Null){
        Set-mailbox $Username -HiddenFromAddressListsEnabled:$True -Confirm:$False
        Set-mailbox $Username -Alias "$MailboxAlias_archived"
        New-MailboxExportRequest –Mailbox $Username -FilePath \\$Server\C$\PST\$Username.pst -ErrorAction SilentlyContinue
        If ($FwdAddress -ne $Null){
            Set-Mailbox $Username -ForwardingAddress $FwdAddress
            Write-Host "Forwarding to $FwdAddress
        }
    }
    Else{
         Write-Host "Mailbox for $UserToRemove does not exist"
    }
    Import-Module ActiveDirectory
    $DisabledUserPath = Get-ADOrganizationalUnit -Filter {(Name -eq "Disabled Accounts") -or (Name -eq "Disabled Users")} | %{$_.DistinguishedName}


    #Get AD Groups and remove from all but Domain Users
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where {$_.Name -ne "Domain Users"}
    Write-host "Removing $UserToRemove from groups:"
    If ($JoinedGroups -ne $Null){
        ForEach($Group in $JoinedGroups){ 
            $GroupStrName = $Group.name
            Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False 
            Write-Host "$GroupStrName"
    }
    #Disable AD User
    Set-ADUser $Username -Enabled $False
    Write-Host "User $Username is disabled"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    Write-Host "User $Username has been moved to Disabled Users"
}

exit
