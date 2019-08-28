#Requires -Modules PoShKeePass
#Install-Module -Name PoShKeePass

<#
.SYNOPSIS
    Function to return a KeePassEntry object which will contain the username and password as clear text.
    This function depends on the passwords being in the appropriate place in the vault. See the parameter for -KeePassEntryGroupPath in the implementation.
    It also requires a DatabaseProfile name. This is an XML file that describes the configuration of the location and login information for the keepass vault.
    To create a new configuration use:
        #New-KeePassDatabaseConfiguration -DatabaseProfileName 'NetworkTeamPasswordVault' -DatabasePath "\\dc1-file-01\infrastructure$\KeePass\NetworkTeamPasswordVault.kdbx" -UseMasterKey

        Existing configurations are cound in C:\Program Files\WindowsPowerShell\Modules\PoShKeePass
        
        To get existing KeePass DatabaseConfigurations use Get-KeePassDatabaseConfiguration

.DESCRIPTION
Long description

.PARAMETER UserName
Parameter description

.PARAMETER MasterKey
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-KeePassPassword
(   
    [Parameter(Mandatory=$True)]   [SecureString] $MasterKey,
    [Parameter(Mandatory=$True)]   [string] $DatabaseProfileName,
    [Parameter(Mandatory=$True)]   [string] $UserName, 
    [Parameter(Mandatory=$True)]   [string] $pKeePassEntryGroupPath
    )
{
    if ( !(Get-KeePassDatabaseConfiguration -DatabaseProfileName $DatabaseProfileName) ){
        Write-Warning 'KeePassDatabaseConfiguration not found, does it exist on your workstation?'
        Write-Warning "To create a new KeePass DatabaseConfiguration use: New-KeePassDatabaseConfiguration -DatabaseProfileName 'NetworkTeamPasswordVault' -DatabasePath `"\\dc1-file-01\infrastructure$\KeePass\NetworkTeamPasswordVault.kdbx`" -UseMasterKey"
        Write-Warning "To get existing KeePass DatabaseConfigurations: use Get-KeePassDatabaseConfiguration"
        return $null
    }

    $kpe = (Get-KeePassEntry -KeePassEntryGroupPath $pKeePassEntryGroupPath -AsPlainText -DatabaseProfileName $DatabaseProfileName -MasterKey $MasterKey  |  Where-Object {$_.UserName -eq $UserName})
    
    if (-Not $kpe){
        Write-Warning "$username not found in KeePass"
    }
    else{
        if ( (($kpe | Measure-Object).Count -gt 1) -or !$kpe ){
            Write-Warning "More than one entry found in KeePass for the account, please remove the duplicate from KeePass"
        }
    }
    return  $kpe.Password
}

<#
$MasterKey = ConvertTo-SecureString -String "?ntadmin4" -AsPlainText -Force
$kpe = Get-KeePassPassword -UserName "SA-DSCSQL" -MasterKey $MasterKey -DatabaseProfileName "CentinoLab/SQL" -pKeePassEntryGroupPath $KeePassEntryGroupPath
Write-output $kpe.Password

#>