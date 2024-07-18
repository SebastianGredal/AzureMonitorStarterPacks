param functionUserAssignedIdentityResourceId string
param storageAccountResourceId string
param storageAccountContainerName string
param fileName string = 'discover'
param galleryResourceId string
param galleryApplicationName string = 'windiscovery'
param location string = resourceGroup().location

resource functionUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: split(functionUserAssignedIdentityResourceId, '/')[8]
  scope: resourceGroup(
    split(functionUserAssignedIdentityResourceId, '/')[2],
    split(functionUserAssignedIdentityResourceId, '/')[4]
  )
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: split(storageAccountResourceId, '/')[8]
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: storageAccountContainerName
  parent: storageAccountBlobService
}

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: split(galleryResourceId, '/')[8]
}

resource galleryApplication 'Microsoft.Compute/galleries/applications@2023-07-03' existing = {
  name: galleryApplicationName
  parent: gallery
}

module windowsDiscoveryZipUpload 'br/public:avm/res/resources/deployment-script:0.2.4' = {
  name: 'windowsDiscoveryZipUpload'
  params: {
    managedIdentities: {
      userAssignedResourcesIds: [
        functionUserAssignedIdentity.id
      ]
    }
    kind: 'AzurePowerShell'
    azPowerShellVersion: '12.0'
    name: 'windowsDiscoveryZipUpload'
    timeout: 'PT5M'
    cleanupPreference: 'Always'
    enableTelemetry: false
    environmentVariables: {
      secureList: [
        {
          name: 'ResourceGroupName'
          value: split(storageAccountResourceId, '/')[4]
        }
        {
          name: 'StorageAccountName'
          value: storageAccount.name
        }
        {
          name: 'ContainerName'
          value: storageAccountContainer.name
        }
        {
          name: 'FileName'
          value: fileName
        }
        {
          name: 'CONTENT'
          value: loadFileAsBase64('../../../discovery/Windows/discover.zip')
        }
      ]
    }
    scriptContent: '''
      $Location = Get-Location
      $FileName = $Location.Path + "/$($env:FileName).zip"
      $Bytes = [System.Convert]::FromBase64String($env:CONTENT)
      [System.IO.File]::WriteAllBytes($FileName, $Bytes)

      $StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResourceGroupName -Name $env:StorageAccountName
      $BlobSplat = @{
        File = $FileName
        Container = $env:ContainerName
        Blob = $env:FileName + '.zip'
        Context = $StorageAccount.Context
      }
      $Blob = Set-AzStorageBlobContent @BlobSplat -ErrorAction Stop -Force
      $DeploymentScriptOutput = @{
        BlobUri = $Blob.ICloudBlob.Uri.AbsoluteUri
      }
      Write-Output 'Discovery data uploaded to storage account'
    '''
  }
}

resource galleryApplicationVersion 'Microsoft.Compute/galleries/applications/versions@2023-07-03' = {
  name: '1.0.0'
  location: location
  parent: galleryApplication
  properties: {
    publishingProfile: {
      source: {
        mediaLink: windowsDiscoveryZipUpload.outputs.outputs.BlobUri
      }
      manageActions: {
        install: 'powershell -command "ren windiscovery discover.zip; expand-archive ./discover.zip . ; ./install.ps1"'
        remove: 'powershell -command "Unregister-ScheduledTask -TaskName \'Monstar Packs Discovery\' \'\\\'"'
      }
      settings: {
        packageFileName: '${fileName}.zip'
      }
      enableHealthCheck: false
      targetRegions: [
        {
          name: location
          regionalReplicaCount: 1
          storageAccountType: 'Standard_LRS'
        }
      ]
      replicaCount: 1
      excludeFromLatest: false
      storageAccountType: 'Standard_LRS'
    }
  }
}
