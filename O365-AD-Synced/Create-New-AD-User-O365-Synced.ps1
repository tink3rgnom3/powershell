Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    Start-Sleep -Seconds 10
    exit
}
Try{
	Import-Module ActiveDirectory -ErrorAction Stop
}
Catch {
	Write-Host "Could not load Active Directory module. This script will exit."
	exit
}

$Userlist = Import-Csv .\Create-New-AD-User-O365-Synced-List.csv
$ScriptParams = Import-Csv .\ADDS-O365-Synced-Params.csv
$EmailDomain = $ScriptParams.EmailDomain
$UserPath = $ScriptParams.UserPath
$EmailConvention = $ScriptParams.EmailFormat
$Clientmsdomain = $ScriptParams.MSDomain
$MSTenantName = $ScriptParams.MSTenantName

Write-Host "The default OU is $UserPath. Please make sure user is moved to the correct OU if this is not it."

#Check for AD Connect service
$AzureADchk = Get-Service AzureADConnectHealthSyncMonitor -ErrorAction SilentlyContinue
$RemoteADSyncChk = $ScriptParams.RemoteADSync
$ADSyncSrv = $ScriptParams.ADSyncSrv

If( -Not $AzureADchk -and $RemoteADSyncChk -ne "True"){
	Write-Host "Azure AD Synchronization service not found. Sync will not run for this script. If this client is synced to AD, please ensure you run it on a server running AD Sync service"
	}
	
#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect.ps1
}

ForEach($NewUser in $Userlist){
    $FirstName = $NewUser.FirstName
    $LastName = $NewUser.Lastname
    $FullName = "$Firstname $LastName"
    $UserName = $NewUser.Username
    $FirstInitial = $FirstName[0]
    $LastInitial = $LastName[0]
    $Principal = "$Username@$env:USERDNSDOMAIN"
    $Password = (ConvertTo-SecureString -String ($NewUser.Passwd) -AsPlainText -Force)
    $Description = $NewUser.Description
    $Department = $NewUser.Department
    $UserToCopy = $NewUser.UserToCopy
    If(($NewUser.EmailDomain -ne $EmailDomain)){
        $EmailDomain = $NewUser.EmailDomain
    }
    Else{
        $EmailDomain = $ScriptParams.EmailDomain
    }
    <#
    #This is causing issues with user being created. Removing for now
    If(($NewUser.CustomOU -ne "") -or (-Not ($NewUser.CustomOU))){
        $UserPath = $NewUser.CustomOU
    }
    Else{
        $UserPath = $ScriptParams.UserPath
        }
    #>

    If($EmailConvention -eq "FirstNameLastName"){
        $EmailUsername = $FirstName + $LastName
    }
    ElseIf($EmailConvention -eq "FirstNameLastInitial"){
        $EmailUsername = $FirstName + $LastInitial
    }
    ElseIf($EmailConvention -eq "Firstname.LastName"){
        $Emailusername = $FirstName + "." + $LastName
    }
    ElseIf($EmailConvention -eq "FirstName"){
        $EmailUsername = $FirstName
    }
    Else{
        $EmailUsername = $FirstInitial + $LastName
    }
    If(-Not ($NewUser.EmailDomain)){
        $EmailDomain = $NewUser.EmailDomain
    }
    $EmailAddr = "$EmailUsername@$EmailDomain"

    
    #Check if user exists
    $UserExists = Get-ADUser -Filter {SamAccountName -eq $UserName} -ErrorAction SilentlyContinue
    If (-Not ($UserExists)){
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -DisplayName $FullName -SamAccountName $UserName -AccountPassword $Password  -UserPrincipalName $Principal -Path $UserPath -Description $Description -Enabled:$True -Department $Department -Title $Description
        Set-ADUser $Username -UserPrincipalName "$Username@$EmailDomain"
        Write-Host "User $Username has been created"
        Get-ADUser $Username
    }
    Else{
	#Preparing for restoring disabled user to AD
	#	If($NewUser.ReturningUser -eq "Y"){}
	#Else{
        Write-Host "User $Fullname already exists as $Username. Try a different username"
        continue
	#	}
    }

    $PrimarySMTP = "SMTP:"
    $SecondarySMTP = "smtp:"

    #Variable not used, may be removed in the future
    #$UserFullName = $FirstName + $LastName

    $UserMSEmail = "$Username@$ClientMSDomain"

    $ProxyPrimary = $PrimarySMTP + $EmailAddr
    $ProxySecondary = $SecondarySMTP + $UserMSEmail


    Get-ADUser -Identity $Username | Set-ADUser -Add @{ProxyAddresses="$ProxyPrimary"}
    Get-ADUser -Identity $Username | Set-ADUser -Add @{ProxyAddresses="$ProxySecondary"}
    Get-AdUser -Identity $Username | Set-ADUser -Replace @{mail="$EmailAddr"}
    #Get-AdUser -Identity $Username | Set-ADUser -Replace @{title="$Description"}

        #Copy groups from another user
    If($UserToCopy -ne "None"){
        $SourceUser = Get-ADUser $UserToCopy -ErrorAction SilentlyContinue
        }

    If($SourceUser){
        $UserGroups = Get-ADPrincipalGroupMembership $SourceUser | Where-Object {$_.Name -ne "Domain Users"}
        ForEach($Group in $UserGroups){
            $GroupName = $Group.name
            Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction SilentlyContinue
            Write-Host "Copying user $Username to $Groupname"
            }

        }

    Else{
        Write-Host "No groups to copy"
    }
	    
}

If($AzureADchk){
	SyncADtoO365
}
ElseIf($RemoteADSyncChk){
    Try{
        Invoke-Command -ComputerName $ADSyncSrv -FilePath .\AD_Sync.ps1 -ErrorAction Stop
    }
    Catch{
        Write-Host "Remote command failed. Make sure remote server has PS Remoting enabled and AD_Sync.ps1 is present on this server."
    }
}
#Work in progress - assign O365 license
ForEach($NewUser in $Userlist){
    Start-Sleep -Seconds 30
    $USR = Get-MsolUser | Where-Object{($_.FirstName -eq $FirstName) -and ($_.LastName -eq $LastName)}
    If($USR){
	    .\Assign-O365-License.ps1
    }
    Else{
        Write-Host "Could not assign license to $FirstName $Lastname. 
        Please assign license manually."
    }
}