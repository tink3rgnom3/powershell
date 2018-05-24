Get-MailboxExportRequest | Where {$_.Status -eq 'Completed'} | Remove-MailboxExportRequest -Confirm:$False

$User = Read-Host -Prompt "Input the user's full name"
$UserMailbox = Get-Mailbox -Identity $User -ErrorAction SilentlyContinue

If ($UserMailbox -eq $Null){
    Write-Host -BackgroundColor Red -ForegroundColor Black "Sorry, user $User does not have a mailbox. Exiting."
    exit
}

$MailboxAlias = $UserMailbox.Alias
$Server = $env:COMPUTERNAME
$PathTest = Test-Path \\$server\C$\PST

If ( $PathTest -eq $False ) { 
mkdir C:\PST
net share PST=C:\PST
}

#Get current user and assign to variable
Import-Module ActiveDirectory
$Manager = $env:username | Get-ADUser | %{ $_.Name}
$ManagerCheck = Get-ManagementRoleAssignment -Role "Mailbox Import Export" | where { $_.EffectiveUserName -eq $Manager }


If ($ManagerCheck -ne $null) {
    New-MailboxExportRequest –Mailbox $UserMailbox -FilePath \\$server\C$\PST\$MailboxAlias.pst
    $NewMailboxAlias = $MailboxAlias + "_archived"
    Set-Mailbox $UserMailbox -Alias $NewMailboxAlias -HiddenFromAddressListsEnabled:$True -Confirm:$False
    $Forwarding = Read-Host -Prompt "Does the user need to be forwarded? (Y/N)"
    If ($Forwarding -eq "Y"){
        $ForwardAddress = Read-Host -Prompt "Please enter the forwarding address"
        Set-Mailbox $NewMailboxAlias -ForwardingAddress $ForwardAddress
    }
    Else {
        Exit
    }

}
Else {
    New-ManagementRoleAssignment –Role “Mailbox Import Export” –User $env:UserDomain\$env:Username
    Write-Host "Management role has been assigned. Please restart shell and run script again."
}
