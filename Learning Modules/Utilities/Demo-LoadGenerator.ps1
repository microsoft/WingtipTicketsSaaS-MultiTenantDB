# Invokes load generation on the tenant databases currently defined in the catalog.  
 
# Duration of the load generation session. Some activity may continue after this time. 
$DurationMinutes = 120

# If SingleTenant is enabled (scenario 4), this specifies the tenant database to be overloaded. 
# If set to "" a random tenant database is chosen.
$SingleTenantDatabaseName = "contosoconcerthall"

# If true, generator will run once. If false will keep looking for additional tenants and apply load to them 
$OneTime = $true

$Scenario = 2
<# Select the scenario to run 
    Scenario
      0   None
      1   Start a normal intensity load (approx 30 DTU) 
      2   Start a load with longer bursts per database
      3   Start a load with higher DTU bursts per database (approx 70 DTU)  
      4   Start a high intensity load (approx 95 DTU) on a single tenant plus a normal intensity load on all other tenants 
#>

## ------------------------------------------------------------------------------------------------

Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

Save-AzureRmContext -Path $env:temp\AzureContext.json -Force

# Get the resource group and user names used when the WTP application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

### Default state - enter a valid demo scenaro 
if ($Scenario -eq 0)
{
  Write-Output "Please modify this script to select a scenario to run."
  exit
}

### Generate normal intensity load
if ($Scenario -eq 1)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"
    
    # Intensity of load, roughly approximates to average DTU loading on the tenants 
    $Intensity = 30   

    # start a new set of load generation jobs for the current databases with the load configuration above
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs
      
    exit
}

### Generate load with longer bursts per database
if ($Scenario -eq 2)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"

    # Intensity of workload, roughly approximates to DTU 
    $Intensity = 30

    # start a new set of load generation jobs for the current databases
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes",
        "-LongerBursts"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs
   
    Write-Output "`nOpening new PowerShell session to generate load."
    Write-Output "Close load generation session before starting another one on the same tenants`n" 

    exit 
}      

### Generate load with higher DTU bursts per database
if ($DemoScenario -eq 3)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nClose any previously opened PowerShell load generation sessions before launching another on the same tenants."
    Write-Output "Closing a session can take a minute or more... "
    Read-Host "`nPress ENTER to continue"

    # Intensity of workload, roughly approximates to DTU 
    $Intensity = 70

    # start a new set of load generation jobs for the current databases
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes",
        "-LongerBursts"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`nOpening new PowerShell session to generate load."
    Write-Output "Close load generation session before starting another one on the same tenants`n" 
        
    exit        
} 

<### Generate a high intensity load (approx 95 DTU) on a single tenant plas a normal intensity load (40 DTU) on all other tenants
if ($DemoScenario -eq 4)
{       
    # First, stop and remove any prior running jobs
    Write-Output "`nStopping any prior jobs. This can take a minute or more... "
    Remove-Job * -Force

    # Intensity of load, roughly approximates to average eDTU loading on the pool 
    $Intensity = 30   

    # start a new set of load generation jobs for the current databases with the load configuration above
    & $PSScriptRoot\..\Utilities\LoadGenerator.ps1 `
        -WtpResourceGroupName $wtpUser.ResourceGroupName `
        -Wtpuser $wtpUser.Name `
        -Intensity $Intensity `
        -DurationMinutes $DurationMinutes `
        -SingleTenant `
        -SingleTenantDatabaseName $SingleTenantDatabaseName
    
    exit         
}
#>

Write-Output "Invalid scenario selected"