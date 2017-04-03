import Foundation
import SpriteKit

public class Cannonball : Character {
    // constants
    private static var CANNONBALL_WIDTH : CGFloat = 32
    private static var CANNONBALL_HEIGHT : CGFloat = 32
    private static var HORIZ_ACCELERATION : CGFloat = 3000
    public var directionOfMotion : CGFloat = 1

    // ensure constant horizontal speed
    override public func update(_ delta: TimeInterval) {
        self.velocity = CGPoint(x: self.directionOfMotion * Cannonball.HORIZ_ACCELERATION * 0.3, y: 0)
        let velocityStep = self.velocity.multiplyScalar(delta)
        self.desiredPosition = self.position.add(velocityStep)
    }
    
    // the bounding box to be used for collisions
    override public func collisionBoundingBox() -> CGRect {
        let originalBounding = CGRect(x: self.desiredPosition.x - Cannonball.CANNONBALL_WIDTH/2,
                                      y: self.desiredPosition.y - Cannonball.CANNONBALL_HEIGHT/2,
                                      width: Cannonball.CANNONBALL_WIDTH,
                                      height: Cannonball.CANNONBALL_HEIGHT)
        return originalBounding
    }
}
