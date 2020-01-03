Set-ExecutionPolicy Unrestricted -Force
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