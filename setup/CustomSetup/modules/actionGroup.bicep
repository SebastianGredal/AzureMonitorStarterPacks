targetScope = 'subscription'

param resourceGroupName string
param actionGroupConfig actionGroupType
param location string
param tags object

var createActionGroup = actionGroupConfig.createMode == 'default'

var id = createActionGroup ? actionGroupCreate.outputs.resourceId : actionGroupExisting.outputs.resourceId
var name = createActionGroup ? actionGroupConfig.name : actionGroupExisting.outputs.name

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

module actionGroupCreate 'br/public:avm/res/insights/action-group:0.2.5' = if (createActionGroup) {
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

module actionGroupExisting 'actionGroupExisting.bicep' = if (!createActionGroup) {
  name: 'actionGroupExisting'
  params: {
    actionGroupResourceId: actionGroupConfig.resourceId
  }
}

output resourceId string = id
output name string = name

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
