Set-ExecutionPolicy Unrestricted -Force

Try{
    Set-Location C:\Source\Scripts -ErrorAction Stop
    Import-Module .\Common-Functions.psm1 -ErrorAction Stop
    . .\ADDS-O365-Synced-Params.ps1
}
Catch{
    Write-Host "Could not locate C:\Source\Scripts or supporting files in folder. Attempting sync..."
}

If(-Not $RemoteADSync){
	Try{
		Import-Module ADSync
	}
	Catch{
		Write-Host "Could not import ADSync module"
	}

	Try{
		Write-Host "Starting AD Sync..."
		Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
	}
	Catch [System.InvalidOperationException]{
		Write-Host "AAD is busy. Waiting 60 seconds to try again."
		Start-Sleep -Seconds 60
		Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
	}
	Catch{
		Write-Host "Could not run AD Sync at this time. Please try again later."
	}
}
Else{
	Try{
		Invoke-Command -ComputerName $ScriptParams.ADSyncSrv -ScriptBlock {C:\Source\Scripts\AD_Sync.ps1}
	}
	Catch{
		Write-Host "Remote AD Sync failed. Check that script is present and remote server has PS Remoting enabled"
	}
}