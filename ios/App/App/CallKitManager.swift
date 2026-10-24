import Foundation
import CallKit
import AVFoundation
import UIKit

@objc public protocol CallKitManagerDelegate: AnyObject {
    func callDidAnswer(uuid: UUID)
    func callDidEnd(uuid: UUID)
    func callDidMute(uuid: UUID, isMuted: Bool)
}

public class CallKitManager: NSObject, CXProviderDelegate {
    public static let shared = CallKitManager()
    
    private let callController = CXCallController()
    private var provider: CXProvider?
    public weak var delegate: CallKitManagerDelegate?
    public private(set) var activeCallUUID: UUID?
    
    private override init() {
        super.init()
        setupProvider()
    }
    
    private func setupProvider() {
        let configuration = CXProviderConfiguration(localizedName: "CallVexa")
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber, .generic]
        configuration.includesCallsInRecents = true
        
        let provider = CXProvider(configuration: configuration)
        provider.setDelegate(self, queue: nil)
        self.provider = provider
    }
    
    public func reportIncomingCall(uuid: UUID, callerName: String, handle: String, completion: ((Error?) -> Void)? = nil) {
        self.activeCallUUID = uuid
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.localizedCallerName = callerName.isEmpty ? "CallVexa Caller" : callerName
        update.hasVideo = false
        update.supportsDTMF = true
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        
        MainViewController.configureAudioSession()
        
        provider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                print("[CallKit] Error reporting incoming call: \(error)")
                self?.activeCallUUID = nil
            } else {
                print("[CallKit] Incoming call reported successfully: \(callerName)")
            }
            completion?(error)
        }
    }
    
    public func endCall(uuid: UUID) {
        let endAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endAction)
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKit] Error ending call: \(error)")
            }
        }
        if activeCallUUID == uuid {
            activeCallUUID = nil
        }
    }
    
    // MARK: - CXProviderDelegate
    public func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallKit] Answer action received")
        MainViewController.configureAudioSession()
        delegate?.callDidAnswer(uuid: action.callUUID)
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKit] End call action received")
        delegate?.callDidEnd(uuid: action.callUUID)
        if activeCallUUID == action.callUUID {
            activeCallUUID = nil
        }
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        delegate?.callDidMute(uuid: action.callUUID, isMuted: action.isMuted)
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session activated")
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKit] Audio session deactivated")
    }
}
