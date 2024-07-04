targetScope = 'subscription'

param resourceGroupName string
param storageAccountConfig storageAccountType
param location string
param tags object

var createStorageAccount = storageAccountConfig.createMode == 'default'

var id = createStorageAccount ? storageAccountCreate.outputs.storageAccountResourceId : storageAccountExisting.id
var name = createStorageAccount ? storageAccountCreate.outputs.storageAccountName : storageAccountExisting.name

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module storageAccountCreate '../../backend/code/modules/mg/storageAccount.bicep' = if (createStorageAccount) {
  name: 'storageAccount'
  scope: rg
  params: {
    location: location
    Tags: tags
    storageAccountName: storageAccountConfig.name
  }
}

resource storageAccountExisting 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (!createStorageAccount) {
  scope: rg
  name: storageAccountConfig.name
}

output resourceId string = id
output name string = name

type storageAccountType = {
  createMode: 'default' | 'existing'
  name: string
}
