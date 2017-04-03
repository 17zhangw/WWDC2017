import Foundation
import SpriteKit

public class Spike : Character {
    // constants and a weak reference to the PlayerNode for computation
    private static var SPIKE_WIDTH : CGFloat = 64
    private static var SPIKE_HEIGHT : CGFloat = 64
    private static var SPIKE_LEEWAY : CGFloat = 15
    public weak var PlayerNode : Player?
    
    override public func update(_ delta: TimeInterval) {
        // shortcircuit GameScene()'s udpate if spike is too far out
        if self.position.distanceTo(self.PlayerNode!.position) > 1000 {
            self.desiredPosition = self.position
            return
        }
        
        // allow graity to act
        let gravityStep = self.gravityVector.multiplyScalar(delta)
        self.velocity = self.velocity.add(gravityStep)
        self.velocity = self.velocity.multiplyScalar(0.3)
        self.velocity = self.velocity.clamp(-3764, 3764)
        let velocityStep = self.velocity.multiplyScalar(delta)
        self.desiredPosition = self.position.add(velocityStep)
    }
    
    // the bounding box to be used for collisions
    // shrink the top part by 'SPIKE_LEEWAY'
    // shrink width by 20, 10 from each side
    override public func collisionBoundingBox() -> CGRect {
        var originalBounding = CGRect(x: self.desiredPosition.x - Spike.SPIKE_WIDTH/2,
                                      y: self.desiredPosition.y - Spike.SPIKE_HEIGHT/2,
                                      width: Spike.SPIKE_WIDTH,
                                      height: Spike.SPIKE_HEIGHT - Spike.SPIKE_LEEWAY)
        originalBounding = originalBounding.insetBy(dx: 10, dy: 0)
        return originalBounding
    }
}
