# Helper script for demonstrating performance monitoring and management tasks.

# Duration of the load generation session. Some activity may continue after this time. 
$DurationMinutes = 120

# If SingleTenant is enabled (scenario 5), this specifies the tenant to be overloaded. 
# If set to "" a random tenant is chosen.
$SingleTenantName = "Salix Salsa"

$DemoScenario = 1
<# Select the demo scenario to run 
    Demo    Scenario
      1       Provision a batch of tenants (do this before any of the load generation scenarios)
      2       Generate normal intensity load (approx 30 DTU) 
      3       Generate load with longer burts per tenant
      4       Generate load with higher DTU bursts per tenant (approx 70 DTU)  
      5       Generate a high intensity (approx 90 DTU) on a single tenant plus a normal intensity load on all other tenants 
#>

## --------------------------------------------------------------------------------------

Import-Module $PSScriptRoot\..\Common\CatalogAndDatabaseManagement -Force
Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

# Saving context to temp directory that will be retrieved and used to initialize the context in the load generation session
Save-AzureRmContext -Path $env:temp\AzureContext.json -Force

# Get the resource group and user names used when the Wingtip Tickets application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

### Provision a batch of tenants
if ($DemoScenario -eq 1)
{
    $config = Get-Configuration

    $tenantNames = $config.TenantNameBatch

    & "$PSScriptRoot\..\ProvisionTenants\New-TenantBatch.ps1" -NewTenants $tenantNames
          
    exit          
}

### Generate normal intensity load
if ($DemoScenario -eq 2)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"
    
    # Intensity of load, roughly approximates to average DTU loading on the tenants 
    $Intensity = 30   

    # start a new set of load generation jobs for the current tenants with the load configuration above
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\..\Utilities\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`Load generation session launched."
    Write-Output "Close the session before starting another one on the same tenants`n" 
      
    exit
}

### Generate load with longer bursts per database
if ($DemoScenario -eq 3)
{       
     # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"

    # Intensity of workload, roughly approximates to DTU 
    $Intensity = 30

    # start a new set of load generation jobs for the current tenants
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\..\Utilities\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes",
        "-LongerBursts"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`Load generation session launched."
    Write-Output "Close the session before starting another one on the same tenants`n" 

    exit    
}      

### Generate load with higher DTU bursts per database
if ($DemoScenario -eq 4)
{       
       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"

    # Intensity of workload, roughly approximates to DTU 
    $Intensity = 70

    # start a new set of load generation jobs for the current tenants
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\..\Utilities\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes",
        "-LongerBursts"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`Load generation session launched."
    Write-Output "Close the session before starting another one on the same tenants`n"  
        
    exit   
} 

### Generate high intensity (approx 90 DTU) on a single tenant plus a normal intensity load on all other tenants
if ($DemoScenario -eq 5)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"

    # Intensity of workload, roughly approximates to DTU 
    $Intensity = 30

    # start a new set of load generation jobs for the current tenants
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\..\Utilities\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes", `
        "-SingleTenant", `
        "-SingleTenantName ""$SingleTenantName"""

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`Load generation session launched."
    Write-Output "Close the session before starting another one on the same tenants`n" 
    
    exit        
}  

Write-Output "Invalid scenario selected"
