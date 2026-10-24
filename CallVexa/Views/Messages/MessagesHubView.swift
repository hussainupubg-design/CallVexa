import SwiftUI
import PhotosUI

enum MessageTabType {
    case sms
    case whatsapp
    case broadcast
}

struct MessagesHubView: View {
    @State private var selectedTab: MessageTabType = .sms
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: "Messages", subtitle: "SMS & WhatsApp omni-channel inbox")
            
            // Channel Selector
            Picker("Channel", selection: $selectedTab) {
                Text("SMS").tag(MessageTabType.sms)
                Text("WhatsApp").tag(MessageTabType.whatsapp)
                Text("Broadcast").tag(MessageTabType.broadcast)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            switch selectedTab {
            case .sms:
                SMSInboxView()
            case .whatsapp:
                WhatsAppInboxView()
            case .broadcast:
                WhatsAppBroadcastView()
            }
        }
        .cvBackground()
    }
}

// MARK: - SMS Inbox View

struct SMSInboxView: View {
    @State private var conversations: [SMSConversation] = []
    @State private var isLoading: Bool = false
    @State private var selectedContact: String? = nil
    @State private var showNewSMS: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { showNewSMS = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("New SMS")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cvPrimaryLight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cvPrimary.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            if isLoading && conversations.isEmpty {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if conversations.isEmpty {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No SMS Conversations",
                    message: "Tap 'New SMS' to send an outbound text."
                )
                Spacer()
            } else {
                List(conversations) { conv in
                    Button(action: { selectedContact = conv.contact }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.cvSurfaceElevated)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "message.fill")
                                        .foregroundColor(.cvCyan)
                                        .font(.system(size: 16))
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(PhoneNumberFormatter.formatForDisplay(conv.contact))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.cvTextPrimary)
                                    Spacer()
                                    Text(DateFormatters.relativeTimestamp(conv.lastAt))
                                        .font(.system(size: 11))
                                        .foregroundColor(.cvTextMuted)
                                }
                                
                                Text(conv.lastBody ?? "No messages")
                                    .font(.system(size: 13))
                                    .foregroundColor(.cvTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.cvSurface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadConversations()
                }
            }
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedContact.map { IdentifiableString(id: $0) } },
            set: { selectedContact = $0?.id }
        )) { item in
            SMSThreadSheet(contactNumber: item.id)
        }
        .sheet(isPresented: $showNewSMS) {
            NewSMSSheet { to, body in
                await sendSMS(to: to, body: body)
            }
        }
        .task {
            await loadConversations()
        }
    }
    
    private func loadConversations() async {
        isLoading = true
        do {
            let res: SMSConversationsResponse = try await APIClient.shared.get("/api/sms/conversations")
            self.conversations = res.conversations
        } catch {
            print("Failed to load SMS conversations: \(error)")
        }
        isLoading = false
    }
    
    private func sendSMS(to: String, body: String) async -> Bool {
        do {
            struct SendResp: Codable { let ok: Bool; let sid: String? }
            let req = SMSSendRequest(to: to, body: body)
            let res: SendResp = try await APIClient.shared.post("/api/sms/send", body: req)
            if res.ok {
                await loadConversations()
                return true
            }
        } catch {
            print("Send SMS error: \(error)")
        }
        return false
    }
}

// Helper wrapper for sheets
struct IdentifiableString: Identifiable {
    let id: String
}

// MARK: - SMS Thread Sheet

struct SMSThreadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let contactNumber: String
    
    @State private var messages: [SMSMessage] = []
    @State private var messageInput: String = ""
    @State private var isLoading: Bool = false
    @State private var isSending: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                HStack {
                                    if !msg.isInbound { Spacer() }
                                    
                                    VStack(alignment: msg.isInbound ? .leading : .trailing, spacing: 4) {
                                        Text(msg.body)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(msg.isInbound ? Color.cvSurfaceElevated : Color.cvPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        
                                        Text(DateFormatters.shortTime.string(from: Date(timeIntervalSince1970: TimeInterval(msg.at) / 1000)))
                                            .font(.system(size: 10))
                                            .foregroundColor(.cvTextMuted)
                                    }
                                    
                                    if msg.isInbound { Spacer() }
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                
                // Composer
                HStack(spacing: 10) {
                    TextField("Type an SMS message…", text: $messageInput)
                        .foregroundColor(.cvTextPrimary)
                        .padding(10)
                        .background(Color.cvSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.cvBorder, lineWidth: 1)
                        )
                    
                    Button(action: {
                        let text = messageInput
                        messageInput = ""
                        Task {
                            isSending = true
                            let req = SMSSendRequest(to: contactNumber, body: text)
                            struct Resp: Codable { let ok: Bool }
                            let _: Resp? = try? await APIClient.shared.post("/api/sms/send", body: req)
                            await loadMessages()
                            isSending = false
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageInput.isEmpty ? .cvTextMuted : .cvPrimaryLight)
                    }
                    .disabled(messageInput.isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.cvSurfaceElevated)
            }
            .cvBackground()
            .navigationTitle(PhoneNumberFormatter.formatForDisplay(contactNumber))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.cvPrimaryLight)
                }
            }
            .task {
                await loadMessages()
            }
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        do {
            let res: SMSMessagesResponse = try await APIClient.shared.get("/api/sms/messages", query: ["contact": contactNumber])
            self.messages = res.messages
        } catch {
            print("Failed to load thread messages: \(error)")
        }
        isLoading = false
    }
}

// MARK: - New SMS Sheet

struct NewSMSSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSend: (String, String) async -> Bool
    
    @State private var to: String = ""
    @State private var bodyText: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Recipient") {
                    TextField("Phone number (+15551234567)", text: $to)
                        .keyboardType(.phonePad)
                }
                Section("Message Body") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                }
            }
            .scrollContentBackground(.hidden)
            .cvBackground()
            .navigationTitle("New SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        isSubmitting = true
                        Task {
                            let ok = await onSend(to, bodyText)
                            isSubmitting = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(to.isEmpty || bodyText.isEmpty || isSubmitting)
                    .foregroundColor(.cvPrimaryLight)
                }
            }
        }
    }
}

// MARK: - WhatsApp Inbox View

struct WhatsAppInboxView: View {
    @State private var conversations: [WhatsAppConversation] = []
    @State private var isLoading: Bool = false
    @State private var selectedContact: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 24hr Notice Banner
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.cvCyan)
                Text("Meta 24h Customer Window: inbound chat opens 24h session.")
                    .font(.system(size: 11))
                    .foregroundColor(.cvTextSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            if isLoading && conversations.isEmpty {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if conversations.isEmpty {
                EmptyStateView(
                    icon: "bubble.right.fill",
                    title: "No WhatsApp Threads",
                    message: "Customer WhatsApp chats will appear here automatically."
                )
                Spacer()
            } else {
                List(conversations) { conv in
                    Button(action: { selectedContact = conv.contact }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.cvGreen.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "bubble.left.fill")
                                        .foregroundColor(.cvGreen)
                                        .font(.system(size: 16))
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(PhoneNumberFormatter.formatForDisplay(conv.contact))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.cvTextPrimary)
                                    Spacer()
                                    Text(DateFormatters.relativeTimestamp(conv.lastAt))
                                        .font(.system(size: 11))
                                        .foregroundColor(.cvTextMuted)
                                }
                                
                                Text(conv.lastBody ?? "Media message")
                                    .font(.system(size: 13))
                                    .foregroundColor(.cvTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.cvSurface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadConversations()
                }
            }
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedContact.map { IdentifiableString(id: $0) } },
            set: { selectedContact = $0?.id }
        )) { item in
            WhatsAppThreadSheet(contactNumber: item.id)
        }
        .task {
            await loadConversations()
        }
    }
    
    private func loadConversations() async {
        isLoading = true
        do {
            let res: WhatsAppConversationsResponse = try await APIClient.shared.get("/api/whatsapp/conversations")
            self.conversations = res.conversations
        } catch {
            print("Failed to load WhatsApp conversations: \(error)")
        }
        isLoading = false
    }
}

// MARK: - WhatsApp Thread Sheet with Media Attachment

struct WhatsAppThreadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let contactNumber: String
    
    @State private var messages: [WhatsAppMessage] = []
    @State private var messageInput: String = ""
    @State private var isSending: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var uploadedMediaURL: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                HStack {
                                    if !msg.isInbound { Spacer() }
                                    
                                    VStack(alignment: msg.isInbound ? .leading : .trailing, spacing: 4) {
                                        if let mediaUrl = msg.mediaUrl, !mediaUrl.isEmpty {
                                            AsyncImage(url: URL(string: mediaUrl.hasPrefix("http") ? mediaUrl : "https://callvexa.us\(mediaUrl)")) { image in
                                                image.resizable().scaledToFit()
                                            } placeholder: {
                                                ProgressView().tint(.cvCyan)
                                            }
                                            .frame(maxWidth: 240, maxHeight: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        
                                        if let body = msg.body, !body.isEmpty {
                                            Text(body)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(msg.isInbound ? Color.cvSurfaceElevated : Color.cvGreen.opacity(0.85))
                                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        
                                        Text(DateFormatters.shortTime.string(from: Date(timeIntervalSince1970: TimeInterval(msg.at) / 1000)))
                                            .font(.system(size: 10))
                                            .foregroundColor(.cvTextMuted)
                                    }
                                    
                                    if msg.isInbound { Spacer() }
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(16)
                    }
                }
                
                // Composer with Photo Picker
                HStack(spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 20))
                            .foregroundColor(.cvCyan)
                            .padding(8)
                    }
                    .onChange(of: selectedPhotoItem) { item in
                        Task { await handleMediaSelection(item) }
                    }
                    
                    TextField("WhatsApp message…", text: $messageInput)
                        .foregroundColor(.cvTextPrimary)
                        .padding(10)
                        .background(Color.cvSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.cvBorder, lineWidth: 1)
                        )
                    
                    Button(action: {
                        let text = messageInput
                        let media = uploadedMediaURL
                        messageInput = ""
                        uploadedMediaURL = nil
                        Task {
                            isSending = true
                            let req = WhatsAppSendRequest(to: contactNumber, body: text, mediaUrl: media, mediaType: nil)
                            struct Resp: Codable { let ok: Bool }
                            let _: Resp? = try? await APIClient.shared.post("/api/whatsapp/send", body: req)
                            await loadMessages()
                            isSending = false
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor((messageInput.isEmpty && uploadedMediaURL == nil) ? .cvTextMuted : .cvGreen)
                    }
                    .disabled(messageInput.isEmpty && uploadedMediaURL == nil)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.cvSurfaceElevated)
            }
            .cvBackground()
            .navigationTitle("WhatsApp • \(PhoneNumberFormatter.formatForDisplay(contactNumber))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.cvPrimaryLight)
                }
            }
            .task {
                await loadMessages()
            }
        }
    }
    
    private func loadMessages() async {
        do {
            let res: WhatsAppMessagesResponse = try await APIClient.shared.get("/api/whatsapp/messages", query: ["contact": contactNumber])
            self.messages = res.messages
        } catch {
            print("Failed to load WhatsApp thread: \(error)")
        }
    }
    
    private func handleMediaSelection(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        do {
            let res: WhatsAppUploadResponse = try await APIClient.shared.uploadMedia(
                path: "/api/whatsapp/upload",
                fileData: data,
                fileName: "photo.jpg",
                mimeType: "image/jpeg"
            )
            self.uploadedMediaURL = res.url
        } catch {
            print("Upload failed: \(error)")
        }
    }
}

// MARK: - WhatsApp Broadcast View

struct WhatsAppBroadcastView: View {
    @State private var numbersText: String = ""
    @State private var bodyText: String = ""
    @State private var isSending: Bool = false
    @State private var statusMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Broadcast Template Messages")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.cvTextPrimary)
                
                Text("Send approved template broadcasts up to 500 recipients at once.")
                    .font(.system(size: 13))
                    .foregroundColor(.cvTextSecondary)
                
                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.cvGreen)
                        .padding(10)
                        .background(Color.cvGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recipients (Comma or newline separated, max 500)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cvTextSecondary)
                    
                    TextEditor(text: $numbersText)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color.cvSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.cvBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Broadcast Message (Max 1,000 characters)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cvTextSecondary)
                    
                    TextEditor(text: $bodyText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.cvSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color.cvBorder, lineWidth: 1)
                        )
                }
                
                CallVexaButton(
                    title: "Send WhatsApp Broadcast",
                    icon: "megaphone.fill",
                    variant: .primary,
                    isLoading: isSending
                ) {
                    executeBroadcast()
                }
            }
            .padding(16)
        }
    }
    
    private func executeBroadcast() {
        let rawNumbers = numbersText.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !rawNumbers.isEmpty && !bodyText.isEmpty else { return }
        isSending = true
        statusMessage = nil
        
        Task {
            struct BroadcastResp: Codable { let ok: Bool; let sent: Int? }
            let req = WhatsAppBroadcastRequest(numbers: rawNumbers, body: bodyText, useTemplate: true)
            do {
                let res: BroadcastResp = try await APIClient.shared.post("/api/whatsapp/broadcast", body: req)
                if res.ok {
                    statusMessage = "Broadcast triggered successfully."
                    numbersText = ""
                    bodyText = ""
                }
            } catch {
                statusMessage = "Broadcast failed: \(error.localizedDescription)"
            }
            isSending = false
        }
    }
}
