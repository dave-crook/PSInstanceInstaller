function Invoke-SqlConfigure {
    Param(
        [Parameter(Mandatory = $True)]    [String]   $SqlInstance,
        [String]   $InstanceName = "MSSQLSERVER"
    
    )
        
    #region - ### Post installation ###
    #Add "SQL Management Group to local administrators, this is for CommVault access to the server"
    $group = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }
    try {
        if ( -not $group ) {
            Write-Verbose "Adding $($group.Name) to Local Adminstrators group on $servername"
            Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Add-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement }
        }
        else {
            Write-Verbose "$($group.Name) found on $SqlInstance in Local Adminstrators group"
        }
    }
    catch {
        Write-Error $_ 
    }
    
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
        Write-Error $_ 
    }
    
    #Configure SPNs for use with a named SQL Server service account
    try {
        Test-DbaSpn -ComputerName $SqlInstance | Where-Object { $_.IsSet -eq $false } | Set-DbaSpn
    }
    catch {
        Write-Error $_
    }
    
    #if this is the primary configure the SPN for the AG listener
    if ( $SqlInstance -eq $AGPrimary ) {
        try {
            $ListenerFQDN = ([System.Net.Dns]::GetHostByName($AGListener)).HostName
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN" -ServiceAccount $ServiceAccount
            Set-DbaSpn -SPN "MSSQLSvc/$ListenerFQDN`:1433" -ServiceAccount $ServiceAccount
        }
        catch {
            Write-Error $_
        }
    }
    
    #Install sp_whoisactive
#    Expand-Archive -Path "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2\who_is_active_v11_32.zip" -DestinationPath "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2" -Force
#    Install-DbaWhoIsActive -SqlInstance "$SqlInstance\$InstanceName" -Database "master" -LocalFile "\\dcp-vsql-01\Installs\Scripts\DSC_SQL_v2\who_is_active_v11_32.sql" #this deletes the sql file when done!   
    Install-DbaWhoIsActive -SqlInstance "$SqlInstance\$InstanceName" -Database "master" 
    
    #Install and configure the maintenance scripts
    Install-DbaMaintenanceSolution -SqlInstance "$SqlInstance\$InstanceName" -Database master -OutputFileDirectory 'C:\SqlAgentLogs'
    
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
        Write-Error $_ 
    }
    
    #Configure TempDB
    try {
        Set-DbaTempdbConfig -SqlInstance "$SqlInstance\$InstanceName" -DataFileCount 8 -DataFileSize 1024 -DataFileGrowth 1024 -LogFileSize 1024 -LogFileGrowth 1024 -DataPath 'T:\TEMPDB' -LogPath 'L:\LOGS' 
    }
    catch {
        Write-Error $_ 
    }
    
    #Enroll in CMS/MSX
    if ( $InstanceName -ne 'MSSQLSERVER') {
        Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName "$SqlInstance\$InstanceName" -Group 'ALL'
        Register-Msx -MSXServer $SQLManagementServer -TargetServer $SqlInstance -InstanceName $InstanceName -ServiceAccount $ServiceAccount -ActiveDirectoryDomain $ActiveDirectoryDomain
        Install-SqlCertificate -ServerName $SqlInstance -InstanceName $InstanceName
    }
    else {
        Add-DbaRegServer -SqlInstance $SQLManagementServer -ServerName $SqlInstance -Group 'ALL'        
        Register-Msx -MSXServer $SQLManagementServer -TargetServer $SqlInstance -ServiceAccount $ServiceAccount -ActiveDirectoryDomain $ActiveDirectoryDomain
        Install-SqlCertificate -ServerName $SqlInstance 
    }
    
    <#
    #Configure SQL Agent, SQL Mail and send a test email
    try {
        Invoke-DbaQuery -ServerInstance "$SqlInstance\$InstanceName" -Database "MASTER" -File ".\1-instance.sql" 
    }
    catch {
        Write-Error $_ 
    }
    
    #Configure Query Store
    try {
        Invoke-DbaQuery -ServerInstance "$SqlInstance\$InstanceName" -Database "MASTER" -File ".\2-querystore.sql" 
        #Set-DbaDbQueryStoreOption -SqlInstance $SqlInstance -Database 'MODEL' -State ReadWrite -FlushInterval 900 -CollectionInterval 30 -MaxSize 1000 -CaptureMode Auto -CleanupMode Auto -StaleQueryThreshold 367
    }
    catch {
    }
    #>
    #endregion
}
    