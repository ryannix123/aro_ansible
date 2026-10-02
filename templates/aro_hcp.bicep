// Azure Red Hat OpenShift with hosted control planes (public preview)
// ------------------------------------------------------------------
// Everything an ARO HCP cluster needs, in one idempotent ARM deployment:
//   NSG + VNet (worker subnet, delegated VNet-integration subnet)
//   12 operator managed identities + 1 service managed identity
//   Role assignments (built-in ARO / ARO HCP roles)
//   Key Vault + RSA key for customer-managed etcd (KMS) encryption
//   Cluster + one node pool
//
// Driven by aro_deployment.yaml (aro_architecture: hcp). Based on the
// Microsoft Learn "Create an ARO HCP cluster" procedure, API 2026-09-01-preview.

targetScope = 'resourceGroup'

// ---------- Cluster ----------
@description('Cluster name')
param clusterName string

@description('Azure region (must be an ARO HCP preview region)')
param location string = resourceGroup().location

@description('OpenShift minor version for the control plane, e.g. 4.20')
param clusterVersion string

@description('Name of the managed resource group the service creates')
param managedResourceGroupName string = '${clusterName}-managed-rg'

@description('Optional DNS base domain prefix (<=15 chars, lowercase)')
@maxLength(15)
param baseDomainPrefix string = ''

@allowed(['Public', 'Private'])
param apiVisibility string = 'Public'

@description('Optional list of IPv4 CIDRs allowed to reach the API server')
param apiAuthorizedCidrs array = []

@allowed(['Public', 'Private'])
param ingressVisibility string = 'Public'

@description('Immutable: FIPS-validated crypto on worker nodes')
@allowed(['None', 'FIPS'])
param cryptoRestrictions string = 'None'

@allowed(['Enabled', 'Disabled'])
param imageRegistryState string = 'Enabled'

// ---------- Network ----------
param nsgName string
param vnetName string
param vnetCidr string = '10.0.0.0/16'
param workerSubnetName string = 'workers'
param workerSubnetCidr string = '10.0.0.0/24'
param integrationSubnetName string = 'vnet-integration'
param integrationSubnetCidr string = '10.0.1.0/24'
param podCidr string = '10.128.0.0/14'
param serviceCidr string = '172.30.0.0/16'
param hostPrefix int = 23

// ---------- etcd encryption ----------
@description('Globally unique Key Vault name (3-24 chars)')
@minLength(3)
@maxLength(24)
param keyVaultName string
param etcdKeyName string = 'etcd-data-kms-encryption-key'

// ---------- Node pool ----------
param nodePoolName string = 'workers'

@description('OpenShift patch version for the node pool, e.g. 4.20.8')
param nodePoolVersion string
param nodeVmSize string = 'Standard_D8s_v3'
param nodeCount int = 2
param nodeOsDiskSizeGiB int = 64

param tags object = {}

// ---------- Built-in role definition GUIDs ----------
var roles = {
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  hcpClusterApiProvider: '88366f10-ed47-4cc0-9fab-c8a06148393e'
  hcpControlPlaneOperator: 'fc0c873f-45e9-4d0d-a7d1-585aab30c6ed'
  cloudControllerManager: 'a1f96423-95ce-4224-ab27-4e3dc72facd4'
  ingressOperator: '0336e1d3-7a87-462b-b6db-342b63f7802c'
  fileStorageOperator: '0d7aedc0-15fd-4a67-a412-efad370c947e'
  networkOperator: 'be7a6435-15ae-4171-8f30-4a343eff9e8f'
  imageRegistryOperator: '8b32b316-c2f5-4ddf-b05b-83dacd2d08b5'
  federatedCredential: 'ef318e2a-8334-4a05-9e4a-295a196c6a6e'
  hcpServiceManagedIdentity: 'c0ff367d-66d8-445e-917c-583feb0ef0d4'
  keyVaultCryptoUser: '12338af0-0e69-4776-bea7-57ae8d297424'
}

// Operator identities: cp-* = control plane operators, dp-* = data plane operators
var identityNames = [
  'cp-cluster-api-azure'
  'cp-control-plane'
  'cp-cloud-controller-manager'
  'cp-ingress'
  'cp-disk-csi-driver'
  'cp-file-csi-driver'
  'cp-image-registry'
  'cp-cloud-network-config'
  'cp-kms'
  'dp-disk-csi-driver'
  'dp-file-csi-driver'
  'dp-image-registry'
]

// Who needs what, grouped by scope
var subnetAssignments = [
  { mi: 'cp-cluster-api-azure', role: roles.hcpClusterApiProvider }
  { mi: 'cp-cloud-controller-manager', role: roles.cloudControllerManager }
  { mi: 'cp-ingress', role: roles.ingressOperator }
  { mi: 'cp-file-csi-driver', role: roles.fileStorageOperator }
  { mi: 'cp-cloud-network-config', role: roles.networkOperator }
  { mi: 'dp-file-csi-driver', role: roles.fileStorageOperator }
]
var vnetAssignments = [
  { mi: 'cp-cluster-api-azure', role: roles.hcpClusterApiProvider }
  { mi: 'cp-control-plane', role: roles.hcpControlPlaneOperator }
  { mi: 'cp-cloud-controller-manager', role: roles.cloudControllerManager }
  { mi: 'cp-ingress', role: roles.ingressOperator }
  { mi: 'cp-file-csi-driver', role: roles.fileStorageOperator }
  { mi: 'cp-image-registry', role: roles.imageRegistryOperator }
  { mi: 'cp-cloud-network-config', role: roles.networkOperator }
  { mi: 'dp-file-csi-driver', role: roles.fileStorageOperator }
  { mi: 'dp-image-registry', role: roles.imageRegistryOperator }
]
var nsgAssignments = [
  { mi: 'cp-control-plane', role: roles.hcpControlPlaneOperator }
  { mi: 'cp-cloud-controller-manager', role: roles.cloudControllerManager }
  { mi: 'cp-file-csi-driver', role: roles.fileStorageOperator }
  { mi: 'dp-file-csi-driver', role: roles.fileStorageOperator }
]

// ======================= Network =======================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  tags: tags
}

// Subnets are declared inline so re-deploying the VNet never wipes them
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [vnetCidr] }
    subnets: [
      {
        name: workerSubnetName
        properties: {
          addressPrefix: workerSubnetCidr
          networkSecurityGroup: { id: nsg.id }
        }
      }
      {
        name: integrationSubnetName
        properties: {
          addressPrefix: integrationSubnetCidr
          networkSecurityGroup: { id: nsg.id }
          delegations: [
            {
              name: 'aro-hcp-delegation'
              properties: { serviceName: 'Microsoft.RedHatOpenShift/hcpOpenShiftClusters' }
            }
          ]
        }
      }
    ]
  }
}

resource workerSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: workerSubnetName
}

resource integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  parent: vnet
  name: integrationSubnetName
}

// ======================= Identities =======================
resource operatorMi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [
  for n in identityNames: {
    name: '${clusterName}-${n}'
    location: location
    tags: tags
  }
]

resource serviceMi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${clusterName}-service-managed-identity'
  location: location
  tags: tags
}

// ======================= Role assignments =======================
resource subnetRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for a in subnetAssignments: {
    name: guid(workerSubnet.id, clusterName, a.mi, a.role)
    scope: workerSubnet
    properties: {
      principalId: operatorMi[indexOf(identityNames, a.mi)].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', a.role)
    }
  }
]

resource vnetRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for a in vnetAssignments: {
    name: guid(vnet.id, clusterName, a.mi, a.role)
    scope: vnet
    properties: {
      principalId: operatorMi[indexOf(identityNames, a.mi)].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', a.role)
    }
  }
]

resource nsgRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for a in nsgAssignments: {
    name: guid(nsg.id, clusterName, a.mi, a.role)
    scope: nsg
    properties: {
      principalId: operatorMi[indexOf(identityNames, a.mi)].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', a.role)
    }
  }
]

// Service MI: Reader on every control-plane identity, Federated Credential on every data-plane identity
resource serviceMiOnOperatorsRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (n, i) in identityNames: {
    name: guid(operatorMi[i].id, clusterName, 'service-mi')
    scope: operatorMi[i]
    properties: {
      principalId: serviceMi.properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId(
        'Microsoft.Authorization/roleDefinitions',
        startsWith(n, 'cp-') ? roles.reader : roles.federatedCredential
      )
    }
  }
]

resource serviceMiVnetRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, clusterName, 'service-mi', roles.hcpServiceManagedIdentity)
  scope: vnet
  properties: {
    principalId: serviceMi.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.hcpServiceManagedIdentity)
  }
}

resource serviceMiNsgRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(nsg.id, clusterName, 'service-mi', roles.hcpServiceManagedIdentity)
  scope: nsg
  properties: {
    principalId: serviceMi.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.hcpServiceManagedIdentity)
  }
}

// ======================= etcd KMS =======================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    publicNetworkAccess: 'Enabled'
    sku: { family: 'A', name: 'standard' }
  }
}

// NOTE: every ARM PUT of a key creates a new key version. The playbook
// therefore skips this deployment once the cluster exists.
resource etcdKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: keyVault
  name: etcdKeyName
  properties: {
    kty: 'RSA'
    keySize: 2048
  }
}

resource kmsRa 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, clusterName, 'cp-kms', roles.keyVaultCryptoUser)
  scope: keyVault
  properties: {
    principalId: operatorMi[indexOf(identityNames, 'cp-kms')].properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultCryptoUser)
  }
}

// ======================= Cluster =======================
resource cluster 'Microsoft.RedHatOpenShift/hcpOpenShiftClusters@2026-09-01-preview' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${serviceMi.id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-cluster-api-azure')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-control-plane')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-cloud-controller-manager')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-ingress')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-disk-csi-driver')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-file-csi-driver')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-image-registry')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-cloud-network-config')].id}': {}
      '${operatorMi[indexOf(identityNames, 'cp-kms')].id}': {}
    }
  }
  properties: {
    version: {
      id: clusterVersion
      channelGroup: 'stable'
    }
    dns: empty(baseDomainPrefix) ? {} : { baseDomainPrefix: baseDomainPrefix }
    network: {
      networkType: 'OVNKubernetes'
      podCidr: podCidr
      serviceCidr: serviceCidr
      machineCidr: vnetCidr
      hostPrefix: hostPrefix
    }
    etcd: {
      dataEncryption: {
        keyManagementMode: 'CustomerManaged'
        customerManaged: {
          encryptionType: 'KMS'
          kms: {
            activeKey: {
              name: etcdKeyName
              version: last(split(etcdKey.properties.keyUriWithVersion, '/'))
            }
            vaultName: keyVaultName
            visibility: 'Public'
          }
        }
      }
    }
    api: union(
      { visibility: apiVisibility },
      empty(apiAuthorizedCidrs) ? {} : { authorizedCidrs: apiAuthorizedCidrs }
    )
    ingress: { type: ingressVisibility }
    cryptoRestrictions: cryptoRestrictions
    clusterImageRegistry: { state: imageRegistryState }
    platform: {
      managedResourceGroup: managedResourceGroupName
      subnetId: workerSubnet.id
      vnetIntegrationSubnetId: integrationSubnet.id
      outboundType: 'LoadBalancer'
      networkSecurityGroupId: nsg.id
      operatorsAuthentication: {
        userAssignedIdentities: {
          controlPlaneOperators: {
            'cluster-api-azure': operatorMi[indexOf(identityNames, 'cp-cluster-api-azure')].id
            'control-plane': operatorMi[indexOf(identityNames, 'cp-control-plane')].id
            'cloud-controller-manager': operatorMi[indexOf(identityNames, 'cp-cloud-controller-manager')].id
            ingress: operatorMi[indexOf(identityNames, 'cp-ingress')].id
            'disk-csi-driver': operatorMi[indexOf(identityNames, 'cp-disk-csi-driver')].id
            'file-csi-driver': operatorMi[indexOf(identityNames, 'cp-file-csi-driver')].id
            'image-registry': operatorMi[indexOf(identityNames, 'cp-image-registry')].id
            'cloud-network-config': operatorMi[indexOf(identityNames, 'cp-cloud-network-config')].id
            kms: operatorMi[indexOf(identityNames, 'cp-kms')].id
          }
          dataPlaneOperators: {
            'disk-csi-driver': operatorMi[indexOf(identityNames, 'dp-disk-csi-driver')].id
            'file-csi-driver': operatorMi[indexOf(identityNames, 'dp-file-csi-driver')].id
            'image-registry': operatorMi[indexOf(identityNames, 'dp-image-registry')].id
          }
          serviceManagedIdentity: serviceMi.id
        }
      }
    }
  }
  dependsOn: [
    subnetRa
    vnetRa
    nsgRa
    serviceMiOnOperatorsRa
    serviceMiVnetRa
    serviceMiNsgRa
    kmsRa
  ]
}

resource nodePool 'Microsoft.RedHatOpenShift/hcpOpenShiftClusters/nodePools@2026-09-01-preview' = {
  parent: cluster
  name: nodePoolName
  location: location
  tags: tags
  properties: {
    version: {
      id: nodePoolVersion
      channelGroup: 'stable'
    }
    platform: {
      subnetId: workerSubnet.id
      vmSize: nodeVmSize
      osDisk: {
        sizeGiB: nodeOsDiskSizeGiB
        diskStorageAccountType: 'StandardSSD_LRS'
      }
    }
    replicas: nodeCount
  }
}

output clusterId string = cluster.id
output nodePoolId string = nodePool.id
