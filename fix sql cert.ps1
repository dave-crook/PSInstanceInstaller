# check cert for sql instance
Get-DbaComputerCertificate -ComputerName dcd-vsql-101 | Format-Table  # should show ~6 certs, one of which is the sql cert (or should be). it's the one with the name = sql server name.
Get-DbaNetworkCertificate -SqlInstance dcd-vsql-187

### manually fix cert ###

# show cert candidates. pick one with name = sql server name and get its thumbprint
Get-DbaComputerCertificate -ComputerName dcp-vsql-192 | Format-Table

# set cert for sql instance, using thumbprint from above
Set-DbaNetworkCertificate -SqlInstance "DCP-VSQL-192\MSSQLSERVER" -EnableException -Thumbprint E10420B3E11220AC290FF289BABCC838C109F936
Restart-DbaService -ComputerName DCP-VSQL-192

# confirm cert install
Get-DbaNetworkCertificate -SqlInstance dcp-vsql-192

