targetScope = 'managementGroup'

param actionGroupResourceId string
@description('location for the deployment.')
param location string //= resourceGroup().location
@description('Full resource ID of the log analytics workspace to be used for the deployment.')
param workspaceId string
param solutionTag string
param solutionVersion string
@description('Full resource ID of the data collection endpoint to be used for the deployment.')
param dataCollectionEndpointResourceId string
@description('Full resource ID of the user managed identity to be used for the deployment')
param userManagedIdentityResourceId string
param managementGroupName string // this the last part of the management group id
param subscriptionId string
param resourceGroupId string
param assignmentLevel string
param customerTags object
param instanceName string

module Storage '../../../../Packs/PaaS/Storage/monitoring.bicep' = {
  name: 'StorageAlerts'
  params: {
    assignmentLevel: assignmentLevel
    location: location
    mgname: managementGroupName
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    actionGroupResourceId: actionGroupResourceId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packtag: 'Storage'
    customerTags: customerTags
    instanceName: instanceName
    solutionVersion: solutionVersion
  }
}

module AVD '../../../../Packs/PaaS/AVD/monitoring.bicep' = {
  name: 'AvdAlerts'
  params: {
    assignmentLevel: assignmentLevel
    customerTags: customerTags
    location: location
    mgname: managementGroupName
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    solutionVersion: solutionVersion
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packtag: 'Avd'
    instanceName: instanceName
    dceId: dataCollectionEndpointResourceId
    workspaceId: workspaceId
  }
}

module LogicApps '../../../../Packs/PaaS/LogicApps/alerts.bicep' = {
  name: 'LogicAppsAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'LogicApps'
    instanceName: instanceName
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    solutionVersion: solutionVersion
    resourceType: 'Microsoft.Logic/workflows'
  }
}

module SQLMI '../../../../Packs/PaaS/SQL/SQLMI/alerts.bicep' = {
  name: 'SQLMIAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'SQLMI'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Sql/managedInstances'
  }
}
module SQLSrv '../../../../Packs/PaaS/SQL/server/alerts.bicep' = {
  name: 'SQLSrvAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'SQLSrv'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Sql/servers/databases'
  }
}
module WebApps '../../../../Packs/PaaS/WebApp/monitoring.bicep' = {
  name: 'WebApps'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packtag: 'WebApp'
    instanceName: instanceName
    solutionVersion: solutionVersion
    actionGroupResourceId: actionGroupResourceId
    customerTags: customerTags
    location: location
    resourceGroupId: resourceGroupId
    workspaceId: workspaceId
  }
}
