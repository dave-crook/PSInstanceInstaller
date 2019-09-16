Param(
    [Parameter(Mandatory=$True)]
    [ValidateSet('DC1','DC2','LSP')]
    [String]   $DataCenter)
try{
    if ( $DataCenter -eq 'DC1' ){
        Write-Output "Loading $DataCenter Environment Settings"
        . .\Import-Dc1EnvironmentSettings.ps1 
    }        
    if ( $DataCenter -eq 'DC2' ){
        Write-Output "Loading $DataCenter Environment Settings"
        . .\Import-Dc2EnvironmentSettings.ps1
    }
    if ( $DataCenter -eq 'LSP' ){
        Write-Output "Loading $DataCenter Environment Settings"
        . .\Import-LspEnvironmentSettings.ps1
    }
}
catch{
    Write-Error $_
}
