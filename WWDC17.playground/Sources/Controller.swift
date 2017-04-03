import Foundation
import UIKit
import SpriteKit
import AVFoundation

public class Controller : UIViewController, GameProtocol {
    private var scene : GameScene?
    private var backgroundPlayer : AVAudioPlayer?
    
    // prevent autorotation and interface
    override public var shouldAutorotate: Bool {
        return false
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.landscape
    }
    
    override public func loadView() {
        // force initialization of SKView into 'landscape' orientation
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        var ScreenBounds = UIScreen.main.bounds
        if screenWidth < screenHeight {
            ScreenBounds = CGRect(origin: CGPoint.zero, size: CGSize(width: screenHeight, height: screenWidth))
        }
        
        // intiialize the SKView
        let skview = SKView(frame: ScreenBounds)
        skview.shouldCullNonVisibleNodes = true
        skview.showsFPS = true
        skview.showsNodeCount = true
        skview.allowsTransparency = true
        skview.isMultipleTouchEnabled = true
        skview.backgroundColor = UIColor.black
        self.view = skview
        
        // try forcing the bounds necessary
        self.preferredContentSize = ScreenBounds.size
        
        // The background audio is taken with the permission of
        // and proper credit is given to http://www.purple-planet.com
        MusicPlayer.sharedInstance().initializeBackgroundAudio()
        MusicPlayer.sharedInstance().playBackgroundAudio()
    }
    
    public func presentScene() {
        // creating the waiting display
        let waitScene = SKScene(size: self.view.frame.size)
        waitScene.scaleMode = SKSceneScaleMode.aspectFit
        waitScene.backgroundColor = UIColor.black
        
        let titleNode = SKLabelNode(text: "Wintry World Descent Crawler")
        titleNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        titleNode.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        titleNode.position = self.view.center
        titleNode.fontSize = 72
        waitScene.addChild(titleNode)
        
        let labelNode = SKLabelNode(text: "Loading... 😀")
        labelNode.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
        labelNode.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
        labelNode.position = self.view.center.add(CGPoint(x: 0, y: -titleNode.frame.size.height - 30))
        labelNode.fontSize = 48
        waitScene.addChild(labelNode)
        (self.view as! SKView).presentScene(waitScene, transition: SKTransition.fade(withDuration: 2))
        
        DispatchQueue.global(qos: .userInteractive).async {
            // create the actual GameScene()
            // although this scene size may not stretch fully as the Playground loads and varies
            // the 'aspectRatio' is guaranteed to remain constant through a single 'run'
            self.scene = GameScene(size: self.view.frame.size)
            self.scene?.scaleMode = SKSceneScaleMode.aspectFit
            self.scene?.backgroundColor = UIColor.white
            self.scene?.anchorPoint = CGPoint(x: 0, y: 0)
            self.scene?.gameDelegate = self
            
            // load the texture atlases necessary
            // create the actual scene
            _ = self.scene?.loadTextureAtlases()
            if (!self.scene!.createScene()) {
                return
            }
            
            (self.view as! SKView).presentScene(self.scene!, transition: SKTransition.fade(withDuration: 2))
        }
    }
    
    public func restartInitiated() {
        // stop the effect audio and recreate the scene
        MusicPlayer.sharedInstance().stopEffectAudio()
        presentScene()
    }
}
