function Set-PageFile {
    Param(
        [Parameter(Mandatory = $True)] [String] $ComputerName,
        [Parameter(Mandatory = $True)] [String] $Location,
        [Parameter(Mandatory = $True)] [int]    $InitialSize,
        [Parameter(Mandatory = $True)] [int]    $MaximumSize
    )
    try {
        $computersys = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges -ComputerName $ComputerName
        $computersys.AutomaticManagedPagefile = $False
        $computersys.Put()

        $pagefile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name='c:\\pagefile.sys'" -ComputerName $ComputerName
        $pagefile.Delete()
        Set-WMIInstance -class Win32_PageFileSetting -Arguments @{name = "$Location\pagefile.sys"; InitialSize = $InitialSize; MaximumSize = $MaximumSize } -ComputerName $ComputerName
        
        if ($RestartComputer) {
            Restart-Computer -ComputerName 'DBASQL1' -Force
        }
        else {
            Write-Output 'Changing page file settings requires a reboot.'
        }
    }
    catch {
        Write-Error "Error configuring the page file $_"
    }
}


