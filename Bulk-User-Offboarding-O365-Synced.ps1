cd C:\source\scripts\
Import-Module ActiveDirectory
Import-Module .\Common-Functions.psm1

function MSOLConnected {
    Get-MsolDomain -ErrorAction SilentlyContinue | out-null
    $result = $?
    return $result
}

#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect.ps1
    Write-Host "Enter Office 365 admin credentials when prompted"
}

$Logfile = "C:\Source\Scripts\Bulk-User-Offboarding-O365-Synced-Log.log"

Function LogWrite
{
   Param ([string]$logstring)

   $TimeStamp = get-date -uformat "%Y/%m/%d %H:%M"

   Add-content $Logfile -value "[$TimeStamp] $logstring"
}

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

    #Remove proxy attributes
    Set-ADUser -Identity $Username -Clear Mail
    Set-ADUser -Identity $Username -Clear ProxyAddresses
    Set-ADUser -Identity $Username -Add @{ProxyAddresses = "SMTP:$FLastName@$MSDomain"}
    LogWrite "Cleared proxy addresses"
    Set-ADUser -Identity $Username -Replace @{msExchHideFromAddressLists=$TRUE}
    LogWrite "Removed $Fullname from global address list"

    #Move user to "Disabled Users" OU
    Get-ADUser $Username | Move-ADObject -TargetPath $DisabledUserPath
    LogWrite "User $FullName has been moved to Disabled Users"


    Write-Host "User offboarding for $FullName is complete"
}

SyncADtoO365
