# getting errors validating credentials. issue seems to be in the principal context.
    
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    $Account = 'SA-DCP-VSQL-211'
    $Password = 'oDwflpaB*pZKUAngoTwWb'
    
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext 'Domain', 'POLSINELLI', 'DC=POLSINELLI,DC=LAW', ([System.DirectoryServices.AccountManagement.ContextOptions]'Negotiate') 
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext 'Domain', 'POLSINELLI', $null, ([System.DirectoryServices.AccountManagement.ContextOptions]'Negotiate') 
    
    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext 'Domain', 'POLSINELLI.LAW', $null, ([System.DirectoryServices.AccountManagement.ContextOptions]'Negotiate') 

    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain', 'DC2-P-DC-01.polsinelli.law', $null, ([System.DirectoryServices.AccountManagement.ContextOptions]'SecureSocketLayer,Negotiate'))


    $loginresult = $pc.ValidateCredentials( $Account, $Password )
