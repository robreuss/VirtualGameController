# VirtualGameController
iOS game controller framework that wraps GCController and supports the development of software-based controllers.  

1. [Platform Support](#platform_support)
1. [Integration](#integration)
1. [Sample Projects](#samples)
1. [Terminology](#terminology)
1. [Software-based Peripheral](#usage)
	- [Initialization](#initialization)
	- [Finding Central Services](#finding_services)
	- [Connecting to a Central](#connecting)
	- [Sending Values to a Central](#sending)
	- [System Messages](#system_messages)
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

Platform-specific framework projects are included in the workspace.

```swift
import VirtualGameController
```

## Sample Projects

A number of sample projects are included that demonstrate the app roles (Peripheral, Bridge and Central) for different platforms (iOS, tvOS, OS X, watchOS).  A few notes:

- To explore using your Apple Watch as a controller, reference the iOS Bridge sample, which is setup as a watchOS project.  A watch can interact with the iPhone it is paired to as either a Bridge (forwarding values to some other Central) or as a Central (displaying the game interface directly on the paired iPhone).  Discovery of paired watches is automatic.



## Terminology

* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".

## Software-based Peripheral
####Initialization
Note that in the following example, no custom elements or custom mappings are being set.  See elsewhere in this document for a discussion of how those are handled (or see the sample projects).  **appIdentifier** is for use with Bonjour and should be a short, unique identifier for your app.

```swift
VgcManager.startAs(.Peripheral, appIdentifier: "MyAppID", customElements: nil, customMappings: nil)
```
After calling the **startAs** method, the Peripheral may be defined by setting it's **deviceInfo** property.  It is not required and the following example settings is the default and should suffice for most purposes.

Pass an empty string to deviceUID to have it be created by the system using NSUUID() and stored to user defaults.  

Pass an empty string to vendorName and the device network name will be used to identify the Peripheral.

```swift
VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
```
####Finding Central Services
In the simplest implementation, you'll just be connecting to the first Central service you find, and if you always use a Bridge, you'll be connecting to the first Bridge you find.  In those cases, you'll want to start the search and use the notification to call the **connectToService** method described below.

Things get a bit more complicated if you are using both methods, and the following methods and notifications should be able to handle most scenarios.

Begin the search for Bridges and Centrals:

```swift
VgcManager.peripheral.browseForServices()
```
Access the current set of found services:

```swift
VgcManager.peripheral.availableServices
```

Related notifications - both notifications carry a reference to a VgcService as their payload:

```swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)
NSNotificationCenter.defaultCenter().addObserver(self, selector: "lostService:", name: VgcPeripheralLostService, object: nil)
```
        
####Connecting to and Disconnecting from a Central
Once a reference to a service (either a Central or Bridge) is obtained, it is passed to the following method:

```swift
VgcManager.peripheral.connectToService(service)
```

To disconnect from a service:

```swift
VgcManager.peripheral.disconnectFromService()
```

Related notifications:

```swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidConnect:", name: VgcPeripheralDidConnectNotification, object: nil)
NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidDisconnect:", name: VgcPeripheralDidDisconnectNotification, object: nil)
```

####Sending Values to a Central
An Element class is provided, each instance of which represents a hardware or software controller element.  Sets of elements are made available for each supported profile (Micro Gamepad, Gamepad, Extended Gamepad and Motion).  To send a value to the Central, the value property of the appropriate Element object is set, and the element is passed to the "sendElementState" method.

```swift
let leftShoulder = VgcManager.elements.leftShoulder
leftShoulder.value = 1.0
VgcManager.peripheral.sendElementState(leftShoulder)
```

####System Messages
The only currently implemented system message relevant to the Peripheral role is a message sent by the Central when it receives an element value from a Peripheral that fails a checksum test.  System messages are enumerated, and the invalid checksum message is of type .ReceivedInvalidMessage.  

```swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedSystemMessage:", name: VgcSystemMessageNotification, object: nil)
```

Example of handling .ReceivedInvalidMessage:

```swift
    let systemMessageTypeRaw = notification.object as! Int
    let systemMessageType = SystemMessages(rawValue: systemMessageTypeRaw)
    if systemMessageType == SystemMessages.ReceivedInvalidMessage {        
		// Do something
    }
```
####Player Index
When a Central assigns a player index, it triggers the following notification which carries the new player index value as a payload:

```swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedPlayerIndex:", name: VgcNewPlayerIndexNotification, object: nil)
```

####Motion (Accelerometer)
Support for motion updates is contingent on Core Motion support for a given platform (for example, it is not supported on OS X).  The framework should detect it if an attempt is made to start motion updates on an unsupported platform.

```swift
VgcManager.peripheral.motion.start()
VgcManager.peripheral.motion.stop()
```
## Game Integration 
