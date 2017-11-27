-- Connect to and run against the jobaccount database in catalog-mt-<User> server
-- Replace <User> below with your user name
DECLARE @User nvarchar(50);
DECLARE @server2 nvarchar(50);
SET @User = '<User>';

-- Create job to retrieve tickets data from the sharded tenants database.
EXEC jobs.sp_add_job
@job_name='ExtractTickets',
@description='Retrieve tickets data from all tenants',
@enabled=1,
@schedule_interval_type='Once'
--@schedule_interval_type='Minutes',
--@schedule_interval_count=15,
--@schedule_start_time='2017-08-21 10:00:00.0000000',
--@schedule_end_time='2017-08-21 11:00:00.0000000'

SET @server2 = 'catalog-mt-' + @User + '.database.windows.net'

-- Create job step to retrieve ticket and customer data from the sharded database.
-- The T-SQL script in the job specifies to select new data from the TicketFacts view.
-- After the data is extracted, the LastExtracted table in the tenants database is updated to 
-- save the new RowVersion
EXEC jobs.sp_add_jobstep
@job_name='ExtractTickets',
@command=N'
DECLARE @TicketRowVersion binary(8)
SET @TicketRowVersion = (SELECT LastExtractedTicketRowVersion FROM [dbo].[LastExtracted] )

SELECT TicketPurchaseId, CustomerEmailId, VenueId, CustomerPostalCode, 
		CustomerCountryCode, EventId, RowNumber, SeatNumber, PurchaseTotal, PurchaseDate
FROM TicketFacts tf
WHERE [TicketPurchaseRowVersion] > @TicketRowVersion
GO

Update [dbo].[LastExtracted] 
SET LastExtractedTicketRowVersion = (SELECT MAX(TicketPurchaseRowVersion) FROM [dbo].[TicketFacts])
',
@credential_name='mydemocred',
@target_group_name='TenantGroup',
@output_type='SqlDatabase',
@output_credential_name='mydemocred',
@output_server_name=@server2,
@output_database_name='tenantanalytics',
@output_table_name='TicketsRawData'

--
-- Views
-- Job and Job Execution Information and Status
--
--SELECT * FROM [jobs].[jobs] 
--WHERE job_name = 'ExtractTickets'

--SELECT * FROM [jobs].[jobsteps] 
--WHERE job_name = 'ExtractTickets'

WAITFOR DELAY '00:00:10'
--View parent execution status
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ExtractTickets' and step_id IS NULL

--View all execution status. Wait till the 'lifecycle' column denotes 'Succeeded' for all rows.
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ExtractTickets'

-- Cleanup
--EXEC [jobs].[sp_delete_job] 'ExtractTickets'
--EXEC [jobs].[sp_delete_target_group] 'TenantGroup'
--EXEC [jobs].[sp_start_job] 'ExtractTickets'
