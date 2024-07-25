targetScope = 'managementGroup'

param actionGroupResourceId string
@description('location for the deployment.')
param location string //= resourceGroup().location
@description('Full resource ID of the log analytics workspace to be used for the deployment.')
param workspaceId string
param solutionTag string
param solutionVersion string
@description('Full resource ID of the user managed identity to be used for the deployment')
param userManagedIdentityResourceId string
param managementGroupName string // this the last part of the management group id
param subscriptionId string
param resourceGroupId string
param assignmentLevel string
param customerTags object
param instanceName string

module KVAlerts '../../../../Packs/PaaS/KeyVault/monitoring.bicep' = {
  name: 'KVAlerts'
  params: {
    assignmentLevel: assignmentLevel
    location: location
    mgname: managementGroupName
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    actionGroupResourceId: actionGroupResourceId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packtag: 'KeyVault'
    instanceName: instanceName
    solutionVersion: solutionVersion
  }
}
module vWan '../../../../Packs/PaaS/Network/vWan/monitoring.bicep' = {
  name: 'vWanAlerts'
  params: {
    actionGroupResourceId: actionGroupResourceId
    assignmentLevel: assignmentLevel
    location: location
    mgname: managementGroupName
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    workspaceId: workspaceId
    packtag: 'vWan'
    solutionVersion: solutionVersion
    customerTags: customerTags
    instanceName: instanceName
  }
}
module LoadBalancers '../../../../Packs/PaaS/Network/LoadBalancers/monitoring.bicep' = {
  name: 'LoadBalancersAlerts'
  params: {
    actionGroupResourceId: actionGroupResourceId
    assignmentLevel: assignmentLevel
    location: location
    mgname: managementGroupName
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packtag: 'ALB'
    solutionVersion: solutionVersion
    customerTags: customerTags
    instanceName: instanceName
  }
}
module AA '../../../../Packs/PaaS/AA/alerts.bicep' = {
  name: 'AA'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'AA'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Automation/automationAccounts'
  }
}
module AppGW '../../../../Packs/PaaS/Network/AppGW/alerts.bicep' = {
  name: 'AppGWAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'AppGW'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/applicationGateways'
  }
}
module AzFW '../../../../Packs/PaaS/Network/AzFW/alerts.bicep' = {
  name: 'AzFWAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'AzFW'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/azureFirewalls'
  }
}
module AzFD '../../../../Packs/PaaS/Network/AzFD/alerts.bicep' = {
  name: 'AzFDAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'AzFD'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/frontdoors'
  }
}
module PrivZones '../../../../Packs/PaaS/Network/PrivZones/alerts.bicep' = {
  name: 'PrivZonesAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'PrivZones'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/privateDnsZones'
  }
}
module PIP '../../../../Packs/PaaS/Network/PIP/alerts.bicep' = {
  name: 'PIPAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'PIP'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/publicIPAddresses'
  }
}

module NSG '../../../../Packs/PaaS/Network/NSG/alerts.bicep' = {
  name: 'NSGAlerts'
  params: {
    assignmentLevel: assignmentLevel
    mgname: managementGroupName
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    userManagedIdentityResourceId: userManagedIdentityResourceId
    packTag: 'NSG'
    instanceName: instanceName
    solutionVersion: solutionVersion
    AGId: actionGroupResourceId
    policyLocation: location
    parResourceGroupName: resourceGroupId
    resourceType: 'Microsoft.Network/networkSecurityGroups'
  }
}
