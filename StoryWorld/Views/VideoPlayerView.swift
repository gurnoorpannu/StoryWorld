import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView("Loading video...")
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
