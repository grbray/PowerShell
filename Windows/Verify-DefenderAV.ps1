<#
.Synopsis
   Pulls a select set of values back from Get-MPComputerStatus and Get-MPPreference
.DESCRIPTION
   Pulls a select set of values back from Get-MPComputerStatus and Get-MPPreference
.EXAMPLE
   .\Verify-MDAntivirus.ps1 -Server contoso.com | Out-GridView
.EXAMPLE
   .\Verify-MDAntivirus.ps1 -Server contoso.com | Export-Csv -Path c:\temp\DefenderAVStatus.csv -NoTypeInformation
.INPUTS
   $Server = Domain Name
.OUTPUTS
   PS Custom Object
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
[CmdletBinding(DefaultParameterSetName='Parameter Set 1', 
                SupportsShouldProcess=$true, 
                PositionalBinding=$false,
                HelpUri = 'http://www.microsoft.com/',
                ConfirmImpact='Medium')]
[Alias()]
[OutputType([String])]
Param
(
    # Domain Name
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                Position=0)]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Server
)

Begin {
    Write-Verbose "Verifying ActiveDirectory module is available"
    If (-NOT(Get-Module -ListAvailable -Name ActiveDirectory -Verbose:$False)){
 	    Throw 'ActiveDirectory module is not available.'
    } # End If 

    If ([environment]::OSVersion.Version.Major -ne "10") {
        Throw 'Unsupported Operating System.  Use Windows 10 or Windows Server 2016/2019'
    }

    Write-Verbose "Pulling all Windows Server 2016 and Windows Server 2019 machines"
    $ComputerName = Get-ADComputer -Server $Server -Filter {(Enabled -eq $true) -and ((OperatingSystem -like '*2016*') -or (OperatingSystem -like '*2019*'))} | select -ExpandProperty dnshostname
} # End Begin
Process {
   foreach ($Computer in $ComputerName) {
        If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
            If (Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue) {
                Try {
                    $CIM = New-CimSession -ComputerName $Computer -ErrorAction Stop
                
                    $MPComputerStatus = Get-MpComputerStatus -CimSession $CIM
                    $MPPreference = Get-MpPreference -CimSession $CIM

                    [PSCustomObject]@{
                        ComputerName = $Computer
                        RealTimeProtectionEnabled = $MPComputerStatus.RealTimeProtectionEnabled
                        NISEnabled = $MPComputerStatus.NISEnabled
                        AMRunningMode = $MPComputerStatus.AMRunningMode
                        AMServiceEnabled = $MPComputerStatus.AMServiceEnabled
                        AntispwareEnabled = $MPComputerStatus.AntispywareEnabled
                        AntispywareSignatureVersion = $MPComputerStatus.AntispywareSignatureVersion
                        AntispywareAge = $MPComputerStatus.AntispywareSignatureAge
                        AMEngineVersion = $MPComputerStatus.AMEngineVersion
                        AMServiceVersion = $MPComputerStatus.AMServiceVersion
                        CloudBlockLevel = switch ($MPPreference.CloudBlockLevel) {
                                              '0' {'Default'}
                                              '1' {'Moderate'}
                                              '2' {'High'}
                                              '4' {'High+'}
                                              '6' {'ZeroTolerance'}
                                              Default {'Unknown'}
                                          } # End Switch
                        MAPSReporting = switch ($MPPreference.MAPSReporting) {
                                              '0' {'Disabled'}
                                              '1' {'Basic'}
                                              '2' {'Advanced'}
                                              Default {'Unknown'}
                                          } # End Switch
                        SignatureFallbackOrder = $MPPreference.SignatureFallbackOrder
                    } # End [PSCustomObject]

                    Remove-CimSession -CimSession $CIM
                } Catch {
                    Write-Verbose "$Computer Failed"
                }
            } Else {
                Write-Warning "Unable to make a WinRM connection to $Computer"
            } # End If WSMan
        } Else {
            Write-Warning "Unable to connect to $Computer"
        } # End If Test-Connection
   } # End Foreach $ComputerName
} # End Process
End {
} # End End