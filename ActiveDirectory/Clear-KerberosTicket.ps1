<#        
THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED    
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR    
    FITNESS FOR A PARTICULAR PURPOSE.   
      
This sample is not supported under any Microsoft standard support program or service.    
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all   
    implied warranties including, without limitation, any implied warranties of merchantability   
    or of fitness for a particular purpose. The entire risk arising out of the use or performance   
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,   
    or anyone else involved in the creation, production, or delivery of the script be liable for    
    any damages whatsoever (including, without limitation, damages for loss of business profits,    
    business interruption, loss of business information, or other pecuniary loss) arising out of    
    the use of or inability to use the sample or documentation, even if Microsoft has been advised    
    of the possibility of such damages, rising out of the use of or inability to use the sample script,    
    even if Microsoft has been advised of the possibility of such damages.    
#>

<#
.Synopsis
   This function uses Powershell remoting and the command line utility klist.exe to clear Kerberos Tickets
.DESCRIPTION
   This function uses Powershell remoting and the command line utility klist.exe to clear Kerberos Tickets

   You can pass through multiple computer names and clear either the LocalSystem or NetworkService Kerberos Tickets.

   This is a simplified script of the Technet/Microsoft script listed below:
   http://blogs.technet.com/b/tspring/archive/2014/06/23/viewing-and-purging-cached-kerberos-tickets.aspx
.EXAMPLE
PS C:\windows\system32> Clear-KerberosTicket -ComputerName server01 -SessionName LocalSystem
Success
.EXAMPLE
PS C:\windows\system32> Clear-KerberosTicket -ComputerName server01 -SessionName LocalSystem -Verbose
VERBOSE: Attempting to connnect to server01
WARNING: Unable to connect to server01
#>
function Clear-KerberosTicket
{
    [CmdletBinding()]
    [OutputType([String])]
    Param
    (
        # Computer name variable
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $ComputerName,

        # Session Name (Local System or Network Service)
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateSet('LocalSystem', 'NetworkService')]
        $SessionName
    )

    Begin {
        switch ($SessionName) {
            'LocalSystem' { $ID = '0x3e7' }
            'NetworkService' { $ID = '0x3e4' }
            Default { Write-Error 'Invalid Session Name' -ErrorAction Stop}
        }
    } # End Begin
    Process {
        foreach ($Computer in $ComputerName) {
            Write-Verbose "Attempting to connnect to $Computer"
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                Write-Verbose "Clearing Kerberos Ticket on $Computer for $SessionName"
                $Result = invoke-command -ComputerName $Computer -ScriptBlock { klist -li $Using:ID purge}
                If ($Result[4].TrimStart() -like 'Ticket(s) Purged!') {
                    Write-Output "Success - $Computer"
                } Else {
                    Write-Warning "Failure - $Computer"
                } # End If
            } Else {
                Write-Warning "Unable to connect to $Computer"
            } # End If
        } # End Foreach
    } # End Process
} # End Clear-KerberosTicket