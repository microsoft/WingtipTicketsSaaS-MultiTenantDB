# Script for provisioning and de-provisioning tenants in a sharded multi-tenant database.

# IMPORTANT: Before provisioning tenants using this script ensure the catalog is initialized using 
# http://events.wingtip-mt.<USER>.trafficmanager.net

# Parameters for scenarios #1, #2 and #3, provision or deprovision a single tenant 
$TenantName = "Red Maple Racing" #  name of the venue to be added/removed as a tenant
$VenueType  = "motorracing" # valid types: blues, classicalmusic, dance, jazz, judo, motorracing, multipurpose, opera, rockmusic, soccer 
$PostalCode = "98052"

$Scenario = 1
<# Select the scenario to run
 Scenario
    1    Provision a tenant into a shared database with other tenants
    2    Provision a tenant into its own database
    3    Remove a provisioned tenant
    4    Provision a batch of tenants into a shared database
    5    Get tenant key

#>

## ------------------------------------------------------------------------------------------------

Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force
Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\WtpConfig" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

$wtpUser = Get-UserConfig
$config = Get-Configuration

### Provision a tenant in a shared database with other tenants
if ($Scenario -eq 1)
{
    New-Tenant `
        -TenantName $TenantName `
        -VenueType $VenueType `
        -PostalCode $PostalCode `
        -ErrorAction Stop `
        > $null

    Write-Output "Provisioning complete for tenant '$TenantName'"

    # Open the events page for the new venue
    Start-Process "http://events.wingtip-mt.$($wtpUser.Name).trafficmanager.net/$(Get-NormalizedTenantName $TenantName)"
    
    exit
}
#>

### Provision a tenant in its own database
if ($Scenario -eq 2)
{
    & $PSScriptRoot\New-TenantAndDatabase `
        -TenantName $TenantName `
        -VenueType $VenueType `
        -PostalCode $PostalCode `
        -ErrorAction Stop `
        > $null

    Write-Output "Provisioning complete for tenant '$TenantName'"

    # Open the events page for the new venue
    Start-Process "http://events.wingtip-mt.$($wtpUser.Name).trafficmanager.net/$(Get-NormalizedTenantName $TenantName)"
    
    exit
}

### Remove a provisioned tenant
if ($Scenario -eq 3)
{
    & $PSScriptRoot\Remove-ProvisionedTenant.ps1 -TenantName $TenantName 
    exit

}

### Provision a batch of tenants
if ($Scenario -eq 4)
{
    $config = Get-Configuration

    $tenantNames = $config.TenantNameBatch

    & $PSScriptRoot\New-TenantBatch.ps1 `
        -NewTenants $tenantNames 

    exit
} 

### get tenant key
if ($Scenario -eq 5)
{
    $tenantKey = Get-TenantKey -TenantName $TenantName
    
    $tenantKey

    exit
} 

Write-Output "Invalid scenario selected"
              