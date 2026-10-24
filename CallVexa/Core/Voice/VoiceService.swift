import Foundation
import Combine
import AVFoundation
import CallKit
#if canImport(TwilioVoice)
import TwilioVoice
#endif

@MainActor
final class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()
    
    // Call state and metrics
    @Published var callState: CallState = .idle
    @Published var activeNumber: String = ""
    @Published var durationSeconds: Int = 0
    @Published var isMuted: Bool = false
    @Published var isSpeaker: Bool = false
    @Published var lastSummary: CallSummary? = nil
    @Published var lastDialedNumber: String = ""
    @Published var verifiedCallerId: String = ""
    
    // Internal references
    #if canImport(TwilioVoice)
    private var activeCall: Call? = nil
    private var activeCallInvite: CallInvite? = nil
    #endif
    
    private var durationTimer: AnyCancellable? = nil
    private var tokenRefreshTimer: AnyCancellable? = nil
    private var currentAuthId: String? = nil
    private var currentCallUUID: UUID? = nil
    
    struct CallSummary: Identifiable {
        let id = UUID()
        let number: String
        let durationSec: Int
        let status: String
        let date: Date
    }
    
    override private init() {
        super.init()
        CallKitManager.shared.delegate = self
        PushKitManager.shared.delegate = self
        fetchLastDialedNumber()
        fetchVerifiedCallerId()
    }
    
    // MARK: - Initial Server Sync
    
    func fetchLastDialedNumber() {
        Task {
            do {
                let res: VoiceLastNumberResponse = try await APIClient.shared.get("/api/voice/last-number")
                if let num = res.number, !num.isEmpty {
                    self.lastDialedNumber = num
                }
            } catch {
                // Ignore if offline
            }
        }
    }
    
    func fetchVerifiedCallerId() {
        Task {
            do {
                let res: SettingsResponse = try await APIClient.shared.get("/api/settings")
                if let cid = res.settings["caller_id"], !cid.isEmpty {
                    self.verifiedCallerId = cid
                }
            } catch {
                // Ignore
            }
        }
    }
    
    // MARK: - Voice Token Fetching
    
    private func fetchVoiceToken() async throws -> (token: String, ttl: Int) {
        let isAdmin = AuthSessionManager.shared.currentUser?.isAdmin ?? true
        let endpoint = isAdmin ? "/api/voice/token" : "/api/agent/token"
        let res: VoiceTokenResponse = try await APIClient.shared.postEmpty(endpoint)
        return (token: res.token, ttl: res.ttl ?? 300)
    }
    
    // MARK: - Outbound Call Flow
    
    func placeCall(to destination: String) async {
        let cleanE164 = PhoneNumberFormatter.normalizeE164(destination)
        guard PhoneNumberFormatter.isValidE164(cleanE164) else {
            self.callState = .failed(message: "Invalid phone number. Check the number and country code.")
            return
        }
        
        self.activeNumber = cleanE164
        self.lastDialedNumber = cleanE164
        self.callState = .authorizing
        self.durationSeconds = 0
        self.isMuted = false
        self.isSpeaker = false
        
        let isAdmin = AuthSessionManager.shared.currentUser?.isAdmin ?? true
        let authEndpoint = isAdmin ? "/api/voice/authorize" : "/api/agent/authorize"
        
        do {
            // 1. Server authorization: validates limits, spend, emergency stop, country allowlist
            let auth: VoiceAuthResponse = try await APIClient.shared.post(
                authEndpoint,
                body: VoiceAuthRequest(to: cleanE164)
            )
            self.currentAuthId = auth.authId
            
            // 2. Fetch fresh Twilio Voice token
            let (token, _) = try await fetchVoiceToken()
            
            // 3. Initiate CallKit outgoing call
            self.callState = .connecting
            let uuid = CallKitManager.shared.startOutgoingCall(handle: cleanE164)
            self.currentCallUUID = uuid
            CallKitManager.shared.reportOutgoingCallConnecting(uuid: uuid)
            
            // 4. Connect Twilio Voice SDK
            // CRITICAL: Send ONLY authId parameter. Never send destination number!
            #if canImport(TwilioVoice)
            let connectOptions = ConnectOptions(accessToken: token, delegate: self) { builder in
                builder.params = ["authId": auth.authId]
                builder.uuid = uuid
            }
            self.activeCall = TwilioVoiceSDK.connect(options: connectOptions)
            #else
            // Simulated development connect for environments without Twilio binary
            self.simulateCallFlow(uuid: uuid)
            #endif
            
        } catch let apiError as APIError {
            self.releaseStuckCall()
            self.callState = .failed(message: apiError.localizedDescription)
            if let uuid = self.currentCallUUID {
                CallKitManager.shared.reportCallEnded(uuid: uuid, reason: .failed)
            }
        } catch {
            self.releaseStuckCall()
            self.callState = .failed(message: error.localizedDescription)
            if let uuid = self.currentCallUUID {
                CallKitManager.shared.reportCallEnded(uuid: uuid, reason: .failed)
            }
        }
    }
    
    // Releases stuck queued call record on server
    private func releaseStuckCall() {
        Task {
            let isAdmin = AuthSessionManager.shared.currentUser?.isAdmin ?? true
            let cancelEndpoint = isAdmin ? "/api/voice/cancel" : "/api/agent/cancel"
            struct EmptyResp: Codable { let ok: Bool? }
            let _: EmptyResp? = try? await APIClient.shared.postEmpty(cancelEndpoint)
        }
    }
    
    // MARK: - In-Call Controls
    
    func toggleMute() {
        setMuted(!isMuted)
    }
    
    func setMuted(_ muted: Bool) {
        self.isMuted = muted
        #if canImport(TwilioVoice)
        activeCall?.isMuted = muted
        #endif
        if let uuid = currentCallUUID {
            CallKitManager.shared.setMuted(uuid: uuid, isMuted: muted)
        }
    }
    
    func sendDTMFDigit(_ digit: String) {
        guard callState.isConnected else { return }
        #if canImport(TwilioVoice)
        activeCall?.sendDigits(digit)
        #endif
    }
    
    func toggleSpeaker() {
        AudioDeviceManager.shared.toggleSpeaker()
        self.isSpeaker = AudioDeviceManager.shared.isSpeakerOn
    }
    
    func hangup() {
        self.callState = .disconnecting
        #if canImport(TwilioVoice)
        activeCall?.disconnect()
        #endif
        if let uuid = currentCallUUID {
            CallKitManager.shared.endCall(uuid: uuid)
        }
        endCallUI(status: "Completed")
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        durationSeconds = 0
        durationTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.durationSeconds += 1
            }
    }
    
    private func stopDurationTimer() {
        durationTimer?.cancel()
        durationTimer = nil
    }
    
    private func endCallUI(status: String) {
        stopDurationTimer()
        
        let dur = self.durationSeconds
        let num = self.activeNumber
        if !num.isEmpty {
            self.lastSummary = CallSummary(
                number: num,
                durationSec: dur,
                status: status,
                date: Date()
            )
        }
        
        #if canImport(TwilioVoice)
        self.activeCall = nil
        #endif
        self.isMuted = false
        self.callState = .completed(summary: "\(status) (\(DateFormatters.formatDuration(dur)))")
        
        if let uuid = currentCallUUID {
            CallKitManager.shared.reportCallEnded(uuid: uuid, reason: .remoteEnded)
            currentCallUUID = nil
        }
        
        releaseStuckCall()
    }
    
    #if !canImport(TwilioVoice)
    private func simulateCallFlow(uuid: UUID) {
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.callState = .ringing
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.callState = .connected
            CallKitManager.shared.reportOutgoingCallConnected(uuid: uuid)
            self.startDurationTimer()
        }
    }
    #endif
}

// MARK: - CallKitManagerDelegate

extension VoiceService: CallKitManagerDelegate {
    func callKitDidPerformStartCall(action: CXStartCallAction) {
        print("[VoiceService] CallKit performed start call")
    }
    
    func callKitDidPerformAnswerCall(action: CXAnswerCallAction) {
        print("[VoiceService] CallKit performed answer call")
        #if canImport(TwilioVoice)
        if let invite = activeCallInvite {
            let acceptOptions = AcceptOptions(callKitUUID: action.callUUID, delegate: self)
            activeCall = invite.accept(options: acceptOptions)
            activeCallInvite = nil
            self.callState = .connected
            startDurationTimer()
        }
        #endif
    }
    
    func callKitDidPerformEndCall(action: CXEndCallAction) {
        print("[VoiceService] CallKit performed end call")
        hangup()
    }
    
    func callKitDidPerformSetMuted(action: CXSetMutedCallAction) {
        self.isMuted = action.isMuted
        #if canImport(TwilioVoice)
        activeCall?.isMuted = action.isMuted
        #endif
    }
    
    func callKitDidReset() {
        hangup()
    }
}

// MARK: - PushKitManagerDelegate (Phase 2)

extension VoiceService: PushKitManagerDelegate {
    func pushKitDidReceiveIncomingCall(payload: [AnyHashable: Any], uuid: UUID) {
        print("[VoiceService] Received VoIP push payload: \(payload)")
        #if canImport(TwilioVoice)
        TwilioVoiceSDK.handleNotification(payload, delegate: self, delegateQueue: nil)
        #endif
    }
}

#if canImport(TwilioVoice)
// MARK: - Twilio CallDelegate

extension VoiceService: CallDelegate {
    nonisolated func callDidStartRinging(call: Call) {
        Task { @MainActor in
            self.callState = .ringing
        }
    }
    
    nonisolated func callDidConnect(call: Call) {
        Task { @MainActor in
            self.callState = .connected
            if let uuid = self.currentCallUUID {
                CallKitManager.shared.reportOutgoingCallConnected(uuid: uuid)
            }
            self.startDurationTimer()
        }
    }
    
    nonisolated func callDidFailToConnect(call: Call, error: Error) {
        Task { @MainActor in
            self.callState = .failed(message: error.localizedDescription)
            self.endCallUI(status: "Failed")
        }
    }
    
    nonisolated func callDidDisconnect(call: Call, error: Error?) {
        Task { @MainActor in
            self.endCallUI(status: error == nil ? "Completed" : "Disconnected")
        }
    }
}

// MARK: - Twilio NotificationDelegate

extension VoiceService: NotificationDelegate {
    nonisolated func callInviteReceived(callInvite: CallInvite) {
        Task { @MainActor in
            self.activeCallInvite = callInvite
            self.activeNumber = callInvite.from
            self.callState = .ringing
        }
    }
    
    nonisolated func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        Task { @MainActor in
            self.activeCallInvite = nil
            self.endCallUI(status: "Missed Call")
        }
    }
}
#endif
