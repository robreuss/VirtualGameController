# VirtualGameController
iOS game controller framework that wraps GCController and supports the development of software-based controllers.  

1. [Features](#features)
1. [Requirements](#requirements)
1. [Platform Support](#platform_support)
1. [Terminology](#terminology)
1. [Integration](#integration)
1. [Sample Projects](#samples)
1. [Software-based Peripheral](#usage)
	- [Initialization](#initialization)
	- [Finding Central Services](#finding_services)
	- [Connecting to a Central](#connecting)
	- [Sending Values to a Central](#sending)
	- [System Messages](#system_messages)
	- [Player Index](#player_index)
	- [Motion (Accelerometer)](#motion)
1. [Game Integration](#game_integration)
 	- [GCController Replacement](#gccontroller)
	- [Central versus Bridge](#central_versus_bridge)
	- [Extended Functionality](#extended)

## Features

- Drop-in replacement (wrapper) for *GameController*
- Software-based controllers on all supported platforms
- Device motion support
- Custom controller elements
- Custom element mapping
- WiFi-based
- Controller-forwarding
- Unlimited number of controllers on Apple TV (with caveats)
- Ability to enhance slide-on/form-fitting controllers with motion, Extended profile and custom elements
- iCade controller support (mapped into _GameController_, so they appear as MFi hardware)
- Easy to implement 3d touch on software controllers
- Easy to utilize on-screen and Bluetooth keyboards with software controllers
- Support for snapshots (using Apple format)
- Use of hardware keyboard with Apple TV (when in combination with a software controller)
- Developed in Swift
- Framework-based


## Requirements

- iOS 9.0+ / Mac OS X 10.9+
- Xcode 7

## Platform Support

- iOS
- tvOS
- OS X
- watchOS


## Terminology
* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".


## Integration
Platform-specific framework projects are included in the workspace.  A single framework file supports both Peripherals (software-based controllers) and Centrals (games, replacement for GCController).

```swift
import VirtualGameController
```

CocoaPods and Carthage support will be forthcoming.

## Sample Projects Notes

A number of sample projects are included that demonstrate the app roles (Peripheral, Bridge and Central) for different platforms (iOS, tvOS, OS X, watchOS).  A few notes:

- To explore using your _Apple Watch_ as a controller, use the __iOS Bridge__ sample, which is setup as a watchOS project.  A watch can interact with the iPhone it is paired to as either a Bridge (forwarding values to some other Central) or as a Central (displaying the game interface directly on the paired iPhone).  Discovery of paired watches is automatic.


## Creating a Software-based Peripheral
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
####GCController Replacement
**VirtualGameController** is designed to be a drop-in replacement for the Apple framework **GameController**:

```swift
import GameController
```

becomes...

```swift
import VirtualGameController
```

The interface for the controller class **VgcController** is the same as that of **GCController**, and for the most part an existing game can be transitioned by doing a global search that replaces **GCC** with **VgcC**.  There are a couple of exceptions where **GameController** structures are used and should not be modified:

```swift
GCControllerButtonValueChangedHandler
GCControllerDirectionPadValueChangedHandler
```
If you wish to test integration of the framework, it is proven to work with the Apple [DemoBots](https://developer.apple.com/library/prerelease/ios/samplecode/DemoBots/Introduction/Intro.html) sample project. The one limitation is that when using the Apple TV version, you must use the Remote to start the game because of issues related to how *DemoBots* implements [this functionality](https://developer.apple.com/library/prerelease/ios/documentation/ServicesDiscovery/Conceptual/GameControllerPG/ControllingInputontvOS/ControllingInputontvOS.html#//apple_ref/doc/uid/TP40013276-CH7-DontLinkElementID_13) (see the last paragraph on that page).

####Central versus Bridge
There are two types of Central app integrations and which result in dramatically different: **Central** and **Bridge**.

A **Central** is exactly what you expect in terms of game integration: your Central is your game and there should only be one implemented at a time.  

A **Bridge** combines the behavior of a Central and a Peripheral; it is a Peripheral in relation to your Central, and it is a Central in relation to your Peripheral(s).  Another name for it would be a *controller forwarder*, because it's primary function is to forward/relay values sent by one or more Peripherals to the Central.  The Peripheral could be a MFi hardware controller, an iCade hardware controller, an *Apple Watch* or a software-based virtual controller (assuming the Bridge is deployed on an iPhone paired to the watch).  If the bridge is implemented on a device with device motion support (an iOS device) the Bridge can extend the capabilities of a Peripheral to include motion support.  For example, a MFi or iCade controller can appear to the Central to implement the motion profile.  

####Extended Functionality
There are two features supported by a Central that exceed the capabilities of the Apple *GameController* framework, and should be used with caution if you want to make reverting to that framework easy:

- Custom elements
- Custom mapping

####Potential App Store Approval Issues
There is only one feature that I think may cause problems with app approval: snapshots.  *VirtualGameController* not only supports the same snapshot functionality offered by *GameController*, it does so using the same data format, which is private.

##Donations
If you like VirtualGameController, please feel free to donate to support it's continued development!

<div>
<script src="https://raw.github.com/paypal/JavaScriptButtons/master/dist/paypal-button.min.js?merchant=MERCHANT_ID"
    data-button="buynow"
    data-name="Donate to The Changelog"
    data-amount="5.00"
></script>
</div>

