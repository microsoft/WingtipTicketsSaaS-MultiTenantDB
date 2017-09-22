<#
.SYNOPSIS
  Deletes a tenant.  Deletes the database and all entries from the catalog. 
#>
[cmdletbinding()]
param (
    [parameter(Mandatory=$true)][string]$TenantName
)


# Stop execution on error 
#$ErrorActionPreference = "Stop"

Import-Module $PSScriptRoot\..\Common\CatalogAndDatabaseManagement -Force
Import-Module $PSScriptRoot\..\Common\SubscriptionManagement -Force

# Ensure logged in to Azure
Initialize-Subscription

# Get the resource group and user names used when the application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

$catalog = Get-Catalog `
            -ResourceGroupName $wtpUser.ResourceGroupName `
            -WtpUser $wtpUser.Name `

$tenantKey = Get-TenantKey -TenantName $TenantName

# Check if the tenant is registered in the catalog. If so, remove the tenant
if(Test-TenantKeyInCatalog -Catalog $catalog -TenantKey $tenantKey)
{
    Remove-Tenant `
        -Catalog $catalog `
        -TenantKey $tenantKey

    Write-Output "'$TenantName' is removed."
}
else
{
    Write-Output "'$TenantName' is not in the catalog."
    exit
}
