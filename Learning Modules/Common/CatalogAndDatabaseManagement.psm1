<#
.Synopsis
  This module implements a tenant-focused catalog and database API over the Shard Management APIs. 
  It simplifies catalog management by focusing on operations done to a tenant and tenant databases.
#>

Import-Module $PSScriptRoot\..\WtpConfig -Force
Import-Module $PSScriptRoot\..\UserConfig -Force
Import-Module $PSScriptRoot\AzureShardManagement -Force
Import-Module $PSScriptRoot\SubscriptionManagement -Force
Import-Module sqlserver -ErrorAction SilentlyContinue

# Stop execution on error
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
    Adds extended tenant meta data associated with a mapping using the raw value of the tenant key
#>
function Add-ExtendedTenantMetaDataToCatalog
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey,

        [parameter(Mandatory=$true)]
        [string]$TenantName
    )

    $config = Get-Configuration

    # Get the raw tenant key value used within the shard map
    $tenantRawKey = Get-TenantRawKey ($TenantKey)
    $rawkeyHexString = $tenantRawKey.RawKeyHexString


    # Add the tenant name into the Tenants table
    $commandText = "
        MERGE INTO Tenants as [target]
        USING (VALUES ($rawkeyHexString, '$TenantName')) AS source
            (TenantId, TenantName)
        ON target.TenantId = source.TenantId
        WHEN MATCHED THEN
            UPDATE SET TenantName = source.TenantName
        WHEN NOT MATCHED THEN
            INSERT (TenantId, TenantName)
            VALUES (source.TenantId, source.TenantName);"

    Invoke-SqlAzureWithRetry `
        -ServerInstance $Catalog.FullyQualifiedServerName `
        -Username $config.TenantAdminuserName `
        -Password $config.TenantAdminPassword `
        -Database $Catalog.Database.DatabaseName `
        -Query $commandText `
        -ConnectionTimeout 30 `
        -QueryTimeout 30 `
}

<#
.SYNOPSIS
    Registers a tenant database in the catalog
#>
function Add-TenantDatabaseToCatalog
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [string]$ServerName,
        
        [parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    $ServerFullyQualifiedName = $ServerName + ".database.windows.net"

    # Add the database to the catalog shard map (idempotent)
    Add-Shard -ShardMap $Catalog.ShardMap `
        -SqlServerName $ServerFullyQualifiedName `
        -SqlDatabaseName $DatabaseName

}


<#
.SYNOPSIS
    Registers a tenant in the catalog, including adding the tenant name as extended tenant meta data.
#>
function Add-TenantToCatalog
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [string]$TenantName,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey,

        [parameter(Mandatory=$true)]
        [string]$ServerName,

        [parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    $ServerFullyQualifiedName = $ServerName + ".database.windows.net"

    # Add the tenant-to-database mapping to the catalog (idempotent)
    Add-ListMapping `
        -KeyType $([int]) `
        -ListShardMap $Catalog.ShardMap `
        -SqlServerName $ServerFullyQualifiedName `
        -SqlDatabaseName $DatabaseName `
        -ListPoint $TenantKey

    # Add the tenant name to the catalog as extended meta data (idempotent)
    Add-ExtendedTenantMetaDataToCatalog `
        -Catalog $Catalog `
        -TenantKey $TenantKey `
        -TenantName $TenantName
}


<#
.SYNOPSIS
    Finds names of tenants that match an input string.
#>
function Find-TenantNames
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [string] $SearchString
    )
    Test-LegalNameFragment $SearchString

    $config = Get-Configuration

    $adminUserName = $config.CatalogAdminUserName
    $adminPassword = $config.CatalogAdminPassword
   
    $commandText = "SELECT TenantName from Tenants WHERE TenantName LIKE '%$SearchString%'";
             
    $tenantNames = Invoke-SqlAzureWithRetry `
        -Username $adminUserName `
        -Password $adminPassword `
        -ServerInstance $catalog.FullyQualifiedServerName `
        -Database $catalog.Database.DatabaseName `
        -ConnectionTimeout 45 `
        -Query $commandText `

    return $tenantNames            
}


<#
.SYNOPSIS
    Initializes and returns a catalog object based on the catalog database created during deployment of the
    WTP application.  The catalog contains the initialized shard map manager and shard map, which can be used to access
    the associated databases (shards) and tenant key mappings.
#>
function Get-Catalog
{
    param (
        [parameter(Mandatory=$true)]
        [string]$ResourceGroupName,

        [parameter(Mandatory=$true)]
        [string]$WtpUser
    )
    $config = Get-Configuration

    $catalogServerName = $config.CatalogServerNameStem + $WtpUser
    $catalogServerFullyQualifiedName = $catalogServerName + ".database.windows.net"

    # Check catalog database exists
    $catalogDatabase = Get-AzureRmSqlDatabase `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $catalogServerName `
        -DatabaseName $config.CatalogDatabaseName `
        -ErrorAction Stop

    # Initialize shard map manager from catalog database
    [Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardMapManager]$shardMapManager = Get-ShardMapManager `
        -SqlServerName $catalogServerFullyQualifiedName `
        -UserName $config.CatalogAdminUserName `
        -Password $config.CatalogAdminPassword `
        -SqlDatabaseName $config.CatalogDatabaseName

    if (!$shardmapManager)
    {
        throw "Failed to initialize shard map manager from '$($config.CatalogDatabaseName)' database. Ensure catalog is initialized by opening the Events app and try again."
    }

    # Initialize shard map
    [Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardMap]$shardMap = Get-ListShardMap `
        -KeyType $([int]) `
        -ShardMapManager $shardMapManager `
        -ListShardMapName $config.CatalogShardMapName

    If (!$shardMap)
    {
        throw "Failed to load shard map '$($config.CatalogShardMapName)' from '$($config.CatalogDatabaseName)' database. Ensure catalog is initialized by opening the Events app and try again."
    }
    else
    {
        $catalog = New-Object PSObject -Property @{
            ShardMapManager=$shardMapManager
            ShardMap=$shardMap
            FullyQualifiedServerName = $catalogServerFullyQualifiedName
            Database = $catalogDatabase
            }

        return $catalog
    }
}


<#
.SYNOPSIS
  Validates and normalizes the name for use in creating the tenant key and database name. Removes spaces and sets to lowercase.
#>
function Get-NormalizedTenantName
{
    param
    (
        [parameter(Mandatory=$true)]
        [string]$TenantName
    )

    return $TenantName.Replace(' ','').ToLower()
}


function Get-Tenant
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [string] $TenantName
    )
    $tenantKey = Get-TenantKey -TenantName $TenantName

    try
    {
        $tenantShard = $Catalog.ShardMap.GetMappingForKey($tenantKey)     
    }
    catch
    {
        throw "Tenant '$TenantName' not found in catalog."
    }

    $tenantServerName = $tenantShard.Shard.Location.Server.Split('.',2)[0]
    $tenantDatabaseName = $tenantShard.Shard.Location.Database

    # requires tenant resource group is same as catalog resource group
    $TenantResourceGroupName = $Catalog.Database.ResourceGroupName
     
    $tenantDatabase = Get-AzureRmSqlDatabase `
        -ResourceGroupName $TenantResourceGroupName `
        -ServerName $tenantServerName `
        -DatabaseName $tenantDatabaseName 

    $tenant = New-Object PSObject -Property @{
        Name = $TenantName
        Key = $tenantKey
        Database = $tenantDatabase
    }

    return $tenant            
}

<#
.SYNOPSIS
    Retrieves the server and database name for each database registered in the catalog.
#>
function Get-TenantDatabaseLocations
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog
    )
    # return all databases registered in the catalog shard map
    return Get-Shards -ShardMap $Catalog.ShardMap
}


<#
.SYNOPSIS
    Returns an integer tenant key from a tenant name for use in the catalog.
#>
function Get-TenantKey
{
    param
    (
        # Tenant name 
        [parameter(Mandatory=$true)]
        [String]$TenantName
    )

    $normalizedTenantName = $TenantName.Replace(' ', '').ToLower()

    # Produce utf8 encoding of tenant name 
    $utf8 = New-Object System.Text.UTF8Encoding
    $tenantNameBytes = $utf8.GetBytes($normalizedTenantName)

    # Produce the md5 hash which reduces the size
    $md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $tenantHashBytes = $md5.ComputeHash($tenantNameBytes)

    # Convert to integer for use as the key in the catalog 
    $tenantKey = [bitconverter]::ToInt32($tenantHashBytes,0)

    return $tenantKey
}

<#
.SYNOPSIS
    Returns the raw key used within the shard map for the tenant  Returned as an object containing both the
    byte array and a text representation suitable for insert into SQL.
#>
function Get-TenantRawKey
{
    param
    (
        # Integer tenant key value
        [parameter(Mandatory=$true)]
        [int32]$TenantKey
    )

    # retrieve the byte array 'raw' key from the integer tenant key - the key value used in the catalog database.
    $shardKey = New-Object Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.ShardKey($TenantKey)
    $rawValueBytes = $shardKey.RawValue

    # convert the raw key value to text for insert into the database
    $rawValueString = [BitConverter]::ToString($rawValueBytes)
    $rawValueString = "0x" + $rawValueString.Replace("-", "")

    $tenantRawKey = New-Object PSObject -Property @{
        RawKeyBytes = $shardKeyRawValueBytes
        RawKeyHexString = $rawValueString
    }

    return $tenantRawKey
}


<#
.SYNOPSIS
  Provisions a new Wingtip SaaS tenant in the specified tenanats database   

#>
function Initialize-Tenant 
{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ServerName,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true)]
        [int]$TenantKey,

        [Parameter(Mandatory=$true)]
        [string]$TenantName,

        [Parameter(Mandatory=$false)]
        [string]$VenueType = 'multipurpose',

        [Parameter(Mandatory=$false)]
        [string]$PostalCode = "98052",

        [Parameter(Mandatory=$false)]
        [string]$CountryCode = "USA"
    )
    # Set up tenant initialization script
    $CommandText = "exec sp_NewVenue $TenantKey, '$TenantName', '$VenueType', '$postalCode', '$CountryCode' "         

    Invoke-SqlAzureWithRetry `
        -ServerInstance ($ServerName + ".database.windows.net") `
        -Database $DatabaseName `
        -Query $commandText `
        -UserName $config.TenantAdminUserName `
        -Password $config.TenantAdminPassword `
        -ConnectionTimeout 30 `
        -QueryTimeout 15 ` 

}

<#
.SYNOPSIS
    Invokes a SQL command. Uses ADO.NET not Invoke-SqlCmd. Always uses an encrypted connection.
#>
function Invoke-SqlAzure{
    param
    (
        [Parameter(Mandatory=$true)]
        [string] $ServerInstance,

        [Parameter(Mandatory=$false)]
        [string] $DatabaseName,

        [Parameter(Mandatory=$true)]
        [string] $Query,

        [Parameter(Mandatory=$true)]
        [string] $UserName,

        [Parameter(Mandatory=$true)]
        [string] $Password,

        [Parameter(Mandatory=$false)]
        [int] $ConnectionTimeout = 30,
        
        [Parameter(Mandatory=$false)]
        [int] $QueryTimeout = 60
      )
    $Query = $Query.Trim()

    $connectionString = `
        "Data Source=$ServerInstance;Initial Catalog=$DatabaseName;Connection Timeout=$ConnectionTimeOut;User ID=$UserName;Password=$Password;Encrypt=true;"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($Query,$connection)
    $command.CommandTimeout = $QueryTimeout

    $connection.Open()

    $reader = $command.ExecuteReader()
    
    $results = @()

    while ($reader.Read())
    {
        $row = @{}
        
        for ($i=0;$i -lt $reader.FieldCount; $i++)
        {
           $row[$reader.GetName($i)]=$reader.GetValue($i)
        }
        $results += New-Object psobject -Property $row
    }
     
    $connection.Close()
    $connection.Dispose()
    
    return $results  
}


<#
.SYNOPSIS
    Wraps Invoke-SqlAzure. Retries on any error with exponential back-off policy.  
    Assumes query is idempotent.  Always uses an encrypted connection.  
#>
function Invoke-SqlAzureWithRetry{
    param(
        [parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [parameter(Mandatory=$true)]
        [string]$ServerInstance,

        [parameter(Mandatory=$true)]
        [string]$Query,

        [parameter(Mandatory=$true)]
        [string]$UserName,

        [parameter(Mandatory=$true)]
        [string]$Password,

        [string]$ConnectionTimeout = 30,

        [int]$QueryTimeout = 30
    )

    $tries = 1
    $limit = 5
    $interval = 2
    do  
    {
        try
        {
            return Invoke-SqlAzure `
                        -ServerInstance $ServerInstance `
                        -Database $DatabaseName `
                        -Query $Query `
                        -Username $UserName `
                        -Password $Password `
                        -ConnectionTimeout $ConnectionTimeout `
                        -QueryTimeout $QueryTimeout `
        }
        catch
        {
                    if ($tries -ge $limit)
                    {
                        throw $_.Exception.Message
                    }                                       
                    Start-Sleep ($interval)
                    $interval += $interval
                    $tries += 1                                      
        }
    }while (1 -eq 1)
}


<#
.SYNOPSIS
    Wraps Invoke-SqlCmd.  Retries on any error with exponential back-off policy.  
    Assumes query is idempotent. Always uses an encrypted connection.
#>
function Invoke-SqlCmdWithRetry{
    param(
        [parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [parameter(Mandatory=$true)]
        [string]$ServerInstance,

        [parameter(Mandatory=$true)]
        [string]$Query,

        [parameter(Mandatory=$true)]
        [string]$UserName,

        [parameter(Mandatory=$true)]
        [string]$Password,

        [string]$ConnectionTimeout = 30,

        [int]$QueryTimeout = 30
    )

    $tries = 1
    $limit = 5
    $interval = 2
    do  
    {
        try
        {
            return Invoke-Sqlcmd `
                        -ServerInstance $ServerInstance `
                        -Database $DatabaseName `
                        -Query $Query `
                        -Username $UserName `
                        -Password $Password `
                        -ConnectionTimeout $ConnectionTimeout `
                        -QueryTimeout $QueryTimeout `
                        -EncryptConnection
        }
        catch
        {
                    if ($tries -ge $limit)
                    {
                        throw $_.Exception.Message
                    }                                       
                    Start-Sleep ($interval)
                    $interval += $interval
                    $tries += 1                                      
        }

    }while (1 -eq 1)
}


<#
.SYNOPSIS
  Provisions a new Wingtip SaaS tenant in the tenant database and registers the tenant/database mapping 
  in the catalog

#>
function New-Tenant 
{
    Param(
        [Parameter(Mandatory=$true)]
        [string]$TenantName,

        [Parameter(Mandatory=$false)]
        [string]$VenueType = "multipurpose",

        [Parameter(Mandatory=$false)]
        [string]$PostalCode = "98052",

        [Parameter(Mandatory=$false)]
        [object]$TenantDatabase

    )

    # Get the resource group and user names used when the application was deployed from UserConfig.psm1.  
    $wtpUser = Get-UserConfig

    # Get the WTP app configuration
    $config = Get-Configuration

    $catalog = Get-Catalog -ResourceGroupName $wtpUser.ResourceGroupName -WtpUser $($wtpUser.Name) 

    # Validate tenant name
    $TenantName = $TenantName.Trim()
    Test-LegalName $TenantName > $null

    #validate venue type against venue types in basetenantdb
    Test-ValidVenueType $VenueType -Catalog $catalog > $null

    # Compute the tenant key from the tenant name, key is used to register the tenant in the catalog 
    $tenantKey = Get-TenantKey -TenantName $TenantName 

    # Check if a tenant with this key is aleady registered in the catalog
    if (Test-TenantKeyInCatalog -Catalog $catalog -TenantKey $tenantKey)
    {
        throw "A tenant with name '$TenantName' is already registered in the catalog."    
    }

    # if a tenant database is input use that, otherwise use the default database 
    if($TenantDatabase)
    {    
        $serverName = $TenantDatabase.ServerName
        $databaseName = $TenantDatabase.DatabaseName
    }
    else
    {
        $serverName = $config.TenantsServerNameStem + $wtpUser.Name
        $databaseName = $config.TenantsDatabaseName
    }

    # Initialize tenant data in the database 
    Initialize-Tenant `
        -ServerName $serverName `
        -DatabaseName $databaseName `
        -TenantKey $tenantKey `
        -TenantName $TenantName `
        -VenueType $VenueType `
        -PostalCode $PostalCode `
        -CountryCode 'USA'

    # Register the tenant in the catalog
    Add-TenantToCatalog -Catalog $catalog `
        -TenantName $TenantName `
        -TenantKey $tenantKey `
        -ServerName $serverName `
        -DatabaseName $DatabaseName

}

<#
.SYNOPSIS
    Creates a new tenants database by copying the basetenantdb using an ARM template.  Database may be used to host one or more tenants.
#>

function New-TenantsDatabase
{
    param (
        [parameter(Mandatory=$true)]
        [string]$ResourceGroupName,

        [parameter(Mandatory=$true)]
        [string]$WtpUser,

        [parameter(Mandatory=$true)]
        [string]$ServerName,

        [parameter(Mandatory=$false)]
        [string]$DatabaseName

    )

    $config = Get-Configuration

    # Check the tenant server exists
    $Server = Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $ServerName

    if (!$Server)
    {
        throw "Could not find tenant server '$ServerName'."
    }

    $tenantServerFullyQualifiedName = $ServerName + ".database.windows.net"
    
    if (!$DatabaseName)
    {
        $DatabaseName = $config.TenantDatabaseName
    }

    # Check the tenants database does not exist

    $database = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -ErrorAction SilentlyContinue

    if ($database)
    {
        throw "Tenants database '$DatabaseName' already exists.  Exiting..."
    }

    # create the tenants database
    try
    {
        # The tenants database is provisioned by copying the 'golden' tenants database from the catalog server.  
        # An alternative approach could be to deploy an empty database and then import a suitable bacpac into it to initialize it.

        # Construct the resource id for the 'golden' tenant database 
        #$AzureContext = Get-AzureRmContext
        $subscriptionId = Get-SubscriptionId
        $SourceDatabaseId = "/subscriptions/$($subscriptionId)/resourcegroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$($config.CatalogServerNameStem)$WtpUser/databases/$($config.GoldenTenantsDatabaseName)"

        # Use an ARM template to create the tenant database by copying the 'golden' database
        $deployment = New-AzureRmResourceGroupDeployment `
            -TemplateFile ($PSScriptRoot + "\" + $config.TenantsDatabaseCopyTemplate) `
            -Location $Server.Location `
            -ResourceGroupName $ResourceGroupName `
            -SourceDatabaseId $sourceDatabaseId `
            -ServerName $ServerName `
            -DatabaseName $DatabaseName `
            -RequestedServiceObjectiveName $config.TenantsDatabaseSingletonServiceObjective `
            -ErrorAction Stop `
            -Verbose
    }
    catch
    {
        Write-Error $_.Exception.Message
        Write-Error "An error occured deploying the tenants database"
        throw
    }

    $database = Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -ErrorAction Stop

    return $database

}


<#
.SYNOPSIS
    Opens tenant-related resources in the portal.
#>
function Open-TenantResourcesInPortal
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [string]$TenantName,

        [parameter(Mandatory=$true)]
        [string[]]$ResourceTypes

    )
    # get the tenant object
    $tenant = Get-Tenant `
        -Catalog $Catalog `
        -TenantName $TenantName

    $subscriptionId = $tenant.Database.ResourceId.Split('/',4)[2]
    $ResourceGroupName = $tenant.Database.ResourceGroupName
    $serverName = $tenant.Database.ServerName
    $databaseName = $tenant.Database.DatabaseName

    if ($ResourceTypes -contains 'server')
    {
        # open the server in the portal
        Start-Process "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Sql/servers/$serverName/overview"
    }

    if ($ResourceTypes -contains 'elasticpool' -and $tenant.Database.CurrentServiceObjectiveName -eq 'ElasticPool')
    {
        $poolName = $tenant.Database.ElasticPoolName

        # open the elastic pool blade in the portal
        Start-Process "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Sql/servers/$serverName/elasticPools/$poolName/overview"
    }

    if ($ResourceTypes -contains 'database')
    {
        # open the database blade in the portal
        Start-Process "https://portal.azure.com/#resource/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Sql/servers/$serverName/databases/$databaseName/overview"
    }
}


<#
.SYNOPSIS
    Removes extended tenant entry from catalog  
#>
function Remove-ExtendedTenant
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey,

        [parameter(Mandatory=$true)]
        [string]$ServerName,

        [parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    $config = Get-Configuration

    # Get the raw tenant key value used within the shard map
    $tenantRawKey = Get-TenantRawKey ($TenantKey)
    $rawkeyHexString = $tenantRawKey.RawKeyHexString


    # Delete the tenant name from the Tenants table
    $commandText = "
        DELETE FROM Tenants 
        WHERE TenantId = $rawkeyHexString;"

    Invoke-SqlAzureWithRetry `
        -ServerInstance $Catalog.FullyQualifiedServerName `
        -Username $config.CatalogAdminuserName `
        -Password $config.CatalogAdminPassword `
        -Database $Catalog.Database.DatabaseName `
        -Query $commandText `
}


<#
.SYNOPSIS
    Removes all data asscociate with a tenant from its hosting database, plus its extended metadata and mapping entry from the catalog database.
#>
function Remove-Tenant
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey
    )

    $config = Get-Configuration

    # Take tenant offline
    Set-TenantOffline -Catalog $Catalog -TenantKey $TenantKey

    $tenantMapping = $Catalog.ShardMap.GetMappingForKey($TenantKey)
    $tenantShardLocation = $tenantMapping.Shard.Location
    $databaseNameRoot = $tenantShardLocation.Database.Substring(0,$config.tenantsDatabaseNameStem.Length).ToLower()

    # determine if the tenant is hosted in a generic multi-tenant database
    if ($databaseNameRoot -eq $config.tenantsDatabaseNameStem)
    {
        # Delete tenant entry from the database

        $commandText = "EXEC sp_DeleteVenue $TenantKey"

        Invoke-SqlAzureWithRetry `
            -ServerInstance $tenantShardLocation.Server `
            -Username $config.TenantAdminuserName `
            -Password $config.TenantAdminPassword `
            -Database $tenantShardLocation.Database `
            -Query $commandText

        # Delete tenant mapping from catalog
        $Catalog.ShardMap.DeleteMapping($tenantMapping)

    }
    else
    {           
        # Delete tenant mapping from catalog
        $Catalog.ShardMap.DeleteMapping($tenantMapping)      
        
        # Get updated shard entry and delete it from catalog
        $tenantShard = $Catalog.ShardMap.GetShard($tenantShardLocation)      
        $Catalog.ShardMap.DeleteShard($tenantShard)

        # Delete tenant database
        Remove-AzureRmSqlDatabase `
            -ResourceGroupName $Catalog.Database.ResourceGroupName `
            -ServerName ($tenantShard.Location.Server).Split('.')[0] `
            -DatabaseName $tenantShard.Location.Database `
            -ErrorAction Continue `
            >$null
                  
    }

    # Remove Tenant entry from Tenants table
    Remove-ExtendedTenant `
        -Catalog $Catalog `
        -TenantKey $TenantKey `
        -ServerName ($tenantShardLocation.Server).Split('.')[0] `
        -DatabaseName $tenantShardLocation.Database 

}


<#
.SYNOPSIS
    Marks a tenant as offline in the Wingtip tickets tenant catalog
#>
function Set-TenantOffline
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey
    )

    $tenantMapping = ($Catalog.ShardMap).GetMappingForKey($TenantKey)

    # Mark tenant offline if its mapping status is online, and suppress output
    if ($tenantMapping.Status -eq "Online")
    {
        ($Catalog.ShardMap).MarkMappingOffline($tenantMapping) >$null
    }
}


<#
.SYNOPSIS
    Marks a tenant as online in the Wingtip tickets tenant catalog
#>
function Set-TenantOnline
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32]$TenantKey
    )

    $tenantMapping = ($Catalog.ShardMap).GetMappingForKey($TenantKey)
    $recoveryManager = ($Catalog.ShardMapManager).getRecoveryManager()

    # Detect any differences between local and global shard map -accomodates case where database has been restored while offline
    $shardMapMismatches = $recoveryManager.DetectMappingDifferences($tenantMapping.Shard.Location, $Catalog.ShardMap.Name)

    # Resolve any differences between local and global shard map. Use global shard map as a source of truth if there's a conflict
    foreach ($mismatch in $shardMapMismatches)
    {
        $recoveryManager.ResolveMappingDifferences($mismatch, [Microsoft.Azure.SqlDatabase.ElasticScale.ShardManagement.Recovery.MappingDifferenceResolution]::KeepShardMapMapping)
    }

    # Mark tenant online if its mapping status is offline, and suppress output
    if ($tenantMapping.Status -eq "Offline")
    {
       ($Catalog.ShardMap).MarkMappingOnline($tenantMapping) >$null
    }
}

<#
.SYNOPSIS
    Tests if a tenant key is registered. Returns true if the key exists in the catalog (whether online or offline) or false if it does not.
#>
function Test-TenantKeyInCatalog
{
    param(
        [parameter(Mandatory=$true)]
        [object]$Catalog,

        [parameter(Mandatory=$true)]
        [int32] $TenantKey
    )

    try
    {
        ($Catalog.ShardMap).GetMappingForKey($tenantKey) > $null
        return $true
    }
    catch
    {
        return $false
    }
}


<#
.SYNOPSIS
    Validates a name contains only legal characters
#>
function Test-LegalName
{
    param(
        [parameter(Mandatory=$true)]
        [ValidateScript(
        {
            if ($_ -match '^[A-Za-z0-9][A-Za-z0-9 \-_]*[^\s+]$') 
            {
                $true
            } 
            else 
            {
                throw "'$_' is not an allowed name.  Use a-z, A-Z, 0-9, ' ', '-', or '_'.  Must start with a letter or number and have no trailing spaces."
            }
         }
         )]
        [string]$Input
    )
    return $true
}


<#
.SYNOPSIS
    Validates a name fragment contains only legal characters
#>
function Test-LegalNameFragment
{
    param(
        [parameter(Mandatory=$true)]
        [ValidateScript(
        {
            if ($_ -match '^[A-Za-z0-9 \-_][A-Za-z0-9 \-_]*$') 
            {
                return $true
            } 
            else 
            {
                throw "'$_' is invalid.  Names can only include a-z, A-Z, 0-9, space, hyphen or underscore."
            }
         }
         )]
        [string]$Input
    )
}


<#
.SYNOPSIS
    Validates a venue type name contains only legal characters
#>
function Test-LegalVenueTypeName
{
    param(
        [parameter(Mandatory=$true)]
        [ValidateScript(
        {
            if ($_ -match '^[A-Za-z][A-Za-z]*$') 
            {
                return $true
            } 
            else 
            {
                throw "'$_' is invalid.  Venue type names can only include a-z, A-Z."
            }
         }
         )]
        [string]$Input
    )
}


<#
.SYNOPSIS
    Validates that a venue type is a supported venue type (validated against venue types in the  
    golden tenant database on the catalog server)
#>
function Test-ValidVenueType
{
    param(
        [parameter(Mandatory=$true)]
        [string]$VenueType,

        [parameter(Mandatory=$true)]
        [object]$Catalog
    )
    $config = Get-Configuration

    $commandText = "
        SELECT Count(VenueType) AS Count FROM [dbo].[VenueTypes]
        WHERE VenueType = '$VenueType'"

    $results = Invoke-SqlAzureWithRetry `
                    -ServerInstance $Catalog.FullyQualifiedServerName `
                    -Username $config.CatalogAdminuserName `
                    -Password $config.CatalogAdminPassword `
                    -Database $config.GoldenTenantsDatabaseName `
                    -Query $commandText

    if($results.Count -ne 1)
    {
        throw "Error: '$VenueType' is not a supported venue type."
    }

    return $true
}
