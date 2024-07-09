targetScope = 'subscription'

param resourceGroupName string
param storageAccountConfig storageAccountType
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = {
  scope: rg
  name: 'storageAccount'
  params: {
    name: storageAccountConfig.name
    skuName: 'Standard_LRS'
    location: location
    tags: tags
    kind: 'StorageV2'
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    requireInfrastructureEncryption: true
    blobServices: {
      deleteRetentionPolicyEnabled: false
      containers: [
        {
          name: 'discovery'
          immutableStorageWithVersioningEnabled: false
          publicAccess: 'None'
        }
        {
          name: 'applications'
          immutableStorageWithVersioningEnabled: false
          publicAccess: 'None'
        }
      ]
    }
  }
}

output resourceId string = storageAccount.outputs.resourceId
output name string = storageAccount.outputs.name

type storageAccountType = {
  name: string
}
