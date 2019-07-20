Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    exit
}

Import-Module ActiveDirectory


#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect
    Write-Host "Enter Office 365 admin credentials when prompted"
}

#Variable used for Logwrite function
$Logfile = "C:\Source\Scripts\Bulk-User-Offboarding-O365-Synced-Log.log"
#See Common-Functions.psm1 for LogWrite function

$ScriptParams = Import-Csv .\ADDS-O365-Synced-Params.csv
$Userlist = Import-Csv .\Bulk-User-Offboarding-O365-Synced-List.csv
$DisabledUserPath = $ScriptParams.DisabledUserPath
$MSDomain = $ScriptParams.MSDomain

If(-Not ($DisabledUserPath)){
    $DisabledUserPath = Get-ADOrganizationalUnit -Filter * | Where-Object {($_.DistinguishedName -like "OU=Users,OU=Disabled*") -or ($_.Name -eq "Disabled Accounts" -or "Disabled Users")} | ForEach-Object{$_.DistinguishedName}
}

ForEach($OffUser in $Userlist){

    $FName = $Offuser.FirstName
    $LName = $Offuser.LastName
    $FullName = "$FName $LName"
    $Username = Get-AdUser -Filter {(GivenName -eq $FName) -and (Surname -eq $LName)} | ForEach-Object{$_.SamAccountName}
    $FLName = $FName[0] + $LName
    $ForwardingAddress = $Offuser.ForwardingAddress

    If(MSOLConnected){
        $Mailbox = Get-Mailbox -Identity $FullName
        $MsolUser = Get-MsolUser | Where-Object{($_.FName -eq $FName) -and ($_.LName -eq $LName)}
    }
    #Disable AD User
    Set-ADUser $Username -Enabled $False
    LogWrite "User $FullName is disabled"

    #Get AD Groups and remove from all but Domain Users
    $JoinedGroups = Get-ADPrincipalGroupMembership $Username | Where-Object {$_.Name -ne "Domain Users"}

    LogWrite "Removing $FullName from:"
    ForEach($Group in $JoinedGroups){ 
    
        $GroupName = $Group.Name
        Remove-ADGroupmember -Identity $Group -Members $Username -Confirm:$False -ErrorAction SilentlyContinue
        LogWrite "$Groupname"

    }
    #Clear mail field in AD
    Set-ADUser -Identity $Username -Clear Mail
	#Reset user principal name domain to AD domain
	Set-ADUser -Identity $Username -UserPrincipalName $Username@$env:USERDNSDOMAIN
    #Set to hide from address lists
    Set-ADUser -Identity $Username -Replace @{msExchHideFromAddressLists=$TRUE}
    #Attribute must be set to sync in AD connect and a transform rule must be in place
    Set-ADUser -Identity $Username -Replace @{"msDS-CloudExtensionAttribute1"="HideFromGAL"}
    LogWrite "Removed $Fullname from global address list"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $FullName has been moved to Disabled Users"

    #Set mailbox to shared, set forwarding
    If ($Mailbox){
		If(-Not($Mailbox.isShared)){
			Set-mailbox -Identity $Mailbox.alias -Type Shared
			Write-Host "Setting mailbox for $FullName to Shared"
		}
		If($ForwardingAddress){
			Set-mailbox -Identity $Mailbox.alias -ForwardingAddress $ForwardingAddress
		}
    }
    Else{
        Write-Host "Could not set to shared. Please log into Office 365 to finish offboarding tasks"
    }
    
    If (($Mailbox.IsShared) -And ($MSolUser)){
        Set-MsolUserLicense -UserPrincipalName $MsolUser.UserPrincipalName -RemoveLicenses $MSolUser.Licenses.AccountSkuId
		Write-Host "Removed Office 365 license from $Fullname"
		#Change user to .onmicrosoft.com format
        Set-MsolUserPrincipalName -UserPrincipalName $MsolUser.UserPrincipalName -NewUserPrincipalName "$FLName@$MSDomain"
    }
    Else{
        Write-Host "Mailbox is not shared. Did not remove license at this time."
    }

    Write-Host "User offboarding for $FullName is complete"
}

SyncADtoO365
