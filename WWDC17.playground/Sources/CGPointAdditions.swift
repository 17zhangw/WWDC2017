import Foundation
import UIKit

// CGPoint helper functions
extension CGPoint {
    
    // returns the addition of another point to self
    public func add(_ point : CGPoint) -> CGPoint {
        return CGPoint(x: self.x + point.x, y: self.y + point.y)
    }
    
    // returns multiplication of self by a constant
    public func multiplyScalar(_ multiplier : Double) -> CGPoint {
        return CGPoint(x: self.x * CGFloat(multiplier), y: self.y * CGFloat(multiplier))
    }
    
    // subtracts another point from self
    public func subtract(_ point : CGPoint) -> CGPoint {
        return CGPoint(x: self.x - point.x, y: self.y - point.y)
    }
    
    // calcualtes distance between self and another point
    public func distanceTo(_ point : CGPoint) -> Double {
        return sqrt(Double(pow(point.x - self.x, 2)) + Double(pow(point.y - self.y, 2)))
    }
    
    // clamps a 'vector' CGPoint between two values
    public func clamp(_ min : CGFloat, _ max : CGFloat) -> CGPoint {
        var newX = self.x
        if newX > max || newX < min {
            newX = (newX > 0 ? 1 : -1) * max
        }
        
        var newY = self.y
        if newY > max || newY < min {
            newY = (newY > 0 ? 1 : -1) * max
        }
        
        return CGPoint(x: newX, y: newY)
    }
}
