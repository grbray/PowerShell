<#
.SYNOPSIS
   This script will gather the appropriate Service Principal information and register AAD Connect Health
.DESCRIPTION
   This script will gather the appropriate Service Principal information and register AAD Connect Health
.EXAMPLE
   .\Register-AADCHealthviaSP.ps1 -TenantId 'bf2930bf-54d5-4883-a8d7-f928b4b4d8b4' -ServicePrincipal '9613492b-a3de-4fbb-bca5-99ff596af46d
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
    # Service Principal AppID GUID
    [ValidateScript({
        Try {
            [Guid]::Parse($_) | out-null
            $true
        } Catch {
            $false
        }
    })]
    $ServicePrincipal = 'Replace-Me-With-Your-Service-Principal',

    # Tenant ID GUID
    [ValidateScript({
        Try {
            [Guid]::Parse($_) | out-null
            $true
        } Catch {
            $false
        }
    })]
    $TenantId = 'Replace-Me-With-Your-Tenant'
)

Begin {
    Try {
        $Credential = (Get-Credential -UserName "donotmodify@contoso.com" -Message "Enter Password").GetNetworkCredential().Password
    } Catch {
        break
    }

    Write-Verbose " Verifying AdHealthAdds module is available"
    If (-NOT(Get-Module -ListAvailable -Name AdHealthAdds -Verbose:$false)){
        Try {
            Import-Module "C:\Program Files\Azure Ad Connect Health Adds Agent\PowerShell\AdHealthAdds"
        } Catch {
            Write-Error "AdHealthAdds module is not available"
        }
    }

    # Verify AADC Connect Health is installed
    $Registry = Get-ItemProperty -path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object DisplayName -like "*Azure AD Connect Health agent*"
    If (-NOT($Registry)) {
        Write-Warning 'Azure AD Connect Health agent is not installed'
        break
    }
}
Process {
    # Set up oAuthURI and Body
    $oAuthUri = "https://login.microsoftonline.com/$TenantId/oauth2/token?api-version=2019-12-01"
    $body = [Ordered] @{
        client_id = $ServicePrincipal 
        client_secret = $Credential
        grant_type = 'client_credentials'
        Resource = "https://management.core.windows.net"
    }

    # Pull AAD Access Token
    $response = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $body -ErrorAction Stop -ContentType 'application/x-www-form-urlencoded' 
    $aadToken = $response.access_token

    # Run the Registration of AAD Connect Health
    Register-AzureADConnectHealthADDSAgent -AadToken (ConvertTo-SecureString -AsPlainText $aadToken -Force)
    
} # End Process
End {
    Remove-Variable body, Credential -ErrorAction SilentlyContinue
} # End End