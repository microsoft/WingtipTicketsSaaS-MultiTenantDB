<#
.SYNOPSIS
  Provisions a batch of tenants in a multi-tenant database and registers them in the catalog   

.DESCRIPTION
  Creates a batch of new tenants in the default tenants database.

#>

Param(
    [Parameter(Mandatory=$true)]
    [string[][]]$NewTenants
)

Import-Module $PSScriptRoot\..\Common\SubscriptionManagement -Force
Import-Module $PSScriptRoot\..\Common\CatalogAndDatabaseManagement -Force
Import-Module $PSScriptRoot\..\UserConfig -Force
Import-Module $PSScriptRoot\..\WtpConfig -Force

## MAIN SCRIPT ## ----------------------------------------------------------------------------

# Ensure logged in to Azure
Initialize-Subscription

# Get the resource group and user names used when the application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

# Get the WTP app configuration
$config = Get-Configuration

$serverName = $config.TenantsServerNameStem + $WtpUser.Name

# Check the tenants server exists
$tenantsServer = Get-AzureRmSqlServer -ResourceGroupName $wtpUser.ResourceGroupName -ServerName $serverName  

if (!$tenantsServer)
{
    throw "Could not find tenants server '$serverName'."
}

# Get the catalog 
$catalog = Get-Catalog -ResourceGroupName $wtpUser.ResourceGroupName -WtpUser $wtpUser.Name

foreach ($newTenant in $NewTenants)
{
    $newTenantName = $newTenant[0].Trim()
    $newTenantVenueType = $newTenant[1].Trim()
    $newTenantPostalCode = $newTenant[2].Trim()

    try
    {
        Test-LegalName $newTenantName > $null
        Test-LegalVenueTypeName $newTenantVenueType > $null
    }
    catch
    {
        throw
    }

    $tenantKey = Get-TenantKey -TenantName $newTenantName
    
    # Check if a tenant with this key is aleady registered in the catalog
    if (Test-TenantKeyInCatalog -Catalog $catalog -TenantKey $tenantKey)
    {
        Write-Output "Tenant '$newTenantName' is already registered in the catalog.  Skipping..."
        continue    
    }   
           
    # Initialize the tenant's venue information in the default tenants database
    New-Tenant `
        -TenantName $newTenantName `
        -VenueType $newTenantVenueType `
        -PostalCode $newTenantPostalCode

    Write-Output "Provisioning complete for tenant '$newTenantName'"
} 

Write-Output "Batch provisioning complete."