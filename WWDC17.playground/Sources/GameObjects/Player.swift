import Foundation
import UIKit
import SpriteKit

public enum DeathCause {
    case FALLING
    case SPIKE
    case SHOT_FROM_LEFT
    case SHOT_FROM_RIGHT
    case EXPLOSION
}

public class Player : Character {
    // Player texture's base bounding box
    private static let PLAYER_WIDTH : CGFloat = 44
    private static let PLAYER_HEIGHT : CGFloat = 64
    
    // speed up (y-gravity*delta)*delta pixels/frame
    // assming update() is called with 60 fps
    // test machine: delta ~ 0.005
    private static let FIRST_JUMP_FRAMES = 38 // these are maximum bounds
    private static let SECOND_JUMP_FRAMES = 35 // these are maximum bounds - should be able to clear 2 tiles
    private static let JUMP_FORCE : CGFloat = 2300.0 // feels about right...
    private static let SECOND_JUMP_MULTIPLIER : CGFloat = 0.75 // multiplier of JUMP_FORCE for jump #2
    private var acceleratingFrames : Int = Player.FIRST_JUMP_FRAMES // capping # of accelerating frames
    
    private static let PLAYER_ACCELERATION : CGFloat = 800 // acceleration when player moving horizontally
    private static let PLAYER_CLIMBING_ACCEL : CGFloat = 400 // acceleration when climbing
    private static let PLAYER_MAX_SPEED : CGFloat = 3764 // about 1 tile at 60fps...
    private static let PLAYER_DAMPING : Double = 0.3 // damping to be applied to the speed (a.k.a friction)
    
    // control for jumps
    private var numJumpsLeft : Int = 2
    private var jumpInProgress : Bool = false
    
    // weak access to HUD and the InteractableTileMap for rope display
    public weak var HUDNode : HUD?
    public weak var InteractableTileMap : TileMap?
    
    // fall damage tracking AND death cause
    private var trackingFallDamage : Bool = false
    private var greatestPosition : CGFloat = 0.0
    public var deathCause : DeathCause = DeathCause.FALLING
    
    // player state control update cycles
    public func updateState(_ state : CharacterState) {
        if state == self.state {
            return
        }
        
        self.state = state
        removeAllActions()
        
        var action : SKAction?
        switch state {
        case CharacterState.IDLE:
            MusicPlayer.sharedInstance().stopEffectAudio() // disable all audio effects
            fallthrough
        case CharacterState.CLIMBING:
            action = SKAction.repeatForever(self.animations["Idle"]!)
        case CharacterState.WALKING:
            if !MusicPlayer.sharedInstance().getCurrentEffectResource().contains("Shuffle") {
                // play Shuffle effect infinitely
                MusicPlayer.sharedInstance().playEffectAudio("Shuffle", true)
            }
            
            action = SKAction.repeatForever(self.animations["Walk"]!)
        case CharacterState.JUMPING: fallthrough
        case CharacterState.DOUBLE_JUMPING:
            if !MusicPlayer.sharedInstance().getCurrentEffectResource().contains("Jump") {
                // play jump sound for a single time
                MusicPlayer.sharedInstance().playEffectAudio("Jump", false)
            }
            
            action = self.animations["Jump"]
        case CharacterState.FALLING: // fix the falling image
            MusicPlayer.sharedInstance().stopEffectAudio()
            self.texture = self.textureAtlas!.textureNamed("Armature-Jump_6")
            self.size = self.texture!.size()
        case CharacterState.DEAD:
            // show dying animation
            action = self.animations["Dead"]
        default:
            break
        }
        
        if action != nil {
            run(action!)
        }
    }
    
    // update cycles to be called from GameScene()
    override public func update(_ delta: TimeInterval) {
        var newState = self.state
        
        // get joystick displacement
        let DEADZONE_CONSTANT : CGFloat = 15
        var joyForce = CGPoint.zero
        let thumbDelta = self.HUDNode!.getThumbDelta()
        
        // adjust facing direction if displacement is large enough
        if thumbDelta.x < -DEADZONE_CONSTANT {
            self.xScale = -1
        } else if thumbDelta.x > DEADZONE_CONSTANT {
            self.xScale = 1
        }
        
        // check if the player is currently interacting with a CLIMBING object
        let tileSize = self.InteractableTileMap!.getTileMap().tileSize
        let xCoord = Int(self.position.x / tileSize.width)
        let yCoord = Int(self.position.y / tileSize.height)
        let centerOffset = 16
        let tileDefinitionPos = self.InteractableTileMap!.getTileMap().tileDefinition(atColumn: xCoord, row: yCoord)
        var isOnRope : Bool = false
        if tileDefinitionPos != nil {
            // check to make sure that the USER actually wants to move vertically on the 'LADDER'
            // do this by ensuring that the displacement vertically is greater than horizontally
            if  (tileDefinitionPos!.name != "RopeBase" && (newState == CharacterState.FALLING ||
                                                           newState == CharacterState.JUMPING ||
                                                           newState == CharacterState.DOUBLE_JUMPING)
                                                       && abs(thumbDelta.y) > abs(thumbDelta.x)) || // mid air catch of the rope
                // climbing
                (tileDefinitionPos!.name != "RopeBase" && newState == CharacterState.CLIMBING) ||
                
                // USER at the bottom and near the center of the tile to allow the PLAYER
                // to start climbing
                (tileDefinitionPos!.name == "RopeBase" && abs(thumbDelta.y) > abs(thumbDelta.x) &&
                 abs(self.position.x - CGFloat(xCoord) * tileSize.width - tileSize.width / 2) < CGFloat(centerOffset))
            {
                // move exclusively upwards using a relative indicator of the displacement
                if abs(thumbDelta.y) > DEADZONE_CONSTANT {
                    joyForce = CGPoint(x: 0, y: Player.PLAYER_CLIMBING_ACCEL * thumbDelta.y / 70)
                    self.velocity = self.velocity.add(joyForce)
                }
                
                // set the accurate state information
                isOnRope = true
                newState = CharacterState.CLIMBING
                self.greatestPosition = 0.0
                self.trackingFallDamage = false
            }
            
            // allow the user to take the Player away from the 'Base' of the rope
            if tileDefinitionPos!.name == "RopeBase" && abs(thumbDelta.x) > abs(thumbDelta.y) {
                newState = CharacterState.IDLE
            }
        }
        
        if newState != CharacterState.CLIMBING {
            // calculate relative horizontal motion depending on whether Player is climbing
            if abs(thumbDelta.x) > DEADZONE_CONSTANT {
                joyForce = CGPoint(x: Player.PLAYER_ACCELERATION * thumbDelta.x / 70, y: 0)
                self.velocity = self.velocity.add(joyForce)
            }
        }
        
        if self.HUDNode!.getJumpState() && self.numJumpsLeft > 0 {
            if ((self.state == CharacterState.FALLING && self.numJumpsLeft == 2) ||
                (self.state == CharacterState.JUMPING && self.numJumpsLeft == 1) ||
                (self.state == CharacterState.DOUBLE_JUMPING)) && self.acceleratingFrames > 0 {
                // if the character is already falling when the jump button was pressed
                // OR if the character has already made the first JUMP
                // OR if the character is in double jump state
                self.velocity = CGPoint(x: self.velocity.x, y: Player.JUMP_FORCE * Player.SECOND_JUMP_MULTIPLIER)
                self.acceleratingFrames -= 1
                self.jumpInProgress = true
                self.trackingFallDamage = true
                newState = CharacterState.DOUBLE_JUMPING
            } else if self.numJumpsLeft == 2 && self.acceleratingFrames > 0 {
                // conditions necessary to gain the MAX first jump
                self.velocity = CGPoint(x: self.velocity.x, y: Player.JUMP_FORCE)
                self.acceleratingFrames -= 1
                self.jumpInProgress = true
                self.onGround = false
                self.trackingFallDamage = true
                newState = CharacterState.JUMPING
            }
        } else if !self.HUDNode!.getJumpState() && self.jumpInProgress {
            // USER detached jump button while player is still jumping
            self.acceleratingFrames = 0
            if !isOnRope {
                // adjust jump variables to account for current jump state
                if newState == CharacterState.JUMPING {
                    self.numJumpsLeft -= 1
                    self.acceleratingFrames = Player.SECOND_JUMP_FRAMES
                } else {
                    self.numJumpsLeft = 0
                }
            }
            
            self.jumpInProgress = false
        }
        
        // if player is not dead
        if self.state != CharacterState.DEAD {
            if self.onGround {
                if self.trackingFallDamage {
                    // player can fall for a total vertical distance of 12 tiles before dying
                    let safeYTiles : CGFloat = 12
                    if self.greatestPosition > self.position.y {
                        // this means that 'player' has fallen to a lower point
                        let deltaTiles = (self.greatestPosition - self.position.y) / self.InteractableTileMap!.getTileMap().tileSize.height
                        if abs(deltaTiles) > safeYTiles {
                            newState = CharacterState.DEAD
                            self.deathCause = DeathCause.FALLING
                            self.velocity = CGPoint(x: 0.0, y: self.velocity.y)
                            updateState(newState)
                            return
                        }
                    }
                }
                
                // reset tracking and jump information
                self.greatestPosition = 0
                self.trackingFallDamage = false
                self.acceleratingFrames = Player.FIRST_JUMP_FRAMES
                self.jumpInProgress = false
                self.numJumpsLeft = 2
                
                // adjust state using DEADZONE_CONSTANT whether walking or IDLE
                if newState != CharacterState.CLIMBING {
                    if abs(thumbDelta.x) > DEADZONE_CONSTANT {
                        newState = CharacterState.WALKING
                    } else {
                        newState = CharacterState.IDLE
                    }
                }
            } else if newState != CharacterState.JUMPING && newState != CharacterState.DOUBLE_JUMPING && newState != CharacterState.CLIMBING {
                newState = CharacterState.FALLING
                self.trackingFallDamage = true
            } else if isOnRope {
                // reset jump information if CLIMBING
                self.acceleratingFrames = Player.FIRST_JUMP_FRAMES
                self.jumpInProgress = false
                self.numJumpsLeft = 2
            }
        }
        
        // update state information
        updateState(newState)
        
        // allow for gravity to execute if Player is not climbing
        if newState != CharacterState.CLIMBING {
            let gravityStep = self.gravityVector.multiplyScalar(delta)
            self.velocity = self.velocity.add(gravityStep)
        }
        
        // update the max height if tracking fall dmaage
        if self.trackingFallDamage {
            if self.position.y > self.greatestPosition {
                self.greatestPosition = self.position.y
            }
        }
        
        // run extra velocity and position computation factors
        self.velocity = self.velocity.multiplyScalar(Player.PLAYER_DAMPING)
        self.velocity = self.velocity.clamp(-Player.PLAYER_MAX_SPEED, Player.PLAYER_MAX_SPEED)
        let velocityStep = self.velocity.multiplyScalar(delta)
        self.desiredPosition = self.position.add(velocityStep)
        if newState == CharacterState.CLIMBING {
            // if player is climbing, clamp him to the middle of the tile
            self.desiredPosition = CGPoint(x: CGFloat(xCoord) * tileSize.width + tileSize.width / 2, y: self.desiredPosition.y)
        }
    }
    
    // the bounding box to be used for collisions
    override public func collisionBoundingBox() -> CGRect {
        var originalBounding = CGRect(x: self.desiredPosition.x - Player.PLAYER_WIDTH/2,
                                      y: self.desiredPosition.y - Player.PLAYER_HEIGHT/2,
                                      width: Player.PLAYER_WIDTH,
                                      height: Player.PLAYER_HEIGHT)
        originalBounding = originalBounding.insetBy(dx: 6, dy: 0)
        return originalBounding
    }
}
