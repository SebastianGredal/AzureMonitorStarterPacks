param logAnalyticsName string
param tableName string
param retentionDays int = 31

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

resource table 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: tableName
  parent: logAnalytics
  properties: {
    totalRetentionInDays: retentionDays
    plan: 'Analytics'
    schema: {
      name: tableName
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
    retentionInDays: retentionDays
  }
}

output resourceId string = table.id
output tableName string = table.name
