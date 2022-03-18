param location string
param vnetId string
param acrSubnetId string

@allowed([
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Premium'

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = false

var acrName  = 'acr${uniqueString(resourceGroup().id)}'
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Disabled'
  }

  resource agentPool 'agentPools@2019-06-01-preview' = {
    name: 'acrAgentPool'
    location: location
    properties: {
      tier: 'S1'
      virtualNetworkSubnetResourceId: acrSubnetId
      os: 'Linux'
      count: 1
    }
  }

  resource acrTask 'tasks@2019-06-01-preview' = {
    name: 'acrTask'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      agentPoolName: containerRegistry::agentPool.name
      platform: {
        os: 'Linux'
      }
      status: 'Enabled'
      step: {
        type: 'FileTask'
        taskFilePath: 'build-task.yaml'
        contextPath: 'https://github.com/Azure-Samples/acr-build-helloworld-node.git'
      }
    }
  }
}

var acrDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'
resource acrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: acrDnsZoneName
  location: 'global'
  
  resource  vnetLink 'virtualNetworkLinks' = {
    name: 'acrVnetLink'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnetId
      }
    }
  }
}

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'acrPrivateEndpoint${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    subnet: {
      id: acrSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'acrServiceLink${uniqueString(resourceGroup().id)}'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'acrDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: acrDnsZone.id
          }
        }
      ]
    }
  }
}


