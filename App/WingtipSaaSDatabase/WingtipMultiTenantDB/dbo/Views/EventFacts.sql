CREATE VIEW [dbo].[EventFacts] AS
SELECT      v.VenueId, v.VenueName, v.VenueType,v.PostalCode as VenuePostalCode, CountryCode AS VenueCountryCode,
            (SELECT SUM (SeatRows * SeatsPerRow) FROM [dbo].[Sections] WHERE VenueId = v.VenueId) AS VenueCapacity,
            v.RowVersion AS VenueRowVersion,
            e.EventId, e.EventName, e.Subtitle AS EventSubtitle, e.Date AS EventDate,
            e.RowVersion AS EventRowVersion
FROM        [dbo].[Venues] as v
 INNER JOIN [dbo].[Events] AS e ON e.VenueId = v.VenueId
