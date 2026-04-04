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

    // New feature state
    @State private var showModelPicker = false
    @State private var showGallery = false
    @State private var capturedFrames: [CapturedFrame] = []
    @State private var selectedBackground: BackgroundTheme = .realWorld
    @State private var showBackgroundPicker = false

    // Services
    private let gemini = GeminiVoiceService(apiKey: Secrets.geminiKey)
    private let appleSpeech = AppleSpeechService()
    private let modelService = HuggingFaceModelService()
    private let conversion = ModelConversionService()
    private let videoService = VideoGenerationService(apiKey: Secrets.minimaxKey)
    private let bgRemoval = BackgroundRemovalService()

    var body: some View {
        ZStack {
            // Full-screen AR view
            ARViewContainer(viewModel: arVM)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top bar: gallery + status + models
                HStack {
                    // Gallery button (top left)
                    Button {
                        showGallery = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 14))
                            if !capturedFrames.isEmpty {
                                Text("\(capturedFrames.count)")
                                    .font(.caption2.bold())
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer()

                    // Models button (top right)
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 14))
                            Text("Models")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                // Status messages
                VStack(spacing: 4) {
                    if !arVM.trackingStatus.isEmpty {
                        statusPill(text: arVM.trackingStatus)
                    }
                    if !statusMessage.isEmpty {
                        statusPill(text: statusMessage)
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Onboarding hint
                if showOnboarding && arVM.placedCharacters.isEmpty && !isProcessing {
                    VStack(spacing: 6) {
                        Text("Welcome to StoryWorld")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Tap the mic and describe a character,\nor tap Models to browse starter 3D models.\nThen tap a surface to place it in AR.")
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

                // Background picker button (only when characters placed)
                if !arVM.placedCharacters.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBackgroundPicker.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedBackground == .realWorld ? "photo.fill" : selectedBackground.icon)
                                .font(.caption2)
                            Text(selectedBackground == .realWorld ? "Background" : selectedBackground.rawValue)
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedBackground == .realWorld ? .white.opacity(0.7) : .cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .disabled(isProcessing)
                    .padding(.bottom, 8)
                }

                // Background picker strip
                if showBackgroundPicker {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BackgroundTheme.allCases) { theme in
                                Button {
                                    selectedBackground = theme
                                    showBackgroundPicker = false
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            if theme == .realWorld {
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                    .frame(width: 44, height: 44)
                                            } else {
                                                Circle()
                                                    .fill(LinearGradient(
                                                        colors: [theme.colors.0, theme.colors.1],
                                                        startPoint: .top, endPoint: .bottom
                                                    ))
                                                    .frame(width: 44, height: 44)
                                            }
                                            Image(systemName: theme.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(.white)
                                        }
                                        Text(theme.rawValue)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(4)
                                    .background(
                                        selectedBackground == theme
                                            ? RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.2))
                                            : nil
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

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

                    // Camera button — captures to gallery
                    controlButton(
                        icon: "camera.fill",
                        size: 72,
                        color: .white,
                        foreground: .black
                    ) {
                        captureToGallery()
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
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet { selectedURL in
                arVM.pendingModelURL = selectedURL
                statusMessage = "Tap a surface to place the model!"
                showOnboarding = false
            }
        }
        .sheet(isPresented: $showGallery) {
            GalleryView(
                capturedFrames: $capturedFrames,
                videoService: videoService
            )
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

    // MARK: - Capture to Gallery

    private func captureToGallery() {
        statusMessage = "Capturing..."

        Task { @MainActor in
            guard let rawImage = await arVM.captureFrame() else {
                statusMessage = "Capture failed — try again"
                return
            }

            let finalImage: UIImage
            if selectedBackground != .realWorld {
                statusMessage = "Applying \(selectedBackground.rawValue) background..."
                if let composited = bgRemoval.applyBackground(to: rawImage, theme: selectedBackground) {
                    finalImage = composited
                } else {
                    // Fallback: use raw image if background removal fails
                    finalImage = rawImage
                    print("MainARView: Background removal failed, using original")
                }
            } else {
                finalImage = rawImage
            }

            let frame = CapturedFrame(image: finalImage)
            capturedFrames.append(frame)
            statusMessage = "Captured! Open Gallery to animate."

            // Flash effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if statusMessage == "Captured! Open Gallery to animate." {
                    statusMessage = ""
                }
            }
        }
    }

    // MARK: - Voice → 3D → AR Pipeline

    private func processAudio(_ audioData: Data) {
        isProcessing = true
        statusMessage = "Understanding your voice..."

        Task { @MainActor in
            do {
                let prompt: CharacterPrompt
                do {
                    prompt = try await gemini.extractCharacterPrompt(audioData: audioData)
                } catch {
                    print("MainARView: Gemini failed (\(error)), trying Apple Speech fallback")
                    statusMessage = "Gemini unavailable, using on-device speech..."
                    if let transcript = await appleSpeech.transcribeFromAudio(audioData),
                       !transcript.isEmpty {
                        prompt = CharacterPrompt(
                            raw_transcript: transcript,
                            optimized_3d_prompt: transcript,
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

                statusMessage = "Generating 3D: \"\(prompt.raw_transcript)\"..."
                let remoteGLBURL: URL
                do {
                    remoteGLBURL = try await modelService.generateModel(prompt: prompt.optimized_3d_prompt)
                } catch {
                    print("MainARView: 3D generation failed: \(error)")
                    if let fallback = starterModelURL() {
                        arVM.pendingModelURL = fallback
                        statusMessage = "3D generation unavailable — tap to place a starter model"
                        isProcessing = false
                        return
                    }
                    throw error
                }

                statusMessage = "Downloading 3D model..."
                let localGLB = try await modelService.downloadModel(from: remoteGLBURL)

                statusMessage = "Preparing for AR..."

                // Try USDZ conversion first, then custom GLB loader as fallback
                var placed = false
                do {
                    let usdzURL = try conversion.convertGLBtoUSDZ(glbLocalURL: localGLB)
                    arVM.pendingModelURL = usdzURL
                    placed = true
                } catch {
                    print("MainARView: USDZ conversion failed, trying direct GLB loader...")
                }

                if !placed {
                    do {
                        let entity = try GLBLoader.loadEntity(from: localGLB)
                        arVM.pendingEntity = entity
                        placed = true
                        print("MainARView: Loaded GLB directly via custom parser")
                    } catch {
                        print("MainARView: GLB loader also failed: \(error)")
                        if let fallback = starterModelURL() {
                            arVM.pendingModelURL = fallback
                            statusMessage = "Using starter model — AI model had complex geometry. Tap to place!"
                            isProcessing = false
                            return
                        }
                        throw AppError.conversionFailed
                    }
                }
                statusMessage = "Tap a surface to place your character!"
                isProcessing = false

            } catch {
                statusMessage = friendlyError(error)
                isProcessing = false
                print("MainARView: Pipeline error: \(error)")
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
