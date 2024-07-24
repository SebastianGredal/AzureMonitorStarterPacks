targetScope = 'subscription'

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
param resourceGroupName string
param keyVaultResourceId string
param functionUserAssignedIdentityResourceId string
param packsUserAssignedIdentityResourceId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: split(keyVaultResourceId, '/')[8]
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: split(storageAccountResourceId, '/')[8]
  scope: resourceGroup(split(storageAccountResourceId, '/')[2], split(storageAccountResourceId, '/')[4])
}

resource functionUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: split(functionUserAssignedIdentityResourceId, '/')[8]
  scope: resourceGroup(
    split(functionUserAssignedIdentityResourceId, '/')[2],
    split(functionUserAssignedIdentityResourceId, '/')[4]
  )
}

resource packsUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: split(packsUserAssignedIdentityResourceId, '/')[8]
  scope: resourceGroup(
    split(packsUserAssignedIdentityResourceId, '/')[2],
    split(packsUserAssignedIdentityResourceId, '/')[4]
  )
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module storageAccountConnectionString '../key-vault-secrets.bicep' = {
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
  name: 'storageAccountConnectionString'
  params: {
    keyVaultName: keyVault.name
    name: '${toUpper(storageAccount.name)}-CONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

// Function App Specific
module functionAppPlan 'br/public:avm/res/web/serverfarm:0.2.2' = {
  scope: rg
  name: 'functionAppPlan'
  params: {
    name: 'asp-amp-${instanceName}'
    skuCapacity: 0
    skuName: 'Y1'
    kind: 'Windows'
    location: location
    zoneRedundant: false
    enableTelemetry: false
  }
}

module functionApp 'br/public:avm/res/web/site:0.3.9' = {
  scope: rg
  name: 'functionApp'
  params: {
    kind: 'functionapp'
    name: functionAppName
    serverFarmResourceId: functionAppPlan.outputs.resourceId
    enableTelemetry: false
    location: location
    enabled: true
    httpsOnly: true
    appInsightResourceId: appInsights.outputs.resourceId
    storageAccountResourceId: storageAccountResourceId
    storageAccountUseIdentityAuthentication: true
    keyVaultAccessIdentityResourceId: functionUserAssignedIdentity.id
    publicNetworkAccess: 'Enabled'
    tags: tags
    siteConfig: {
      alwaysOn: false
      powershellVersion: '7.4'
    }
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: false
        name: 'scm'
      }
    ]
    managedIdentities: {
      userAssignedResourceIds: [
        functionUserAssignedIdentity.id
      ]
    }
    appSettingsKeyValuePairs: union(
      {
        FUNCTIONS_WORKER_RUNTIME: 'powershell'
        FUNCTIONS_EXTENSION_VERSION: '~4'
        ResourceGroup: resourceGroupName
        SolutionTag: solutionTag
        PacksUserManagedId: packsUserAssignedIdentity.id
        MSI_CLIENT_ID: functionUserAssignedIdentity.properties.clientId
        ARTIFACS_LOCATION: _artifactsLocation
        ARTIFACTS_LOCATION_SAS_TOKEN: _artifactsLocationSasToken
        WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=${storageAccountConnectionString.outputs.secretUri})'
        WEBSITE_CONTENTSHARE: storageAccount.name
      },
      {
        WEBSITE_RUN_FROM_PACKAGE: 1
      },
      {
        AzureWebJobsStorage__clientId: functionUserAssignedIdentity.properties.clientId
        AzureWebJobsStorage__credential: 'managedIdentity'
      }
    )
    roleAssignments: [
      {
        principalId: functionUserAssignedIdentity.properties.principalId
        roleDefinitionIdOrName: 'Contributor'
      }
    ]
  }
}

module functionAppZipDeployment 'br/public:avm/res/resources/deployment-script:0.2.4' = {
  scope: rg
  name: 'functionAppZipUpload'
  params: {
    managedIdentities: {
      userAssignedResourcesIds: [
        functionUserAssignedIdentity.id
      ]
    }
    kind: 'AzurePowerShell'
    azPowerShellVersion: '12.0'
    name: 'functionAppZipUpload'
    timeout: 'PT5M'
    cleanupPreference: 'Always'
    enableTelemetry: false
    environmentVariables: {
      secureList: [
        {
          name: 'ResourceGroupName'
          value: resourceGroupName
        }
        {
          name: 'FunctionAppName'
          value: functionApp.outputs.name
        }
        {
          name: 'CONTENT'
          value: loadFileAsBase64('../../../backend/backend.zip')
        }
      ]
    }
    scriptContent: '''
      $Location = Get-Location
      $FileName = $Location.Path + '/backend.zip'
      $Bytes = [System.Convert]::FromBase64String($env:CONTENT)
      [System.IO.File]::WriteAllBytes($FileName, $Bytes)
      Publish-AzWebApp -ResourceGroupName $env:ResourceGroupName -Name $env:FunctionAppName -ArchivePath $FileName -Restart -Force -ErrorAction Stop
      Write-Output 'Function App deployment completed'
    '''
  }
}

module appInsights 'br/public:avm/res/insights/component:0.3.1' = {
  scope: rg
  name: 'appInsights'
  params: {
    name: 'appi-amp-${instanceName}'
    enableTelemetry: false
    workspaceResourceId: workspaceResourceId
    location: appInsightsLocation
    tags: tags
  }
}

// Workbooks
module workbook '../../../backend/code/modules/extendedworkbook.bicep' = {
  scope: rg
  name: 'workbook'
  params: {
    lawresourceid: workspaceResourceId
    location: location
    Tags: tags
  }
}

module logicApp 'logicApp.bicep' = {
  dependsOn: [
    functionAppZipDeployment
  ]
  scope: rg
  name: 'logicApp-deployment'
  params: {
    functionAppResourceId: functionApp.outputs.resourceId
    userAssignedIdentityResourceId: functionUserAssignedIdentity.id
    keyVaultResourceId: keyVault.id
    logicAppName: logicAppName
    location: location
  }
}
