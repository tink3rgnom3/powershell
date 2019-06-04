cd C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    exit
}

Import-Module ActiveDirectory


#Connect to MS Online
If (-Not (MSOLConnected)){
    MSOnlineConnect
    Write-Host "Enter Office 365 admin credentials when prompted"
}

$Logfile = "C:\Source\Scripts\Bulk-User-Offboarding-O365-Synced-Log.log"
#See Common-Functions.psm1 for LogWrite function

$ScriptParams = Import-Csv .\Bulk-User-Offboarding-O365-Synced-Params.csv
$Userlist = Import-Csv .\Bulk-User-Offboarding-O365-Synced-List.csv
$DisabledUserPath = $ScriptParams.DisabledUserPath
$MSDomain = $ScriptParams.MSDOmain

If($DisabledUserPath -eq $Null){
    $DisabledUserPath = Get-ADOrganizationalUnit -Filter * | Where {($_.DistinguishedName -like "OU=Users,OU=Disabled*") -or ($_.Name -eq "Disabled Accounts" -or "Disabled Users")} | %{$_.DistinguishedName}
}

ForEach($OffUser in $Userlist){

    $FirstName = $Offuser.Firstname
    $LastName = $Offuser.Lastname
    $FullName = "$Firstname $Lastname"
    $Username = Get-ADUser -Filter {Name -eq $FullName}
    $FLastName = $FirstName[0] + $LastName
    $ForwardingAddress = $Offuser.ForwardingAddress

    If(MSOLConnected){
        $Mailbox = Get-Mailbox -Identity $FullName
    }
    #Disable AD User
    Set-ADUser $Username -Enabled $False
    LogWrite "User $FullName is disabled"

    #Get AD Groups and remove from all but Domain Users
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where {$_.Name -ne "Domain Users"}

    LogWrite "Removing $FullName from:"
    ForEach($Group in $JoinedGroups){ 
    
        $GroupName = $Group.Name
        Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False -ErrorAction SilentlyContinue
        LogWrite "$Groupname"

    }
    #Clear mail field in AD
    Set-ADUser -Identity $Username -Clear Mail
    #Set to hide from address lists
    Set-ADUser -Identity $Username -Replace @{msExchHideFromAddressLists=$TRUE}
    #Attribute must be set to sync in AD connect and a transform rule must be in place
    Set-ADUser -Identity $Username -Replace @{"msDS-CloudExtensionAttribute1"="HideFromGAL"}
    LogWrite "Removed $Fullname from global address list"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $FullName has been moved to Disabled Users"

    If ($Mailbox){
        #Set mailbox to shared
        If ($Mailbox.isShared -eq $False){
            Set-mailbox -Identity $Mailbox.alias -Type Shared
            Write-Host "Setting mailbox for $FullName to Shared"
        }
        Else{
            Write-Host "Mailbox is already shared"
        }
        #Forward mailbox
        If ($ForwardingAddress -ne $Null){
            Set-mailbox -ForwardingAddress $ForwardingAddress
            Write-Host "Forwarding mailbox to $ForwardingAddress"
        }
        Else{
            Write-Host "Could not forward mailbox"
        }
    }
    Else{
        Write-Host "Please log into Office 365 to set mailbox to shared and forward"
    }

    Write-Host "User offboarding for $FullName is complete"
}

SyncADtoO365
