targetScope = 'subscription'

param actionGroupResourceId string
var actionGroupSplit = split(actionGroupResourceId, '/')

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' existing = {
  scope: resourceGroup(actionGroupSplit[2], actionGroupSplit[4])
  name: actionGroupSplit[8]
}

output resourceId string = actionGroup.id
output name string = actionGroup.name
