targetScope = 'subscription'

param resourceGroupName string
param actionGroupConfig actionGroupType
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module actionGroup 'br/public:avm/res/insights/action-group:0.2.5' = {
  name: 'actionGroup'
  scope: rg
  params: {
    name: actionGroupConfig.name
    groupShortName: actionGroupConfig.name
    location: actionGroupConfig.?location ?? location
    tags: tags
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

output resourceId string = actionGroup.outputs.resourceId
output name string = actionGroup.outputs.name

func parseId(resourceId string) string[] => split(resourceId, '/')

type actionGroupType = {
  name: string
  location: string?
  emailReceiver: string
  emailReceiversEmail: string
}
