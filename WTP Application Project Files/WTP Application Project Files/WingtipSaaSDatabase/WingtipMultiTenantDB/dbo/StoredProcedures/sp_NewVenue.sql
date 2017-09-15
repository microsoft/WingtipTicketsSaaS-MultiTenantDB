-- Creates a new venue with a set of default sections and events
CREATE PROCEDURE [dbo].[sp_NewVenue]
    @VenueId  INT,
    @VenueName NVARCHAR(128),
    @VenueType NVARCHAR(30) = 'multipurpose',
    @PostalCode NVARCHAR(20) = '98052',
    @CountryCode CHAR(3) = 'USA'
AS
    IF @VenueId IS NULL
    BEGIN
        RAISERROR ('Error. @VenueId must be specified', 11, 1)
        RETURN 1
    END

    IF @VenueName IS NULL
    BEGIN
        RAISERROR ('Error. @VenueName must be specified', 11, 1)
        RETURN 1
    END

    DECLARE @StartHour int = 19
    DECLARE @StartMinute int = 00
    DECLARE @BaseDate datetime = DATETIMEFROMPARTS(YEAR(CURRENT_TIMESTAMP),MONTH(CURRENT_TIMESTAMP),DAY(CURRENT_TIMESTAMP),@StartHour,@StartMinute,00,000)

    -- Insert Venue
    INSERT INTO [dbo].Venues
        ([VenueId],[VenueName],[VenueType],[AdminEmail],[CountryCode], [PostalCode])         
    VALUES
        (@VenueId, @VenueName,@VenueType,'admin@email.com',@CountryCode, @PostalCode)

    -- Insert default Sections
    SET IDENTITY_INSERT [dbo].[Sections] ON;

    INSERT INTO [dbo].[Sections]
        ([VenueId],[SectionId],[SectionName])
    VALUES
        (@VenueId,1,'Section 1'),
        (@VenueId,2,'Section 2');
    SET IDENTITY_INSERT [dbo].[Sections] OFF
    
    -- Insert default Events with dates distributed around current date
    SET IDENTITY_INSERT [dbo].[Events] ON;

    INSERT INTO [dbo].[Events]
        ([VenueId],[EventId],[EventName],[Subtitle],[Date])     
    VALUES
        (@VenueId,1,'Event 1','Performer 1',DATEADD(Day,-5,@BaseDate)),
        (@VenueId,2,'Event 2','Performer 2',DATEADD(Day,-2,@BaseDate)),
        (@VenueId,3,'Event 3','Performer 3',DATEADD(Day,1,@BaseDate)),
        (@VenueId,4,'Event 4','Performer 4',DATEADD(Day,4,@BaseDate)),
        (@VenueId,5,'Event 5','Performer 5',DATEADD(Day,7,@BaseDate));

    SET IDENTITY_INSERT [dbo].[Events] OFF

    -- Insert default EventSections

    INSERT INTO [dbo].[EventSections]
        ([VenueId],[EventId],[SectionId],[Price])
    VALUES
        (@VenueId,1,1,40.00),
        (@VenueId,1,2,20.00),
        (@VenueId,2,1,40.00),
        (@VenueId,2,2,20.00),    
        (@VenueId,3,1,40.00),
        (@VenueId,3,2,20.00),
        (@VenueId,4,1,40.00),
        (@VenueId,4,2,20.00),
        (@VenueId,5,1,40.00),
        (@VenueId,5,2,20.00);

RETURN 0