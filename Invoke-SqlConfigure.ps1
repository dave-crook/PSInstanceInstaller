
function ConfigurePageFile {
    Param(
        [Parameter(Mandatory = $True)] [String]   $SqlInstance
    )

    Write-Output "Configuring page file"

    $PageFileLocation = 'F:\'
    $PageFileSize = 8192

    if ($PageFileSettings -eq $null) {
        Write-Warning "WARNING - Couldn't get page file settings!"
        return
    }

    $PageFileSettings = Get-DbaPageFileSetting -ComputerName $SqlInstance
    if ( $PageFileSettings.FileName -notlike "$PageFileLocation*" -or $PageFileSettings.InitialSize -ne $PageFileSize  -or $PageFileSettings.MaximumSize -ne $PageFileSize  ){
        Write-Verbose "Setting page file size"
        Set-PageFile -ComputerName $SqlInstance -Location $PageFileLocation -InitialSize $PageFileSize -MaximumSize $PageFileSize        
    }
    else{
        Write-Output "Page file in desired state"
        $PageFileSettings
    }
}

function AddSqlManagementToLocalAdmin {
    Param(
        [Parameter(Mandatory = $True)] [String]   $SqlInstance
    )

    Write-Output "Adding SQLManagement to local admin"

    #Add "SQL Management Group to local administrators, this is for CommVault access to the server"
    $group = $null
    try {
        $group = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }  -ErrorAction Ignore
    }
    catch {
    }

    try {
        if ($null -eq $group -or ($group.Name -notcontains $SQLManagement)) {
            Write-Verbose "Adding $($group.Name) to Local Adminstrators group on $servername"
            Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Add-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }
        }
        else {
            Write-Verbose "$($group.Name) found on $SqlInstance in Local Adminstrators group"
        }
    }
    catch {
        Write-Error "Error adding SQL Management to local administrators: $_" 
    }

    try{
        New-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement -WarningAction SilentlyContinue
        Set-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement -AddRole sysadmin
    }
    catch{
        Write-Error "Error creating the login for $SQLManagement and adding it to the sysadmin server role: $_"
    }
}


# chatgpt rewrite of Add-SqlManagementToLocalAdmin.  Test this next time.
function Add-SqlManagementToLocalAdmin2 {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)] [string] $SqlInstance,      # target Windows host name
        [Parameter(Mandatory)] [string] $SQLManagement,    # e.g. 'DOMAIN\SQLManagement'
        [string] $InstanceName                             # optional named SQL instance
    )

    Write-Verbose "Target host: $SqlInstance; SQL group: $SQLManagement; Instance: $InstanceName"

    # Quick connectivity sanity check (helps distinguish WinRM/name issues)
    try {
        Test-WSMan -ComputerName $SqlInstance -ErrorAction Stop | Out-Null
    } catch {
        throw "Cannot reach WinRM on '$SqlInstance'. Check name resolution, firewall, or WinRM configuration. Details: $($_.Exception.Message)"
    }

    Write-Output "Adding $SQLManagement to local Administrators on $SqlInstance"

    # Do everything related to local group membership inside one remote hop
    $script = {
        param($SqlMgmt)
        $group = 'Administrators'

        # Function to attempt the add once
        $attempt = {
            $existing = Get-LocalGroupMember -Group $group -Member $SqlMgmt -ErrorAction SilentlyContinue
            if (-not $existing) {
                Add-LocalGroupMember -Group $group -Member $SqlMgmt -ErrorAction Stop
                "Added '$SqlMgmt' to '$group'."
            } else {
                "'$SqlMgmt' already in '$group'."
            }
        }

        try {
            & $attempt
        } catch {
            # Some environments briefly fail to resolve the domain principal; retry once after a short wait
            Start-Sleep -Seconds 2
            try {
                & $attempt
            } catch {
                throw "Failed to add '$SqlMgmt' to '$group' on $env:COMPUTERNAME. $_"
            }
        }
    }

    try {
        Invoke-Command -ComputerName $SqlInstance -ScriptBlock $script -ArgumentList $SQLManagement -ErrorAction Stop | Write-Verbose
    } catch {
        throw "Error adding '$SQLManagement' to local Administrators on '$SqlInstance': $($_.Exception.Message)"
    }

    # Build the SQL connection target safely
    $targetInstance = if ($InstanceName) { "$SqlInstance\$InstanceName" } else { $SqlInstance }

    # Create the SQL login and grant sysadmin using dbatools (assumes module is present on the caller)
    try {
        Write-Output "Ensuring SQL login exists and is sysadmin on $targetInstance"
        # New-DbaLogin will no-op if the login already exists (unless -Force), but we�ll swallow benign warnings
        New-DbaLogin -SqlInstance $targetInstance -Login $SQLManagement -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        Set-DbaLogin -SqlInstance $targetInstance -Login $SQLManagement -AddRole sysadmin -ErrorAction Stop | Out-Null
    } catch {
        throw "Error creating/granting SQL login for '$SQLManagement' on '$targetInstance': $($_.Exception.Message)"
    }
}

function DisableSaLogin {
    Param(
        [Parameter(Mandatory = $True)]  [String] $SqlInstance,
        [String] $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Disabling SA login"

    #Disable the sa login.
    Get-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.Name -eq 'sa' } | Set-DbaLogin -Disable
}

function InsertIntoCmdb {
    Param(
        [Parameter(Mandatory = $True)]  [String] $SqlInstance,
        [String] $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Inserting into CMDB"

    #Insert this instance into the CMDB
    try {
        if ($InstanceName -ne 'MSSQLSERVER') {
            $Query = "exec dbo.InsertSqlServer `'$($SqlInstance)\$($InstanceName)`'"
        }
        else {
            $Query = "exec dbo.InsertSqlServer `'$($SqlInstance)'"
        }
        Invoke-DbaQuery -SqlInstance $SQLManagementServer -Database 'DBA' -Query $Query
    }
    catch {
        Write-Error "Error adding instance to CMDB: $_" 
    }
}

function ConfigureSpn {
    Param(
        [Parameter(Mandatory = $True)] [String]   $SqlInstance
    )

    Write-Output "Configuring SPN"

    #Configure SPNs for use with a named SQL Server service account
    try {
        Test-DbaSpn -ComputerName $SqlInstance | Where-Object { $_.IsSet -eq $false } | Set-DbaSpn
    }
    catch {
        Write-Error "Error setting the SPN: $_"
    }

    #if this is the primary configure the SPN for the AG listener
    if ( $SqlInstance -eq $AGPrimary ) {  # $AGPrimary is not set in Install-SqlServer.ps1.  This will never be executed.
        try {
            $ListenerFQDN = ([System.Net.Dns]::GetHostByName($AGListener)).HostName
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN" -ServiceAccount $ServiceAccount
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN`:1433" -ServiceAccount $ServiceAccount
        }
        catch {
            Write-Error "Error setting the AG Listener's SPN: $_"
        }
    }
}

function RunSqlFiles {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Running SQL files"

    $sqlFiles = Get-ChildItem -Path "." -Filter "*.sql" 

    foreach ($sqlFile in $sqlFiles) {
        Write-Output "Running SQL file $sqlFile"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -File $sqlFile.FullName -EnableException
    }
    Write-Output "SQL files run complete"
}

function ConfigureTraceFlags {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Configuring trace flags"

    $TraceFlags = @(3226)
    if ($SqlVersion -lt 2016 ) {
        $TraceFlags += 1117
        $TraceFlags += 1118
    }
    Write-Verbose "Enabling trace flags $TraceFlags"
    
    try {
        Enable-DbaTraceFlag -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags -WarningAction SilentlyContinue
        Set-DbaStartupParameter -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags -Confirm:$false
    }
    catch {
        Write-Error "Error enabling or setting the instance trace flags: $_"
    }
}

function SetSpConfigureOptions {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Setting SpConfigure options"
  
    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'remote admin connections').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'remote admin connections' -Value 1 
    }

    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'optimize for ad hoc workloads').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'optimize for ad hoc workloads' -Value 1 
    }

    #Set CTOP to initial value of 50
    Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName"  -Name 'cost threshold for parallelism' -Value 50 -WarningAction SilentlyContinue
}

function AddToCms {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Adding to CMS"

    try {
        if ( $InstanceName -ne 'MSSQLSERVER') {
            if ( -Not ( Get-DbaRegisteredServer -SqlInstance $SQLManagementServer | Where-Object { $_.Name -contains "$SqlInstance\$InstanceName" }  ) ) {
                Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName "$SqlInstance\$InstanceName" -Group 'ALL' 
            }
        }
        else {
            if ( -Not ( Get-DbaRegisteredServer -SqlInstance $SQLManagementServer | Where-Object { $_.Name -contains $SqlInstance } ) ) {
                Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName $SqlInstance -Group 'ALL'
            }
        }    
    }
    catch {
        Write-Error "Error enrolling in CMS: $_"
    }
}

function InstallSqlCertificate {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Installing SQL certificate"

    try {
        if ( $InstanceName -ne 'MSSQLSERVER') {
            Install-SqlCertificate -ServerName $SqlInstance -InstanceName $InstanceName
        }
        else {
            Install-SqlCertificate -ServerName $SqlInstance
        }    
    }
    catch {
        Write-Error "Error installing certificate: $_"
    }
}

function ConfigureTempDb {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Configuring tempdb"

    try {
        Set-DbaTempdbConfig -SqlInstance "$SqlInstance\$InstanceName" -DataFileCount 8 -DataFileSize 1024 -DataFileGrowth 1024 -LogFileSize 1024 -LogFileGrowth 1024 -DataPath 'T:\TEMPDB' -LogPath 'L:\LOGS' 
    }
    catch {
        Write-Error "Error applying TempDB configuration: $_"
    }
}

function ConfigureModelDatabase  {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Configuring model database"

    try {
        $modelrecoverymodel = Get-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL"
        if ( $modelrecoverymodel.RecoveryModel -ne 'SIMPLE' ){
            Set-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL" -RecoveryModel Simple -Confirm:$false -EnableException
        }
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modeldev`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modellog`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException

        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Database "MASTER" -File ".\2-querystore.sql" -EnableException
        

        #Set-DbaDbQueryStoreOption -SqlInstance "$SqlInstance\$InstanceName" -Database 'MODEL' -State ReadWrite -FlushInterval 900 -CollectionInterval 30 -MaxSize 1000 -CaptureMode Auto -CleanupMode Auto -StaleQueryThreshold 367
    }
    catch {
        Write-Error "Error configuring the model database: $_"
    }
}

function ConfigureDatabaseMail {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Configuring database mail"

    try {
        if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name 'Database Mail XPs').ConfiguredValue -ne 1) {
            Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name 'Database Mail XPs' -Value 1 
        }

        if ( $SqlInstance -ne "MSSQLSERVER" ) {
            $EmailAddress = "$SqlInstance`_$InstanceName@polsinelli.com"        
        }
        else {
            $EmailAddress = $SqlInstance
        }

        $MailAccount = Get-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName"

        if ($MailAccount.Name -ne 'Default'){
            $NewMailAccount = New-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName" -Name 'Default' -EmailAddress $EmailAddress -DisplayName $EmailAddress -MailServer $SmtpRelay -Force
            New-DbaDbMailProfile -SqlInstance "$SqlInstance\$InstanceName" -Name 'Default' -MailAccountName $NewMailAccount.Name     
        }

        #Create the mail profile, create the Agent Operator and set the failsafe operator settings
        $Query = @()
        $Query += 'EXEC msdb.dbo.sp_send_dbmail @profile_name = ''Default'', @recipients = ''dbengineering@polsinelli.com'', @subject = ''SQL installed successfully'', @body = ''SQL installed successfully.  This is a test of sp_send_dbmail.'''

        if (  -Not (Get-DbaAgentOperator -SqlInstance "$SqlInstance\$InstanceName" -Operator 'Alerts') ){
            $Query += 'EXEC msdb.dbo.sp_add_operator @name = N''Alerts'', @email_address = N''sqlalerts@polsinelli.com'''
        }

        $Query += 'EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator = N''Alerts''';
        $Query += 'EXEC master.dbo.sp_MSsetalertinfo @notificationmethod = 1';
        $Query += "EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1,  @databasemail_profile=N`'Default`'";
        
        foreach ($line in $Query) {
            Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $line -EnableException
        }
    }
    catch {
        Write-Error "Error configuring database mail: $_"
    }
}

function RenameSaAccount {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Renaming SA account"

    $sql = "USE [master]
        DECLARE @new_sa_name VARCHAR(30) = 'dbe_internal'

        IF (SELECT COUNT(*) FROM sys.server_principals WHERE name='sa' AND is_disabled=1) > 0
        BEGIN
	        PRINT('Renaming sa account on ' + @@SERVERNAME + ' to ' + @new_sa_name)
	        DECLARE @cmd VARCHAR(100) = 'ALTER LOGIN sa WITH NAME = ' + @new_sa_name
	        EXEC(@cmd)
        END
        ELSE
        BEGIN
	        DECLARE @sa_name VARCHAR(30)
	        SELECT @sa_name = name FROM sys.server_principals WHERE sid = 0x01

	        PRINT('sa account already renamed to ' + @sa_name + ' on ' + @@SERVERNAME)
        END"

        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $sql -EnableException
}

function CreateLoginTrigger {
 Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Creating login trigger"

    $sql = "CREATE OR ALTER TRIGGER [TrgEnforceSecurity]
        ON ALL SERVER WITH EXECUTE AS 'dbe_internal'
        FOR CREATE_LOGIN, DROP_LOGIN, ADD_SERVER_ROLE_MEMBER, DROP_SERVER_ROLE_MEMBER
        AS
        BEGIN
	           DECLARE @userName varchar(128); 
	           SELECT @userName = EVENTDATA().value('(/EVENT_INSTANCE/LoginName)[1]', 'varchar(128)');

	           IF @userName IN ('POLSINELLI\dacroadmin','POLSINELLI\minmoadmin')
		          RETURN;

               DECLARE @ExecStr VARCHAR(MAX);
               DECLARE @EventData VARCHAR(MAX);
               DECLARE @ErrorMsg VARCHAR(MAX);

               -- Print warning to user   
               PRINT 'This SQL statement issued in violation of IT policy.  ALL database security changes must be sent to the Database Engineering team.';
               PRINT '';

               -- log error
               SELECT @EventData = COALESCE(CONVERT(VARCHAR(MAX), EVENTDATA()), '')
               SET @ErrorMsg = 'TrgEnforceSecurity invoked. ' + @EventData;
               RAISERROR (@ErrorMsg, 25, 1) WITH LOG

               -- Rollback unauthorized transaction    
               ROLLBACK;
        END"

        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $sql -EnableException
}


function ConfigureSqlAgent {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Configuring SQLAgent"

    try {
        Set-DbaAgentServer -SqlInstance "$SqlInstance\$InstanceName" -MaximumHistoryRows 10000 -MaximumJobHistoryRows 1000 -AgentMailType DatabaseMail -DatabaseMailProfile 'Default' -SaveInSentFolder Enabled
    }
    catch {
        Write-Error "Error configuring the SQL Agent: $_"
    }
}

function CreateSqlAgentJobs {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    Write-Output "Creating SQLAgent jobs"

    # Create SQLAgent jobs
    $jobs = [System.Collections.ArrayList] @()
    $jobs.AddRange((Get-ChildItem -Path ".\SqlAgentJobs\" -Filter "All*.sql")) | Out-Null
    $jobPrefix = (Invoke-DbaQuery -SqlInstance $SQLManagementServer -Database DBA -Query "SELECT dbo.GetJobPrefix('$SqlInstance') as JobPrefix").JobPrefix
    if ($jobPrefix -ne '') {
        $jobs.AddRange((Get-ChildItem -Path ".\SqlAgentJobs\" -Filter "$jobPrefix*.sql")) | Out-Null
    }

    $sqlCmdInstance  = "$SqlInstance\$InstanceName".Replace('\MSSQLSERVER', '')

    foreach ($job in $jobs) {
        $jobName = $($job.Name)
        Write-Output "Creating SQLAgent job $jobName"
        $fileName = ".\SqlAgentJobs\$jobName"
        Invoke-Sqlcmd -ServerInstance $sqlCmdInstance -InputFile $fileName -OutputSqlErrors:$True -DisableVariables
    }
}

function Invoke-SqlConfigure {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    # ConfigurePageFile -SqlInstance $SqlInstance # ignore error

    # run group

    Set-DbaPowerPlan -ComputerName $SqlInstance -PowerPlan 'High Performance'
    
    # chatgpt rewrite of AddSqlManagementToLocalAdmin.  test this, and revert back to orig version if problems.
    Add-SqlManagementToLocalAdmin2 -SqlInstance $SqlInstance -SQLManagement $SQLManagement
   
    InsertIntoCmdb -SqlInstance $SqlInstance -InstanceName $InstanceName
   
    ConfigureSpn -SqlInstance $SqlInstance

    ConfigureTraceFlags -SqlInstance $SqlInstance -InstanceName $InstanceName
    
    SetSpConfigureOptions -SqlInstance $SqlInstance -InstanceName $InstanceName
  
    Set-DbaMaxDop -SqlInstance "$SqlInstance\$InstanceName"

    Set-DbaMaxMemory -SqlInstance "$SqlInstance\$InstanceName"

    AddToCms -SqlInstance $SqlInstance -InstanceName $InstanceName

    ConfigureTempDb -SqlInstance $SqlInstance -InstanceName $InstanceName

    ConfigureModelDatabase -SqlInstance $SqlInstance -InstanceName $InstanceName

    ConfigureDatabaseMail -SqlInstance $SqlInstance -InstanceName $InstanceName # adds Alerts operator and sets database mail profile

    ConfigureSqlAgent -SqlInstance $SqlInstance -InstanceName $InstanceName
    ###

    # run group
    RunSqlFiles -SqlInstance $SqlInstance -InstanceName $InstanceName # hallengren, querystore, agent alerts, whoisactive

    # if this fails on second run, rename dbe_internal back to sa and rerun.  ALTER LOGIN dbe_internal WITH NAME = [sa]
    CreateSqlAgentJobs -SqlInstance $SqlInstance -InstanceName $InstanceName

    # run group
    RenameSaAccount -SqlInstance $SqlInstance -InstanceName $InstanceName
    DisableSaLogin -SqlInstance $SqlInstance -InstanceName $InstanceName
    CreateLoginTrigger -SqlInstance $SqlInstance -InstanceName $InstanceName
    Enable-DbaHideInstance -SqlInstance $SqlInstance

    # turn off remote access option
    $sql = "EXECUTE sp_configure 'show advanced options', 1;
        RECONFIGURE;
        EXECUTE sp_configure 'remote access', 0;
        RECONFIGURE;"
    Invoke-DbaQuery -SqlInstance $SqlInstance -Database master -Query $sql
}
