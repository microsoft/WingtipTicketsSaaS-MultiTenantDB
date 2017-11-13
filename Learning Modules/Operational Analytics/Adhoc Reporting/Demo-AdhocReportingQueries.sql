-- *******************************************************
-- SAMPLE QUERIES
-- *******************************************************

-- Which venues are currently registered?
  SELECT * FROM dbo.Venues 

GO

-- And what is their venue type? 
  SELECT VenueName, 
         VenueTypeName,
         EventTypeName 
  FROM   dbo.Venues 
         INNER JOIN dbo.VenueTypes ON Venues.VenueType = VenueTypes.VenueType

GO

-- What are the most popular venue types?
SELECT VenueType, 
	   Count(TicketId) AS PurchasedTicketCount
FROM   dbo.Venues 
	   INNER JOIN dbo.Tickets ON Venues.VenueId = Tickets.VenueId
GROUP  BY VenueType
ORDER  BY PurchasedTicketCount DESC

GO

-- On which day were the most tickets sold?
SELECT	CAST(PurchaseDate AS DATE) AS TicketPurchaseDate,
		Count(TicketId) AS TicketCount
FROM	TicketPurchases
		INNER JOIN Tickets ON (Tickets.TicketPurchaseId = TicketPurchases.TicketPurchaseId AND Tickets.VenueId = TicketPurchases.VenueId)
GROUP	BY (CAST(PurchaseDate AS DATE))
ORDER	BY TicketCount DESC, TicketPurchaseDate ASC

GO

-- Which event had the highest revenue at each venue?
EXEC sp_execute_remote
	N'WtpTenantDBs',
	N'SELECT	TOP (1)
				VenueName,
				EventName,
				Subtitle AS Performers,
				COUNT(TicketId) AS TicketsSold,
				CONVERT(VARCHAR(30), SUM(PurchaseTotal), 1) AS PurchaseTotal
	  FROM		Events
				INNER JOIN Tickets ON Tickets.EventId = Events.EventId
				INNER JOIN TicketPurchases ON TicketPurchases.TicketPurchaseId = Tickets.TicketPurchaseId
				INNER JOIN Venues ON Events.VenueId = Venues.VenueId
	  GROUP		BY VenueName, EventName, Subtitle
	  ORDER		BY PurchaseTotal DESC'

GO

-- What are the top 10 grossing events across all venues on the WTP platform
SELECT	TOP (10)
		VenueName,
		EventName,
		Subtitle AS EventPerformers,
		CAST(Events.Date AS DATE) AS EventDate,
		COUNT(TicketId) AS TicketPurchaseCount,
		CONVERT(VARCHAR(30), SUM(PurchaseTotal), 1) AS EventRevenue
FROM	Events
		INNER JOIN Tickets ON (Tickets.EventId = Events.EventId AND Tickets.VenueId = Events.VenueId)
		INNER JOIN TicketPurchases ON (TicketPurchases.TicketPurchaseId = Tickets.TicketPurchaseId AND TicketPurchases.VenueId = Events.VenueId)
		INNER JOIN Venues ON Events.VenueId = Venues.VenueId
GROUP	BY VenueName, Subtitle, EventName, (CAST(Events.Date AS DATE))
ORDER	BY SUM(PurchaseTotal) DESC

GO