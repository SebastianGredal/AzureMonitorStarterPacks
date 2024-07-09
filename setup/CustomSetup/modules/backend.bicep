targetScope = 'managementGroup'

@secure()
param _artifactsLocationSasToken string
param _artifactsLocation string
param functionAppName string = 'func-amp-${instanceName}'
param logicAppName string = 'logic-amp-${instanceName}'
param instanceName string
param location string
param storageAccountResourceId string
param solutionTag string
param workspaceResourceId string
param appInsightsLocation string
param tags object
param resourceGroupId string
param imageGalleryName string
param websiteRunFromPackageUrl string

var packPolicyRoleDefinitionIds = [
  // '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor Role Definition Id for Monitoring Contributor
  // '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor Role Definition Id for Log Analytics Contributor
  // //Above role should be able to add diagnostics to everything according to docs.
  // '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // VM Contributor, in order to update VMs with vm Applications
  //Contributor may be needed if we want to create alerts anywhere
  'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  // '/providers/Microsoft.Authorization/roleDefinitions/4a9ae827-6dc8-4573-8ac7-8239d42aa03f' // Tag Contributor
]

var backendFunctionRoleDefinitionIds = [
  '4a9ae827-6dc8-4573-8ac7-8239d42aa03f' // Tag Contributor
  '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // VM Contributor
  '48b40c6e-82e0-4eb3-90d5-19e40f49b624' // Arc Contributor
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
  '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
  '36243c78-bf99-498c-9df9-86d9f8d28608' // policy contributor
  'f1a07417-d97a-45cb-824c-7a7467783830' // Managed identity Operator
]
var logicappRequiredRoleassignments = [
  '4633458b-17de-408a-b874-0445c86b69e6' //keyvault reader role
]

var resourceGroupName = split(resourceGroupId, '/')[4]
var subscriptionId = split(resourceGroupId, '/')[2]

module gallery '../../backend/code/modules/aig.bicep' = {
  name: imageGalleryName
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    galleryname: imageGalleryName
    location: location
    tags: tags
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: split(storageAccountResourceId, '/')[8]
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
}

// Function App Specific
module functionAppPlan 'br/public:avm/res/web/serverfarm:0.2.2' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'functionAppPlan'
  params: {
    name: 'asp-amp-${instanceName}'
    skuCapacity: 0
    skuName: 'Y1'
    kind: 'FunctionApp'
    location: location
    zoneRedundant: false
  }
}

module functionApp 'br/public:avm/res/web/site:0.3.9' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'functionApp'
  params: {
    kind: 'functionapp'
    name: functionAppName
    serverFarmResourceId: functionAppPlan.outputs.resourceId
    location: location
    enabled: true
    httpsOnly: true
    appInsightResourceId: appInsights.outputs.resourceId
    storageAccountResourceId: storageAccountResourceId
    storageAccountUseIdentityAuthentication: true
    keyVaultAccessIdentityResourceId: functionUserAssignedIdentity.outputs.resourceId
    publicNetworkAccess: 'Enabled'
    vnetContentShareEnabled: true
    tags: tags
    siteConfig: {
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: true
      }
    }
    managedIdentities: {
      userAssignedResourceIds: [
        functionUserAssignedIdentity.outputs.resourceId
      ]
    }
    appSettingsKeyValuePairs: {
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      ResourceGroup: resourceGroupName
      SolutionTag: solutionTag
      PacksUserManagedId: packsUserManagedIdentity.outputs.resourceId
      MSI_CLIENT_ID: functionUserAssignedIdentity.outputs.clientId
      ARTIFACS_LOCATION: _artifactsLocation
      ARTIFACTS_LOCATION_SAS_TOKEN: _artifactsLocationSasToken
      WEBSITE_RUN_FROM_PACKAGE: websiteRunFromPackageUrl
      WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: functionUserAssignedIdentity.outputs.resourceId
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0]};EndpointSuffix=${environment().suffixes.storage}'
      WEBSITE_CONTENTSHARE: storageAccount.name
    }
  }
}

module functionUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.2' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'AMP-${instanceName}-UMI-Function'
  params: {
    name: 'AMP-${instanceName}-UMI-Function'
    enableTelemetry: false
    location: location
  }
}

module functionUMIManagementGroupRoleAssignment 'role-assignment/management-group.bicep' = [
  for (item, index) in backendFunctionRoleDefinitionIds: {
    name: 'AMP-${instanceName}-UMI-Function-Role-${index}'
    params: {
      principalId: functionUserAssignedIdentity.outputs.principalId
      roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${item}'
    }
  }
]

module appInsights 'br/public:avm/res/insights/component:0.3.1' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'appInsights'
  params: {
    name: 'appi-amp-${instanceName}'
    workspaceResourceId: workspaceResourceId
    location: appInsightsLocation
    tags: tags
  }
}

// Packs Specific
module packsUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.2' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'AMP-${instanceName}-UMI-Packs'
  params: {
    name: 'AMP-${instanceName}-UMI-Packs'
    enableTelemetry: false
    location: location
  }
}

module packsUMIManagementGroupRoleAssignment 'role-assignment/management-group.bicep' = [
  for (item, index) in packPolicyRoleDefinitionIds: {
    name: 'AMP-${instanceName}-UMI-Packs-Role-${index}'
    params: {
      principalId: packsUserManagedIdentity.outputs.principalId
      roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${item}'
    }
  }
]

// Workbooks
module workbook '../../backend/code/modules/extendedworkbook.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'workbook'
  params: {
    lawresourceid: workspaceResourceId
    location: location
    Tags: tags
  }
}

module dataCollectionEndpoint 'br/public:avm/res/insights/data-collection-endpoint:0.1.3' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'data-collection-endpoint'
  params: {
    name: 'AMP-${instanceName}-DCE-${location}'
    location: location
    enableTelemetry: false
    publicNetworkAccess: 'Enabled'
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.6.2' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'key-vault'
  params: {
    name: take('kv-amp-${instanceName}-${uniqueString(subscriptionId, resourceGroupName)}', 24)
    location: location
    tags: tags
    enableTelemetry: false
    enablePurgeProtection: false
    enableSoftDelete: false
    publicNetworkAccess: 'Enabled'
  }
}

module logicApp 'logicApp.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'logicApp-deployment'
  params: {
    functionAppResourceId: functionApp.outputs.resourceId
    keyVaultResourceId: keyVault.outputs.resourceId
    logicAppName: logicAppName
    location: location
  }
}
