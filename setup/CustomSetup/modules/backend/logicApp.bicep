param subscriptionId string = subscription().subscriptionId
param location string = resourceGroup().location
param keyVaultResourceId string
param logicAppName string
param functionAppResourceId string
param userAssignedIdentityResourceId string
param tags object

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: split(keyVaultResourceId, '/')[8]
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: split(functionAppResourceId, '/')[8]
  scope: resourceGroup(split(functionAppResourceId, '/')[2], split(functionAppResourceId, '/')[4])
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: split(userAssignedIdentityResourceId, '/')[8]
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
}

module defaultFunctionKey '../key-vault-secrets.bicep' = {
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
  name: 'defaultFunctionKey'
  params: {
    keyVaultName: keyVault.name
    name: 'FunctionKey'
    value: listKeys('${functionApp.id}/host/default', '2023-12-01').functionKeys.default
  }
}

module logicAppConnection 'br/public:avm/res/web/connection:0.2.0' = {
  name: 'logicAppConnection'
  params: {
    displayName: keyVault.name
    name: 'keyvault'
    location: location
    api: {
      name: keyVault.name
      displayName: 'Azure Key Vault'
      iconUri: 'https://connectoricons-prod.azureedge.net/releases/v1.0.1656/1.0.1656.3432/keyvault/icon.png'
      brandColor: '#0079d6'
      category: 'Standard'
      id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
      type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValueSet: {
      name: 'oauthMI'
      values: {
        vaultName: {
          value: keyVault.name
        }
      }
    }
    tags: tags
  }
}

module logicApp 'br/public:avm/res/logic/workflow:0.2.6' = {
  dependsOn: [
    defaultFunctionKey
  ]
  name: 'logicApp'
  params: {
    name: logicAppName
    tags: tags
    managedIdentities: {
      userAssignedResourceIds: [
        userAssignedIdentityResourceId
      ]
    }
    definitionParameters: {
      '$connections': {
        value: {
          keyvault: {
            id: '/subscriptions/${subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/keyvault'
            connectionId: logicAppConnection.outputs.resourceId
            connectionName: logicAppConnection.outputs.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: userAssignedIdentity.id
              }
            }
          }
        }
      }
    }
    workflowTriggers: {
      manual: {
        type: 'Request'
        kind: 'Http'
        inputs: {
          schema: {}
        }
      }
    }
    workflowActions: {
      Parse_JSON: {
        runAfter: {}
        type: 'ParseJson'
        inputs: {
          content: '@triggerBody()'
          schema: {
            properties: {
              function: {
                type: 'string'
              }
              functionBody: {
                properties: {}
                type: 'object'
              }
            }
            type: 'object'
          }
        }
      }
      Get_Secret: {
        runAfter: {
          Parse_JSON: [
            'Succeeded'
          ]
        }
        type: 'ApiConnection'
        inputs: {
          host: {
            connection: {
              name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
            }
          }
          method: 'get'
          path: '/secrets/@{encodeURIComponent(\'FunctionKey\')}/value'
        }
      }
      Switch: {
        runAfter: {
          Get_Secret: [
            'Succeeded'
          ]
        }
        cases: {
          Case: {
            case: 'tagmgmt'
            actions: {
              tagmgmt: {
                runAfter: {}
                type: 'Function'
                inputs: {
                  body: '@body(\'Parse_JSON\')?[\'functionBody\']'
                  function: {
                    id: '${functionApp.id}/functions/tagmgmt'
                  }
                  headers: {
                    'x-functions-key': '@body(\'Get_secret\')?[\'value\']'
                  }
                }
              }
            }
          }
          Case_2: {
            case: 'alertmgmt'
            actions: {
              alertConfigMgmt: {
                runAfter: {}
                type: 'Function'
                inputs: {
                  body: '@body(\'Parse_JSON\')?[\'functionBody\']'
                  function: {
                    id: '${functionApp.id}/functions/alertConfigMgmt'
                  }
                  headers: {
                    'x-functions-key': '@body(\'Get_secret\')?[\'value\']'
                  }
                }
              }
            }
          }
          Case_3: {
            case: 'policymgmt'
            actions: {
              policymgmt: {
                runAfter: {}
                type: 'Function'
                inputs: {
                  body: '@body(\'Parse_JSON\')?[\'functionBody\']'
                  function: {
                    id: '${functionApp.id}/functions/policymgmt'
                  }
                  headers: {
                    'x-functions-key': '@body(\'Get_secret\')?[\'value\']'
                  }
                }
              }
            }
          }
          Case_4: {
            case: 'agentMgmt'
            actions: {
              agentMgmt: {
                runAfter: {}
                type: 'Function'
                inputs: {
                  body: '@body(\'Parse_JSON\')?[\'functionBody\']'
                  function: {
                    id: '${functionApp.id}/functions/agentmgmt'
                  }
                  headers: {
                    'x-functions-key': '@body(\'Get_secret\')?[\'value\']'
                  }
                }
              }
            }
          }
        }
        default: {
          actions: {}
        }
        expression: '@body(\'Parse_JSON\')?[\'Function\']'
        type: 'Switch'
      }
    }
    workflowParameters: {
      '$connections': {
        type: 'Object'
        defaultValue: {}
      }
    }
  }
}
