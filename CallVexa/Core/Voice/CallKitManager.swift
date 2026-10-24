import Foundation
import CallKit
import AVFoundation

protocol CallKitManagerDelegate: AnyObject {
    func callKitDidPerformStartCall(action: CXStartCallAction)
    func callKitDidPerformAnswerCall(action: CXAnswerCallAction)
    func callKitDidPerformEndCall(action: CXEndCallAction)
    func callKitDidPerformSetMuted(action: CXSetMutedCallAction)
    func callKitDidReset()
}

final class CallKitManager: NSObject {
    static let shared = CallKitManager()
    
    weak var delegate: CallKitManagerDelegate?
    
    private let provider: CXProvider
    private let callController = CXCallController()
    
    private(set) var activeCallUUID: UUID?
    
    override private init() {
        let configuration = CXProviderConfiguration(localizedName: "CallVexa")
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportedHandleTypes = [.phoneNumber]
        configuration.ringtoneSound = "ringtone.caf"
        
        self.provider = CXProvider(configuration: configuration)
        super.init()
        self.provider.setDelegate(self, queue: nil)
    }
    
    // MARK: - Outgoing Call Flow
    
    func startOutgoingCall(handle: String) -> UUID {
        let uuid = UUID()
        self.activeCallUUID = uuid
        
        let callHandle = CXHandle(type: .phoneNumber, value: handle)
        let startAction = CXStartCallAction(call: uuid, handle: callHandle)
        startAction.isVideo = false
        
        let transaction = CXTransaction(action: startAction)
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKitManager] Request CXStartCallAction error: \(error.localizedDescription)")
            }
        }
        return uuid
    }
    
    func reportOutgoingCallConnecting(uuid: UUID) {
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: nil)
    }
    
    func reportOutgoingCallConnected(uuid: UUID) {
        provider.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    // MARK: - Incoming Call Flow (Phase 2)
    
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: @escaping (Error?) -> Void) {
        self.activeCallUUID = uuid
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.localizedCallerName = handle
        update.hasVideo = hasVideo
        update.supportsDTMF = true
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("[CallKitManager] reportNewIncomingCall error: \(error)")
            }
            completion(error)
        }
    }
    
    // MARK: - Ending / Muting Actions
    
    func endCall(uuid: UUID) {
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKitManager] CXEndCallAction request error: \(error)")
            }
        }
    }
    
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason = .remoteEnded) {
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        if self.activeCallUUID == uuid {
            self.activeCallUUID = nil
        }
    }
    
    func setMuted(uuid: UUID, isMuted: Bool) {
        let muteAction = CXSetMutedCallAction(call: uuid, muted: isMuted)
        let transaction = CXTransaction(action: muteAction)
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKitManager] CXSetMutedCallAction error: \(error)")
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        self.activeCallUUID = nil
        delegate?.callKitDidReset()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        AudioDeviceManager.shared.configureAudioSessionForCall()
        delegate?.callKitDidPerformStartCall(action: action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        AudioDeviceManager.shared.configureAudioSessionForCall()
        delegate?.callKitDidPerformAnswerCall(action: action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        AudioDeviceManager.shared.deactivateAudioSession()
        delegate?.callKitDidPerformEndCall(action: action)
        self.activeCallUUID = nil
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        delegate?.callKitDidPerformSetMuted(action: action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKitManager] CallKit didActivate audioSession")
        AudioDeviceManager.shared.configureAudioSessionForCall()
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKitManager] CallKit didDeactivate audioSession")
    }
}
