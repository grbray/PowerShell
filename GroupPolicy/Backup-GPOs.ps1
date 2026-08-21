##########################################################################################################
<#
.SYNOPSIS
    Backs up GPOs from a specified domain and includes additional GPO information.

.DESCRIPTION
    The script backs up GPOs in a target domain and captures additional GPO management information, such
    as Scope of Management, Block Inheritance, Link Enabled, Link Order, Link Enforced and WMI Filters.

    The backup can then be used by a partner script to mirror GPOs in a test domain.

    Details:
    * Creates a XML file containing PSCustomObjects used by partner import script
    * Creates a XML file WMI filter details used by partner import script
    * Creates a CSV file of additional information for readability
    * Creates a folder containing HTML reports of settings for each GPO
    * Additional backup information includes SOM (Scope of Management) Path, Block Inheritance, Link Enabled,
      Link Order', Link Enforced and WMI Filter data
    * Each CSV SOM entry is made up of "DistinguishedName:BlockInheritance:LinkEnabled:LinkOrder:LinkEnforced"
    * Option to create a Migration Table (to then be manually updated)

    Requirements: 
    * PowerShell GroupPolicy Module
    * PowerShell ActiveDirectory Module
    * Group Policy Management Console

.EXAMPLE
   .\BackUp_GPOs.ps1 -Domain wintiptoys.com -BackupFolder "\\wingdc01\backups\"

   This will backup all GPOs in the domain wingtiptoys.com and store them in a date and time stamped folder 
   under \\wingdc01\backups\.

.EXAMPLE
   .\BackUp_GPOs.ps1 -Domain contoso.com -BackupFolder "c:\backups" -MigTable

   This will backup all GPOs in the domain contoso.com and store them in a date and time stamped folder 
   under c:\backups\. A migration table, MigrationTable.migtable, will also be created for manual editing.

.EXAMPLE
   .\BackUp_GPOs.ps1 -Domain contoso.com -BackupFolder "c:\backups" -ModifiedDays 15

   This will backup all GPOs in the domain contoso.com that have been modified within the last 15 days. 
   The script will store the backed up GPOs in a date and time stamped folder under c:\backups\

.EXAMPLE
   .\BackUp_GPOs.ps1 -Domain adatum.com -BackupFolder "c:\backups" -GpoGuid "b1e0e5ea-0d6b-48f1-a56c-0a98d8acd17b"

   This will backup the GPO identified by the following GUID - "b1e0e5ea-0d6b-48f1-a56c-0a98d8acd17b" - from the 
   domain adatum.com

   The backed up GPO will be stored in a date and time stamped folder under c:\backups\

.OUTPUTS
   * Backup folder name in the format Year_Month_Day_HourMinuteSecond
   * Per-GPO HTML settings report in the format <backup-guid>__<gpo-guid>__<gpo-name>.html
   * GpoDetails.xml
   * Wmifilters.xml
   * GpoInformation.csv
   * MigrationTable.migtable (optional)

   EXIT CODES: 1 - GPMC not found

.NOTES
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
##########################################################################################################

#################################
## Script Options and Parameters
#################################

#Requires -version 3
#Requires -modules ActiveDirectory,GroupPolicy

#Version: 2.4
<#   
     - 2.1 - 19/08/2014 
     * the script now processes gPLink info on site objects
     * thanks to Mark Renoden [MSFT]

     - 2.2 - 08/07/2015 
     * updates to allow backup from one trusted forest to another

     - 2.3 - 12/01/2016 
     * added ability to backup GPOs modified within the last X days
     * added ability to create html report of settings per GPO
     * thanks to Marcus Carvalho [MSFT]

     - 2.4 - 15/01/2016 
     * added ability to backup a single GPO
     * added parameter sets to prevent -GpoGuid and -ModifiedDate being used together
#>

#Define and validate parameters
[CmdletBinding(DefaultParameterSetName="All")]
Param(
      #The target domain
      [parameter(Mandatory=$True,Position=1)]
      [ValidateScript({Get-ADDomain $_})] 
      [String]$Domain,

      #The backup folder
      [parameter(Mandatory=$True,Position=2)]
      [ValidateScript({Test-Path $_})]
      [String]$BackupFolder,

      #Backup GPOs modified within the last X days
      [parameter(ParameterSetName="Modified",Mandatory=$False,Position=3)]
      [ValidateSet(15,30,45,60,90)]
      [Int]$ModifiedDays,

      #Backup a single GPO
      [parameter(ParameterSetName="Guid",Mandatory=$False,Position=3)]
      [ValidateScript({Get-GPO -Guid $_})] 
      [String]$GpoGuid,

      #Whether to create a migration table
      [Switch]$MigTable
    )


#Set strict mode to identify typographical errors (uncomment whilst editing script)
#Set-StrictMode -version Latest


##########################################################################################################

########
## Main
########


########################
##BACKUP FOLDER DETAILS
#Create a variable to represent a new backup folder
#(constructing the report name from date details and the supplied backup folder)
$Date = Get-Date
$ShortDate = Get-Date -format d

$SubBackupFolder = "$BackupFolder\" + `                   "$($Date.Year)_" + `                   "$("{0:D2}" -f $Date.Month)_" + `                   "$("{0:D2}" -f $Date.Day)_" + `                   "$("{0:D2}" -f $Date.Hour)" + `                   "$("{0:D2}" -f $Date.Minute)" + `                   "$("{0:D2}" -f $Date.Second)"


##################
##BACKUP ALL GPOs
#Create the backup folder
New-Item -ItemType Directory -Path $SubBackupFolder | Out-Null

#Create the settings report folder
$HtmlReports = "HTML_Reports"
New-Item -ItemType Directory -Path "$SubBackupFolder\$HtmlReports" | Out-Null


#Make sure the backup folders have been created
if ((Test-Path -Path $SubBackupFolder) -and (Test-Path -Path "$SubBackupFolder\$HtmlReports")) {

    #Connect to the supplied domain
    $TargetDomain = Get-ADDomain -Identity $Domain
    

    #Obtain the domain FQDN
    $DomainFQDN = $TargetDomain.DNSRoot


    #Obtain the domain DN
    $DomainDN = $TargetDomain.DistinguishedName


    #Connect to the forest root domain
    $TargetForestRootDomain = (Get-ADForest -Server $DomainFQDN).RootDomain | Get-ADDomain
    

    #Obtain the forest FQDN
    $ForestFQDN = $TargetForestRootDomain.DNSRoot


    #Obtain the forest DN
    $ForestDN = $TargetForestRootDomain.DistinguishedName    

	
    #Create an empty array for our backups
	$Backups = @()

        #Determine the type of backup to be performed
	    if ($ModifiedDays) {

            #Get a list of
		    $ModGpos = Get-GPO -Domain $DomainFQDN -All | Where-Object {$_.ModificationTime -gt $Date.AddDays(-$ModifiedDays)}
            
            #Loop through each recently changed GPO and back it up, adding the resultant object to the $Backups array
            foreach ($ModGpo in $ModGpos) {

			    $Backups += Backup-GPO $ModGpo.DisplayName -Path $SubBackupFolder -Comment "Scripted backup created by $env:userdomain\$env:username on $ShortDate"
		    

            }   #end of foreach ($ModGpo in $ModGpos)

	    }   #end of if ($ModifiedDays)
        elseif ($GpoGuid) {

            #Backup single GPO
             $Backups = Backup-GPO -Guid $GpoGuid -Path $SubBackupFolder -Domain $DomainFQDN -Comment "Scripted backup created by $env:userdomain\$env:username on $ShortDate"

        }   #end of elseif ($GpoGuid)
	    else {
		    
		    #Backup all GPOs found in the domain
            $Backups = Backup-GPO -All -Path $SubBackupFolder -Domain $DomainFQDN -Comment "Scripted backup created by $env:userdomain\$env:username on $ShortDate"

		    
	    }   #end of else ($ModifiedDays)

	
        #Instantiate an object for Group Policy Management (GPMC required)
        try {

            $GPM = New-Object -ComObject GPMgmt.GPM
    
        }   #end of Try...
    
        catch {

            #Display exit message to console
            $Message = "ERROR: Unable to connect to GPMC. Please check that it is installed."
            Write-Host
            Write-Error $Message
  
            #Exit the script
            exit 1
    
        }   #end of Catch...


    #Import the GPM API constants
    $Constants = $GPM.getConstants()


    #Connect to the supplied domain
    $GpmDomain = $GPM.GetDomain($DomainFQDN,$Null,$Constants.UseAnyDc)

    
    #Connect to the sites container
    $GpmSites = $GPM.GetSitesContainer($ForestFQDN,$DomainFQDN,$Null,$Constants.UseAnyDc)
    

    ###################################
    ##COLLECT SPECIFIC GPO INFORMATION
    #Loop through each backed-up GPO
    foreach ($Backup in $Backups) {

        #Get the GPO GUID for our target GPO
        $GpoGuid = $Backup.GpoId


        #Get the backup GUID for our target GPO
        $BackupGuid = $Backup.Id
        

        #Instantiate an object for the relevant GPO using GPM
        $GPO = $GpmDomain.GetGPO("{$GpoGuid}")


        #Get the GPO DisplayName property
        $GpoName = $GPO.DisplayName

        #Get the GPO ID property
        $GpoID = $GPO.ID
	
            
		##Retrieve SOM Information
		#Create a GPM search criteria object
		$GpmSearchCriteria = $GPM.CreateSearchCriteria()


		#Configure search critera for SOM links against a GPO
		$GpmSearchCriteria.Add($Constants.SearchPropertySOMLinks,$Constants.SearchOpContains,$GPO)


		#Perform the search
		$SOMs = $GpmDomain.SearchSOMs($GpmSearchCriteria) + $GpmSites.SearchSites($GpmSearchCriteria)


		#Empty the SomPath variable
		$SomInfo = $Null

		
		#Loop through any SOMs returned and write them to a variable
		foreach ($SOM in $SOMs) {

			#Capture the SOM Distinguished Name
			$SomDN = $SOM.Path

		
			#Capture Block Inheritance state
			$SomInheritance = $SOM.GPOInheritanceBlocked

		
			#Get GPO Link information for the SOM
			$GpoLinks = $SOM.GetGPOLinks()


				#Loop through the GPO Link information and match info that relates to our current GPO
				foreach ($GpoLink in $GpoLinks) {
				
					if ($GpoLink.GPOID -eq $GpoID) {

						#Capture the GPO link status
						$LinkEnabled = $GpoLink.Enabled


						#Capture the GPO precedence order
						$LinkOrder = $GpoLink.SOMLinkOrder


						#Capture Enforced state
						$LinkEnforced = $GpoLink.Enforced


					}   #end of if ($GpoLink.GPOID -eq $GpoID)


				}   #end of foreach ($GpoLink in $GpoLinks)


			#Append the SOM DN, link status, link order and Block Inheritance info to $SomInfo
			[Array]$SomInfo += "$SomDN`:$SomInheritance`:$LinkEnabled`:$LinkOrder`:$LinkEnforced"
	
	
		}   #end of foreach ($SOM in $SOMs)...


        ##Obtain WMI Filter path using Get-GPO
        $Wmifilter = (Get-GPO -Guid $GpoGuid -Domain $DomainFQDN).WMifilter.Path
        
        #Split the value down and use the ID portion of the array
        #$WMifilter = ($Wmifilter -split "`"")[1]
        $WMifilter = ($Wmifilter -split '"')[1]



        #Add selected GPO properties to a custom GPO object
        $GpoInfo = [PSCustomObject]@{

                BackupGuid = $BackupGuid
                Name = $GpoName
                GpoGuid = $GpoGuid
                SOMs = $SomInfo
                DomainDN = $DomainDN
                Wmifilter = $Wmifilter
        
        }   #end of $Properties...

        
        #Add our new object to an array
        [Array]$TotalGPOs += $GpoInfo


    }   #end of foreach ($Backup in $Backups)...



    #####################
    ##BACKUP WMI FILTERS
    #Connect to the Active Directory to get details of the WMI filters
    $Wmifilters = Get-ADObject -Filter 'objectClass -eq "msWMI-Som"' `                               -Properties msWMI-Author, msWMI-ID, msWMI-Name, msWMI-Parm1, msWMI-Parm2 `                               -Server $DomainFQDN `                               -ErrorAction SilentlyContinue



    ######################
    ##CREATE REPORT FILES
    ##XML reports
    #Create a variable for the XML file representing custom information about the backed up GPOs
    $CustomGpoXML = "$SubBackupFolder\GpoDetails.xml"

    #Export our array of custom GPO objects to XML so they can be easily re-imported as objects
    $TotalGPOs | Export-Clixml -Path $CustomGpoXML

    #if $WMifilters contains objects write these to an XML file
    if ($Wmifilters) {

        #Create a variable for the XML file representing the WMI filters
        $WmiXML = "$SubBackupFolder\Wmifilters.xml"

        #Export our array of WMI filters to XML so they can be easily re-imported as objects
        $Wmifilters | Export-Clixml -Path $WmiXML

    }   #end of if ($Wmifilters)


    ##CSV report / HTML Settings reports
    #Create a variable for the CSV file that will contain the SOM (Scope of Management) information for each backed-up GPO
    $SOMReportCSV = "$SubBackupFolder\GpoInformation.csv"

    #Now, let's create the CSV report and the HTML settings reports
    foreach ($CustomGPO in $TotalGPOs) {
        
        ##CSV report stuff    
        #Start constructing the CSV file line entry for the current GPO
        $CSVLine = "`"$($CustomGPO.Name)`",`"{$($CustomGPO.GPOGuid)}`","


        #Expand the SOMs property of the current object
        $CustomSOMs = $CustomGPO.SOMs


            #Loop through any SOMs returned
            foreach ($CustomSOM in $CustomSOMs) {

                #Append the SOM path to our CSV line
                $CSVLine += "`"$CustomSOM`","

         
           }   #end of foreach ($CustomSOM in $CustomSOMs)...


       #Write the newly constructed CSV line to the report
       Add-Content -Path $SOMReportCSV -Value $CSVLine


       ##HTML settings report stuff
	   #Remove invalid characters from GPO display name
	   $GpoCleanedName = $CustomGPO.Name -replace "[^1-9a-zA-Z_]", "_"
	
       #Create path to html file
	   $ReportPath = "$SubBackupFolder\$HtmlReports\$($CustomGPO.BackupGuid)___$($CustomGPO.GpoGuid)__$($GpoCleanedName).html"
	
       #Create GPO report
       Get-GPOReport -Guid $CustomGPO.GpoGuid -Path $ReportPath -ReportType HTML 


    }   #end of foreach ($CustomGPO in $TotalGPOs)...



    ###########
    ##MIGTABLE
    #Check whether a migration table should be created
    if ($MigTable) {

        #Create a variable for the migration table
        $MigrationFile = "$SubBackupFolder\MigrationTable.migtable"

        #Create a migration table 
        $MigrationTable = $GPM.CreateMigrationTable()


        #Connect to the backup directory
        $GpmBackupDir = $GPM.GetBackUpDir($SubBackupFolder)

        #Reset the GPM search criterea
        $GpmSearchCriteria = $GPM.CreateSearchCriteria()


        #Configure search critera for the most recent backup
        $GpmSearchCriteria.Add($Constants.SearchPropertyBackupMostRecent,$Constants.SearchOpEquals,$True)
   

        #Get GPO information
        $BackedUpGPOs = $GpmBackupDir.SearchBackups($GpmSearchCriteria)


            #Add the information to our migration table
            foreach ($BackedUpGPO in $BackedUpGPOs) {

                $MigrationTable.Add($Constants.ProcessSecurity,$BackedUpGPO)
        
            }   #end of foreach ($BackedUpGPO in $BackedUpGPOs)...


        #Save the migration table
        $MigrationTable.Save($MigrationFile)


    }   #end of if ($MigTable)...


}   #end of if ((Test-Path -Path $SubBackupFolder) -and (Test-Path -Path "$SubBackupFolder\$HtmlReports"))...
else {

    #Write error
    Write-Error -Message "Backup path validation failed"


}   #end of ((Test-Path -Path $SubBackupFolder) -and (Test-Path -Path "$SubBackupFolder\$HtmlReports"))
