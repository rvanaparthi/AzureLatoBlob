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

$laQuery = $env:laQuery 

Write-Output $laQuery

$WorkspaceID = $env:WorkspaceID

$storageAccName = $env:storageAccName

$ContainerName = $env:ContainerName  

$appendqueryresults = $env:appendqueryresults

## Function to run Query and get Csv Data     
        
Function Query {  
       if($laQuery -like "*;*"){
           Write-Host "Running For Multiple Search Query"
           $lasplit = $laQuery.split(';')         
           Write-Output $lasplit
           $BlobNames += @()   
           foreach ($searchquery in $lasplit) { 
                        $Lastwords = $searchquery.split('|',[System.StringSplitOptions]::RemoveEmptyEntries)[-1]   ## To remove Pipe special charcter from Serch Query
                        $Filename = $Lastwords.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)[-1] ## To capture file name from the Search Query
                        $Blobfile = "$Filename.csv"
                        $BlobNames += "$Filename.csv"
                        
                        ## Containername 
                        $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
                        
                        ## BlobName
                        $Blob = $storageContainer | Get-AzureStorageBlob -Blob "$Blobfile" -ErrorAction Ignore | select Name      
                        
                        ## Compares Blobfilename with filename passed in search query as output        
                                  
                        if (($Blob.Name -eq "$Blobfile") -and ($appendqueryresults -eq "True")) {

                              ## Loops each blob in the container and gets content downloaded

                              foreach($filename in $Blob.Name){
                                  
                                      $storageContainer | Get-AzureStorageBlobContent  -Blob $filename -force
                                      
                                      Write-Output $filename

                                      ## Append Results to existing Csv Files
                                      
                                      $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$searchquery"
                                      $results.Results | Export-CSV -Append -Path "$filename" -NoTypeInformation
                                }
                              
                        }
                        else {
                                      ## Create a new CSV file with Results  

                                      Write-Output "$Filename"                                                                   
                                      $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$searchquery" 
                                      $results.Results | Export-CSV -Path "$Filename.csv" -NoTypeInformation

                        }

                        
                    
                      
                    }
            }
            else {

                    Write-Host "Running For Single Search Query"
                    
                    $Lastwords = $laQuery.split('|',[System.StringSplitOptions]::RemoveEmptyEntries)[-1]   ## To remove Pipe special charcters from Serch Query
                    $Filename = $Lastwords.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)[-1]   ## To capture file name from the Search Query
                    $Blobfile = "$Filename.csv"
                    $BlobNames += "$Filename.csv"
                    
                    ## Containername 
                    $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
                    
                    ## BlobName
                    $Blob = $storageContainer | Get-AzureStorageBlob -Blob "$Blobfile" -ErrorAction Ignore | select Name

                    ## Compares Blobfilename with filename passed in search query as output

                    if (($Blob.Name -eq "$Blobfile") -and ($appendqueryresults -eq "True")) {
                    
                                  $storageContainer | Get-AzureStorageBlobContent  -Blob $Blob.Name -force
                    
                                  ## Append Results to existing Csv Files
                    
                                  $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$laQuery"
                                  $results.Results | Export-CSV -Append -Path "$Blobfile" -NoTypeInformation
                              
                    }else {
                    
                                   ## Create a new CSV file with Results                             
                    
                                  $results = Invoke-AzureRmOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query "$laQuery" 
                                  $results.Results | Export-CSV -Path "$Filename.csv" -NoTypeInformation

                    }

            }

            foreach ($BlobFileName in $BlobNames)
            {
               ## Uploading the files generated to blob storage base on Output name passed in search query

               Write-Host $BlobFileName
               $storageContainer = Get-AzureRmStorageAccount | where {$_.StorageAccountName -eq "$storageAccName"} | Get-AzureStorageContainer $ContainerName
               $BlobName = ''
               $storageContainer | Set-AzureStorageBlobContent –File $BlobFileName –Blob $BlobName -Force
               Write-Host "LatoBlob finished uploading $BlobFileName to Azure Blob Storage at TIME: $currentUTCtime"
          
            }   


           
 
 
 }
      

# Run a function to Get the Data into csv and upload to storage

Query


## Disconnect Az Account
Disconnect-AzAccount

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
