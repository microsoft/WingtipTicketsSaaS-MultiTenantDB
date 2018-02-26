# Find tenants by name, then open a selected tenant's database in the Azure Portal  


# Start a load on the databases first with scenario 1. To make the exploration more interesting,
# let it run for a few minutes.

# Duration of the load generation session. Some activity may continue after this time. 
$DurationMinutes = 60

# This specifies a tenant to be overloaded in scenario 1.
$SingleTenantName = "Fabrikam Jazz Club"

# In scenario 2, try entering 'jazz' when prompted to quickly locate Fabrikam Jazz Club. 

$DemoScenario = 1
<# Select the scenario to run
   Scenario
      1       Generate a high intensity load (approx 95 DTU) on a single tenant plus a normal intensity load (40 DTU) on all other tenants 
      2       Open a specific tenant's database in the portal plus their public events page
#>

## ------------------------------------------------------------------------------------------------

Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force
Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on,  Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

Save-AzureRmContext -Path $env:temp\AzureContext.json -Force

# Get the resource group and user names used when the WTP application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

### Default state - enter a valid demo scenaro 
if ($DemoScenario -eq 0)
{
  Write-Output "Please modify the demo script to select a scenario to run."
  exit
}


### Generate a high intensity load (approx 95 DTU) on a single tenant plas a normal intensity load (30 DTU) on all other tenants
if ($DemoScenario -eq 1)
{       
    # First, stop and remove any prior running jobs
    Write-Output "Stopping any prior jobs. This can take a minute or more... "
    Remove-Job * -Force

    # Intensity of normal load, roughly approximates to average eDTU loading on the pool 
    $Intensity = 30   

    # start a new set of load generation jobs for the current tenants with the load configuration above
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


### Open a specific tenant's database in the portal, plus their public events page
if ($DemoScenario -eq 2)
{       
    $catalog = Get-Catalog `
        -ResourceGroupName $wtpUser.ResourceGroupName `
        -WtpUser $wtpUser.Name

    $tenantNames = @()

    # Get search string from console and find matching tenants
    do 
    {
        [string]$searchString = Read-Host "`nTenant name search string" -ErrorAction Stop       

        Write-Output "`nLooking for tenants..."

        # Check search string is valid and prevent SQL injection
        Test-LegalNameFragment $searchString

        # Find tenants with names that match the search string
        $tenantNames += Find-TenantNames -Catalog $catalog -SearchString $searchString

        if(-not $tenantNames)
        {
            Write-Output "No tenants found matching '$searchString', try again or ctrl-c to exit" 
        }

    } while (-not $tenantNames)

    # Display matching tenants 
    $index = 1
    foreach($tenantName in $TenantNames)
    {
        $tenantName | Add-Member -type NoteProperty -name "Tenant" -value $index
        $index++
    }

    # Prompt for selection 
    Write-Output "`nFound matching tenants: "
    $TenantNames | Format-Table Tenant,TenantName -AutoSize
            

    # Get the tenant selection from console and open database in portal and the corresponding events page  
    do
    {
        try
        {
            [int]$selectedRow = Read-Host "`nEnter the tenant number to open database in portal, 0 to exit" -ErrorAction Stop

            if ($selectedRow -ne 0)
            {
                $selectedTenantName = $TenantNames[$selectedRow - 1].TenantName

                # Open the events page for the new venue to verify it's working correctly
                Start-Process "http://events.wingtip-mt.$($wtpUser.Name).trafficmanager.net/$(Get-NormalizedTenantName $selectedTenantName)"

                # open the database blade in the portal to review performance
                Open-TenantResourcesInPortal `
                    -Catalog $catalog `
                    -TenantName $selectedTenantName `
                    -ResourceTypes ('database')  
            }
            exit       
        }
        catch
        { 
            Write-Output 'Invalid selection.'         
        }

    } while (1 -eq 1)

    exit
}


Write-Output "Invalid scenario selected"