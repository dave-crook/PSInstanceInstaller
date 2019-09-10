
$SqlInstances = (Invoke-DbaQuery -SqlInstance 'LSP-VSQL-01' -Database 'DBA' -Query "select ServerName from [dbo].[vw_ActiveServerList]").ServerName

foreach ($SqlInstance in $SqlInstances){
    Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $SqlInstance; } } -PassThru | Format-Pester -Path . -Format HTML
}

#TempDB and TF3226