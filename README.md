# VirtualGameController
iOS game controller framework that wraps GCController and supports the development of software-based controllers.  

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
	- [Motion (Accelerometer)](#motion)
1. [Game Integration](#game_integration)

## Requirements

- iOS 9.0+ / Mac OS X 10.9+
- Xcode 7

## Platform Support

- iOS
- tvOS
- OS X
- watchOS

## Integration

Framework projects are included in the workspace.

```swift
import VirtualGameController
```

## Terminology

* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".

## Software-based Peripheral
####Initialization
```swift
VgcManager.startAs(.Peripheral, customElements: CustomElements(), customMappings: CustomMappings())
```
Pass an empty string to deviceUID to have it be created by the system using NSUUID() and stored to user defaults.  

Pass an empty string to vendorName and the device network name will be used to identify the Peripheral.

```swift
VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
```
####Finding Central Services
Begin the search for Bridges and Centrals:

```swift
VgcManager.peripheral.browseForServices()
```
Access the current set of found services:

```swift
VgcManager.peripheral.availableServices
```

Related notifications:

```swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)
NSNotificationCenter.defaultCenter().addObserver(self, selector: "lostService:", name: VgcPeripheralLostService, object: nil)
```
        
####Connecting to a Central
Once a reference to a service (either a Central or Bridge) is obtained, it is passed to the following method:

```swift
VgcManager.peripheral.connectToService(service)
```
####Sending Values to a Central
An Element class is provided, each instance of which represents a hardware or software controller element.  Sets of elements are made available for each supported profile (Micro Gamepad, Gamepad, Extended Gamepad and Motion).  For Peripherals, a global variable "elements" contains the entire set of elements.  To send a value to the Central, the value property of the appropriate Element object is set, and the element is passed to the "sendElementState" method.

```swift
let leftShoulder = VgcManager.peripheral.elements.leftShoulder
leftShoulder.value = 1.0z
VgcManager.peripheral.sendElementState(leftShoulder)
```

####Notifications
####Player Index
####Motion (Accelerometer)
## Game Integration 
