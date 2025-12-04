# this quit working, trying different approach below
function Test-AdCredential_old(   
    [Parameter(Mandatory=$True)]   [PSCredential] $Credential
)
{
    # $Credential = $EngineCredential
    $NetworkCredential = New-Object System.Net.NetworkCredential $Credential.UserName, $Credential.Password
    $Domain = $NetworkCredential.UserName.Split('\')[0]
    $Account = $NetworkCredential.UserName.Split('\')[1]
    $Password = $NetworkCredential.Password

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $DefaultNC = "DC=$($Domain -replace '\.',',DC=')"

    $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext $ct, $Domain, $DefaultNC, ([System.DirectoryServices.AccountManagement.ContextOptions]'Negotiate') 

    try{
        $loginresult = $pc.ValidateCredentials( $Account, $Password )
    }
    catch{
        Write-Error $_ -ErrorAction Stop
        return $false
    }

    if ($loginresult -eq $true) {
        Write-Verbose "Login succeeded for $Account"
        return $true
    }
    else {
        Write-Verbose "Login failed for $Account!"
        return $false
    }
}


function Test-AdCredential(   
        [Parameter(Mandatory=$true)]
        [PSCredential]$Credential,
        [string]$LdapPath = "LDAP://DC=POLSINELLI,DC=LAW"
)
{    
    try {
        # Create a DirectoryEntry object to force an LDAP bind.
        $de = New-Object System.DirectoryServices.DirectoryEntry(
            $LdapPath, 
            $Credential.UserName, 
            $Credential.GetNetworkCredential().Password
        )
        # Access a property to trigger the bind.
        $null = $de.NativeObject

        Write-Verbose "Login succeeded for $Account"
        return $true
    }
    catch {
        Write-Verbose "Login failed for $Account!"
        return $false
    }
}

 