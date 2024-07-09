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

param location string = deployment().location
param assignmentLevel assignmentLevelType = 'managementGroup'

param deployAMApolicy bool
//param currentUserIdObject string // This is to automatically assign permissions to Grafana.
//param functionName string

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
param functionAppName string = 'AMP-${instanceName}-${split(subscriptionId, '-')[0]}-Function'
param logicAppName string = 'AMP-${instanceName}-LogicApp'
param imageGalleryName string = 'AMP${instanceName}Gallery'
param websiteRunFromPackageUrl string

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

var actionGroupCreate = actionGroupConfig.createMode == 'default'
var logAnalyticsCreate = logAnalyticsConfig.createMode == 'default'
var storageAccountCreate = storageAccountConfig.createMode == 'default'

module rg 'modules/resourceGroup.bicep' = {
  scope: subscription(subscriptionId)
  name: 'resourceGroup-deployment'
  params: {
    location: location
    resourceGroupConfig: resourceGroupConfig
    tags: unionTags
  }
}

module storageAccount 'modules/storageAccount.bicep' = if (storageAccountCreate) {
  scope: subscription(subscriptionId)
  name: 'storageAccount-deployment'
  params: {
    location: location
    resourceGroupName: rg.outputs.name
    storageAccountConfig: {
      name: storageAccountConfig.name
    }
    tags: unionTags
  }
}

module logAnalytics 'modules/logAnalytics.bicep' = if (logAnalyticsCreate) {
  scope: subscription(subscriptionId)
  name: 'logAnalytics-deployment'
  params: {
    location: location
    logAnalyticsConfig: {
      name: logAnalyticsConfig.name
    }
    resourceGroupName: rg.outputs.name
    tags: unionTags
  }
}

module AMAPolicy '../AMAPolicy/amapoliciesmg.bicep' = if (deployAMApolicy) {
  name: 'DeployAMAPolicy'
  params: {
    assignmentLevel: assignmentLevel
    location: location
    resourceGroupName: rg.outputs.name
    solutionTag: solutionTagComponents
    solutionVersion: solutionVersion
    subscriptionId: subscriptionId
    Tags: unionTags
  }
}

// module discovery '../discovery/discovery.bicep' = if (deployDiscovery) {
//   name: 'DeployDiscovery-${instanceName}'
//   params: {
//     assignmentLevel: assignmentLevel
//     location: location
//     resourceGroupName: rg.outputs.name
//     solutionTag: solutionTag
//     solutionVersion: solutionVersion
//     subscriptionId: subscriptionId
//     dceId: backend.outputs.dceId
//     imageGalleryName: imageGalleryName
//     lawResourceId: logAnalytics.outputs.resourceId
//     mgname: managementGroupName
//     storageAccountname: storageAccount.outputs.name
//     tableName: 'Discovery'
//     userManagedIdentityResourceId: backend.outputs.packsUserManagedResourceId
//     Tags: unionTags
//     instanceName: instanceName
//   }
// }

module grafana 'modules/grafana.bicep' = {
  scope: subscription(subscriptionId)
  name: 'grafana-deployment'
  params: {
    grafanaConfig: grafanaConfig
    location: location
    resourceGroupName: rg.outputs.name
    solutionTag: solutionTag
    tags: unionTags
  }
}

module actionGroup 'modules/actionGroup.bicep' = if (actionGroupCreate) {
  scope: subscription(subscriptionId)
  name: 'actionGroup-deployment'
  params: {
    actionGroupConfig: {
      name: actionGroupConfig.name
      emailReceiver: actionGroupConfig.emailReceiver
      emailReceiversEmail: actionGroupConfig.emailReceiversEmail
      location: actionGroupConfig.location
    }
    location: location
    resourceGroupName: rg.outputs.name
    tags: unionTags
  }
}

// BACKEND
module backend 'modules/backend.bicep' = {
  name: 'monitoringPacks-backend'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    appInsightsLocation: appInsightsLocationOveride
    functionAppName: functionAppName
    imageGalleryName: imageGalleryName
    instanceName: instanceName
    workspaceResourceId: logAnalyticsCreate ? logAnalytics.outputs.resourceId : logAnalyticsConfig.resourceId
    location: location
    logicAppName: logicAppName
    resourceGroupId: rg.outputs.resourceId
    solutionTag: solutionTag
    storageAccountResourceId: actionGroupCreate ? storageAccount.outputs.resourceId : storageAccountConfig.resourceId
    tags: unionTags
    websiteRunFromPackageUrl: websiteRunFromPackageUrl
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
  createMode: 'default' | 'existing'
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
  name: string
  createMode: 'default' | 'existing'
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
