#Requires -Modules @{ ModuleName="pester"; ModuleVersion="4.8.1" }
#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.0.23" }

<#Requires -RunAsAdministrator#>

. .\Import-EnvironmentSettings.ps1
. .\Get-KeePassPassword.ps1
. .\Test-AdCredential.ps1

$Version = 2017
$SqlInstance = 'DBASQL1'
$Features = @('ENGINE')
$ServiceAccount = "SA-DSCSQL"
$password = Get-KeePassPassword -UserName $ServiceAccount -MasterKey $MasterKey -DatabaseProfileName $DatabaseProfileName -pKeePassEntryGroupPath $KeePassEntryGroupPath 
$svcPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)    

$result = Invoke-Pester -Script @{ 
    Path = '.\Test-PreInstallationChecks.ps1' ; 
    Parameters = @{
        SqlInstance = $SqlInstance;  
        EngineCredential = $EngineCredential; 
        InstallationCredential = $InstallationCredential; 
        InstallationSource =  $InstallationSources[$Version];
        UpdateSource =  $UpdateSources[$Version];
    }
}  -PassThru

if ( $result.FailedCount -gt 0 ){
    Write-Error "Preflight checks failed please ensure pester test passes" -ErrorAction Stop
}

Install-DbaInstance `
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
    -Confirm:$false `
    -Verbose

Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ Server = $SqlInstance; } }
