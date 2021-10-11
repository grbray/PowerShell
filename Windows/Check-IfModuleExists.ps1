## This snippet will ensure that a module is available, correctly.

Write-Verbose "Verifying ActiveDirectory module is available"
If (-NOT(Get-Module -ListAvailable -Name ActiveDirectory -Verbose:$False)){
 	Throw 'ActiveDirectory module is not available.'
} # End If 