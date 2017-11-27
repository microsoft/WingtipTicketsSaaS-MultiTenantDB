-- Connect to and run against the jobaccount database in catalog-mt-<User> server

-- Create job to run a stored procedure that shreds raw extracted data into star-schema tables
EXEC jobs.sp_add_job
@job_name='ShredRawExtractedData',
@description='Split tickets raw data into ticket fact, venue, event, customer and date dimension tables',
@enabled=1,
@schedule_interval_type='Once'
--To run the job on schedule, use the parameters below to specify schedule.
--@schedule_interval_type='Minutes',
--@schedule_interval_count=15,
--@schedule_start_time='2017-08-21 10:00:00.0000000',
--@schedule_end_time='2017-08-21 11:00:00.0000000'


-- Create job step to execute sp_ShredExtractedData stored procedure to populate the
-- star-schema tables.
EXEC jobs.sp_add_jobstep
@job_name='ShredRawExtractedData',
@command=N'EXEC sp_ShredRawExtractedData',
@credential_name='mydemocred',
@target_group_name='AnalyticsGroup'

--
-- Views
-- Job Execution Information and Status
--

--View parent execution status
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ShredRawExtractedData' and step_id IS NULL

--View all execution status. Wait till the 'lifecycle' column denotes 'Succeeded' for all rows.
SELECT * FROM [jobs].[job_executions] 
WHERE job_name = 'ShredRawExtractedData'

-- Cleanup
--EXEC [jobs].[sp_delete_job] 'ShredRawExtractedData'
--EXEC [jobs].[sp_stop_job] 'ShredRawExtractedData'
--EXEC jobs.sp_start_job 'ShredRawExtractedData'

