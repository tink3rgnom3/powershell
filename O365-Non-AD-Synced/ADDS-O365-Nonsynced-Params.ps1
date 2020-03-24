param(
	#If parameter is string, use single or double quotes. If [switch], use $ before the value ($True/$False)
	[string]$DisabledUserPath="OU=Disabled Users,OU=Users,OU=MyBusiness,DC=ortho,DC=local",
	[string]$MSDomain="company.onmicrosoft.com",
	[string]$EmailDomain="savannahfoot.com",
	[string]$EmailFormat="FLastName",
	[string]$MSTenantName="savannahfoot",
	[string]$UserPath="OU=SBSUsers,OU=Users,OU=MyBusiness,DC=ortho,DC=local"
)