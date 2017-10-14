[CmdletBinding()]
Param(
    # Resource group containing the 
    [Parameter(Mandatory=$True)]    
    [string]$WtpResourceGroupName,
    
    [Parameter(Mandatory=$True)]    
    [string]$WtpUser, 

    # Intensity of load - equates roughly to the workload in DTU applied to each tenant 
    [int][validaterange(1,100)] $Intensity = 40,

    # If enabled causes databases in different pools on the same server to be loaded unequally
    # Use to demonstrate load balancing databases between pools  
    [switch]$Unbalanced,

    # Duration of the load generation session in minutes. Due to the way loads are applied, some 
    # activity may continue after this time. 
    [int]$DurationMinutes = 120,

    # If enabled, causes a single tenant to have a specific distinct load applied
    # Use with SingleTenantIntensity to demonstrate moving a database in or out of a pool  
    [switch] $SingleTenant,

    # If SingleTenant is enabled, defines the load in DTU applied to an isolated tenant 
    [int][validateRange(1,100)] $SingleTenantDtu = 95,

    # If singleTenant is enabled, identifes the tenant database.  If not specified a random tenant database is chosen
    [string]$SingleTenantDatabaseName = "contosoconcerthall",

    [switch]$LongerBursts,

    # if OneTime switch is used then jobs are submitted and the script stops, othewise it continues to poll for new tenants 
    [bool]$OneTime
)

## Configuration

$WtpUser = $WtpUser.ToLower()

Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription

$config = Get-Configuration

$tenantAdminUser = $config.TenantAdminUsername
$tenantAdminPassword = $config.TenantAdminPassword

## MAIN SCRIPT ------------------------------------------------------------------------------

# Get the catalog 
$catalog = Get-Catalog -ResourceGroupName $WtpResourceGroupName -WtpUser $WtpUser 

# Burst durations are randomized, the following set the min and max duration in seconds
$burstMinDuration = 25 
$burstMaxDuration = 40

# boost increases burst duration, increasing the likelihood of overlaps  
if ($LongerBursts.IsPresent) {$burstMinDuration = 30; $burstMaxDuration = 52}

# interval between bursts is randomized, the following set min and max interval in seconds for normal range
$intervalMin = 100
$intervalMax = 360

# longer bursts also decreases the interval between bursts, increasing likelihood of overlaps
if ($LongerBursts.IsPresent) {$intervalMin = $intervalMin * 0.9; $intervalMax = $intervalMax * 0.9}

# DTU burst level is randomized by applying a factor with min and max values 
$burstMinFactor = 0.6
$burstMaxFactor = 1.1

# Load factor skews the load on databases for unbalanced pools or intense single tenant usage scenarios.  
# Load factor impacts DTU levels and interval between bursts -> interval = interval/loadFactor (low load factor ==> longer intervals)
$highPoolLoadFactor = 1.20
$lowPoolLoadFactor = 0.50 
# Load factor for single tenant burst mode
$intenseLoadFactor = 15.00

# density load factor, decreases the database load with more dbs, allowing more interesting demos with small numbers of tenants
# It impacts the interval between bursts [interval = interval + (interval * densityLoadFactor * dbcount)]
# 0 removes the effect, 0.1 will double the typical interval for 10 dbs  
$densityLoadFactor = 0.11

$CatalogServerName = $config.CatalogServerNameStem + $WtpUser

$jobs = @{}

## Start job invocation loop

$start = Get-Date

$sleepCount = 0
$sleep = 10

$settings = "`nDuration: $DurationMinutes mins, Intensity: $intensity, LongerBursts: $LongerBursts, Unbalanced: $Unbalanced, SingleTenant: $SingleTenant"

if($SingleTenant)
{
    if ($SingleTenantDatabaseName -ne "")
    {
        $settings += ", Database: $SingleTenantDatabaseName"
    }
    $settings += ", DTU: $singleTenantDtu"
}

Write-Output $settings
Write-Output "`nInvoking a load generation job for each tenant. Will check for new tenants every $sleep seconds for $durationMinutes minutes."  
write-output "`nUse Ctrl-C to stop invoking jobs.  Already started jobs can be managed as follows:" 
Write-Output "  Get-Job to view status of all jobs" 
Write-Output "  Receive-Job <job id> -Keep to view output from an individual job" 
Write-Output "  Stop-Job <job id> to stop a job.  Use Stop-Job * to stop all jobs (which can take a minute or more)"
Write-Output "  Remove-Job <job id> to remove a job.  Use Remove-Job * to remove all jobs.  Use -Force to stop and remove.`n"

while (1 -eq 1)
{
    $mappings = Get-Mappings -ShardMap $catalog.ShardMap

    #$shards = Get-Shards -ShardMap $catalog.ShardMap

    # Array that will contain all tenants to be targeted
    $tenants = @()
    $loadFactor = 1.0

    #$ServerNames = @()
    foreach ($mapping in $mappings)
    {        
        $serverName = ($mapping.ShardLocation.Datasource.split(":",2)[1]).split(",",2)[0]
        $databaseName = $mapping.ShardLocation.Database

        $burstLevel = Get-Random -Minimum $burstMinFactor -Maximum $burstMaxFactor # randomizes the intensity of each database
        $burstDtu = [math]::Ceiling($burstLevel * $Intensity)

        # add tenant 
        $tenantProperties = @{ServerName=$serverName;DatabaseName=$databaseName;TenantKey=$mapping.Value; BurstDtu=$burstDtu;LoadFactor=$loadFactor}
        $tenant = New-Object PSObject -Property $tenantProperties

        $tenants += $tenant

        # $ServerNames += $serverName
    }
    
    <#
    #$serverNames = $serverNames| sort | Get-Unique
   
    # Array that will contain all databases to be targeted
    $allDbs = @() 

    foreach($serverName in $serverNames)
    {
        [array]$serverPools = (Get-AzureRmSqlElasticPool -ResourceGroupName $WtpResourceGroupName -ServerName $serverName).ElasticPoolName
        $poolNumber = 1

        foreach($elasticPool in $serverPools)
        {
            # Set up the relative load level for each pool
            if($Unbalanced.IsPresent -and $serverPools.Count -gt 1)
            {
                # alternating pools on the same server are given high and low loads 
                if ($poolNumber % 2 -ne 0)
                {
                    $loadFactor = $highPoolLoadFactor
                    Write-Output ("Pool " + $elasticPool + " on " + $serverName + " has high load factor - " + $loadFactor)         
                }
                else
                {
                    $loadFactor = $lowPoolLoadFactor 
                    Write-Output ("Pool "+ $elasticPool + " on " + $serverName + " has low load factor - " + $loadFactor)        
                }
            }
            else
            {
                # Neutral default for the relative load level for databases in a pool
                $loadFactor = 1.0
            }
               
            $elasticDbs = (Get-AzureRmSqlElasticPoolDatabase -ResourceGroupName $WtpResourceGroupName -ServerName $serverName -ElasticPoolName $elasticPool).DatabaseName

            Foreach($elasticDb in $elasticDbs)
            {          
                # vary the baseline DTU level of each database using a random factor x the input intensity x load factor for the pool 

                $burstFactor = Get-Random -Minimum $burstMinFactor -Maximum $burstMaxFactor # randomizes the intensity of each database
                $burstDtu = [math]::Ceiling($Intensity * $BurstFactor * $loadFactor)


                # add db with its pool-based load factor to the list
                $dbProperties = @{ServerName=($serverName + ".database.windows.net");DatabaseName=$elasticDb;BurstDtu=$burstDtu;LoadFactor=$loadFactor;ElasticPoolName=$elasticPool;PoolDbCount=$elasticDbs.Count}
                $db = New-Object PSObject -Property $dbProperties

                $allDbs += $db       
            }
        
            $poolNumber ++        
        }

        # Get standalone dbs and add to $allDbs

        $StandaloneDbs = (Get-AzureRmSqlDatabase -ResourceGroupName $WtpResourceGroupName -ServerName $serverName |  where {$_.CurrentServiceObjectiveName -ne "ElasticPool"} | where {$_.DatabaseName -ne "master"} ).DatabaseName 
        Foreach ($standaloneDb in $StandaloneDbs)
        {
                $burstLevel = Get-Random -Minimum $burstMinFactor -Maximum $burstMaxFactor # randomizes the intensity of each database
                $burstDtu = [math]::Ceiling($burstLevel * $Intensity)

                #store db with a neutral load factor
                $dbProperties = @{ServerName=($serverName + ".database.windows.net");DatabaseName=$StandaloneDb;BurstDtu=$burstDtu;LoadFactor=1.0;ElasticPoolName="";PoolDbCount=0.0}
                $db = New-Object PSObject -Property $dbProperties

                $allDbs += $db
        } 
    }

    if ($SingleTenant.IsPresent -and $SingleTenantDatabaseName -ne "")
    {
        $SingleTenantDatabaseName = Get-NormalizedTenantname $SingleTenantDatabaseName

        #validate that the name is one of the database names about to be processed
        $allDBNames = $allDBs | select -ExpandProperty DatabaseName

        if (-not ($allDBNames -contains $SingleTenantDatabaseName))
        {
            throw "The Single Tenant Database Name '$SingleTenantDatabaseName' was not found.  Check the spelling and try again."
        }     
    }
    #>

    # spawn jobs to spin up load on each database in $allDbs
    # note there are limits to using PS jobs at scale; this should only be used for small scale demonstrations 

    # Set the end time for all jobs
    $endTime = [DateTime]::Now.AddMinutes($DurationMinutes)

    $scriptPath= $PSScriptRoot

    # Script block for job that executes the load generation stored procedure on each database 
    $scriptBlock = `
        {
            param($tenantKey,$server,$database, $AdminUser,$AdminPassword,$DurationMinutes,$intervalMin,$intervalMax,$burstMinDuration,$burstMaxDuration,$baseDtu,$loadFactor,$densityLoadFactor,$dbCount)

            Import-Module "$using:scriptPath\..\Common\CatalogAndDatabaseManagement" -Force

            Write-Output ("Tenant " + $tenantKey + " " + $database + "/" + $server + " Load factor: " + $loadFactor + " Density weighting: " + ($densityLoadFactor*$dbCount)) 

            $endTime = [DateTime]::Now.AddMinutes($DurationMinutes)

            $firstTime = $true

            While ([DateTime]::Now -lt $endTime)
            {
                # add variable delay before execution, this staggers bursts
                # load factor is applied to reduce interval for high or intense loads, and increase interval for low loads
                # density load factor extends interval for higher density pools to reduce overloading
                if($firstTime)
                {
                    $snooze = [math]::ceiling((Get-Random -Minimum 0 -Maximum ($intervalMax - $intervalMin)) / $loadFactor)
                    $snooze = $snooze + ($snooze * $densityLoadFactor * $dbCount)
                    $firstTime = $false
                }
                else
                {
                    $snooze = [math]::ceiling((Get-Random -Minimum $intervalMin -Maximum $intervalMax) / $loadFactor)
                    $snooze = $snooze + ($snooze * $densityLoadFactor * $dbCount)
                }
                Write-Output ("Snoozing for " + $snooze + " seconds")  
                Start-Sleep $snooze

                # vary each burst to add realism to the workload
            
                # vary burst duration
                $burstDuration = Get-Random -Minimum $burstMinDuration -Maximum $burstMaxDuration

                # Increase burst duration based on load factor.  Has marginal effect on low loadfactor databases.
                $burstDuration += ($loadFactor * 2)           

                # vary DTU 
                $dtuVariance = Get-Random -Minimum 0.9 -Maximum 1.1
                $burstDtu = [Math]::ceiling($baseDtu * $dtuVariance)

                # ensure burst DTU doesn't exceed 100 
                if($burstDtu -gt 100) 
                {
                    $burstDtu = 100
                }

                # configure and submit the SQL script to run the load generator
                $sqlScript = "EXEC sp_CpuLoadGenerator @duration_seconds = " + $burstDuration + ", @dtu_to_simulate = " + $burstDtu               
                try
                {
                    Invoke-SqlAzureWithRetry -ServerInstance $server `
                        -Database $database `
                        -Username $AdminUser `
                        -Password $AdminPassword `
                        -Query $sqlscript `
                        -QueryTimeout 36000         
                }
                catch
                {
                    write-error $_.Exception.Message
                    Write-Output ("Error connecting to tenant database " + $database + "/" + $server)
                }

                [string]$message = $([DateTime]::Now) 
                Write-Output ( $message + " Starting load: " + $burstDtu + " DTUs for " + $burstDuration + " seconds")  

                # exit loop if end time exceeded
                if ([DateTime]::Now -gt $endTime)
                {
                    break;
                }
            }
        }

    # Start a job for each tenant.  Each job runs for the specified session duration and triggers load periodically.
    # The base-line load level for each tenant is set by the entry in $tenants.  Burst duration, interval and DTU are randomized
    # slightly within each job to create a more realistic workload

    $randomTenantIndex = 0

    if ($SingleTenant -and $SingleTenantDatabaseName -eq "")
    {
        $randomTenantIndex = Get-Random -Minimum 1 -Maximum ($tenants.Count + 1)        
    }

    #$i = 1

    foreach ($tenant in $tenants)
    {
        # skip further processing if job is already started for this tenant
        if ($jobs.ContainsKey($tenant.TenantKey.ToString()))
        {
            continue
        } 

        if($sleeping -eq $true)
        {
            $sleeping = $false
            # emit next job output on a new line
            Write-Output "`n"
        }

        <# Customize the load applied for each tenant
        if ($SingleTenant)
        {
            if ($i -eq $randomTenantIndex) 
            {
                # this is the randomly selected database, so use the single-tenant factors
                $burstDtu = $SingleTenantDtu
                $loadFactor = $intenseLoadFactor 
            }        
            elseif ($randomTenantIndex -eq 0 -and $SingleTenantDatabaseName -eq $db.DatabaseName) 
            {
                # this is the named database, so use the single-tenant factors
                $burstDtu = $SingleTenantDtu
                $loadFactor = $intenseLoadFactor 
            }
            else 
            {             
                # use per-db computed factors 
                $burstDtu = $db.BurstDtu
                $loadFactor = $db.LoadFactor
            }
        }
        else 
        {
            # use per-db computed factors
            $burstDtu = $db.BurstDtu
            $loadFactor = $db.LoadFactor
        }
        #>

        # use per-tenant factors
        $burstDtu = $tenant.BurstDtu
        $loadFactor = $tenant.LoadFactor

        $dbCount = $tenants.Count

        #$i ++   

        $outputText = " Starting load with load factor $loadFactor with baseline DTU $burstDtu"
        <#
        if ($db.ElasticPoolName -ne "")
        {
            $outputText += " in pool " + $db.ElasticPoolName
        }
        else
        {
            $outputText += " standalone"
        }
        
        if ($LongerBursts.IsPresent)
        {
            $outputText += " [BOOSTED]"
        }
        #>
    
        # start the load generation job for the current tenant
        
        $job = Start-Job `
            -ScriptBlock $scriptBlock `
            -Name ($tenant.TenantKey).ToString() `
            -ArgumentList $(`
                $tenant.TenantKey, $tenant.ServerName,$tenant.DatabaseName,`
                $TenantAdminUser,$TenantAdminPassword,`
                $DurationMinutes,$intervalMin,$intervalMax,`
                $burstMinDuration,$burstMaxDuration,$burstDtu,`
                $loadFactor,$densityLoadFactor,$dbCount)    

        # add job to dictionary of currently running jobs
        $jobs += @{$job.Name = $job}

        $outputText = ("Job $($job.Id) $($Job.Name) $outputText")
        write-output $outputText
    }

    $now = Get-Date
    $runtime = ($now - $start).TotalMinutes

    if ($runtime -ge $DurationMinutes -or $OneTime)
    {
        Write-Output "`n`nLoad generation session stopping after $runtime minutes"
        exit
    }

    $sleepCount ++

    # displays rows of dots to show it's still working. A dot every 10 seconds, a new row every 10 minutes 
    if ($sleepCount -ge 60)
    {
        write-host "."
        $sleepCount = 0
    }
    else
    {
        write-host -NoNewline "."
    }

    $sleeping = $true
    
    Sleep $sleep
}