cd C:\Source\Scripts
Import-Module ActiveDirectory

$Userlist = Import-Csv .\Create-New-AD-User-Premises-List.csv
$Parameters = Import-Csv .\Create-New-AD-User-Premises-Params.csv
$LocalDomain = $env:USERDNSDOMAIN
$MailServer = $Parameters.MailServer
$Path = $Parameters.Path
$ExchSession = New-PSSession -ConfigurationName Microsoft.exchange -ConnectionUri "http://$MailServer.$LocalDomain/powershell"
Import-PSSession $ExchSession -AllowClobber

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
    If ($UserExists -eq $Null){
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -DisplayName $FullName -SamAccountName $UserName -AccountPassword $Password  -UserPrincipalName $Principal -Description $Description -Enabled:$True -Path $Path -Department $Department
        Write-Host "User $Username has been created"
        Get-ADUser $Username

        Enable-Mailbox -Identity $Username
    
        #Copy groups from another user
        If($UserToCopy -ne $Null){
            $SourceUser = Get-ADUser $UserToCopy -ErrorAction SilentlyContinue
            }

        If($SourceUser -ne $Null){
            $UserGroups = Get-ADPrincipalGroupMembership $SourceUser | Where {$_.Name -ne "Domain Users"}
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
