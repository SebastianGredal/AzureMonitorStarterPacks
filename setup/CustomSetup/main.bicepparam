using './main.bicep'

param _artifactsLocation = 'https://raw.githubusercontent.com/JCoreMS/AzureMonitorStarterPacks/AVDMerge/'
param _artifactsLocationSasToken = ''
param subscriptionId = 'e973cb1c-e0e0-4e65-87db-6a5bd11fe045'
param resourceGroupConfig = {
  name: 'rg-amp-${instanceName}'
  createMode: 'default'
}
param logAnalyticsConfig = {
  name: 'law-amp-${instanceName}'
  createMode: 'default'
}
param grafanaConfig = {
  name: 'grafana-amp-${instanceName}'
  createMode: 'default'
  location: location
}
param storageAccountConfig = {
  name: 'saamp${instanceName}'
  createMode: 'default'
}
param location = 'westeurope'
param assignmentLevel = 'managementGroup'
param deployAMApolicy = false
param instanceName = 'moni'
param appInsightsLocationOveride = location
param actionGroupConfig = {
  name: 'ag-amp-${instanceName}'
  location: 'global'
  emailReceiver: 'Sebastian'
  emailReceiversEmail: 'segr@anquellion.com'
  createMode: 'default'
}
param tags = {}
param packs = [
  'all'
]
param deployDiscovery = false
param functionAppName = 'AMP-${instanceName}-${split(subscriptionId, '-')[0]}-Function'
param logicAppName = 'AMP-${instanceName}-LogicApp'
param imageGalleryName = 'AMP${instanceName}Gallery'
param websiteRunFromPackageUrl = ''
