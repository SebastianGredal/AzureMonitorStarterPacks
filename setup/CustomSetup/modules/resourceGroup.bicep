targetScope = 'subscription'

param resourceGroupConfig resourceGroupType
param location string
param tags object

var createResourceGroup = resourceGroupConfig.createMode == 'default'
var resourceId = createResourceGroup ? resourceGroupCreate.outputs.resourceId : resourceGroupExisting.id
var name = createResourceGroup ? resourceGroupCreate.outputs.name : resourceGroupExisting.name

module resourceGroupCreate 'br/public:avm/res/resources/resource-group:0.2.4' = if (createResourceGroup) {
  name: 'resourceGroup'
  params: {
    name: resourceGroupConfig.name
    enableTelemetry: false
    location: location
    tags: tags
  }
}

resource resourceGroupExisting 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!createResourceGroup) {
  name: resourceGroupConfig.name
}

output resourceId string = resourceId
output name string = name

type resourceGroupType = {
  createMode: 'default' | 'existing'
  name: string
}
