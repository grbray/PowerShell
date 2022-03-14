<#
.Synopsis
   Pulls pertinent info from machines for AV Blockers
.DESCRIPTION
   Pulls pertinent info from machines for AV Blockers
.EXAMPLE
   .\Get-DefenderBlockers.ps1 -ComputerName server16, server19, server12, server17 | Format-Table

Name     Service Feature          InstallState DisableAntiSpyware DisableAntiVirus GPODisableAntiSpyware GPODisableAntiVirus DisableWUAccess
----     ------- -------          ------------ ------------------ ---------------- --------------------- ------------------- ---------------
server16         Windows-Defender    Available                                                                                              
server19 Running Windows-Defender    Installed 0                  0                0                     NotSet              1              
server12                                                                                                                                    
server17         Windows-Defender      Unknown          

.EXAMPLE
   .\Get-DefenderBlockers.ps1 -ComputerName server19
Name                  : server19
Service               : Running
Feature               : Windows-Defender
InstallState          : Installed
DisableAntiSpyware    : 0
DisableAntiVirus      : 0
GPODisableAntiSpyware : 0
GPODisableAntiVirus   : NotSet
DisableWUAccess       : 1

.NOTES
   Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. 
Microsoft further disclaims all implied warranties including, without limitation, 
any implied warranties of merchantability or of fitness for a particular purpose. 
The entire risk arising out of the use or performance of the sample scripts and documentation 
remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, 
production, or delivery of the scripts be liable for any damages whatsoever 
(including, without limitation, damages for loss of business profits, business interruption, 
loss of business information, or other pecuniary loss) arising out of the use of or inability 
to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.
#>

#>

[CmdletBinding()]
Param
(
    # Computer (or array of computers)
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $ComputerName
)

Begin {
}
Process {
    foreach ($Computer in $ComputerName) {
        Write-Verbose "$Computer - Pulling Defender service status"
        Try {
            $Service = Get-CimInstance -ComputerName $Computer -ClassName Win32_Service -Filter "Name like 'WinDefend'" -ErrorAction Stop
        } Catch {
            Write-Warning "$Computer - Service Not Installed/Running"
            $Service = 'NotInstalled'
        }
        
        Write-Verbose "$Computer - Pulling Defender feature status"
        Try {
            $Feature = Get-WindowsFeature -ComputerName $Computer -Name Windows-Defender -ErrorAction Stop
        } Catch {
            Write-Warning "$Computer - Windows Feature query failure"
            $Feature = [pscustomobject]@{
                "Name" = "Windows-Defender"
                "InstallState" = "Unknown"
            }
        }

        Write-Verbose "$Computer - Pulling pertinent Registry Keys"
        $RegKeys = Try {
            Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock {
                $RebootTime = Get-WMIObject -Class Win32_OperatingSystem | Select @{l="LastBootUpTime";e={$_.ConverttoDateTime($_.lastbootuptime)}}
                
                $GPOSpy = try {
                Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\' -Name DisableAntiSpyware -ErrorAction Stop
                } Catch {
                    'NotSet'
                }

                $GPOAV = try {
                    Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\' -Name DisableAntiVirus -ErrorAction Stop
                } Catch {
                    'NotSet'
                }

                $DisableWUAccess = try {
                    Get-ItemPropertyValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate' -Name DisableWindowsUpdateAccess -ErrorAction Stop
                } Catch {
                    'NotSet'
                }
            

                [pscustomobject]@{
                    'LastBootUpTime' = $RebootTime.LastBootUpTime
                    'DisableAntiSpyware' = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\' -Name DisableAntiSpyware
                    'DisableAntiVirus' = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\' -Name DisableAntiVirus
                    'GPODisableAntiSpyware' = $GPOSpy
                    'GPODisableAntiVirus' = $GPOAV
                    'DisableWUAccess' = $DisableWUAccess
                }
            }

        } Catch {
            Write-Warning "$Computer - Registry Query Failure"
            $RegKeys = [pscustomobject]@{
                'LastBootUpTime' = 'N/A'
                'DisableAntiSpyware' = 'N/A'
                'DisableAntiVirus' = 'N/A'
                'GPODisableAntiSpyware' = 'N/A'
                'GPODisableAntiVirus' = 'N/A'
                'DisableWUAccess' = 'N/A'
            }
        }

        [PSCustomObject]@{
            "Name" = $Computer
            'Service' = $Service.State
            "Feature" = $Feature.Name
            "InstallState" = $Feature.InstallState
            'LastBootUpTime' = $RegKeys.LastBootUpTime
            'DisableAntiSpyware' = $RegKeys.DisableAntiSpyware
            'DisableAntiVirus' = $RegKeys.DisableAntiVirus
            'GPODisableAntiSpyware' = $RegKeys.GPODisableAntiSpyware
            'GPODisableAntiVirus' = $RegKeys.GPODisableAntiVirus
            'DisableWUAccess' = $RegKeys.DisableWUAccess
        }
    }
}
End {
}