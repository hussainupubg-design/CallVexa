import Foundation
import AVFoundation

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var isSpeakerOn: Bool = false
    @Published var currentRouteName: String = "Receiver"
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    func configureAudioSessionForCall() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            updateCurrentRoute()
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
            }
        } catch {
            print("[AudioDeviceManager] Failed to deactivate audio session: \(error)")
        }
    }
    
    func toggleSpeaker() {
        let session = AVAudioSession.sharedInstance()
        do {
            if isSpeakerOn {
                try session.overrideOutputAudioPort(.none)
                DispatchQueue.main.async {
                    self.isSpeakerOn = false
                    self.updateCurrentRoute()
                }
            } else {
                try session.overrideOutputAudioPort(.speaker)
                DispatchQueue.main.async {
                    self.isSpeakerOn = true
                    self.currentRouteName = "Speaker"
                }
            }
        } catch {
            print("[AudioDeviceManager] Failed to toggle speaker: \(error)")
        }
    }
    
    func setSpeaker(enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
            DispatchQueue.main.async {
                self.isSpeakerOn = enabled
                self.updateCurrentRoute()
            }
        } catch {
            print("[AudioDeviceManager] Set speaker error: \(error)")
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        DispatchQueue.main.async {
            self.updateCurrentRoute()
            switch reason {
            case .newDeviceAvailable:
                print("[AudioDeviceManager] Headset or Bluetooth connected")
            case .oldDeviceUnavailable:
                print("[AudioDeviceManager] Headset or Bluetooth disconnected, restoring default route")
                // If headphones were unplugged, fallback to receiver or speaker based on current state
                if self.isSpeakerOn {
                    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                }
            default:
                break
            }
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("[AudioDeviceManager] Audio interruption began (e.g. cellular call or Siri)")
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        @unknown default:
            break
        }
    }
    
    private func updateCurrentRoute() {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        if let output = currentRoute.outputs.first {
            switch output.portType {
            case .builtInSpeaker:
                self.currentRouteName = "Speaker"
                self.isSpeakerOn = true
            case .builtInReceiver:
                self.currentRouteName = "Receiver"
                self.isSpeakerOn = false
            case .headphones, .headsetMic:
                self.currentRouteName = "Headphones"
                self.isSpeakerOn = false
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                self.currentRouteName = output.portName.isEmpty ? "Bluetooth" : output.portName
                self.isSpeakerOn = false
            default:
                self.currentRouteName = output.portName
            }
        }
    }
}
