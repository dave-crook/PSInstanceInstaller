function Install-SqlCertificate{
    Param(
        [Parameter(Mandatory=$True)]    [String]   $ServerName,
                                        [String]   $AGListener,
                                        [String]   $InstanceName = "MSSQLSERVER"
                                        )
    # Get certificate and authorize SQL service account
    try{
        $certificate = Get-DbaNetworkCertificate -ComputerName $ServerName

        if ( $certificate ){
            Write-Verbose "A computer certifcate exists on $Servername already. Perform certificate modifications manually"
        }
        else {
            Write-Verbose "Requesting a computer certificate for $servername"
                #add both the server shortname and FQDN to the $DnsNames List. These will be added to the list of subject alternative names in the certificate.
            $DnsNames = @()
            $DnsNames += $ServerName
            $DnsNames += ([System.Net.Dns]::GetHostByName($ServerName)).HostName

            #If we're in an AG, add both the listener's shortname and FQDN to the $DnsNames List. These will be added to the list of subject alternative names in the certificate.
            if ( $AGListener ){
            $DnsNames += $AGListener
            $DnsNames += ([System.Net.Dns]::GetHostByName($AGListener)).HostName
            }

            #TODO Parameterize the ClusterTemplateName
            #$certificate = New-DbaComputerCertificate -ComputerName $ServerName -CertificateTemplate "SqlClusterCert" -KeyLength 4096 -FriendlyName $ServerName -Dns $DnsNames 
            $CaName = 'Polsinelli-Sub-02'
            $CaServer = 'DC2-P-ICA-01.polsinelli.law'

            $certificate = New-DbaComputerCertificate -ComputerName $ServerName  -KeyLength 4096 -FriendlyName $ServerName -Dns $DnsNames -CertificateTemplate "SQLClusterCert"  -CaServer $CaServer -CaName $CaName
            if (!$certificate){
                Write-Error "Unable to request a certificate from the CA"
            }
            else{
            Set-DbaNetworkCertificate -SqlInstance "$ServerName\$InstanceName" -EnableException -Thumbprint $certificate.Thumbprint
            }
        }
    }
    catch{
        Write-Error $_
    }
}
