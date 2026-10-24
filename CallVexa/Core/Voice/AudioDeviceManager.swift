import Foundation
import AVFoundation

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var isSpeakerOn: Bool = false
    @Published var currentRouteName: String = "Receiver"
    
    private init() {}
    
    func configureAudioSessionForCall() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("[AudioDeviceManager] Audio session active for call")
        } catch {
            print("[AudioDeviceManager] Failed to configure audio session: \(error)")
        }
    }
    
    func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.none)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            DispatchQueue.main.async {
                self.isSpeakerOn = false
                self.currentRouteName = "Receiver"
            }
        } catch {
            print("[AudioDeviceManager] Failed to deactivate audio session: \(error)")
        }
    }
    
    func setSpeaker(enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if enabled {
                print("[AudioDeviceManager] Switching to LOUDSPEAKER (.speaker)")
                try session.overrideOutputAudioPort(.speaker)
            } else {
                print("[AudioDeviceManager] Switching to EARPIECE (.none)")
                try session.overrideOutputAudioPort(.none)
            }
            DispatchQueue.main.async {
                self.isSpeakerOn = enabled
                self.currentRouteName = enabled ? "Speaker" : "Receiver"
            }
        } catch {
            print("[AudioDeviceManager] setSpeaker error: \(error)")
        }
    }
    
    @discardableResult
    func toggleSpeaker() -> Bool {
        let target = !self.isSpeakerOn
        setSpeaker(enabled: target)
        return target
    }
}
