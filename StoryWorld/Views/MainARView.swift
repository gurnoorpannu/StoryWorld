import SwiftUI

struct MainARView: View {
    @StateObject private var arVM = ARSceneViewModel()
    @StateObject private var audioRecorder = AudioRecorder()

    @State private var showingVideoResult = false
    @State private var resultVideoURL: URL?
    @State private var statusMessage = ""
    @State private var isProcessing = false
    @State private var lastAudioData: Data?
    @State private var lastPrompt: CharacterPrompt?
    @State private var showOnboarding = true
    @State private var cinematicStyleEnabled = false

    // Services
    private let gemini = GeminiVoiceService(apiKey: Secrets.geminiKey)
    private let appleSpeech = AppleSpeechService()
    private let modelService = FalModelService(falKey: Secrets.falKey)
    private let conversion = ModelConversionService()
    private let imageUploader = ImageUploadService()
    private let imageEditService = ImageEditService(falKey: Secrets.falKey)
    private let videoService = VideoGenerationService(falKey: Secrets.falKey)

    var body: some View {
        ZStack {
            // Full-screen AR view
            ARViewContainer(viewModel: arVM)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top: status + tracking
                VStack(spacing: 4) {
                    if !arVM.trackingStatus.isEmpty {
                        statusPill(text: arVM.trackingStatus)
                    }
                    if !statusMessage.isEmpty {
                        statusPill(text: statusMessage)
                    }
                }
                .padding(.top, 60)

                Spacer()

                // Onboarding hint
                if showOnboarding && arVM.placedCharacters.isEmpty && !isProcessing {
                    VStack(spacing: 6) {
                        Text("Welcome to StoryWorld")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Tap the mic and describe a character.\nOr tap a surface to place a starter model.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
                    .onTapGesture { showOnboarding = false }
                }

                // Character count
                if !arVM.placedCharacters.isEmpty {
                    Text("\(arVM.placedCharacters.count) character\(arVM.placedCharacters.count == 1 ? "" : "s") placed")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 8)
                }

                // Cinematic style toggle
                Button {
                    cinematicStyleEnabled.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cinematicStyleEnabled ? "sparkles" : "sparkles")
                            .font(.caption2)
                        Text(cinematicStyleEnabled ? "Cinematic Style ON" : "Cinematic Style OFF")
                            .font(.caption2)
                    }
                    .foregroundStyle(cinematicStyleEnabled ? .yellow : .white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(isProcessing)
                .padding(.bottom, 8)

                // Bottom: control buttons
                HStack(spacing: 32) {
                    // Mic button
                    controlButton(
                        icon: audioRecorder.isRecording ? "mic.fill" : "mic",
                        size: 56,
                        color: audioRecorder.isRecording ? .red : .white,
                        foreground: audioRecorder.isRecording ? .white : .black
                    ) {
                        toggleRecording()
                    }
                    .disabled(isProcessing)

                    // Camera button
                    controlButton(
                        icon: "camera.fill",
                        size: 72,
                        color: .white,
                        foreground: .black
                    ) {
                        captureAndGenerateVideo()
                    }
                    .disabled(isProcessing || arVM.placedCharacters.isEmpty)
                    .opacity(isProcessing || arVM.placedCharacters.isEmpty ? 0.5 : 1.0)

                    // Trash button
                    controlButton(
                        icon: "trash",
                        size: 56,
                        color: .white,
                        foreground: .black
                    ) {
                        arVM.removeAllCharacters()
                        statusMessage = ""
                    }
                    .disabled(arVM.placedCharacters.isEmpty)
                    .opacity(arVM.placedCharacters.isEmpty ? 0.5 : 1.0)
                }
                .padding(.bottom, 40)
            }

            // Loading overlay
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .sheet(isPresented: $showingVideoResult) {
            if let url = resultVideoURL {
                VideoResultSheet(videoURL: url)
            }
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if audioRecorder.isRecording {
            let data = audioRecorder.stopRecording()
            guard let data = data else {
                statusMessage = "Recording failed — try again"
                return
            }
            lastAudioData = data
            showOnboarding = false
            processAudio(data)
        } else {
            audioRecorder.startRecording()
            statusMessage = "Listening... tap mic again when done"
            showOnboarding = false
        }
    }

    // MARK: - Voice → 3D → AR Pipeline

    private func processAudio(_ audioData: Data) {
        isProcessing = true
        statusMessage = "Understanding your voice..."

        Task { @MainActor in
            do {
                // Step 1: Gemini transcription + prompt enhancement
                let prompt: CharacterPrompt
                do {
                    prompt = try await gemini.extractCharacterPrompt(audioData: audioData)
                } catch {
                    // Fallback: use Apple Speech for transcription
                    print("MainARView: Gemini failed (\(error)), trying Apple Speech fallback")
                    statusMessage = "Gemini unavailable, using on-device speech..."
                    if let transcript = await appleSpeech.transcribeFromAudio(audioData),
                       !transcript.isEmpty {
                        prompt = CharacterPrompt(
                            raw_transcript: transcript,
                            optimized_3d_prompt: "A detailed 3D model of \(transcript), high quality, photorealistic",
                            motion_prompt: "Gentle camera movement, cinematic atmosphere, the subject subtly animates"
                        )
                    } else {
                        throw AppError.noResponse
                    }
                }

                lastPrompt = prompt
                print("MainARView: CharacterPrompt:")
                print("  raw_transcript: \(prompt.raw_transcript)")
                print("  optimized_3d_prompt: \(prompt.optimized_3d_prompt)")
                print("  motion_prompt: \(prompt.motion_prompt)")

                // Step 2: Generate 3D model via Rodin
                statusMessage = "Generating 3D: \"\(prompt.raw_transcript)\"..."
                let remoteGLBURL: URL
                do {
                    remoteGLBURL = try await modelService.generateModel(prompt: prompt.optimized_3d_prompt)
                } catch {
                    // If 3D generation fails (no fal key, no credits), use starter model
                    print("MainARView: 3D generation failed: \(error)")
                    if let fallback = starterModelURL() {
                        arVM.pendingModelURL = fallback
                        statusMessage = "3D generation unavailable — tap to place a starter model"
                        isProcessing = false
                        return
                    }
                    throw error
                }

                // Step 3: Download GLB
                statusMessage = "Downloading 3D model..."
                let localGLB = try await modelService.downloadModel(from: remoteGLBURL)

                // Step 4: Convert GLB → USDZ
                statusMessage = "Preparing for AR..."
                let usdzURL: URL
                do {
                    usdzURL = try conversion.convertGLBtoUSDZ(glbLocalURL: localGLB)
                } catch {
                    print("MainARView: GLB→USDZ conversion failed, using starter model: \(error)")
                    if let fallback = starterModelURL() {
                        usdzURL = fallback
                        statusMessage = "Using starter model — AI model had complex geometry. Tap to place!"
                        arVM.pendingModelURL = usdzURL
                        isProcessing = false
                        return
                    }
                    throw AppError.conversionFailed
                }

                // Step 5: Ready to place
                arVM.pendingModelURL = usdzURL
                statusMessage = "Tap a surface to place your character!"
                isProcessing = false

            } catch {
                statusMessage = friendlyError(error)
                isProcessing = false
                print("MainARView: Pipeline error: \(error)")
            }
        }
    }

    // MARK: - Capture + Video Pipeline

    private func captureAndGenerateVideo() {
        isProcessing = true
        statusMessage = "Capturing your scene..."

        Task { @MainActor in
            do {
                // Step 1: Capture AR frame
                guard let image = await arVM.captureFrame() else {
                    throw AppError.captureFailed
                }
                print("MainARView: Captured frame \(Int(image.size.width))x\(Int(image.size.height))")

                // Step 2: Upload to fal.ai storage
                statusMessage = "Uploading frame..."
                var imageURL = try await imageUploader.upload(image, falKey: Secrets.falKey)

                // Step 3 (optional): Cinematic stylization via Flux 2.0 Pro
                if cinematicStyleEnabled {
                    statusMessage = "Applying cinematic style..."
                    do {
                        let styledURL = try await imageEditService.stylizeFrame(imageURL: imageURL)
                        imageURL = styledURL
                        print("MainARView: Stylized image at \(styledURL)")
                    } catch {
                        // Non-fatal: continue with unstylized image
                        print("MainARView: Stylization failed, continuing with original: \(error)")
                        statusMessage = "Style failed — using original frame..."
                    }
                }

                // Step 4: Generate video via Seedance
                let motionPrompt = lastPrompt?.motion_prompt
                    ?? "Gentle camera movement, character subtly animates, cinematic atmosphere"

                let videoURL = try await videoService.generateVideo(
                    fromImageURL: imageURL,
                    motionPrompt: motionPrompt
                ) { progress in
                    Task { @MainActor in
                        statusMessage = progress
                    }
                }

                // Step 4: Show result
                resultVideoURL = videoURL
                showingVideoResult = true
                isProcessing = false
                statusMessage = ""

            } catch {
                statusMessage = friendlyError(error)
                isProcessing = false
                print("MainARView: Video pipeline error: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func starterModelURL() -> URL? {
        Bundle.main.url(forResource: "toy_biplane_realistic", withExtension: "usdz")
            ?? Bundle.main.url(forResource: "toy_car", withExtension: "usdz")
    }

    private func friendlyError(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "Something went wrong"
        }
        let desc = error.localizedDescription
        if desc.contains("offline") || desc.contains("not connected") || desc.contains("network") {
            return "No internet connection — check your WiFi"
        }
        if desc.contains("timed out") {
            return "Request timed out — try again"
        }
        return "Something went wrong — try again"
    }

    // MARK: - Components

    private func statusPill(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func controlButton(
        icon: String,
        size: CGFloat,
        color: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.35))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(color)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
    }
}
