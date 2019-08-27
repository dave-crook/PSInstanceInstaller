
function Register-Msx{
    Param(
        [Parameter(Mandatory=$True)]   [String] $MSXServer, 
        [Parameter(Mandatory=$True)]   [String] $TargetServer,
        [Parameter(Mandatory=$True)]   [String] $ServiceAccount,
        [Parameter(Mandatory=$True)]   [String] $ActiveDirectoryDomain,
        [String]   $InstanceName = "MSSQLSERVER"
    ) 

    try {
        Write-Verbose "Attempting to register target $TargetServer on MSX $MSXServer."

        $TargetFQDN = ([System.Net.Dns]::GetHostByName($TargetServer)).HostName
        $MSXFQDN = ([System.Net.Dns]::GetHostByName($MSXServer)).HostName
        
        #Test to ensure SQL Server Service account is in the correct group. This is used for access to the MSX. 
        if ( !(Test-ServiceAccountToGroup -ServiceAccountName $ServiceAccount -SqlServiceGroup $SqlServiceGroup) ){
            Set-ServiceAccountToGroup -ServiceAccountName $ServiceAccount -SqlServiceGroup $SqlServiceGroup 
        }

        Write-Verbose "Searching for login $SqlServiceGroup on MSX $MSXServer."
        $SqlLogin = Get-DbaLogin -SqlInstance $MSXServer -Login "$ActiveDirectoryDomain\$SqlServiceGroup"

        if (!$SqlLogin){
            Write-Verbose "Login $SqlServiceGroup NOT found on MSX $MSXServer. Adding SQL Service Group to MSX Server"

            if ( Get-DbaServerTrigger -SqlInstance $msxserver | Where-Object { $_.Name -eq 'TrgEnforceSecurity' } ){
                $reenable = $True
                Invoke-DbaQuery -SqlInstance $MSXServer -Query 'DISABLE TRIGGER [TrgEnforceSecurity] ON ALL SERVER'
            }

            Add-SqlLogin -ServerInstance $MSXServer -LoginName "$ActiveDirectoryDomain\$SqlServiceGroup" -LoginType "WindowsGroup" -DefaultDatabase "MSDB" -GrantConnectSql
            $SqlLogin = Get-DbaLogin -SqlInstance $MSXServer -Login "$ActiveDirectoryDomain\$SqlServiceGroup"

            if ($reenable){
                Invoke-DbaQuery -SqlInstance $MSXServer -Query 'ENABLE TRIGGER [TrgEnforceSecurity] ON ALL SERVER'
            }
        }
        else{
            Write-Verbose "Login $SqlServiceGroup found on MSX $MSXServer."
        }

        $Database = Get-SqlDatabase -ServerInstance $MSXServer -Name "MSDB"

        #check to see if the user is in the databases
        $User = $Database.Users[$SqlLogin.Name]

        #Check to see if the 
        if (!$User){
            Write-Verbose "Creating database user for $($SqlLogin.Name)"
            $User = New-Object ("Microsoft.SqlServer.Management.SMO.User") ($Database, $SqlLogin.Name)
            $User.Login = $login
            $User.Create()    
        }

        $TargetServersRole = $Database.Roles | Where-Object { $_.Name -eq 'TargetServersRole' }
        
        if ( $TargetServersRole.EnumMembers() -notcontains $SqlLogin.Name ){
            Write-Verbose "Adding $($User.Name) to $($TargetServersRole.Name)"
            $TargetServersRole.AddMember($User.Name)
        }
        else{
            Write-Verbose "User $($SqlLogin.Name) currently in role $($TargetServersRole.Name)"
        }

        # enlist target server in MSX
        #$sql = "EXEC msdb.dbo.sp_msx_enlist @msx_server_name = '$MSXFQDN', @location = N''"
        $sql = "EXEC msdb.dbo.sp_msx_enlist @msx_server_name = '$MSXServer', @location = N''"
        Invoke-DbaQuery -SqlInstance $TargetFQDN -Database "MSDB" -Query $sql

        # push central jobs to target server
        Invoke-DbaQuery -SqlInstance $MSXFQDN -Database "DBA" -Query "EXEC DBA.dbo.CreateTargetSQLAgentJobs @TargetServer= '$TargetServer' " 
    }
    catch {
        Write-Error $_.Exception.Message
    }
}
<#
$ServerName = 'DC2-D-VSQL-48A'
$ServiceAccount = "POLSINELLI\SA-DC2-D-VSQL-48"
Register-Msx -MSXServer $SQLManagementServer -TargetServer $ServerName -ServiceAccount $ServiceAccount
#>