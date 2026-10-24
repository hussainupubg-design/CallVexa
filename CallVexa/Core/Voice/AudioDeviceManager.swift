import Foundation
import AVFoundation

final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var isSpeakerOn: Bool = false
    @Published var currentRouteName: String = "Receiver"
    
    private(set) var speakerState: Bool = false
    
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
            // Ensure default at call start is always the earpiece (receiver)
            try session.overrideOutputAudioPort(.none)
            self.speakerState = false
            self.notifyRouteUpdated(isSpeaker: false, routeName: "Receiver")
            print("[AudioDeviceManager] Call audio session active, default route: Earpiece")
        } catch {
            print("[AudioDeviceManager] Failed to configure audio session: \(error)")
        }
    }
    
    func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.none)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            self.speakerState = false
            self.notifyRouteUpdated(isSpeaker: false, routeName: "Receiver")
            print("[AudioDeviceManager] Audio session deactivated")
        } catch {
            print("[AudioDeviceManager] Failed to deactivate audio session: \(error)")
        }
    }
    
    func setSpeaker(enabled: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if enabled {
                print("[AudioDeviceManager] >>> Switching to LOUDSPEAKER (.speaker)")
                try session.overrideOutputAudioPort(.speaker)
            } else {
                print("[AudioDeviceManager] >>> Switching to EARPIECE (.none)")
                try session.overrideOutputAudioPort(.none)
            }
            self.speakerState = enabled
            self.notifyRouteUpdated(isSpeaker: enabled, routeName: enabled ? "Speaker" : "Receiver")
        } catch {
            print("[AudioDeviceManager] Set speaker error: \(error)")
        }
    }
    
    @discardableResult
    func toggleSpeaker() -> Bool {
        let target = !self.speakerState
        setSpeaker(enabled: target)
        return self.speakerState
    }
    
    private func notifyRouteUpdated(isSpeaker: Bool, routeName: String) {
        if Thread.isMainThread {
            self.isSpeakerOn = isSpeaker
            self.currentRouteName = routeName
        } else {
            DispatchQueue.main.async {
                self.isSpeakerOn = isSpeaker
                self.currentRouteName = routeName
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("[AudioDeviceManager] External accessory connected")
            self.updateCurrentRoute()
        case .oldDeviceUnavailable:
            print("[AudioDeviceManager] Accessory disconnected, restoring: \(self.speakerState ? "Speaker" : "Receiver")")
            self.setSpeaker(enabled: self.speakerState)
        case .categoryChange, .routeConfigurationChange:
            self.updateCurrentRoute()
        default:
            self.updateCurrentRoute()
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
            print("[AudioDeviceManager] Audio interruption began")
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
            let isSpeaker = (output.portType == .builtInSpeaker)
            let name: String
            switch output.portType {
            case .builtInSpeaker:
                name = "Speaker"
            case .builtInReceiver:
                name = "Receiver"
            case .headphones, .headsetMic:
                name = "Headphones"
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                name = output.portName.isEmpty ? "Bluetooth" : output.portName
            default:
                name = output.portName
            }
            self.speakerState = isSpeaker
            self.notifyRouteUpdated(isSpeaker: isSpeaker, routeName: name)
        }
    }
}
