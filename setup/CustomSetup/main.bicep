targetScope = 'managementGroup'

param _artifactsLocation string = 'https://raw.githubusercontent.com/JCoreMS/AzureMonitorStarterPacks/AVDMerge/'
@secure()
param _artifactsLocationSasToken string = ''

param subscriptionId string

param resourceGroupConfig resourceGroupType = {
  name: 'rg-amp-${instanceName}'
  createMode: 'default'
}

param logAnalyticsConfig logAnalyticsType = {
  name: 'law-amp-${instanceName}'
  createMode: 'default'
}

param grafanaConfig grafanaType = {
  name: 'grafana-amp-${instanceName}'
  createMode: 'default'
  location: location
}

param storageAccountConfig storageAccountType = {
  name: 'saamp${instanceName}'
  createMode: 'default'
}

param keyVaultConfig keyVaultType = {
  createMode: 'default'
  name: 'kv-amp-${instanceName}'
}

param location string = deployment().location
param assignmentLevel assignmentLevelType = 'managementGroup'

param instanceName string
param appInsightsLocationOveride string = location

// Packs stuff
param actionGroupConfig actionGroupType = {
  name: 'ag-amp-${instanceName}'
  emailReceiver: ''
  emailReceiversEmail: ''
  createMode: 'default'
}

param tags object

param packs packsType = [
  'all'
]
param deployDiscovery bool = false
param functionAppName string = 'func-amp-${instanceName}'
param logicAppName string = 'logic-amp-${instanceName}'
param galleryName string = 'galamp${instanceName}'

param packsUserAssignedIdentityName string = 'id-packs'
param functionUserAssignedIdentityName string = 'id-func'

var solutionTag = 'MonitorStarterPacks'
var solutionTagComponents = 'MonitorStarterPacksComponents'
var solutionVersion = '0.1'
var tempTags = {
  '${solutionTagComponents}': 'BackendComponent'
  solutionVersion: solutionVersion
  instanceName: instanceName
}
var unionTags = empty(tags) ? tempTags : union(tempTags, tags)

var deployIaaSPack = contains(packs, 'all') || contains(packs, 'iaas')
var deployPaaSPack = contains(packs, 'all') || contains(packs, 'paas')
var deployPlatformPack = contains(packs, 'all') || contains(packs, 'platform')

module rg 'br/public:avm/res/resources/resource-group:0.2.4' = {
  scope: subscription(subscriptionId)
  name: 'resourceGroup-deployment'
  params: {
    name: resourceGroupConfig.name
    location: location
    tags: unionTags
  }
}

module core 'modules/core.bicep' = {
  name: 'core-deployment'
  params: {
    actionGroupConfig: actionGroupConfig
    functionUserAssignedIdentityName: functionUserAssignedIdentityName
    grafanaConfig: grafanaConfig
    keyVaultConfig: keyVaultConfig
    location: location
    logAnalyticsConfig: logAnalyticsConfig
    packsUserAssignedIdentityName: packsUserAssignedIdentityName
    resourceGroupName: rg.outputs.name
    solutionTag: solutionTag
    storageAccountConfig: storageAccountConfig
    subscriptionId: subscriptionId
    tags: unionTags
  }
}

// deployment of AMA Policies should be handled by epac
//param deployAMApolicy bool
// module AMAPolicy '../AMAPolicy/amapoliciesmg.bicep' = if (deployAMApolicy) {
//   name: 'DeployAMAPolicy'
//   params: {
//     assignmentLevel: assignmentLevel
//     location: location
//     resourceGroupName: rg.outputs.name
//     solutionTag: solutionTagComponents
//     solutionVersion: solutionVersion
//     subscriptionId: subscriptionId
//     Tags: unionTags
//   }
// }

// module discovery '../discovery/discovery.bicep' = if (deployDiscovery) {
//   name: 'DeployDiscovery-${instanceName}'
//   params: {
//     assignmentLevel: assignmentLevel
//     location: location
//     resourceGroupName: rg.outputs.name
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     subscriptionId: subscriptionId
//     dceId: backend.outputs.dataCollectionEndpointResourceId
//     imageGalleryName: core.outputs.galleryResourceId
//     lawResourceId: core.outputs.logAnalyticsResourceId
//     mgname: managementGroup().name
//     storageAccountname: core.outputs.storageAccountResourceId
//     tableName: 'Discovery'
//     userManagedIdentityResourceId: core.outputs.packsUserAssignedIdentityResourceId
//     Tags: unionTags
//     instanceName: instanceName
//   }
// }

// BACKEND
module backend 'modules/backend.bicep' = {
  name: 'monitoringPacks-backend'
  scope: subscription(subscriptionId)
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appInsightsLocation: appInsightsLocationOveride
    functionAppName: functionAppName
    functionUserAssignedIdentityResourceId: core.outputs.functionUserAssignedIdentityResourceId
    instanceName: instanceName
    keyVaultResourceId: core.outputs.keyVaultResourceId
    location: location
    logicAppName: logicAppName
    packsUserAssignedIdentityResourceId: core.outputs.packsUserAssignedIdentityResourceId
    resourceGroupName: rg.outputs.name
    solutionTag: solutionTag
    storageAccountResourceId: core.outputs.storageAccountResourceId
    tags: unionTags
    workspaceResourceId: core.outputs.logAnalyticsResourceId
  }
}

// module iaasPack '../../Packs/IaaS/AllIaaSPacks.bicep' = if (deployIaaSPack) {
//   name: 'deployIaaSPack'
//   params: {
//     location: location
//     actionGroupResourceId: actionGroupCreate ? actionGroup.outputs.resourceId : actionGroupConfig.resourceId
//     assignmentLevel: assignmentLevel
//     customerTags: tags
//     dceId: backend.outputs.dceId
//     imageGalleryName: imageGalleryName
//     instanceName: instanceName
//     mgname: managementGroupName
//     resourceGroupId: rg.outputs.resourceId
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     storageAccountName: actionGroupCreate ? storageAccount.outputs.name : split(storageAccountConfig.resourceId, '/')[8]
//     subscriptionId: subscriptionId
//     userManagedIdentityResourceId: backend.outputs.packsUserManagedResourceId
//     workspaceId: logAnalyticsCreate ? logAnalytics.outputs.resourceId : logAnalyticsConfig.resourceId
//   }
// }

// module paasPack '../../Packs/PaaS/AllPaaSPacks.bicep' = if (deployPaaSPack) {
//   name: 'deployPaaSPack'
//   params: {
//     location: location
//     actionGroupResourceId: actionGroup.outputs.resourceId
//     assignmentLevel: assignmentLevel
//     customerTags: unionTags
//     dceId: backend.outputs.dceId
//     instanceName: instanceName
//     mgname: managementGroupName
//     resourceGroupId: rg.outputs.resourceId
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     subscriptionId: subscriptionId
//     userManagedIdentityResourceId: backend.outputs.packsUserManagedResourceId
//     workspaceId: logAnalytics.outputs.resourceId
//   }
// }

// module platformPack '../../Packs/Platform/AllPlatformPacks.bicep' = if (deployPlatformPack) {
//   name: 'deployPlatformPack'
//   params: {
//     location: location
//     actionGroupResourceId: actionGroup.outputs.resourceId
//     assignmentLevel: assignmentLevel
//     customerTags: unionTags
//     mgname: managementGroupName
//     instanceName: instanceName
//     resourceGroupId: rg.outputs.resourceId
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     subscriptionId: subscriptionId
//     userManagedIdentityResourceId: backend.outputs.packsUserManagedResourceId
//     workspaceId: logAnalytics.outputs.resourceId
//   }
// }

type resourceGroupType = {
  createMode: 'default'
  name: string
}

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

type grafanaType = {
  location: string?
  @maxLength(23)
  name: string
  createMode: 'default'
}
type storageAccountDefaultType = {
  createMode: 'default'
  name: string
}
type storageAccountExistingType = {
  createMode: 'existing'
  resourceId: string
}
@discriminator('createMode')
type storageAccountType = storageAccountDefaultType | storageAccountExistingType

type actionGroupDefaultType = {
  @maxLength(12)
  name: string
  location: string?
  emailReceiver: string
  emailReceiversEmail: string
  createMode: 'default'
}
type actionGroupExistingType = {
  createMode: 'existing'
  resourceId: string
}
@discriminator('createMode')
type actionGroupType = actionGroupDefaultType | actionGroupExistingType

type packsType = ('all' | 'iaas' | 'paas' | 'platform')[]
type assignmentLevelType = 'managementGroup' | 'subscription'

type keyVaultDefaultType = {
  createMode: 'default'
  name: string
}
type keyVaultRecoverType = {
  createMode: 'recover'
  name: string
}
type keyVaultExistingType = {
  createMode: 'existing'
  resourceId: string
}
@discriminator('createMode')
type keyVaultType = keyVaultDefaultType | keyVaultExistingType | keyVaultRecoverType
