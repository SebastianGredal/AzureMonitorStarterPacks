targetScope = 'subscription'

param resourceGroupName string
param logAnalyticsConfig logAnalyticsType
param location string
param tags object

var createLogAnalytics = logAnalyticsConfig.createMode == 'default'

var id = createLogAnalytics ? logAnalyticsCreate.outputs.lawresourceid : logAnalyticsExisting.outputs.resourceId
var name = createLogAnalytics ? logAnalyticsConfig.name : logAnalyticsExisting.outputs.name

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module logAnalyticsCreate '../../../modules/LAW/law.bicep' = if (createLogAnalytics) {
  name: 'logAnalytics-Deployment'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: logAnalyticsConfig.name
    Tags: tags
    createNewLogAnalyticsWS: true
  }
}

module logAnalyticsExisting 'logAnalyticsExisting.bicep' = if (!createLogAnalytics) {
  name: 'logAnalyticsExisting'
  params: {
    logAnalyticsResourceId: logAnalyticsConfig.resourceId
  }
}

output resourceId string = id
output name string = name

type LogAnalyticsDefaultType = {
  createMode: 'default'
  name: string
}
type LogAnalyticsExistingType = {
  createMode: 'existing'
  resourceId: string
}
@discriminator('createMode')
type logAnalyticsType = LogAnalyticsDefaultType | LogAnalyticsExistingType
