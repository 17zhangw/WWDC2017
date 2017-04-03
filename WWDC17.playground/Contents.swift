import UIKit
import Foundation
import PlaygroundSupport
import SpriteKit

//: Wintry World Descent Crawler - A Game written using SpriteKit

// Although this code was written exclusively by me, not all of the graphics
// were created directly by myself. All graphics and audio that I used require
// attribution. Henceforth, I have listed them here:
// - Background Audio: http://www.purple-planet.com
// - Original Unaltered Tilsets: Feaw at http://feuniverse.us/users/feaw/
// - Blood Animations: Pow Studios at http://powstudios.com/
// - Original Unaltered Player: Zuhria Alfitra at http://www.gameart2d.com/the-knight-free-sprites.html

PlaygroundPage.current.needsIndefiniteExecution = true
let controller = Controller()
controller.presentScene()
PlaygroundPage.current.liveView = controller

