
$ServerList = (Invoke-DbaQuery -SqlInstance 'LSP-VSQL-01' -Database 'DBA' -Query "select ServerName from [dbo].[vw_ActiveServerList] WHERE Environment = 'Prod'").ServerName

foreach ($server in $ServerList){
    Invoke-Pester -Script @{ Path = '.\Test-PostInstallationChecks.ps1' ; Parameters = @{ SqlInstance = $server; } } -PassThru | Format-Pester -Path . -Format HTML
}
