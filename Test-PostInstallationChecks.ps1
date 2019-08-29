#Requires -Modules @{ ModuleName="pester"; ModuleVersion="4.8.1" }
#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.0.34" }

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Specify a servername')]
    [ValidateNotNullorEmpty()]
    [string] $SqlInstance,
    [string] $InstanceName = "MSSQLSERVER"
    )

. .\Register-Msx.ps1
. .\Test-ServiceAccountToGroup.ps1
. .\Set-ServiceAccountToGroup.ps1

Describe "Management Services" {
    Context "$SqlInstance`: CMBD Enrolled" {
        $cmdb_Servers = (Invoke-DbaQuery -SqlInstance $CMDBServer -Database 'DBA' -Query 'select ServerName from [dbo].[vw_ActiveServerList]').ServerName
        It "Testing to see if this server exists in the CMDB on $CMDBServer" {
            $cmdb_Servers | Should -Contain $SqlInstance -Because "We want this server to be registerd in the CMDB on $CMDBServer"
        }
    }
    Context "$SqlInstance`: Registered in MSX" {
        $AgentConfiguration = (Get-DbaAgentServer -SqlInstance "$SqlInstance\$InstanceName" | Select-Object JobServerType, MsxServerName)

        if ($AgentConfiguration.JobServerType -eq 'Msx') {
            It "$SqlInstance`: Testing to ensure this is a master server" {
                ($AgentConfiguration).JobServerType | Should -Be 'Msx' -Because "This is a master (MSX) Server"
            }
        }
        if ($AgentConfiguration.JobServerType -ne 'Msx') {
            It "$SqlInstance`: Testing to ensure this is a target server" {
                ($AgentConfiguration).JobServerType | Should -Be 'tsx' -Because "This is a target (TSX) Server and it's master is $($AgentConfiguration.MsxServerName) "
            }
        }
    }  
    Context "$SqlInstance`: Registered in CMS, but only if we're not the CMS." {
        $registeredServer = (Get-DbaRegisteredServer -SqlInstance $CMDBServer -Name $SqlInstance).ServerName
        It "$SqlInstance`: Test to see if instance is registered in the CMS" {
            #Using a BeLike which should get us around shortname vs. FQDNs in the $SqlInstance and $registeredServer variables
            $registeredServer | Should -BeLike "$SqlInstance*" -Because "We really want to have all of the servers registered in the CMS "
        }  
    }

    Context "$SqlInstance`: Registered in SentryOne" {
        Import-Module "C:\Program Files\SentryOne\19.0\Intercerve.SQLSentry.Powershell.psd1"
        $instance = Get-Connection | Where-Object { $_.ServerName -like "$SqlInstance*" }
        It "$SqlInstance`: Check to see if SQL Instance is registered in SentryOne and watched by Performance Advisor" {
            $instance.WatchedBy | Should -BeLike "*PerformanceAdvisor*"
        }
    }  
}

    
Describe "SQL Agent Configuration" {
    Context "$SqlInstance`: Testing to see if the SQL Server Agent Service is running" {
        It "Testing to see if the SQL Server Agent Service is running" {
            $result = (Get-DbaService -ComputerName "$SqlInstance\$InstanceName" -Type Agent).State
            $result | Should -Be 'Running' -Because "We want to ensure SQL Server Service is online."
        }
    } 
    Context "$SqlInstance`: SqlAgent Operator" {
        @(Get-DbaAgentOperator -SqlInstance "$SqlInstance\$InstanceName" -Operator Alerts).ForEach{
            It 'Testing for an Operator named Alerts' {
                $PSItem.Name | Should -Be "Alerts" -Because "There should be an operator named Alerts"
            }
            It 'Testing if Alert Operator has a valid email address' {
                $PSItem.EmailAddress | Should -Match '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$' -Because "There should be valid email address on the operator"
            }
        }  
    }
    Context "$SqlInstance`: Agent History Retention" {
        @(Get-DbaAgentServer -SqlInstance "$SqlInstance\$InstanceName").ForEach{
            It "$SqlInstance`: Should have a job history length set to 1000 per job" {
                $psitem.MaximumJobHistoryRows | Should -BeGreaterOrEqual 1000 -Because "We want to keep a large body of job history around per job."
            }
            It "$SqlInstance`: Should have a job history length set to 10000 total" {
                $psitem.MaximumHistoryRows | Should -BeGreaterOrEqual 10000 -Because "We want to keep a large body of job history around total."
            }
        }  
    }
    Context "$SqlInstance`: Testing for the existence of required SQL Agent Alerts" {
        $alerts = (Get-DbaAgentAlert -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.IsEnabled -eq $true } )

        It "Should have an Agent Alert for Error 18456: Failed Login" {
            ($alerts.MessageID | Where-Object { $_ -eq '18456' }) | Should -Be '18456'
        }
  
        It "Should have an Agent Alert for Error 5144: Database Auto-grow cancelled or failed" {
            ($alerts.MessageID | Where-Object { $_ -eq '5144' }) | Should -Be '5144'
        }
  
        It "Should have an Agent Alert for Error 5145: Database Auto-grow successful" {
            ($alerts.MessageID | Where-Object { $_ -eq '5145' }) | Should -Be '5145'
        }
  
        It "Should have an Agent Alert for Error 823: Operating System Read Error Occured" {
            ($alerts.MessageID | Where-Object { $_ -eq '823' }) | Should -Be '823'
        }
  
        It "Should have an Agent Alert for Error 824: SQL Server Read Error Occured" {
            ($alerts.MessageID | Where-Object { $_ -eq '824' }) | Should -Be '824'
        }
  
        It "Should have an Agent Alert for Error 825: Read-Retry Required" {
            ($alerts.MessageID | Where-Object { $_ -eq '825' }) | Should -Be '825'
        }
  
        It "Should have an Agent Alert for Error 832: Constant page has changed" {
            ($alerts.MessageID | Where-Object { $_ -eq '832' }) | Should -Be '832'
        }
  
        It "Should have an Agent Alert for Error 855: Uncorrectable hardware memory corruption detected" {
            ($alerts.MessageID | Where-Object { $_ -eq '855' }) | Should -Be '855'
        }
  
        It "Should have an Agent Alert for Error 856: SQL Server has detected hardware memory corruption, but has recovered the page" {
            ($alerts.MessageID | Where-Object { $_ -eq '856' }) | Should -Be '856'
        }
  
        It "Should have an Agent Alert for Sev 16 Error: Error in Resource - User correctable" {
            ($alerts.Severity | Where-Object { $_ -eq '16' }) | Should -Be '16'
        }
  
        It "Should have an Agent Alert for Sev 17 Error: Insufficient Resources" {
            ($alerts.Severity | Where-Object { $_ -eq '17' }) | Should -Be '17'
        }
  
        It "Should have an Agent Alert for Sev 18 Error: Nonfatal Internal Error Detected" {
            ($alerts.Severity | Where-Object { $_ -eq '18' }) | Should -Be '18'
        }
  
        It "Should have an Agent Alert for Sev 19 Error: Fatal Error in Resource" {
            ($alerts.Severity | Where-Object { $_ -eq '19' }) | Should -Be '19'
        }
  
        It "Should have an Agent Alert for Sev 20 Error: Fatal Error in Current Process" {
            ($alerts.Severity | Where-Object { $_ -eq '20' }) | Should -Be '20'
        }
  
        It "Should have an Agent Alert for Sev 21 Error: Fatal Error in Database Process" {
            ($alerts.Severity | Where-Object { $_ -eq '21' }) | Should -Be '21'
        }
  
        It "Should have an Agent Alert for Sev 22 Error: Fatal Error: Table Integrity Suspect" {
            ($alerts.Severity | Where-Object { $_ -eq '22' }) | Should -Be '22'
        }
  
        It "Should have an Agent Alert for Sev 23 Error: Fatal Error Database Integrity Suspect" {
            ($alerts.Severity | Where-Object { $_ -eq '23' }) | Should -Be '23'
        }
  
        It "Should have an Agent Alert for Sev 24 Error: Fatal Hardware Error" {
            ($alerts.Severity | Where-Object { $_ -eq '24' }) | Should -Be '24'
        }
  
        It "Should have an Agent Alert for Sev 25 Error: Fatal Error" {
            ($alerts.Severity | Where-Object { $_ -eq '25' }) | Should -Be '25'
        }        
    }
    Context "$SqlInstance`: Failsafe Operator Configuration" {
        $AgentConfiguration = Get-DbaAgentServer -Sqlinstance "$SqlInstance\$InstanceName"
        $fso = $AgentConfiguration | Select-Object AlertSystem -ExpandProperty AlertSystem
        It "Should have a Failsafe Operator named Alerts" {
            $fso.FailSafeOperator | Should -Be "Alerts"
        }
        It "Should have a Failsafe Operator notification method set to email" {
            $fso.NotificationMethod | Should -Be "NotifyEmail"
        }
        It "Should have a Agent Alert Type of DatabaseMail" {
            $AgentConfiguration.AgentMailType | Should -Be "DatabaseMail"
        }
        It "Should have a DatabaseMail Profile" {
            $AgentConfiguration.DatabaseMailProfile | Should -Be "Default"
        }
    }
}

Describe "Ola Hallengren SP and Job Configuration" {
    Context "$SqlInstance`: Test to see if Ola Hallengrens Maintenance Solution and if sp_whoisactive is installed" {
        #Do not use this, brutally slow.
        #$storedprocedures = (Get-DbaDbStoredProcedure -SqlInstance "$SqlInstance\$InstanceName" -Database 'master' -ExcludeSystemSp).Name
        $storedprocedures = (Get-DbaModule -SqlInstance "$SqlInstance\$InstanceName" -Database 'master' -ExcludeSystemObjects | Where-Object { $_.Type -eq 'SQL_STORED_PROCEDURE' } ).Name

        It 'Testing for DatabaseBackup' {
            $storedprocedures | Should -Contain "DatabaseBackup" -Because "We want this script on all systems"
        }
        It 'Testing for DatabaseIntegrityCheck' {
            $storedprocedures | Should -Contain "DatabaseIntegrityCheck" -Because "We want this script on all systems"
        }
        It 'Testing for IndexOptimize' {
            $storedprocedures | Should -Contain "IndexOptimize" -Because "We want this script on all systems"
        }
        It 'Testing for CommandExecute' {
            $storedprocedures | Should -Contain "CommandExecute" -Because "We want this script on all systems"
        }
        It 'Testing for sp_WhoIsActive' {
            $storedprocedures | Should -Contain "sp_WhoIsActive" -Because "We want this script on all systems"
        }
    }
    Context "$SqlInstance`: Test to see if maintenance jobs are on the local instance" {
        $jobs = Get-DbaAgentJob -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.Enabled -eq $true }
        It 'Should have a CommandLog Cleanup job' {
            ($jobs.Name | Where-Object { $_ -like "*CommandLog Cleanup" }) | Should -BeLike "*CommandLog Cleanup" 
        }
        It 'Should have an All - Cycle SQL Error Log job' {
            ($jobs.Name | Where-Object { $_ -like "All - Cycle SQL Error Log" }) | Should -BeLike "All - Cycle SQL Error Log"
        }        
        It 'Should have a Integrity Check job for the SYSTEM_DATABASES' {
            ($jobs.Name | Where-Object { $_ -like "*DatabaseIntegrityCheck - SYSTEM_DATABASES" }) | Should -BeLike "*DatabaseIntegrityCheck - SYSTEM_DATABASES"
        }
        It 'Should have a Integrity Check job for the USER_DATABASES' {
            ($jobs.Name | Where-Object { $_ -like "*DatabaseIntegrityCheck - USER_DATABASES" }) | Should -BeLike "*DatabaseIntegrityCheck - USER_DATABASES"
        }
        It 'Should have a Index Maintenance job for the ALL_DATABASES' {
            ($jobs.Name | Where-Object { $_ -like "*IndexOptimize - ALL_DATABASES" }) | Should -BeLike "*IndexOptimize - ALL_DATABASES"           
        }
    }
}

Describe "Security Configuration" {
    Context "$SqlInstance`: Test and verify the SPN configuration." {
        @(Test-DbaSpn -ComputerName $SqlInstance).ForEach{
            $ThisSet = ($PSItem).IsSet
            It "Testing the SPN settings of the instance $($PSItem.RequiredSPN)" {
                $ThisSet | Should -Be $true -Because "We really would like the SPN configuration to be valid"
            }
        }
    }
    Context "$SqlInstance`: SQL Management Group Membership in Local Administrators" {
        $MatchCount = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { (Get-LocalGroupMember -Group "Administrators" -Member $using:SQLManagement | Measure-Object).Count } 

        It "$SqlInstance`: Testing to see if SQL Management Group in a member of the Local Administrators group" {
            $MatchCount | Should -BeGreaterOrEqual 1 -Because "We want SQL Management Group as a member of the Local Administrators group"
        }
    }
    Context "$SqlInstance`: Sysadmin fixed server role members" {
        $GroupMembers = Get-DbaServerRoleMember -SqlInstance "$SqlInstance\$InstanceName" -ServerRole sysadmin 

        It "$SqlInstance`: Testing to see if $SQLManagement in a member of the sysadmin server role" {
            $GroupMembers.Name | Where-Object { $_ -eq $SQLManagement } | Should -Contain $SQLManagement
        }

        It "$SqlInstance`: Testing to see if $DbEngineers in a member of the sysadmin server role" {
            $GroupMembers.Name | Where-Object { $_ -eq $DbEngineers } | Should -Contain $DbEngineers
        }
    }
    Context "$SqlInstance`: sa SQL login should be disabled" {
        $logins = Get-DbaLogin -SqlInstance "$SqlInstance\$InstanceName" | Where-Object { $_.Name -eq 'sa' }
        It "$SqlInstance`: Test to see if sa is disabled" {
            $logins.IsDisabled | Should -Be $true
        }
    }
}

Describe "Instance Startup Trace Flags" {
    Context "$SqlInstance`: Test to see if trace flags are set if < 2017 1117/1118/3226 else if 2017+ just 3226" {
        $ThisSqlInstance = Connect-DbaInstance -SqlInstance "$SqlInstance\$InstanceName" 
        $serverversion = $ThisSqlInstance.Version
        $traceflags = (Get-DbaStartupParameter -SqlInstance "$SqlInstance\$InstanceName").TraceFlags.Split(',')

        if ( $serverversion.major -lt 13 ) {
            It 'Before SQL 2016, TF 1117' {
                $traceflags | Should -Contain '1117' 
            }
            It 'Before SQL 2016, TF 1118' {
                $traceflags | Should -Contain '1118' 
            }
        } #end if lt 13      
        It 'All Versions should TF 3226 enabled' {
            $traceflags | Should -Contain '3226' 
        }
        It 'Find any non-standard trace flags' {
            #pulling the TFs again in the event the previous tests added one
            $traceflags = (Get-DbaStartupParameter -SqlInstance "$SqlInstance\$InstanceName").TraceFlags.Split(',')
            $traceflags | Should -BeIn @('1117', '1118', '3226') -Because "There are non-standard trace flags enabled"
        }
    }
}

Describe "Test for Instance Level Settings" {
    Context "$SqlInstance`: Memory Configuration" {
        $Memory = (Test-DbaMaxMemory -SqlInstance "$SqlInstance\$InstanceName")
        $RecommendedMB = $Memory.RecommendedMB
        $SqlMaxMB = $Memory.SqlMaxMB
        It "Checking the Max Memory setting for the instance" {
            $SqlMaxMB | Should -Be $RecommendedMB
        }  
    }
    Context "$SqlInstance`: MaxDOP Configuration" {
        $dop = Test-DbaMaxDop -SqlInstance "$SqlInstance\$InstanceName"
        $DopInstance = ($dop | Where-Object { $_.Database -eq 'n/a' })
        $DopDatabase = ($dop | Where-Object { $_.Database -ne 'n/a' })

        It "$SqlInstance`: Checking if Instance MAXDOP exceeds the number of cores in a NUMA node" {
            $DopInstance.CurrentInstanceMaxDop | Should -BeLessOrEqual $NumberOfPhysicalCoresPerCPU -Because "we do not want to span a NUMA Node. Resource: Instance. Suggested value: $($PSItem.RecommendedMaxDop)"
        }
        @($DopDatabase).foreach{
            It "$SqlInstance`: Checking if database: $($PSItem.Database) MAXDOP exceeds the number of cores in a NUMA node" {
                $PSItem.DatabaseMaxDop | Should -BeLessOrEqual $NumberOfPhysicalCoresPerCPU -Because "We do not want to span a NUMA Node. Resource: $($PSItem.Database). Suggested value: $($PSItem.RecommendedMaxDop)"
            }
        }    
    }

    $configuration = Get-DbaSpConfigure -SqlInstance "$SqlInstance\$InstanceName"
    Context "$SqlInstance`: DAC Configuration" {
        It "Remote Admin Connections - DAC" {
            $configuration.Name | Should -Contain 'RemoteDacConnectionsEnabled'
        }  
    }
    Context "$SqlInstance`: Optimize for Adhoc workloads" {
        It "Optimize for Adhoc workloads" {
            $configuration.Name | Should -Contain 'OptimizeAdhocWorkloads'
        }  
    }
    Context "$SqlInstance`: AgentXPs Enabled" {
        It "AgentXPs Enabled" {
            $configuration.Name | Should -Contain 'AgentXPsEnabled'
        }  
    }
    Context "$SqlInstance`: Database Mail Enabled" {
        It "DatabaseMailEnabled Enabled" {
            $configuration.Name | Should -Contain 'DatabaseMailEnabled'
        }  
    }
    Context "$SqlInstance`: Database Mail Configuration" {
        #Enable Database mail
        @(Get-DbaDbMailAccount -SqlInstance "$SqlInstance\$InstanceName").ForEach{
            It "$SqlInstance`: Testing for valid Database Mail configuration" {
                $PSItem.EmailAddress | Should -Match '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$' -Because "There should be a valid email address set"
            }
        }
    }
    Context "$SqlInstance`: Testing for valid network certificate." {
        @(Get-DbaNetworkCertificate -ComputerName "$SqlInstance\$InstanceName").ForEach{
            It 'Should return a valid certificate from the SQL Server Network Configuration' {
                $psitem.Expires | Should -BeGreaterThan (Get-Date) -Because "Certificate should not be expired"
            }
            It 'Should contain a DNS name that is a short name' {
                ($psitem.DnsNameList.Unicode) | Should -Contain "$SqlInstance" -Because "Certificate should contain a DNS shortname for network connection"
            }
            It 'Should contain a DNS name that is a FQDN' {
                ($psitem.DnsNameList.Unicode) | Should -Contain ([System.Net.Dns]::GetHostByName($SqlInstance).Hostname) -Because "Certificate should contain a DNS FQDN for network connection"
            }
        }
    }
}

Describe "TempDB Configuration" {
    $TempDBTest = Test-DbaTempdbConfig -SqlInstance "$SqlInstance\$InstanceName"
    Context "$SqlInstance`: TempDB should have best practice or 8 TempDB Files" {
        It "should have 8 TempDB Files on $($TempDBTest[1].SqlInstance)" {
            $Reccomended = @()
            $Reccomended += $TempDBTest[1].Recommended
            $Reccomended += 8
            $TempDBTest[1].CurrentSetting | Should -BeIn $Reccomended -Because 'This is the recommended number of tempdb files for your server'
        }
    }
    Context "$SqlInstance`: TempDB growth should be a fixed value" {
        It "TempDB growth should be a fixed value on all files" {
            $TempDBTest[2].CurrentSetting | Should -Be $TempDBTest[2].Recommended -Because 'Auto growth type should not be percent'
        }
    }
    Context "$SqlInstance`: TempDB files should not be on the system drive" {
        It "TempDB files should not be on the system drive" {
            $TempDBTest[3].CurrentSetting | Should -Be $TempDBTest[3].Recommended -Because 'You do not want the tempdb files on the same drive as the operating system'
        }
    }
    Context "$SqlInstance`: TempDB should have have no max growth" {
        It "on $($TempDBTest[4].SqlInstance)" {
            $TempDBTest[4].CurrentSetting | Should -Be $TempDBTest[4].Recommended -Because 'Tempdb files should be able to grow'
        }
    }
    Context "$SqlInstance`: TempDB files should all be the same size" {
        It "TempDB data files should all be the same size" {
            @((Get-DbaDbFile -SqlInstance "$SqlInstance\$InstanceName" -Database tempdb).Where{ $_.Type -eq 0 }.Size.Megabyte | Select-Object -Unique).Count | Should -Be 1 -Because "We want all the tempdb data files to be the same size"
        }
    }
}  

Describe "Database Settings" {
    Context "$SqlInstance`: Model Database Should Be Set to Simple" {
        @(Get-DbaDatabase -SqlInstance "$SqlInstance\$InstanceName" -Database 'model').ForEach{
            It 'Should have a recovery model set to SIMPLE' {
                $PSItem.RecoveryModel | Should -Be 'SIMPLE' -Because "We want to use the SIMPLE recovery model for newly databases created."
            }
        } 
    }

    $files = Get-DbaDbFile -SqlInstance "$SqlInstance\$InstanceName" -Database 'model'
    Context "$SqlInstance`: Model Database Should have data file growth set to 512MB or greater" {      
        $mdffile = $files | Where-Object { $_.ID -eq "1" }
        It 'Should have a data file growth size set to greater than 512MB' {
            $mdffile.growth | Should -BeGreaterOrEqual 524288 -Because 'we want the mdf to have a 1GB expansion by default'
        }  
    }
    Context "$SqlInstance`: Model Database Should have log file growth set to 512MB or greater" {
        $logfile = $files | Where-Object { $_.TypeDescription -eq "LOG" }
        It 'Should have a log file growth size set to greater than 512MB' {
            $logfile.growth | Should -BeGreaterOrEqual 524288 -Because 'we want the log to have a 1GB expansion by default'
        }
    }
}

Describe "Windows Settings" {
    Context "$SqlInstance`: High Performance Powerplan" {        
        $dbapp = Test-DbaPowerPlan -ComputerName $SqlInstance
        try {
            It "Checking if the Windows PowerPlan is set to High Performance" {
                $dbapp.isBestPractice | Should -Be $true 
            }
        }
        catch {
            Write-Warning -Message "Setting Powerplan to High Performance"
            if ( $remediate ) {
                Set-DbaPowerPlan -ComputerName $SqlInstance -PowerPlan "High Performance"
            }
        }      
    }
    Context "$SqlInstance`: Page File Settings" {
        $PageFile = Get-DbaPageFileSetting -ComputerName $SqlInstance
        It "Checking if the page file location is on F" {
            $PageFile.FileName | Should -BeLike "F:\*"
        }
        It "Checking if the page file is system managed" {
            $PageFile.AutoPageFile | Should -Be $false
        }
        It "Checking if the page file size is statically set to 8GB" {
            $PageFile.InitialSize | Should -Be $PageFile.MaximumSize
        }
    }

    #Perform Volume Maintenance
    #NOTIMPLEMENTED

    #Lock Pages in Memory
    #NOTIMPLEMENTED
}

#Query store configuration of >= 2016
#Get-DbaQueryStoreConfig -SqlInstance "DCP-VSQL-01"
#UNABLE TO QUERY MODEL's QS configuration
<#Context "Testing for valid Query Store Configuration on Model Database"{
      Describe "$server Valid Query Store Configration for Model Database"{
        @(Get-DbaQueryStoreConfig -SqlInstance $server -Database 'Model').ForEach{
          $server = Connect-DbaInstance -SqlInstance $server 
          $serverversion = $server.Version
    
          if ( $serverversion.major -ge 13 ){
            It "Should have an OPERATION_MODE of ReadWrite on database $($psitem.Database)"{
              $psitem.ActualState | Should -Be 'ReadWrite' -Because "We would like to have Query Store turned on if the instance and database supports it"
            }
            It "Should have an CLEANUP_POLICY = STALE_QUERY_THRESHOLD_DAYS = 367 on database $($psitem.Database)"{
              $psitem.StaleQueryThresholdInDays | Should -Be 367 -Because "CLEANUP_POLICY = STALE_QUERY_THRESHOLD_DAYS = 367"
            }        
            It "Should have an DATA_FLUSH_INTERVAL_SECONDS = 9300 on database $($psitem.Database)"{
              $psitem.DataFlushIntervalInSeconds | Should -Be 9300 -Because "DATA_FLUSH_INTERVAL_SECONDS = 9300"
            }        
            It "Should have an INTERVAL_LENGTH_MINUTES = 30 on database $($psitem.Database)"{
              $psitem.StatisticsCollectionIntervalInMinutes | Should -Be 30 -Because "INTERVAL_LENGTH_MINUTES = 30"
            }        
            It "Should have an MAX_STORAGE_SIZE_MB = 1000 on database $($psitem.Database)"{
              $psitem.MaxStorageSizeInMB | Should -Be 1000 -Because "MAX_STORAGE_SIZE_MB = 1000"
            }        
            It "Should have an QueryCaptureMode set to Auto on database $($psitem.Database)"{
              $psitem.QueryCaptureMode | Should -Be 'Auto' -Because "QUERY_CAPTURE_MODE set to Auto"
            }        
          }
        }
      }
  }
  #>
#>