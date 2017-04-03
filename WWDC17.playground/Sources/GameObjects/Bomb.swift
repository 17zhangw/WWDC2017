import Foundation
import SpriteKit

public class Bomb : Character {
    // constants
    private static var BOMB_WIDTH : CGFloat = 32
    private static var BOMB_HEIGHT : CGFloat = 32
    private var explosionTime : Double = 3.0
    private var escalatingTime : Double = 1.0
    
    // control's the state of the 'Bomb'
    private func updateState(_ state : CharacterState) {
        if state == self.state {
            return
        }
        
        self.state = state
        removeAllActions()
        
        var action : SKAction?
        switch state {
        // adjust the rate the Bomb's tile flashes red
        case CharacterState.BLINKING:
            let actions = [SKAction.colorize(withColorBlendFactor: 0.5, duration: 0.1),
                           SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)]
            action = SKAction.repeatForever(SKAction.sequence(actions))
        case CharacterState.ESCALATING:
            let actions = [SKAction.colorize(withColorBlendFactor: 0.8, duration: 0.05),
                           SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.05)]
            action = SKAction.repeatForever(SKAction.sequence(actions))
        case CharacterState.EXPLODING: // explosion status is handled in GameScene()'s update loop
            break
        default:
            break
        }
        
        if action != nil {
            run(action!)
        }
    }
    
    override public func update(_ delta: TimeInterval) {
        self.desiredPosition = self.position
        if self.state == CharacterState.EXPLODING {
            return
        }
        
        var newState = self.state
        
        // adjust the state depending on the explosion time
        self.explosionTime -= delta
        if self.explosionTime > escalatingTime {
            newState = CharacterState.BLINKING
        } else if self.explosionTime < escalatingTime && self.explosionTime > 0 {
            newState = CharacterState.ESCALATING
        } else {
            newState = CharacterState.EXPLODING
        }
        
        updateState(newState)
        
        // allow the bomb to be influenced by gravity
        let gravityStep = self.gravityVector.multiplyScalar(delta)
        self.velocity = self.velocity.add(gravityStep)
        self.velocity = self.velocity.multiplyScalar(0.3)
        self.velocity = self.velocity.clamp(-3764, 3764)
        let velocityStep = self.velocity.multiplyScalar(delta)
        self.desiredPosition = self.position.add(velocityStep)
    }
    
    // the bounding box to be used for collisions
    override public func collisionBoundingBox() -> CGRect {
        let originalBounding = CGRect(x: self.desiredPosition.x - Bomb.BOMB_WIDTH/2,
                                      y: self.desiredPosition.y - Bomb.BOMB_HEIGHT/2,
                                      width: Bomb.BOMB_WIDTH,
                                      height: Bomb.BOMB_HEIGHT)
        return originalBounding
    }
}
