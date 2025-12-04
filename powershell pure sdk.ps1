$webclient=New-Object System.Net.WebClient
$webclient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
[Net.ServicePointManager]::SecurityProtocol = "tls12"

Get-PSRepository
Register-PSRepository -Default

Install-Module PureStoragePowershellSDK


Register-PSRepository -Name PSGallery1-SourceLocation https://www.powershellgallery.com/api/v2/ -InstallationPolicy Trusted
Update-Module -Name pester -Force

Unregister-PSRepository -Name PSGallery1-SourceLocation 

$PSVersionTable


    Unregister-PSRepository -Name 'PSGallery'
    Register-PSRepository -Default

