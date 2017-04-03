import Foundation
import UIKit

public enum PerlinInterpolation {
    case Linear
    case Cosine
}

public class PerlinGenerator {
    
    private var MapWidthTiles : Int
    private var MapHeightTiles : Int
    
    public init() {
        self.MapHeightTiles = 0
        self.MapWidthTiles = 0
    }
    
    public init(height : Int, width : Int) {
        self.MapHeightTiles = height
        self.MapWidthTiles = width
    }
    
    public func getMapWidth() -> Int {
        return self.MapWidthTiles
    }
    
    public func getMapHeight() -> Int {
        return self.MapHeightTiles
    }
    
    // generates base white noise
    private func GenerateWhiteNoise() -> [[Float]] {
        var noise = [[Float]]()
        for i in 0 ..< self.MapHeightTiles {
            noise.append([Float]())
            for _ in 0 ..< self.MapWidthTiles {
                // random number generation limited from 0 to 1
                noise[i].append(Float(arc4random()) / Float(UINT32_MAX))
            }
        }
        
        return noise
    }
    
    // computes a smooth noise variant for a given 'octave' where
    // an 'octave' is derived by variation in the sampling from
    // the  base noise matrix
    private func GenerateSmoothNoise(baseNoise:[[Float]], octave:Int, interpolate:PerlinInterpolation) -> [[Float]] {
        
        var smoothNoise = [[Float]]()
        let samplePeriod : Int = 1 << octave;
        let sampleFrequency = 1.0 / Float(samplePeriod)
        
        for i in 0..<self.MapHeightTiles {
            smoothNoise.append([Float]())
            
            // sample indices vertically
            let sampleV0 : Int = ( i / samplePeriod) * samplePeriod;
            let sampleV1 : Int = ( sampleV0 + samplePeriod ) % self.MapHeightTiles
            let verticalBlend : Float = Float(( i - sampleV0 )) * sampleFrequency
            
            for j in 0..<self.MapWidthTiles {
                // sample indices horizontally
                let sampleH0 : Int = ( j / samplePeriod) * samplePeriod;
                let sampleH1 : Int = ( sampleH0 + samplePeriod ) % self.MapWidthTiles
                let horizontalBlend : Float = Float(( j - sampleH0 )) * sampleFrequency
                
                // blend top two corners and bottom two corners
                let iFunction = interpolate == .Linear ? LinearInterpolate : CosineInterpolate
                let topBlendedValue = iFunction(baseNoise[sampleV0][sampleH0], baseNoise[sampleV0][sampleH1], horizontalBlend)
                let bottomBlendedValue = iFunction(baseNoise[sampleV1][sampleH0], baseNoise[sampleV1][sampleH1], horizontalBlend)
                
                // blend top and bottom together to final smooth
                smoothNoise[i].append(iFunction(topBlendedValue, bottomBlendedValue, verticalBlend))
            }
        }
        
        return smoothNoise
    }
    
    public func GeneratePerlinMap(octaveCount : Int, interpolate : PerlinInterpolation) -> [[Float]] {
        if (self.MapHeightTiles == 0 || self.MapWidthTiles == 0) {
            return [[Float]]()
        }
        
        let baseNoise = GenerateWhiteNoise()
        var smoothNoise = [[[Float]]]();
        let persistence : Float = 0.5 // how much to retain when shifting octaves
        for octave in 0..<octaveCount {
            smoothNoise.append(GenerateSmoothNoise(baseNoise: baseNoise, octave: octave, interpolate: interpolate))
        }
        
        var perlinMap = [[Float]](repeating:[Float](repeating:0.0,count:self.MapWidthTiles), count:self.MapHeightTiles)
        var amplitude : Float = 1.0 // reflects weighted factor
        var totalAmplitude : Float = 0.0 // for normalization [0..1]
        
        for octave in stride(from: octaveCount-1, through: 0, by: -1) {
            amplitude *= persistence
            totalAmplitude += amplitude
            
            for i in 0..<self.MapHeightTiles {
                for j in 0..<self.MapWidthTiles {
                    perlinMap[i][j] += smoothNoise[octave][i][j] * amplitude
                }
            }
        }
        
        // normalize values
        for i in 0..<self.MapHeightTiles {
            for j in 0..<self.MapWidthTiles {
                perlinMap[i][j] /= totalAmplitude
            }
        }
        
        return perlinMap
    }
    
    private func CosineInterpolate(_ x0 : Float, _ x1 : Float, _ mu : Float) -> Float {
        // utilize cosine interpolation
        // adjust mu to account for curve
        let adjustedMu = (1.0 - cos(mu * Float(M_PI)))/2.0
        return x0 * (1 - adjustedMu) + x1 * adjustedMu
    }
    
    private func LinearInterpolate(_ x0 : Float, _ x1 : Float, _ alpha : Float) -> Float {
        // utilize linear interpolation
        return x0 * (1 - alpha) + x1 * alpha;
    }
}
