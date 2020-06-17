<#
.SYNOPSIS
   Creates Scheduled Task with Group Managed Service Account (gMSA)
.DESCRIPTION
   Creates Scheduled Task with Group Managed Service Account (gMSA)
.EXAMPLE
   .\New-ScheduledTask.ps1 -File C:\Scripts\Backup-AllGPO.ps1 -Arguments '-Server contoso.com -Path \\server.contoso.com\GPOBackup\' -Time 23:00 -UserID contoso\GPOBackup$ -Weekly -DayOfWeek Friday
.EXAMPLE
   .\New-ScheduledTask.ps1 -File C:\Scripts\Backup-AllGPO.ps1 -Arguments '-Server contoso.com -Path \\server.contoso.com\GPOBackup\' -Time 01:00 -UserID contoso\GPOBackup$ -Daily
.EXAMPLE
   .\New-ScheduledTask.ps1 -File c:\scripts\myscript.ps1 -Repetition -Interval '5 Minutes' -Duration '1 Day' -TaskName 'My Task' -Time '8:00' -UserID 'NT Authority\System'
.NOTES
   Time must be entered in 24-Hour time (11:00PM == 23:00)
#>
[CmdletBinding()]
[OutputType([int])]
Param
(
    # Script File to run
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $File,

    [String]
    [Parameter()]
    $Arguments,

    # Param2 help description
    [DateTime]
    [Parameter(Mandatory=$true)]
    $Time,

    [String]
    [Parameter(Mandatory=$true)]
    $UserID,

    [Switch]
    [Parameter(ParameterSetName='Daily')]
    $Daily,

    [Switch]
    [Parameter(ParameterSetName='Weekly')]
    $Weekly,

    [Switch]
    #If "Repetition is selected, Daily is auto-picked"
    [Parameter(ParameterSetName='Repetition')]
    $Repetition,

    [Parameter(ParameterSetName='Repetition')]
    #This is how long the script will bet set for, such as it will repeat X times for every $Duration
    [ValidateSet('1 Hour','2 Hours','4 Hours','6 Hours','8 Hours','12 Hours','1 Day')]
    $Duration,

    [Parameter(ParameterSetName='Repetition')]
    #This is how often the script will run, such as it will repeat every $Interval for X duration
    [ValidateSet('5 Minutes','10 Minutes','30 Minutes','1 Hour','2 Hours','6 Hours','12 Hours')]
    $Interval,

    [String]
    [Parameter(ParameterSetName='Weekly')]
    [ValidateSet('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')]
    $DayOfWeek,

    [String]
    [Parameter(Mandatory=$true)]
    $TaskName
)
Begin {
    If (!(Test-Path $file)) {
        Throw "File: $File is not valid or accessible"
    }
    If (($UserID.split('\')).count -ne 2) {
        Throw "UserID: $UserID needs to be in ""Domain\User"" format"
    }
} # End Begin
Process {
    Write-Verbose 'Checking if the task exists.'
    If (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
        Write-Verbose "Setting Scheduled Task Action - Running PowerShell.exe with $File"
        $action = New-ScheduledTaskAction -Execute PowerShell.exe -Argument "-file $File $Arguments"

        IF ($Repetition) { $Daily = $true }

        Write-Verbose "Running task at $Time" 
        if ($Daily) {
            $trigger = New-ScheduledTaskTrigger -At $Time -Daily
        } ElseIf ($Weekly) {
            $trigger = New-ScheduledTaskTrigger -At $Time -Weekly -DaysOfWeek $DayOfWeek
        } # End If/Else
    
        $taskSettings = New-ScheduledTaskSettingsSet -Compatibility Win8

        Write-Verbose "Running task as $UserID"    
        $principal = New-ScheduledTaskPrincipal -UserID $UserID -LogonType Password
    
        Write-Verbose "Creating Scheduled Task"
        Register-ScheduledTask -TaskName $TaskName –Action $action –Trigger $trigger –Principal $principal -Settings $taskSettings
    } Else {
        Write-Warning "The Task '$TaskName' already exists."
    }

    If ($Repetition) {
        $Trigger = Get-ScheduledTask -TaskName $TaskName
        
        Write-Verbose "Setting Repetition Interval to $Interval"
        switch ($Interval) {
            '5 Minutes' {$i = 'PT05M'}
            '10 Minutes' {$i = 'PT10M'}
            '15 Minutes' {$i = 'PT15M'}
            '30 Minutes' {$i = 'PT30M'}
            '1 Hour' {$i = 'PT1H00M'}
            '2 Hours' {$i = 'PT2H00M'}
            '6 Hours' {$i = 'PT6H00M'}
            '12 Hours' {$i = 'PT12H00M'}
            Default {$i = 'PT1H00M'}
        }
        $Trigger.triggers.repetition.Interval = $i
        
        Write-Verbose "Setting the Duration to $Duration"
        switch ($Duration) {
            '1 Hour' {$d = 'PT1H00M'}
            '2 Hours' {$d = 'PT2H00M'}
            '4 Hours' {$d = 'PT4H00M'}
            '6 Hours' {$d = 'PT6H00M'}
            '8 Hours' {$d = 'PT8H00M'}
            '12 Hours' {$d = 'PT12H00M'}
            '1 Day' {$d = 'PT24H00M'}
            Default {$d = 'PT24H00M'}
        }
        $trigger.triggers.repetition.Duration = $d

        Write-Verbose "Updating Scheduled Task $TaskName"
        $Trigger | Set-ScheduledTask
    }
} # End Process
End {
} # End End
