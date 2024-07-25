using 'modules/packs/paas-pack-2.bicep'
// New-AzManagementGroupDeployment -Name DeployPaasPack2 -Location swedencentral -ManagementGroupId test -TemplateParameterFile .\setup\CustomSetup\deployPaasPack2.bicepparam
param location = 'swedencentral'
param actionGroupResourceId = '/subscriptions/e973cb1c-e0e0-4e65-87db-6a5bd11fe045/resourceGroups/rg-amp-zhv5vo/providers/Microsoft.Insights/actionGroups/ag-amp-zhv5v'
param assignmentLevel = 'managementGroup'
param customerTags = {}
param instanceName = 'zhv5vo'
param managementGroupName = 'test'
param resourceGroupId = '/subscriptions/e973cb1c-e0e0-4e65-87db-6a5bd11fe045/resourceGroups/rg-amp-zhv5vo'
param solutionTag = 'MonitorStarterPacks'
param solutionVersion = '0.1'
param subscriptionId = 'e973cb1c-e0e0-4e65-87db-6a5bd11fe045'
param userManagedIdentityResourceId = '/subscriptions/e973cb1c-e0e0-4e65-87db-6a5bd11fe045/resourceGroups/rg-amp-zhv5vo/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-packs'
param workspaceId = '/subscriptions/e973cb1c-e0e0-4e65-87db-6a5bd11fe045/resourceGroups/rg-amp-zhv5vo/providers/Microsoft.OperationalInsights/workspaces/law-amp-zhv5vo'
