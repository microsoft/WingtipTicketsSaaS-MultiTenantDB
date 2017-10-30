<#
.SYNOPSIS
  Provisions a new tenant in a new single-tenant database and registers it in the catalog   
#>

Param(
    [Parameter(Mandatory=$true)]
    [string]$TenantName,

    [Parameter(Mandatory=$false)]
    [string]$VenueType = "multipurpose",

    [Parameter(Mandatory=$false)]
    [string]$PostalCode = "98052"
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

# Get the catalog 
$catalog = Get-Catalog -ResourceGroupName $wtpUser.ResourceGroupName -WtpUser $wtpUser.Name

$tenantKey = Get-TenantKey -TenantName $TenantName
    
# Check if a tenant with this key is aleady registered in the catalog
if (Test-TenantKeyInCatalog -Catalog $catalog -TenantKey $tenantKey)
{
    throw "Tenant '$TenantName' is already registered in the catalog."    
} 

# check the venue type name is valid
if (-not(Test-ValidVenueType -Catalog $catalog -VenueType $VenueType))
{
    throw "Invalid venue type '$VenueType'"
}

# use the default server 
$serverName = $config.TenantsServerNameStem + $wtpUser.Name

# base the new database name on the tenant name
$databaseName = Get-NormalizedTenantName -TenantName $TenantName
 
# create a new tenant database
$tenantDatabase = New-TenantsDatabase `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -WtpUser $wtpUser.Name `
    -ServerName $serverName `
    -DatabaseName $databaseName

# register the tenant database as a shard in the catalog
Add-TenantDatabaseToCatalog `
    -Catalog $catalog `
    -ServerName $serverName `
    -DatabaseName $databaseName
           
# Initialize the venue information in the tenant database and register in the catalog
New-Tenant `
    -TenantName $TenantName `
    -VenueType $VenueType `
    -PostalCode $PostalCode `
    -TenantDatabase $TenantDatabase

Write-Output "Tenant '$TenantName' initialized and registered in the catalog."
 