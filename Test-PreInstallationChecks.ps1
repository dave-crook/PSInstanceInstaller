[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)] [String] $SqlInstance,
    [Parameter(Mandatory = $true)] [PSCredential] $EngineCredential,
    [Parameter(Mandatory = $true)] [PSCredential] $InstallationCredential,
    [Parameter(Mandatory = $true)] [String] $InstallationSource
)
{
    if ( -Not (Test-NetConnection -ComputerName $ServerName -InformationLevel Quiet -CommonTCPPort WINRM) ) {
        Write-MyException "Cannot Reach $ServerName ensure that the system is online or the firewall is not blocking access to WinRM. Script exiting."
        exit
    }
}

Describe "Pre-Installation Checks" {
    Context "Service Account Validation" {
        $CredentialTestResult = Test-AdCredential -Credential $EngineCredential
        It "Testing to see if the Engine Service account credential is valid $($EngineCredential.Username): " {
            $CredentialTestResult | Should -BeTrue -Because "SQL Server requires a valid service account."
        }
    }

    Context "Installation Account Validation" {
        $CredentialTestResult = Test-AdCredential -Credential $InstallationCredential
        It "Testing to see if the installation account credential is valid $($InstallationCredential.Username): " {
            $CredentialTestResult | Should -BeTrue -Because "Need a valid installation account to run the installer."
        }
    }

    Context "Testing for the existence of required drives on target" {
        $drives = @('C', 'D', 'F', 'L', 'S', 'T') 
        $ServerDrives = Invoke-Command -ComputerName $SqlInstance -ScriptBlock { Get-PSDrive } 
        foreach ($drive in $drives) {
            $result = $ServerDrives.Name.Contains($drive)
            It "Should have a drive $($drive)" {
                $result | Should -BeTrue -Because "SQL Server requires a drive $($Drive)"
            }
        }
    }

    Context "Testing for existance of the installation share" {
        $result = Test-Path -Path $InstallationSource
        It "Testing to see if the installation share exists $InstallationSource" {
            $result | Should -BeTrue -Because "The installation share must exist"
        }
    }
}
  