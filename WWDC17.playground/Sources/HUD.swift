import Foundation
import SpriteKit

// protocols for information relaying
public protocol HUDTouchTriggered : NSObjectProtocol {
    func HUDTapped()
}

protocol JoystickTriggered : NSObjectProtocol {
    func JoystickTapped()
}

internal class Joystick : SKNode {
    // variable declaration
    private var thumbNode : SKSpriteNode?
    private var dpadNode : SKSpriteNode?
    private var size : CGFloat = 0
    private var isTracking : Bool = false
    public weak var joystickDelegate : JoystickTriggered?
    
    // create the joystick from two additional SKImageNodes
    public override init() {
        super.init()
        self.isUserInteractionEnabled = true
        self.thumbNode = SKSpriteNode(imageNamed: "joystick.png")
        self.dpadNode = SKSpriteNode(imageNamed: "dpad.png")
        self.size = self.dpadNode!.size.width
        self.addChild(self.thumbNode!)
        self.addChild(self.dpadNode!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func getDeltaOffset() -> CGPoint {
        return self.thumbNode!.position
    }
    
    // resets the displacement thumb node
    private func reset() {
        self.isTracking = false
        let easeOutAction = SKAction.move(to: self.dpadNode!.position, duration: 0.2)
        easeOutAction.timingMode = SKActionTimingMode.easeOut
        self.thumbNode!.run(easeOutAction)
    }
    
    // notify via the delegate that joystick had been interacted with
    // initialize the tracking status for computation in touchesMoved()
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.joystickDelegate != nil {
            self.joystickDelegate!.JoystickTapped()
        }
        
        for touch in touches {
            let touchPoint = touch.location(in: self)
            if !isTracking && thumbNode!.frame.contains(touchPoint) {
                isTracking = true
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            if self.thumbNode!.contains(touchPoint) {
                // cap the max possible displacement
                if isTracking &&
                    sqrt(pow(touchPoint.x-self.dpadNode!.position.x, 2) + sqrt(pow(touchPoint.y-self.dpadNode!.position.y, 2))) < self.size * 2 {
                    
                    // if the displacement is within 1 width of the thumb node
                    // use the actual horizontal/vertical displacement to adjust position
                    if sqrt(pow(touchPoint.x-self.dpadNode!.position.x, 2) +
                            pow(touchPoint.y-self.dpadNode!.position.y, 2)) <= self.thumbNode!.size.width {
                        
                        let moveDifference = CGPoint(x: touchPoint.x - self.dpadNode!.position.x, y: touchPoint.y - self.dpadNode!.position.y)
                        self.thumbNode!.position = CGPoint(x: moveDifference.x + self.dpadNode!.position.x,
                                                           y: moveDifference.y + self.dpadNode!.position.y);
                        
                    } else {
                        // use a more relative and skewed form of displacement indicator
                        let vX = touchPoint.x - self.dpadNode!.position.x;
                        let vY = touchPoint.y - self.dpadNode!.position.y;
                        let magV = sqrt(vX*vX + vY*vY);
                        let aX = self.dpadNode!.position.x + vX / magV * self.thumbNode!.size.width;
                        let aY = self.dpadNode!.position.x + vY / magV * self.thumbNode!.size.height;
                        self.thumbNode!.position = CGPoint(x: aX, y: aY)
                    }
                }
            }
        }
    }
    
    // reset the joystick state at end
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

public class HUD : SKNode, JoystickTriggered {
    // necessary variables and intiializations
    private var joystick : Joystick?
    private var jump : SKSpriteNode?
    private var rope : SKSpriteNode?
    private var bomb : SKSpriteNode?
    private var restart : SKSpriteNode?
    private var minimap : SKSpriteNode?
    public var IndicatorSprite : SKSpriteNode = SKSpriteNode(imageNamed: "indicator")
    
    private var isJumpPressed : Bool = false
    private var isRopePressed : Bool = false
    private var isBombPressed : Bool = false
    private var isMinimapPressed : Bool = false
    
    private var isBlinking : Bool = false
    private var isRestartPressed : Bool = false
    
    private var isEnabled : Bool = true
    public weak var HUDDelegate : HUDTouchTriggered?
    
    // initialize the HUD with specific offsets in between interactable 'buttons'
    // 32 is the magic number as (1/2) the size of the User Interface buttons
    public init(size : CGSize) {
        super.init()
        let offset : CGFloat = 60
        self.isUserInteractionEnabled = true
        
        self.joystick = Joystick()
        self.joystick!.position = CGPoint(x: 96 + offset, y: 96 + offset)
        self.joystick!.joystickDelegate = self
        self.addChild(self.joystick!)
        
        let delta = 32 + offset
        self.jump = SKSpriteNode(imageNamed: "jump.png")
        self.jump!.position = CGPoint(x: size.width - (2 * delta + 32), y: delta)
        self.jump!.color = UIColor.gray
        self.addChild(self.jump!)
        
        self.rope = SKSpriteNode(imageNamed: "rope.png")
        self.rope!.position = CGPoint(x: size.width - (delta), y: delta)
        self.rope!.color = UIColor.gray
        self.addChild(self.rope!)
        
        self.bomb = SKSpriteNode(imageNamed: "bomb.png")
        self.bomb!.position = CGPoint(x: size.width - (delta), y: 2 * delta + 32)
        self.bomb!.color = UIColor.gray
        self.addChild(self.bomb!)
        
        self.IndicatorSprite.position = CGPoint(x: size.width/2, y: delta)
        self.addChild(self.IndicatorSprite)
        
        self.restart = SKSpriteNode(imageNamed: "restart.png")
        self.restart!.position = CGPoint(x: size.width - (delta), y: size.height - delta)
        self.restart!.color = UIColor.gray
        self.addChild(self.restart!)
        
        self.minimap = SKSpriteNode(imageNamed: "minimap.png")
        self.minimap!.position = CGPoint(x: delta, y: size.height - delta)
        self.minimap!.color = UIColor.gray
        self.addChild(self.minimap!)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // disable the HUD
    public func disable() {
        self.isEnabled = false
        self.joystick?.isUserInteractionEnabled = false
        
        self.isBombPressed = false
        self.isJumpPressed = false
        self.isRopePressed = false
        self.isMinimapPressed = false
        
        self.bomb?.colorBlendFactor = 0.0
        self.jump?.colorBlendFactor = 0.0
        self.rope?.colorBlendFactor = 0.0
        self.minimap?.colorBlendFactor = 0.0
    }
    
    // reenable the HUD
    public func enable() {
        self.isEnabled = true
        self.joystick?.isUserInteractionEnabled = true
    }
    
    //MARK: Get state information
    public func getThumbDelta() -> CGPoint {
        return self.joystick!.getDeltaOffset()
    }
    
    public func getJumpState() -> Bool {
        return self.isJumpPressed
    }
    
    public func getRopeState() -> Bool {
        return self.isRopePressed
    }
    
    public func getBombState() -> Bool {
        return self.isBombPressed
    }
    
    public func getRestartState() -> Bool {
        return self.isRestartPressed
    }
    
    public func getMinimapState() -> Bool {
        return self.isMinimapPressed
    }
    
    //MARK: Touches
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // notify via delegate that the HUD has been tapped
        if self.HUDDelegate != nil {
            self.HUDDelegate!.HUDTapped()
        }
        
        // change the button's color depending on touch
        for touch in touches {
            let touchPoint = touch.location(in: self)
            if self.isEnabled {
                if self.jump!.frame.contains(touchPoint) {
                    self.isJumpPressed = true
                    self.jump!.colorBlendFactor = 0.5
                } else if self.rope!.frame.contains(touchPoint) {
                    self.isRopePressed = true
                    self.rope!.colorBlendFactor = 0.5
                } else if self.bomb!.frame.contains(touchPoint) {
                    self.isBombPressed = true
                    self.bomb!.colorBlendFactor = 0.5
                } else if self.minimap!.frame.contains(touchPoint) {
                    self.isMinimapPressed = true
                    self.minimap!.colorBlendFactor = 0.5
                }
            }
            
            if self.restart!.frame.contains(touchPoint) {
                self.isRestartPressed = true
                self.restart!.removeAllActions()
                self.restart!.colorBlendFactor = 0.5
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            let prevTouchPoint = touch.previousLocation(in: self)
            
            // reset the button's color if the finger slides off the button
            if self.jump!.contains(prevTouchPoint) && !self.jump!.contains(touchPoint) {
                self.isJumpPressed = false
                self.jump!.colorBlendFactor = 0.0
            } else if self.rope!.contains(prevTouchPoint) && !self.rope!.contains(touchPoint) {
                self.isRopePressed = false
                self.rope!.colorBlendFactor = 0.0
            } else if self.bomb!.contains(prevTouchPoint) && !self.bomb!.contains(touchPoint) {
                self.isBombPressed = false
                self.bomb!.colorBlendFactor = 0.0
            } else if self.minimap!.contains(prevTouchPoint) && !self.minimap!.contains(touchPoint) {
                self.isMinimapPressed = false
                self.minimap!.colorBlendFactor = 0.0
            }
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let touchPoint = touch.location(in: self)
            // resets the color of the button as necessary
            if self.jump!.frame.contains(touchPoint) {
                self.isJumpPressed = false
                self.jump!.colorBlendFactor = 0.0
            } else if self.rope!.frame.contains(touchPoint) {
                self.isRopePressed = false
                self.rope!.colorBlendFactor = 0.0
            } else if self.bomb!.frame.contains(touchPoint) {
                self.isBombPressed = false
                self.bomb!.colorBlendFactor = 0.0
            } else if self.minimap!.frame.contains(touchPoint) {
                self.isMinimapPressed = false
                self.minimap?.colorBlendFactor = 0.0
            }
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    // creates blinking of the restart button
    public func blinkRestart() {
        if self.isBlinking != true {
            let blink = SKAction.sequence([SKAction.fadeAlpha(to: 0.3, duration: 0.3),
                                           SKAction.fadeIn(withDuration: 0.3)])
            self.restart!.run(SKAction.repeatForever(blink))
            self.isBlinking = true
        }
    }
    
    // passes along the Joystick interaction to the GameScene()
    public func JoystickTapped() {
        if self.HUDDelegate != nil {
            self.HUDDelegate!.HUDTapped()
        }
    }
}
