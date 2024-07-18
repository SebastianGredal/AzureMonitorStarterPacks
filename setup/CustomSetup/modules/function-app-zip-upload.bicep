param functionAppResourceId string
param storageAccountResourceId string

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: split(functionAppResourceId, '/')[8]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: split(storageAccountResourceId, '/')[8]
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
}

resource deployFunctions 'Microsoft.Web/sites/extensions@2023-12-01' = {
  parent: functionApp
  name: 'ZipDeploy'
  properties: {
    packageUri: ''
  }
}
