-- Connect to and run against the jobaccount database in catalog-mt-<User> server
-- Replace <User> below with your user name
DECLARE @User nvarchar(50);
DECLARE @server2 nvarchar(50);
SET @User = 'aj3';

-- Create job to retrieve venue and event data from the sharded tenants database.
EXEC jobs.sp_add_job
@job_name='ExtractVenuesEvents',
@description='Retrieve venues and events data from all tenants',
@enabled=1,
@schedule_interval_type='Once'
--Specify time for periodic job
--@schedule_interval_type='Minutes',
--@schedule_interval_count=15,
--@schedule_start_time='2017-08-21 10:00:00.0000000',
--@schedule_end_time='2017-08-21 11:00:00.0000000'

-- Create job step to retrieve venues and events all the tenants
SET @server2 = 'catalog-mt-' + @User + '.database.windows.net'

-- Create job step to retrieve event and venue data from the sharded database.
-- The T-SQL script in the job specifies to select new data from the EventFacts view.
-- After the data is extracted, the LastExtracted table in the tenants database is updated to 
-- save the new RowVersion
EXEC jobs.sp_add_jobstep
@job_name='ExtractVenuesEvents',
@command=N'
DECLARE @EventRowVersion binary(8)
SET @EventRowVersion = (SELECT LastExtractedEventRowVersion FROM [dbo].[LastExtracted] )

DECLARE @VenueRowVersion binary(8)
SET @VenueRowVersion = (SELECT LastExtractedVenueRowVersion FROM [dbo].[LastExtracted] )


SELECT e.VenueId, e.VenueName, e.VenueType, e.VenuePostalCode,  e.VenueCountryCode,
       e.VenueCapacity, e.EventId, e.EventName, e.EventSubtitle, e.EventDate
FROM   [dbo].[EventFacts] e
WHERE e.EventRowVersion > @EventRowVersion AND e.VenueRowVersion > @VenueRowVersion

Update [dbo].[LastExtracted]
SET LastExtractedEventRowVersion = (SELECT MAX(EventRowVersion) FROM [dbo].[EventFacts]),
    LastExtractedVenueRowVersion = (SELECT MAX(VenueRowVersion) FROM [dbo].[EventFacts]) 
',
@credential_name='mydemocred',
@target_group_name='TenantGroup',
@output_type='SqlDatabase',
@output_credential_name='mydemocred',
@output_server_name=@server2,
@output_database_name='tenantanalytics',
@output_table_name='EventsRawData'

-- Check parent job status. Wait till the 'lifecycle' column denotes 'Succeeded'.
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ExtractVenuesEvents' and step_id IS NULL

-- Check job status. Wait till the 'lifecycle' column denotes 'Succeeded' for all rows.
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ExtractVenuesEvents'

-- Cleanup
--EXEC [jobs].[sp_delete_job] 'ExtractVenuesEvents'
--EXEC [jobs].[sp_start_job] 'ExtractVenuesEvents'
