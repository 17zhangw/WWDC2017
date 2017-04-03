import Foundation
import SpriteKit
import AVFoundation

public protocol GameProtocol : NSObjectProtocol {
    func restartInitiated()
}

public class GameScene : SKScene, HUDTouchTriggered, TurretProtocol {
    //MARK: Variables and Constants
    // scene information
    private static let NUM_TILES_HEIGHT = 100
    private static let NUM_TILES_WIDTH = 100
    private static let TILE_SIZE = CGSize(width: 64, height: 64)
    private static let SCENE_SIZE = CGSize(width: CGFloat(NUM_TILES_WIDTH) * TILE_SIZE.width, height: CGFloat(NUM_TILES_HEIGHT) * TILE_SIZE.height)
    
    // texture atlases
    private var InanimateWallTexture : SKTextureAtlas?
    private var CharacterTexture : SKTextureAtlas?
    private var InteractablesTexture : SKTextureAtlas?
    private var EnemiesTexture : SKTextureAtlas?
    
    // tilesets
    private var InanimateWallTileSet : SKTileSet?
    private var InteractablesTileSet : SKTileSet?
    
    // nodes concerning GlobalNode(), Player(), HUD(), TileMaps()
    private var WorldNode : SKNode?
    private var PlayerNode : Player?
    private var TileMapContainer : TileMap?
    private var InteractableTileMapContainer : TileMap?
    private var HUDNode : HUD?
    
    // reference to the Map Information
    private var MapValidator : AutomataMapValidator?
    
    // collection of enemy objects (subclass of Character)
    private var enemyObjects : [Character] = [Character]()
    
    // variable storing delta time interval
    private var previousUpdateTime : TimeInterval = 0
    
    // ensure that cannot continuously deploy bombs and ropes without lifting finger
    private var ropePressed : Bool = true
    private var bombPressed : Bool = true
    
    // variables to control messages/restarting
    private var hasDisplayedMessage : Bool = false
    private var isSceneRestarting : Bool = false
    
    // variables pertaining to the minimap
    private var mapWrapper : SKShapeNode?
    private var isDisplayingMinimap : Bool = false
    
    // reference to the exit rectangle
    private var exitRect : CGRect = CGRect.zero
    
    public weak var gameDelegate : GameProtocol?
    
    //MARK: Texture Helper Functions
    public func loadTextureAtlases() -> Bool {
        // create texture atlases from the respective folders
        loadTextureTiles(atlas: &self.InanimateWallTexture, atlasName: "InanimateWall")
        loadTextureTiles(atlas: &self.CharacterTexture, atlasName: "Character")
        loadTextureTiles(atlas: &self.InteractablesTexture, atlasName: "Interactables")
        loadTextureTiles(atlas: &self.EnemiesTexture, atlasName: "Enemies")
        
        // create tilesets for the SKTileMapNode
        loadTileSetFromTextureAtlas(&self.InanimateWallTileSet, atlas: self.InanimateWallTexture!)
        loadTileSetFromTextureAtlas(&self.InteractablesTileSet, atlas: self.InteractablesTexture!)
        return true
    }
    
    // create animation from atlas
    private func createSKAnimationFromAtlas(_ atlas : SKTextureAtlas, _ animationName : String, _ duration : Double) -> SKAction {
        var textures : [SKTexture] = [SKTexture]()
        
        // filter all texturenames based on whether they precede with the 'animationName'
        var textureNames = atlas.textureNames.filter {(s:String) -> Bool in return s.hasPrefix(animationName)}
        
        // sort the textures in ascending order (frame #) of format (ANIMATION-NAME_#)
        textureNames.sort {(s1 : String, s2 : String) -> Bool in
            return Int(s1.components(separatedBy: "_")[1])! < Int(s2.components(separatedBy: "_")[1])!
        }
        
        for textureName in textureNames {
            textures.append(atlas.textureNamed(textureName))
        }
        
        // create the SKAction
        return SKAction.animate(with: textures, timePerFrame: duration, resize: true, restore: false)
    }
    
    // create the SKTextureAtlas
    private func loadTextureTiles(atlas : inout SKTextureAtlas?, atlasName : String) {
        let Folder = Bundle.main.path(forResource: atlasName, ofType: "")
        do {
            // load all files from the specified atlas folder
            let FileContents : [String] = try FileManager.default.contentsOfDirectory(atPath: Folder!)
            var FileDictionary = Dictionary<String, URL>()
            for file in FileContents {
                // ignore any 'hidden' files or miscellaneous files
                if file.hasPrefix(".") {
                    continue
                }
                
                // remove the file extension and use the remainder as the TextureName
                let FileURL = NSURL(fileURLWithPath: Folder!).appendingPathComponent(file)
                let fileKey = (file as NSString).deletingPathExtension
                FileDictionary[fileKey] = FileURL!
            }
            
            // create the texture atlas
            atlas = SKTextureAtlas(dictionary: FileDictionary)
        } catch {
            
        }
    }
    
    // create the SKTileSet
    private func loadTileSetFromTextureAtlas(_ tileset : inout SKTileSet?, atlas : SKTextureAtlas) {
        let textureNames : [String] = atlas.textureNames
        var tileGroups = [SKTileGroup]()
        var shouldCreateBackTile = false
        for textureName in textureNames {
            // if it is a BackTile, stash for later
            if textureName.contains("BackTile") {
                shouldCreateBackTile = true
                continue
            }
            
            // create the necessary SKTileDefinition/SKTileGroup and set the name accordingly
            let texture = atlas.textureNamed(textureName)
            let tileDefinition = SKTileDefinition(texture: texture, size: texture.size())
            let tileGroup = SKTileGroup(tileDefinition: tileDefinition)
            tileDefinition.name = textureName
            tileGroup.name = textureName
            tileGroups.append(tileGroup)
        }
        
        if shouldCreateBackTile {
            // create the SKTileGroup using a SKTileGroupRule
            // that prescribes the weighted values between Up/Down/Left/Right
            let textureNames = ["BackTilesUp", "BackTilesDown", "BackTilesLeft", "BackTilesRight"]
            let placementWeights = [ 2,2,1,1 ]
            var tileDefinitions = [SKTileDefinition]()
            for textureName in textureNames {
                let tileDefinition = SKTileDefinition(texture: atlas.textureNamed(textureName))
                tileDefinition.name = textureName
                tileDefinition.placementWeight = placementWeights[textureNames.index(of: textureName)!]
                tileDefinitions.append(tileDefinition)
            }
            
            let tileGroupRule = SKTileGroupRule()
            tileGroupRule.name = "BackTiles"
            tileGroupRule.tileDefinitions = tileDefinitions
            
            let tileGroup = SKTileGroup(rules: [tileGroupRule])
            tileGroup.name = "BackTiles"
            tileGroups.append(tileGroup)
        }
        
        tileset = SKTileSet(tileGroups: tileGroups)
    }
    
    //MARK: Scene Creation
    public func createScene() -> Bool {
        self.WorldNode = SKNode()
        self.scene?.addChild(self.WorldNode!)
        
        // create HUD Node
        self.HUDNode = HUD(size: self.frame.size)
        self.HUDNode!.zPosition = 1500
        self.HUDNode!.HUDDelegate = self
        self.addChild(self.HUDNode!)
        
        // generate until a valid Zone is found
        var isZoningValid = false
        var largestZone : Zone?
        var map : [[Float]] = [[Float]]()
        while !isZoningValid {
            // generate the map
            let perlinGen = PerlinGenerator(height: GameScene.NUM_TILES_HEIGHT, width: GameScene.NUM_TILES_WIDTH)
            let automataMap = AutomataMap(height: GameScene.NUM_TILES_HEIGHT, width: GameScene.NUM_TILES_WIDTH)
            map = perlinGen.GeneratePerlinMap(octaveCount: 5, interpolate: .Linear)
            automataMap.createMap(numSimulation: 5)
            
            // construct zones and validate the map
            self.MapValidator = AutomataMapValidator(map: automataMap)
            self.MapValidator!.fillMapBoundaries()
            self.MapValidator!.constructMapZones()
            (isZoningValid, largestZone) = self.MapValidator!.isZoningValid()
        }

        // create the Spawn and Exit tiles
        let (spawnPoint, exitPoint) = self.MapValidator!.generateStartFinishTiles(zone: largestZone!)
        
        // create the main TileMap
        let ColorScheme = generateTileColorScheme()
        self.TileMapContainer = TileMap(worldSize: GameScene.SCENE_SIZE,
                                        tileSize: GameScene.TILE_SIZE,
                                        tileSet: self.InanimateWallTileSet!,
                                        colorScheme: ColorScheme)
        
        // create the TileMap's tiles, draw Spawn/Exit tiles
        // set the TileMap to be behind all tiles
        let _ = self.TileMapContainer?.generateTiles(map, automata: self.MapValidator!)
        self.TileMapContainer?.generateSpawnExit(spawn: spawnPoint, exit: exitPoint)
        self.TileMapContainer?.getTileMap().zPosition = -100
        self.WorldNode?.addChild(self.TileMapContainer!.getTileMap())
        
        // save the exit point for later computations
        self.exitRect = CGRect(x: CGFloat(exitPoint.Column) * GameScene.TILE_SIZE.width,
                               y: GameScene.SCENE_SIZE.height - CGFloat(exitPoint.Row + 1) * GameScene.TILE_SIZE.height,
                               width: GameScene.TILE_SIZE.width,
                               height: GameScene.TILE_SIZE.height)
        
        // create the TileMap used for interactables
        self.InteractableTileMapContainer = TileMap(worldSize: GameScene.SCENE_SIZE,
                                                    tileSize: GameScene.TILE_SIZE,
                                                    tileSet: self.InteractablesTileSet!,
                                                    colorScheme: ColorScheme)
        self.InteractableTileMapContainer!.getTileMap().zPosition = -99
        self.WorldNode?.addChild(self.InteractableTileMapContainer!.getTileMap())
        
        // Create the Player and set the necessary variables
        // Load all Player animations to be used later for fast access
        let spawn = convertTileToCenterPoint(tilePosition: spawnPoint, shouldInvert: true)
        self.PlayerNode = Player(texture: self.CharacterTexture!.textureNamed("Armature"))
        self.PlayerNode?.zPosition = 1000
        self.PlayerNode?.position = spawn // set Player position to the spawn point
        self.PlayerNode!.HUDNode = self.HUDNode!
        self.PlayerNode!.InteractableTileMap = self.InteractableTileMapContainer!
        self.PlayerNode!.textureAtlas = self.CharacterTexture!
        self.PlayerNode!.animations = [ "Idle":createSKAnimationFromAtlas(CharacterTexture!, "Armature-Idle", 0.1),
                                        "Walk":createSKAnimationFromAtlas(CharacterTexture!, "Armature-Run", 0.1),
                                        "Jump":createSKAnimationFromAtlas(CharacterTexture!, "Armature-Jump", 0.03),
                                        "Dead":createSKAnimationFromAtlas(CharacterTexture!, "Armature-Dead", 0.1),
                                        "Shot":createSKAnimationFromAtlas(CharacterTexture!, "Shot", 0.1),
                                        "Falling":createSKAnimationFromAtlas(CharacterTexture!, "Falling", 0.1),
                                        "Spike":createSKAnimationFromAtlas(CharacterTexture!, "Spike", 0.1)]
        self.WorldNode?.addChild(self.PlayerNode!)
        
        // generate all Spikes() and Turrets()
        generateSpikes()
        generateTurrets()
        
        // center the camera on Spawn
        self.centerAtTile(tilePosition: spawnPoint, shouldInvert: true)
        return true
    }
    
    private func generateTileColorScheme() -> ColorScheme {
        let i = arc4random_uniform(4)
        switch i {
        case 0: return ColorScheme.Royal
        case 1: return ColorScheme.Snow
        case 3: return ColorScheme.Gold
        case 4: fallthrough
        default: return ColorScheme.Arid
        }
    }
    
    //MARK: Generate Terrain Obstacles
    private func generateSpikes() {
        let zones = self.MapValidator!.getZones()
        zoneLoop: for zone in zones {
            let spike_percentage = 0.25 // 25% of ground tiles should be spikes
            let numTiles = spike_percentage * Double(zone.numGroundTiles) + 0.5
            
            var groundCoords = zone.groundTileCoordinates
            for _ in 0..<Int(numTiles) {
                var spikeRect = CGRect.zero
                while spikeRect.size.width == 0 {
                    if groundCoords.count == 0 {
                        continue zoneLoop
                    }
                    
                    // generate a random location to place the Spike
                    let rand = Int(arc4random_uniform(UInt32(groundCoords.count)))
                    let location = groundCoords[rand]
                    let coord = CGPoint(x: location.Column, y: location.Row)
                    let tileRect = self.TileMapContainer!.tileRectFromTileCoords(coord, shouldInvert: true)
                    
                    var notFound = false
                    // ensure that the Spike is not overlapping with any other enemy object
                    enemyLoop: for enemy in self.enemyObjects {
                        if enemy.collisionBoundingBox().intersects(tileRect) {
                            groundCoords.remove(at: rand)
                            notFound = true
                            break enemyLoop
                        }
                    }
                    
                    if !notFound {
                        spikeRect = tileRect
                    }
                }
                
                // create the Spike and position it accordingly
                // set the zPosition to 49 so to be behind the 'Bomb'
                let spike = Spike(texture: self.EnemiesTexture!.textureNamed("spike"))
                spike.zPosition = 49
                spike.position = CGPoint(x: spikeRect.midX, y: spikeRect.midY)
                spike.PlayerNode = self.PlayerNode!
                self.enemyObjects.append(spike)
                self.WorldNode!.addChild(spike)
            }
        }
    }
    
    private func generateTurrets() {
        generateTurretsSide(isLeft: true) // generate turrets facing the right
        generateTurretsSide(isLeft: false) // generate turrets facing the left
        
        // recalibrate the zoning map
        self.MapValidator!.drawInternalMap()
        self.MapValidator!.constructMapZones()
    }
    
    private func generateTurretsSide(isLeft : Bool) {
        let zones = self.MapValidator!.getZones()
        
        // create the animation
        let turretAnimation = ["Fire":createSKAnimationFromAtlas(self.EnemiesTexture!, "Turret-Fire", 0.3)]
        zoneLoop: for zone in zones {
            let spike_percentage = 0.125 // combined 25% vertical walls have turrets
            let numTiles = spike_percentage * Double(isLeft ? zone.numLeftTiles : zone.numRightTiles) + 0.5
            
            // ensure that a tile is not captured by a solid wall on LEFT and RIGHT
            var groundCoords = isLeft ? zone.leftTileCoordinates : zone.rightTileCoordinates
            let otherCoords = isLeft ? zone.rightTileCoordinates : zone.leftTileCoordinates
            for loc in otherCoords {
                if groundCoords.contains(loc) {
                    groundCoords.remove(at: groundCoords.index(of: loc)!)
                }
            }
            
            for _ in 0..<Int(numTiles) {
                var turretRect = CGRect.zero
                while turretRect.size.width == 0 {
                    if groundCoords.count == 0 {
                        continue zoneLoop
                    }
                    
                    // generate a random location to place the Turret
                    let rand = Int(arc4random_uniform(UInt32(groundCoords.count)))
                    let location = groundCoords[rand]
                    let coord = CGPoint(x: location.Column, y: location.Row)
                    let tileRect = self.TileMapContainer!.tileRectFromTileCoords(coord, shouldInvert: true)
                    
                    var isFound = false
                    // ensure that the Turret is not overlapping with any other enemy object
                    enemyLoop: for enemy in self.enemyObjects {
                        if enemy.collisionBoundingBox().intersects(tileRect) {
                            groundCoords.remove(at: rand)
                            isFound = true
                            break enemyLoop
                        }
                    }
                    
                    if !isFound {
                        // alter the internal map to reflect a 'wall' => simplies boundary collision tests
                        turretRect = tileRect
                        self.MapValidator!.alterInternalRawMap(location.Column, location.Row, true)
                    }
                }
                
                // draws the turret with the correct orientation
                // sets up the turret's type and adds in the animation
                let turret = Turret(texture: self.EnemiesTexture!.textureNamed("Turret"))
                turret.zPosition = 49
                turret.position = CGPoint(x: turretRect.midX, y: turretRect.midY)
                turret.PlayerNode = self.PlayerNode!
                turret.setupTurretType()
                turret.textureAtlas = self.EnemiesTexture
                turret.animations = turretAnimation
                turret.xScale = isLeft ? 1 : -1
                turret.TurretDelegate = self
                self.enemyObjects.append(turret)
                self.WorldNode!.addChild(turret)
            }
        }
    }
    
    //MARK: Camera Functions    
    private func convertTileToCenterPoint(tilePosition : Location, shouldInvert : Bool) -> CGPoint {
        // adjusts the location to account for coordinate system
        var adjustedRow = tilePosition.Row
        if shouldInvert {
            adjustedRow = self.TileMapContainer!.getTileMap().numberOfRows - 1 - adjustedRow
        }
        
        // convert to points, want to focus on the center!
        let x = GameScene.TILE_SIZE.width * CGFloat(tilePosition.Column) + GameScene.TILE_SIZE.width/2
        let y = GameScene.TILE_SIZE.height * CGFloat(adjustedRow) + GameScene.TILE_SIZE.height/2
        return CGPoint(x: x, y: y)
    }
    
    public func centerAtTile(tilePosition : Location, shouldInvert : Bool) {
        self.centerAtPoint(convertTileToCenterPoint(tilePosition: tilePosition, shouldInvert: shouldInvert))
    }
    
    public func centerAtPoint(_ point : CGPoint) {
        let Tile = self.TileMapContainer!.getTileMap()
        // adjust camera accordingly
        // first bound against left/bottom corners
        var x = max(point.x, self.frame.size.width/2)
        var y = max(point.y, self.frame.size.height/2)
        
        // next bound against extremes
        x = min(x, (Tile.mapSize.width) - self.frame.size.width/2)
        y = min(y, (Tile.mapSize.height) - self.frame.size.height/2)
        
        // reposition the WorldNode
        let shiftVec = CGPoint(x: x - self.frame.size.width/2, y: y-self.frame.size.height/2)
        self.WorldNode!.position = CGPoint(x: -shiftVec.x, y: -shiftVec.y)
    }
    
    //MARK: Update Sequences
    override public func update(_ currentTime: TimeInterval) {
        if self.isSceneRestarting {
            return
        }
        
        // IF User decides to restart, initiate restart
        if self.HUDNode != nil && self.HUDNode!.getRestartState() && !self.isSceneRestarting {
            self.isSceneRestarting = true
            restartScene()
            return
        }
        
        // force a consistent 60fps, even though visibly lagging
        // ensures that computations will be accurate
        var delta = currentTime - self.previousUpdateTime
        self.previousUpdateTime = currentTime
        if delta > 0.017 { // cap delta if FPS falls too low
            delta = 0.017  // 60 fps...
        }
        
        // update Player's posiiton, resolve wall collisions, and center the camera
        self.PlayerNode!.update(delta)
        _ = resolveCollisions(self.PlayerNode!, self.TileMapContainer!)
        centerAtPoint(self.PlayerNode!.position)
        
        var enemiesToRemove = [Character]()
        for enemy in self.enemyObjects {
            // update enemy positions, resolve their collisions
            enemy.update(delta)
            let didCollide = resolveCollisions(enemy, self.TileMapContainer!)
            
            if enemy.isKind(of: Bomb.self) {
                if (enemy as! Bomb).state == CharacterState.EXPLODING {
                    // delete the Bomb if it has entered explosion status
                    enemiesToRemove.append(enemy)
                }
                
            } else if enemy.isKind(of: Spike.self) && enemy.collisionBoundingBox().intersects(self.PlayerNode!.collisionBoundingBox()) {
                // kill the player if the Player is in contact with a Spike
                // force their horizontal velocity to 0
                self.PlayerNode!.updateState(CharacterState.DEAD)
                self.PlayerNode!.deathCause = DeathCause.SPIKE
                self.PlayerNode!.velocity = CGPoint(x: 0.0, y: self.PlayerNode!.velocity.y)
            } else if enemy.isKind(of: Cannonball.self) && enemy.collisionBoundingBox().intersects(self.PlayerNode!.collisionBoundingBox()) {
                // kill the Player if the Player is in contact with the Cannonball
                self.PlayerNode!.updateState(CharacterState.DEAD)
                if enemy.position.x < self.PlayerNode!.position.x {
                    self.PlayerNode!.deathCause = DeathCause.SHOT_FROM_LEFT
                } else {
                    self.PlayerNode!.deathCause = DeathCause.SHOT_FROM_RIGHT
                }
                
                // force their horizontal velocity to 0
                self.PlayerNode!.velocity = CGPoint(x: 0.0, y: self.PlayerNode!.velocity.y)
                enemiesToRemove.append(enemy)
            } else if enemy.isKind(of: Cannonball.self) && didCollide {
                // if the Cannonball collided with walls, remove it
                enemiesToRemove.append(enemy)
            }
        }
        
        for enemy in enemiesToRemove {
            enemy.removeFromParent()
            self.enemyObjects.remove(at: self.enemyObjects.index(of: enemy)!)
            
            if enemy.isKind(of: Bomb.self) {
                // detonate the bomb using the SKEmitterNode for effects
                let bombNode = SKEmitterNode(fileNamed: "Explosion")
                bombNode!.position = enemy.position
                bombNode!.zPosition = 50
                self.WorldNode!.addChild(bombNode!)
                enemy.removeFromParent()
                self.run(SKAction.sequence([SKAction.wait(forDuration: 0.68), SKAction.run {bombNode!.removeFromParent()}]))
                detonateBomb(enemy as! Bomb, self.PlayerNode!)
            }
        }
        
        // disable HUD and blink restart if player is dead
        if self.PlayerNode!.state == CharacterState.DEAD {
            self.HUDNode!.disable()
            self.HUDNode!.blinkRestart()
            
            if !self.hasDisplayedMessage {
                // the three specific death animations were taken with the
                // permission of Pow Studios so long as due credit was given to them
                
                // adjust the animation and positioning of the animation
                // depending on the specific cause
                // use the FRAME and not the collisionBoundingBox() so animation is not
                // at an intermediary part of the sprite
                let animation : SKAction?
                let bloodNode = SKSpriteNode()
                var position : CGPoint = CGPoint.zero
                switch self.PlayerNode!.deathCause {
                case DeathCause.FALLING:
                    animation = self.PlayerNode!.animations["Falling"]
                    position = self.PlayerNode!.position.add(CGPoint(x: 0, y: -self.PlayerNode!.frame.size.height/2))
                case DeathCause.EXPLOSION:
                    animation = self.PlayerNode!.animations["Falling"]
                    position = self.PlayerNode!.position
                case DeathCause.SHOT_FROM_LEFT:
                    animation = self.PlayerNode!.animations["Shot"]
                    position = self.PlayerNode!.position.add(CGPoint(x: self.PlayerNode!.frame.size.width/2, y: 0))
                case DeathCause.SHOT_FROM_RIGHT:
                    animation = self.PlayerNode!.animations["Shot"]
                    position = self.PlayerNode!.position.add(CGPoint(x: -self.PlayerNode!.frame.size.width/2, y: 0))
                    bloodNode.xScale = -bloodNode.xScale
                case DeathCause.SPIKE:
                    animation = self.PlayerNode!.animations["Spike"]
                    position = self.PlayerNode!.position.add(CGPoint(x: 0, y: -self.PlayerNode!.frame.size.height/2))
                }
                
                bloodNode.position = position
                bloodNode.zPosition = 1100
                self.WorldNode!.addChild(bloodNode)
                bloodNode.run(animation!, completion: {
                    bloodNode.removeFromParent()
                })
                
                // play the sound effect
                if !MusicPlayer.sharedInstance().getCurrentEffectResource().contains("Splatter") {
                    MusicPlayer.sharedInstance().playEffectAudio("Splatter", false)
                }
                
                // display the death label
                let deathLabel = SKLabelNode(text: "YOU DIED 😔. Try Again?")
                deathLabel.fontSize = 56
                deathLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
                deathLabel.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
                deathLabel.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
                deathLabel.zPosition = 2000
                deathLabel.name = "Death"
                deathLabel.alpha = 0.0
                self.addChild(deathLabel)
                
                let bloodredLbl = SKShapeNode(rect: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
                bloodredLbl.fillColor = UIColor(red: 138/255.0, green: 7/255.0, blue: 7/255.0, alpha: 1.0)
                bloodredLbl.zPosition = 1300
                bloodredLbl.name = "Background"
                bloodredLbl.alpha = 0.0
                self.addChild(bloodredLbl)
                
                // animate the display of the message
                self.run(SKAction.group([SKAction.run(SKAction.fadeAlpha(to: 0.5, duration: 1.0), onChildWithName: "Background"),
                                         SKAction.run(SKAction.fadeIn(withDuration: 1.0), onChildWithName: "Death")]))
                self.hasDisplayedMessage = true
            }
            
            return
        }
        
        // check if player has reached exit...
        if self.PlayerNode!.collisionBoundingBox().intersects(self.exitRect) {
            // disable and flash restart on the HUD
            self.HUDNode!.disable()
            self.HUDNode!.blinkRestart()
            
            // animate the Player disappearing into the BlackBox
            self.PlayerNode!.run(SKAction.group([SKAction.move(to: CGPoint(x: self.exitRect.midX, y: self.exitRect.midY), duration: 0.1),
                                                 SKAction.fadeOut(withDuration: 0.1)]))
            
            if !self.hasDisplayedMessage {
                // play sound effect
                if !MusicPlayer.sharedInstance().getCurrentEffectResource().contains("Triumph") {
                    MusicPlayer.sharedInstance().playEffectAudio("Triumph", false)
                }
                
                // display win label
                let winLabel = SKLabelNode(text: "Next Round? 😉")
                winLabel.fontSize = 56
                winLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.center
                winLabel.verticalAlignmentMode = SKLabelVerticalAlignmentMode.center
                winLabel.position = self.view!.center
                winLabel.zPosition = 2000
                winLabel.name = "Win"
                winLabel.alpha = 0.0
                self.addChild(winLabel)
                
                let darkGoldBckgd = SKShapeNode(rect: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
                darkGoldBckgd.fillColor = UIColor(red: 163/255.0, green: 141/255.0, blue: 28/255.0, alpha: 1.0)
                darkGoldBckgd.zPosition = 1300
                darkGoldBckgd.name = "Background"
                darkGoldBckgd.alpha = 0.0
                self.addChild(darkGoldBckgd)
                
                self.run(SKAction.group([SKAction.run(SKAction.fadeAlpha(to: 0.5, duration: 1.0), onChildWithName: "Background"),
                                         SKAction.run(SKAction.fadeIn(withDuration: 1.0), onChildWithName: "Win")]))
                self.hasDisplayedMessage = true
            }
            return
        }
        
        // adjust the indicator sprite so the black points towards the exit
        let dY = self.exitRect.midY - self.PlayerNode!.position.y
        let dX = self.exitRect.midX - self.PlayerNode!.position.x
        self.HUDNode!.IndicatorSprite.zRotation = atan2(dY, dX)
        
        // deploy the CLIMBING if the USER tapped the button
        if self.HUDNode!.getRopeState() && ropePressed {
            deployRopeFromCharacter(self.PlayerNode!, self.InteractableTileMapContainer!)
            ropePressed = false
        } else if !self.HUDNode!.getRopeState() {
            ropePressed = true
        }
        
        // deploy Bomb if USER tapped
        if self.HUDNode!.getBombState() && bombPressed {
            deployBombFromCharacter(self.PlayerNode!)
            bombPressed = false
        } else if !self.HUDNode!.getBombState() {
            bombPressed = true
        }
        
        // show minimap if USER tapped
        if self.HUDNode!.getMinimapState() && !self.isDisplayingMinimap {
            displayMinimap()
            self.isDisplayingMinimap = true
        }
    }
    
    // restarts the scene
    private func restartScene() {
        if self.gameDelegate != nil {
            self.gameDelegate!.restartInitiated()
        }
    }
    
    // displays a small minimap
    private func displayMinimap () {
        // ensure that map takes up 3/4 of the shorter edge of the screen
        let shorterSide = min(self.size.width, self.size.height) * 3/4
        
        // create a black boundary to encapsulate the map
        self.mapWrapper = SKShapeNode(rect: CGRect(x: 0, y: 0, width: shorterSide + 30, height: shorterSide + 30), cornerRadius: 10)
        self.mapWrapper!.zPosition = 2500
        self.mapWrapper!.position = CGPoint(x: self.size.width/2 - (shorterSide + 30)/2,
                                            y: self.size.height/2 - (shorterSide + 30)/2)
        self.mapWrapper!.fillColor = UIColor.black
        self.addChild(self.mapWrapper!)
        
        // creates a picture of the entire map using pixel data generated
        // via the Minimap class
        let MinimapInstance = Minimap(self.MapValidator!)
        let pixelData : [Pixel] = MinimapInstance.getMinimapPixelData()
        let texture = SKTexture(data: Data(bytes: pixelData, count: pixelData.count * 4),
                                size: CGSize(width: 100, height: 100), flipped: true)
        let minimap = SKSpriteNode(texture: texture)
        
        // scale the minimap accordingly, position and add to the mapWrapper
        minimap.scale(to: CGSize(width: shorterSide, height: shorterSide))
        minimap.zPosition = 2500
        minimap.position = CGPoint(x: self.mapWrapper!.frame.size.width/2, y: self.mapWrapper!.frame.size.height/2)
        self.mapWrapper!.addChild(minimap)
        
        // player indicator
        let size = shorterSide / 100.0
        let playerIndicator = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size, height: size))
        playerIndicator.fillColor = UIColor.red
        playerIndicator.zPosition = 2600
        
        // get player coordinates in terms of the internal map
        let playerCoord = self.TileMapContainer!.convertPointToAutomataMapCoords(self.PlayerNode!.position)
        
        // convert the player coordinate into SpriteKit position within the minimap
        let playerX = self.mapWrapper!.frame.size.width/2 - minimap.frame.size.width/2 + CGFloat(playerCoord.Column) * size
        let playerY = self.mapWrapper!.frame.size.height/2 + minimap.frame.size.height/2 - CGFloat(playerCoord.Row + 1) * size
        playerIndicator.position = CGPoint(x: playerX, y: playerY)
        
        // create animation that flashes the player square
        playerIndicator.run(SKAction.repeatForever(SKAction.sequence([SKAction.fadeAlpha(to: 0.5, duration: 0.2),
                                                                      SKAction.fadeIn(withDuration: 0.2)])))
        self.mapWrapper!.addChild(playerIndicator)
    }
    
    // detonation of the bomb
    private func detonateBomb (_ bomb : Bomb, _ player : Player) {
        // calcualte SpriteKit coordinates
        let bombXCoord = Int(bomb.position.x/GameScene.TILE_SIZE.width)
        let bombYCoord = Int(bomb.position.y/GameScene.TILE_SIZE.height)
        
        // these outer loops ensure that detonation results in a gradually spreading out
        // for instance, with a bomb Radius of 3: the detonation is like
        //                                  x
        //                                 xxx
        //                                xxxxx
        //                               xxxxxxx
        //                                xxxxx
        //                                 xxx
        //                                  x
        let bombRadius = 3
        outer: for row in -bombRadius ... bombRadius {
            for col in abs(row)-bombRadius...(bombRadius-abs(row)) {
                // ensure that the frame will not be destroyed
                if bombXCoord + col <= 0 || bombXCoord + col >= GameScene.NUM_TILES_WIDTH - 1 {
                    continue
                }
                
                if bombYCoord + row <= 0 || bombYCoord + row >= GameScene.NUM_TILES_HEIGHT - 1 {
                    continue outer
                }
                
                let existingTile = self.TileMapContainer!.getTileMap().tileDefinition(atColumn: bombXCoord + col, row: bombYCoord + row)
                if existingTile != nil && existingTile!.name!.contains("WallTile") {
                    // if the tile is a 'wall', replace with 'BackTiles' and update the internal map accordingly
                    self.TileMapContainer!.paintTile(col: bombXCoord + col, row: bombYCoord + row, tileName: "BackTiles", shouldFlipRow: false)
                    self.MapValidator!.alterInternalRawMap(bombXCoord + col, GameScene.NUM_TILES_HEIGHT - 1 - (bombYCoord + row), false)
                }
                
                // get the rectangle of the Tile being exploded
                let tileRect = CGRect(x: CGFloat(bombXCoord + col) * GameScene.TILE_SIZE.width,
                                      y: CGFloat(bombYCoord + row) * GameScene.TILE_SIZE.height,
                                      width: GameScene.TILE_SIZE.width,
                                      height: GameScene.TILE_SIZE.height)
                
                // IF tile touching player, kill the Player
                if tileRect.intersects(player.frame) {
                    player.updateState(CharacterState.DEAD)
                    player.deathCause = DeathCause.EXPLOSION
                }
                
                // Kill any enemy objects directly in contact
                var enemiesToRemove = [Character]()
                for enemy in self.enemyObjects {
                    if !enemy.isKind(of: Bomb.self) {
                        if tileRect.intersects(enemy.frame) {
                            enemiesToRemove.append(enemy)
                        }
                    }
                }
                
                for enemy in enemiesToRemove {
                    self.enemyObjects.remove(at: self.enemyObjects.index(of: enemy)!)
                    if enemy.isKind(of: Turret.self) {
                        // adjust the map to account for the hack in setting up the Turret's collision mechanism
                        let turX = Int(enemy.position.x/GameScene.TILE_SIZE.width)
                        let turY = Int(enemy.position.y/GameScene.TILE_SIZE.height)
                        self.MapValidator!.alterInternalRawMap(turX, GameScene.NUM_TILES_HEIGHT - 1 - turY, false)
                    }
                    
                    enemy.removeFromParent()
                }
            }
        }
        
        // recalibrate mapping information
        self.MapValidator!.drawInternalMap()
        self.MapValidator!.constructMapZones()
    }
    
    // deploys Bomb from a Character (i.e Player) position
    // code is here as need access to zoning information
    private func deployBombFromCharacter(_ character : Character) {
        let ZonedMap = self.MapValidator!.getZonedMap()
        
        // calculate Player's coord in SpriteKit coordinate system
        let playerCoord = CGPoint(x: Int(character.position.x/GameScene.TILE_SIZE.width),
                                  y: Int(character.position.y/GameScene.TILE_SIZE.height))
        
        // create the bomb
        let bomb = Bomb(texture: self.EnemiesTexture!.textureNamed("grenade"))
        bomb.color = UIColor.red
        
        // try placing it in front of the player - test if there is a wall there
        // otherwise, place it right at the player's feet
        // this 'wall test' works because when viewing the Player's Sprite, the intersection is either at a tile
        // where the player already is in or is one that directly ends up overlapping the adjacent tile
        var adjustWidth : CGFloat = 0
        if ZonedMap[GameScene.NUM_TILES_HEIGHT - 1 - Int(playerCoord.y)][Int(playerCoord.x) + Int(character.xScale)] != Zone.WALL_ZONE_ID {
            adjustWidth = character.size.width/2 + bomb.size.width/2
        }
        
        // places the bomb
        let xPos = character.position.x + CGFloat(sign(Double(character.xScale))) * (adjustWidth)
        let yPos = character.position.y - character.size.height/2 + bomb.size.height/2
        bomb.position = CGPoint(x: xPos, y: yPos)
        bomb.zPosition = 50
        self.enemyObjects.append(bomb)
        self.WorldNode!.addChild(bomb)
    }
    
    // deploys CLIMBING from the character
    // code is here as need access to zoning information
    private func deployRopeFromCharacter(_ character : Character, _ interactiveMap : TileMap) {
        let ZonedMap = self.MapValidator!.getZonedMap()
        
        // calculate the player's coord in SpriteKit coordinate system
        let tileMapCoord = CGPoint(x: Int(character.position.x / GameScene.TILE_SIZE.width),
                                   y: Int(character.position.y / GameScene.TILE_SIZE.height))
        
        // if tile definition not set (i.e NOT A WALL), start deployment
        if interactiveMap.getTileMap().tileDefinition(atColumn: Int(tileMapCoord.x), row: Int(tileMapCoord.y)) == nil {
            for i in Int(tileMapCoord.y) ..< GameScene.NUM_TILES_HEIGHT {
                // flip the row when matching against Zoning information
                // keep painting until a wall is reached
                if ZonedMap[GameScene.NUM_TILES_HEIGHT - 1 - i][Int(tileMapCoord.x)] == Zone.WALL_ZONE_ID {
                    return
                }
                
                // paint the tile that the character is on as the 'base'
                if i == Int(tileMapCoord.y) {
                    interactiveMap.paintTile(col: Int(tileMapCoord.x), row: i, tileName: "RopeBase", shouldFlipRow: false)
                } else {
                    interactiveMap.paintTile(col: Int(tileMapCoord.x), row: i, tileName: "Rope", shouldFlipRow: false)
                }
            }
        }
    }
    
    //MARK: Collisions
    private func resolveCollisions(_ character : Character, _ tileMap : TileMap) -> Bool {
        let ZonedMap = self.MapValidator!.getZonedMap()
        
        // indices reflecting the tile in the order:
        // TILE_BELOW, TILE_ABOVE, TILE_LEFT, TILE_RIGHT,
        // TILE_TOP_LEFT, TILE_TOP_RIGHT, TILE_BOTTOM_LEFT, TILE_BOTTOM_RIGHT
        let indices : [Int] = [7,1,3,5,0,2,6,8]
        
        var didCollide = false // collision indicator
        character.onGround = false // set the character's onGround to false only to be enabled later as necessary
        
        for tileIndex in indices {
            // get internally mapped character coordinates
            let characterRect = character.collisionBoundingBox()
            let characterCoord = tileMap.convertPointToAutomataMapCoords(character.position)
            
            // calculate the relative shift in columns and rows from the indices
            let tileColumn = tileIndex % 3
            let tileRow = tileIndex / 3
            
            // get the tile coordinate by using the relative shift
            let tileCoord = CGPoint(x: characterCoord.Column+(tileColumn-1), y: characterCoord.Row+(tileRow-1))
            if ZonedMap[Int(tileCoord.y)][Int(tileCoord.x)] == Zone.WALL_ZONE_ID {
                // get the tile rect in terms of SpriteKit's coord system
                let tileRect = tileMap.tileRectFromTileCoords(tileCoord, shouldInvert: true)
                if characterRect.intersects(tileRect) {
                    // handle the collision interaction
                    let intersection = characterRect.intersection(tileRect)
                    collisionIntersection(character, intersection, tileIndex)
                    didCollide = true
                }
            }
            
            character.position = character.desiredPosition
        }
        
        return didCollide
    }
    
    private func collisionIntersection(_ character : Character, _ intersection : CGRect, _ tileIndex : Int) {
        if tileIndex == 7 {
            // if the tile is directly below, push the character vertically upwards
            character.desiredPosition = CGPoint(x: character.desiredPosition.x, y: character.desiredPosition.y + intersection.size.height)
            character.velocity = CGPoint(x: character.velocity.x, y: 0.0)
            character.onGround = true
        } else if tileIndex == 1 {
            // if the tile is directly above, push the character vertically downwards
            character.desiredPosition = CGPoint(x: character.desiredPosition.x, y: character.desiredPosition.y - intersection.size.height);
            character.velocity = CGPoint(x: character.velocity.x, y: 0.0)
        } else if tileIndex == 3 {
            // if the tile is directly left, push the character rightwards
            character.desiredPosition = CGPoint(x: character.desiredPosition.x + intersection.size.width, y: character.desiredPosition.y);
        } else if tileIndex == 5 {
            // if the tile is directly right, push the character leftwards
            character.desiredPosition = CGPoint(x: character.desiredPosition.x - intersection.size.width, y: character.desiredPosition.y);
        } else {
            if intersection.size.width > intersection.size.height {
                // resolve diagonal collision vertically
                var resolutionHeight : CGFloat = 0
                if tileIndex > 4 { // either bottom left or bottom right
                    // push character uwpards and set the character onto ground
                    resolutionHeight = intersection.size.height;
                    if character.velocity.y < 0 {
                        character.velocity = CGPoint(x: character.velocity.x, y: 0.0)
                        character.onGround = true
                    }
                } else { // top left or top right
                    // push character downwards and set the character's y-velocity to 0
                    resolutionHeight = -intersection.size.height;
                    if character.velocity.y > 0 {
                        character.velocity = CGPoint(x: character.velocity.x, y: 0.0)
                    }
                }
                
                // adjust the position as necessary
                character.desiredPosition = CGPoint(x:character.desiredPosition.x, y: character.desiredPosition.y + resolutionHeight)
            } else {
                // resolve diagonal collision horizontally
                var resolutionWidth : CGFloat = 0;
                if (tileIndex == 6 || tileIndex == 0) { // tile leftwards
                    resolutionWidth = intersection.size.width;
                } else { // tile rightwards
                    resolutionWidth = -intersection.size.width;
                }
                
                character.desiredPosition = CGPoint(x: character.desiredPosition.x + resolutionWidth, y: character.desiredPosition.y)
            }
        }
    }
    
    //MARK: Interactions & Delegates
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // get touches to disable minimap
        HUDTapped()
    }
    
    public func HUDTapped() {
        if self.isDisplayingMinimap {
            // remove the minimap if it's being displayed
            self.mapWrapper?.removeFromParent()
            self.mapWrapper = nil
            self.isDisplayingMinimap = false
        }
    }
    
    public func TurretFired(_ turret: Turret) {
        // create the cannonball and position it relative to the turret
        // in the orientation the turret is facing
        let ball = Cannonball(texture: self.EnemiesTexture!.textureNamed("Ball"))
        var position = turret.position
        let shiftDistance = turret.frame.size.width/2 + ball.frame.size.width/2
        let shift : CGFloat = turret.xScale > 0 ? 1 : -1
        position = position.add(CGPoint(x: shift * shiftDistance, y: 0))
        
        ball.position = position
        ball.zPosition = 49
        ball.directionOfMotion = shift
        self.enemyObjects.append(ball)
        self.WorldNode!.addChild(ball)
    }
}
