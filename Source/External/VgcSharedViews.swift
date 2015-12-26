//
//  VirtualGameControllerSharedViews.swift
//
//
//  Created by Rob Reuss on 9/28/15.
//
//

import Foundation
import UIKit
import VirtualGameController
import AVFoundation

public let animationSpeed = 0.35

var peripheralManager = VgcManager.peripheral

// A simple mock-up of a game controller (Peripheral)
@objc public class PeripheralControlPadView: NSObject {

    var custom = VgcManager.elements.custom
    var elements = VgcManager.elements
    var parentView: UIView!
    var controlOverlay: UIView!
    var controlLabel: UILabel!
    #if !os(tvOS)
    var motionSwitch : UISwitch!
    #endif
    var activityIndicator : UIActivityIndicatorView!
    var leftShoulderButton: VgcButton!
    var rightShoulderButton: VgcButton!
    var leftTriggerButton: VgcButton!
    var rightTriggerButton: VgcButton!
    var centerTriggerButton: VgcButton!
    var playerIndexLabel: UILabel!
    var keyboardTextField: UITextField!
    var keyboardControlView: UIView!
    var keyboardLabel: UILabel!
    public var flashView: UIImageView!
    public var viewController: UIViewController!
    
    public var serviceSelectorView: ServiceSelectorView!
    
    @objc public init(vc: UIViewController) {
    
        super.init()
        
        viewController = vc
        parentView = viewController.view
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidDisconnect:", name: VgcPeripheralDidDisconnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidConnect:", name: VgcPeripheralDidConnectNotification, object: nil)        
        
        // Notification that a player index has been set
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "gotPlayerIndex:", name: VgcNewPlayerIndexNotification, object: nil)
        
        parentView.backgroundColor = UIColor.darkGrayColor()
        
        flashView = UIImageView(frame: CGRect(x: 0, y: 0, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        flashView.backgroundColor = UIColor.redColor()
        flashView.alpha = 0
        flashView.userInteractionEnabled = false
        parentView.addSubview(flashView)
        
        let buttonSpacing: CGFloat = 1.0
        let buttonHeight: CGFloat = (0.15 * parentView.bounds.size.height)
        
        let stickSideSize = parentView.bounds.size.height * 0.25
        var marginSize: CGFloat = parentView.bounds.size.width * 0.03
        
        if VgcManager.peripheral.deviceInfo.profileType != .MicroGamepad {
        
            leftShoulderButton = VgcButton(frame: CGRect(x: 0, y: 0, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.leftShoulder)
            leftShoulderButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleRightMargin]
            parentView.addSubview(leftShoulderButton)
            
            rightShoulderButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.50), y: 0, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.rightShoulder)
            rightShoulderButton.valueLabel.textAlignment = .Left
            rightShoulderButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin]
            parentView.addSubview(rightShoulderButton)
            
            leftTriggerButton = VgcButton(frame: CGRect(x: 0, y: buttonHeight + buttonSpacing, width: (parentView.bounds.width * 0.50) - buttonSpacing, height: buttonHeight), element: elements.leftTrigger)
            leftTriggerButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleRightMargin]
            parentView.addSubview(leftTriggerButton)
            
            rightTriggerButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.50), y:  buttonHeight + buttonSpacing, width: parentView.bounds.width * 0.50, height: buttonHeight), element: elements.rightTrigger)
            rightTriggerButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin]
            rightTriggerButton.valueLabel.textAlignment = .Left
            parentView.addSubview(rightTriggerButton)
            
            /*
            // FOR TESTING CUSTOM ELEMENTS
            centerTriggerButton = VgcButton(frame: CGRect(x: (parentView.bounds.width * 0.25), y:  buttonHeight + buttonSpacing, width: parentView.bounds.width * 0.50, height: buttonHeight), element: custom[CustomElementType.FiddlestickX.rawValue]!)
            centerTriggerButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin]
            centerTriggerButton.valueLabel.textAlignment = .Center
            parentView.addSubview(centerTriggerButton)
            */

            var yPosition = (buttonHeight * 2) + (buttonSpacing * 2)
            
            let padHeightWidth = parentView.bounds.size.width * 0.50
            let abxyButtonPad = VgcAbxyButtonPad(frame: CGRect(x: (parentView.bounds.size.width * 0.50), y: yPosition, width: padHeightWidth, height: padHeightWidth))
            abxyButtonPad.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleRightMargin]
            parentView.addSubview(abxyButtonPad)
            
            
            let dpadPad = VgcStick(frame: CGRect(x: 0, y: yPosition, width: padHeightWidth - buttonSpacing, height: padHeightWidth), xElement: elements.dpadXAxis, yElement: elements.dpadYAxis)
            dpadPad.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin]
            dpadPad.nameLabel.text = "dpad"
            dpadPad.valueLabel.textAlignment = .Right
            dpadPad.layer.cornerRadius = 0
            dpadPad.controlView.layer.cornerRadius = 0
            parentView.addSubview(dpadPad)
            
            yPosition += padHeightWidth + 10
            
            let leftThumbstickPad = VgcStick(frame: CGRect(x: marginSize, y: yPosition, width: stickSideSize , height: stickSideSize), xElement: elements.leftThumbstickXAxis, yElement: elements.leftThumbstickYAxis)
            leftThumbstickPad.nameLabel.text = "L Thumb"
            parentView.addSubview(leftThumbstickPad)
            
            let rightThumbstickPad = VgcStick(frame: CGRect(x: parentView.bounds.size.width - stickSideSize - marginSize, y: yPosition, width: stickSideSize, height: stickSideSize), xElement: elements.rightThumbstickXAxis, yElement: elements.rightThumbstickYAxis)
            rightThumbstickPad.nameLabel.text = "R Thumb"
            parentView.addSubview(rightThumbstickPad)
            
            
            let cameraBackground = UIView(frame: CGRect(x: parentView.bounds.size.width * 0.50 - 25, y: parentView.bounds.size.height - 49, width: 50, height: 40))
            cameraBackground.backgroundColor = UIColor.lightGrayColor()
            cameraBackground.layer.cornerRadius = 5
            parentView.addSubview(cameraBackground)
            
            let cameraImage = UIImageView(image: UIImage(named: "camera"))
            cameraImage.contentMode = .Center
            cameraImage.frame = CGRect(x: parentView.bounds.size.width * 0.50 - 25, y: parentView.bounds.size.height - 49, width: 50, height: 40)
            cameraImage.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
            cameraImage.userInteractionEnabled = true
            parentView.addSubview(cameraImage)
            
            let gr = UITapGestureRecognizer(target: vc, action: "displayPhotoPicker:")
            cameraImage.gestureRecognizers = [gr]

            playerIndexLabel = UILabel(frame: CGRect(x: parentView.bounds.size.width * 0.50 - 50, y: parentView.bounds.size.height - 75, width: 100, height: 25))
            playerIndexLabel.text = "Player: 0"
            playerIndexLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin]
            playerIndexLabel.textColor = UIColor.grayColor()
            playerIndexLabel.textAlignment = .Center
            playerIndexLabel.font = UIFont(name: playerIndexLabel.font.fontName, size: 14)
            parentView.addSubview(playerIndexLabel)

            
            // This is hidden because it is only used to display the keyboard below in playerTappedToShowKeyboard
            keyboardTextField = UITextField(frame: CGRect(x: -10, y: parentView.bounds.size.height + 30, width: 10, height: 10))
            keyboardTextField.addTarget(self, action: "textFieldDidChange:", forControlEvents: .EditingChanged)
            keyboardTextField.autocorrectionType = .No
            parentView.addSubview(keyboardTextField)
            
            
            // Set iCadeControllerMode when testing the use of an iCade controller
            // Instead of displaying the button to the user to display an on-screen keyboard
            // for string input, we make the hidden keyboardTextField the first responder so
            // it receives controller input
            if VgcManager.iCadeControllerMode != .Disabled {
                
                keyboardTextField.becomeFirstResponder()
                
            } else {
                
    //            let keyboardLabel = UIButton(frame: CGRect(x: marginSize, y: parentView.bounds.size.height - 46, width: 100, height: 44))
    //            keyboardLabel.backgroundColor = UIColor(white: CGFloat(0.76), alpha: 1.0)
    //            keyboardLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
    //            keyboardLabel.setTitle("Keyboard", forState: .Normal)
    //            keyboardLabel.setTitleColor(UIColor.blackColor(), forState: .Normal)
    //            keyboardLabel.titleLabel!.font = UIFont(name: keyboardLabel.titleLabel!.font.fontName, size: 18)
    //            keyboardLabel.layer.cornerRadius = 2
    //            keyboardLabel.addTarget(self, action: "playerTappedToShowKeyboard:", forControlEvents: .TouchUpInside)
    //            keyboardLabel.userInteractionEnabled = true
    //            parentView.addSubview(keyboardLabel)
                
                let keyboardBackground = UIView(frame: CGRect(x: marginSize, y: parentView.bounds.size.height - 49, width: 89, height: 42))
                keyboardBackground.backgroundColor = UIColor.lightGrayColor()
                keyboardBackground.layer.cornerRadius = 5
                parentView.addSubview(keyboardBackground)
                
                let keyboardImage = UIImageView(image: UIImage(named: "keyboard"))
                keyboardImage.contentMode = .ScaleAspectFill
                keyboardImage.frame = CGRect(x: marginSize - 6, y: parentView.bounds.size.height - 55, width: 100, height: 42)
                keyboardImage.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
                keyboardImage.userInteractionEnabled = true
                parentView.addSubview(keyboardImage)
                
                let gr = UITapGestureRecognizer(target: self, action: "playerTappedToShowKeyboard:")
                keyboardImage.gestureRecognizers = [gr]
                
            }

            /* Uncomment to sample software-based controller pause behavior, and comment out camera image
               above since the two icons occupy the same space.
            
            let pauseButtonSize = CGFloat(64.0)
            let pauseButtonLabel = UIButton(frame: CGRect(x: (parentView.bounds.size.width * 0.50) - (pauseButtonSize * 0.50), y: parentView.bounds.size.height - (parentView.bounds.size.height * 0.15), width: pauseButtonSize, height: pauseButtonSize))
            pauseButtonLabel.backgroundColor = UIColor(white: CGFloat(0.76), alpha: 1.0)
            pauseButtonLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleTopMargin]
            pauseButtonLabel.setTitle("||", forState: .Normal)
            pauseButtonLabel.setTitleColor(UIColor.blackColor(), forState: .Normal)
            pauseButtonLabel.titleLabel!.font = UIFont(name: pauseButtonLabel.titleLabel!.font.fontName, size: 35)
            pauseButtonLabel.layer.cornerRadius = 10
            pauseButtonLabel.addTarget(self, action: "playerTappedToPause:", forControlEvents: .TouchUpInside)
            pauseButtonLabel.userInteractionEnabled = true
            parentView.addSubview(pauseButtonLabel)
            */
            
            let motionLabel = UILabel(frame: CGRect(x: parentView.bounds.size.width - 63, y: parentView.bounds.size.height - 58, width: 50, height: 25))
            motionLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleTopMargin]
            motionLabel.text = "Motion"
            motionLabel.textAlignment = .Center
            motionLabel.textColor = UIColor.whiteColor()
            //motionLabel.backgroundColor = UIColor.redColor()
            motionLabel.font = UIFont(name: motionLabel.font.fontName, size: 10)
            parentView.addSubview(motionLabel)
            
            #if !(os(tvOS))
                motionSwitch = UISwitch(frame:CGRect(x: parentView.bounds.size.width - 63, y: parentView.bounds.size.height - 37, width: 45, height: 30))
                motionSwitch.on = false
                //motionSwitch.setOn(true, animated: false);
                motionSwitch.addTarget(self, action: "motionSwitchDidChange:", forControlEvents: .ValueChanged);
                motionSwitch.backgroundColor = UIColor.lightGrayColor()
                motionSwitch.layer.cornerRadius = 15
                parentView.addSubview(motionSwitch);
            #endif
            
        } else {
            
            marginSize = 10
            
            parentView.backgroundColor = UIColor.blackColor()
            
            let dpadSize = parentView.bounds.size.height * 0.50
            let lightBlackColor = UIColor.init(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            
            let leftThumbstickPad = VgcStick(frame: CGRect(x: (parentView.bounds.size.width - dpadSize) * 0.50, y: 24, width: dpadSize, height: parentView.bounds.size.height * 0.50), xElement: elements.dpadXAxis, yElement: elements.dpadYAxis)
            leftThumbstickPad.nameLabel.text = "dpad"
            leftThumbstickPad.nameLabel.textColor = UIColor.lightGrayColor()
            leftThumbstickPad.nameLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
            leftThumbstickPad.valueLabel.textColor = UIColor.lightGrayColor()
            leftThumbstickPad.valueLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
            leftThumbstickPad.backgroundColor = lightBlackColor
            leftThumbstickPad.controlView.backgroundColor = lightBlackColor
            parentView.addSubview(leftThumbstickPad)
            
            let buttonHeight = parentView.bounds.size.height * 0.20
            
            let aButton = VgcButton(frame: CGRect(x: 0, y: parentView.bounds.size.height - (buttonHeight * 2) - 20, width: (parentView.bounds.width) - buttonSpacing, height: buttonHeight), element: elements.buttonA)
            aButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleRightMargin]
            aButton.nameLabel.font = UIFont(name: aButton.nameLabel.font.fontName, size: 40)
            aButton.valueLabel.font = UIFont(name: aButton.valueLabel.font.fontName, size: 20)
            aButton.baseGrayShade = 0.08
            aButton.nameLabel.textColor = UIColor.lightGrayColor()
            aButton.valueLabel.textColor = UIColor.lightGrayColor()
            parentView.addSubview(aButton)
            
            let xButton = VgcButton(frame: CGRect(x: 0, y: parentView.bounds.size.height - buttonHeight - 10, width: parentView.bounds.width, height: buttonHeight), element: elements.buttonX)
            xButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin]
            xButton.valueLabel.textAlignment = .Right
            xButton.nameLabel.font = UIFont(name: xButton.nameLabel.font.fontName, size: 40)
            xButton.valueLabel.font = UIFont(name: xButton.valueLabel.font.fontName, size: 20)
            xButton.baseGrayShade = 0.08
            xButton.nameLabel.textColor = UIColor.lightGrayColor()
            xButton.valueLabel.textColor = UIColor.lightGrayColor()
            parentView.addSubview(xButton)

        }
        
        controlOverlay = UIView(frame: CGRect(x: 0, y: 0, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        controlOverlay.backgroundColor = UIColor.blackColor()
        controlOverlay.alpha = 0.9
        parentView.addSubview(controlOverlay)
        
        controlLabel = UILabel(frame: CGRect(x: 0, y: controlOverlay.bounds.size.height * 0.35, width: controlOverlay.bounds.size.width, height: 25))
        controlLabel.autoresizingMask = [UIViewAutoresizing.FlexibleRightMargin , UIViewAutoresizing.FlexibleBottomMargin]
        controlLabel.text = "Seeking Centrals..."
        controlLabel.textAlignment = .Center
        controlLabel.textColor = UIColor.whiteColor()
        controlLabel.font = UIFont(name: controlLabel.font.fontName, size: 20)
        controlOverlay.addSubview(controlLabel)
        
        activityIndicator = UIActivityIndicatorView(frame: CGRectMake(0, controlOverlay.bounds.size.height * 0.40, controlOverlay.bounds.size.width, 50)) as UIActivityIndicatorView
        activityIndicator.autoresizingMask = [UIViewAutoresizing.FlexibleRightMargin , UIViewAutoresizing.FlexibleBottomMargin]
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.White
        controlOverlay.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        serviceSelectorView = ServiceSelectorView(frame: CGRectMake(25, controlOverlay.bounds.size.height * 0.50, controlOverlay.bounds.size.width - 50, controlOverlay.bounds.size.height - 200))
        serviceSelectorView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleRightMargin]
        controlOverlay.addSubview(serviceSelectorView)
        
        
    }
    
    @objc func peripheralDidConnect(notification: NSNotification) {
        vgcLogDebug("Animating control overlay up")
        UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
            self.controlOverlay.frame = CGRect(x: 0, y: -self.parentView.bounds.size.height, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in

        })
        
        
    }
    
    #if !os(tvOS)
    @objc func peripheralDidDisconnect(notification: NSNotification) {
        vgcLogDebug("Animating control overlay down")
        UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
            self.controlOverlay.frame = CGRect(x: 0, y: 0, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in
                self.serviceSelectorView.refresh()
                if self.motionSwitch != nil { self.motionSwitch.on = false }
        })
    }
    #endif
    
    @objc func gotPlayerIndex(notification: NSNotification) {
        
        let playerIndex: Int = notification.object as! Int
        if playerIndexLabel != nil { playerIndexLabel.text = "Player \(playerIndex + 1)" }
    }
    
    @objc func playerTappedToPause(sender: AnyObject) {
        
        // Pause toggles, so we send both states at once
        elements.pauseButton.value = 1.0
        VgcManager.peripheral.sendElementState(elements.pauseButton)
        
    }
    
    @objc func playerTappedToShowKeyboard(sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled { return }
        
        keyboardControlView = UIView(frame: CGRect(x: 0, y: parentView.bounds.size.height, width: parentView.bounds.size.width, height: parentView.bounds.size.height))
        keyboardControlView.backgroundColor = UIColor.darkGrayColor()
        parentView.addSubview(keyboardControlView)
        
        let dismissKeyboardGR = UITapGestureRecognizer(target: self, action:Selector("dismissKeyboard"))
        keyboardControlView.gestureRecognizers = [dismissKeyboardGR]
        
        keyboardLabel = UILabel(frame: CGRect(x: 0, y: 0, width: keyboardControlView.bounds.size.width, height: keyboardControlView.bounds.size.height * 0.60))
        keyboardLabel.text = ""
        keyboardLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin]
        keyboardLabel.textColor = UIColor.whiteColor()
        keyboardLabel.textAlignment = .Center
        keyboardLabel.font = UIFont(name: keyboardLabel.font.fontName, size: 40)
        keyboardLabel.adjustsFontSizeToFitWidth = true
        keyboardLabel.numberOfLines = 5
        keyboardControlView.addSubview(keyboardLabel)
        
        UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
            self.keyboardControlView.frame = self.parentView.bounds
            }, completion: { finished in
        })
        
        keyboardTextField.becomeFirstResponder()
        
    }
    
    func dismissKeyboard() {
        
        keyboardTextField.resignFirstResponder()
        UIView.animateWithDuration(animationSpeed, delay: 0.0, options: .CurveEaseIn, animations: {
            self.keyboardControlView.frame = CGRect(x: 0, y: self.parentView.bounds.size.height, width: self.parentView.bounds.size.width, height: self.parentView.bounds.size.height)
            }, completion: { finished in
        })
    }
    
    func textFieldDidChange(sender: AnyObject) {
        
        if VgcManager.iCadeControllerMode != .Disabled {
            
            vgcLogDebug("Sending iCade character: \(keyboardTextField.text) using iCade mode: \(VgcManager.iCadeControllerMode.description)")

            var element: Element!
            var value: Int
            (element, value) = VgcManager.iCadePeripheral.elementForCharacter(keyboardTextField.text!, controllerElements: elements)
            keyboardTextField.text = ""
            if element == nil { return }
            element.value = value
            VgcManager.peripheral.sendElementState(element)
            
        } else {
            
            keyboardLabel.text = keyboardTextField.text!
            VgcManager.elements.custom[CustomElementType.Keyboard.rawValue]!.value = keyboardTextField.text!
            VgcManager.peripheral.sendElementState(VgcManager.elements.custom[CustomElementType.Keyboard.rawValue]!)
            keyboardTextField.text = ""
            
        }
        
    }
    
    #if !(os(tvOS))
    func motionSwitchDidChange(sender:UISwitch!) {
        
        vgcLogDebug("User modified motion switch: \(sender.on)")
        
        if sender.on == true {

            VgcManager.peripheral.motion.start()
        } else {
            VgcManager.peripheral.motion.stop()
        }
        
    }
    #endif
}

// Provides a view over the Peripheral control pad that allows the end user to
// select which Central/Bridge to connect to.
public class ServiceSelectorView: UIView, UITableViewDataSource, UITableViewDelegate {
    
    var tableView: UITableView!
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        tableView = UITableView(frame: CGRectMake(0, 0, frame.size.width, frame.size.height))
        tableView.layer.cornerRadius = 20.0
        tableView.backgroundColor = UIColor.clearColor()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44.0
        self.addSubview(tableView)
        
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
    }
    
    public func refresh() {
        vgcLogDebug("Refreshing server selector view")
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Automatic)
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.frame = CGRectMake(0, 0, tableView.bounds.size.width, CGFloat(tableView.rowHeight) * CGFloat(VgcManager.peripheral.availableServices.count))
        return VgcManager.peripheral.availableServices.count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.tableView.dequeueReusableCellWithIdentifier("cell")! as UITableViewCell
        let serviceName = VgcManager.peripheral.availableServices[indexPath.row].fullName
         cell.textLabel?.font = UIFont(name: cell.textLabel!.font.fontName, size: 16)
        cell.textLabel?.text = serviceName
        cell.backgroundColor = UIColor.grayColor()
        cell.alpha = 1.0
        cell.textLabel?.textColor = UIColor.whiteColor()

        return cell
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if VgcManager.peripheral.availableServices.count > 0 {
            let service = VgcManager.peripheral.availableServices[indexPath.row]
            VgcManager.peripheral.connectToService(service)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// Basic button element, with support for 3d touch
class VgcButton: UIView {
    
    let element: Element!
    var nameLabel: UILabel!
    var valueLabel: UILabel!
    var _baseGrayShade: Float = 0.76
    var baseGrayShade: Float {
        get {
            return _baseGrayShade
        }
        set {
            _baseGrayShade = newValue
            self.backgroundColor = UIColor(white: CGFloat(_baseGrayShade), alpha: 1.0)
        }
    }
    
    var value: Float {
        get {
            return self.value
        }
        set {
            self.value = newValue
        }
    }
    
    init(frame: CGRect, element: Element) {
        
        self.element = element
        
        super.init(frame: frame)
        
        baseGrayShade = 0.76
        
        nameLabel = UILabel(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        nameLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight]
        nameLabel.text = element.name
        nameLabel.textAlignment = .Center
        nameLabel.font = UIFont(name: nameLabel.font.fontName, size: 20)
        self.addSubview(nameLabel)
        
        valueLabel = UILabel(frame: CGRect(x: 10, y: frame.size.height * 0.70, width: frame.size.width - 20, height: frame.size.height * 0.30))
        valueLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleTopMargin]
        valueLabel.text = "0.0"
        valueLabel.textAlignment = .Center
        valueLabel.font = UIFont(name: valueLabel.font.fontName, size: 10)
        valueLabel.textAlignment = .Right
        self.addSubview(valueLabel)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func percentageForce(touch: UITouch) -> Float {
        let force = Float(touch.force)
        let maxForce = Float(touch.maximumPossibleForce)
        let percentageForce: Float
        if (force == 0) { percentageForce = 0 } else { percentageForce = force / maxForce }
        return percentageForce
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        let touch = touches.first
        
        // If 3d touch is not supported, just send a "1" value
        if (self.traitCollection.forceTouchCapability == .Available) {
            element.value = self.percentageForce(touch!)
            valueLabel.text = "\(element.value)"
            let colorValue = CGFloat(baseGrayShade - (element.value as! Float / 10))
            self.backgroundColor = UIColor(red: colorValue, green: colorValue, blue: colorValue, alpha: 1)
        } else {
            element.value = 1.0
            valueLabel.text = "\(element.value)"
            self.backgroundColor = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        }
        VgcManager.peripheral.sendElementState(element)
        
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
        let touch = touches.first
        
        // If 3d touch is not supported, just send a "1" value
        if (self.traitCollection.forceTouchCapability == .Available) {
            element.value = self.percentageForce(touch!)
            valueLabel.text = "\(element.value)"
            let colorValue = CGFloat(baseGrayShade - (element.value as! Float) / 10)
            self.backgroundColor = UIColor(red: colorValue, green: colorValue, blue: colorValue, alpha: 1)
        } else {
            element.value = 1.0
            valueLabel.text = "\(element.value)"
            self.backgroundColor = UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        }

        VgcManager.peripheral.sendElementState(element)
        
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
            
        element.value = 0.0
        valueLabel.text = "\(element.value)"
        VgcManager.peripheral.sendElementState(element)
        self.backgroundColor = UIColor(white: CGFloat(baseGrayShade), alpha: 1.0)
        
    }
    
}

class VgcStick: UIView {
    
    let xElement: Element!
    let yElement: Element!
    
    var nameLabel: UILabel!
    var valueLabel: UILabel!
    var controlView: UIView!
    var touchesView: UIView!
    
    var value: Float {
        get {
            return self.value
        }
        set {
            self.value = newValue
        }
    }
    
    init(frame: CGRect, xElement: Element, yElement: Element) {
        
        self.xElement = xElement
        self.yElement = yElement
        
        super.init(frame: frame)
        
        nameLabel = UILabel(frame: CGRect(x: 0, y: frame.size.height - 20, width: frame.size.width, height: 15))
        nameLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight]
        nameLabel.textAlignment = .Center
        nameLabel.font = UIFont(name: nameLabel.font.fontName, size: 10)
        self.addSubview(nameLabel)
        
        valueLabel = UILabel(frame: CGRect(x: 10, y: 10, width: frame.size.width - 20, height: 15))
        valueLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleTopMargin]
        valueLabel.text = "0.0/0.0"
        valueLabel.font = UIFont(name: valueLabel.font.fontName, size: 10)
        valueLabel.textAlignment = .Center
        self.addSubview(valueLabel)
        
        let controlViewSide = frame.height * 0.40
        controlView = UIView(frame: CGRect(x: controlViewSide, y: controlViewSide, width: controlViewSide, height: controlViewSide))
        controlView.layer.cornerRadius = controlView.bounds.size.width / 2
        controlView.backgroundColor = UIColor.blackColor()
        self.addSubview(controlView)
        
        self.backgroundColor = peripheralBackgroundColor
        self.layer.cornerRadius = frame.width / 2
        
        self.centerController(0.0)
        
        if VgcManager.peripheral.deviceInfo.profileType == .MicroGamepad {
            touchesView = self
            controlView.userInteractionEnabled = false
            controlView.hidden = true
        } else {
            touchesView = controlView
            controlView.userInteractionEnabled = true
            controlView.hidden = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func percentageForce(touch: UITouch) -> Float {
        let force = Float(touch.force)
        let maxForce = Float(touch.maximumPossibleForce)
        let percentageForce: Float
        if (force == 0) { percentageForce = 0 } else { percentageForce = force / maxForce }
        return percentageForce
    }
    
    // Manage the frequency of updates
    var lastMotionRefresh: NSDate = NSDate()
    
    func processTouch(touch: UITouch!) {
        
        if touch!.view == touchesView {
            
            // Avoid updating too often
            if lastMotionRefresh.timeIntervalSinceNow > -(1 / 60) { return } else { lastMotionRefresh = NSDate() }
            
            // Prevent the stick from leaving the view center area
            var newX = touch!.locationInView(self).x
            var newY = touch!.locationInView(self).y
            let movementMarginSize = self.bounds.size.width * 0.25
            if newX < movementMarginSize { newX = movementMarginSize}
            if newX > self.bounds.size.width - movementMarginSize { newX = self.bounds.size.width - movementMarginSize }
            if newY < movementMarginSize { newY = movementMarginSize }
            if newY > self.bounds.size.height - movementMarginSize { newY = self.bounds.size.height - movementMarginSize }
            controlView.center = CGPoint(x: newX, y: newY)
            
            // Regularize the value between -1 and 1
            let rangeSize = self.bounds.size.height - (movementMarginSize * 2.0)
            let xValue = (((newX / rangeSize) - 0.5) * 2.0) - 1.0
            var yValue = (((newY / rangeSize) - 0.5) * 2.0) - 1.0
            yValue = -(yValue)
            
            xElement.value = Float(xValue)
            yElement.value = Float(yValue)
            VgcManager.peripheral.sendElementState(xElement)
            VgcManager.peripheral.sendElementState(yElement)
            
            valueLabel.text = "\(round(xValue * 100.0) / 100)/\(round(yValue * 100.0) / 100)"
            
        }
        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first
        self.processTouch(touch)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touch = touches.first
        if touch!.view == touchesView {
            self.centerController(0.1)
        }
        xElement.value = Float(0)
        yElement.value = Float(0)
        VgcManager.peripheral.sendElementState(xElement)
        VgcManager.peripheral.sendElementState(yElement)
    }
    
    // Re-center the control element
    func centerController(duration: Double) {
        UIView.animateWithDuration(duration, delay: 0.0, options: .CurveEaseIn, animations: {
            self.controlView.center = CGPoint(x: ((self.bounds.size.height * 0.50)), y: ((self.bounds.size.width * 0.50)))
            }, completion: { finished in
                self.valueLabel.text = "0/0"
        })
    }
}

class VgcAbxyButtonPad: UIView {

    let elements = VgcManager.elements
    var aButton: VgcButton!
    var bButton: VgcButton!
    var xButton: VgcButton!
    var yButton: VgcButton!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        self.backgroundColor = peripheralBackgroundColor
        
        let buttonWidth = frame.size.width * 0.33333
        let buttonHeight = frame.size.height * 0.33333
        let buttonMargin: CGFloat = 10.0
        
        let fontSize: CGFloat = 35.0
        
        yButton = VgcButton(frame: CGRect(x: buttonWidth, y: buttonMargin, width: buttonWidth, height: buttonHeight), element: elements.buttonY)
        yButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleBottomMargin]
        yButton.nameLabel.textAlignment = .Center
        yButton.valueLabel.textAlignment = .Center
        yButton.layer.cornerRadius =  yButton.bounds.size.width / 2
        yButton.nameLabel.textColor = UIColor.blueColor()
        yButton.baseGrayShade = 0.0
        yButton.valueLabel.textColor = UIColor.whiteColor()
        yButton.nameLabel.font = UIFont(name: yButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(yButton)
        
        xButton = VgcButton(frame: CGRect(x: buttonMargin, y: buttonHeight, width: buttonWidth, height: buttonHeight), element: elements.buttonX)
        xButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleBottomMargin]
        xButton.nameLabel.textAlignment = .Center
        xButton.valueLabel.textAlignment = .Center
        xButton.layer.cornerRadius =  xButton.bounds.size.width / 2
        xButton.nameLabel.textColor = UIColor.yellowColor()
        xButton.baseGrayShade = 0.0
        xButton.valueLabel.textColor = UIColor.whiteColor()
        xButton.nameLabel.font = UIFont(name: xButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(xButton)
        
        bButton = VgcButton(frame: CGRect(x: frame.size.width - buttonWidth - buttonMargin, y: buttonHeight, width: buttonWidth, height: buttonHeight), element: elements.buttonB)
        bButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleBottomMargin]
        bButton.nameLabel.textAlignment = .Center
        bButton.valueLabel.textAlignment = .Center
        bButton.layer.cornerRadius =  bButton.bounds.size.width / 2
        bButton.nameLabel.textColor = UIColor.greenColor()
        bButton.baseGrayShade = 0.0
        bButton.valueLabel.textColor = UIColor.whiteColor()
        bButton.nameLabel.font = UIFont(name: bButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(bButton)
        
        aButton = VgcButton(frame: CGRect(x: buttonWidth, y: buttonHeight * 2.0 - buttonMargin, width: buttonWidth, height: buttonHeight), element: elements.buttonA)
        aButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth , UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin]
        aButton.nameLabel.textAlignment = .Center
        aButton.valueLabel.textAlignment = .Center
        aButton.layer.cornerRadius =  aButton.bounds.size.width / 2
        aButton.nameLabel.textColor = UIColor.redColor()
        aButton.baseGrayShade = 0.0
        aButton.valueLabel.textColor = UIColor.whiteColor()
        aButton.nameLabel.font = UIFont(name: aButton.nameLabel.font.fontName, size: fontSize)
        self.addSubview(aButton)
        
        
    }
}

public class ElementDebugView: UIView {
    
    var elementLabelLookup = Dictionary<Int, UILabel>()
    var elementBackgroundLookup = Dictionary<Int, UIView>()
    var controllerVendorName: UILabel!
    var scrollView: UIScrollView!
    var controller: VgcController!
    var titleRegion: UIView!
    var imageView: UIImageView!
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(frame: CGRect, controller: VgcController) {
        
        self.controller = controller
        
        super.init(frame: frame)
        
        let debugViewTapGR = UITapGestureRecognizer(target: self, action: "receivedDebugViewTap")
        
        let debugViewDoubleTapGR = UITapGestureRecognizer(target: self, action: "receivedDebugViewDoubleTap")
        debugViewDoubleTapGR.numberOfTapsRequired = 2
        self.gestureRecognizers = [debugViewTapGR, debugViewDoubleTapGR]
        
        debugViewTapGR.requireGestureRecognizerToFail(debugViewDoubleTapGR)
        
        self.backgroundColor = UIColor.whiteColor()
        
        //self.layer.cornerRadius = 15
        self.layer.shadowOffset = CGSizeMake(5, 5)
        self.layer.shadowColor = UIColor.blackColor().CGColor
        self.layer.shadowRadius = 3.0
        self.layer.shadowOpacity = 0.3
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.mainScreen().scale
        
        titleRegion = UIView(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: 140))
        titleRegion.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        titleRegion.backgroundColor = UIColor.lightGrayColor()
        titleRegion.clipsToBounds = true
        self.addSubview(titleRegion)
        
        imageView = UIImageView(frame: CGRect(x: self.bounds.size.width - 110, y: 150, width: 100, height: 100))
        imageView.contentMode = .ScaleAspectFit
        self.addSubview(imageView)
        
        controllerVendorName = UILabel(frame: CGRect(x: 0, y: 0, width: titleRegion.frame.size.width, height: 50))
        controllerVendorName.backgroundColor = UIColor.lightGrayColor()
        controllerVendorName.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        controllerVendorName.text = controller.deviceInfo.vendorName
        controllerVendorName.textAlignment = .Center
        controllerVendorName.font = UIFont(name: controllerVendorName.font.fontName, size: 20)
        controllerVendorName.clipsToBounds = true
        titleRegion.addSubview(controllerVendorName)
        
        var labelHeight: CGFloat = 20.0
        let deviceDetailsFontSize: CGFloat = 14.0
        let leftMargin: CGFloat = 40.0
        var yPosition = controllerVendorName.bounds.size.height
        
        let controllerTypeLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        controllerTypeLabel.backgroundColor = UIColor.lightGrayColor()
        controllerTypeLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        controllerTypeLabel.text = "Controller Type: " + controller.deviceInfo.controllerType.description
        controllerTypeLabel.textAlignment = .Left
        controllerTypeLabel.font = UIFont(name: controllerTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(controllerTypeLabel)
        
        yPosition += labelHeight
        let profileTypeLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        profileTypeLabel.backgroundColor = UIColor.lightGrayColor()
        profileTypeLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        profileTypeLabel.text = "Profile Type: " + controller.profileType.description
        profileTypeLabel.textAlignment = .Left
        profileTypeLabel.font = UIFont(name: profileTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(profileTypeLabel)
        
        yPosition += labelHeight
        
        let attachedLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        attachedLabel.backgroundColor = UIColor.lightGrayColor()
        attachedLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        attachedLabel.text = "Attached to Device: " + "\(controller.deviceInfo.attachedToDevice)"
        attachedLabel.textAlignment = .Left
        attachedLabel.font = UIFont(name: profileTypeLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(attachedLabel)
        
        yPosition += labelHeight
        
        let supportsMotionLabel = UILabel(frame: CGRect(x: leftMargin, y: yPosition, width: titleRegion.frame.size.width - 50, height: labelHeight))
        supportsMotionLabel.backgroundColor = UIColor.lightGrayColor()
        supportsMotionLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth]
        supportsMotionLabel.text = "Supports Motion: " + "\(controller.deviceInfo.supportsMotion)"
        supportsMotionLabel.textAlignment = .Left
        supportsMotionLabel.font = UIFont(name: supportsMotionLabel.font.fontName, size: deviceDetailsFontSize)
        titleRegion.addSubview(supportsMotionLabel)
        
        // Scrollview allows the element values to scroll vertically, especially important on phones
        scrollView = UIScrollView(frame: CGRect(x: 0, y: titleRegion.bounds.size.height + 10, width: frame.size.width, height: frame.size.height - titleRegion.bounds.size.height - 10))
        scrollView.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        self.addSubview(scrollView)
        
        labelHeight = CGFloat(22.0)
        yPosition = CGFloat(10.0)
        
        if deviceIsTypeOfBridge() && VgcManager.bridgeRelayOnly {
            let elementLabel = UILabel(frame: CGRect(x: 10, y: yPosition, width: frame.size.width - 20, height: labelHeight * 2))
            elementLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleRightMargin]
            elementLabel.text = "In relay-only mode - no data will display here."
            elementLabel.textAlignment = .Center
            elementLabel.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            elementLabel.numberOfLines = 2
            scrollView.addSubview(elementLabel)
            
            return
        }
        
        for element in VgcManager.elements.elementsForController(controller) {
            
            let elementBackground = UIView(frame: CGRect(x: (frame.size.width * 0.50) + 15, y: yPosition, width: 0, height: labelHeight))
            elementBackground.backgroundColor = UIColor.lightGrayColor()
            elementBackground.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleLeftMargin]
            scrollView.addSubview(elementBackground)
            
            let elementLabel = UILabel(frame: CGRect(x: 10, y: yPosition, width: frame.size.width * 0.50, height: labelHeight))
            elementLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleRightMargin]
            elementLabel.text = "\(element.name):"
            elementLabel.textAlignment = .Right
            elementLabel.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            scrollView.addSubview(elementLabel)
            
            let elementValue = UILabel(frame: CGRect(x: (frame.size.width * 0.50) + 15, y: yPosition, width: frame.size.width * 0.50, height: labelHeight))
            elementValue.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleLeftMargin]
            elementValue.text = "0"
            elementValue.font = UIFont(name: controllerVendorName.font.fontName, size: 16)
            scrollView.addSubview(elementValue)
            
            elementBackgroundLookup[element.identifier] = elementBackground
            
            elementLabelLookup[element.identifier] = elementValue
            
            yPosition += labelHeight
            
        }
        
        scrollView.contentSize = CGSize(width: frame.size.width, height: yPosition + 40)
        
    }
    
    // Demonstrate bidirectional communication using a simple tap on the
    // Central debug view to send a message to one or all Peripherals.
    // Use of a custom element is demonstrated; both standard and custom
    // are supported.
    public func receivedDebugViewTap() {

        // Test vibrate using standard system element
        controller.vibrateDevice()
        
        // Test vibrate using custom element
        /*
        let element = controller.elements.custom[CustomElementType.VibrateDevice.rawValue]!
        element.value = 1
        VgcController.sendElementStateToAllPeripherals(element)
        */
    }
    
    public func receivedDebugViewDoubleTap() {
        
        let imageElement = VgcManager.elements.elementFromIdentifier(ElementType.Image.rawValue)
        let imageData = UIImageJPEGRepresentation(UIImage(named: "digit.jpg")!, 1.0)
        imageElement.value = imageData!
        imageElement.clearValueAfterTransfer = true
        controller.sendElementStateToPeripheral(imageElement)
        
        return

        let element = controller.elements.rightTrigger
        element.value = 1.0
        controller.sendElementStateToPeripheral(element)
        
    }
    
    public func receivedDebugViewTripleTap() {
        
        let imageElement = VgcManager.elements.elementFromIdentifier(ElementType.Image.rawValue)
        let imageData = UIImageJPEGRepresentation(UIImage(named: "digit.jpg")!, 1.0)
        imageElement.value = imageData!
        imageElement.clearValueAfterTransfer = true
        controller.sendElementStateToPeripheral(imageElement)
        
        // Test simple float mode
        //let rightShoulder = controller.elements.rightShoulder
        //rightShoulder.value = 1.0
        //controller.sendElementStateToPeripheral(rightShoulder)
        //VgcController.sendElementStateToAllPeripherals(rightShoulder)
        
        // Test string mode
        let keyboard = controller.elements.custom[CustomElementType.Keyboard.rawValue]!
        keyboard.value = "1 2 3 4 5 6 7 8"
        keyboard.value = "Before newline\nAfter newline\n\n\n"
        controller.sendElementStateToPeripheral(keyboard)
        //VgcController.sendElementStateToAllPeripherals(keyboard)
        
    }
    
    // The Central is in charge of managing the toggled state of the
    // pause button on a controller; we're doing that here just using
    // the current background color to track state.
    public func togglePauseState() {
        if (self.backgroundColor == UIColor.whiteColor()) {
            self.backgroundColor = UIColor.lightGrayColor()
        } else {
            self.backgroundColor = UIColor.whiteColor()
        }
    }
    
    // Instead of refreshing individual values by setting up handlers, we use a
    // global handler and refresh all the values.
    public func refresh(controller: VgcController) {
        
        self.controllerVendorName.text = controller.deviceInfo.vendorName
        
        for element in controller.elements.elementsForController(controller) {
            if let label = self.elementLabelLookup[element.identifier] {
                let keypath = element.getterKeypath(controller)
                var value: AnyObject
                if element.type == .Custom {
                    if element.dataType == .Data {
                        value = ""
                    } else {
                        value = (controller.elements.custom[element.identifier]?.value)!
                    }
                    if element.dataType == .String && value as! NSObject == 0 { value = "" }
                } else if keypath != "" {
                    value = controller.valueForKeyPath(keypath)!
                } else {
                    value = ""
                }
                // PlayerIndex uses enumerated values that are offset by 1
                if element == controller.elements.playerIndex {
                    label.text = "\(controller.playerIndex.rawValue + 1)"
                    continue
                }
                label.text = "\(value)"
                let stringValue = "\(value)"
                
                // Pause will be empty
                if stringValue == "" { continue }

                if element.dataType == .Float {
                    
                    let valFloat = Float(stringValue)! as Float
                    
                    if let backgroundView = self.elementBackgroundLookup[element.identifier] {
                        var width = label.bounds.size.width * CGFloat(valFloat)
                        if (width > 0 && width < 0.1) || (width < 0 && width > -0.1) { width = 0 }
                        backgroundView.frame = CGRect(x: (label.bounds.size.width) + 15, y: backgroundView.frame.origin.y, width: width, height: backgroundView.bounds.size.height)
                    }
                    
                } else if element.dataType == .Int {

                    let valInt = Int(stringValue)! as Int

                    if let backgroundView = self.elementBackgroundLookup[element.identifier] {
                        var width = label.bounds.size.width * CGFloat(valInt)
                        if (width > 0 && width < 0.1) || (width < 0 && width > -0.1) { width = 0 }
                        backgroundView.frame = CGRect(x: (label.bounds.size.width) + 15, y: backgroundView.frame.origin.y, width: width, height: backgroundView.bounds.size.height)
                    }
                } else if element.dataType == .String {
                    
                    if stringValue != "" {
                        label.backgroundColor = UIColor.lightGrayColor()
                    } else {
                        label.backgroundColor = UIColor.clearColor()
                    }
                    
                }
            }
        }
    }
}

