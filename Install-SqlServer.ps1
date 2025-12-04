#Requires -Modules @{ ModuleName="pester"; ModuleVersion="4.8.1" }
#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.1.143" }
#Requires -RunAsAdministrator

##### CHANGE LOCAL DIRECTORY TO D:\INSTALLS\PSINSTANCEINSTALLER
CD D:\INSTALLS\PSINSTANCEINSTALLER

# NOTE - MANUALLY CHECK FOR BACKSLASHES IN SQL SERVICE ACCOUNT PASSWORDS.  IT BREAKS EVERYTHING.

Import-Module sqlserver
Import-Module dbatools 

#region Dot sourcing of functions
$Environment = 'DC2'
. .\Import-EnviromentSettings.ps1 -DataCenter $Environment
. .\Get-KeePassPassword.ps1
. .\Test-AdCredential.ps1
. .\Invoke-SqlConfigure.ps1
. .\Install-SqlCertificate.ps1
. .\Test-ServiceAccountToGroup.ps1
. .\Set-ServiceAccountToGroup.ps1
. .\Set-PageFile.ps1
. .\InstallSql2025.ps1
#endregion

#region Installation Variables
$Version = 2025
$SqlInstance = 'DCP-VSQL-217'
$Features = @('ENGINE')

$ServiceAccount = "SA-$SqlInstance"  # non-AG installs
$UpdateSource = $UpdateSources[$Version]
$Configuration = @{ UpdateSource = $UpdateSource; BROWSERSVCSTARTUPTYPE = "Disabled"}
$MediaPath = $InstallationSources[$Version]

# uncomment below for non-standard collation (needed for intellistat, interaction)
#$Configuration = @{ UpdateSource = $UpdateSources[$Version]; BROWSERSVCSTARTUPTYPE = "Disabled"; SqlCollation = "Latin1_General_CI_AI"}

$InstallationCredential = Get-Credential -UserName "$env:USERDOMAIN\$env:USERNAME" -Message 'Enter your credential information...'
$password = Get-KeePassPassword -UserName $ServiceAccount -MasterKey $MasterKey -DatabaseProfileName $DatabaseProfileName -pKeePassEntryGroupPath $KeePassEntryGroupPath 
$svcPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)    

# enable CredSSP for remote management.  this is necessary for SQLAgent service configuration.
Enable-WSManCredSSP -Role Client -DelegateComputer $SqlInstance -Force

# run this on the target server to enable CredSSP for remote management.  RDP into the server and run this command until it can be part of standard Windows install.
# Enable-WSManCredSSP -Role Server -Force

#endregion

#region Pre-flight checks - (problem validating credentials just started)
$PreflightChecksResult = Invoke-Pester -Script @{ 
    Path = '.\Test-PreInstallationChecks.ps1' ; 
    Parameters = @{
        SqlInstance = $SqlInstance;  
        EngineCredential = $EngineCredential; 
        InstallationCredential = $InstallationCredential; 
        InstallationSource = $MediaPath;
        UpdateSource =  $UpdateSource;
    }
}  -PassThru 

if ( $PreflightChecksResult.FailedCount -gt 0 ){
    Write-Output "FAILED: Preflight checks failed please ensure pester test passes" -ErrorAction Stop
}

#region Install SQL Server

# Uninstall SQL 2025 
$uninstallExit = UninstallSqlInstance -Version $Version -MediaPath $MediaPath -SqlInstance $SqlInstance
if ( -Not ($uninstallExit -eq 0 )){
    Write-Output "FAILED: Uninstallation on $SqlInstance failed. Examine the uninstallation log at $($uninstallExit.LogFile) on the target server." -ErrorAction Stop
}
Restart-Computer -ComputerName $SqlInstance -Wait -For PowerShell -Timeout 300 -Delay 2 -Force

# SQL 2025
$exitCode = InstallSql2025 `
    -Version $Version `
    -MediaPath $InstallationSources[$Version] `
    -SqlInstance $SqlInstance `
    -InstancePath $InstancePath `
    -DataPath $DataPath `
    -LogPath $LogPath `
    -TempPath $TempPath `
    -BackupPath $BackupPath `
    -SqlSysadminAccounts @('POLSINELLI\Database Engineers', 'POLSINELLI\SQL Management') `
    -EngineCredential $EngineCredential `
    -AgentCredential $AgentCredential `
    -InstallationCredential $InstallationCredential 

# Install SQL 2022 and below using dbatools
# $InstallationResult = Install-DbaInstance `
#     -SqlInstance $SqlInstance `
#     -Path $InstallationSources[$Version] `
#     -Version $Version `
#     -Feature $Features `  
#     -InstancePath $InstancePath `
#     -DataPath $DataPath `
#     -LogPath $LogPath `
#     -TempPath $TempPath `
#     -BackupPath $BackupPath `
#     -AdminAccount $AdminAccount `
#     -EngineCredential $EngineCredential `
#     -AgentCredential $AgentCredential `
#     -Credential $InstallationCredential `
#     -Configuration $Configuration `
#     -PerformVolumeMaintenanceTasks `
#     -Restart `
#     -Confirm:$false -Verbose
    
# if ( -Not ($InstallationResult.Successful )){
#     Write-Output "FAILED: Installation on $SqlInstance failed. Examine the installation log at $($InstallationResult.LogFile) on the target server." -ErrorAction Stop
# }

### run up to here, then run the install cert process below separately before continuing.

# Install cert
InstallSqlCertificate -SqlInstance $SqlInstance -InstanceName MSSQLSERVER
Restart-Computer -ComputerName $SqlInstance -Wait -For PowerShell -Timeout 300 -Delay 2
###

# continue on to configure SQL

# Configure SQL instance (run steps manually)
Invoke-SqlConfigure -SqlInstance $SqlInstance 

# Test SQL install
Remove-Module dbatools # neccessary after Invoke-SqlConfigure has been run in the session
Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $SqlInstance; } }


