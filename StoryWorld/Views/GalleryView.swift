import SwiftUI

struct GalleryView: View {
    @Binding var capturedFrames: [CapturedFrame]
    let videoService: VideoGenerationService

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrame: CapturedFrame?

    var body: some View {
        NavigationStack {
            Group {
                if capturedFrames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No captures yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Place characters in AR and tap the\ncamera button to capture frames")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(capturedFrames.reversed()) { frame in
                                GalleryThumbnail(frame: frame) {
                                    selectedFrame = frame
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedFrame) { frame in
                AnimateSheet(
                    frame: frame,
                    videoService: videoService
                )
            }
        }
    }
}

struct GalleryThumbnail: View {
    @ObservedObject var frame: CapturedFrame
    let onAnimate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: frame.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 140)
                .clipped()

            HStack {
                Text(frame.capturedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if frame.videoURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if frame.isAnimating {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Button {
                onAnimate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption2)
                    Text(frame.videoURL != nil ? "View / Re-animate" : "Animate")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(frame.isAnimating ? Color.gray : Color.blue, in: RoundedRectangle(cornerRadius: 0))
            }
            .disabled(frame.isAnimating)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}
