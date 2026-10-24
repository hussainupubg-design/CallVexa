import SwiftUI

struct ActiveCallView: View {
    @ObservedObject var voiceService = VoiceService.shared
    @State private var showKeypadOverlay: Bool = false
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        ZStack {
            Color.cvBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 20)
                
                // Top Indicator & Destination
                VStack(spacing: 8) {
                    StatusPill(
                        text: voiceService.callState.displayText.uppercased(),
                        color: voiceService.callState.statusColor
                    )
                    
                    Text(PhoneNumberFormatter.formatForDisplay(voiceService.activeNumber))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.cvTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if voiceService.callState.isConnected {
                        Text(DateFormatters.formatDuration(voiceService.durationSeconds))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.cvGreenLight)
                    } else {
                        Text("CallVexa Voice Engine")
                            .font(.system(size: 13))
                            .foregroundColor(.cvTextSecondary)
                    }
                }
                
                // Avatar with Animated Pulse
                ZStack {
                    if voiceService.callState.isConnected {
                        Circle()
                            .stroke(Color.cvGreen.opacity(0.2), lineWidth: 2)
                            .frame(width: 170, height: 170)
                            .scaleEffect(pulseAnimation ? 1.25 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: pulseAnimation)
                    }
                    
                    Circle()
                        .fill(Color.cvSurfaceElevated)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle().stroke(Color.cvBorder, lineWidth: 2)
                        )
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.cvTextMuted)
                }
                .onAppear {
                    pulseAnimation = true
                }
                
                Spacer()
                
                // In-Call DTMF Keypad (Collapsible)
                if showKeypadOverlay {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Touch-Tone Keypad (DTMF)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cvTextSecondary)
                            Spacer()
                            Button("Hide") {
                                showKeypadOverlay = false
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.cvPrimaryLight)
                        }
                        .padding(.horizontal, 16)
                        
                        let rows = [
                            ["1", "2", "3"],
                            ["4", "5", "6"],
                            ["7", "8", "9"],
                            ["*", "0", "#"]
                        ]
                        ForEach(rows, id: \.self) { row in
                            HStack(spacing: 16) {
                                ForEach(row, id: \.self) { key in
                                    Button(action: {
                                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                                        feedback.impactOccurred()
                                        voiceService.sendDTMFDigit(key)
                                    }) {
                                        Text(key)
                                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                                            .foregroundColor(.cvTextPrimary)
                                            .frame(width: 64, height: 48)
                                            .background(Color.cvSurfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.cvBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.cvSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Call Action Controls
                HStack(spacing: 28) {
                    // Mute Button
                    Button(action: { voiceService.toggleMute() }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(voiceService.isMuted ? Color.white : Color.cvSurfaceElevated)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: voiceService.isMuted ? "mic.slash.fill" : "mic.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(voiceService.isMuted ? Color.cvBackground : Color.cvTextPrimary)
                                )
                            Text(voiceService.isMuted ? "Muted" : "Mute")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                        }
                    }
                    
                    // DTMF Keypad Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showKeypadOverlay.toggle()
                        }
                    }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(showKeypadOverlay ? Color.cvPrimary : Color.cvSurfaceElevated)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "circle.grid.3x3.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                            Text("Keypad")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                        }
                    }
                    
                    // Speaker Button
                    Button(action: { voiceService.toggleSpeaker() }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(voiceService.isSpeaker ? Color.white : Color.cvSurfaceElevated)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: voiceService.isSpeaker ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(voiceService.isSpeaker ? Color.cvBackground : Color.cvTextPrimary)
                                )
                            Text(voiceService.isSpeaker ? "Speaker On" : "Speaker")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.cvTextSecondary)
                        }
                    }
                }
                
                // Big Red End Call Button
                Button(action: {
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.warning)
                    voiceService.hangup()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.cvRed)
                            .frame(width: 76, height: 76)
                            .shadow(color: Color.cvRed.opacity(0.4), radius: 16, x: 0, y: 6)
                        
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
    }
}
