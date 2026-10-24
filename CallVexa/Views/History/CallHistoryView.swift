import SwiftUI

struct CallHistoryView: View {
    @ObservedObject var voiceService = VoiceService.shared
    
    @State private var calls: [CallRecord] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var searchQuery: String = ""
    @State private var selectedStatus: String = ""
    @State private var page: Int = 0
    @State private var totalCalls: Int = 0
    
    let statuses = [
        ("All", ""),
        ("Completed", "completed"),
        ("Answered", "answered"),
        ("Busy", "busy"),
        ("No Answer", "no-answer"),
        ("Failed", "failed")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: "Call History", subtitle: "Real call records from your cloud account") {
                Button(action: {
                    Task { await loadCalls() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cvPrimaryLight)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            // Search and Status Filters
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cvTextMuted)
                    TextField("Search phone numbers…", text: $searchQuery)
                        .foregroundColor(.cvTextPrimary)
                        .onSubmit {
                            Task { await loadCalls() }
                        }
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            Task { await loadCalls() }
                        }) {
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
                                Task { await loadCalls() }
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
            if isLoading && calls.isEmpty {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if calls.isEmpty {
                EmptyStateView(
                    icon: "phone.badge.clock",
                    title: "No Calls Recorded",
                    message: "Completed and attempted calls will appear here in real-time."
                )
                Spacer()
            } else {
                List {
                    ForEach(calls) { call in
                        HStack(spacing: 12) {
                            // Status Icon
                            ZStack {
                                Circle()
                                    .fill(call.isSuccess ? Color.cvGreen.opacity(0.15) : Color.cvRed.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: call.isSuccess ? "phone.arrow.up.right.fill" : "phone.down.circle.fill")
                                    .foregroundColor(call.isSuccess ? .cvGreen : .cvRed)
                                    .font(.system(size: 16))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(PhoneNumberFormatter.formatForDisplay(call.toNumber))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cvTextPrimary)
                                
                                HStack(spacing: 6) {
                                    if let country = call.country {
                                        Text(country)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.cvCyan)
                                    }
                                    
                                    if let dur = call.duration {
                                        Text("• \(DateFormatters.formatDuration(dur))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.cvTextSecondary)
                                    }
                                    
                                    if let price = call.price, price > 0 {
                                        Text("• $\(String(format: "%.3f", price))")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.cvTextMuted)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Call Action Button
                            Button(action: {
                                Task {
                                    await voiceService.placeCall(to: call.toNumber)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.cvGreen)
                                    .font(.system(size: 14))
                                    .padding(8)
                                    .background(Color.cvGreen.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.cvSurface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await deleteCall(call.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadCalls()
                }
            }
        }
        .cvBackground()
        .task {
            await loadCalls()
        }
    }
    
    private func loadCalls() async {
        isLoading = true
        errorMessage = nil
        do {
            var queryParams: [String: String] = [
                "page": String(page),
                "limit": "40"
            ]
            if !searchQuery.isEmpty { queryParams["q"] = searchQuery }
            if !selectedStatus.isEmpty { queryParams["status"] = selectedStatus }
            
            let res: CallsResponse = try await APIClient.shared.get("/api/calls", query: queryParams)
            self.calls = res.rows
            self.totalCalls = res.total ?? res.rows.count
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func deleteCall(_ id: Int) async {
        do {
            struct DeleteResp: Codable { let ok: Bool }
            let _: DeleteResp = try await APIClient.shared.delete("/api/calls/\(id)")
            calls.removeAll(where: { $0.id == id })
        } catch {
            print("Failed to delete call record: \(error)")
        }
    }
}
