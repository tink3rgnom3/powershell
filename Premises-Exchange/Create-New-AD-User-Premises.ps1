Set-Location C:\Source\Scripts
Import-Module .\Common-Functions.psm1

If (-Not (CheckRunningAsAdmin)){
    Write-Host "You are not currently running as admin. Please relaunch as admin."
    exit
}
Import-Module ActiveDirectory

$Userlist = Import-Csv .\Create-New-AD-User-Premises-List.csv
$ScriptParams = Import-Csv .\ADDS-Premises-Params.csv
$LocalDomain = $env:USERDNSDOMAIN
$MailServer = $ScriptParams.MailServer
$UserPath = $ScriptParams.UserPath
$ExchSession = New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
Import-PSSession $ExchSession -AllowClobber

Write-Host "The default OU is $UserPath. Please make sure user is moved to the correct OU if this is not it."

ForEach($NewUser in $Userlist){

    $FirstName = $NewUser.FirstName
    $LastName = $NewUser.Lastname
    $FullName = "$Firstname $LastName"
    $UserName = $NewUser.Username
	$Principal = "$Username@$env:USERDNSDOMAIN"
    $Password = (ConvertTo-SecureString -String ($NewUser.Passwd) -AsPlainText -Force)
    $Description = $NewUser.Description
    $Department = $NewUser.Department
    $UserToCopy = $NewUser.UserToCopy

    #Check if user exists
    $UserExists = Get-ADUser -Filter {SamAccountName -eq $UserName} -ErrorAction SilentlyContinue
    If (-Not ($UserExists)){
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -DisplayName $FullName -SamAccountName $UserName -AccountPassword $Password  -UserPrincipalName $Principal -Description $Description -Enabled:$True -Path $UserPath -Department $Department
        Write-Host "User $Username has been created"
        Get-ADUser $Username

        Enable-Mailbox -Identity $Username
    
        #Copy groups from another user
        If($UserToCopy -ne "None"){
            $SourceUser = Get-ADUser $UserToCopy -ErrorAction SilentlyContinue
            }

        If($SourceUser){
            $UserGroups = Get-ADPrincipalGroupMembership $SourceUser | Where-Object {$_.Name -ne "Domain Users"}
            ForEach($Group in $UserGroups){
				$Groupname = $Group.name
                Add-ADGroupMember -Identity $Group -Members $Username -ErrorAction SilentlyContinue
                Write-Host "Copying user $Username to $Groupname"
                }

            }

        Else{
            Write-Host "No groups to copy"
        }

    }
    Else{
        Write-Host "Someone already has this username"
    }


}
