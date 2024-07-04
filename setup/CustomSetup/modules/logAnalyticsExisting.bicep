targetScope = 'subscription'

param logAnalyticsResourceId string

var logAnalyticsSplit = split(logAnalyticsResourceId, '/')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: resourceGroup(logAnalyticsSplit[2], logAnalyticsSplit[4])
  name: logAnalyticsSplit[8]
}

output resourceId string = logAnalytics.id
output name string = logAnalytics.name
