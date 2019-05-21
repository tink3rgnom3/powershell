cd C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    Start-Sleep -Seconds 10
    exit
}
Import-Module ActiveDirectory

#Connect to MS Online
If (-Not (MSOLConnected)){
    .\O365PSOnlineConnect.ps1
    Write-Host "Enter Office 365 admin credentials when prompted"
}

$Userlist = Import-Csv .\Create-New-AD-User-O365-Synced-List.csv
$Parameters = Import-Csv .\Create-New-AD-User-O365-Synced-Params.csv
$EmailDomain = $Parameters.EmailDomain
$Path = $Parameters.Path
$EmailConvention = $Parameters.EmailFormat
$Clientmsdomain = $Parameters.MSDomain

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
#   If(($NewUser.Path -ne $Null) -or ($NewUser.Path -ne "")){
#       $Path = $NewUser.Path
#    Else{
#       $Path = $Parameters.Path
#    }
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
    If($NewUser.EmailDomain -ne $Null){
        $EmailDomain = $NewUser.EmailDomain
    }
    $EmailAddr = "$EmailUsername@$EmailDomain"

    
    #Check if user exists
    $UserExists = Get-ADUser -Filter {SamAccountName -eq $UserName} -ErrorAction SilentlyContinue
    If ($UserExists -eq $Null){
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -DisplayName $FullName -SamAccountName $UserName -AccountPassword $Password  -UserPrincipalName $Principal -Path $Path -Description $Description -Enabled:$True -Department $Department -Title $Description
        Set-ADUser $Username -UserPrincipalName "$Username@$EmailDomain"
        Write-Host "User $Username has been created"
        Get-ADUser $Username
    }
    Else{
        Write-Host "User $Fullname already exists"
        continue
    }

    $PrimarySMTP = "SMTP:"
    $SecondarySMTP = "smtp:"

    $UserFullName = $FirstName + $LastName

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

    If($SourceUser -ne $Null){
        $UserGroups = Get-ADPrincipalGroupMembership $SourceUser | Where {$_.Name -ne "Domain Users"}
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

SyncADtoO365
