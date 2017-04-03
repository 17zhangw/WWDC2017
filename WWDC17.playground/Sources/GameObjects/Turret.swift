import Foundation
import SpriteKit

// notifies listener that turret has fired
public protocol TurretProtocol : NSObjectProtocol {
    func TurretFired(_ turret : Turret)
}

enum TurretType {
    case CAMPER
    case TURRET
}

public class Turret : Character {
    // constants and variables
    private static var TURRET_WIDTH : CGFloat = 64
    private static var TURRET_HEIGHT : CGFloat = 64
    private var type : TurretType = TurretType.CAMPER
    
    public weak var PlayerNode : Player?
    public weak var TurretDelegate : TurretProtocol?
    
    private static var COOLDOWN_TIME = 3.0
    private var IsFiring = false
    private var Cooldown = Turret.COOLDOWN_TIME
    
    // configures the turret type
    // 50% of the turret being a camper
    public func setupTurretType() {
        let r = arc4random_uniform(2)
        if r == 0 {
            self.type = TurretType.TURRET
        }
    }
    
    // updates the state as needed
    public func updateState(_ state : CharacterState) {
        if state == self.state {
            return
        }
        
        self.state = state
        removeAllActions()
        
        var action : SKAction?
        switch state {
        case CharacterState.WAITING: // leave default configuration and preserve orientation
            let precedingScale = self.xScale
            self.texture = self.textureAtlas!.textureNamed("Turret")
            self.size = self.texture!.size()
            self.xScale = precedingScale
        case CharacterState.FIRING:
            // shows the loading animation -> fires -> reverses loading -> sets firing to done
            action = SKAction.sequence([self.animations["Fire"]!, SKAction.run { self.TurretDelegate!.TurretFired(self) },
                                        self.animations["Fire"]!.reversed(), SKAction.run { self.IsFiring = false }])
        default:
            break
        }
        
        if action != nil {
            run(action!)
        }
    }
    
    // update loop to be called by GameScene()
    override public func update(_ delta: TimeInterval) {
        // ensure that turret's position does not change
        self.desiredPosition = self.position
        
        // disable the turret if the distance is too far
        if self.IsFiring || self.position.distanceTo(self.PlayerNode!.position) > 1000 {
            return
        }
        
        var newState = self.state
        let tolerance : CGFloat = 64 * 8 // 8 tiles
        var shouldAttemptFiring = false
        
        if self.type == TurretType.CAMPER {
            // if turret is a camper, FIRE if the player is in 'front' of the turret
            // and also if the x difference is within tolerance
            if  self.xScale == 1 && // turret facing to the right
                self.position.x < self.PlayerNode!.position.x &&
                self.position.x - self.PlayerNode!.position.x < tolerance {
                shouldAttemptFiring = true
            } else if   self.xScale == -1 && // turret facing to the left
                        self.position.x > self.PlayerNode!.position.x &&
                        self.PlayerNode!.position.x - self.position.x < tolerance {
                shouldAttemptFiring = true
            }
        } else if self.type == TurretType.TURRET {
            // if turret is a regular firer, ensure that the turret has
            // completely cooldowned before firing again
            self.Cooldown -= delta
            if self.Cooldown < 0 {
                shouldAttemptFiring = true
            }
        }
        
        if shouldAttemptFiring {
            // 50% chance of firing
            let r = arc4random_uniform(2)
            if r == 0 {
                self.IsFiring = true
                newState = CharacterState.FIRING
                self.Cooldown = Turret.COOLDOWN_TIME
            } else {
                newState = CharacterState.WAITING
            }
        } else {
            newState = CharacterState.WAITING
        }
        
        updateState(newState)
    }
    
    // the bounding box to be used for collisions
    override public func collisionBoundingBox() -> CGRect {
        let originalBounding = CGRect(x: self.desiredPosition.x - Turret.TURRET_WIDTH/2,
                                      y: self.desiredPosition.y - Turret.TURRET_HEIGHT/2,
                                      width: Turret.TURRET_WIDTH,
                                      height: Turret.TURRET_HEIGHT)
        return originalBounding
    }
}
