param galleryResourceId string
param galleryApplicationName string
param location string
@secure()
param mediaLink string
param installCommand string
param removeCommand string
param packageFileName string

resource gallery 'Microsoft.Compute/galleries@2023-07-03' existing = {
  name: split(galleryResourceId, '/')[8]
}

resource galleryApplication 'Microsoft.Compute/galleries/applications@2023-07-03' existing = {
  name: galleryApplicationName
  parent: gallery
}

resource galleryApplicationVersion 'Microsoft.Compute/galleries/applications/versions@2023-07-03' = {
  name: '1.0.0'
  location: location
  parent: galleryApplication
  properties: {
    publishingProfile: {
      source: {
        mediaLink: mediaLink
      }
      manageActions: {
        install: installCommand
        remove: removeCommand
      }
      settings: {
        packageFileName: packageFileName
      }
      enableHealthCheck: false
      targetRegions: [
        {
          name: location
          regionalReplicaCount: 1
          storageAccountType: 'Standard_LRS'
        }
      ]
      replicaCount: 1
      excludeFromLatest: false
      storageAccountType: 'Standard_LRS'
    }
  }
}

output resourceId string = galleryApplicationVersion.id
output name string = galleryApplicationVersion.name
