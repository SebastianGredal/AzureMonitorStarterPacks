param subscriptionId string = subscription().id
param location string = resourceGroup().location
param keyVaultResourceId string
param logicAppName string
param functionAppResourceId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: split(keyVaultResourceId, '/')[8]
  scope: resourceGroup(split(keyVaultResourceId, '/')[2], split(keyVaultResourceId, '/')[4])
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: split(functionAppResourceId, '/')[8]
  scope: resourceGroup(split(functionAppResourceId, '/')[2], split(functionAppResourceId, '/')[4])
}
module logicAppConnection 'br/public:avm/res/web/connection:0.2.0' = {
  name: 'logicAppConnection'
  params: {
    displayName: 'KeyVault'
    name: 'keyvault'
    location: location
    api: {
      name: 'keyvault'
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
  }
}

module logicApp 'br/public:avm/res/logic/workflow:0.2.6' = {
  name: 'logicApp'
  params: {
    name: logicAppName
    managedIdentities: {
      systemAssigned: true
    }
    definitionParameters: {
      '$connections': {
        defaultValue: {}
        type: 'Object'
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
                  Headers: {
                    'x-functions-key': functionApp.listKeys().functionKeys.default
                  }
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
        value: {
          keyvault: {
            id: logicAppConnection.outputs.resourceId
            connectionName: logicAppConnection.outputs.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
          }
        }
      }
    }
  }
}

module keyVaultSecretsUser 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  name: 'keyVaultSecretsUser'
  params: {
    principalId: logicApp.outputs.systemAssignedMIPrincipalId
    resourceId: keyVault.id
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}
