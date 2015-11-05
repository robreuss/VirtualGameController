# VirtualGameController
iOS game controller framework that wraps GCController and supports development of software-based controllers.

1. [Platform Support](#platform_support)
1. [Integration](#integration)
1. [Terminology](#terminology)
1. [Software-based Peripheral](#usage)
- [Initialization](#initialization)
- [Finding Central Services](#finding_services)
- [Connecting to a Central](#connecting)
- [Sending Values to a Central](#sending)
- [Notifications](#notifications)
- [Player Index](#player_index)
- [Motion (Accelerometer](#motion)
1. [Game Integration](#work-with-alamofire)

## Requirements

- iOS 7.0+ / Mac OS X 10.9+
- Xcode 7

## Platform Support
## Integration
## Terminology 
## Software-based Peripheral
####Initialization
```swift
VgcManager.startAs(.Peripheral, customElements: CustomElements(), customMappings: CustomMappings())
```
```swift
VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
```
####Finding Central Services
```swift
VgcManager.peripheral.browseForServices()
```
####Connecting to a Central
####Sending Values to a Central
####Notifications
####Player Index
####Motion
## Game Integration 
