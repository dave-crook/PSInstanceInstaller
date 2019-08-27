#$MasterKey = ConvertTo-SecureString -String "Where'sMyTowel?" -AsPlainText -Force
#$KeePassEntryGroupPath  = 'NetworkTeamPasswordVault/General/SVC Accounts/Sql Svs Accounts'
$InstallationCredential = Get-Credential -Message 'This is the account the installation will run as on the target SQL Server. Most likely your administrator login'

$MasterKey = ConvertTo-SecureString -String "?ntadmin4" -AsPlainText -Force
$KeePassEntryGroupPath  = 'CentinoLab/SQL'
$DatabaseProfileName = 'CentinoLab/SQL'

$InstancePath = 'S:\SYSTEM'
$DataPath = 'D:\DATA'
$LogPath = 'L:\LOGS'
$TempPath = 'T:\TEMPDB'
$BackupPath = 'S:\BACKUPS'


$logfile = "output.log"

$ActiveDirectoryDomain = "LAB"
$OU = "OU=SQL Servers,OU=Servers,DC=POLSINELLI,DC=LAW"

#Group to be added to sysadmin during installation
$AdminAccount = 'LAB\Database Engineers'
#$SQLAdministrators = "$ActiveDirectoryDomain\Database Engineers"
$SQLManagement = "$ActiveDirectoryDomain\SQL Management"

$SQLManagementServer = "DCP-VSQL-01"
$SqlServersGroup = "SQL Servers"
# the SQL Service account will be added to this group. This group is used for access to the CMS and MSX.
$SqlServiceGroup = "SQL Server Service Accounts"
# the Cluster computer account will be added to this group. This group is used for access to the fileshare witness.
$ClusterServiceGroup = "SQL Cluster Computer Accounts"

$InstallRoot = "\\DC1\INSTALLS"

#Location of installation files for each version of SQL Server. Each of these is currently the latest SP we've standardized on.
$InstallationSources = @{
    2012 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2012_enterprise_edition_with_sp_3_x64_dvd_7286819"
    2014 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2014_enterprise_edition_with_service_pack_2_x64_dvd_8962401"
    2016 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2016_enterprise_with_service_pack_1_x64_dvd_9542382"
    2017 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2017_enterprise_x64_dvd_11293666"
}


#Location of update sources for each version of SQL Server. Directory should contain the latest CU we've standardized on.
$UpdateSources = @{
    2012 = "$InstallRoot\SQL Server Update Files\2012Updates"
    2014 = "$InstallRoot\SQL Server Update Files\2014Updates"
    2016 = "$InstallRoot\SQL Server Update Files\2016Updates"
    2017 = "$InstallRoot\SQL Server Update Files\2017Updates"  
}
