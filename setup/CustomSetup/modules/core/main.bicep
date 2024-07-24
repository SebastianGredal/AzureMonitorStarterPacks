targetScope = 'managementGroup'

param resourceGroupName string
param subscriptionId string
param actionGroupConfig actionGroupType
param storageAccountConfig storageAccountType
param logAnalyticsConfig logAnalyticsType
param keyVaultConfig keyVaultType
param grafanaConfig grafanaType
param solutionTag string
param location string
param tags object
param instanceName string

param packsUserAssignedIdentityName string = 'id-packs'
param functionUserAssignedIdentityName string = 'id-func'

var packPolicyRoleDefinitionIds = [
  // '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor Role Definition Id for Monitoring Contributor
  // '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor Role Definition Id for Log Analytics Contributor
  // //Above role should be able to add diagnostics to everything according to docs.
  // '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // VM Contributor, in order to update VMs with vm Applications
  //Contributor may be needed if we want to create alerts anywhere
  'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  // '/providers/Microsoft.Authorization/roleDefinitions/4a9ae827-6dc8-4573-8ac7-8239d42aa03f' // Tag Contributor
]

var functionRoleDefinitionIds = [
  '4a9ae827-6dc8-4573-8ac7-8239d42aa03f' // Tag Contributor
  '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // VM Contributor
  '48b40c6e-82e0-4eb3-90d5-19e40f49b624' // Arc Contributor
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
  '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
  '36243c78-bf99-498c-9df9-86d9f8d28608' // policy contributor
  'f1a07417-d97a-45cb-824c-7a7467783830' // Managed identity Operator
]

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
  scope: subscription(subscriptionId)
}

module keyVault 'br/public:avm/res/key-vault/vault:0.6.2' = if (keyVaultConfig.createMode != 'existing') {
  scope: rg
  name: 'key-vault'
  params: {
    name: keyVaultConfig.name
    location: location
    tags: tags
    enableTelemetry: false
    enablePurgeProtection: false
    enableSoftDelete: false
    publicNetworkAccess: 'Enabled'
    createMode: keyVaultConfig.createMode
    roleAssignments: [
      {
        principalId: functionUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
  }
}

resource keyVaultExisting 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (keyVaultConfig.createMode == 'existing') {
  scope: resourceGroup(
    split(keyVaultConfig.?resourceId ?? '//', '/')[2],
    split(keyVaultConfig.?resourceId ?? '////', '/')[4]
  )
  name: last(split(keyVaultConfig.?resourceId ?? 'vault', '/'))
}

module actionGroup 'br/public:avm/res/insights/action-group:0.2.5' = if (actionGroupConfig.createMode == 'default') {
  name: 'actionGroup'
  scope: rg
  params: {
    name: actionGroupConfig.name
    groupShortName: actionGroupConfig.name
    location: actionGroupConfig.?location ?? location
    tags: tags
    enableTelemetry: false
    enabled: true
    emailReceivers: [
      {
        name: actionGroupConfig.emailReceiver
        emailAddress: actionGroupConfig.emailReceiversEmail
        useCommonAlertSchema: false
      }
    ]
  }
}

resource actionGroupExisting 'Microsoft.Insights/actionGroups@2023-01-01' existing = if (actionGroupConfig.createMode == 'existing') {
  scope: resourceGroup(
    split(actionGroupConfig.?resourceId ?? '//', '/')[2],
    split(actionGroupConfig.?resourceId ?? '////', '/')[4]
  )
  name: last(split(actionGroupConfig.?resourceId ?? 'actionGroup', '/'))
}

module grafana '../../../backend/code/modules/grafana.bicep' = if (grafanaConfig.createMode == 'default') {
  name: 'azureManagedGrafana'
  scope: rg
  params: {
    Tags: tags
    location: grafanaConfig.?location ?? location
    grafanaName: grafanaConfig.name
    solutionTag: solutionTag
  }
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.3.5' = if (logAnalyticsConfig.createMode == 'default') {
  scope: rg
  name: 'logAnalytics'
  params: {
    name: logAnalyticsConfig.name
    location: location
    tags: tags
    enableTelemetry: false
  }
}

resource logAnalyticsExisting 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (logAnalyticsConfig.createMode == 'existing') {
  scope: resourceGroup(
    split(logAnalyticsConfig.?resourceId ?? '//', '/')[2],
    split(logAnalyticsConfig.?resourceId ?? '////', '/')[4]
  )
  name: last(split(logAnalyticsConfig.?resourceId ?? 'logAnalytics', '/'))
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.9.1' = if (storageAccountConfig.createMode == 'default') {
  scope: rg
  name: 'storageAccount'
  params: {
    name: storageAccountConfig.name
    skuName: 'Standard_LRS'
    location: location
    tags: tags
    kind: 'StorageV2'
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'
    enableTelemetry: false
    networkAcls: {
      defaultAction: 'Allow'
    }
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    requireInfrastructureEncryption: true
    blobServices: {
      deleteRetentionPolicyEnabled: false
      containers: [
        {
          name: 'discovery'
          immutableStorageWithVersioningEnabled: false
          publicAccess: 'None'
        }
        {
          name: 'applications'
          immutableStorageWithVersioningEnabled: false
          publicAccess: 'None'
        }
      ]
    }
    roleAssignments: [
      {
        principalId: functionUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Queue Data Contributor'
      }
      {
        principalId: functionUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Owner'
      }
      {
        principalId: functionUserAssignedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Table Data Contributor'
      }
    ]
  }
}

resource storageAccountExisting 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (storageAccountConfig.createMode == 'existing') {
  scope: resourceGroup(
    split(storageAccountConfig.?resourceId ?? '//', '/')[2],
    split(storageAccountConfig.?resourceId ?? '////', '/')[4]
  )
  name: last(split(storageAccountConfig.?resourceId ?? 'storageAccount', '/'))
}

module packsUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.2' = {
  scope: rg
  name: 'packs-user-assigned-identity'
  params: {
    name: packsUserAssignedIdentityName
    enableTelemetry: false
    location: location
  }
}

module packsUMIManagementGroupRoleAssignment '../role-assignment/management-group.bicep' = [
  for (item, index) in packPolicyRoleDefinitionIds: {
    name: 'packs-identity-role-${index}'
    params: {
      principalId: packsUserAssignedIdentity.outputs.principalId
      roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${item}'
    }
  }
]

module functionUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.2' = {
  scope: rg
  name: 'function-user-assigned-identity'
  params: {
    name: functionUserAssignedIdentityName
    enableTelemetry: false
    location: location
  }
}

module functionUMIManagementGroupRoleAssignment '../role-assignment/management-group.bicep' = [
  for (item, index) in functionRoleDefinitionIds: {
    name: 'function-identity-role-${index}'
    params: {
      principalId: functionUserAssignedIdentity.outputs.principalId
      roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${item}'
    }
  }
]

module dataCollectionEndpoint 'br/public:avm/res/insights/data-collection-endpoint:0.1.3' = {
  scope: rg
  name: 'data-collection-endpoint'
  params: {
    name: 'dce-amp-${instanceName}-${location}'
    location: location
    enableTelemetry: false
    publicNetworkAccess: 'Enabled'
  }
}

output keyVaultResourceId string = keyVaultConfig.createMode != 'existing'
  ? keyVault.outputs.resourceId
  : keyVaultExisting.id
output actionGroupResourceId string = actionGroupConfig.createMode == 'default'
  ? actionGroup.outputs.resourceId
  : actionGroupExisting.id
output grafanaResourceId string = grafanaConfig.createMode == 'default' ? grafana.outputs.grafanaId : ''
output logAnalyticsResourceId string = logAnalyticsConfig.createMode == 'default'
  ? logAnalytics.outputs.resourceId
  : logAnalyticsExisting.id
output storageAccountResourceId string = storageAccountConfig.createMode == 'default'
  ? storageAccount.outputs.resourceId
  : storageAccountExisting.id
output functionUserAssignedIdentityResourceId string = functionUserAssignedIdentity.outputs.resourceId
output packsUserAssignedIdentityResourceId string = packsUserAssignedIdentity.outputs.resourceId
output dataCollectionEndpointResourceId string = dataCollectionEndpoint.outputs.resourceId

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
