import Foundation

// generate caves using mechanics from 'Game of Life'
public class AutomataMap {
    
    public var CHANCE_TO_START_ALIVE : UInt32 = 39  // 39% cells start 'alive'
    public var BIRTH_LIMIT : Int = 3                // MIN surrounding alive to create new cell
    public var STARVATION_LIMIT : Int = 4           // MIN surrounding alive to kill the cell
    
    private var height : Int;
    private var width : Int;
    private var internalMap : [[Bool]];
    
    // convenience initializer to create height x width matrix
    public init(height: Int, width: Int) {
        self.height = height
        self.width = width
        
        self.internalMap = [[Bool]]()
        for _ in 0..<self.height {
            let rowElement = Array<Bool>(repeating: false, count: self.width)
            self.internalMap.append(rowElement)
        }
        
        self.initializeMap()
    }
    
    public func getHeight() -> Int {
        return self.height
    }
    
    public func getWidth() -> Int {
        return self.width
    }
    
    public func alterRawMap(_ row : Int, _ col : Int, _ val : Bool) {
        self.internalMap[row][col] = val
    }
    
    public func getRawMap() -> [[Bool]] {
        return self.internalMap
    }
    
    // sets fields using CHANCE_TO_START_ALIVE to true/false (i.e live/dead)
    public func initializeMap() {
        for i in 0..<self.height {
            for j in 0..<self.width {
                let ranChance = arc4random_uniform(100)
                if ranChance < self.CHANCE_TO_START_ALIVE {
                    self.internalMap[i][j] = true
                } else {
                    self.internalMap[i][j] = false
                }
            }
        }
    }
    
    // changes the size of the internally stored matrix
    public func adjustMapSize(height : Int, width : Int, initialize : Bool) {
        if height <= 0 || width <= 0 {
            return
        }
        
        // adjust width of all elements (adjust for shrinking of height)
        if self.width != width {
            for i in 0..<min(self.height, height) {
                if self.width > width {
                    self.internalMap[i].removeLast(self.width - width)
                } else if self.width < width {
                    let addComponent = Array<Bool>(repeating: false, count: width - self.width)
                    self.internalMap[i].append(contentsOf: addComponent)
                }
            }
        }
        
        // adjust for height
        if self.height != height {
            if self.height > height {
                self.internalMap.removeLast(self.height - height)
            } else  {
                for _ in self.height..<height {
                    let addComponent = Array<Bool>(repeating: false, count: width)
                    self.internalMap.append(addComponent)
                }
            }
        }
        
        self.height = height
        self.width = width
        if initialize {
            initializeMap()
        }
    }
    
    public func createMap(numSimulation : Int) {
        for _ in 0..<numSimulation {
            step()
        }
    }
    
    // external mutating method to change an element described by (row) and (col)
    public func mark(row: Int, col: Int, mark : Bool) {
        self.internalMap[row][col] = mark
    }
    
    private func step() {
        // operate with a separate map to not have changes affect future results
        var temporaryMap = [[Bool]]()
        for _ in 0..<self.height {
            temporaryMap.append(Array<Bool>(repeating: false, count: self.width))
        }
        
        for i in 0..<self.height {
            for j in 0..<self.width {
                // get number of alive neighbors
                let numAliveNeighbors = countAliveNeighbors(i, j)
                var cellStatus = false
                if self.internalMap[i][j] {
                    if numAliveNeighbors < STARVATION_LIMIT {
                        // original cell is alive but not enough surrounding cells
                        cellStatus = false
                    } else {
                        cellStatus = true
                    }
                } else {
                    if numAliveNeighbors > self.BIRTH_LIMIT {
                        // original cell is dead but enough alive to regenerate cell
                        cellStatus = true
                    } else {
                        cellStatus = false
                    }
                }
                
                temporaryMap[i][j] = cellStatus
            }
        }
        
        // assign temporary map to permanent
        self.internalMap = temporaryMap
    }
    
    private func countAliveNeighbors(_ heightIndex : Int, _ widthIndex : Int) -> Int {
        var count = 0
        for i in -1...1 {
            for j in -1...1 {
                let neighborH = heightIndex + i
                let neighborW = widthIndex + j
                if i == 0 && j == 0 {
                    // ignore self
                } else if neighborH < 0 || neighborW < 0 || neighborH >= self.height || neighborW >= self.width {
                    // count offscreen element as 'alive'
                    count += 1
                } else if self.internalMap[neighborH][neighborW] { // 'alive'
                    count += 1
                }
            }
        }
        
        return count
    }
}
