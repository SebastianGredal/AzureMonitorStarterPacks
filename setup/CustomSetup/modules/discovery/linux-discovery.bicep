targetScope = 'managementGroup'

param functionUserAssignedIdentityResourceId string
param storageAccountResourceId string
param storageAccountContainerName string
param fileName string = 'discover'
param galleryResourceId string
param galleryApplicationName string = 'linuxdiscovery'
param location string
param solutionTag string
param assignmentLevel string
param packsUserAssignedIdentityResourceId string
param subscriptionId string
param dataCollectionEndpointResourceId string
param tags object
param tableName string
param logAnalyticsResourceId string
param packtag string = 'LxDisc'
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

module linuxDiscoveryZipUpload 'br/public:avm/res/resources/deployment-script:0.2.4' = {
  name: 'linuxDiscoveryZipUpload'
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
  params: {
    managedIdentities: {
      userAssignedResourcesIds: [
        functionUserAssignedIdentity.id
      ]
    }
    kind: 'AzurePowerShell'
    azPowerShellVersion: '12.0'
    name: 'linuxDiscoveryZipUpload'
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
          value: loadFileAsBase64('../../../discovery/Linux/discover.tar')
        }
      ]
    }
    scriptContent: '''
      $Location = Get-Location
      $FileName = $Location.Path + "/$($env:FileName).tar"
      $Bytes = [System.Convert]::FromBase64String($env:CONTENT)
      [System.IO.File]::WriteAllBytes($FileName, $Bytes)

      $StorageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResourceGroupName -Name $env:StorageAccountName
      $BlobSplat = @{
        File = $FileName
        Container = $env:ContainerName
        Blob = $env:FileName + '.tar'
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
  name: 'linux-discovery-app-version'
  scope: resourceGroup(split(galleryResourceId, '/')[2], split(galleryResourceId, '/')[4])
  params: {
    location: location
    galleryApplicationName: galleryApplicationName
    galleryResourceId: galleryResourceId
    installCommand: 'tar -xvf ${galleryApplicationName} && chmod +x ./install.sh && ./install.sh'
    mediaLink: '${linuxDiscoveryZipUpload.outputs.outputs.blobUri}?${storageAccount.listAccountSas(storageAccount.apiVersion, accountSasRequestBody).accountSasToken}'
    packageFileName: 'discover.tar'
    removeCommand: '/opt/microsoft/discovery/uninstall.sh'
  }
}

module applicationPolicy 'vm-application-policy.bicep' = {
  name: 'linux-discovery-app-policy'
  params: {
    packtag: packtag
    packtype: 'Discovery'
    policyDescription: 'Install ${galleryApplicationName} to Linux VMs'
    policyDisplayName: 'Install ${galleryApplicationName} to Linux VMs'
    policyName: 'Onboard-${galleryApplicationName}-VMs'
    roledefinitionIds: [
      '/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
    ]
    solutionTag: solutionTag
    vmapplicationResourceId: galleryApplicationVersion.outputs.resourceId
  }
}

module applicationPolicyAssignment 'br/public:avm/ptn/authorization/policy-assignment:0.1.1' = {
  name: 'linux-discovery-app-policy-assignment-${assignmentLevel == 'managementGroup' ? 'mg' : 'sub'}'
  params: {
    displayName: 'Linux AMP ${galleryApplicationName}'
    name: 'linux-amp-app-${assignmentLevel == 'managementGroup' ? 'mg' : 'sub'}'
    policyDefinitionId: applicationPolicy.outputs.resourceId
    managementGroupId: managementGroup().name
    subscriptionId: assignmentLevel == 'managementGroup' ? '' : subscriptionId
    enableTelemetry: false
    identity: 'UserAssigned'
    userAssignedIdentityId: packsUserAssignedIdentityResourceId
  }
}

module dataCollectionRule 'br/public:avm/res/insights/data-collection-rule:0.1.3' = {
  scope: resourceGroup(split(dataCollectionEndpointResourceId, '/')[2], split(dataCollectionEndpointResourceId, '/')[4])
  name: 'linux-discovery-dcr'
  params: {
    name: 'linux-discovery-dcr'
    kind: 'Linux'
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
            '/opt/microsoft/discovery/*.csv'
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
  name: 'linux-discovery-dcr-association-policy'
  params: {
    dataCollectionRuleResourceId: dataCollectionRule.outputs.resourceId
    instanceName: instanceName
    packtag: packtag
    packtype: 'Discovery'
    policyDescription: 'Policy to associate ${dataCollectionRule.outputs.name} with Linux VMs tagged with ${packtag} tag'
    policyDisplayName: 'Associate ${dataCollectionRule.outputs.name} with Linux VMs tagged with ${packtag} tag'
    policyName: 'Associate-${dataCollectionRule.outputs.name}-${packtag}-vms'
    solutionTag: solutionTag
  }
}

module dataCollectionRuleAssociationPolicyAssignment 'br/public:avm/ptn/authorization/policy-assignment:0.1.1' = {
  name: 'linux-discovery-dcr-association-policy-assignment-${assignmentLevel == 'managementGroup' ? 'mg' : 'sub'}'
  params: {
    displayName: 'Linux AMP ${dataCollectionRule.outputs.name}'
    name: 'linux-amp-dcr-assoc-${assignmentLevel == 'managementGroup' ? 'mg' : 'sub'}'
    policyDefinitionId: dataCollectionRuleAssociationPolicy.outputs.resourceId
    managementGroupId: managementGroup().name
    subscriptionId: assignmentLevel == 'managementGroup' ? '' : subscriptionId
    enableTelemetry: false
    identity: 'UserAssigned'
    userAssignedIdentityId: packsUserAssignedIdentityResourceId
  }
}
