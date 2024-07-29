targetScope = 'managementGroup'

param functionUserAssignedIdentityResourceId string
param storageAccountResourceId string
param storageAccountContainerName string
param fileName string = 'discover'
param galleryResourceId string
param galleryApplicationName string = 'windiscovery'
param location string
param solutionTag string
param assignmentLevel string
param packsUserAssignedIdentityResourceId string
param subscriptionId string
param dataCollectionEndpointResourceId string
param tags object
param tableName string
param logAnalyticsResourceId string
param packtag string = 'WinDisc'
param instanceName string

param time string = utcNow()

var streamName = 'Custom-${tableName}'

var accountSasRequestBody = {
  signedServices: 'b'
  signedResourceTypes: 'sco'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(time, 'PT1H')
}

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

module windowsDiscoveryZipUpload 'br/public:avm/res/resources/deployment-script:0.2.4' = {
  name: 'windowsDiscoveryZipUpload'
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
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
      $DeploymentScriptOutputs = @{
        blobUri = $Blob.ICloudBlob.Uri.AbsoluteUri
      }
      Write-Output 'Discovery data uploaded to storage account'
    '''
  }
}

module galleryApplicationVersion 'gallery-application-version.bicep' = {
  scope: resourceGroup(split(galleryResourceId, '/')[2], split(galleryResourceId, '/')[4])
  name: 'win-discovery-app-version'
  params: {
    galleryApplicationName: galleryApplicationName
    galleryResourceId: galleryResourceId
    installCommand: 'powershell -command "ren windiscovery ${fileName}.zip; expand-archive ./${fileName}.zip . ; ./install.ps1"'
    location: location
    mediaLink: '${windowsDiscoveryZipUpload.outputs.outputs.blobUri}?${storageAccount.listAccountSas(storageAccount.apiVersion, accountSasRequestBody).accountSasToken}'
    packageFileName: '${fileName}.zip'
    removeCommand: 'powershell -command "Unregister-ScheduledTask -TaskName \'Monstar Packs Discovery\' \'\\\'"'
  }
}

module applicationPolicy 'vm-application-policy.bicep' = {
  name: 'win-discovery-app-policy'
  params: {
    packtag: packtag
    packtype: 'Discovery'
    policyDescription: 'Install ${galleryApplicationName} to Windows VMs'
    policyDisplayName: 'Install ${galleryApplicationName} to Windows VMs'
    policyName: 'Onboard-${galleryApplicationName}-VMs'
    solutionTag: solutionTag
    vmapplicationResourceId: galleryApplicationVersion.outputs.resourceId
  }
}

module applicationPolicyAssignment 'br/public:avm/ptn/authorization/policy-assignment:0.1.1' = {
  name: 'win-discovery-app-policy-assignment-${assignmentLevel =~ 'ManagementGroup' ? 'mg' : 'sub'}'
  params: {
    displayName: 'Windows AMP ${galleryApplicationName}'
    name: 'win-amp-app-${assignmentLevel =~ 'ManagementGroup' ? 'mg' : 'sub'}'
    policyDefinitionId: applicationPolicy.outputs.resourceId
    managementGroupId: managementGroup().name
    subscriptionId: assignmentLevel =~ 'ManagementGroup' ? '' : subscriptionId
    enableTelemetry: false
    identity: 'UserAssigned'
    userAssignedIdentityId: packsUserAssignedIdentityResourceId
  }
}

module dataCollectionRule 'br/public:avm/res/insights/data-collection-rule:0.1.3' = {
  scope: resourceGroup(split(dataCollectionEndpointResourceId, '/')[2], split(dataCollectionEndpointResourceId, '/')[4])
  name: 'win-discovery-dcr'
  params: {
    name: 'win-discovery-dcr'
    kind: 'Windows'
    dataFlows: [
      {
        streams: [
          streamName
        ]
        destinations: [
          split(logAnalyticsResourceId, '/')[8]
        ]
        transformKql: 'source'
        outputStream: 'Custom-${tableName}'
      }
    ]
    dataSources: {
      logFiles: [
        {
          streams: [
            streamName
          ]
          filePatterns: [
            'C:\\WindowsAzure\\Discovery\\*.csv'
          ]
          format: 'text'
          settings: {
            text: {
              recordStartTimestampFormat: 'ISO 8601'
            }
          }
          name: tableName
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsResourceId
          name: split(logAnalyticsResourceId, '/')[8]
        }
      ]
    }
    dataCollectionEndpointId: dataCollectionEndpointResourceId
    streamDeclarations: {
      '${streamName}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'RawData'
            type: 'string'
          }
        ]
      }
    }
    enableTelemetry: false
    tags: tags
  }
}

module dataCollectionRuleAssociationPolicy 'vm-association-policy.bicep' = {
  name: 'win-discovery-dcr-association-policy'
  params: {
    dataCollectionRuleResourceId: dataCollectionRule.outputs.resourceId
    instanceName: instanceName
    packtag: packtag
    packtype: 'Discovery'
    policyDescription: 'Policy to associate ${dataCollectionRule.outputs.name} with Windows VMs tagged with ${packtag} tag'
    policyDisplayName: 'Associate ${dataCollectionRule.outputs.name} with Windows VMs tagged with ${packtag} tag'
    policyName: 'Associate-${dataCollectionRule.outputs.name}-${packtag}-vms'
    solutionTag: solutionTag
  }
}

module dataCollectionRuleAssociationPolicyAssignment 'br/public:avm/ptn/authorization/policy-assignment:0.1.1' = {
  name: 'win-discovery-dcr-association-policy-assignment-${assignmentLevel =~ 'ManagementGroup' ? 'mg' : 'sub'}'
  params: {
    displayName: 'Windows AMP ${dataCollectionRule.outputs.name}'
    name: 'win-amp-dcr-assoc-${assignmentLevel =~ 'ManagementGroup' ? 'mg' : 'sub'}'
    policyDefinitionId: dataCollectionRuleAssociationPolicy.outputs.resourceId
    managementGroupId: managementGroup().name
    subscriptionId: assignmentLevel =~ 'ManagementGroup' ? '' : subscriptionId
    enableTelemetry: false
    identity: 'UserAssigned'
    userAssignedIdentityId: packsUserAssignedIdentityResourceId
  }
}
