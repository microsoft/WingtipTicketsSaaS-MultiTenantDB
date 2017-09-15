# Script for initializing the catalog with the pre-provided tenants.

# It is intended this is replaced by an equivalent function run automatically on deployment of the app. 


## ------------------------------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

Import-Module $PSScriptRoot\..\Common\CatalogAndDatabaseManagement -Force
Import-Module $PSScriptRoot\..\Common\SubscriptionManagement -Force
Import-Module $PSScriptRoot\..\WtpConfig -Force
Import-Module $PSScriptRoot\..\UserConfig -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho


# Get the resource group and user names used when the application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

# Get the WTP app configuration
$config = Get-Configuration

$catalogAdminPassword = ConvertTo-SecureString $($config.CatalogAdminPassword) –asplaintext –force 

# create common pscredential that will be shared for catalog and tenant server use 
$cred = New-Object System.Management.Automation.PSCredential `
    -ArgumentList $($config.catalogAdminUserName), $catalogAdminPassword 
   
$catalogServerName = $config.CatalogServerNameStem + $wtpUser.Name
$catalogServerFullyQualifiedName = $catalogServerName + ".database.windows.net"

Write-Output 'Creating/checking resource group'

#check is target resource group exists
$resourceGroup = Get-AzureRmResourceGroup -Name $wtpUser.ResourceGroupName -ErrorAction SilentlyContinue

if (!$resourceGroup)
{
    # deploy resource group
    $resourceGroup = New-AzureRmResourceGroup -Name $wtpUser.ResourceGroupName -Location 'East US'
}

Write-Output 'Creating/checking catalog server'

# check catalog server exists
$catalogServer = Get-AzureRmSqlServer `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -ServerName $catalogServerName `
    -ErrorAction SilentlyContinue

if(!$catalogServer)
{
    # Deploy catalog server
    $catalogServer = New-AzureRmSqlServer `
        -ResourceGroupName $wtpUser.ResourceGroupName `
        -ServerName $catalogServerName `
        -Location 'East US' `
        -SqlAdministratorCredentials $cred       

    # add open firewall rule
    $catalogServer | New-AzureRmSqlServerFirewallRule `
        -FirewallRuleName Open `
        -StartIpAddress 0.0.0.0 -EndIpAddress 255.255.255.255
}

Write-Output 'Creating/checking catalog database'

# Check catalog database exists
$catalogDatabase = Get-AzureRmSqlDatabase `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -ServerName $catalogServerName `
    -DatabaseName $config.CatalogDatabaseName `
    -ErrorAction SilentlyContinue

if (!$catalogDatabase)
{
    # Deploy catalog database
    $catalogDatabase = New-AzureRmSqlDatabaseCopy `
        -CopyResourceGroupName $wtpUser.ResourceGroupName `
        -CopyServerName $catalogServerName `
        -CopyDatabaseName $config.CatalogDatabaseName `
        -ResourceGroupName 'wingtip-mt-gold' `
        -ServerName 'wingtip-catalog-mt-gold' `
        -DatabaseName 'wingtipcatalogdb'
    
    # Get the catalog database just deployed
    $catalogDatabase = Get-AzureRmSqlDatabase `
        -ResourceGroupName $wtpUser.ResourceGroupName `
        -ServerName $catalogServerName `
        -DatabaseName $config.CatalogDatabaseName `

}

Write-Output 'Creating/checking basetenantdb'

# Check catalog database exists
$baseTenantDb = Get-AzureRmSqlDatabase `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -ServerName $catalogServerName `
    -DatabaseName $config.GoldenTenantsDatabaseName `
    -ErrorAction SilentlyContinue

if (!$baseTenantDb)
{
    # Deploy basetenantdb database
    New-AzureRmSqlDatabaseCopy `
        -CopyResourceGroupName $wtpUser.ResourceGroupName `
        -CopyServerName $catalogServerName `
        -CopyDatabaseName $config.GoldenTenantsDatabaseName `
        -ResourceGroupName 'wingtip-mt-gold' `
        -ServerName 'wingtip-catalog-mt-gold' `
        -DatabaseName $config.GoldenTenantsDatabaseName

}

# Initialize shard map manager from catalog database
[Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardMapManager]$shardMapManager = Get-ShardMapManager `
    -SqlServerName $catalogServerFullyQualifiedName `
    -UserName $config.CatalogAdminUserName `
    -Password $config.CatalogAdminPassword `
    -SqlDatabaseName $config.CatalogDatabaseName

if (!$shardmapManager)
{
    throw "Failed to initialize shard map manager from '$($config.CatalogDatabaseName)' database."
}

# check if shard map exists
[Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardMap]$shardMap = Get-ListShardMap `
    -KeyType $([int]) `
    -ShardMapManager $shardMapManager `
    -ListShardMapName $config.CatalogShardMapName

if(!$shardMap)
{
    # Initialize new shard map object with existing catalog shard map
    [Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardMap]$shardMap = New-ListShardMap `
        -KeyType $([int]) `
        -ShardMapManager $shardMapManager `
        -ListShardMapName $config.CatalogShardMapName

    if (!$shardMap)
    {
        throw "Failed to load shard map '$($config.CatalogShardMapName)' from '$($config.CatalogDatabaseName)' database. Ensure catalog is initialized by opening the Events app and try again."
    }
}
$catalog = New-Object PSObject -Property @{
    ShardMapManager=$shardMapManager
    ShardMap=$shardMap
    FullyQualifiedServerName = $catalogServerFullyQualifiedName
    Database = $catalogDatabase
    }

Write-Output 'Creating/checking tenants server'

$tenantsServerName = $config.TenantsServerNameStem + $wtpUser.Name
$tenantsServerFullyQualifiedName = $tenantsServerName + '.database.windows.net'

$tenantsServer = Get-AzureRmSqlServer `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -ServerName $tenantsServerName `
    -ErrorAction SilentlyContinue

if(!$tenantsServer)
{
    # Deploy tenant server
    $tenantsServer = New-AzureRmSqlServer `
        -ResourceGroupName $wtpUser.ResourceGroupName `
        -ServerName $tenantsServerName `
        -Location 'East US' `
        -SqlAdministratorCredentials $cred       

    # add open firewall rule
    $tenantsServer | New-AzureRmSqlServerFirewallRule `
        -FirewallRuleName Open `
        -StartIpAddress 0.0.0.0 -EndIpAddress 255.255.255.255
}

Write-Output 'Creating/checking tenants database'

# Check tenant database exists
$tenantsDatabase = Get-AzureRmSqlDatabase `
    -ResourceGroupName $wtpUser.ResourceGroupName `
    -ServerName $tenantsServerName `
    -DatabaseName $config.TenantsDatabaseName `
    -ErrorAction SilentlyContinue

if (!$tenantsDatabase)
{
    # Deploy tenant database
    New-AzureRmSqlDatabaseCopy `
        -CopyResourceGroupName $wtpUser.ResourceGroupName `
        -CopyServerName $tenantsServerName `
        -CopyDatabaseName $config.TenantsDatabaseName `
        -ResourceGroupName 'wingtip-mt-gold' `
        -ServerName 'wingtip-tenants-mt-gold' `
        -DatabaseName 'tenants1'

    # Get the database just deployed
    $tenantsDatabase = Get-AzureRmSqlDatabase `
        -ResourceGroupName $wtpUser.ResourceGroupName `
        -ServerName $tenantsServerName `
        -DatabaseName $config.TenantsDatabaseName 
}

Write-Output 'Registering tenants database in catalog'

# Add the database to the catalog shard map (idempotent)
Add-Shard -ShardMap $Catalog.ShardMap `
    -SqlServerName $tenantsServerFullyQualifiedName `
    -SqlDatabaseName $tenantsDatabase.DatabaseName


Write-Output 'Registering predefined tenants in catalog'

$tenantNames = 'Contoso Concert Hall', 'Dogwood Dojo','Fabrikam Jazz Club'

foreach($tenantName in $tenantNames)
{
    $tenantKey = Get-TenantKey -TenantName $tenantName

    # Add the tenant-to-database mapping to the catalog (idempotent)
    Add-ListMapping `
        -KeyType $([int]) `
        -ListShardMap $Catalog.ShardMap `
        -SqlServerName $tenantsServerFullyQualifiedName `
        -SqlDatabaseName $tenantsDatabase.DatabaseName `
        -ListPoint $tenantKey

    # Add the tenant name to the catalog as extended meta data (idempotent)
    Add-ExtendedTenantMetaDataToCatalog `
        -Catalog $catalog `
        -TenantKey $tenantKey `
        -TenantName $tenantName
}

Write-Output 'Complete'