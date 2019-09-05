function Invoke-SqlConfigure {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    )

    #region Windows Configuration
    $PageFileLocation = 'F:\'
    $PageFileSize = 8192
    $PageFileSettings = Get-DbaPageFileSetting -ComputerName $SqlInstance
    if ( $PageFileSettings.FileName -notlike "$PageFileLocation*" -or $PageFileSettings.InitialSize -ne $PageFileSize  -or $PageFileSettings.MaximumSize -ne $PageFileSize  ){
        Set-PageFile -ComputerName $SqlInstance -Location $PageFileLocation -InitialSize $PageFileSize -MaximumSize $PageFileSize        
    }
    else{
        Write-Output "Page file in desired state"
        $PageFileSettings
    }
    #end region

    #region SQL Management
    #Add "SQL Management Group to local administrators, this is for CommVault access to the server"
    $group = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement } 
    try {
        if ( $group.Name -notcontains $SQLManagement  ) {
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
        New-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement
        Set-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" -Login $SQLManagement -AddRole sysadmin
    }
    catch{
        Write-Error "Error creating the login for $SQLManagement and adding it to the sysadmin server role: $_"
    }


    #Disable the sa login.
    Get-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.Name -eq 'sa' } | Set-DbaLogin -Disable

    
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
    #endregion

    #region SPN Configuration
    #Configure SPNs for use with a named SQL Server service account
    try {
        Test-DbaSpn -ComputerName $SqlInstance | Where-Object { $_.IsSet -eq $false } | Set-DbaSpn
    }
    catch {
        Write-Error "Error setting the SPN: $_"
    }
    
    #if this is the primary configure the SPN for the AG listener
    if ( $SqlInstance -eq $AGPrimary ) {
        try {
            $ListenerFQDN = ([System.Net.Dns]::GetHostByName($AGListener)).HostName
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN" -ServiceAccount $ServiceAccount
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN`:1433" -ServiceAccount $ServiceAccount
        }
        catch {
            Write-Error "Error setting the AG Listener's SPN: $_"
        }
    }
    #endregion

    #region Tools Installation
    #Expand-Archive -Path "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2\who_is_active_v11_32.zip" -DestinationPath "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2" -Force
    #Install-DbaWhoIsActive -SqlInstance "$SqlInstance\$InstanceName" -Database "master" -LocalFile "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2\who_is_active_v11_32.sql" #this deletes the sql file when done!   
    Install-DbaWhoIsActive -SqlInstance "$SqlInstance\$InstanceName" -Database "master" 
    
    #Install and configure the maintenance scripts
    Install-DbaMaintenanceSolution -SqlInstance "$SqlInstance\$InstanceName" -Database master -OutputFileDirectory 'C:\SqlAgentLogs'
    
    #endregion

    #region Instance Configuration
    #Configure server wide trace flags
    $TraceFlags = @(3226)
    if ($SqlVersion -lt 2016 ) {
        $TraceFlags += 1117
        $TraceFlags += 1118
    }
    Write-Verbose "Enabling trace flags $TraceFlags"
    
    try {
        Enable-DbaTraceFlag -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags
        Set-DbaStartupParameter -SqlInstance "$SqlInstance\$InstanceName" -TraceFlag $TraceFlags -Confirm:$false
    }
    catch {
        Write-Error "Error enabling or setting the instance trace flags: $_"
    }

    if ( (Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'remote admin connections').ConfiguredValue -ne 1) {
        Set-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName" -Name  'remote admin connections' -Value 1 
    }


    #Enroll in CMS/MSX
    try {
        if ( $InstanceName -ne 'MSSQLSERVER') {
            if ( -Not ( Get-DbaRegisteredServer -SqlInstance $SQLManagementServer | Where-Object { $_.Name -contains "$SqlInstance\$InstanceName" }  ) ) {
                Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName "$SqlInstance\$InstanceName" -Group 'ALL' 
            }

            $TargetServer = $null
            $TargetServer = (Get-DbaAgentServer -SqlInstance $CMDBServer).TargetServers.Name | Where-Object { $_ -contains "$SqlInstance\$InstanceName" } 
            if ( !$TargetServer ){
                Register-Msx -MSXServer $SQLManagementServer -TargetServer $SqlInstance -InstanceName $InstanceName -ServiceAccount $ServiceAccount -ActiveDirectoryDomain $ActiveDirectoryDomain
            }
            Install-SqlCertificate -ServerName $SqlInstance -InstanceName $InstanceName
        }
        else {
            if ( -Not ( Get-DbaRegisteredServer -SqlInstance $SQLManagementServer | Where-Object { $_.Name -contains $SqlInstance } ) ) {
                Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName $SqlInstance -Group 'ALL'
            }

            $TargetServer = $null
            $TargetServer = (Get-DbaAgentServer -SqlInstance $CMDBServer).TargetServers.Name | Where-Object { $_ -contains "$SqlInstance" } 
            if ( !$TargetServer ){
                Register-Msx -MSXServer $SQLManagementServer -TargetServer $SqlInstance -ServiceAccount $ServiceAccount -ActiveDirectoryDomain $ActiveDirectoryDomain
            }
            else{
                Write-Output 'hete'
            }
            Install-SqlCertificate -ServerName $SqlInstance
        }    
    }
    catch {
        Write-Error "Error enrolling system in the CMS or MSX: $_"
    }

    #Configure TempDB
    try {
        Set-DbaTempdbConfig -SqlInstance "$SqlInstance\$InstanceName" -DataFileCount 8 -DataFileSize 1024 -DataFileGrowth 1024 -LogFileSize 1024 -LogFileGrowth 1024 -DataPath 'T:\TEMPDB' -LogPath 'L:\LOGS' 
    }
    catch {
        Write-Error "Error applying TempDB configuration: $_"
    }
    

    #Configure Model
    try {
        $modelrecoverymodel = Get-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL"
        if ( $modelrecoverymodel.RecoveryModel -ne 'SIMPLE' ){
            Set-DbaDbRecoveryModel -SqlInstance "$SqlInstance\$InstanceName" -Database "MODEL" -RecoveryModel Simple -Confirm:$false -EnableException
        }
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modeldev`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException
        $Query = "ALTER DATABASE [model] MODIFY FILE ( NAME = N`'modellog`', FILEGROWTH = 512MB )"
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $Query -EnableException

        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Database "MASTER" -File ".\2-querystore.sql"  -EnableException
        #Set-DbaDbQueryStoreOption -SqlInstance "$SqlInstance\$InstanceName" -Database 'MODEL' -State ReadWrite -FlushInterval 900 -CollectionInterval 30 -MaxSize 1000 -CaptureMode Auto -CleanupMode Auto -StaleQueryThreshold 367
    }
    catch {
        Write-Error "Error configuring the model database: $_"
    }
    #endregion
    
    #region Database Mail Configuration
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
        $Query += 'EXEC msdb.dbo.sp_send_dbmail @profile_name = ''Default'', @recipients = ''dbengineering@polsinelli.com'', @subject = ''Test message'', @body = ''This is the body of the test message.'''

        if (  -Not (Get-DbaAgentOperator -SqlInstance "$SqlInstance\$InstanceName" -Operator 'Alerts') ){
            $Query += 'EXEC msdb.dbo.sp_add_operator @name = N''Alerts'', @email_address = N''sqlalerts@polsinelli.com'''
        }

        $Query += 'EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator = N''Alerts''';
        $Query += 'EXEC master.dbo.sp_MSsetalertinfo @notificationmethod = 1';
        
        foreach ($line in $Query) {
            Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Query $line -EnableException
        }
    }
    catch {
        Write-Error "Error configuring database mail: $_"
    }
    #endregion

    #region Configure Agent and Agent Alerts
    #Configure Agent
    try {
        Set-DbaAgentServer -SqlInstance "$SqlInstance\$InstanceName" -MaximumHistoryRows 10000 -MaximumJobHistoryRows 1000 -AgentMailType DatabaseMail -DatabaseMailProfile 'Default' -SaveInSentFolder Enabled
    }
    catch {
        Write-Error "Error configuring the SQL Agent: $_"
    }

    #Create SQL Agent Alerts
    try {
        Invoke-DbaQuery -SqlInstance "$SqlInstance\$InstanceName" -Database "MSDB"  -File '.\1-Alerts.sql' -EnableException
    }
    catch {
        Write-Error "Error creating the SQL Agent Alerts: $_"
    }
    #endregion

    #region Add Server to S1
    Import-Module "C:\Program Files\SentryOne\19.0\Intercerve.SQLSentry.Powershell.psd1"
    $instance = Get-Connection | Where-Object { $_.ServerName -like "$SqlInstance*" }
    if ( $instance.WatchedBy -notlike "*PerformanceAdvisor*" ){        
        Add-SentryOne -SqlInstance $SqlInstance -S1Host $S1Host
    }
    else{
        Write-Output "$SqlInstance already in SentryOne"
    }
    #region
}