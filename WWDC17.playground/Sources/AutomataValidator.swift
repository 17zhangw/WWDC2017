import Foundation
import UIKit

public struct Location : Equatable {
    public static let Undef : Location = Location(Column: -1, Row: -1) // indicaor of undefined location
    public static func ==(lhs: Location, rhs: Location) -> Bool {
        return lhs.Column == rhs.Column && lhs.Row == rhs.Row
    }

    public var Column : Int
    public var Row : Int
}

public class Zone {
    public var zoneId : Int = 0                             // zone's ID - wall zone has ZoneId of 0
    public static let WALL_ZONE_ID = 0
    public static let WALL_ZONE_UNDEF = -1
    
    public var size : Int = 0                               // number of tile coordinates, i.e size estimator
    public var numGroundTiles : Int = 0                     // number of tiles, which lie directly above a 'solid' tile
    public var numCeilingTiles : Int = 0                    // number of tiles, which lie directly below a 'solid' tile
    public var numLeftTiles : Int = 0                       // number of tiles that are bounded on the left by 'solid' tile
    public var numRightTiles : Int = 0                      // number of tiles that are bounded ont he right by 'solid' tile
    
    public var groundTileCoordinates = [Location]()
    public var ceilingTileCoordinates = [Location]()
    public var leftTileCoordinates = [Location]()
    public var rightTileCoordinates = [Location]()
}

public class AutomataMapValidator {
    public static let ZONE_VALIDITY_CONSTANT = 0.65
    public static let START_END_MIN_DISTANCE : Double = 60
    
    private var internalMap : AutomataMap
    private var zones : [Zone]
    private var zonedMap : [[Int]]
    
    private var startLocation : Location
    private var endLocation : Location
    
    public init(map : AutomataMap) {
        self.internalMap = map
        self.zonedMap = [[Int]](repeating: Array<Int>(repeating: 0, count: map.getWidth()), count: map.getHeight())
        self.zones = [Zone]()
        self.startLocation = Location.Undef
        self.endLocation = Location.Undef
        
        drawInternalMap()
    }
    
    // draw preliminary map based on initial AutomataMap
    // an 'alive' cell corresponds to the wall
    public func drawInternalMap() {
        let map = self.internalMap.getRawMap()
        for i in 0..<self.internalMap.getHeight() {
            for j in 0..<self.internalMap.getWidth() {
                if map[i][j] {
                    self.zonedMap[i][j] = Zone.WALL_ZONE_ID
                } else {
                    self.zonedMap[i][j] = Zone.WALL_ZONE_UNDEF
                }
            }
        }
        
        if self.zones.count > 0 {
            self.zones.removeAll()
        }
    }
    
    public func getLocations() -> (Location, Location) {
        return (self.startLocation, self.endLocation)
    }
    
    public func getAutomataMap() -> AutomataMap {
        return self.internalMap
    }
    
    public func getZones() -> [Zone] {
        return self.zones
    }
    
    public func getZonedMap() -> [[Int]] {
        return self.zonedMap
    }
    
    public func alterInternalRawMap(_ col : Int, _ row : Int, _ val : Bool) {
        self.internalMap.alterRawMap(row, col, val)
    }
    
    // analyze whether a given tile is bounded by a 'solid' wall or edge
    private func AnalyzeLocationForSolidBound(location : Location, zone : Zone) {
        // if bound is an edge...default to solid
        // if bound is a 'solid' wall surface
        
        // check left
        if location.Column-1 < 0 || self.zonedMap[location.Row][location.Column-1] == Zone.WALL_ZONE_ID {
            zone.leftTileCoordinates.append(Location(Column: location.Column, Row: location.Row))
            zone.numLeftTiles += 1
        }
        
        // check right
        if location.Column+1 >= self.zonedMap[0].count || self.zonedMap[location.Row][location.Column+1] == Zone.WALL_ZONE_ID {
            zone.rightTileCoordinates.append(Location(Column: location.Column, Row: location.Row))
            zone.numRightTiles += 1
        }
        
        // check top
        if location.Row-1 < 0 || self.zonedMap[location.Row-1][location.Column] == Zone.WALL_ZONE_ID {
            zone.ceilingTileCoordinates.append(Location(Column: location.Column, Row: location.Row))
            zone.numCeilingTiles += 1
        }
        
        // check bottom
        if location.Row+1 >= self.zonedMap.count || self.zonedMap[location.Row+1][location.Column] == Zone.WALL_ZONE_ID {
            zone.groundTileCoordinates.append(Location(Column: location.Column, Row: location.Row))
            zone.numGroundTiles += 1
        }
    }
    
    // flood-fill 'forestfire' algorithm to map adjacent accessible tiles
    // this method uses additional memory in contrast to stack space
    private func ForestFire(start : Location, map : inout [[Bool]]) {
        let PaintedZone = Zone()
        PaintedZone.zoneId = self.zones.count + 1
        
        var queue = [Location]()
        self.zonedMap[start.Row][start.Column] = PaintedZone.zoneId
        queue.append(start)
        
        while queue.count != 0 {
            let curLoc = queue.remove(at: 0)
            
            // check whether west tile is 'empty space'
            if (curLoc.Column - 1 >= 0 &&
                map[curLoc.Row][curLoc.Column - 1] == false &&
                self.zonedMap[curLoc.Row][curLoc.Column-1] == Zone.WALL_ZONE_UNDEF) {
                
                self.zonedMap[curLoc.Row][curLoc.Column-1] = PaintedZone.zoneId
                queue.append(Location(Column: curLoc.Column-1, Row: curLoc.Row))
            }
            
            // check whether east tile is 'empty space'
            if (curLoc.Column+1 < self.getAutomataMap().getHeight() &&
                map[curLoc.Row][curLoc.Column+1] == false &&
                self.zonedMap[curLoc.Row][curLoc.Column+1] == Zone.WALL_ZONE_UNDEF) {
                
                self.zonedMap[curLoc.Row][curLoc.Column+1] = PaintedZone.zoneId
                queue.append(Location(Column: curLoc.Column+1, Row: curLoc.Row))
            }
            
            // check whether north tile is 'empty space'
            if (curLoc.Row - 1 >= 0 &&
                map[curLoc.Row-1][curLoc.Column] == false &&
                self.zonedMap[curLoc.Row-1][curLoc.Column] == Zone.WALL_ZONE_UNDEF) {
                
                self.zonedMap[curLoc.Row-1][curLoc.Column] = PaintedZone.zoneId
                queue.append(Location(Column: curLoc.Column, Row: curLoc.Row-1))
            }
            
            // check whether south tile is 'empty space'
            if (curLoc.Row+1 < self.getAutomataMap().getWidth() &&
                map[curLoc.Row+1][curLoc.Column] == false &&
                self.zonedMap[curLoc.Row+1][curLoc.Column] == Zone.WALL_ZONE_UNDEF) {
                
                self.zonedMap[curLoc.Row+1][curLoc.Column] = PaintedZone.zoneId
                queue.append(Location(Column: curLoc.Column, Row: curLoc.Row+1))
            }
            
            // analyze tile's surrounding
            AnalyzeLocationForSolidBound(location: curLoc, zone: PaintedZone)
            PaintedZone.size += 1
        }
        
        
        // mutate the Zone IF it it contains the start location and end location to
        // reflect that the groundTiles are not empty space
        if self.startLocation != Location.Undef && self.endLocation != Location.Undef {
            if  PaintedZone.groundTileCoordinates.contains(self.startLocation) &&
                PaintedZone.groundTileCoordinates.contains(self.endLocation) {
                let sIndex = PaintedZone.groundTileCoordinates.index(of: self.startLocation)!
                let eIndex = PaintedZone.groundTileCoordinates.index(of: self.endLocation)!
                PaintedZone.groundTileCoordinates.remove(at: sIndex)
                PaintedZone.groundTileCoordinates.remove(at: eIndex)
            }
        }
        
        self.zones.append(PaintedZone)
    }
    
    // checks whether the current map configuration is valid
    public func isZoningValid() -> (Bool, Zone?) {
        var largestZone : Zone?
        var totalTiles : Int = 0
        for zone in self.zones {
            totalTiles += zone.size
            if largestZone == nil {
                largestZone = zone
            } else if largestZone!.size < zone.size {
                largestZone = zone
            }
        }
        
        if largestZone == nil || Double(largestZone!.size) / Double(totalTiles) < AutomataMapValidator.ZONE_VALIDITY_CONSTANT {
            return (false, nil)
        }
        
        return (true, largestZone)
    }
    
    // generates the spawn location of the player and the exit
    public func generateStartFinishTiles(zone : Zone) -> (Location, Location) {
        // both start and finish tiles must be in 'groundTileCoordinates'
        // both start and finish tiles cannot be in 'left/right/ceilingTileCoordinates'
        
        // try to sort them as far apart as possible
        // this rudimentary sort forces rows in ascending order
        // and columns in ascending order within row groups
        // should force topleft corner into index 0 and bottomright corner into count-1
        var groundTileCoordsCopy = zone.groundTileCoordinates
        groundTileCoordsCopy.sort { (lhs:Location, rhs:Location) -> Bool in
            if lhs.Row < rhs.Row { return true }
            if lhs.Row > rhs.Row { return false }
            
            if lhs.Column < rhs.Column { return true }
            if lhs.Column > rhs.Column { return false }
            
            return false
        }
        
        // worst time 0(n^2)
        for i in 0..<groundTileCoordsCopy.count {
            for j in stride(from: groundTileCoordsCopy.count-1, to: i, by: -1) {
                let startLoc = groundTileCoordsCopy[i]
                let endLoc = groundTileCoordsCopy[j]
                
                // check surrounding tiles and diagonals, ensure that left and right are perfectly grounded...
                /* ensure that space follows the below diagram where W - Wall, X - empty, U - undefined
                 UUUUU
                 WXXXW
                 WXXXW
                 WWWWW
                 */
                if  zone.leftTileCoordinates.contains(startLoc) ||
                    zone.rightTileCoordinates.contains(startLoc) ||
                    zone.ceilingTileCoordinates.contains(startLoc) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: startLoc.Column-1, Row: startLoc.Row)) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: startLoc.Column+1, Row: startLoc.Row)) ||
                    !zone.groundTileCoordinates.contains(Location(Column: startLoc.Column-1, Row: startLoc.Row)) ||
                    !zone.groundTileCoordinates.contains(Location(Column: startLoc.Column+1, Row: startLoc.Row)) {
                    
                    break
                }
                
                /* - END
                 WWWWW
                 WXXXW
                 WXXXW
                 WXXXW
                 WWWWW
                 */
                if  zone.leftTileCoordinates.contains(endLoc) ||
                    zone.rightTileCoordinates.contains(endLoc) ||
                    zone.ceilingTileCoordinates.contains(endLoc) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: endLoc.Column-1, Row: endLoc.Row)) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: endLoc.Column+1, Row: endLoc.Row)) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: endLoc.Column, Row: endLoc.Row-1)) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: endLoc.Column-1, Row: endLoc.Row-1)) ||
                    zone.ceilingTileCoordinates.contains(Location(Column: endLoc.Column+1, Row: endLoc.Row-1)) ||
                    !zone.groundTileCoordinates.contains(Location(Column: endLoc.Column-1, Row: endLoc.Row)) ||
                    !zone.groundTileCoordinates.contains(Location(Column: endLoc.Column+1, Row: endLoc.Row)) {
                    continue
                }
                
                // check to make sure locations are sufficiently far enough
                if  pow(Double(startLoc.Column - endLoc.Column), 2) + pow(Double(startLoc.Row - endLoc.Row), 2) <
                    pow(AutomataMapValidator.START_END_MIN_DISTANCE, 2) {
                    
                    continue
                }
                
                startLocation = startLoc
                endLocation = endLoc
                
                // adjust the specific zone's tiles accordingly
                groundTileCoordsCopy.remove(at: i)
                groundTileCoordsCopy.remove(at: j)
                zone.groundTileCoordinates = groundTileCoordsCopy
                zone.size -= 2
                zone.numGroundTiles -= 2
                return (startLoc, endLoc)
            }
        }
        
        // fail case - no locations could be found within the set of constraints
        return (Location.Undef, Location.Undef)
    }
    
    // constructs map zones using flood-fill
    public func constructMapZones() {
        var map = self.internalMap.getRawMap()
        let height = self.internalMap.getHeight()
        let width = self.internalMap.getWidth()
        
        // dead cells (false) form the contents of the zone
        for i in 0..<height {
            for j in 0..<width {
                if (map[i][j] == false && self.zonedMap[i][j] == Zone.WALL_ZONE_UNDEF) {
                    // if cell has not been accessed by flood-fill
                    self.ForestFire(start: Location(Column: j, Row: i), map: &map)
                }
            }
        }
    }
    
    // ensure map is completely enclosed on top/bot/left/right
    public func fillMapBoundaries() {
        let height = self.internalMap.getHeight()
        let width = self.internalMap.getWidth()
        for i in 0..<height {
            self.internalMap.mark(row: i, col: 0, mark: true)
            self.internalMap.mark(row: i, col: width-1, mark: true)
            self.zonedMap[i][0] = Zone.WALL_ZONE_ID
            self.zonedMap[i][width-1] = Zone.WALL_ZONE_ID
        }
        
        for i in 0..<width {
            self.internalMap.mark(row: 0, col: i, mark: true)
            self.internalMap.mark(row: height-1, col: i, mark: true)
            self.zonedMap[0][i] = Zone.WALL_ZONE_ID
            self.zonedMap[height-1][i] = Zone.WALL_ZONE_ID
        }
    }
}
