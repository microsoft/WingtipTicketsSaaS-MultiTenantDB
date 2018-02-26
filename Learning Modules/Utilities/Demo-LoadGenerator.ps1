# Invokes load generation on the tenants currently defined in the catalog.  
 
# Duration of the load generation session. Some activity may continue after this time. 
$DurationMinutes = 120

# For the Single Tenant burst scenario (scenario 4), this specifies the tenant to be overloaded. 
$SingleTenantName = "Contoso Concert Hall"

# If true, generator will run once. If false will keep looking for additional tenants and apply load to them 
$OneTime = $true

$Scenario = 1
<# Select the scenario to run 
    Scenario
      1   Start a normal intensity load (approx 30 DTU) 
      2   Start a load with longer bursts per tenant
      3   Start a load with higher DTU bursts per tenant (approx 70 DTU)  
      4   Start a high intensity load (approx 90 DTU) on a single tenant plus a normal intensity load on all other tenants 
#>

## ------------------------------------------------------------------------------------------------

Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

Save-AzureRmContext -Path $env:temp\AzureContext.json -Force

# Get the resource group and user names used when the Wingtip Tickets application was deployed from UserConfig.psm1.  
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

    # start a new set of load generation jobs for the current tenants with the load configuration above
    $powershellArgs = `
        "-NoExit", `
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
        "$($wtpUser.ResourceGroupName)",`
        "$($wtpUser.Name)",`
        "$Intensity",`
        "$DurationMinutes"

    Start-Process PowerShell.exe -ArgumentList $powershellArgs

    Write-Output "`Load generation session launched."
    Write-Output "Close the session before starting another one on the same tenants`n" 
      
    exit
}

### Generate load with longer bursts per tenant
if ($Scenario -eq 2)
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
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
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

### Generate load with higher DTU bursts per tenant
if ($Scenario -eq 3)
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
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
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

### Generate a high intensity load (approx 95 DTU) on a single tenant plas a normal intensity load (40 DTU) on all other tenants
if ($Scenario -eq 4) 
<#{
    Write-Output "Not implemented yet" 
    exit
}
#>
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
        "-File ""$($PSScriptRoot)\LoadGenerator2.ps1""",`
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