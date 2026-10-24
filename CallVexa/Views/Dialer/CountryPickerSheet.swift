import SwiftUI

struct CountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: CountryItem
    @State private var searchText: String = ""
    
    var filteredCountries: [CountryItem] {
        if searchText.isEmpty {
            return CountryDirectory.all
        }
        return CountryDirectory.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText) ||
            $0.dialCode.contains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cvTextMuted)
                    TextField("Search countries or dial codes…", text: $searchText)
                        .foregroundColor(.cvTextPrimary)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.cvTextMuted)
                        }
                    }
                }
                .padding(12)
                .background(Color.cvSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                List(filteredCountries) { country in
                    Button(action: {
                        selectedCountry = country
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(country.flag)
                                .font(.system(size: 24))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.cvTextPrimary)
                                
                                Text(country.code)
                                    .font(.system(size: 12))
                                    .foregroundColor(.cvTextSecondary)
                            }
                            
                            Spacer()
                            
                            Text(country.dialCode)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cvCyan)
                            
                            if selectedCountry.code == country.code {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.cvPrimaryLight)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.cvSurface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .cvBackground()
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.cvPrimaryLight)
                }
            }
        }
    }
}
