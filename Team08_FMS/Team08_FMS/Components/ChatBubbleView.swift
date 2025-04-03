import SwiftUI
import AVFoundation

class AudioPlayer: ObservableObject {
    private var player: AVPlayer?
    private var currentURL: URL?
    @Published var isPlaying = false
    private var timeObserver: Any?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    func play(url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if currentURL != url {
                // New URL, create new player
                player = AVPlayer(url: url)
                currentURL = url
                setupTimeObserver()
                if let duration = player?.currentItem?.duration {
                    self.duration = CMTimeGetSeconds(duration)
                }
            }
            player?.play()
            isPlaying = true
            
            // Reset isPlaying when audio finishes
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.isPlaying = false
                self?.currentTime = 0
            }
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }
    }
    
    func stop() {
        player?.pause()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player = nil
        currentURL = nil
        isPlaying = false
        currentTime = 0
    }
    
    deinit {
        stop()
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var imageData: Data?
    @State private var isImageLoading = false
    @State private var isAnimating = false
    @StateObject private var supabaseController = SupabaseDataController.shared
    @State private var currentUserId: UUID?
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var showDeleteAlert = false
    var onDelete: () -> Void = {} // Default empty closure
    
    private var backgroundColor: Color {
        message.isFromCurrentUser ? ChatThemeColors.primary : Color(.systemGray6)
    }
    
    private var textColor: Color {
        message.isFromCurrentUser ? .white : .primary
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    // Fleet manager icon
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 24))
                        .padding(.trailing, 4)
                }
                
                VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                    if let attachmentUrl = message.attachment_url {
                        if message.attachment_type == "image/jpeg" {
                            // Image message
                            VStack(alignment: .leading, spacing: 4) {
                                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 200, maxHeight: 200)
                                        .cornerRadius(8)
                                } else {
                                    if isImageLoading {
                                        ProgressView()
                                            .frame(width: 200, height: 200)
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 200, height: 200)
                                            .cornerRadius(8)
                                            .onAppear {
                                                loadImage(from: attachmentUrl)
                                            }
                                    }
                                }
                            }
                            .padding(8)
                            .background(backgroundColor)
                            .cornerRadius(12)
                        } else if message.attachment_type == "audio/m4a" {
                            // Voice note message
                            Button(action: {
                                if let url = URL(string: attachmentUrl) {
                                    audioPlayer.play(url: url)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(textColor)
                                    
                                    if audioPlayer.duration > 0 {
                                        // Progress bar
                                        GeometryReader { geometry in
                                            ZStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(textColor.opacity(0.3))
                                                    .frame(height: 4)
                                                
                                                Rectangle()
                                                    .fill(textColor)
                                                    .frame(width: geometry.size.width * CGFloat(audioPlayer.currentTime / audioPlayer.duration), height: 4)
                                            }
                                        }
                                        .frame(height: 4)
                                        
                                        // Duration
                                        Text(formatDuration(audioPlayer.currentTime))
                                            .font(.caption)
                                            .foregroundColor(textColor)
                                            .frame(width: 40)
                                    } else {
                                        Text("Voice Note")
                                            .foregroundColor(textColor)
                                    }
                                }
                                .frame(width: 200)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(backgroundColor)
                                .cornerRadius(12)
                            }
                        } else {
                            // Text message with unknown attachment
                            Text(message.message_text)
                                .foregroundColor(textColor)
                                .padding(8)
                                .background(backgroundColor)
                                .cornerRadius(12)
                        }
                    } else {
                        // Regular text message
                        Text(message.message_text)
                            .foregroundColor(textColor)
                            .padding(8)
                            .background(backgroundColor)
                            .cornerRadius(12)
                    }
                    
                    HStack(spacing: 4) {
                        Text(formatDate(message.created_at))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        if message.isFromCurrentUser {
                            Group {
                                switch message.status {
                                case .sent:
                                    Image(systemName: "checkmark")
                                case .delivered:
                                    Image(systemName: "checkmark.circle")
                                case .read:
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showDeleteAlert = true
                }
                
                if message.isFromCurrentUser {
                    // Driver icon
                    Image(systemName: "car.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                        .padding(.leading, 4)
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .alert("Delete Message", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await supabaseController.supabase.database
                            .from("chat_messages")
                            .update(["is_deleted": true])
                            .eq("id", value: message.id)
                            .execute()
                        onDelete()
                    } catch {
                        print("Error deleting message: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this message?")
        }
        .onAppear {
            withAnimation(ChatBubbleAnimation.messageAppearance) {
                isAnimating = true
            }
            
            Task {
                currentUserId = await supabaseController.getUserID()
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        isImageLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.imageData = data
                    self.isImageLoading = false
                }
            } catch {
                print("Error loading image: \(error)")
                await MainActor.run {
                    self.isImageLoading = false
                }
            }
        }
    }
}

// Preview provider
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "Hello, this is a test message that's quite long to see how it wraps",
                status: .delivered,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: true
            ))
            
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "This is a response",
                status: .read,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: false
            ))
        }
        .padding()
    }
} 
