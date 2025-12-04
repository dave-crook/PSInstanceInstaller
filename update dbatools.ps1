[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12

Install-Module dbatools -Force -SkipPublisherCheck

Get-Module dbatools -ListAvailable