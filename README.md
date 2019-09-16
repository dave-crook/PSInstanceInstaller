# PSInstanceInstaller

# Installation Prerequisites
To use `PsInstanceInstaller` the workstation that you are performing the installatoin from will need the following 

1. [Git Desktop](https://desktop.github.com/) - Not required but will make life easier on updating the repository
1. [Installation Code](https://github.com/nocentino/PSInstanceInstaller) - A copy of this repositoriy pulled locally
1. PowerShell 5.1 - included in Windows 2012R2+
1. [dbatool](https://dbatools.io/) 1.0.38 - Open Powershell 5.1 in administrator mode. Other versions may work, this is the version tested.
    1. New installation `Install-Module -Name dbatools -RequiredVersion 1.0.38`
    1. Update existing installlation `Update-Module dbatools`
1. Pester 4.8.1+ [Follow the directions here to update Pester.](https://github.com/pester/Pester/wiki/Installation-and-Update#installing-from-psgallery-windows-10-or-windows-server-2016) There is a version of Pester included with Windows, but its super old and needs to be updated. This has to be updated as Pester v3 and v4 are very differnt.

# Overview of the Installation Process

The installation process is driven from the script `Install-SqlServer.ps1`. I plan on converting this to a module but while we're rapidly developing this it will remain a script.

Each of the following bullets aligns with a code `region` in the `Install-SqlServer.ps1` script.

1. __Requires__ - Pester 4.8.1, dbatools 1.0.38, and the enviroment running the script needs to be run as administrator, VSCode, ISE or PowerShell prompt.
1. __Dot Sourcing of functions__ - currently all custom function implementations are in ps1 files in the directory and need to be imported. 
    1. `$Environment` - This is the data center you're installing to. Valid options are `DC1`, `DC2`, `LSP`. Currently the DC1 settings file and DC2 settings files are the same. This is used by the `Import-EvironmentSettings.ps1` script to load the data center specific installation variables. Things like domain name, file paths for SQL installation files and updates.
1. __Installation variables__ - This is where you'll set the settings specific to the server you're installating
    1. `$version` - This is an integer for the version of SQL you're installation. `2012`, `2014`, `2016`, `2017` are accepted.
    1. `$SqlInstance` - The computer name of the server that you're installing SQL server to.
    1. `$Features` - Array of Features to install. Options are `SQLEngine`, `AS`, `RS`, `IS` and others. Same as those if you where doing this at the command line. See [this](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-2017#Feature) for all of the options available. 
    1. `$Configuration` - For additional install options that aren't surfaced as parameters in the dbatools cmdlet, they can be added to this Hash Table around line 61. In the example below, I'm setting the Update Source for patches and the Browser to Automatic. See [this](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-2017#Feature) for all of the available options available.     
        ```
        $Configuration = @{ UpdateSource = $UpdateSources[$Version]; BROWSERSVCSTARTUPTYPE = "Automatic"}
        ```      
    1. `$ServiceAccount` - The service account for the Database Engine and the SQL Server Agent Services.
    1. `$InstallationCredential` - This is YOUR login. You will be prompted to enter your username and password. Use the DOMAIN\USERNAME format.
    1. `$password` - the service account's password retrieved from KeePass
    1. `$svcPassword` - the service account's password retrieved from KeePass, converted to a `Secure-String`
    1. `$EngineCredential` - A `PSCredential` used to the Engine and Agent services.

1. __Pre-flight Checks__ - a Pester test that checks to ensure the server is online, the service account it valid, the required drives are online and available, the installation share exists, and the update sources directory exists. 
1. __Installation Execution__ - this is the parameterized dbatools cmdlet to install SQL Server. Generally this shouldn't need to be edited as all parameters are set in the `Installation Variables` code region
1. __Instance Configuration__ - This is the post instance configuration tasks. The following items are performed
    1. Page file configuration
    1. Add SQL Management to local administrators
    1. Add SQL Management to sysadmins fixed server role
    1. Disable the sa login
    1. Insert the instance into the CMDB
    1. Test and Set the SPN configuration
    1. Install sp_whoisactive
    1. Install Ola's scripts
    1. Set instance trace flages 3226 on all versions, 1117,1118,3226 on instances before 2016.
    1. Enable Remote DAC
    1. Enable Optimize for Ad-Hoc workloads
    1. Enroll in CSM and MSX
    1. Configure TempDB - Fixed growth 1GB. 8 total data files
    1. Configure Model - Fixed growth - 512MB for data and log
    1. Enable and configure Database Mail
    1. Configure SQL Server Agent Settings - History, Mail Profile, Failsafe Operators, Operators, Alerts, Deploy standard maintenance jobs
    1. Add Instance to SentryOne

1. __Post Installation Checks__ - Pester check to ensure all settings in the 'Instance Configuration' phase are actually set. And the following additional checks...
   
    1. If the instance has been online for longer than a week have maintenance jobs run
    1. Windows Power Plan set to High Performance


## Performing an Installation
1. Launch your environment as administrator
1. Set the `$Environment` variable to your datacenter location
1. Edit the `Installation Variables` Region in the `Install-SqlServer.ps1` script to the appropriate settings for your installation. Likely the only change will be `$SqlInstance`
1. Run the code regions in order, I've been high lighting the code then right click, run selection.
    1. Requires
    1. Dot Source Functions
    1. Installation Variables
    1. Pre-flight Checks
    1. Installation Execution
    1. Instance Configuration
    1. Post Installation Checks 
