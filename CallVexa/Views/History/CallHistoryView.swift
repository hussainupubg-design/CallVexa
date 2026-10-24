import SwiftUI

struct CallHistoryView: View {
    @ObservedObject var historyManager = CallHistoryManager.shared
    @ObservedObject var voiceService = VoiceService.shared
    
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""
    @State private var selectedStatus: String = ""
    @State private var showClearConfirm: Bool = false
    
    let statuses = [
        ("All", ""),
        ("Completed", "completed"),
        ("Answered", "answered"),
        ("Busy", "busy"),
        ("No Answer", "no-answer"),
        ("Failed", "failed")
    ]
    
    private var displayedCalls: [CallRecord] {
        historyManager.calls.filter { call in
            let matchesQuery = searchQuery.isEmpty ||
                call.toNumber.contains(searchQuery) ||
                (call.country?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                (call.startedAt?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            
            let matchesStatus: Bool
            if selectedStatus.isEmpty {
                matchesStatus = true
            } else if selectedStatus == "failed" {
                matchesStatus = call.isFailed
            } else {
                matchesStatus = call.status.lowercased() == selectedStatus.lowercased()
            }
            
            return matchesQuery && matchesStatus
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            PageHeaderView(
                title: "Call History",
                subtitle: "\(historyManager.calls.count) recorded call\(historyManager.calls.count == 1 ? "" : "s")"
            ) {
                HStack(spacing: 12) {
                    if !historyManager.calls.isEmpty {
                        Button(action: { showClearConfirm = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.cvTextMuted)
                                .font(.system(size: 15))
                        }
                    }
                    
                    Button(action: {
                        Task { await syncWithServer() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.cvPrimaryLight)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            
            // Search Bar & Filter Chips
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cvTextMuted)
                    TextField("Search phone numbers or dates…", text: $searchQuery)
                        .foregroundColor(.cvTextPrimary)
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.cvTextMuted)
                        }
                    }
                }
                .padding(10)
                .background(Color.cvSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Status Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(statuses, id: \.1) { (label, value) in
                            Button(action: {
                                selectedStatus = value
                            }) {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedStatus == value ? .white : .cvTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedStatus == value ? Color.cvPrimary : Color.cvSurfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Calls List
            if historyManager.calls.isEmpty && isLoading {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if displayedCalls.isEmpty {
                EmptyStateView(
                    icon: "phone.badge.clock",
                    title: historyManager.calls.isEmpty ? "No Calls Recorded" : "No Matching Calls",
                    message: historyManager.calls.isEmpty
                        ? "Every call made or received will automatically appear here with duration and one-tap redial."
                        : "Try clearing your search query or filter."
                )
                Spacer()
            } else {
                List {
                    ForEach(displayedCalls) { call in
                        HStack(spacing: 12) {
                            // Status Icon
                            ZStack {
                                Circle()
                                    .fill(call.isSuccess ? Color.cvGreen.opacity(0.15) : Color.cvRed.opacity(0.15))
                                    .frame(width: 42, height: 42)
                                Image(systemName: call.isSuccess ? "phone.arrow.up.right.fill" : "phone.down.circle.fill")
                                    .foregroundColor(call.isSuccess ? .cvGreen : .cvRed)
                                    .font(.system(size: 17))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(PhoneNumberFormatter.formatForDisplay(call.toNumber))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.cvTextPrimary)
                                
                                HStack(spacing: 6) {
                                    // Status Badge Text
                                    Text(call.status.capitalized)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(call.isSuccess ? .cvGreenLight : .cvRed)
                                    
                                    if let dur = call.duration, dur > 0 {
                                        Text("• \(DateFormatters.formatDuration(dur))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.cvTextSecondary)
                                    }
                                    
                                    if let started = call.startedAt, !started.isEmpty {
                                        Text("• \(started)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.cvTextMuted)
                                    } else if let created = call.createdAt {
                                        Text("• \(DateFormatters.relativeTimestamp(created))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.cvTextMuted)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // One-Tap Instant Redial Button
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                Task {
                                    await voiceService.placeCall(to: call.toNumber)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.cvGreen)
                                    .font(.system(size: 15))
                                    .padding(10)
                                    .background(Color.cvGreen.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.cvSurface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                historyManager.deleteCall(id: call.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await syncWithServer()
                }
            }
        }
        .cvBackground()
        .confirmationDialog(
            "Clear all call history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All Calls", role: .destructive) {
                historyManager.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            historyManager.loadFromStorage()
            await syncWithServer()
        }
    }
    
    private func syncWithServer() async {
        isLoading = true
        defer { isLoading = false }
        
        // 1. Try agent calls endpoint first
        do {
            struct AgentCallsResp: Codable {
                let ok: Bool
                let rows: [AgentCallRecord]?
            }
            let res: AgentCallsResp = try await APIClient.shared.get("/api/agent/calls", query: ["limit": "50"])
            if let agentRows = res.rows, !agentRows.isEmpty {
                let mapped = agentRows.map { r in
                    CallRecord(
                        id: r.id,
                        toNumber: r.toNumber,
                        status: r.status,
                        duration: r.durationSec,
                        country: nil,
                        direction: "outbound",
                        startedAt: r.createdAt != nil ? DateFormatters.formatTimestamp(r.createdAt!) : nil,
                        createdAt: r.createdAt
                    )
                }
                historyManager.mergeServerCalls(mapped)
                return
            }
        } catch {
            // Ignore and fall through to admin endpoint
        }
        
        // 2. Try admin calls endpoint
        do {
            let res: CallsResponse = try await APIClient.shared.get("/api/calls", query: ["limit": "50"])
            historyManager.mergeServerCalls(res.rows)
        } catch {
            // Offline or unauthenticated — local calls are safely preserved
        }
    }
}
