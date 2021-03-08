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