<#
.Synopsis
   Uninstall's an MSI from the machine
.DESCRIPTION
   Uninstall's an MSI from the machine
.EXAMPLE
   .\Uninstall-Software.ps1 -ComputerName server12 -DisplayName 'Local Administrator' -NoExit

   ComputerName   : server12
   ExitCode       : 0
   PSComputerName : server12
   RunspaceId     : a86ca4f7-d0f2-40da-b062-9587dc37f878
.EXAMPLE
   .\Uninstall-Software.ps1 -ComputerName server12,server16,server19 -DisplayName 'Local Administrator Password Solution'
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

[CmdletBinding(SupportsShouldProcess)]
[Alias()]
[OutputType([int])]
Param
(
    # Provide the computer name to uninstall from
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $ComputerName,

    # Provide the display name of the app to uninstall
    $DisplayName,
    
    # Provides the Exit code
    [switch]
    $NoExit = $false
)

Begin {
}
Process {
    foreach ($Computer in $ComputerName) {
        Write-Progress "Processing $Computer"
        If (Test-Connection -ComputerName $Computer -Count 2 -Quiet) {
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                $program = Get-ItemProperty -path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like "*$($Using:DisplayName)*"
                $id = $program | Select-Object -ExpandProperty PSChildName -ErrorAction SilentlyContinue

                if ($id) {
                    Write-Verbose "Uninstalling product with $id"
                    $process = Start-Process msiexec -ArgumentList '/x',$id,'/qn','/norestart','/l*v uninstall.log' -Wait -PassThru
                    if ($Using:NoExit) {
                        return [pscustomobject]@{
                            'ComputerName' = $Using:Computer
                            'ExitCode' = $process.ExitCode
                        }
                    } else {
                        exit $process.ExitCode
                    }
                } Else {
                    return [pscustomobject]@{
                        'ComputerName' = $Using:Computer
                        'ExitCode' = 'NotInstalled'
                    }
                }
            }
        } Else {
            Write-Warning "$Computer was not reachable"
        }
    }
}
End {
}
