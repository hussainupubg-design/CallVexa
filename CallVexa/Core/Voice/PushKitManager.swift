import Foundation
import PushKit
import CallKit

protocol PushKitManagerDelegate: AnyObject {
    func pushKitDidReceiveIncomingCall(payload: [AnyHashable: Any], uuid: UUID)
}

final class PushKitManager: NSObject, ObservableObject {
    static let shared = PushKitManager()
    
    weak var delegate: PushKitManagerDelegate?
    
    @Published var voipPushToken: String? = nil
    @Published var registrationStatus: String = "Initialized — Awaiting VoIP PushKit Token"
    @Published var lastPushReceivedDate: Date? = nil
    @Published var isPhase2ConfiguredOnServer: Bool = false
    
    private var pushRegistry: PKPushRegistry?
    
    override private init() {
        super.init()
    }
    
    func start() {
        // Run on main queue
        DispatchQueue.main.async {
            self.pushRegistry = PKPushRegistry(queue: .main)
            self.pushRegistry?.delegate = self
            self.pushRegistry?.desiredPushTypes = [.voIP]
            self.registrationStatus = "Requesting VoIP Credentials from Apple APNs…"
        }
    }
}

// MARK: - PKPushRegistryDelegate

extension PushKitManager: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = credentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        
        DispatchQueue.main.async {
            self.voipPushToken = token
            self.registrationStatus = "VoIP Token Active (\(token.prefix(8))…)"
            print("[PushKitManager] Received VoIP device token: \(token)")
        }
        
        // Notify server or Twilio of VoIP token registration when credentials available
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        DispatchQueue.main.async {
            self.voipPushToken = nil
            self.registrationStatus = "VoIP Token Invalidated"
        }
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        
        DispatchQueue.main.async {
            self.lastPushReceivedDate = Date()
        }
        
        let dict = payload.dictionaryPayload
        let callUUID = UUID()
        
        // Extract caller name or number from payload
        var caller = "Incoming Call"
        if let twilioFrom = dict["twi_from"] as? String {
            caller = twilioFrom
        } else if let aps = dict["aps"] as? [String: Any],
                  let alert = aps["alert"] as? [String: Any],
                  let body = alert["body"] as? String {
            caller = body
        }
        
        // CRITICAL APPLE REQUIREMENT: Always report incoming call to CallKit immediately
        CallKitManager.shared.reportIncomingCall(uuid: callUUID, handle: caller) { [weak self] error in
            if error == nil {
                self?.delegate?.pushKitDidReceiveIncomingCall(payload: dict, uuid: callUUID)
            }
            completion()
        }
    }
}
