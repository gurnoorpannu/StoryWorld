import SwiftUI

@main
struct StoryWorldApp: App {
    init() {
        cleanupTempFiles()
    }

    var body: some Scene {
        WindowGroup {
            MainARView()
        }
    }

    /// Remove old StoryWorld temp files from previous sessions
    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let storyWorldFiles = files.filter {
            let name = $0.lastPathComponent
            return name.hasPrefix("storyworld_") || name.hasPrefix("model_") || name.hasPrefix("speech_")
        }

        for file in storyWorldFiles {
            try? FileManager.default.removeItem(at: file)
        }

        if !storyWorldFiles.isEmpty {
            print("StoryWorldApp: Cleaned up \(storyWorldFiles.count) temp files")
        }
    }
}
