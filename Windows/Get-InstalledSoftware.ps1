<#
.Synopsis
   Gets a list of installed software from a machines registry
.DESCRIPTION
   Gets a list of installed software from a machines registry
.EXAMPLE
   .\Get-InstalledSoftware.ps1 -ComputerName server19


DisplayName    : 
PSChildName    : Connection Manager
ComputerName   : server19
PSComputerName : server19
RunspaceId     : f6bf641b-bb75-490c-b1ab-cc98d2ea8a9e

DisplayName    : 
PSChildName    : WIC
ComputerName   : server19
PSComputerName : server19
RunspaceId     : f6bf641b-bb75-490c-b1ab-cc98d2ea8a9e

DisplayName    : Local Administrator Password Solution
PSChildName    : {EA8CB806-C109-4700-96B4-F1F268E5036C}
ComputerName   : server19
PSComputerName : server19
RunspaceId     : f6bf641b-bb75-490c-b1ab-cc98d2ea8a9e

DisplayName    : 
PSChildName    : Connection Manager
ComputerName   : server19
PSComputerName : server19
RunspaceId     : f6bf641b-bb75-490c-b1ab-cc98d2ea8a9e

DisplayName    : 
PSChildName    : WIC
ComputerName   : server19
PSComputerName : server19
RunspaceId     : f6bf641b-bb75-490c-b1ab-cc98d2ea8a9e
.EXAMPLE
   .\Get-InstalledSoftware.ps1 -ComputerName server19 | Where-Object {$_.DisplayName -like 'Local*'}

   DisplayName    : Local Administrator Password Solution
   PSChildName    : {EA8CB806-C109-4700-96B4-F1F268E5036C}
   ComputerName   : server19
   PSComputerName : server19
   RunspaceId     : 563f6dd1-071f-4cdb-9aea-6b4037665978

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
[Alias()]
Param
(
    # Param1 help description
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $ComputerName
)

Begin {
}
Process {
    foreach ($Computer in $ComputerName) {
        Write-Progress "Processing $Computer"
        If (Test-Connection -ComputerName $Computer -Count 2 -Quiet) {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | select DisplayName, PSChildName, @{N='ComputerName'; E={$Using:Computer}}
            }
        } Else {
            Write-Warning "$Computer was not reachable"
        }
    }
}
End {
}
