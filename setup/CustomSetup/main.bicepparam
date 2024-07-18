using './main.bicep'

param _artifactsLocation = 'https://raw.githubusercontent.com/JCoreMS/AzureMonitorStarterPacks/AVDMerge/'
param _artifactsLocationSasToken = ''
param subscriptionId = 'e973cb1c-e0e0-4e65-87db-6a5bd11fe045'
param resourceGroupConfig = {
  name: 'rg-amp-${instanceName}'
  createMode: 'default'
}
param actionGroupConfig = {
  name: 'ag-amp-${take(instanceName, 5)}'
  location: 'global'
  emailReceiver: 'Sebastian'
  emailReceiversEmail: 'segr@anquellion.com'
  createMode: 'default'
}
param logAnalyticsConfig = {
  name: 'law-amp-${instanceName}'
  createMode: 'default'
}
param grafanaConfig = {
  name: 'amg-amp-${instanceName}'
  createMode: 'default'
  location: location
}
param storageAccountConfig = {
  name: 'saamp${instanceName}'
  createMode: 'default'
}
param keyVaultConfig = {
  name: 'kv-amp-${instanceName}'
  createMode: 'default'
}
param location = 'swedencentral'
param assignmentLevel = 'managementGroup'
param instanceName = take(uniqueString(subscriptionId), 6)
param appInsightsLocationOveride = location
param tags = {}
param packs = [
  'all'
]
param deployDiscovery = false
param functionAppName = 'func-amp-${instanceName}'
param logicAppName = 'logic-amp-${instanceName}'
param galleryName = 'galamp${instanceName}'
