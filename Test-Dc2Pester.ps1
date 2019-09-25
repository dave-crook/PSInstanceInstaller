#Load environment specific settings
. .\Import-Dc2EnvironmentSettings.ps1

$SqlInstances = (Invoke-DbaQuery -SqlInstance 'DCP-VSQL-01' -Database 'DBA' -Query "select top 10 ServerName from [dbo].[vw_ActiveServerList]").ServerName

$TestNames = @()
$TestNames += "Management Services" 
$TestNames += "SQL Agent Configuration" 
$TestNames += "Ola Hallengren SP and Job Configuration" 
$TestNames += "Security Configuration" 
$TestNames += "Instance Startup Trace Flags" 
$TestNames += "Test for Instance Level Settings" 
$TestNames += "TempDB Configuration" 
$TestNames += "Database Settings"
$TestNames += "Windows Settings"

foreach($TestName in $TestNames){
    Invoke-Pester -Script @{ 
        Path = '.\Test-PostInstallationChecks.ps1' ; 
        Parameters = @{ 
            SqlInstance = $SqlInstances; 
        } 
    } -PassThru -TestName $TestName | Format-Pester -Path . -Format HTML -GroupResultsBy  Result -BaseFileName  $TestName  
}

