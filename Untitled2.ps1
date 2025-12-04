#Requires -Modules @{ ModuleName="dbatools"; RequiredVersion="1.1.143" }
#Requires -RunAsAdministrator

# Remove-Module dbatools 

Import-Module dbatools -Force -Verbose

Uninstall-Module dbatools -AllVersions -Force
Install-Module dbatools -Force

Import-Module dbatools -Verbose
(Get-Command -Module dbatools).Count