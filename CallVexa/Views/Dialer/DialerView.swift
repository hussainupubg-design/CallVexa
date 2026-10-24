import SwiftUI

struct DialerView: View {
    @ObservedObject var voiceService = VoiceService.shared
    
    @State private var inputNumber: String = ""
    @State private var selectedCountry: CountryItem = CountryDirectory.defaultCountry()
    @State private var showCountryPicker: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header / Caller ID Bar
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "shield.checkmark.fill")
                            .foregroundColor(.cvGreen)
                            .font(.system(size: 13))
                        
                        Text(voiceService.verifiedCallerId.isEmpty
                             ? "Caller ID: Ready (Default Twilio)"
                             : "Caller ID: \(voiceService.verifiedCallerId)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cvTextSecondary)
                        
                        Spacer()
                        
                        if !voiceService.lastDialedNumber.isEmpty {
                            Button(action: {
                                inputNumber = voiceService.lastDialedNumber
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Redial")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cvPrimaryLight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cvPrimary.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                // Error Alert Banner (if failed)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cvRed.opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                }
                
                // Last Summary Card (after call finishes)
                if let summary = voiceService.lastSummary {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cvGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Call \(summary.status)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.cvTextPrimary)
                            Text("\(summary.number) • \(DateFormatters.formatDuration(summary.durationSec))")
                                .font(.system(size: 12))
                                .foregroundColor(.cvTextSecondary)
                        }
                        Spacer()
                        Button(action: {
                            voiceService.lastSummary = nil
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.cvTextMuted)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(12)
                    .background(Color.cvSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }
                
                // Number Display Area
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Country Selector Button
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 6) {
                                Text(selectedCountry.flag)
                                    .font(.system(size: 20))
                                Text(selectedCountry.dialCode)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cvCyan)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cvTextMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cvSurfaceElevated)
                            .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Formatted phone number text
                        Text(inputNumber.isEmpty ? "Enter Number" : inputNumber)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(inputNumber.isEmpty ? .cvTextMuted : .cvTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        
                        Spacer()
                        
                        // Backspace Button
                        if !inputNumber.isEmpty {
                            Button(action: {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                inputNumber.removeLast()
                            }) {
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.cvTextMuted)
                            }
                        } else {
                            // Paste helper
                            Button(action: {
                                if let pasteboard = UIPasteboard.general.string {
                                    inputNumber = pasteboard.filter { $0.isNumber || $0 == "+" }
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 16))
                                    .foregroundColor(.cvTextMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 54)
                }
                .padding(.vertical, 4)
                
                // 3x4 Keypad Grid
                VStack(spacing: 14) {
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
                        HStack(spacing: 24) {
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
                .padding(.vertical, 8)
                
                // Call Button
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
                            .frame(width: 76, height: 76)
                            .shadow(color: Color.cvGreen.opacity(0.4), radius: 16, x: 0, y: 6)
                        
                        Image(systemName: "phone.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .cvBackground()
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selectedCountry: $selectedCountry)
        }
        .fullScreenCover(isPresented: Binding(
            get: { voiceService.callState.isInCall },
            set: { _ in }
        )) {
            ActiveCallView()
        }
    }
}
