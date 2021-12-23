Set-ExecutionPolicy Unrestricted -Force
Import-Module ADSync -ErrorAction Stop
Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop