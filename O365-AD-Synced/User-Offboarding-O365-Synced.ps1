Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    exit
}
Try{
	Import-Module ActiveDirectory -ErrorAction Stop
}
Catch {
	Write-Host "Could not load Active Directory module. This script will exit."
	exit
}

#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect
    $ExchangeConnected = ExchConnected
}

#Variable used for Logwrite function
$Logfile = "C:\Source\Scripts\User-Offboarding-O365-Synced-Log.log"
#See Common-Functions.psm1 for LogWrite function

. .\ADDS-O365-Synced-Params.ps1
$Userlist = Import-Csv .\User-Offboarding-O365-Synced-List.csv

If(-Not ($DisabledUserPath)){
    Write-Host "Could not locate a path for disabled users. Please correct and run again."
    Start-sleep -Seconds 15
    exit
}

ForEach($OffUser in $Userlist){

    $FName = $Offuser.FirstName
    $LName = $Offuser.LastName
    $FullName = "$FName $LName"
    $Username = Get-AdUser -Filter {(GivenName -eq $FName) -and (Surname -eq $LName)} | ForEach-Object{$_.SamAccountName}
    If(-Not $Username){
        Write-Host -ForegroundColor Red -BackgroundColor Yellow "Could not locate user $Fullname. Please check user exists in AD under that name."
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
    #Set to hide from address lists
    Set-ADUser -Identity $Username -Replace @{msExchHideFromAddressLists=$TRUE}
    #Attribute must be set to sync in AD connect and a transform rule must be in place
	#Need a rule to determine if the functional level is below 2012 and if so, leave out the next line
    Set-ADUser -Identity $Username -Replace @{"msDS-CloudExtensionAttribute1"="HideFromGAL"}
    LogWrite "Removed $Fullname from global address list"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $FullName has been moved to Disabled Users"

    #Set mailbox to shared, set forwarding
    If ($Mailbox){
		If(-Not($Mailbox.isShared)){
			Try{
				Set-mailbox -Identity $Mailbox.alias -Type Shared
				Write-Host "Setting mailbox for $FullName to Shared"
			}
			Catch{
				LogWrite "Could not set mailbox to Shared. Please ensure this is complete before removing license."
			}
		}
		#After setting the mailbox to shared, the object did not update, so this next step was necessary
		If($?){
			$Mailbox.isShared = $True
		}
		If($ForwardingAddress){
			Try{
				Set-mailbox -Identity $Mailbox.alias -ForwardingAddress $ForwardingAddress
				LogWrite "Forwarding $Username to $ForwardingAddress"
			}
			Catch{
				LogWrite "Unable to set mailbox to shared. Please make sure forwarding was completed."
			}
		}
		Else{
			LogWrite "Not forwarding $Username, as no address was specified"
		}
        Get-mailbox $Mailbox.alias | Select Name,IsShared,ForwardingAdddress
    }
    Else{
        Write-Host "Please log into Office 365 to finish offboarding tasks if any of the above failed."
    }

    If (($Mailbox.IsShared) -And ($MSolUser)){
                Try{
            Set-MsolUserLicense -UserPrincipalName $MsolUser.UserPrincipalName -RemoveLicenses $MSolUser.Licenses.AccountSkuId
		    Write-Host "Removed Office 365 license from $Fullname"
		    #Change user to .onmicrosoft.com format
            Set-MsolUserPrincipalName -UserPrincipalName $MsolUser.UserPrincipalName -NewUserPrincipalName "$FLName@$MSDomain"
        }
        Catch{
            Write-Host "Unable to remove license at this time."
        }
    }
    Else{
        Write-Host "Did not remove license at this time. Please check that mailbox is shared and remove license manually."
    }

    Write-Host "User offboarding for $FullName is complete"
}

SyncADtoO365
