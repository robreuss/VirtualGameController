[![Language](https://img.shields.io/badge/Language-Swift%202.0%20%7C%20Obj%20C-orange.svg?style=flat)](https://developer.apple.com/swift/)
[![Platforms OS X | iOS | watchOS | tvOS](https://img.shields.io/badge/Platforms-OS%20X%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-lightgray.svg?style=flat)](https://developer.apple.com/swift/)
[![License MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](https://github.com/robreuss/VirtualGameController/blob/master/LICENSE)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-4BC51D.svg?style=flat)](https://cocoapods.org/?q=virtualgamecontroller)
![Travis](https://travis-ci.org/robreuss/VirtualGameController.svg)

# Virtual Game Controller

## Features

- Wraps Apple's *GameController* framework API (GCController)
- Create software-based controllers (that use the MFi profiles)
- Controller forwarding
- Bidirectional communication between software-based controllers and game, including larger files such as images represented as NSData (on a seperate channel)
- Device motion support
- Custom controller elements
- Custom element mapping
- WiFi-based, with Bluetooth fallback
- Works with Apple TV Simulator
- Unlimited number of hardware controllers on Apple TV (using controller forwarding)
- Ability to enhance inexpensive slide-on/form-fitting controllers with motion, extended profile elements and custom elements
- iCade controller support (mapped through the MFi profiles so they appear as MFi hardware)
- Easy-to-implement 3d touch on software controllers
- Leverage on-screen and Bluetooth keyboards using software controllers (including with Apple TV)
- Support for snapshots (compatible with Apple's snapshot format)
- Swift 2.1 or Objective C
- Framework-based

## Requirements 

- iOS 9.0+ / Mac OS X 10.9+
- Xcode 7 / Swift 2.0 / Objective C

## Platform Support

- iOS
- tvOS
- OS X
- watchOS

## Some Use Cases
**VirtualGameController** is a drop-in replacement for Apple's _Game Controller_ framework, so it can be easily integrated into existing games, provide protection in case you need to revert to using Apple's framework, and allow for features that go beyond _Game Controller_ but use the MFi profiles.  A single game-side implementation can work with a wide range of controller scenarios.  **VirtualGameController** may be useful for you in the following cases:

- **Developing and supporting software-based controllers.**  Enable your users to use their iPhone, iPad or Apple Watch to control your game, leveraging 3d touch and motion input.  Inputs are flowed through the GCController API (that is, through the MFi profiles) and so your software-based controller will appear as a hardware-based controller.  Easily send information from your game to your software controller (bidirectional communication).  The API for creating a software-based controller is simple and easy-to-use.  
- **Creating a hybrid hardware/software controller using controller forwarding.**  Apple described a feature called "controller forwarding" in a session at WWDC in 2014 (at around _29:00_, [https://developer.apple.com/videos/play/wwdc2014-611/](https://developer.apple.com/videos/play/wwdc2014-611/)) but as far as I know the feature never emerged. *VirtualGameController* supports controller forwarding in roughly the form described in the session, enabling you to enhance form-fitting hardware controllers with a full profile and motion input.
- **Supporting large numbers of controllers for social games.**  There are no imposed limits on the number of hardware or software controllers that can be used with a game.  The two third-party controller limit on the Apple TV can be exceeded using controller forwarding (bridging), hybrid controllers and software-based controllers. 
- **Creating text-driven games.**  Support for string-based custom inputs makes it easy to create text-oriented games.  Use of dictation is demonstrated in the sample projects.

## Screenshots
The user interfaces in the sample projects are designed for documentation, testing and debugging purposes, rather than for use in games.  

<img src="http://robreuss.squarespace.com/storage/peripheral_central_selector2.png" alt="Selector" width="225"/>
<img src="http://robreuss.squarespace.com/storage/peripheral2.png" alt="Peripheral"  width="225"/>
<img src="http://robreuss.squarespace.com/storage/central2.png" alt="Central" width="275"/>

## Terminology
* **Peripheral**: A software-based game controller.
* **Central**: Typically a game that supports hardware and software controllers.  The Central utilizes VirtualGameController as a replacement for the Apple Game Controller framework.
* **Bridge**: Acts as a relay between a Peripheral and a Central, and represents a hybrid of the two.  Key use case is "controller forwarding".


## Integration
Platform-specific framework projects are included in the workspace.  A single framework file supports both Peripherals (software-based controllers) and Centrals (that is, your game).

``` swift
import VirtualGameController
```

Note that you currently need to ````import GameController```` as well.

See the [instructions on the Wiki](https://github.com/robreuss/VirtualGameController/wiki/Implementing-in-Objective-C) for utilizing Objective C.

#### CocoaPods
Preliminary support is in place for [CocoaPods](https://cocoapods.org/?q=virtualgamecontroller).

#### Carthage
In order to integrate using Carthage, add VGC to your Cartfile:

````
github "robreuss/VirtualGameController"
````

Then use platform-specific commands to create the build products that you need to add to your project:

````
carthage update --platform iOS
carthage update --platform OSX
carthage update --platform tvOS
carthage update --platform watchOS
````

## Using the Sample Projects

A number of sample projects are included that demonstrate the app roles (Peripheral, Bridge and Central) for different platforms (iOS, tvOS, OS X, watchOS), along with projects that demonstrates the use of Objective C and SceneKit.  They are delivered with the framework projects as submodules.  

Other notes on sample projects:

- To explore using your _Apple Watch_ as a controller, use the __iOS Peripheral__ sample, which is setup as a watchOS project.  A watch can interact with the iPhone it is paired to as either a Bridge (forwarding values to some other Central) or as a Central (displaying the game interface directly on the paired iPhone).  Discovery of paired watches is automatic.
- Checking out the SceneKit sample project is a great way to evaluate the motion capabilities of the framework, as well as being fun.  It is implemented as a single project with shared code for targetting iOS, OSX and tvOS.
- There are also instructions on the Wiki for testing using [DemoBots](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-DemoBots) (in Swift) and [SceneKitVehicle](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-SceneKitVehicle) (in Objective C) sample projects from Apple.

## Working with MFi Hardware-based Controllers
VirtualGameController is a wrapper around Apple's Game Controller framework, and so working with hardware controllers with VGC is the same as it is with the [Game Controller framework](https://developer.apple.com/library/tvos/documentation/GameController/Reference/GCController_Ref/index.html).  See the Game Integration section below and the sample projects for additional details.

## Creating a Software-based Peripheral
####Initialization
Note that in the following example, no custom elements or custom mappings are being set.  See elsewhere in this document for a discussion of how those are handled (or see the sample projects). 

``` swift
 VgcManager.startAs(.Peripheral, appIdentifier: "MyAppID", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
```

The parameter `appIdentifier` is for use with Bonjour and should be a short, unique identifier for your app.
 
A simplified form is available if custom mapping and custom elements are not used:

``` swift
VgcManager.startAs(.Peripheral, appIdentifier: "MyAppID", includesPeerToPeer: true)
```
Documentation of the custom mapping and custom elements functionality is coming soon, although the combination of the sample projects and class files are probably enough for you to get going.

The `includesPeerToPeer` parameter is passed through to NSNetServices.  It provides the functionality for connectivity to fallback to Bluetooth or WiFi peer-to-peer.  See the NSNetServices documentation for more information.

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
Access the current set of available services:

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

####Player Index
When a Central assigns a player index, it triggers the following notification which carries the new player index value as a payload:

``` swift
NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedPlayerIndex:", name: VgcNewPlayerIndexNotification, object: nil)
```

####Device Motion
Support for motion updates is contingent on Core Motion support for a given platform (for example, it is not supported on OS X).  The framework should detect it if an attempt is made to start motion updates on an unsupported platform.

Key methods that should be self-explanatory:

``` swift
VgcManager.peripheral.motion.start()
VgcManager.peripheral.motion.stop()

VgcManager.peripheral.motion.enableUserAcceleration = true
VgcManager.peripheral.motion.enableGravity = true
VgcManager.peripheral.motion.enableRotationRate = true
VgcManager.peripheral.motion.enableAttitude = true

VgcManager.peripheral.motion.updateInterval = 1/60

VgcManager.peripheral.motion.enableAdaptiveFilter = true
VgcManager.peripheral.motion.enableLowPassFilter = true
```

It is important for performance reasons to reduce updateInterval as much as you can, and to disable motion inputs that are not used in your game.

## Game Integration (Central)
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

For in-depth instructions on using DemoBots as a test, see the [Wiki article](https://github.com/robreuss/VirtualGameController/wiki/Testing-using-DemoBots), which also provide helpful hints on integrating VirtualGameController with your existing project.

####Central versus Bridge
There are two types of Central app integrations and which result in dramatically different: **Central** and **Bridge**.

A **Central** is exactly what you expect in terms of game integration: your Central is your game and there should only be one implemented at a time.  

A **Bridge** combines the behavior of a Central and a Peripheral; it is a Peripheral in relation to your Central, and it is a Central in relation to your Peripheral(s).  Another name for it would be a *controller forwarder*, because it's primary function is to forward/relay values sent by one or more Peripherals to the Central.  The Peripheral could be a MFi hardware controller, an iCade hardware controller, an *Apple Watch* or a software-based virtual controller (assuming the Bridge is deployed on an iPhone paired to the watch).  If the bridge is implemented on a device with device motion support (an iOS device) the Bridge can extend the capabilities of a Peripheral to include motion support.  For example, a MFi or iCade controller can appear to the Central to implement the motion profile.  

####Extended Functionality
There are a few features supported by a Central that exceed the capabilities of the Apple *GameController* framework:

- [Custom Elements](https://github.com/robreuss/VirtualGameController/wiki/Custom-Elements)
- [Custom Mapping](https://github.com/robreuss/VirtualGameController/wiki/Custom-Mappings)
- [Peripheral Setup from the Central](https://github.com/robreuss/VirtualGameController/wiki/Peripheral-Setup-from-the-Central)



####Other
There is a method provided on instances of VgcController called ````controller.vibrateDevice```` that will vibrate an iPhone, and if a watch app is integrated with that phone, the vibrate request will be forwarded to the watch as well, resulting in haptic feedback (wrist click).

## Integrating the Apple Watch
#### Sample Project
See the iOS Peripheral sample project for additional guidance.
#### Project Setup
In order to integrate watch functionality into your project, it is recommended you start the project using Apple's template for "iOS App with WatchKit App".  That will enable you to create a WatchKit Extension for your app.

Your iOS project must import the iOS version of the framework and the WatchKit Extension must import the watchOS version.

#### Launching your Watch Extension
Your Watch Extension should use the startAs method to launch as a Peripheral, and set an instance variable for the VgcWatchConnectivity class, which the watchOS framework publishes:

````swift
    VgcManager.startAs(.Peripheral, appIdentifier: "", customElements: CustomElements(), customMappings: CustomMappings())
    watchConnectivity = VgcWatchConnectivity()    
````

#### Sending Values from the Watch
Within your watch extension, use the following method on your VgcWatchConnectivity instance variable to send an element value to both your iOS app (living on your phone) and the Central (forwarded from the iOS app automatically):

````swift
let element = watchConnectivity.elements.rightShoulder
element.value = 1.0
watchConnectivity.sendElementState(element)
element.value = 0.0
watchConnectivity.sendElementState(element)

````

#### Recieving Values from the Watch
When your watch sends values as described in the previous section, there are two approaches to handling those messages.  If you do nothing, the values will be automatically forwarded to the Central.  If you want to do handling on the Peripheral, and either forward or not forward, you can set the valuChangedHandler like so:

````swift
VgcManager.peripheral.watch.valueChangedHandler = { (element: Element) in
	print("iOS iPhone watch handler fired for \(element.name) with value \(element.value)")
}
````
If the valueChangedHandler is non-nil, values will no longer be automatically forwarded to the Central, and so if you wish those values to be forwarded, you must do so yourself:

````swift
VgcManager.peripheral.sendElementState(element)
````


####Sending Values to the Watch
To send a value to a watch from your Peripheral iOS app, you can use the following method:

````swift
VgcManager.peripheral.watch.sendElementState(element)

````

####Receiving Values on the Watch
If a watch is paired with your iPhone iOS app, values received by the iOS app from a Central will be forwarded to the watch, and you can react to those values by setting a valueChangedHandler on your watchConnectivity instance:

````swift
watchConnectivity.valueChangedHandler = { (element: Element) in
	print("Watch handler fired for \(element.name) with value \(element.value)")
}
````

Note that the same handler will fire if your Peripheral sends a value to the watch as described above.

#### Starting Motion from the Watch
You can send motion values from the watch, but please note that the performance is not great:

````swift
watchConnectivity.motion.start()
watchConnectivity.motion.stop()
````

##Custom Elements
See the [wiki article](https://github.com/robreuss/VirtualGameController/wiki/Custom-Elements).

##Custom Mappings
See the [wiki article](https://github.com/robreuss/VirtualGameController/wiki/Custom-Mappings).

##Bidirectional Communication
See the [wiki article](https://github.com/robreuss/VirtualGameController/wiki/Bidirectional-Communication).

##Objective C Support
See the Objective C sample project along with the [wiki page](https://github.com/robreuss/VirtualGameController/wiki/Implementing-in-Objective-C).

##iCade Controller Support
See the [wiki article](https://github.com/robreuss/VirtualGameController/wiki/iCade-Controller-Support).
##Contact and Support
Feel free to contact me with any questions either using [LinkedIn](https://www.linkedin.com/pub/rob-reuss/2/7b/488) or <virtualgamecontroller@gmail.com>.  
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



