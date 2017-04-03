import Foundation
import UIKit
import SpriteKit

// states of respective character objects
public enum CharacterState : Int {
    // main player state
    case JUMPING = 0
    case DOUBLE_JUMPING = 1
    case WALKING = 2
    case IDLE = 3
    case DYING = 4
    case FALLING = 5
    case DEAD = 6
    case CLIMBING = 7
    
    // bomb states
    case BLINKING = 8
    case ESCALATING = 9
    case EXPLODING = 10
    
    // turret states
    case WAITING = 11
    case FIRING = 12
}

// class used as a superclass of all animatable objects in the scene
public class Character : GameObject {
    // constants and variables
    public var onGround : Bool = true
    public var desiredPosition : CGPoint = CGPoint.zero
    public weak var textureAtlas : SKTextureAtlas?
    
    internal var state : CharacterState = CharacterState.IDLE
    internal var velocity : CGPoint = CGPoint.zero
    internal var gravityVector : CGPoint = CGPoint(x: 0.0, y: -48000.0)
    
    // default update loop for the object that ensures
    // that the Object stays in the same position
    public func update(_ delta : TimeInterval) {
        self.desiredPosition = self.position
    }

    
    // default configuration of the bounding box to be used
    public func collisionBoundingBox() -> CGRect {
        let diff = self.desiredPosition.subtract(self.position)
        return self.frame.offsetBy(dx: diff.x, dy: diff.y)
    }
}
