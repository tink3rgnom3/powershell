$UserList = Import-Csv C:\Source\Scripts\Remove_Users.csv
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

    
    $UserMailbox = Get-Mailbox $Username -ErrorAction SilentlyContinue
    If($UserMailbox -ne $Null){
        Set-mailbox $Username -HiddenFromAddressListsEnabled:$True -Confirm:$False -ErrorAction SilentlyContinue
        New-MailboxExportRequest –Mailbox $Username -FilePath \\$Server\C$\PST\$Username.pst -ErrorAction SilentlyContinue
    }
    Import-Module ActiveDirectory
    $DisabledUserPath = Get-ADOrganizationalUnit -Filter {Name -eq "Disabled Accounts"} | %{$_.DistinguishedName}


    #Get AD Groups and remove from all but Domain Users
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where {$_.Name -ne "Domain Users"}
    If ($JoinedGroups -ne $Null){
        ForEach($Group in $JoinedGroups){ Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False }
    }
    #Disable AD User
    Set-ADUser $Username -Enabled $False
    Write-Host "User $Username is disabled"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    Write-Host "User $Username has been moved to Disabled Users"
}

exit
