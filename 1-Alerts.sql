-------------------------------------
--  Set Alerts
--------------------------------------

PRINT 'Set Alerts';
USE [msdb];
GO

SET NOCOUNT ON;


-- Change @OperatorName as needed
DECLARE @OperatorName sysname = N'Alerts';

-- Change @CategoryName as needed
DECLARE @CategoryName sysname = N'SQL Server Agent Alerts';

-- Make sure you have an Agent Operator defined that matches the name you supplied
IF NOT EXISTS ( SELECT  *
                FROM    msdb.dbo.sysoperators
                WHERE   name = @OperatorName )
    BEGIN
        RAISERROR ('There is no SQL Operator with a name of %s' , 18 , 16 , @OperatorName);
        RETURN;
    END;

-- Add Alert Category if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    msdb.dbo.syscategories
                WHERE   category_class = 2  -- ALERT
                        AND category_type = 3
                        AND name = @CategoryName )
    BEGIN
        EXEC dbo.sp_add_category @class = N'ALERT', @type = N'NONE',
            @name = @CategoryName;
    END;

-- Get the server name
DECLARE @ServerName sysname = ( SELECT  @@SERVERNAME
                              );


-- Alert Names start with the name of the server 
-- added by Anthony E. Nocentino
DECLARE @Sev16AlertName sysname = @ServerName
    + N' Alert - Sev 16 Error: Error in Resource - User correctable';
DECLARE @Sev17AlertName sysname = @ServerName
    + N' Alert - Sev 17 Error: Insufficient Resources';
DECLARE @Sev18AlertName sysname = @ServerName
    + N' Alert - Sev 18 Error: Nonfatal Internal Error Detected';
DECLARE @Error5144AlertName sysname = @ServerName
    + N' Alert - Error 5144: Database Auto-grow cancelled or failed';
DECLARE @Error5145AlertName sysname = @ServerName
    + N' Alert - Error 5145: Database Auto-grow successful';
DECLARE @Error18456AlertName sysname = @ServerName
    + N' Alert - Error 18456: Failed Login';

-- end 
DECLARE @Sev19AlertName sysname = @ServerName
    + N' Alert - Sev 19 Error: Fatal Error in Resource';
DECLARE @Sev20AlertName sysname = @ServerName
    + N' Alert - Sev 20 Error: Fatal Error in Current Process';
DECLARE @Sev21AlertName sysname = @ServerName
    + N' Alert - Sev 21 Error: Fatal Error in Database Process';
DECLARE @Sev22AlertName sysname = @ServerName
    + N' Alert - Sev 22 Error: Fatal Error: Table Integrity Suspect';
DECLARE @Sev23AlertName sysname = @ServerName
    + N' Alert - Sev 23 Error: Fatal Error Database Integrity Suspect';
DECLARE @Sev24AlertName sysname = @ServerName
    + N' Alert - Sev 24 Error: Fatal Hardware Error';
DECLARE @Sev25AlertName sysname = @ServerName
    + N' Alert - Sev 25 Error: Fatal Error';
DECLARE @Error823AlertName sysname = @ServerName
    + N' Alert - Error 823: Operating System Read Error Occured';
DECLARE @Error824AlertName sysname = @ServerName
    + N' Alert - Error 824: SQL Server Read Error Occured';
DECLARE @Error825AlertName sysname = @ServerName
    + N' Alert - Error 825: Read-Retry Required';
DECLARE @Error832AlertName sysname = @ServerName
    + N' Alert - Error 832: Constant page has changed';
DECLARE @Error855AlertName sysname = @ServerName
    + N' Alert - Error 855: Uncorrectable hardware memory corruption detected';
DECLARE @Error856AlertName sysname = @ServerName
    + N' Alert - Error 856: SQL Server has detected hardware memory corruption, but has recovered the page';

	
-- added by Anthony E. Nocentino
-- Sev 16 Error: Fatal Error in Resource
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev16AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev16AlertName, @message_id = 0,
        @severity = 16, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev16AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev16AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

-- Sev 17 Error: Fatal Error in Resource
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev17AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev17AlertName, @message_id = 0,
        @severity = 17, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev17AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev17AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

-- Sev 18 Error: Fatal Error in Resource
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev18AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev18AlertName, @message_id = 0,
        @severity = 18, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev18AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev18AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

--  Error 5144: Database Auto-grow successful
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error5144AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error5144AlertName, @message_id = 5144,
        @severity = 0, @enabled = 1, @delay_between_responses = 0,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error5144AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error5144AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;
	
--  Error 5145: Database Auto-grow cancelled or failed
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error5145AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error5145AlertName, @message_id = 5145,
        @severity = 0, @enabled = 1, @delay_between_responses = 0,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error5145AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error5145AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

-- Alert - Error 18456: Failed Login
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error18456AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error18456AlertName,
        @message_id = 18456, @severity = 0, @enabled = 1,
        @delay_between_responses = 0, @include_event_description_in = 1,
        @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error18456AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error18456AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;	

	
	
-- end edit by aen

-- Sev 19 Error: Fatal Error in Resource
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev19AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev19AlertName, @message_id = 0,
        @severity = 19, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev19AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev19AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 20 Error: Fatal Error in Current Process
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev20AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev20AlertName, @message_id = 0,
        @severity = 20, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev20AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev20AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 21 Error: Fatal Error in Database Process
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev21AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev21AlertName, @message_id = 0,
        @severity = 21, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev21AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev21AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 22 Error: Fatal Error Table Integrity Suspect
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev22AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev22AlertName, @message_id = 0,
        @severity = 22, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev22AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev22AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 23 Error: Fatal Error Database Integrity Suspect
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev23AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev23AlertName, @message_id = 0,
        @severity = 23, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev23AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev23AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 24 Error: Fatal Hardware Error
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev24AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev24AlertName, @message_id = 0,
        @severity = 24, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev24AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev24AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Sev 25 Error: Fatal Error
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Sev25AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Sev25AlertName, @message_id = 0,
        @severity = 25, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';

-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Sev25AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Sev25AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

	

	-- Error 823: Operating System Read Error Occured
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error823AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error823AlertName, @message_id = 823,
        @severity = 0, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error823AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error823AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Error 824: SQL Server Read Error Occured
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error824AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error824AlertName, @message_id = 824,
        @severity = 0, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error824AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error824AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;




-- Error 825: Read-Retry Required
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error825AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error825AlertName, @message_id = 825,
        @severity = 0, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error825AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error825AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;

-- Error 832 Alert added on 10/30/2013

-- Error 832: Constant page has changed
-- http://www.sqlskills.com/blogs/paul/dont-confuse-error-823-and-error-832/
-- http://support.microsoft.com/kb/2015759
IF NOT EXISTS ( SELECT  name
                FROM    msdb.dbo.sysalerts
                WHERE   name = @Error832AlertName )
    EXEC msdb.dbo.sp_add_alert @name = @Error832AlertName, @message_id = 832,
        @severity = 0, @enabled = 1, @delay_between_responses = 900,
        @include_event_description_in = 1, @category_name = @CategoryName,
        @job_id = N'00000000-0000-0000-0000-000000000000';


-- Add a notification if it does not exist
IF NOT EXISTS ( SELECT  *
                FROM    dbo.sysalerts AS sa
                        INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                WHERE   sa.name = @Error832AlertName )
    BEGIN
        EXEC msdb.dbo.sp_add_notification @alert_name = @Error832AlertName,
            @operator_name = @OperatorName, @notification_method = 1;
    END;


-- Memory Error Correction alerts added on 10/30/2013

-- Mitigation of RAM Hardware Errors	 		
-- When SQL Server 2012 Enterprise Edition is installed on a Windows 2012 operating system with hardware that supports bad memory diagnostics, 
-- you will notice new error messages like 854, 855, and 856 instead of the 832 errors that LazyWriter usually generates.
-- Error 854 is just informing you that your instance supports memory error correction

-- Using SQL Server in Windows 8 and Windows Server 2012 environments
-- http://support.microsoft.com/kb/2681562


-- Check for SQL Server 2012 or greater and Enterprise Edition
-- You also need Windows Server 2012 or greater, plus hardware that supports memory error correction
IF LEFT(CONVERT(CHAR(2), SERVERPROPERTY('ProductVersion')), 2) >= '11'
    AND SERVERPROPERTY('EngineEdition') = 3
    BEGIN
        -- Error 855: Uncorrectable hardware memory corruption detected
        IF NOT EXISTS ( SELECT  name
                        FROM    msdb.dbo.sysalerts
                        WHERE   name = @Error855AlertName )
            EXEC msdb.dbo.sp_add_alert @name = @Error855AlertName,
                @message_id = 855, @severity = 0, @enabled = 1,
                @delay_between_responses = 900,
                @include_event_description_in = 1,
                @category_name = @CategoryName,
                @job_id = N'00000000-0000-0000-0000-000000000000';


		-- Add a notification if it does not exist
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.sysalerts AS sa
                                INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                        WHERE   sa.name = @Error855AlertName )
            BEGIN
                EXEC msdb.dbo.sp_add_notification @alert_name = @Error855AlertName,
                    @operator_name = @OperatorName, @notification_method = 1;
            END;

		-- Error 856: SQL Server has detected hardware memory corruption, but has recovered the page
        IF NOT EXISTS ( SELECT  name
                        FROM    msdb.dbo.sysalerts
                        WHERE   name = @Error856AlertName )
            EXEC msdb.dbo.sp_add_alert @name = @Error856AlertName,
                @message_id = 856, @severity = 0, @enabled = 1,
                @delay_between_responses = 900,
                @include_event_description_in = 1,
                @category_name = @CategoryName,
                @job_id = N'00000000-0000-0000-0000-000000000000';


		-- Add a notification if it does not exist
        IF NOT EXISTS ( SELECT  *
                        FROM    dbo.sysalerts AS sa
                                INNER JOIN dbo.sysnotifications AS sn ON sa.id = sn.alert_id
                        WHERE   sa.name = @Error856AlertName )
            BEGIN
                EXEC msdb.dbo.sp_add_notification @alert_name = @Error856AlertName,
                    @operator_name = @OperatorName, @notification_method = 1;
            END;
    END;
GO

