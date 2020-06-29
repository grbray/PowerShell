<#
.Synopsis
   This script will perform (and utilize Convert-GUIDStoGPOName.ps1 to verify that all GPOs were backed up successfully.
.DESCRIPTION
   This script will perform (and utilize Convert-GUIDStoGPOName.ps1 to verify that all GPOs were backed up successfully.
.EXAMPLE
   .\Confirm-GPOBackup.ps1 -BackupPath C:\GPOBackup -Domain contoso.com
.EXAMPLE
   Another example of how to use this cmdlet
.NOTES
   This script is meant to be used with this script from Ian Farr
      https://gallery.technet.microsoft.com/Comprehensive-Group-Policy-5f9d3ea6
#>
[CmdletBinding()]
[Alias()]
[OutputType([int])]
Param
(
    # Specify the BackupFolder Path
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $BackupPath,

    # Specify the domain to query
    $Domain = $env:USERDOMAIN,

    # Enter To address
    $To = 'ADTeam@contoso.com',

    # Enter From address
    $From = 'no-reply@contoso.com',

    # Enter SMTP Server
    $SMTPServer = 'mail.contoso.com'
    
)

Begin {
    $Date = Get-Date -Format yyyy_MM_dd
    #$Date = '2018_05_11'
    Write-Verbose "Verifying access to $BackupPath\Date*"
    If (-NOT(Test-Path -Path "$BackupPath\$Date*")){
        Write-Error "Unable to access $BackupPath\$Date*" -ErrorAction Stop
    } # End Test-Path
    
    Write-Verbose "Verifying access to $Domain"
    If (-NOT(Test-Connection -ComputerName $Domain -Quiet -Count 2)){
        Write-Error "Unable to access $Domain" -ErrorAction Stop
    } # End Domain Check

    Write-Verbose 'Verifying Group Policy module is available'
    If ((Get-Module -ListAvailable -Name GroupPolicy -Verbose:$False) -eq $null){
 	    Throw 'GroupPolicy module is not available.'
    } # End If 

    Function Convert-GUIDStoGPOName {
        <#
        .SYNOPSIS
           Query a specified GPO Backup Path and pull the display name
        .DESCRIPTION
           Query a specified GPO Backup Path and pull the display name
        .EXAMPLE
           .\Convert-GUIDStoGPOName.ps1 -Path C:\GPOBackup\2018_05_04_230022
        #>
        [CmdletBinding()]
        [Alias()]
        [OutputType([int])]
        Param
        (
            # Param1 help description
            [Parameter(Mandatory=$true,
                        ValueFromPipelineByPropertyName=$true,
                        Position=0)]
            $Path
        )

        Begin {
            If (-NOT(Test-Path $Path)){
                Write-Error "Unable to reach $Path" -ErrorAction Stop
            } # End Test-Path
        } # End Begin
        Process {


            Write-Verbose "Pulling all backup.xml files from $Path"
            $BackupFiles = Get-ChildItem -Path $Path -Recurse -Include Backup.xml

            foreach ($File in $BackupFiles) {
                $ResultHash = @{}

                Write-Verbose "Query File and pull the XML content and get Display Name"
                $GUID = $File.Directory.Name
                $xml = [xml](Get-Content $File)
                $DisplayName = $xml.GroupPolicyBackupScheme.GroupPolicyObject.GroupPolicyCoreSettings.DisplayName.InnerText
                $ResultHash.add('DisplayName', $DisplayName)
                $ResultHash.Add('ID', $GUID)

                # Write Output
                New-Object -TypeName PSObject -Property $ResultHash

            } # End Foreach


        } # End Process
        End {
            rv backupfiles, resulthash, guid, xml, displayname
        } # End End

    }

} # End Begin
Process{
    $Backup = Convert-GUIDStoGPOName -Path "$BackupPath\$Date*"
    $Prod = Get-GPO -All -Domain $Domain

    $Comparison = Compare-Object -ReferenceObject $Prod.DisplayName -DifferenceObject $Backup.DisplayName

    $BodyBUFail = "The following GPOs were in the backup, but not found in Production `n"
    $BodyProdFail = "The following GPOs were in production, but not found in the Backup `n"

    If ($Comparison -ne $null){
        foreach ($GPO in $Comparison) {
            If ($GPO.SideIndicator -eq '=>') {
                $BodyBUFail += "$($GPO.InputObject) `n"
            } ElseIf ($GPO.SideIndicateor -eq '<='){
                $BodyProdFail += "$($GPO.InputObject) `n"
            } # End If 
        }
        # We only want to send an e-mail if there was a backup anomaly
        Send-MailMessage $To -From $From -SmtpServer $SMTPServer -Subject "GPO Backup Verification - $Date" -Body "$BodyBUFail`n$BodyProdFail"
    }
} # End Process
End{
    $Comparison
} # End End