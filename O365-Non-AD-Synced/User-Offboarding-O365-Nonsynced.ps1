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
    $ExchangeConnected = ExchConnected
}

#Variable used for Logwrite function
$Logfile = "C:\Source\Scripts\User-Offboarding-O365-Nonsynced-Log.log"
#See Common-Functions.psm1 for LogWrite function

$ScriptParams = Import-Csv .\ADDS-O365-Nonsynced-Params.csv
$Userlist = Import-Csv .\User-Offboarding-O365-Nonsynced-List.csv
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
	If(-Not $Username){
        Write-Host "Could not locate user $Fullname"
        continue
    }
    $FLName = $FName[0] + $LName
    $ForwardingAddress = $Offuser.ForwardingAddress

    If(MSOLConnected){
        $MsolUser = Get-MsolUser | Where-Object{(($_.FirstName -eq $FName) -and ($_.LastName -eq $LName))}
    }
    If($ExchangeConnected){
        $Mailbox = Get-Mailbox -Identity $FullName
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
    
    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $FullName has been moved to Disabled Users"

    #Set mailbox to shared, set forwarding
    If ($Mailbox){
		If(-Not($Mailbox.isShared)){
			Set-mailbox -Identity $Mailbox.alias -Type Shared
			Write-Host "Setting mailbox for $FullName to Shared"
		}
		If($?){
			$Mailbox.isShared = $True
		}
		If($ForwardingAddress){
			Set-mailbox -Identity $Mailbox.alias -ForwardingAddress $ForwardingAddress
		}
		Else{
			LogWrite "Not forwarding $Username, as no address was specified"
		}
        Get-mailbox $Mailbox.alias | Select Name,IsShared,ForwardingAdddress
    }
    Else{
        Write-Host "Could not set mailbox to shared or enter forwarding address. 
        Check the query results above to verify that it is shared.
        Please log into Office 365 to finish offboarding tasks if any of the above failed."
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
