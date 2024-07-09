targetScope = 'subscription'

param resourceGroupName string
param logAnalyticsConfig logAnalyticsType
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.3.5' = {
  scope: rg
  name: 'logAnalytics'
  params: {
    name: logAnalyticsConfig.name
    location: location
    tags: tags
  }
}

output resourceId string = logAnalytics.outputs.resourceId
output name string = logAnalytics.outputs.name

type logAnalyticsType = {
  name: string
}
