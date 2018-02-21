# Helper script for setting up the job agent required for the schema management tutorial.  
# Requires no input other than setting UserConfig.psm1.  Also deploys and initializes the adhoc reporting database 
# if not already deployed as the schema changes made in the tutorial also impact a local table in that database.

Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement" -Force
Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force
Import-Module "$PSScriptRoot\..\UserConfig" -Force

# Get Azure credentials if not already logged on. Use -Force to select a different subscription 
Initialize-Subscription -NoEcho

# Get the resource group and user value used when the Wingtip SaaS application was deployed from UserConfig.psm1.  
$wtpUser = Get-UserConfig

# Provisions a job agent database and job agent
& $PSScriptRoot\Deploy-JobAgent.ps1 `
    -WtpResourceGroupname $WtpUser.ResourceGroupName `
    -WtpUser $WtpUser.Name
    
# Provisions the adhoc analytics database if not already deployed and initializes its schema
& "$PSScriptRoot\..\Operational Analytics\Adhoc Reporting\Deploy-AdhocReportingDB.ps1" `
    -WtpResourceGroupname $WtpUser.ResourceGroupName `
    -WtpUser $WtpUser.Name `
    -DeploySchema
