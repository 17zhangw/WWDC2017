import Foundation
import AVFoundation

public class MusicPlayer : NSObject, AVAudioPlayerDelegate {
    // singleton instance
    private static let sharedPlayer = MusicPlayer()
    public class func sharedInstance() -> MusicPlayer {
        return MusicPlayer.sharedPlayer
    }
    
    private var backgroundPlayer : AVAudioPlayer?
    private var currentResource : String = ""
    private var effectPlayer : AVAudioPlayer?
    
    public func isBackgroundAudioPlaying() -> Bool {
        return backgroundPlayer != nil && backgroundPlayer!.isPlaying
    }
    
    // intiializes background music
    public func initializeBackgroundAudio() {
        do {
            let audioURL = Bundle.main.url(forResource: "Background", withExtension: "mp3")
            self.backgroundPlayer = try AVAudioPlayer(contentsOf: audioURL!)
            self.backgroundPlayer!.volume = 0.1
            self.backgroundPlayer!.numberOfLoops = -1
            self.backgroundPlayer!.delegate = self
            self.backgroundPlayer!.prepareToPlay()
        } catch {
            print(error)
        }
    }
    
    public func playBackgroundAudio() {
        if self.backgroundPlayer != nil && !self.backgroundPlayer!.isPlaying {
            self.backgroundPlayer!.play()
        }
    }
    
    public func stopBackgroundAudio() {
        if self.backgroundPlayer != nil {
            self.backgroundPlayer!.stop()
        }
    }
    
    // plays a specific effect
    public func playEffectAudio(_ resourceName : String, _ loopInfinite : Bool) {
        do {
            if self.effectPlayer != nil && self.effectPlayer!.isPlaying {
                self.effectPlayer!.stop()
            }
            
            let audioURL = Bundle.main.url(forResource: resourceName, withExtension: "mp3")
            self.currentResource = resourceName
            self.effectPlayer = try AVAudioPlayer(contentsOf: audioURL!)
            self.effectPlayer!.volume = 1.0
            self.effectPlayer!.numberOfLoops = loopInfinite ? -1 : 0
            self.effectPlayer!.enableRate = true
            self.effectPlayer!.rate = 2.0            
            self.effectPlayer!.delegate = self
            self.effectPlayer!.prepareToPlay()
            self.effectPlayer!.play()
        } catch {
            print(error)
        }
    }
    
    public func getCurrentEffectResource() -> String {
        return self.currentResource
    }
    
    public func stopEffectAudio() {
        if self.effectPlayer != nil {
            self.effectPlayer!.stop()
            self.currentResource = ""
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.currentResource = ""
    }
}
