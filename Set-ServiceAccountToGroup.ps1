
function Set-ServiceAccountToGroup{
    Param(
        [Parameter(Mandatory=$True)]    [String]   $ServiceAccountName,
        [Parameter(Mandatory=$True)]    [String]   $SqlServiceGroup
    )

    try{
        Write-Output "Adding $ServiceAccountName to Group $SqlServiceGroup"  
        $Group = Get-ADGroup -Identity $SqlServiceGroup 
        $ThisSerivceAccount = Get-ADUser -Identity $ServiceAccountName
        Add-AdGroupMember -Identity $Group -Members $ThisSerivceAccount 
        return $True
    }
    catch{
        Write-Error "There was an error adding the SQL Server Service $ServiceAccountName account to the group $SqlServiceGroup  $_.Exception.Message"
        return $false
    }
}
