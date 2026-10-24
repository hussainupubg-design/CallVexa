import SwiftUI

struct AgentWorkstationView: View {
    @ObservedObject var voiceService = VoiceService.shared
    @ObservedObject var authManager = AuthSessionManager.shared
    @ObservedObject var historyManager = CallHistoryManager.shared
    
    @State private var inputNumber: String = ""
    @State private var selectedCountry: CountryItem = CountryDirectory.defaultCountry()
    @State private var showCountryPicker: Bool = false
    @State private var showConfigSheet: Bool = false
    
    // Queue state
    @State private var queueSize: Int = 0
    @State private var isAnsweringQueue: Bool = false
    @State private var queueMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Agent Header Status
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Agent Workstation")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.cvTextPrimary)
                            
                            // Online Pulsing Dot
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.cvGreen)
                                    .frame(width: 8, height: 8)
                                Text("Online")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cvGreen)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cvGreen.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        Text("Ready for inbound calls • Presence broadcasting")
                            .font(.system(size: 12))
                            .foregroundColor(.cvTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showConfigSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.cvTextMuted)
                            .font(.system(size: 18))
                            .padding(8)
                            .background(Color.cvSurface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Live Queue Monitor Card
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "person.line.dotted.person.fill")
                            .foregroundColor(.cvCyan)
                            .font(.system(size: 16))
                        
                        Text("Inbound Call Queue")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cvTextPrimary)
                        
                        Spacer()
                        
                        Text("\(queueSize) waiting")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(queueSize > 0 ? .cvAmber : .cvTextMuted)
                    }
                    
                    if let msg = queueMessage {
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cvCyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button(action: {
                        answerNextInQueue()
                    }) {
                        HStack(spacing: 8) {
                            if isAnsweringQueue {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "phone.arrow.down.left.fill")
                            }
                            Text(queueSize > 0 ? "Pick Up Next Caller (\(queueSize))" : "Answer Next in Queue")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(queueSize > 0 ? Color.cvAmber : Color.cvSurfaceHighlight)
                        .foregroundColor(queueSize > 0 ? Color.cvBackground : Color.cvTextPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isAnsweringQueue)
                }
                .cvCard(padding: 14)
                .padding(.horizontal, 16)
                
                // Active / Stuck Call Alert Banner
                if case .failed(let message) = voiceService.callState {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.cvRed)
                        Text(message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cvRed)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.cvRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
                
                // Number Entry & Display Area
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 4) {
                                Text(selectedCountry.flag)
                                    .font(.system(size: 18))
                                Text(selectedCountry.dialCode)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.cvCyan)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.cvTextMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cvSurfaceElevated)
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Text(inputNumber.isEmpty ? "Enter Destination" : inputNumber)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(inputNumber.isEmpty ? .cvTextMuted : .cvTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Spacer()
                        
                        if !inputNumber.isEmpty {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                inputNumber.removeLast()
                            }) {
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.cvTextMuted)
                            }
                        } else if !voiceService.lastDialedNumber.isEmpty {
                            Button(action: { inputNumber = voiceService.lastDialedNumber }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Redial")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cvPrimaryLight)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                }
                
                // 3x4 Keypad Grid
                VStack(spacing: 12) {
                    let keys: [(digit: String, sub: String)] = [
                        ("1", ""), ("2", "ABC"), ("3", "DEF"),
                        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
                        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
                        ("*", ""), ("0", "+"), ("#", "")
                    ]
                    
                    let chunks = stride(from: 0, to: keys.count, by: 3).map {
                        Array(keys[$0..<min($0 + 3, keys.count)])
                    }
                    
                    ForEach(chunks.indices, id: \.self) { rowIndex in
                        HStack(spacing: 22) {
                            ForEach(chunks[rowIndex], id: \.digit) { item in
                                KeypadButton(
                                    digit: item.digit,
                                    subtext: item.sub,
                                    action: { key in
                                        inputNumber.append(key)
                                    },
                                    onLongPress: item.digit == "0" ? {
                                        inputNumber.append("+")
                                    } : nil
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Main Call Action Button
                Button(action: {
                    guard !inputNumber.isEmpty else { return }
                    let destination = inputNumber.hasPrefix("+") ? inputNumber : "\(selectedCountry.dialCode)\(inputNumber)"
                    Task {
                        await voiceService.placeCall(to: destination)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.cvGreen, Color.cvGreenLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.cvGreen.opacity(0.4), radius: 14, x: 0, y: 6)
                        
                        Image(systemName: "phone.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 4)
                
                // Recent Agent Calls
                let recent = historyManager.recentCalls(limit: 5)
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent Calls")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.cvTextPrimary)
                            Spacer()
                            Text("\(recent.count) calls")
                                .font(.system(size: 11))
                                .foregroundColor(.cvTextMuted)
                        }
                        
                        VStack(spacing: 8) {
                            ForEach(recent) { call in
                                HStack {
                                    Image(systemName: call.isSuccess ? "phone.arrow.up.right.fill" : "phone.down.fill")
                                        .foregroundColor(call.isSuccess ? .cvGreen : .cvRed)
                                        .font(.system(size: 13))
                                    
                                    Text(PhoneNumberFormatter.formatForDisplay(call.toNumber))
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.cvTextPrimary)
                                    
                                    Spacer()
                                    
                                    if let dur = call.duration, dur > 0 {
                                        Text(DateFormatters.formatDuration(dur))
                                            .font(.system(size: 12))
                                            .foregroundColor(.cvTextSecondary)
                                    }
                                    
                                    Button(action: {
                                        inputNumber = call.toNumber
                                    }) {
                                        Image(systemName: "phone.fill")
                                            .foregroundColor(.cvGreen)
                                            .font(.system(size: 12))
                                            .padding(6)
                                            .background(Color.cvGreen.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                if call.id != recent.last?.id {
                                    Divider().background(Color.cvBorder)
                                }
                            }
                        }
                        .cvCard(padding: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                AttributionFooter()
            }
        }
        .cvBackground()
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selectedCountry: $selectedCountry)
        }
        .sheet(isPresented: $showConfigSheet) {
            AgentConfigSheet()
        }
        .fullScreenCover(isPresented: Binding(
            get: { voiceService.callState.isInCall },
            set: { _ in }
        )) {
            ActiveCallView()
        }
        .task {
            await pollQueueSize()
            await loadRecentCalls()
            startPeriodicQueuePolling()
        }
    }
    
    // MARK: - Queue Actions
    
    private func pollQueueSize() async {
        do {
            struct QueueSizeResp: Codable { let ok: Bool; let size: Int? }
            let res: QueueSizeResp = try await APIClient.shared.get("/api/agent/queue-size")
            self.queueSize = res.size ?? 0
        } catch {
            // Queue polling is best-effort
        }
    }
    
    private func answerNextInQueue() {
        isAnsweringQueue = true
        queueMessage = "Connecting you to next caller…"
        Task {
            do {
                struct AnsResp: Codable { let ok: Bool }
                let _: AnsResp = try await APIClient.shared.postEmpty("/api/agent/answer-queue")
                queueMessage = "Connected to incoming caller."
                await pollQueueSize()
            } catch let apiError as APIError {
                queueMessage = apiError.errorCode == "queue_empty" ? "No callers waiting in queue." : apiError.localizedDescription
            } catch {
                queueMessage = "Queue pickup error: \(error.localizedDescription)"
            }
            isAnsweringQueue = false
        }
    }
    
    private func startPeriodicQueuePolling() {
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task {
                await pollQueueSize()
            }
        }
    }
    
    private func loadRecentCalls() async {
        historyManager.loadFromStorage()
        do {
            struct AgentCallsResp: Codable {
                let ok: Bool
                let rows: [AgentCallRecord]?
            }
            let res: AgentCallsResp = try await APIClient.shared.get("/api/agent/calls", query: ["limit": "10"])
            if let rows = res.rows, !rows.isEmpty {
                let mapped = rows.map { r in
                    CallRecord(
                        id: r.id,
                        toNumber: r.toNumber,
                        status: r.status,
                        duration: r.durationSec,
                        country: nil,
                        direction: "outbound",
                        createdAt: r.createdAt
                    )
                }
                historyManager.mergeServerCalls(mapped)
            }
        } catch {
            // Best effort
        }
    }
}

// MARK: - Agent Call Record Model

struct AgentCallRecord: Identifiable, Codable {
    let id: Int
    let toNumber: String
    let status: String
    let durationSec: Int?
    let createdAt: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case toNumber = "to_number"
        case status
        case durationSec = "duration_sec"
        case createdAt = "created_at"
    }
    
    var isSuccess: Bool {
        let s = status.lowercased()
        return s == "completed" || s == "answered"
    }
}

// MARK: - Agent Config Sheet (Optional, non-blocking)

struct AgentConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager = AuthSessionManager.shared
    
    @State private var email: String = "agent@callvexa.us"
    @State private var password: String = ""
    @State private var statusMsg: String? = nil
    @State private var isSyncing: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Active Agent Account") {
                    HStack {
                        Text("Current Identity")
                        Spacer()
                        Text(authManager.currentUser?.displayName ?? "CallVexa Agent")
                            .foregroundColor(.cvCyan)
                            .bold()
                    }
                    HStack {
                        Text("Role")
                        Spacer()
                        Text("Call Center Agent")
                            .foregroundColor(.cvTextSecondary)
                    }
                }
                
                Section("Live Server Sync (Optional)") {
                    Text("The app is already open and running. If you want to connect to a specific Agent login on callvexa.us, enter it below:")
                        .font(.system(size: 12))
                        .foregroundColor(.cvTextSecondary)
                    
                    TextField("Agent Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Agent Password", text: $password)
                    
                    if let msg = statusMsg {
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundColor(.cvCyan)
                    }
                    
                    Button("Sync with Server") {
                        syncWithServer()
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSyncing)
                }
                
                Section("About") {
                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("CallVexa iOS Native")
                            .foregroundColor(.cvTextMuted)
                    }
                    HStack {
                        Text("Credit")
                        Spacer()
                        Text("Made by Hussain")
                            .foregroundColor(.cvPrimaryLight)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .cvBackground()
            .navigationTitle("Agent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cvPrimaryLight)
                }
            }
        }
    }
    
    private func syncWithServer() {
        isSyncing = true
        statusMsg = "Connecting…"
        Task {
            let success = await authManager.loginAgent(email: email, password: password)
            if success {
                statusMsg = "Successfully linked to \(email)!"
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            } else {
                statusMsg = authManager.errorMessage ?? "Could not connect to server."
            }
            isSyncing = false
        }
    }
}
