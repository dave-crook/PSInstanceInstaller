#Credential Information
$MasterKey = ConvertTo-SecureString -String "1Changed!for-Saad" -AsPlainText -Force
$KeePassEntryGroupPath  = 'NetworkTeamPasswordVault/General/SVC Accounts/Sql Svs Accounts'
$DatabaseProfileName = 'NetworkTeamPasswordVault'

#Drive Path Information
$InstancePath = 'C:\Program Files\Microsoft SQL Server'
$DataPath = 'F:\data'
$LogPath = 'G:\log'
$TempPath = 'D:\tempDb'
$BackupPath = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup'

#Log file 
$logfile = "output.log"

#Active Directory Information
$ActiveDirectoryDomain = "POLSINELLI"
$OU = "OU=SQL Servers,OU=Servers,DC=POLSINELLI,DC=LAW"

#MSX and CMS
$SQLManagementServer = 'DCP-VSQL-150'
$CMDBServer = 'DCP-VSQL-150'

#The SQL Service account will be added to this group. This group is used for access to the CMS and MSX.
$SqlServiceGroup = "SQL Server Service Accounts"

#Group for SQL Server Computer Accounts
$SqlServersGroup = "SQL Servers"

#Group to be added to sysadmin during installation
$AdminAccount = "$ActiveDirectoryDomain\Database Engineers"

#Additional groups to be added to syadmins and local administrators
$SQLManagement = "$ActiveDirectoryDomain\SQL Management"

$NumberOfPhysicalCoresPerCPU = 4
$SmtpRelay = 'relay.polsinelli.com'

#Location of installation files for each version of SQL Server. Each of these is currently the latest SP we've standardized on.
$InstallRoot = "\\DCP-VSQL-150\INSTALLS"

$InstallationSources = @{
    2012 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2012_enterprise_edition_with_service_pack_4"
    2014 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2014_enterprise_edition_with_service_pack_3"
    2016 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2016_enterprise_with_service_pack_2"
    2017 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2017_enterprise"
    2019 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2019_enterprise"
    2022 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2022_enterprise"
    2025 = "$InstallRoot\SQL Server Installation Files\en_sql_server_2025_enterprise"
}

#Location of update sources for each version of SQL Server. Directory should contain the latest CU we've standardized on.
$UpdateSources = @{
    2012 = "$InstallRoot\SQL Server Update Files\2012Updates"
    2014 = "$InstallRoot\SQL Server Update Files\2014Updates"
    2016 = "$InstallRoot\SQL Server Update Files\2016Updates"
    2017 = "$InstallRoot\SQL Server Update Files\2017Updates"  
    2019 = "$InstallRoot\SQL Server Update Files\2019Updates"  
    2022 = "$InstallRoot\SQL Server Update Files\2022Updates"  
    2025 = "$InstallRoot\SQL Server Update Files\2025Updates"  
}
