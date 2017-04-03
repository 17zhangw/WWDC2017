import Foundation
import SpriteKit

// color scheme to use for wall tiles
public enum ColorScheme : String {
    case Royal
    case Snow
    case Arid
    case Gold
}

public class TileMap {
    private var Tile : SKTileMapNode?
    private var TileSize : CGSize = CGSize.zero
    private var ColoringScheme : ColorScheme = ColorScheme.Arid
    
    // convenience initializer
    public init(worldSize : CGSize, tileSize : CGSize, tileSet: SKTileSet, colorScheme : ColorScheme) {
        self.ColoringScheme = colorScheme
        
        let numColumns = Int(worldSize.width/tileSize.width)
        let numRows = Int(worldSize.height/tileSize.height)
        self.TileSize = tileSize
        self.Tile = SKTileMapNode(tileSet: tileSet, columns: numColumns, rows: numRows, tileSize: tileSize)
        
        // adjust tile map position
        self.Tile?.position = CGPoint(x: self.Tile!.mapSize.width/2, y: self.Tile!.mapSize.height/2)
        self.Tile?.name = "World"
    }
    
    public func getTileMap() -> SKTileMapNode {
        return self.Tile!
    }
    
    // paints a tile using a tile group described by tileName
    // shouldFlipRow used when converting between AutomataMap() and SpriteKit() coordinates
    public func paintTile(col:Int, row:Int, tileName:String, shouldFlipRow:Bool) {
        var adjustedRow = row
        if shouldFlipRow {
            adjustedRow = self.Tile!.numberOfRows - 1 - adjustedRow
        }
        
        let tileSet = self.Tile!.tileSet
        let tileGroup = tileSet.tileGroups.first(where: {$0.name == tileName})
        self.Tile!.setTileGroup(tileGroup!, forColumn: col, row: adjustedRow)
    }
    
    // paints the tilemap using probability distribution
    public func generateTiles(_ perlinMap : [[Float]], automata : AutomataMapValidator) -> Bool {
        let zonedMap = automata.getZonedMap()
        if perlinMap.count != self.Tile!.numberOfRows {
            return false
        }
        
        if perlinMap[0].count != self.Tile!.numberOfColumns {
            return false
        }
        
        for i in 0..<self.Tile!.numberOfRows {
            for j in 0..<self.Tile!.numberOfColumns {
                if zonedMap[i][j] != Zone.WALL_ZONE_ID {
                    if zonedMap[i][j] == Zone.WALL_ZONE_UNDEF {
                        continue
                    }
                    
                    // if the tile is not a wall, use the weighted BackTiles tile
                    let tileGroup : String = "BackTiles"
                    self.paintTile(col: j, row: i, tileName: tileGroup, shouldFlipRow: true)
                    continue
                }
                
                // determine the specific tile type depending on the decimal
                var tileGroupHeader : String?
                switch perlinMap[i][j] {
                case 0..<0.3: tileGroupHeader = "WallTile1" // cross
                case 0.3..<0.4: tileGroupHeader = "WallTile2" // signs
                case 0.6..<0.7: tileGroupHeader = "WallTile3" // cemenet
                case 0.7..<1.0: tileGroupHeader = "WallTile4" // mat like
                case 0.4..<0.6: fallthrough
                default: tileGroupHeader = "WallTile5" // brick
                }
                
                let tileIdentifier = tileGroupHeader!.appending(self.ColoringScheme.rawValue)
                self.paintTile(col: j, row: i, tileName: tileIdentifier, shouldFlipRow: true)
            }
        }
        
        return true
    }
    
    public func generateSpawnExit(spawn:Location, exit:Location) {
        // create spawn door
        self.paintTile(col: spawn.Column, row: spawn.Row, tileName: "SpawnDoor1", shouldFlipRow: true)
        self.paintTile(col: spawn.Column, row: spawn.Row-1, tileName: "SpawnDoor2", shouldFlipRow: true)
        
        // create spawn column
        self.paintTile(col: spawn.Column-1, row: spawn.Row, tileName: "SpawnColumn1", shouldFlipRow: true)
        self.paintTile(col: spawn.Column-1, row: spawn.Row-1, tileName: "SpawnColumn2", shouldFlipRow: true)
        self.paintTile(col: spawn.Column+1, row: spawn.Row, tileName: "SpawnColumn1", shouldFlipRow: true)
        self.paintTile(col: spawn.Column+1, row: spawn.Row-1, tileName: "SpawnColumn2", shouldFlipRow: true)
        
        // create end door
        self.paintTile(col: exit.Column, row: exit.Row, tileName: "EndCenter1", shouldFlipRow: true)
        self.paintTile(col: exit.Column, row: exit.Row-1, tileName: "EndCenter2", shouldFlipRow: true)
        self.paintTile(col: exit.Column, row: exit.Row-2, tileName: "EndCenter3", shouldFlipRow: true)
        
        // create end columns
        self.paintTile(col: exit.Column-1, row: exit.Row, tileName: "EndColumn1", shouldFlipRow: true)
        self.paintTile(col: exit.Column-1, row: exit.Row-1, tileName: "EndColumn2", shouldFlipRow: true)
        self.paintTile(col: exit.Column-1, row: exit.Row-2, tileName: "EndColumn3", shouldFlipRow: true)
        self.paintTile(col: exit.Column+1, row: exit.Row, tileName: "EndColumn1", shouldFlipRow: true)
        self.paintTile(col: exit.Column+1, row: exit.Row-1, tileName: "EndColumn2", shouldFlipRow: true)
        self.paintTile(col: exit.Column+1, row: exit.Row-2, tileName: "EndColumn3", shouldFlipRow: true)
    }
    
    //MARK: Tile Rect
    public func tileRectFromTileCoords(_ tileCoords : CGPoint, shouldInvert : Bool) -> CGRect {
        var actualCoord = tileCoords
        if shouldInvert {
            // adjusts the row in converting between two coordinate representations
            actualCoord.y = CGFloat(self.Tile!.numberOfRows - 1 - Int(actualCoord.y))
        }
        
        return CGRect(x: actualCoord.x * self.TileSize.width,
                      y: actualCoord.y * self.TileSize.height,
                      width: self.TileSize.width,
                      height: self.TileSize.height)
    }
    
    // the location returned in this conversion is purely relative to
    // the internal maps and not in the SpriteKit coordinate system
    public func convertPointToAutomataMapCoords(_ point : CGPoint) -> Location {
        let columnNumber : Int = Int(point.x / TileSize.width)
        let rowNumber = Int((self.Tile!.mapSize.height - point.y) / TileSize.height)
        return Location(Column: columnNumber, Row: rowNumber)
    }
}
