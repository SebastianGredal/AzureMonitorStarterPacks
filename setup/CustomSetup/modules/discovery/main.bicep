targetScope = 'managementGroup'

param logAnalyticsResourceId string
param tableName string = 'Discovery'
param resourceGroupId string
param galleryName string
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: split(resourceGroupId, '/')[4]
  scope: subscription(split(resourceGroupId, '/')[2])
}

module discoveryTable 'log-analytics-table.bicep' = {
  scope: resourceGroup(split(logAnalyticsResourceId, '/')[2], split(logAnalyticsResourceId, '/')[4])
  name: '${tableName}-table'
  params: {
    logAnalyticsName: split(logAnalyticsResourceId, '/')[8]
    tableName: tableName
    retentionDays: 31
  }
}

module gallery 'br/public:avm/res/compute/gallery:0.5.0' = {
  scope: rg
  name: 'gallery'
  params: {
    applications: [
      {
        name: 'windiscovery'
        supportedOSType: 'Windows'
        description: 'Windows Workload discovery'
      }
      {
        name: 'linuxdiscovery'
        supportedOSType: 'Linux'
        description: 'Linux Workload discovery'
      }
    ]
    name: galleryName
    enableTelemetry: false
    location: location
    tags: tags
  }
}
