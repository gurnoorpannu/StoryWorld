import SwiftUI
import Photos

struct VideoResultSheet: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var saveStatus: String?

    var body: some View {
        NavigationStack {
            VStack {
                VideoPlayerView(url: videoURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let status = saveStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Your Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveToPhotos() }
                }
            }
        }
    }

    private func saveToPhotos() {
        saveStatus = "Saving..."
        Task {
            do {
                // Download video to temp file first
                let (localURL, _) = try await URLSession.shared.download(from: videoURL)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("storyworld_export.mp4")
                try? FileManager.default.removeItem(at: tempURL)
                try FileManager.default.moveItem(at: localURL, to: tempURL)

                // Use withCheckedThrowingContinuation for the completion-handler API
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                    }) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: AppError.generationFailed)
                        }
                    }
                }

                await MainActor.run { saveStatus = "Saved to Photos!" }
            } catch {
                await MainActor.run { saveStatus = "Save failed: \(error.localizedDescription)" }
            }
        }
    }
}
