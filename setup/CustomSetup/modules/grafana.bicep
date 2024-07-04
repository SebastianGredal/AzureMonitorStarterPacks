targetScope = 'subscription'

param resourceGroupName string
param grafanaConfig grafanaType
param location string
param tags object
param solutionTag string

var createGrafana = grafanaConfig.createMode == 'default'

var id = createGrafana ? grafanaCreate.outputs.grafanaId : grafanaExisting.id
var name = createGrafana ? grafanaConfig.name : grafanaExisting.name

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module grafanaCreate '../../backend/code/modules/grafana.bicep' = if (createGrafana) {
  name: 'azureManagedGrafana'
  scope: rg
  params: {
    Tags: tags
    location: grafanaConfig.?location ?? location
    grafanaName: grafanaConfig.name
    solutionTag: solutionTag
    //userObjectId: currentUserIdObject
    //lawresourceId: createNewLogAnalyticsWS ? logAnalytics.outputs.lawresourceid : existingLogAnalyticsWSId
  }
}

resource grafanaExisting 'Microsoft.Dashboard/grafana@2023-09-01' existing = {
  scope: rg
  name: grafanaConfig.name
}

output resourceId string = id
output name string = name

type grafanaType = {
  location: string?
  name: string
  createMode: 'default' | 'existing'
}
