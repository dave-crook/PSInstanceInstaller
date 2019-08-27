. .\Import-EnvironmentSettings.ps1
. .\Get-KeePassPassword.ps1

$SqlInstance = 'DBASQL1'
$Version = 2017
$Features = @('ENGINE','FULLTEXT')
$ServiceAccount = "SA-DSCSQL"

$password = Get-KeePassPassword -UserName $ServiceAccount -MasterKey $MasterKey -DatabaseProfileName $DatabaseProfileName -pKeePassEntryGroupPath $KeePassEntryGroupPath 
$svcPassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$EngineCredential = $AgentCredential = New-Object System.Management.Automation.PSCredential("$ActiveDirectoryDomain\$ServiceAccount", $svcPassword)

#TODO: Test AD Credential

Write-Output "SQL Server: $SqlInstance Service Account: $ServiceAccount Password: $password"

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
    -PerformVolumeMaintenanceTasks -Restart -Confirm:$false -Verbose
