# PSInstanceInstaller

Documentation and stuff can go here...

# Installation Prerequisites
To use PsInstanceInstaller the workstation that you are performing the installatoin from will need the following 

1. [Git Desktop](https://desktop.github.com/) - Not required but will make life easier on updating the repository
1. [Installation Code](https://github.com/nocentino/PSInstanceInstaller) - A copy of this repositoriy pulled locally
1. PowerShell 5.1 - included in Windows 2012R2+
1. [dbatools](https://dbatools.io/) - Open Powershell 5.1 in administrator mode
    1. New installation `Install-Module dbatools`
    1. Update existing installlation `Update-Module dbatools`
1. Pester 4.8.1+ [Follow the directions here to update Pester.](https://github.com/pester/Pester/wiki/Installation-and-Update#installing-from-psgallery-windows-10-or-windows-server-2016) There is a version of Pester included with Windows, but its super old and needs to be updated. s

# Overview of the Installation Process

The installation process is driven from the script `Install-SqlServer.ps1`. I plan on converting this to a module but while we're rapidly developing this it will remain a script.

Each of the following aligns with a code `region` in the `Install-SqlServer.ps1`

1. Requires - Pester 4.8.1, dbatools 1.0.38, and the enviroment running the script needs to be run as administrator, VSCode, ISE or PowerShell prompt.
1. Dot Sourcing of functions - currently all custom function implementations are in ps1 files in the directory and need to be imported. 
1. Installation variables - This is where you'll set the settings specific to the server you're installating
    1. `$version` - This is an integer for the version of SQL you're installtion. `2012`, `2014`, `2016`, `2017` are accepted.
    1. `$SqlInstance` - The computer name of the server that you're installing SQL server on.
    1. `$Features` - Array of Features to install. Options are SQLEngine, AS, RS, IS and others. Same as those if you where doing this at the command line. See [this](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-2017#Feature) for all of the options available. For additional installatoin configuration parameters, for example if you want to add an Analysis Services Service account, that will need to be added to the `-Configuration` Hash Table around line 61. 
    ```
    @{ UpdateSource = $UpdateSources[$Version]; 
       ASSVCACCOUNT = 'svcAccountName';  
       ASSVCPASSWORD = 'ASecureAPassword'; 
       } 
    ```
    1. `$ServiceAccount` - The service account for the Database Engine and the SQL Server Agent Services.
    1. `$password` - the service account's password retrieved from KeePass
    1. `$svcPassword` - the service account's password retrieved from KeePass, converted to a `Secure-String`
    1. `$EngineCredential` - A `PSCredential` used to the Engine and Agent services.
    1. `$InstallationCredential` - 

1. Pre-flight Checks
1. Installation Execution
1. Instance Configuration
1. Post Installation Checks