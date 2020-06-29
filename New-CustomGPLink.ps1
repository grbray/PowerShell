<#
.SYNOPSIS
    Link a GPO to a set of locations
.DESCRIPTION
    Link a GPO to a set of locations
.EXAMPLE
    .\Get-OULocation.ps1 -Domain contoso.com -Computer | New-CustomGPLink -Domain contoso.com -Name 'Test - GPO'
.EXAMPLE
    New-GPLink -Name 'Test - GPO' -Target 'DC=contoso,DC=com'
#>
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Domain Name
        $Domain = $env:USERDOMAIN,

        # GPO Name
        $Name,
        
        # Full Distinguished Name
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        $DistinguishedName
    )
        
    Begin {
        If ((Get-Module -Name GroupPolicy -Verbose:$False) -eq $false){
 	        Throw 'Group Policy module is not available.'
        } # End If

        If (-NOT(Get-GPO -Domain $Domain -Name $Name)){
            Throw 'GPO Name is incorrect'
        }
    } # End Begin
    Process {
        # Loop through each of the GP Links
        foreach ($DN in $DistinguishedName) {
            # Check to see if it starts with CN=.  We can't link there, remember?
            If (-NOT($DN.startsWith('CN='))){
                # Link Policy
                New-GPLink -Domain $Domain -Name $Name -Target $DN     
            } # End If
        } # End Foreach
    } # End Process
