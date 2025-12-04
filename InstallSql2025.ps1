function InstallSql2025 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('2022','2025')]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$MediaPath,          # Local path on THIS machine to the root containing setup.exe

        [Parameter(Mandatory)]
        [string]$SqlInstance,        # "SERVER\INSTANCE" or "SERVER"

        [Parameter(Mandatory)]
        [string]$InstancePath,       # e.g. "C:\Program Files\Microsoft SQL Server"

        [Parameter(Mandatory)]
        [string]$DataPath,           # default data dir

        [Parameter(Mandatory)]
        [string]$LogPath,            # default log dir

        [Parameter(Mandatory)]
        [string]$TempPath,           # tempdb dir

        [Parameter(Mandatory)]
        [string]$BackupPath,         # backup dir

        [Parameter(Mandatory)]
        [string[]]$SqlSysadminAccounts,   # e.g. @('POLSINELLI\Database Engineers')

        [Parameter(Mandatory)]
        [pscredential]$EngineCredential,  # SQL Engine service account

        [Parameter(Mandatory)]
        [pscredential]$AgentCredential,   # SQL Agent service account

        [Parameter(Mandatory)]
        [pscredential]$InstallationCredential  # used for CredSSP hop to remote server
    )

    #
    # Parse server + instance
    #
    $serverName, $instanceName = $SqlInstance -split '\\', 2
    if (-not $instanceName -or $instanceName -eq '') {
        $instanceName = 'MSSQLSERVER'
    }

    #
    # Validate media locally (on the orchestrating machine)
    #
    $localSetupExe = Join-Path -Path $MediaPath -ChildPath 'setup.exe'
    if (-not (Test-Path $localSetupExe)) {
        throw "Local setup.exe not found at '$localSetupExe'."
    }

    Write-Host "Preparing SQL Server $Version install for instance '$SqlInstance' on '$serverName'..."

    #
    # Stage media on the target server via admin share ONLY IF MISSING
    #
    $remoteStagingRoot = "\\$serverName\C$\Temp\SQLSetup_$Version"
    $remoteSetupExeUNC = Join-Path $remoteStagingRoot 'setup.exe'

    if (-not (Test-Path $remoteSetupExeUNC)) {
        Write-Host "Media not found on '$serverName'. Copying media from '$MediaPath' to '$remoteStagingRoot' (one-time copy)..."
        if (-not (Test-Path $remoteStagingRoot)) {
            New-Item -Path $remoteStagingRoot -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path (Join-Path $MediaPath '*') -Destination $remoteStagingRoot -Recurse -Force
        Write-Host "Media copy complete."
    }
    else {
        Write-Host "Media already present on '$serverName' at '$remoteStagingRoot'. Skipping copy."
    }

    #
    # Path as seen ON THE TARGET SERVER
    #
    $remoteMediaPathLocal = "C:\Temp\SQLSetup_$Version"

    Write-Host "Running install on remote server: $serverName"

    #
    # Remote script: build command line, clean tempdb files, run setup, set services
    #
    $scriptBlock = {
        param(
            $Version,
            $MediaPathLocal,
            $ServerName,
            $InstanceName,
            $InstancePath,
            $DataPath,
            $LogPath,
            $TempPath,
            $BackupPath,
            $SqlSysadminAccounts,
            [pscredential]$EngineCredential,
            [pscredential]$AgentCredential
        )

        Write-Host "SQL Version: $Version"
        Write-Host "MediaPath (local): $MediaPathLocal"
        Write-Host "Instance: $ServerName\$InstanceName"

        $setupExe = Join-Path -Path $MediaPathLocal -ChildPath 'setup.exe'
        if (-not (Test-Path $setupExe)) {
            throw "setup.exe not found at '$setupExe' on remote server '$env:COMPUTERNAME'."
        }

        #
        # Clean leftover tempdb files (if any)
        #
        if (Test-Path $TempPath) {
            Write-Host "Checking for existing tempdb files in '$TempPath'..."
            $tempdbPatterns = @(
                'tempdb.mdf',
                'templog.ldf',
                'tempdb_mssql_*.ndf'
            )

            foreach ($pattern in $tempdbPatterns) {
                Get-ChildItem -Path $TempPath -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "Removing leftover tempdb file: $($_.FullName)"
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Host "Temp path '$TempPath' does not exist yet. Skipping tempdb cleanup."
        }

        #
        # Build setup arguments
        #
        # Note: /Q + /INDICATEPROGRESS for quiet, non-interactive install
        #
        $args = @(
            '/ACTION=Install'
            '/Q'
            '/INDICATEPROGRESS'
            '/IACCEPTSQLSERVERLICENSETERMS=1'
            '/FEATURES=SQLENGINE'
            "/INSTANCENAME=$InstanceName"
            "/SQLSVCACCOUNT=$($EngineCredential.UserName)"
            "/SQLSVCPASSWORD=$($EngineCredential.GetNetworkCredential().Password)"
            "/SQLSVCSTARTUPTYPE=Automatic"
            "/AGTSVCACCOUNT=$($AgentCredential.UserName)"
            "/AGTSVCPASSWORD=$($AgentCredential.GetNetworkCredential().Password)"
            "/AGTSVCSTARTUPTYPE=Automatic"
            "/INSTALLSQLDATADIR=$DataPath"
            "/SQLUSERDBDIR=$DataPath"
            "/SQLUSERDBLOGDIR=$LogPath"
            "/SQLBACKUPDIR=$BackupPath"
            "/SQLTEMPDBDIR=$TempPath"
            "/SQLTEMPDBLOGDIR=$TempPath"
            "/INSTANCEDIR=$InstancePath"
            "/PID=DBVCF-CW7QC-NJW9V-3CJ9C-7CJPW" # Product Key
            "/PRODUCTCOVEREDBYSA=TRUE"
            "/SUPPRESSPAIDEDITIONNOTICE=1"
            '/BROWSERSVCSTARTUPTYPE=Disabled'
            '/UpdateEnabled=0'          # no product updates during install
        )

        # Sysadmin accounts (quote because of spaces in group names)
        if ($SqlSysadminAccounts -and $SqlSysadminAccounts.Count -gt 0) {
            $quoted = $SqlSysadminAccounts | ForEach-Object { '"{0}"' -f $_ }
            $saList = $quoted -join ' '
            $args += "/SQLSYSADMINACCOUNTS=$saList"
        }

        Write-Host "Starting SQL Server $Version install for instance '$ServerName\$InstanceName'..."
        Write-Host "Command line on $env:COMPUTERNAME:"
        Write-Host "`"$setupExe`" $($args -join ' ')"

        $startProcessSplat = @{
            FilePath     = $setupExe
            ArgumentList = $args
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }

        $proc = Start-Process @startProcessSplat
        $exitCode = $proc.ExitCode

        Write-Host "Setup.exe exited with code $exitCode on $env:COMPUTERNAME."

        #
        # Try to ensure SQL Agent is Automatic + Started if install succeeded / semi-succeeded
        #
        if ($exitCode -eq 0 -or $exitCode -eq -2067919934) {
            $agentServiceName = if ($InstanceName -eq 'MSSQLSERVER') {
                'SQLSERVERAGENT'
            }
            else {
                "SQLAgent`$$InstanceName"
            }

            try {
                $svc = Get-Service -Name $agentServiceName -ErrorAction Stop
                Write-Host "Configuring service '$agentServiceName' to start Automatically..."
                Set-Service -Name $agentServiceName -StartupType Automatic
                if ($svc.Status -ne 'Running') {
                    Write-Host "Starting service '$agentServiceName'..."
                    Start-Service -Name $agentServiceName -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-Warning "SQL Agent service '$agentServiceName' not found or could not be configured. This may occur if setup failed or did not reach service creation."
            }
        }

        return $exitCode
    }

    #
    # Invoke the remote script using CredSSP and the supplied InstallationCredential
    #
    $exitCode = Invoke-Command -ComputerName $serverName `
                               -Authentication CredSSP `
                               -Credential $InstallationCredential `
                               -ScriptBlock $scriptBlock `
                               -ArgumentList @(
                                    $Version,
                                    $remoteMediaPathLocal,
                                    $serverName,
                                    $instanceName,
                                    $InstancePath,
                                    $DataPath,
                                    $LogPath,
                                    $TempPath,
                                    $BackupPath,
                                    $SqlSysadminAccounts,
                                    $EngineCredential,
                                    $AgentCredential
                               )

    Write-Host "Remote setup completed with exit code $exitCode."

    #
    # Handle common exit codes
    #
    switch ($exitCode) {
        0 {
            Write-Host "SQL Server $Version installation on '$serverName' completed successfully." -ForegroundColor Green
        }
        -2067919934 {
            Write-Warning "Install completed but requires a reboot on '$serverName' (exit code -2067919934 / 3010). Reboot the server to finalize SQL setup."
        }
        default {
            Write-Warning "SQL setup failed with exit code $exitCode. Check Summary.txt on '$serverName' under 'C:\Program Files\Microsoft SQL Server\170\Setup Bootstrap\Log' for details."
        }
    }

    return $exitCode
}

function UninstallSqlInstance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('2022','2025')]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$MediaPath,   # same as InstallSql2025 – local path that you used for staging

        [Parameter(Mandatory)]
        [string]$SqlInstance  # "SERVER\INSTANCE" or "SERVER" for default instance
    )

    # Parse server + instance
    $serverName, $instanceName = $SqlInstance -split '\\', 2
    if (-not $instanceName -or $instanceName -eq '') {
        $instanceName = 'MSSQLSERVER'
    }

    # Validate media locally
    $localSetupExe = Join-Path -Path $MediaPath -ChildPath 'setup.exe'
    if (-not (Test-Path $localSetupExe)) {
        throw "Local setup.exe not found at '$localSetupExe'."
    }

    Write-Host "Preparing to uninstall SQL Server $Version instance '$SqlInstance' on '$serverName'..."

    # Staging folder on the target server (via admin share) – same pattern as InstallSql2025
    $remoteStagingRoot  = "\\$serverName\C$\Temp\SQLSetup_$Version"
    $remoteSetupExePath = Join-Path $remoteStagingRoot 'setup.exe'

    if (Test-Path $remoteSetupExePath) {
        Write-Host "Media already present on '$serverName' at '$remoteStagingRoot'. Skipping copy."
    } else {
        if (-not (Test-Path $remoteStagingRoot)) {
            New-Item -Path $remoteStagingRoot -ItemType Directory -Force | Out-Null
        }

        Write-Host "Copying media from '$MediaPath' to '$remoteStagingRoot' (this may take a while)..."
        Copy-Item -Path (Join-Path $MediaPath '*') -Destination $remoteStagingRoot -Recurse -Force
    }

    # Path as seen ON THE TARGET SERVER
    $remoteMediaPathLocal = "C:\Temp\SQLSetup_$Version"

    $scriptBlock = {
        param(
            $Version,
            $MediaPathLocal,
            $ServerName,
            $InstanceName
        )

        Write-Host "Running uninstall on remote server: $env:COMPUTERNAME"
        Write-Host "SQL Version: $Version"
        Write-Host "MediaPath (local): $MediaPathLocal"
        Write-Host "Instance: $ServerName\$InstanceName"

        $setupExe = Join-Path -Path $MediaPathLocal -ChildPath 'setup.exe'
        if (-not (Test-Path $setupExe)) {
            throw "setup.exe not found at '$setupExe' on remote server '$env:COMPUTERNAME'."
        }

        # Core uninstall args
        $args = @(
            '/ACTION=Uninstall'
            '/Q'                              # fully quiet
            '/INDICATEPROGRESS'
            "/INSTANCENAME=$InstanceName"
            '/FEATURES=SQLENGINE'             # adjust if you later add more features
        )

        Write-Host "Starting SQL Server $Version uninstall for instance '$ServerName\$InstanceName'..."
        Write-Host "Command line on $env:COMPUTERNAME:"
        Write-Host "`"$setupExe`" $($args -join ' ')"

        $startProcessSplat = @{
            FilePath     = $setupExe
            ArgumentList = $args
            Wait         = $true
            PassThru     = $true
            NoNewWindow  = $true
        }

        $proc = Start-Process @startProcessSplat
        $exitCode = $proc.ExitCode

        Write-Host "Uninstall setup.exe exited with code $exitCode on $env:COMPUTERNAME."
        return $exitCode
    }

    $exitCode = Invoke-Command -ComputerName $serverName -ScriptBlock $scriptBlock -ArgumentList @(
        $Version,
        $remoteMediaPathLocal,
        $serverName,
        $instanceName
    )

    if ($exitCode -is [array]) {
        $exitCode = $exitCode[0]
    }

    Write-Host "Remote uninstall completed with exit code $exitCode."

    # Optional: detect "reboot required" (same 3010 pattern as install)
    if ($exitCode -eq -2067919934 -or $exitCode -eq 3010) {
        Write-Warning "Uninstall completed but requires a reboot on '$serverName'."
        # If you want to auto-reboot, you *could* do:
        # Restart-Computer -ComputerName $serverName -Force
        # but I'm leaving it as a warning so you stay in control.
    }

    return $exitCode
}
