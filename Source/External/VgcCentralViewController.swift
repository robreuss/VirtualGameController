//
//  VgcCentralViewController.swift
//
//
//  Created by Rob Reuss on 11/1/15.
//
//

import Foundation
import UIKit
import GameController
import AVFoundation
import VirtualGameController

class VgcCentralViewController: UIViewController {
    
    var elementDebugViewLookup = Dictionary<VgcController, UIView>()
    var scrollview: UIScrollView!
    var debugViewWidth: CGFloat!
    var iCadeTextField: UITextField!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.darkGrayColor()
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 20, width: self.view.bounds.size.width, height: 60))
        titleLabel.text = "\(VgcManager.centralServiceName) (\(VgcManager.appRole.description))"
        titleLabel.textAlignment = .Center
        titleLabel.font = UIFont(name: titleLabel.font.fontName, size: 20)
        titleLabel.textColor = UIColor.lightGrayColor()
        titleLabel.adjustsFontSizeToFitWidth = true
        self.view.addSubview(titleLabel)
        
        // Horizontal scrollview that contains the debug views
        scrollview = UIScrollView(frame: CGRect(x: 0, y: 70, width: self.view.bounds.width, height: self.view.bounds.size.height - 70))
        scrollview.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleBottomMargin]
        scrollview.contentSize = CGSize(width: scrollview.bounds.size.width, height: scrollview.bounds.size.height)
        scrollview.backgroundColor = UIColor.grayColor()
        self.view.addSubview(scrollview)
        
        // Make debug view width suitable for a given device type
        if (UIDevice.currentDevice().userInterfaceIdiom == .Phone) {
            self.debugViewWidth = scrollview.bounds.size.width * 0.80
        } else if (UIDevice.currentDevice().userInterfaceIdiom == .Pad) {
            self.debugViewWidth = scrollview.bounds.size.width * 0.40
        } else {
            self.debugViewWidth = scrollview.bounds.size.width * 0.15
        }
        
        #if !os(tvOS)
            // Hidden text field to receive iCade controller input
            iCadeTextField = UITextField(frame: CGRect(x:-1, y: -1, width: 1, height: 1))
            iCadeTextField.addTarget(self, action: "receivedIcadeInput:", forControlEvents: .EditingChanged)
            //iCadeTextField.autocorrectionType = .No
            self.view.addSubview(iCadeTextField)
        #endif
        
        // I have never been able to get this method to discover a controller
        VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in
            
            print("SAMPLE: Discovery completion handler executed")
            
        }
        
        // These function just like their GCController counter-parts, resulting from new connections by
        // both software and hardware controllers
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidConnect:", name: VgcControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidDisconnect:", name: VgcControllerDidDisconnectNotification, object: nil)
        
        // Used to determine if an external keyboard (an iCade controller) is paired
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)

        // This is a little convienance thing for the purpose of keeping the debug views refreshed when a change is
        // made to the playerIndex
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "gotPlayerIndex:", name: "NewPlayerIndexNotification", object: nil)

        #if !os(tvOS)
            // To enable iCade, this must be after the notification observers are defined. The connect notification should be used
            // to setup the controller for use.
            VgcManager.iCadeControllerMode = .iCadeMobile
            if VgcManager.iCadeControllerMode != .Disabled { iCadeTextField.becomeFirstResponder() }
        #endif
    }
    
    // Determine if an iCade controller is paired
    func isExternalKeyboard(keyboardFrame: CGRect) -> Bool {
        
        let keyboard = self.view.convertRect(keyboardFrame, fromView: self.view.window)
        let height = self.view.frame.size.height
        return keyboard.origin.y + keyboard.size.height > height
        
    }
    
    // Determine if an iCade controller is paired
    @objc func keyboardWillHide(aNotification: NSNotification) {
        
        if isExternalKeyboard(aNotification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue) {
            
            // Confirm we are in iCade controller mode
            if VgcManager.iCadeControllerMode != .Disabled {
                
                // Add an iCade controller to our set of controllers
                #if !os(watchOS)
                    VgcController.enableIcadeController()
                #endif
                
            }
        }
    }
 
    // Determine if an iCade controller is paired
    @objc func keyboardWillShow(aNotification: NSNotification) {
        
        print("Testing for external keyboard (iCade controller)")
        // Test for external keyboard
        if isExternalKeyboard(aNotification.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue) {
            
            print("External keyboard found, displaying iCade controller")
            
            // Confirm we are in iCade controller mode
            if VgcManager.iCadeControllerMode != .Disabled {
                
                // Add an iCade controller to our set of controllers
                #if !os(watchOS)
                    VgcController.enableIcadeController()
                #endif
                
            }
            
        } else {
            
            print("No external keyboard (iCade controller), resigning to hide virtual keyboard")
            iCadeTextField.resignFirstResponder()
            
        }
    }
    
    // Characters are received into the hidden iCadeTextField, which calls this function
    func receivedIcadeInput(sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled && VgcController.iCadeController != nil {
            
            print("Sending iCade character: \(iCadeTextField.text) using iCade mode: \(VgcManager.iCadeControllerMode.description)")
            var element: Element!
            var value: Int
            (element, value) = VgcManager.iCadePeripheral.elementForCharacter(iCadeTextField.text!, controllerElements: VgcController.iCadeController.elements)
            iCadeTextField.text = ""
            if element == nil { return }
            element.value = value
            VgcController.iCadeController.triggerElementHandlers(element, value: Float(value))
            
        }
    }
    
    // This will result in a given debug view having all of it's values updated.
    func refreshDebugViewForController(controller: VgcController) {
        
        dispatch_async(dispatch_get_main_queue()) {
            if let elementDebugView: ElementDebugView = self.elementDebugViewLookup[controller] as? ElementDebugView {
                elementDebugView.refresh(controller)
            }
        }
        
    }
    
    // Call refresh on all of the debug views
    func refreshAllDebugViews() {
        
        print("Refreshing all debug views")
        for controller in VgcController.controllers() {
            refreshDebugViewForController(controller)
        }
        
    }
    
    @objc func gotPlayerIndex(notification: NSNotification) {
        
        refreshAllDebugViews()
        
    }
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
        // If we're enhancing a hardware controller, we should display the Peripheral UI
        // instead of the debug view UI
        if VgcManager.appRole == .EnhancementBridge { return }
        
        guard let controller: VgcController = notification.object as? VgcController else {
            print("Got nil controller in controllerDidConnect")
            return
        }
        
        let elementDebugView = ElementDebugView(frame: CGRect(x: -(self.debugViewWidth), y: 0, width: self.debugViewWidth, height: scrollview.bounds.size.height - 50), controller: controller)
        elementDebugView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin]
        scrollview.addSubview(elementDebugView)
        
        elementDebugViewLookup[controller] = elementDebugView
        
        self.refreshElementDebugViewPositions()
        
        // Update the debug view after giving the player index time to arrive
        let triggerTime = (Int64(NSEC_PER_SEC) * 6)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, triggerTime), dispatch_get_main_queue(), { () -> Void in
            elementDebugView.refresh(controller)
        })
        
        // Refresh on all extended gamepad changes (Global handler)
        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            self.refreshDebugViewForController(controller)
            
        }
        
        // Refresh on all gamepad changes (Global handler)
        controller.gamepad?.valueChangedHandler = { (gamepad: GCGamepad, element: GCControllerElement) in
            
            self.refreshDebugViewForController(controller)
            
        }
        
        #if os(tvOS)
            // Refresh on all micro gamepad changes (Global handler)
            controller.microGamepad?.valueChangedHandler = { (gamepad: GCMicroGamepad, element: GCControllerElement) in
                
                self.refreshDebugViewForController(controller)
                
            }
        #endif
        
        // Avoiding updating the UI too frequently for motion changes
        var lastMotionRefresh: NSDate = NSDate()
        
        // Refresh on all motion changes
        controller.motion?.valueChangedHandler = { (input: GCMotion) in
            
            // Avoid updating too often or the UI will freeze up
            if lastMotionRefresh.timeIntervalSinceNow > -0.05 { return } else { lastMotionRefresh = NSDate() }            
            self.refreshDebugViewForController(controller)
            
        }
        
        // Toggle pause button display value.  Note that the toggle state of the pause button is the
        // responsibility of the app (the game) to manage
        controller.controllerPausedHandler = { (controller: VgcController) in
            
            print("Pause handler fired")
            if let elementDebugView: ElementDebugView = self.elementDebugViewLookup[controller] as? ElementDebugView {
                elementDebugView.togglePauseState()
            }
            
        }
        
        // Responds if any custom elements change
        Elements.customElements.valueChangedHandler = { (controller, element) in
            
            self.refreshDebugViewForController(controller)
            
        }
        
        // Test of custom element "keyboard" handler
        controller.elements.custom[CustomElementType.Keyboard.rawValue]!.valueChangedHandler = { (input, value) in
            
            let stringValue = String(controller.elements.custom[CustomElementType.Keyboard.rawValue]!.value)
            if stringValue.characters.count > 1 {
                let synthesizer = AVSpeechSynthesizer()
                let utterance = AVSpeechUtterance(string: (stringValue))
                utterance.rate = AVSpeechUtteranceMaximumSpeechRate / 3.0
                utterance.postUtteranceDelay = 0.0
                utterance.preUtteranceDelay = 0.0
                synthesizer.speakUtterance(utterance)
            }
            
        }
        
        // Another custom element test
        controller.elements.custom[CustomElementType.FiddlestickX.rawValue]!.valueChangedHandler = { (controller, element) in
            
            self.refreshDebugViewForController(controller)
            
        }
        
        
    }
    
    @objc func controllerDidDisconnect(notification: NSNotification) {
        
        guard let controller: VgcController = notification.object as? VgcController else { return }
        
        // Remove element debug view
        let elementDebugView = elementDebugViewLookup.removeValueForKey(controller)
        
        if elementDebugView != nil {
            
            // Send to back so it animates off-screen behind other debug views
            self.scrollview.sendSubviewToBack(elementDebugView!)
            
            UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
                elementDebugView!.frame = CGRect(x: -(self.debugViewWidth), y: 5, width: self.debugViewWidth, height: self.scrollview.bounds.size.height - 5)
                }, completion: { finished in
                    elementDebugView?.removeFromSuperview()
            })
        }
        self.refreshElementDebugViewPositions()
        
    }
    
    func refreshElementDebugViewPositions() {
        
        let controllerCount = CGFloat(VgcController.controllers().count)
        
        print("Refreshing debug view positions with controller count of \(controllerCount), debug view count \(elementDebugViewLookup.count)")
        
        let elementViewSpacing = CGFloat(20.0)
        var xPosition = CGFloat(5)
        var playerIndex = 0
        
        for controller in VgcController.controllers() {
            
            if let elementDebugView = elementDebugViewLookup[controller] {
                
                controller.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
                playerIndex++
                
                UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
                    
                    elementDebugView.frame = CGRect(x: xPosition, y: 5, width: self.debugViewWidth, height: self.scrollview.bounds.size.height - 20)
                    
                    }, completion: { finished in

                })
                xPosition += self.debugViewWidth + elementViewSpacing
                
            } else {
                print("ERROR: Controller \(controller.vendorName) has no DEBUG view")
            }
            
        }
        
        scrollview.contentSize = CGSize(width: (self.debugViewWidth + elementViewSpacing) * controllerCount, height: scrollview.bounds.size.height - 120)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
}
