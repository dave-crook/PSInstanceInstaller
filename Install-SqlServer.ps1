#Requires -Modules @{ ModuleName="pester"; ModuleVersion="4.8.1" }
#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.0.23" }
#Requires -RunAsAdministrator

. .\Import-EnvironmentSettings.ps1
. .\Get-KeePassPassword.ps1
. .\Test-AdCredential.ps1
. .\Invoke-SqlConfigure.ps1
. .\Register-Msx.ps1
. .\Install-SqlCertificate.ps1
. .\Test-ServiceAccountToGroup.ps1
. .\Set-ServiceAccountToGroup.ps1
. .\Set-PageFile.ps1

$Version = 2017
$SqlInstance = 'DBASQL1'
$Features = @('ENGINE')
$ServiceAccount = "SA-DSCSQL"
$password = Get-KeePassPassword -UserName $ServiceAccount -MasterKey $MasterKey -DatabaseProfileName $DatabaseProfileName -pKeePassEntryGroupPath $KeePassEntryGroupPath 
$svcPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)    

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
    -Configuration @{ UpdateSource = $UpdateSources[$Version] } `
    -PerformVolumeMaintenanceTasks `
    -Restart `
    -Confirm:$false

$InstallationResult

if ( -Not ($InstallationResult.Successful )){
    Write-Output "FAILED: Installation on $SqlInstance failed. Examine the installation log at $($InstallationResult.LogFile) on the target server." -ErrorAction Stop
}

Invoke-SqlConfigure -SqlInstance $SqlInstance 

Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $SqlInstance; } }
