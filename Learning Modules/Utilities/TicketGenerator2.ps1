<#
.Synopsis
	Simulates customer ticket purchases for events in WTP tenant databases 
.DESCRIPTION
	Adds customers and creates tickets for events in tenant (venue) databases. Does not 
    create tickets for the last event in each database to allow this to be deleted to 
    demonstrate point-in-time restore.
#>

[CmdletBinding()]
Param
(
	# Resource Group Name entered during deployment 
	[Parameter(Mandatory=$true)]
	[String]$WtpResourceGroupName,

	# The user name used entered during deployment
	[Parameter(Mandatory=$true)]
	[String]$WtpUser
)
Import-Module "$PSScriptRoot\..\Common\SubscriptionManagement"
Import-Module "$PSScriptRoot\..\Common\CatalogAndDatabaseManagement" -Force
Import-Module "$PSScriptRoot\..\wtpConfig" -Force

$ErrorActionPreference = "Stop"

$config = Get-Configuration

$catalog = Get-Catalog -ResourceGroupName $WtpResourceGroupName -WtpUser $WtpUser

## Functions

function Get-PaddedNumber
{
    param ([int] $Number)

    if ($Number -lt 10) {return "000$Number"}
    if ($number -lt 100) {return "00$Number"}
    if ($Number -lt 1000) {return "0$Number"}
    return $Number.ToString()        
}

function Get-CurvedSalesForDay 
{
    param 
    (
        [object] $Curve,

        [ValidateRange(1,60)]
        [int] $Day,

        [int] $Seats

    )
    
    [decimal] $curvePercent = 0   
    
    if ($Day -eq 1) { $curvePercent = $Curve.1 } 
    elseif ($Day -le 5) { $curvePercent = ($Curve.5 / 4) }   
    elseif ($Day -le 10) { $curvePercent = ($Curve.10 / 5) }     
    elseif ($Day -le 15) { $curvePercent = ($Curve.15 / 5) }
    elseif ($Day -le 20) { $curvePercent = ($Curve.20 / 5) }
    elseif ($Day -le 25) { $curvePercent = ($Curve.25 / 5) }
    elseif ($Day -le 30) { $curvePercent = ($Curve.30 / 5) }
    elseif ($Day -le 35) { $curvePercent = ($Curve.35 / 5) }    
    elseif ($Day -le 40) { $curvePercent = ($Curve.40 / 5) }
    elseif ($Day -le 45) { $curvePercent = ($Curve.45 / 5) }
    elseif ($Day -le 50) { $curvePercent = ($Curve.50 / 5) }
    elseif ($Day -le 55) { $curvePercent = ($Curve.55 / 5) }
    else { $curvePercent = ($Curve.60 / 5) }

    # add some random variation
    [decimal] $variance = (-10, -8, -5, -4, 0, 5, 10) | Get-Random 

    # Set variance for Mad Rush to be 0 so the venue sells 100% of the availble tickets.
    if ($Curve.Curve -eq "MadRush"){$variance = 0}

    $curvePercent = $curvePercent + ($curvePercent * $variance/100)

    if ($curvePercent -lt 0) {$curvePercent = 0}
    elseif ($curvePercent -gt 100) {$curvePercent = 100}
    
    [decimal]$sales = ($curvePercent * $Seats / 100)

    [int]$roundedSales = [math]::Ceiling($sales)

    return $roundedSales 
}

## MAIN SCRIPT ## ----------------------------------------------------------------------------

# Ensure logged in to Azure
Initialize-Subscription

$startTime = Get-Date

$AdminUserName = $config.TenantAdminUsername
$AdminPassword = $config.TenantAdminPassword 

# load fictitious customer names, postal codes, 
$fictitiousNames = Import-Csv -Path ("$PSScriptRoot\FictitiousNames.csv") -Header ("Id","FirstName","LastName","Language","Gender")
$fictitiousNames = {$fictitiousNames}.Invoke()

$customerCount = $fictitiousNames.Count

$postalCodes = Import-Csv -Path ("$PSScriptRoot\SeattleZonedPostalCodes.csv") -Header ("Zone","PostalCode")

# add a random postal code to each fictitious name

foreach ($fictitiousName in $fictitiousNames)
{
    Add-Member -InputObject $fictitiousName -MemberType NoteProperty -Name PostalCode -Value ($PostalCodes.PostalCode | Get-Random)
}

# load the full set of event sales curves
$importCurves = Import-Csv -Path ("$PSScriptRoot\WtpSalesCurves1.csv") -Header ("Curve","1", "5","10","15","20","25","30","35","40","45","50","55","60")
$curves = @{}
foreach ($importCurve in $importCurves) 
{
    $curves += @{$importCurve.Curve = $importCurve}
}

# three defined sets of curves that reflect different venue/event popularities (a curve appearing more than once is more likely to be used)
$popularCurves = $curves.MadRush,$curves.Rush,$curves.SShapedHigh,$curves.FastBurn, $curves.StraightLine, $curves.LastMinuteRush,$curves.MediumBurn,$curves.MadRush
$moderateCurves = $Curves.Rush,$Curves.SShapedMedium, $Curves.MediumBurn, $Curves.LastMinute
$unpopularCurves = $curves.SShapedLow, $curves.QuickFizzle, $curves.SlowBurn,$curves.LastGasp, $curves.Disappointing

# Get all the tenant databases in the catalog
$tenantsDatabases = Get-Shards -ShardMap $catalog.ShardMap

foreach ($tenantsDatabase in $tenantsDatabases)
{
    
    $tenantsDatabaseName = $tenantsDatabase.Location.Database
    $tenantsServer = $tenantsDatabase.Location.Server

    # Remove all existing ticket and customer data

    $command = "
        DELETE FROM [dbo].[Tickets]
        DELETE FROM [dbo].[TicketPurchases]
        DELETE FROM [dbo].[Customers]"

    Invoke-SqlAzureWithRetry `
        -Username "$AdminUserName" -Password "$AdminPassword" `
        -ServerInstance $tenantsServer `
        -Database $tenantsDatabaseName `
        -Query $command

    # Get the venues

    $command = "
        SELECT VenueId, VenueName 
        FROM Venues"

    $Venues = Invoke-SqlAzureWithRetry `
        -Username "$AdminUserName" -Password "$AdminPassword" `
        -ServerInstance $tenantsServer `
        -Database $tenantsDatabaseName `
        -Query $command

    if (!$Venues)
    {
        continue
    }

    $totalTicketPurchases = 0
    $totalTickets = 0

    $standardPrice = 10

    foreach ($venue in $venues)
    {

        $venueName = $venue.VenueName
        $venueId = $venue.VenueId

        $venueTickets = 0     
     
        # set the venue popularity, which determines the sales curves used: 1=popular, 2=moderate, 3=unpopular

        # pre-defined venues use same popularity every time 
        if     ($venueName -eq 'Contoso Concert Hall') { $popularity = "popular"}
        elseif ($venueName -eq 'Fabrikam Jazz Club')   { $popularity = "moderate"}
        elseif ($venueName -eq 'Dogwood Dojo')         { $popularity = "unpopular"}
        else
        {
            # set random popularity for all other venues   
            $popularity = ('popular','moderate','unpopular') | Get-Random 
        }

        # assign the venue curves based on popularity 
        switch ($popularity) 
        {
            "popular"   {$venueCurves = $popularCurves}
            "moderate"  {$venueCurves = $moderateCurves}
            "unpopular" {$venueCurves = $unpopularCurves}
        }

        Write-Output "Purchasing tickets for $venueName ($popularity)"

        # add customers to the venue

        # Compose SQL script for inserting customers, same customers are used for all venues, names are picked at random for events

        $customersSql  = "
            SET IDENTITY_INSERT [dbo].[Customers] ON 
            INSERT INTO [dbo].[Customers] 
            ([VenueId],[CustomerId],[FirstName],[LastName],[Email],[PostalCode],[CountryCode]) 
            VALUES `n"

        # all customers are located in the US
        $CountryCode = 'USA'  
        
        $venueCustomers = @{}
        $venueCustomers = {$venueCustomers}.Invoke()  

        $customerId = 0
        $venueCustomerCount = 0
        for( $i=0 ; $i -lt $customerCount ; $i++ ) 
        {
            # randomly skip names so each venue has different subsets drawn from the common set of names
            if ((Get-Random -Minimum 1 -Maximum 10) -le 4)
            {
                continue
            } 

            $name = $fictitiousNames[$i]

            $venueCustomers += $name
            $venueCustomerCount ++

            $firstName = $name.FirstName.Replace("'","").Trim()
            $lastName = $name.LastName.Replace("'","").Trim()

            # form the customers email address
            $alias = ($firstName + "." + $lastName).ToLower()

            # oh look, they all use outlook as their email provider...
            $email = $alias + "@outlook.com"

            $postalCode = $Name.PostalCode

            $customerId ++

            $customersSql += "      ($VenueId,$customerId,'$firstName','$lastName','$email','$postalCode','$CountryCode'),`n"
        }

        $customersSql = $customersSql.TrimEnd(("`n",","," ")) + ";`nSET IDENTITY_INSERT [dbo].[Customers] OFF"

        $results = Invoke-SqlAzureWithRetry `
                    -Username "$AdminUserName" -Password "$AdminPassword" `
                    -ServerInstance $tenantsServer `
                    -Database $tenantsDatabaseName `
                    -Query $customersSql 

        # Initialize script for generating random number of sections for each venues
        $sectionsSql  = "
        DELETE FROM [dbo].[EventSections] where VenueId = $venueId 
        DELETE FROM [dbo].[Sections] where VenueId = $venueId 
        SET IDENTITY_INSERT [dbo].[Sections] ON 
        INSERT INTO [dbo].[Sections] 
        ([VenueId],[SectionId],[SectionName],[SeatRows],[SeatsPerRow],[StandardPrice]) 
        VALUES `n"

        # Add sections to the venue
        if     ($venueName -eq 'contosoconcerthall') { }
        elseif ($venueName -eq 'fabrikamjazzclub')   { }
        elseif ($venueName -eq 'dogwooddojo')        { }
        else
        {
            # set random number of sections for all other venues   
            switch ($popularity) 
                {"popular" {$numSections = Get-Random -Maximum 6 -Minimum 4
                            $SeatRows = Get-Random -Maximum 20 -Minimum 15
                            $SeatsPerRow = Get-Random -Maximum 30 -Minimum 25}
                "moderate" {$numSections = Get-Random -Maximum 4 -Minimum 2
                            $SeatRows = Get-Random -Maximum 18 -Minimum 12
                            $SeatsPerRow = Get-Random -Maximum 30 -Minimum 25}
                "unpopular" {$numSections = Get-Random -Maximum 4 -Minimum 1
                             $SeatRows = Get-Random -Maximum 10 -Minimum 4
                             $SeatsPerRow = Get-Random -Maximum 20 -Minimum 10}
                }

            # Display the sections, seats row and seats per row
            # Write-Output "Venue has $numSections sections,  $SeatRows rows and $SeatsPerRow seats per row"
    
            $Sections = (1..$numSections)
            Foreach ($section in $Sections){
                $sectionId = $section
                $sectionName = "Section " + $section 
                $sectionsSql += "      ($venueId, $sectionId,'$sectionName',$seatRows,$seatsPerRow,$standardPrice),`n"
            }
            $sectionsSql  = $sectionsSql.TrimEnd(("`n",","," ")) + ";`nSET IDENTITY_INSERT [dbo].[Sections] OFF"
            $sectionsSql += "`nINSERT INTO [dbo].[EventSections] (VenueId, EVentId, SectionId, Price)
                               SELECT e.VenueId, e.EventId, s.SectionId, s.StandardPrice
                               FROM [dbo].[Events] e 
                               JOIN [dbo].[Sections] s on 1=1
                               WHERE e.VenueId = $($Venue.VenueId) and s.VenueId = $($Venue.VenueId);"
            $resultsSection = Invoke-SqlAzureWithRetry `
                -Username "$AdminUserName" -Password "$AdminPassword" `
                -ServerInstance $tenantsServer `
                -Database $tenantsDatabaseName `
                -Query $sectionsSql   
        }

        # initialize ticket purchase identity for this venue
        $ticketPurchaseId = 1

        # initialize SQL insert batch counters for tickets and ticket purchases
        $tBatch = 1
        $tpBatch = 1
    
        # initialize SQL batches for tickets and ticket purchases
        $ticketSql = "
            INSERT INTO [dbo].[Tickets] ([VenueId],[RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n"
    
        $ticketPurchaseSql = `
           "SET IDENTITY_INSERT [dbo].[TicketPurchases] ON
            INSERT INTO [dbo].[TicketPurchases] ([VenueId],[TicketPurchaseId],[CustomerId],[PurchaseDate],[PurchaseTotal]) VALUES`n" 

        # get venue capacity - total number of seats in venue
        $command = "
        SELECT SUM(SeatRows * SeatsPerRow) AS Capacity 
        FROM Sections 
        WHERE VenueId = $($Venue.VenueId)"
            
        $capacity = Invoke-SqlAzureWithRetry `
                    -Username "$AdminUserName" -Password "$AdminPassword" `
                    -ServerInstance $tenantsServer `
                    -Database $tenantsDatabaseName `
                    -Query $command

        # get events for this venue
        $command = "
        SELECT EventId, EventName, Date FROM [dbo].[Events] 
        WHERE VenueId = $($Venue.VenueId)
        ORDER BY Date ASC"
       
        $events = Invoke-SqlAzureWithRetry `
                    -Username "$AdminUserName" -Password "$AdminPassword" `
                    -ServerInstance $tenantsServer `
                    -Database $tenantsDatabaseName `
                    -Query $command 

        $eventCount = 1
        foreach ($event in $events) 
        {
            if 
            (
                $eventCount -eq $events.Count -and 
                (
                    $venueName -eq 'Contoso Concert Hall' -or 
                    $venueName -eq 'Fabrikam Jazz Club' -or 
                    $venueName -eq 'Dogwood Dojo'
                )
            )
            {
                # don't generate tickets for the last event for the pre-defined venues so they can be deleted    
                break
            }

            # assign a sales curve for this event from the set assigned to this venue
            $eventCurve = $venueCurves | Get-Random

            Write-Host -NoNewline "  Processing event '$($event.EventName)' ($($eventCurve.Curve))..."

            $eventTickets = 0

            # get seating sections and prices for this event
            $command = "
                SELECT s.SectionId, s.SectionName, SeatRows, SeatsPerRow, es.Price
                FROM [dbo].[EventSections] AS es
                INNER JOIN [dbo].[Sections] AS s ON s.VenueId = es.VenueId AND s.SectionId = es.SectionId
                WHERE s.VenueId = $($Venue.VenueId) AND es.EventId = $($event.EventId)"

            $sections = @()
            $sections += Invoke-SqlAzureWithRetry `
                        -Username "$AdminUserName" -Password "$AdminPassword" `
                        -ServerInstance $tenantsServer `
                        -Database $tenantsDatabaseName `
                        -Query $command

            # process sections to create collections of seats from which purchased tickets will be drawn
            $seating = @{}
            $sectionNumber = 1
            foreach ($section in $sections)
            {
                $sectionSeating = @{}

                for ($row = 1;$row -le $section.SeatRows;$row++)
                {
                    for ($seatNumber = 1;$seatNumber -le $section.SeatsPerRow;$seatNumber++)
                    {
                        # create the seat and assign its price
                        $seat = New-Object psobject -Property @{
                                    SectionId = $section.SectionId
                                    Row = $row
                                    SeatNumber = $seatNumber
                                    Price = $section.Price
                                    }
                    
                        $index = "$(Get-PaddedNumber $row)/$(Get-PaddedNumber $seatNumber)" 
                        $sectionSeating += @{$index = $seat}                    
                    }
                }           

                $seating += @{$sectionNumber = $sectionSeating} 
                $sectionNumber ++
            }            

            # ticket sales start date as (event date - 60)
            $ticketStart = $event.Date.AddDays(-60)

            $today = Get-Date
                    
            # loop over 60 day sales period          
            for($day = 1; $day -le 60 ; $day++)  
            {
                # stop selling tickets when all sold 
                if ($eventTickets -ge $capacity.Capacity) 
                {
                    break
                }
 
                $purchaseDate = $ticketStart.AddDays($day)

                # stop selling tickets after today
                if ($purchaseDate -gt $today)
                {
                    break
                }

                # find the number of tickets to purchase this day based on this event's curve
                [int]$ticketsToPurchase = Get-CurvedSalesForDay -Curve $eventCurve -Day $day -Seats $capacity.Capacity
            
                # if no tickets to sell this day, skip this day
                if ($ticketsToPurchase -eq 0) 
                {
                    continue
                }          

                $ticketsPurchased = 0            
                while ($ticketsPurchased -lt $ticketsToPurchase -and $seating.Count -gt 0 )
                {
                    ## buy tickets on a customer-by-customer basis

                    # pick a random customer Id
                    $customerId = Get-Random -Minimum 1 -Maximum $venueCustomerCount  
                
                    # pick number of tickets for this customer to purchase (2-10 per person)
                    $ticketOrder = Get-Random -Minimum 2 -Maximum 10
                
                    # ensure ticket order does not cause purchases to exceed tickets to buy for this day
                    $remainingTicketsToBuyThisDay = $ticketsToPurchase - $ticketsPurchased
                    if ($ticketorder -gt $remainingTicketsToBuyThisDay)
                    {
                        $ticketOrder = $remainingTicketsToBuyThisDay
                    }

                    # select seating section (could extend here to bias by section popularity)
                    $preferredSectionSeatingKey = $seating.Keys | Get-Random 
                    $preferredSectionSeating = $seating.$preferredSectionSeatingKey
                
                    # modify customer order if insufficient seats available in the chosen section (not so realistic but ensures all seats sell quickly)
                    if ($ticketOrder -gt $preferredSectionSeating.Count)
                    {
                        $ticketOrder = $preferredSectionSeating.Count
                    }

                    $PurchaseTotal = 0                                  

                    # assign seats from the chosen section
                    $seatingAssigned = $false                
                    while ($seatingAssigned -eq $false)
                    {
                        # assign seats to this order
                        for ($s = 1;$s -le $ticketOrder; $s++)
                        {
                            $purchasedSeatKey = $preferredSectionSeating.Keys| Sort | Select-Object -First 1 
                            $purchasedSeat = $preferredSectionSeating.$purchasedSeatKey

                            $PurchaseTotal += $purchasedSeat.Price
                            $ticketsPurchased ++
                        
                            # add ticket to tickets batch

                            # max of 1000 inserts per batch
                            if($tBatch -ge 1000)
                            {
                                # finalize current INSERT and start new INSERT statements and reset batch counter                                                                
                                $ticketSql = $ticketSql.TrimEnd((" ",",","`n")) + ";`n`n"                     
                                $ticketSql += "INSERT INTO [dbo].[Tickets] ([VenueId],[RowNumber],[SeatNumber],[EventId],[SectionId],[TicketPurchaseId]) VALUES `n"                            
                                $tBatch = 0
                            }

                            $ticketSql += "($($Venue.VenueId),$($purchasedSeat.Row),$($purchasedSeat.SeatNumber),$($event.EventId),$($purchasedSeat.SectionId),$ticketPurchaseId),`n"
                            $tBatch ++

                            # remove seat from available seats when sold
                            $preferredSectionSeating.Remove($purchasedSeatKey)
                        
                            # remove section when sold out
                            if ($preferredSectionSeating.Count -eq 0)
                            {
                                $seating.Remove($preferredSectionSeatingKey)
                            }                                                                        
                        }

                        # set time of day of purchase - distributed randomly over prior 24 hours
                        $mins = Get-Random -Maximum 1140 -Minimum 0
                        $purchaseTime = $purchaseDate.AddMinutes(-$mins)

                        # add ticket purchase to batch
                        if($tpBatch -ge 1000)
                        {
                            # finalize current INSERT and start new INSERT statements and reset batch counter                                                                
                            $ticketPurchaseSql = $ticketPurchaseSql.TrimEnd((" ",",","`n")) + ";`n`n"                     
                            $ticketPurchaseSql += "INSERT INTO [dbo].[TicketPurchases] ([VenueId],[TicketPurchaseId],[CustomerId],[PurchaseDate],[PurchaseTotal]) VALUES`n"
                            $tpBatch = 0
                        }
                                     
                        $ticketPurchaseSql += "($($Venue.VenueId),$ticketPurchaseId,$CustomerId,'$purchaseTime',$PurchaseTotal),`n"
                        $tpBatch ++
                    
                        $seatingAssigned = $true
                        $ticketPurchaseId ++
                           
                    }  # tickets one customer

                    $totalTicketPurchases ++
                    $totalTickets += $ticketOrder
                    $eventTickets += $ticketOrder
                    $venueTickets += $ticketOrder
            
                }  # all customer orders (ticket purchases) for one day                                 
        
            } # purchases for all 60 days

            Write-Output " $eventTickets tickets purchased"
        
            $eventCount ++
        
        }  # per event purchases

        Write-Output "  $venueTickets tickets purchased for $venueName"

        # Finalize batched SQL commands for this venue and execute

        Write-Output "    Inserting TicketPurchases" 
        
        $ticketPurchaseSql = $ticketPurchaseSql.TrimEnd((" ",",","`n")) + ";"
        $ticketPurchaseSql += "`nSET IDENTITY_INSERT [dbo].[TicketPurchases] OFF"

        $ticketPurchasesExec = Invoke-SqlAzureWithRetry `
            -Username "$AdminUserName" `
            -Password "$AdminPassword" `
            -ServerInstance $tenantsServer `
            -Database $tenantsDatabaseName `
            -Query $ticketPurchaseSql `
            -QueryTimeout 120 

        Write-Output "    Inserting Tickets " 
               
        $ticketSql = $ticketSql.TrimEnd((" ",",","`n")) + ";"

        $ticketsExec = Invoke-SqlAzureWithRetry `
            -Username "$AdminUserName" `
            -Password "$AdminPassword" `
            -ServerInstance $tenantsServer `
            -Database $tenantsDatabaseName `
            -Query $ticketSql `
            -QueryTimeout 120 
    
        # per venue purchases

    }
}
Write-Output "$totalTicketPurchases TicketPurchases total"
Write-Output "$totalTickets Tickets total"

$duration =  [math]::Round(((Get-Date) - $startTime).Minutes)

Write-Output "Duration $duration minutes"