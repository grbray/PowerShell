<#
.Synopsis
Tests RDP Port connectivity, and then leverages Test-Path for C$ to check Admin rights
.DESCRIPTION
Tests RDP Port connectivity, and then leverages Test-Path for C$ to check Admin rights
.EXAMPLE
.\Verify-RDPAccess.ps1 -ComputerName server12, server16, server19, server22

ComputerName Admin Connectivity
------------ ----- ------------
server12      True         True
server16      True         True
server19      True         True
server22     False        False
.EXAMPLE
.\Verify-RDPAccess.ps1 -ComputerName server12, server16, server19, oldserver12

ComputerName Admin Connectivity
------------ ----- ------------
server12      True         True
server16      True         True
server19      True         True
oldserver12   False        True

.NOTES
Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims 
all implied warranties including, without limitation, any implied warranties of merchantability 
or of fitness for a particular purpose. The entire risk arising out of the use or performance 
of the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
damages whatsoever (including, without limitation, damages for loss of business profits, business 
interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
possibility of such damages.
#>

[CmdletBinding()]
Param
(
    # Param1 help description
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $ComputerName
)

Begin {
    $i = 0
}
Process {
    foreach ($Computer in $ComputerName) {
        $i++
        Write-Progress "Verifying $Computer - $i of $($ComputerName.count)"

        If ((Test-NetConnection -ComputerName $Computer -CommonTCPPort RDP -WarningAction SilentlyContinue).TCPTestSucceeded) {
            Write-Verbose "$Computer - RDP Port Available"
            If (Test-Path \\$computer\c$ -ErrorAction SilentlyContinue) {
                [pscustomobject]@{
                    'ComputerName' = $Computer
                    'Admin' = $true
                    'Connectivity' = $true
                } # End pscustomobject
            } Else {
                [pscustomobject]@{
                    'ComputerName' = $Computer
                    'Admin' = $false
                    'Connectivity' = $true
                } # End pscustomobject
            } # End Test-Path
        } Else {
            If (Test-Path \\$computer\c$ -ErrorAction SilentlyContinue) {
                [pscustomobject]@{
                    'ComputerName' = $Computer
                    'Admin' = $true
                    'Connectivity' = $false
                } # End pscustomobject
            } Else {
                [pscustomobject]@{
                    'ComputerName' = $Computer
                    'Admin' = $false
                    'Connectivity' = $false
                } # End pscustomobject
            } # End Test-Path
        } # End Test-NetConnection
    } # End Foreach
}
End {
}