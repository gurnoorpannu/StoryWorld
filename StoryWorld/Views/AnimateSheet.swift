import SwiftUI

struct AnimateSheet: View {
    @ObservedObject var frame: CapturedFrame
    let imageUploader: ImageUploadService
    let imageEditService: ImageEditService
    let videoService: VideoGenerationService
    let cinematicStyleEnabled: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var animationPrompt = ""
    @State private var statusMessage = ""
    @State private var isGenerating = false
    @State private var showVideoResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview image
                Image(uiImage: frame.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                // Prompt input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Animation Prompt")
                        .font(.subheadline.bold())

                    TextField("Describe the motion...", text: $animationPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)

                    Text("e.g. \"The character walks forward, camera slowly orbits around\"")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                // Status
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }

                // Generate button
                Button {
                    generateAnimation()
                } label: {
                    HStack(spacing: 8) {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Image(systemName: "wand.and.stars")
                        Text(isGenerating ? "Generating..." : "Animate This Frame")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isGenerating || animationPrompt.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.gray : Color.blue,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(isGenerating || animationPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Animate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showVideoResult) {
                if let url = frame.videoURL {
                    VideoResultSheet(videoURL: url)
                }
            }
            .onAppear {
                if animationPrompt.isEmpty {
                    animationPrompt = "Gentle camera movement, character subtly animates, cinematic atmosphere"
                }
            }
        }
    }

    private func generateAnimation() {
        isGenerating = true
        frame.isAnimating = true
        statusMessage = "Uploading frame..."

        Task { @MainActor in
            do {
                // Step 1: Upload image if not already uploaded
                let imageURL: URL
                if let existing = frame.uploadedURL {
                    imageURL = existing
                } else {
                    let uploaded = try await imageUploader.upload(frame.image, falKey: Secrets.falKey)
                    frame.uploadedURL = uploaded
                    imageURL = uploaded
                }

                // Step 2 (optional): Cinematic stylization
                var finalImageURL = imageURL
                if cinematicStyleEnabled {
                    statusMessage = "Applying cinematic style..."
                    do {
                        let styledURL = try await imageEditService.stylizeFrame(imageURL: imageURL)
                        finalImageURL = styledURL
                    } catch {
                        print("AnimateSheet: Stylization failed, using original")
                    }
                }

                // Step 3: Generate video
                let videoURL = try await videoService.generateVideo(
                    fromImageURL: finalImageURL,
                    motionPrompt: animationPrompt
                ) { progress in
                    Task { @MainActor in
                        statusMessage = progress
                    }
                }

                frame.videoURL = videoURL
                frame.isAnimating = false
                isGenerating = false
                statusMessage = "Done!"
                showVideoResult = true

            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                isGenerating = false
                frame.isAnimating = false
                print("AnimateSheet: Error: \(error)")
            }
        }
    }
}
