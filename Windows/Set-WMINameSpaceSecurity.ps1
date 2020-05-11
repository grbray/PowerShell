<#
Disclaimer
The sample scripts are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims 
all implied warranties including, without limitation, any implied warranties of merchantability 
or of fitness for a particular purpose. The entire risk arising out of the use or performance 
of the sample scripts and documentation remains with you. In no event shall Microsoft, its 
authors, or anyone else involved in the creation, production, or delivery of the scripts be 
liable for any damages whatsoever (including, without limitation, damages for loss of business 
profits, business interruption, loss of business information, or other pecuniary loss) arising 
out of the use of or inability to use the sample scripts or documentation, even if Microsoft 
has been advised of the possibility of such damages.
#>


<#
.Synopsis
   A Script for modifying the current security descriptor of a WMI namespace. 
.DESCRIPTION
   A Script for modifying the current security descriptor of a WMI namespace. 
.EXAMPLE
   Set-WMINamespaceSecurity.ps1 -namespace root/cimv2 -account "contoso\AD - Remote WMI Access" -operation Add -permissions Enable
.EXAMPLE
   Set-WmiNamespaceSecurity.ps1 root/cimv2 add steve Enable,RemoteAccess
.NOTES
   Blog links:

   https://blogs.msdn.microsoft.com/wmi/2009/07/20/scripting-wmi-namespace-security-part-1-of-3/
   https://blogs.msdn.microsoft.com/wmi/2009/07/23/scripting-wmi-namespace-security-part-2-of-3/
   https://blogs.msdn.microsoft.com/wmi/2009/07/27/scripting-wmi-namespace-security-part-3-of-3/

   Modified by Graeme Bray
   Original Content by Steve Lee
   Uploaded to Gallery with permission
#>
Param ( [parameter(Mandatory=$true,Position=0)][string] $namespace,
    [parameter(Mandatory=$true,Position=1)][string] $operation,
    [parameter(Mandatory=$true,Position=2)][string] $account,
    [parameter(Position=3)][string[]] $permissions = $null,
    [bool] $allowInherit = $false,
    [bool] $deny = $false,
    [string] $computerName = ".",
    [System.Management.Automation.PSCredential] $credential = $null)
   
Process {
    $ErrorActionPreference = "Stop"
 
    Function Get-AccessMaskFromPermission($permissions) {
        $WBEM_ENABLE            = 1
                $WBEM_METHOD_EXECUTE = 2
                $WBEM_FULL_WRITE_REP   = 4
                $WBEM_PARTIAL_WRITE_REP              = 8
                $WBEM_WRITE_PROVIDER   = 0x10
                $WBEM_REMOTE_ACCESS    = 0x20
                $WBEM_RIGHT_SUBSCRIBE = 0x40
                $WBEM_RIGHT_PUBLISH      = 0x80
        $READ_CONTROL = 0x20000
        $WRITE_DAC = 0x40000
       
        $WBEM_RIGHTS_FLAGS = $WBEM_ENABLE,$WBEM_METHOD_EXECUTE,$WBEM_FULL_WRITE_REP,`
            $WBEM_PARTIAL_WRITE_REP,$WBEM_WRITE_PROVIDER,$WBEM_REMOTE_ACCESS,`
            $READ_CONTROL,$WRITE_DAC
        $WBEM_RIGHTS_STRINGS = "Enable","MethodExecute","FullWrite","PartialWrite",`
            "ProviderWrite","RemoteAccess","ReadSecurity","WriteSecurity"
 
        $permissionTable = @{}
 
        for ($i = 0; $i -lt $WBEM_RIGHTS_FLAGS.Length; $i++) {
            $permissionTable.Add($WBEM_RIGHTS_STRINGS[$i].ToLower(), $WBEM_RIGHTS_FLAGS[$i])
        }
       
        $accessMask = 0
 
        foreach ($permission in $permissions) {
            if (-not $permissionTable.ContainsKey($permission.ToLower())) {
                throw "Unknown permission: $permission`nValid permissions: $($permissionTable.Keys)"
            }
            $accessMask += $permissionTable[$permission.ToLower()]
        }
       
        $accessMask
    }
 
    if ($PSBoundParameters.ContainsKey("Credential")) {
        $remoteparams = @{ComputerName=$computer;Credential=$credential}
    } else {
        $remoteparams = @{ComputerName=$computerName}
    }
       
    $invokeparams = @{Namespace=$namespace;Path="__systemsecurity=@"} + $remoteParams
 
    $output = Invoke-WmiMethod @invokeparams -Name GetSecurityDescriptor
    if ($output.ReturnValue -ne 0) {
        throw "GetSecurityDescriptor failed: $($output.ReturnValue)"
    }
 
    $acl = $output.Descriptor
    $OBJECT_INHERIT_ACE_FLAG = 0x1
    $CONTAINER_INHERIT_ACE_FLAG = 0x2
 
    $computerName = (Get-WmiObject @remoteparams Win32_ComputerSystem).Name
   
    if ($account.Contains('\')) {
        $domainaccount = $account.Split('\')
        $domain = $domainaccount[0]
        if (($domain -eq ".") -or ($domain -eq "BUILTIN")) {
            $domain = $computerName
        }
        $accountname = $domainaccount[1]
    } elseif ($account.Contains('@')) {
        $domainaccount = $account.Split('@')
        $domain = $domainaccount[1].Split('.')[0]
        $accountname = $domainaccount[0]
    } else {
        $domain = $computerName
        $accountname = $account
    }
 
    $getparams = @{Class="Win32_Account";Filter="Domain='$domain' and Name='$accountname'"}
 
    $win32account = Get-WmiObject @getparams
 
    if ($win32account -eq $null) {
        throw "Account was not found: $account"
    }
 
    switch ($operation) {
        "add" {
            if ($permissions -eq $null) {
                throw "-Permissions must be specified for an add operation"
            }
            $accessMask = Get-AccessMaskFromPermission($permissions)
   
            $ace = (New-Object System.Management.ManagementClass("win32_Ace")).CreateInstance()
            $ace.AccessMask = $accessMask
            if ($allowInherit) {
                $ace.AceFlags = $OBJECT_INHERIT_ACE_FLAG + $CONTAINER_INHERIT_ACE_FLAG
            } else {
                $ace.AceFlags = 0
            }
                       
            $trustee = (New-Object System.Management.ManagementClass("win32_Trustee")).CreateInstance()
            $trustee.SidString = $win32account.Sid
            $ace.Trustee = $trustee
           
            $ACCESS_ALLOWED_ACE_TYPE = 0x0
            $ACCESS_DENIED_ACE_TYPE = 0x1
 
            if ($deny) {
                $ace.AceType = $ACCESS_DENIED_ACE_TYPE
            } else {
                $ace.AceType = $ACCESS_ALLOWED_ACE_TYPE
            }
 
            $acl.DACL += $ace.psobject.immediateBaseObject
        }
       
        "delete" {
            if ($permissions -ne $null) {
                throw "Permissions cannot be specified for a delete operation"
            }
       
            [System.Management.ManagementBaseObject[]]$newDACL = @()
            foreach ($ace in $acl.DACL) {
                if ($ace.Trustee.SidString -ne $win32account.Sid) {
                    $newDACL += $ace.psobject.immediateBaseObject
                }
            }
 
            $acl.DACL = $newDACL.psobject.immediateBaseObject
        }
       
        default {
            throw "Unknown operation: $operation`nAllowed operations: add delete"
        }
    }
 
    $setparams = @{Name="SetSecurityDescriptor";ArgumentList=$acl.psobject.immediateBaseObject} + $invokeParams
 
    $output = Invoke-WmiMethod @setparams
    if ($output.ReturnValue -ne 0) {
        throw "SetSecurityDescriptor failed: $($output.ReturnValue)"
    }
}