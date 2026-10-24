import SwiftUI

struct LeadsView: View {
    @ObservedObject var voiceService = VoiceService.shared
    
    @State private var leads: [Lead] = []
    @State private var niches: [String] = []
    @State private var selectedNiche: String = "Roofing"
    @State private var cityInput: String = "Austin, TX"
    @State private var maxLeads: Double = 20
    @State private var isSearching: Bool = false
    @State private var searchProgressText: String? = nil
    @State private var showSearchSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: "Lead Finder", subtitle: "Targeted outbound prospecting & lead lists") {
                Button(action: { showSearchSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Find Leads")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cvPrimary)
                    .clipShape(Capsule())
                }
            }
            
            // Search Progress Banner
            if let prog = searchProgressText {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8).tint(.cvCyan)
                    Text(prog)
                        .font(.system(size: 12))
                        .foregroundColor(.cvCyan)
                    Spacer()
                }
                .padding(10)
                .background(Color.cvCyan.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            if leads.isEmpty {
                EmptyStateView(
                    icon: "person.3.sequence.fill",
                    title: "No Leads Discovered",
                    message: "Tap 'Find Leads' to search by business niche and city."
                )
                Spacer()
            } else {
                List {
                    ForEach(leads) { lead in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.cvSurfaceElevated)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "briefcase.fill")
                                        .foregroundColor(.cvCyan)
                                        .font(.system(size: 16))
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lead.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cvTextPrimary)
                                
                                HStack(spacing: 6) {
                                    Text(PhoneNumberFormatter.formatForDisplay(lead.phone))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.cvTextSecondary)
                                    
                                    if lead.isContacted {
                                        Text("• Contacted")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.cvGreen)
                                    }
                                }
                                
                                if let address = lead.address, !address.isEmpty {
                                    Text(address)
                                        .font(.system(size: 11))
                                        .foregroundColor(.cvTextMuted)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            // Direct Tap-to-Call Lead Button
                            Button(action: {
                                Task {
                                    await voiceService.placeCall(to: lead.phone)
                                    await markContacted(lead.id)
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.cvGreen)
                                    .font(.system(size: 14))
                                    .padding(10)
                                    .background(Color.cvGreen.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.cvSurface)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadLeads()
                }
            }
        }
        .cvBackground()
        .sheet(isPresented: $showSearchSheet) {
            LeadSearchSheet(
                niches: niches,
                selectedNiche: $selectedNiche,
                cityInput: $cityInput,
                maxLeads: $maxLeads
            ) {
                startLeadSearch()
            }
        }
        .task {
            await loadNiches()
            await loadLeads()
        }
    }
    
    private func loadNiches() async {
        do {
            let res: LeadNichesResponse = try await APIClient.shared.get("/api/leads/niches")
            self.niches = res.niches
            if let first = res.niches.first {
                self.selectedNiche = first
            }
        } catch {
            print("Failed to load niches: \(error)")
        }
    }
    
    private func loadLeads() async {
        do {
            let res: LeadsResponse = try await APIClient.shared.get("/api/leads")
            self.leads = res.leads
        } catch {
            print("Failed to load leads: \(error)")
        }
    }
    
    private func startLeadSearch() {
        showSearchSheet = false
        isSearching = true
        searchProgressText = "Searching for \(selectedNiche) in \(cityInput)…"
        
        Task {
            do {
                struct SearchResp: Codable { let ok: Bool; let started: Bool? }
                let req = LeadSearchRequest(niche: selectedNiche, city: cityInput, max: Int(maxLeads))
                let _: SearchResp = try await APIClient.shared.post("/api/leads/find", body: req)
                
                // Poll status for up to 20 seconds
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    let status: LeadJobStatusResponse = try await APIClient.shared.get("/api/leads/status")
                    if status.running != true {
                        break
                    }
                }
                await loadLeads()
                searchProgressText = nil
            } catch {
                searchProgressText = "Search completed or queued."
                await loadLeads()
            }
            isSearching = false
        }
    }
    
    private func markContacted(_ id: Int) async {
        do {
            struct MarkResp: Codable { let ok: Bool }
            let req = ["ids": [id]]
            let _: MarkResp = try await APIClient.shared.post("/api/leads/contacted", body: req)
            await loadLeads()
        } catch {
            print("Mark contacted error: \(error)")
        }
    }
}

// MARK: - Lead Search Sheet

struct LeadSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let niches: [String]
    @Binding var selectedNiche: String
    @Binding var cityInput: String
    @Binding var maxLeads: Double
    let onSearch: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Target Business Niche") {
                    Picker("Niche", selection: $selectedNiche) {
                        ForEach(niches.isEmpty ? ["Roofing", "Plumbing", "HVAC", "Legal"] : niches, id: \.self) { niche in
                            Text(niche).tag(niche)
                        }
                    }
                }
                
                Section("City / Region") {
                    TextField("e.g. Austin, TX", text: $cityInput)
                }
                
                Section("Lead Limit: \(Int(maxLeads))") {
                    Slider(value: $maxLeads, in: 10...50, step: 5)
                }
            }
            .scrollContentBackground(.hidden)
            .cvBackground()
            .navigationTitle("New Lead Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Search") {
                        onSearch()
                    }
                    .disabled(cityInput.isEmpty)
                    .foregroundColor(.cvPrimaryLight)
                }
            }
        }
    }
}
