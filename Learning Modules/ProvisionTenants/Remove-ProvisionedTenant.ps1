<#
.SYNOPSIS
  Deletes a tenant and entries from the catalog.  Deletes the database if tenant is in a single-tenant db. 
#>
[cmdletbinding()]
param (
    [parameter(Mandatory=$true)][string]$TenantName
)

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
    # removes the tenant from the database and catalog
    # and drops the database if it was created as a single-tenant db
    Remove-Tenant `
        -Catalog $catalog `
        -TenantKey $tenantKey

    Write-Output "Tenant '$TenantName' is removed."
}
else
{
    Write-Output "'$TenantName' is not in the catalog."
    exit
}
