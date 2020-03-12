param(
	#If parameter is string, use single or double quotes. If [switch], use $ before the value ($True/$False)
	[string]$DisabledUserPath="OU=Users,OU=Disabled,OU=Company,DC=contoso,DC=local",
	[string]$MSDomain="company.onmicrosoft.com",
	[string]$EmailDomain="contoso.com",
	[string]$EmailFormat="FirstnameLastName",
	[string]$MSTenantName="companyllc",
	[string]$UserPath="OU=Users,OU=Company,DC=contoso,DC=local",
	[switch]$RemoteADSync=$False,
	[string]$ADSyncSrv="None"
)