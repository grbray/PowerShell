<#
.SYNPOSIS
   Adds any account in the Defined OU to the appropriate password policy group.
.DESCRIPTION
   This script will add any account in the Defined OU's to the appropriate password
   policy group.  
.EXAMPLE
.\Set-PasswordPolicy -Server contoso.com -Elevated -Verbose
11:02:41 AM, admin_jdoe, FGPP_ElevatedAccounts
11:02:41 AM, admin_nchorris, FGPP_ElevatedAccounts
11:02:41 AM, admin_doej, FGPP_ElevatedAccounts
.EXAMPLE
.\Set-PasswordPolicy.ps1 -Server corp.graemebray.com -Service
11:06:18 AM, AGPMSvc, FGPP_ServiceSharedAccounts
11:06:18 AM, VeeamSvc, FGPP_ServiceSharedAccounts
11:06:18 AM, AADSync, FGPP_ServiceSharedAccounts
11:06:18 AM, ATAService, FGPP_ServiceSharedAccounts
11:06:18 AM, DSRMSync, FGPP_ServiceSharedAccounts
11:06:18 AM, AATPService, FGPP_ServiceSharedAccounts
11:06:18 AM, AGPMService, FGPP_ServiceSharedAccounts
11:06:19 AM, DHCPSvc, FGPP_ServiceSharedAccounts
11:06:19 AM, jrrtoken, FGPP_ServiceSharedAccounts
11:06:19 AM, BadBind, FGPP_ServiceSharedAccounts

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

[CmdletBinding(DefaultParameterSetName='Elevated Accounts', 
                SupportsShouldProcess=$true, 
                PositionalBinding=$false,
                ConfirmImpact='Medium')]
[OutputType([String])]
Param
(
    # Environment to apply Password Policy To
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                ValueFromRemainingArguments=$false, 
                Position=0)]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Server,

    # Only process Elevated Accounts
    [Parameter(ParameterSetName='Elevated Accounts')]
    [Switch]
    $Elevated,

    # Only process Service Accounts
    [Parameter(ParameterSetName='Service Accounts')]
    [Switch]
    $Service,

    [String]
    $Output = "C:\Temp\Scripts\FGPP"

)

Begin {
    $ElevatedGroup = 'FGPP_AdminAccounts'
    $ServiceGroup = 'FGPP_ServiceSharedAccounts'

    
    $Date = Get-Date -Format "yyyy.MM.dd"

    # Test AD connection
    If ((Test-NetConnection -ComputerName $server -Port 9389).TcpTestSucceeded -eq $False) {
        Write-Warning "Unable to connect to $server"
        Break
    }

    $DomainDN = (Get-ADDomain -Identity $server).DistinguishedName
    If ($Elevated) {
        $OU = @("OU=Elevated,OU=Accounts,OU=Tier 0,OU=Admin,$DomainDN",
                "OU=Elevated,OU=Accounts,OU=Tier 1,OU=Admin,$DomainDN",
                "OU=Elevated,OU=Accounts,OU=Tier 2,OU=Admin,$DomainDN")
    } ElseIf ($Service) {
        $OU = @("OU=Service,OU=Accounts,OU=Tier 0,OU=Admin,$DomainDN",
                "OU=Service,OU=Accounts,OU=Tier 1,OU=Admin,$DomainDN",
                "OU=Service,OU=Accounts,OU=Tier 2,OU=Admin,$DomainDN")
    } Else {
        Write-Error 'Unable to find target path, exiting...'
    } # End If

    If (!(Test-Path $Output)) {
        New-Item -Path $Output -ItemType Directory
    }

} # End Begin
Process {
    if ($pscmdlet.ShouldProcess("Target", "Operation")) {
        foreach ($OUPath in $OU) {
            $ADUsers += Get-ADUser -Server $Server -SearchBase $OUPath -Filter *
        } # End Foreach $OU

        foreach ($User in $ADUsers) {
            If ((Get-ADUserResultantPasswordPolicy -Identity $User) -eq $null){
                If ($User.DistinguishedName -like '*Elevated*'){
                    Write-Verbose "Adding $($User.SamAccountName) to $ElevatedGroup"
                    Write-Output "$(Get-Date -Format T), $($User.SamAccountName), $ElevatedGroup" | Tee-Object -FilePath "$Output\$ElevatedGroup-$Date.csv" -Append
                    Add-ADGroupMember -Identity $ElevatedGroup -Members $User -Server $Server
                } Else {
                    Write-Verbose "Adding $($User.SamAccountName) to $ServiceGroup"
                    Write-Output "$(Get-Date -Format T), $($User.SamAccountName), $ServiceGroup" | Tee-Object -FilePath "$Output\$ServiceGroup-$Date.csv" -Append
                    Add-ADGroupMember -Identity $ServiceGroup -Members $User -Server $Server
                } # End If $OU Test
            } # End Get-ADUserResultantPasswordPolicy
        } # End Foreach $ADUsers
    } # End ShouldProcess
} # End Process
End {
} # End End
