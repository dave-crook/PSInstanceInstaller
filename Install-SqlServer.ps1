#Requires -Modules @{ ModuleName="pester"; ModuleVersion="4.8.1" }
#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.0.38" }
#Requires -RunAsAdministrator


#region Dot sourcing of functions
$Environment = 'DC2'
. .\Import-EnviromentSettings.ps1 -DataCenter $Environment
. .\Get-KeePassPassword.ps1
. .\Test-AdCredential.ps1
. .\Invoke-SqlConfigure.ps1
. .\Register-Msx.ps1
. .\Install-SqlCertificate.ps1
. .\Test-ServiceAccountToGroup.ps1
. .\Set-ServiceAccountToGroup.ps1
. .\Set-PageFile.ps1
. .\Add-SentryOne.ps1
#endregion

#region Installation Variables
$Version = 2017
$SqlInstance = 'DCD-VSQL-55'
$Features = @('ENGINE')
$Configuration = @{ UpdateSource = $UpdateSources[$Version]; BROWSERSVCSTARTUPTYPE = "Automatic"}
$ServiceAccount = "SA-$SqlInstance"
$InstallationCredential = $InstallationCredential = Get-Credential -Message 'This is the account the installation will run as on the target SQL Server. Most likely your administrator login'
$password = Get-KeePassPassword -UserName $ServiceAccount -MasterKey $MasterKey -DatabaseProfileName $DatabaseProfileName -pKeePassEntryGroupPath $KeePassEntryGroupPath 
$svcPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)    
#endregion

#region Pre-flight checks
$PreflightChecksResult = Invoke-Pester -Script @{ 
    Path = '.\Test-PreInstallationChecks.ps1' ; 
    Parameters = @{
        SqlInstance = $SqlInstance;  
        EngineCredential = $EngineCredential; 
        InstallationCredential = $InstallationCredential; 
        InstallationSource =  $InstallationSources[$Version];
        UpdateSource =  $UpdateSources[$Version];
    }
}  -PassThru 

if ( $PreflightChecksResult.FailedCount -gt 0 ){
    Write-Output "FAILED: Preflight checks failed please ensure pester test passes" -ErrorAction Stop
}
#endregion

#region Installation Execution
$InstallationResult = Install-DbaInstance `
    -SqlInstance $SqlInstance `
    -Path $InstallationSources[$Version] `
    -Version $Version `
    -Feature $Features `
    -InstancePath $InstancePath `
    -DataPath $DataPath `
    -LogPath $LogPath `
    -TempPath $TempPath `
    -BackupPath $BackupPath `
    -AdminAccount $AdminAccount `
    -EngineCredential $EngineCredential `
    -AgentCredential $AgentCredential `
    -Credential $InstallationCredential `
    -Configuration $Configuration `
    -PerformVolumeMaintenanceTasks `
    -Restart `
    -Confirm:$false -Verbose

$InstallationResult

if ( -Not ($InstallationResult.Successful )){
    Write-Output "FAILED: Installation on $SqlInstance failed. Examine the installation log at $($InstallationResult.LogFile) on the target server." -ErrorAction Stop
}
#endregion

#region Instance Configuration
Invoke-SqlConfigure -SqlInstance $SqlInstance 
#endregion

#region Post installation checks
Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $SqlInstance; } }
#endregion