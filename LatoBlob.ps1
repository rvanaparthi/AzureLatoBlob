# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

## Connect to AzAccount 

Connect-AzAccount -Identity

## Parameters to run log analytics query

$laQuery = "MyRec_CL | where TimeGenerated > ago(7d) | as LaData;MyRec_CL | where TimeGenerated > ago(7d) | summarize  count() by IPAddress | as LaDataIps" 

$WorkspaceID = "Add Workspace ID of Log Analytics"

$storageAccName="StorageAccountName"

$ContainerName="ContainerName"  

## Function to run Query and get Csv Data             
Function Query {  
       if($laQuery -like "*;*"){
           Write-Host "Running For Multiple Search Query"
           $lasplit = $laQuery.split(';')         
           $BlobNames += @()   
           foreach ($searchquery in $lasplit) { 
                        $Lastwords = $searchquery.split('|')[-1]   ## To remove Pipe special charcters from Serch Query
                        $Filename = $Lastwords.split(' ')[-1] ## To capture file name from the Search Query
                        $Blobfile = "$Filename.csv"
                        $BlobNames += "$Filename.csv"
                        
                        ## Containername 
                        $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
                        
                        ## BlobName
                        $Blob = $storageContainer | Get-AzureStorageBlob -Blob "$Blobfile" -ErrorAction Ignore | select Name      
                        
                        ## Compares filename with Blob name                  
                        if ($Blob.Name -eq "$Blobfile") {
                              ## Loops each blob and gets content
                              foreach($Blobs in $Blob.Name){
                                  
                                      $storageContainer | Get-AzureStorageBlobContent  -Blob $Blobs -force
                                      Write-Output $Blobs

                                      ## Append Results to existing Csv Files
                                      $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$searchquery"
                                      $results.Results | Export-CSV -Append -Path "$Blobs" -NoTypeInformation
                                }
                              
                        }
                        else {
                                      ## Results to Csv Files new file will be created

                                      Write-Output "$Filename"                                
                                      $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$searchquery" 
                                      $results.Results | Export-CSV -Path "$Filename.csv" -NoTypeInformation

                        }

                        
                    
                      
                    }
            }
            else {

                    Write-Host "Running For Single Search Query"
                    
                    $Lastwords = $laQuery.split('|')[-1]   ## To remove Pipe special charcters from Serch Query
                    $Filename = $Lastwords.split(' ')[-1]   ## To capture file name from the Search Query
                    $Blobfile = "$Filename.csv"
                    $BlobNames += "$Filename.csv"
                    
                    ## Containername 
                    $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
                    
                    ## BlobName
                    $Blob = $storageContainer | Get-AzureStorageBlob -Blob "$Blobfile" -ErrorAction Ignore | select Name

                    ## Compares filename with Blob name
                    if ($Blob.Name -eq "$Blobfile") {
                    
                                  $storageContainer | Get-AzureStorageBlobContent  -Blob $Blob.Name -force
                                  ## Append Results to existing Csv Files
                                  $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$laQuery"
                                  $results.Results | Export-CSV -Append -Path "$Blobfile" -NoTypeInformation
                              
                    }else {
                                  ## Results to Csv Files, a new file will be created ad will upload to storage                             
                                  $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$laQuery" 
                                  $results.Results | Export-CSV -Path "$Filename.csv" -NoTypeInformation

                    }

            }

            foreach ($BlobFileName in $BlobNames)
            {
               ## Uploading the files generated to blob storage base on Output files
               Write-Host $BlobFileName
               $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
               $BlobName = ''
               $storageContainer | Set-AzureStorageBlobContent –File $BlobFileName –Blob $BlobName -Force
          
            }   


           
 
 
 }
      

# Run a function to Get the Data into csv and upload to storage

Query


## Disconnect Az Account
Disconnect-AzAccount

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
