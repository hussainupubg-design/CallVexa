import SwiftUI

struct ContactsView: View {
    @ObservedObject var voiceService = VoiceService.shared
    
    @State private var contacts: [Contact] = []
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""
    @State private var showAddContactSheet: Bool = false
    @State private var editingContact: Contact? = nil
    
    var filteredContacts: [Contact] {
        if searchQuery.isEmpty { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.phone.contains(searchQuery)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: "Contacts", subtitle: "Call center directory & address book") {
                Button(action: { showAddContactSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cvPrimaryLight)
                }
            }
            
            // Search Input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.cvTextMuted)
                TextField("Search by name or number…", text: $searchQuery)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            if isLoading && contacts.isEmpty {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if filteredContacts.isEmpty {
                EmptyStateView(
                    icon: "person.crop.circle.badge.plus",
                    title: "No Contacts Found",
                    message: searchQuery.isEmpty ? "Tap '+' to add your first customer contact." : "No contacts match '\(searchQuery)'."
                )
                Spacer()
            } else {
                List {
                    ForEach(filteredContacts) { contact in
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.cvSurfaceElevated)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(contact.name.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.cvCyan)
                                )
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(contact.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cvTextPrimary)
                                
                                Text(PhoneNumberFormatter.formatForDisplay(contact.phone))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.cvTextSecondary)
                                
                                if let notes = contact.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(size: 11))
                                        .foregroundColor(.cvTextMuted)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            // Call Contact Button
                            Button(action: {
                                Task {
                                    await voiceService.placeCall(to: contact.phone)
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
                        .padding(.vertical, 6)
                        .listRowBackground(Color.cvSurface)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingContact = contact
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deleteContact(contact.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadContacts()
                }
            }
        }
        .cvBackground()
        .sheet(isPresented: $showAddContactSheet) {
            ContactFormSheet(title: "Add Contact") { name, phone, notes in
                await addContact(name: name, phone: phone, notes: notes)
            }
        }
        .sheet(item: $editingContact) { contact in
            ContactFormSheet(
                title: "Edit Contact",
                initialName: contact.name,
                initialPhone: contact.phone,
                initialNotes: contact.notes ?? ""
            ) { name, phone, notes in
                await updateContact(id: contact.id, name: name, phone: phone, notes: notes)
            }
        }
        .task {
            await loadContacts()
        }
    }
    
    private func loadContacts() async {
        isLoading = true
        do {
            let res: ContactsResponse = try await APIClient.shared.get("/api/contacts")
            self.contacts = res.rows
        } catch {
            print("Error loading contacts: \(error)")
        }
        isLoading = false
    }
    
    private func addContact(name: String, phone: String, notes: String) async -> Bool {
        do {
            struct AddContactResp: Codable { let ok: Bool; let id: Int? }
            let input = ContactInput(name: name, phone: phone, country: "US", notes: notes)
            let res: AddContactResp = try await APIClient.shared.post("/api/contacts", body: input)
            if res.ok {
                await loadContacts()
                return true
            }
        } catch {
            print("Add contact error: \(error)")
        }
        return false
    }
    
    private func updateContact(id: Int, name: String, phone: String, notes: String) async -> Bool {
        do {
            struct UpdateContactResp: Codable { let ok: Bool }
            let input = ContactInput(name: name, phone: phone, country: "US", notes: notes)
            let res: UpdateContactResp = try await APIClient.shared.put("/api/contacts/\(id)", body: input)
            if res.ok {
                await loadContacts()
                return true
            }
        } catch {
            print("Update contact error: \(error)")
        }
        return false
    }
    
    private func deleteContact(_ id: Int) async {
        do {
            struct DelResp: Codable { let ok: Bool }
            let _: DelResp = try await APIClient.shared.delete("/api/contacts/\(id)")
            contacts.removeAll(where: { $0.id == id })
        } catch {
            print("Delete contact error: \(error)")
        }
    }
}

// MARK: - Contact Form Sheet

struct ContactFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    var initialName: String = ""
    var initialPhone: String = ""
    var initialNotes: String = ""
    let onSave: (String, String, String) async -> Bool
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting: Bool = false
    
    init(title: String, initialName: String = "", initialPhone: String = "", initialNotes: String = "", onSave: @escaping (String, String, String) async -> Bool) {
        self.title = title
        self.initialName = initialName
        self.initialPhone = initialPhone
        self.initialNotes = initialNotes
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _phone = State(initialValue: initialPhone)
        _notes = State(initialValue: initialNotes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Full Name", text: $name)
                    TextField("Phone (+15551234567)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Notes / Company", text: $notes)
                }
            }
            .scrollContentBackground(.hidden)
            .cvBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.cvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSubmitting = true
                        Task {
                            let ok = await onSave(name, phone, notes)
                            isSubmitting = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(name.isEmpty || phone.isEmpty || isSubmitting)
                    .foregroundColor(.cvPrimaryLight)
                }
            }
        }
    }
}
