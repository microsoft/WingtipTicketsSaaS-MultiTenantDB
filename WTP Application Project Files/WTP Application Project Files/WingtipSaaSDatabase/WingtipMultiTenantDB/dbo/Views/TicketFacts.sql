CREATE VIEW [dbo].[TicketFacts] AS
SELECT      c.VenueId, Convert(int, HASHBYTES('md5',c.Email)) AS CustomerEmailId, c.PostalCode AS CustomerPostalCode, c.CountryCode AS CustomerCountryCode,
            tp.TicketPurchaseId, tp.PurchaseDate, tp.PurchaseTotal, tp.RowVersion AS TicketPurchaseRowVersion,
            e.EventId,
            t.RowNumber, t.SeatNumber 
FROM        [dbo].[TicketPurchases] AS tp 
 INNER JOIN [dbo].[Tickets] AS t ON t.TicketPurchaseId = tp.TicketPurchaseId AND t.VenueId = tp.VenueId
 INNER JOIN [dbo].[Events] AS e ON t.EventId = e.EventId AND e.VenueId = tp.VenueId
 INNER JOIN [dbo].[Customers] AS c ON tp.CustomerId = c.CustomerId AND c.VenueId = tp.VenueId