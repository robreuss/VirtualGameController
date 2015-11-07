[![Swift 2.0](https://img.shields.io/badge/Swift-2.0-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Platforms OS X | iOS | watchOS | tvOS](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-lightgray.svg?style=flat)](https://developer.apple.com/swift/)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](https://github.com/robreuss/VirtualGameController/blob/master/LICENSE)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?style=flat-square)](https://paypal.me/robreuss)

# Virtual Game Controller

## Features

- Drop-in replacement for Apple's *GameController* framework
- Software-based controllers (that use the MFi profiles) on all supported platforms
- Device motion support
- Custom controller elements
- Custom element mapping
- WiFi-based, with Bluetooth fallback
- Controller-forwarding
- Works with Apple TV Simulator
- Unlimited number of hardware controllers on Apple TV (using controller forwarding)
- Ability to enhance slide-on/form-fitting controllers with motion, extended profile elements and custom elements
- iCade controller support (mapped through the *GameController* profiles so they appear as MFi hardware)
- Easy to implement 3d touch on software controllers
- Leverage on-screen and Bluetooth keyboards using software controllers (including with Apple TV)
- Support for snapshots (compatible with Apple's snapshot format)
- Swift 2.0
- Framework-based

## Requirements

- iOS 9.0+ / Mac OS X 10.9+
- Xcode 7 / Swift 2.0

## Platform Support

- iOS
- tvOS
- OS X
- watchOS

## Screenshots
![Alt Peripheral](http://robreuss.squarespace.com/storage/peripheral2.png =300x534 "Peripheral")![Alt Central](http://robreuss.squarespace.com/storage/central2.png =300x534 "Central")![Alt Central Selector](http://robreuss.squarespace.com/storage/peripheral_central_selector2.png =300x534 "Central Selector")

## Terminology
* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".


## Integration
Platform-specific framework projects are included in the workspace.  A single framework file supports both Peripherals (software-based controllers) and Centrals (games, replacement for GCController).

``` swift
import VirtualGameController
```

CocoaPods and Carthage support will be forthcoming!

## Sample Projects Notes

A number of sample projects are included that demonstrate the app roles (Peripheral, Bridge and Central) for different platforms (iOS, tvOS, OS X, watchOS).  A few notes:

- In order to run the samples, you need to build and add the framework files to the sample project:

	 1. Clean and build the framework project for the target platform
    1. Navigate to the sample project source code
    2. The framework file will appear in red; delete it
    3. Bring up the project properties and go to the General tab
    4. Remove the existing framework reference under Embedded Binaries
    4. Click the plus button under Embedded Binaries
    5. Find the appropriate framework file for the target platform and add it
    6. Note that if building the Bridge sample project, you'll also need to add the watchOS framework to the watch extension target.
    6. You should be able to run the project now in either the simulator or on a device

    If you happen to know how I can ensure that the frameworks stay linked to the sample projects, please let me know at <virtualgamecontroller@gmail.com>.  As it is, they point to DerivedData and lose their connection when cloned to a different machine.  

- To explore using your _Apple Watch_ as a controller, use the __iOS Bridge__ sample, which is setup as a watchOS project.  A watch can interact with the iPhone it is paired to as either a Bridge (forwarding values to some other Central) or as a Central (displaying the game interface directly on the paired iPhone).  Discovery of paired watches is automatic.


## Creating a Software-based Peripheral
####Initialization
Note that in the following example, no custom elements or custom mappings are being set.  See elsewhere in this document for a discussion of how those are handled (or see the sample projects). 

``` swift
 VgcManager.startAs(.Peripheral, appIdentifier: "MyAppID", customElements: CustomElements(), customMappings: CustomMappings())
```

The parameter `appIdentifier` is for use with Bonjour and should be a short, unique identifier for your app.
 
A simplified form is available if custom mapping and custom elements are not used:

``` swift
VgcManager.startAs(.Peripheral, appIdentifier: "MyAppID")
```
Documentation of the custom mapping and custom elements functionality is coming soon, although the combination of the sample projects and class files are probably enough for you to get going.

After calling the `startAs` method, the Peripheral may be defined by setting it's `deviceInfo` property.  Doing so is not required as the defaults (shown here) should suffice for most purposes.

``` swift
VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
```

Pass an empty string to `deviceUID` to have it be created by the system using `NSUUID()` and stored to user defaults.  

Pass an empty string to `vendorName` and the device network name will be used to identify the Peripheral.  

####Finding Central Services

Begin the search for Bridges and Centrals:

``` swift
VgcManager.peripheral.browseForServices()
```
Access the current set of found services:

``` swift
VgcManager.peripheral.availableServices
```

Related notifications - both notifications carry a reference to a VgcService as their payload:

``` swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)
NSNotificationCenter.defaultCenter().addObserver(self, selector: "lostService:", name: VgcPeripheralLostService, object: nil)
```
In the simplest implementation, you'll be connecting to the first Central service you find, whereas if you always use a Bridge, you'll be connecting to the first Bridge you find.  In those cases, you'll want to start the search and use the `VgcPeripheralFoundService ` notification to call the `connectToService` method.

If you choose to implement a more complex scenario, where you have multiple Peripherals that connect to either a Bridge or Central, the combination of the above methods and notifications should have you covered.  The sample projects implement this type of flexible scenario.
        
####Connecting to and Disconnecting from a Central
Once a reference to a service (either a Central or Bridge) is obtained, it is passed to the following method:

``` swift
VgcManager.peripheral.connectToService(service)
```

To disconnect from a service:

``` swift
VgcManager.peripheral.disconnectFromService()
```

Related notifications:

``` swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidConnect:", name: VgcPeripheralDidConnectNotification, object: nil)
NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidDisconnect:", name: VgcPeripheralDidDisconnectNotification, object: nil)
```

####Sending Values to a Central
An Element class is provided, each instance of which represents a hardware or software controller element.  Sets of elements are made available for each supported profile (Micro Gamepad, Gamepad, Extended Gamepad and Motion).  To send a value to the Central, the value property of the appropriate Element object is set, and the element is passed to the `sendElementState` method.

``` swift
let leftShoulder = VgcManager.elements.leftShoulder
leftShoulder.value = 1.0
VgcManager.peripheral.sendElementState(leftShoulder)
```

####System Messages
The only currently implemented system message relevant to the Peripheral role is a message sent by the Central when it receives an element value from a Peripheral that fails a checksum test.  System messages are enumerated, and the invalid checksum message is of type `.ReceivedInvalidMessage`.  

``` swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedSystemMessage:", name: VgcSystemMessageNotification, object: nil)
```

Example of handling `.ReceivedInvalidMessage`:

``` swift
    let systemMessageTypeRaw = notification.object as! Int
    let systemMessageType = SystemMessages(rawValue: systemMessageTypeRaw)
    if systemMessageType == SystemMessages.ReceivedInvalidMessage {        
		// Do something
    }
```
####<a name="player">Player Index</a>
When a Central assigns a player index, it triggers the following notification which carries the new player index value as a payload:

``` swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedPlayerIndex:", name: VgcNewPlayerIndexNotification, object: nil)
```

####Motion (Accelerometer)
Support for motion updates is contingent on Core Motion support for a given platform (for example, it is not supported on OS X).  The framework should detect it if an attempt is made to start motion updates on an unsupported platform.

``` swift
VgcManager.peripheral.motion.start()
VgcManager.peripheral.motion.stop()
```
## Game Integration 
####GCController Replacement
**VirtualGameController** is designed to be a drop-in replacement for the Apple framework **GameController** (although both frameworks should be included because some **GameController** header references are required):

``` swift
import GameController
```

becomes...

``` swift
import GameController
import VirtualGameController
```

A framework file specific to your targetted platform must be used, and framework files are provided for each platform.

The interface for the controller class **VgcController** is the same as that of **GCController**, and for the most part an existing game can be transitioned by doing a global search that replaces "**GCC**" with "**VgcC**".  There are some exceptions where **GameController** structures are used and these can be left as GC references:

``` swift
GCControllerButtonValueChangedHandler
GCControllerDirectionPadValueChangedHandler
GCControllerElement
GCMicroGamepad
GCGamepad
GCExtendedGamepad
GCMotion
```

If you wish to test integration of the framework, it is proven to work with the Apple [DemoBots](https://developer.apple.com/library/prerelease/ios/samplecode/DemoBots/Introduction/Intro.html) sample project. One limitation is that when using the Apple TV version, you must use the Remote to start the game because of issues related to how *DemoBots* implements [this functionality](https://developer.apple.com/library/prerelease/ios/documentation/ServicesDiscovery/Conceptual/GameControllerPG/ControllingInputontvOS/ControllingInputontvOS.html#//apple_ref/doc/uid/TP40013276-CH7-DontLinkElementID_13) (see the last paragraph on that page).

For in-depth instructions on using DemoBots as a test, see the [Wiki page](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-DemoBots), which also provide helpful hints on integrating VirtualGameController with your existing project.

####Central versus Bridge
There are two types of Central app integrations and which result in dramatically different: **Central** and **Bridge**.

A **Central** is exactly what you expect in terms of game integration: your Central is your game and there should only be one implemented at a time.  

A **Bridge** combines the behavior of a Central and a Peripheral; it is a Peripheral in relation to your Central, and it is a Central in relation to your Peripheral(s).  Another name for it would be a *controller forwarder*, because it's primary function is to forward/relay values sent by one or more Peripherals to the Central.  The Peripheral could be a MFi hardware controller, an iCade hardware controller, an *Apple Watch* or a software-based virtual controller (assuming the Bridge is deployed on an iPhone paired to the watch).  If the bridge is implemented on a device with device motion support (an iOS device) the Bridge can extend the capabilities of a Peripheral to include motion support.  For example, a MFi or iCade controller can appear to the Central to implement the motion profile.  

####Extended Functionality
There are two features supported by a Central that exceed the capabilities of the Apple *GameController* framework, and should be used with caution if you want to make reverting to that framework easy:

- Custom elements
- Custom mapping

##Donations
If you like VirtualGameController, please feel free to [donate](https://paypal.me/robreuss) to support it's continued development!
##Contact
Reach out using [LinkedIn](https://www.linkedin.com/pub/rob-reuss/2/7b/488) or <virtualgamecontroller@gmail.com>.
##License
The MIT License (MIT)

Copyright (c) [2015] [Rob Reuss]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.



