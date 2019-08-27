function Test-ServiceAccountToGroup{
    Param(
        [Parameter(Mandatory=$True)]    [String]   $ServiceAccountName,
        [Parameter(Mandatory=$True)]    [String]   $SqlServiceGroup
    )

    $group = Get-ADGroupMember -Identity $SqlServiceGroup | Select-Object -ExpandProperty Name

    if ( $group -contains $ServiceAccountName ){
        Write-Verbose "User $ServiceAccountName is in the group $SqlServiceGroup"
        return $true
    }
    else{
        Write-Verbose "User $ServiceAccountName is NOT in the group $SqlServiceGroup"
        return $false
    }
}
