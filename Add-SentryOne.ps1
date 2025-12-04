Import-Module "C:\Program Files\SentryOne\20.0\Intercerve.SQLSentry.Powershell.psd1"

function Add-SentryOne(   
    [Parameter(Mandatory=$True)]   [string] $SqlInstance,
    [Parameter(Mandatory=$True)]   [string] $S1Host, 
    [string] $S1DatabaseName = 'SentryOne'
    
    )
{
    Write-Output "Adding $SqlInstance to the SentryOne Server $S1Host..."
    Connect-SQLSentry -ServerName $S1Host -DatabaseName $S1DatabaseName
    Register-Connection -ConnectionType SqlServer -Name $SqlInstance
    Get-Connection -Name $SqlInstance -NamedServerConnectionType SqlServer | Invoke-WatchConnection
}
