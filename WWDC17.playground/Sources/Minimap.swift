import Foundation
import UIKit
import CoreGraphics

// 32 bit RGBA pixel representation
public struct Pixel {
    var r:UInt8
    var g:UInt8
    var b:UInt8
    var a:UInt8
}

public class Minimap {
    private var AutomataMap : AutomataMapValidator
    
    public init(_ map : AutomataMapValidator) {
        self.AutomataMap = map
    }
    
    // converts a tile's information into an array of pixel information
    // the wall is denoted as 'black'; the 'empty space' is denoted as 'white'
    // the start location is 'dark blue' and the end point is 'green'
    public func getMinimapPixelData() -> [Pixel] {
        let ZonedMap = self.AutomataMap.getZonedMap()
        let (startLocation, endLocation) = self.AutomataMap.getLocations()
        
        var pixelValues = [Pixel]()
        for i in 0..<self.AutomataMap.getAutomataMap().getHeight() {
            for j in 0..<self.AutomataMap.getAutomataMap().getWidth() {
                if ZonedMap[i][j] == Zone.WALL_ZONE_ID {
                    pixelValues.append(Pixel(r: 0, g: 0, b: 0, a: 255))
                } else {
                    pixelValues.append(Pixel(r: 255, g: 255, b: 255, a: 255))
                }
            }
        }
        
        let startIndex = startLocation.Row * self.AutomataMap.getAutomataMap().getWidth() + startLocation.Column
        let endIndex = endLocation.Row * self.AutomataMap.getAutomataMap().getWidth() + endLocation.Column
        pixelValues[startIndex] = Pixel(r: 0, g: 0, b: 139, a: 255)
        pixelValues[endIndex] = Pixel(r: 152, g: 251, b: 152, a: 255)
        return pixelValues
    }
}
