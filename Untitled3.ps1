Remove-Module dbatools

Remove-Module -FullyQualifiedName @{ModuleName = "dbatools"; ModuleVersion = "2.1.4"}

Import-Module dbatools -RequiredVersion "2.1.4"
Invoke-DbaQuery -SqlInstance dcp-vsql-150 -Database dba -Query "select * from sys.databases"

$modules = Get-Module dbatools -ListAvailable

$modules[0] | Uninstall-Module

Get-Module 'dbatools' | where {([string]($_.Version)) -eq "2.1.4"} | Remove-Module

Get-InstalledModule -Name dbatools

