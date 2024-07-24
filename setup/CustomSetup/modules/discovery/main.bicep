targetScope = 'managementGroup'

param logAnalyticsResourceId string
param functionUserAssignedIdentityResourceId string
param storageAccountResourceId string
param storageAccountContainerName string
param tableName string = 'Discovery'
param resourceGroupId string
param galleryName string
param location string
param tags object
param solutionTag string
param packsUserAssignedIdentityResourceId string
param assignmentLevel string
param subscriptionId string
param dataCollectionEndpointResourceId string
param instanceName string

var tableNameFormat = contains(tableName, '_CL') ? tableName : '${tableName}_CL'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: split(resourceGroupId, '/')[4]
  scope: subscription(split(resourceGroupId, '/')[2])
}

module discoveryTable 'log-analytics-table.bicep' = {
  scope: resourceGroup(split(logAnalyticsResourceId, '/')[2], split(logAnalyticsResourceId, '/')[4])
  name: '${tableName}-table'
  params: {
    logAnalyticsName: split(logAnalyticsResourceId, '/')[8]
    tableName: tableNameFormat
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

module windowsDiscovery 'windows-discovery.bicep' = {
  name: 'windowsDiscovery'
  params: {
    functionUserAssignedIdentityResourceId: functionUserAssignedIdentityResourceId
    solutionTag: solutionTag
    packsUserAssignedIdentityResourceId: packsUserAssignedIdentityResourceId
    assignmentLevel: assignmentLevel
    galleryResourceId: gallery.outputs.resourceId
    storageAccountContainerName: storageAccountContainerName
    storageAccountResourceId: storageAccountResourceId
    location: location
    galleryApplicationName: 'windiscovery'
    fileName: 'discover'
    dataCollectionEndpointResourceId: dataCollectionEndpointResourceId
    logAnalyticsResourceId: logAnalyticsResourceId
    subscriptionId: subscriptionId
    tableName: discoveryTable.outputs.tableName
    tags: tags
    instanceName: instanceName
  }
}

module linuxDiscovery 'linux-discovery.bicep' = {
  name: 'linuxDiscovery'
  params: {
    location: location
    tags: tags
    assignmentLevel: assignmentLevel
    dataCollectionEndpointResourceId: dataCollectionEndpointResourceId
    functionUserAssignedIdentityResourceId: functionUserAssignedIdentityResourceId
    galleryResourceId: gallery.outputs.resourceId
    instanceName: instanceName
    logAnalyticsResourceId: logAnalyticsResourceId
    packsUserAssignedIdentityResourceId: packsUserAssignedIdentityResourceId
    solutionTag: solutionTag
    storageAccountContainerName: storageAccountContainerName
    storageAccountResourceId: storageAccountResourceId
    subscriptionId: subscriptionId
    tableName: discoveryTable.outputs.tableName
  }
}

output imageGalleryResourceId string = gallery.outputs.resourceId
output imageGalleryName string = gallery.outputs.name
