import SwiftUI
import AVFoundation

struct VoicemailsView: View {
    @State private var voicemails: [Voicemail] = []
    @State private var isLoading: Bool = false
    @State private var currentPlayingId: Int? = nil
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(title: "Voicemails", subtitle: "Recorded messages when no agent was available") {
                Button(action: {
                    Task { await loadVoicemails() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cvPrimaryLight)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            
            if isLoading && voicemails.isEmpty {
                Spacer()
                ProgressView().tint(.cvPrimaryLight)
                Spacer()
            } else if voicemails.isEmpty {
                EmptyStateView(
                    icon: "recordingtape",
                    title: "No Voicemails",
                    message: "Customer voicemails and recordings will appear here."
                )
                Spacer()
            } else {
                List(voicemails) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle()
                                .fill(Color.cvAmber.opacity(0.15))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(.cvAmber)
                                        .font(.system(size: 15))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PhoneNumberFormatter.formatForDisplay(item.fromNumber ?? "Unknown Caller"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.cvTextPrimary)
                                
                                HStack(spacing: 8) {
                                    if let dur = item.durationSec {
                                        Text(DateFormatters.formatDuration(dur))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(.cvCyan)
                                    }
                                    
                                    Text("• \(DateFormatters.formatTimestamp(item.createdAt))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.cvTextSecondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Playback Controls
                        if let audioURL = item.audioStreamURL {
                            HStack(spacing: 12) {
                                Button(action: {
                                    togglePlayback(for: item, url: audioURL)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: (currentPlayingId == item.id && isPlaying) ? "pause.fill" : "play.fill")
                                            .font(.system(size: 14))
                                        Text((currentPlayingId == item.id && isPlaying) ? "Pause" : "Play Recording")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.cvPrimary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                Spacer()
                            }
                            .padding(.top, 4)
                        } else {
                            Text("Audio file processing…")
                                .font(.system(size: 11))
                                .foregroundColor(.cvTextMuted)
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.cvSurface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await loadVoicemails()
                }
            }
        }
        .cvBackground()
        .task {
            await loadVoicemails()
        }
        .onDisappear {
            stopAudio()
        }
    }
    
    private func loadVoicemails() async {
        isLoading = true
        do {
            let res: VoicemailsResponse = try await APIClient.shared.get("/api/admin/voicemails")
            self.voicemails = res.voicemails
        } catch {
            print("Failed to load voicemails: \(error)")
        }
        isLoading = false
    }
    
    private func togglePlayback(for item: Voicemail, url: URL) {
        if currentPlayingId == item.id && isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            stopAudio()
            currentPlayingId = item.id
            player = AVPlayer(url: url)
            player?.play()
            isPlaying = true
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                self.isPlaying = false
                self.currentPlayingId = nil
            }
        }
    }
    
    private func stopAudio() {
        player?.pause()
        player = nil
        isPlaying = false
        currentPlayingId = nil
    }
}
