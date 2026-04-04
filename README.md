# StoryWorld

**An AR filmmaking tool powered by AI.** Speak to create 3D characters, place them in augmented reality, change backgrounds, frame your shot by physically moving your phone, and let AI generate cinematic video clips from your scene.

---

## Demo Pipeline

```
Speak → AI transcribes & enhances prompt → 3D model generated → Placed in AR →
Choose background theme → Frame your shot → Capture → AI video generated → Play & save
```

---

## Features

- **Voice-to-3D**: Describe a character or object in natural language. Gemini 2.5 Flash transcribes your speech and enhances it into an optimized 3D generation prompt.
- **AI 3D Generation**: OpenAI's Shap-E (hosted free on Hugging Face) generates a 3D model from your prompt, loaded directly into AR via a custom GLB parser.
- **AR Placement**: Tap any real-world surface to place your character. Drag, pinch-to-scale, and two-finger-rotate to adjust.
- **Background Themes**: Choose from 8 AR backgrounds — Real World, Desert, Snow, Forest, Space, Ocean, Sunset, or Cyberpunk. Uses Apple Vision framework for foreground segmentation.
- **Cinematic Video**: Capture your AR scene, then MiniMax Hailuo 2.3-Fast generates a short cinematic video clip.
- **Gallery & Animate**: Browse captured frames in a gallery. Select any frame to animate it into a video.
- **Offline Fallback**: If Gemini is unavailable, Apple's on-device SFSpeechRecognizer handles transcription. If 3D generation fails, bundled starter models keep the demo running.
- **Save & Share**: Generated videos can be saved directly to your camera roll.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Speech-to-Text + Prompt Enhancement | Gemini 2.5 Flash (Google AI Studio) |
| Offline Speech Fallback | Apple SFSpeechRecognizer |
| Text-to-3D | OpenAI Shap-E via Hugging Face Spaces (free) |
| GLB Loading | Custom GLB binary parser → RealityKit ModelEntity |
| AR Rendering | ARKit + RealityKit |
| Background Removal | Apple Vision Framework (iOS 17+) |
| Image-to-Video | MiniMax Hailuo 2.3-Fast (768P) |
| Audio Recording | AVFoundation |
| Video Playback & Save | AVKit + Photos |

**Zero external dependencies.** No CocoaPods, no SPM packages. Everything uses URLSession and built-in Apple frameworks.

---

## API Endpoints

| Service | Endpoint | Auth |
|---|---|---|
| Gemini 2.5 Flash | `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` | API key as URL param |
| Shap-E 3D Generation | `hysts-shap-e.hf.space/gradio_api/call/text-to-3d` | None (free) |
| MiniMax Hailuo 2.3 Video | `api.minimax.io/v1/video_generation` | `Authorization: Bearer` header |

Shap-E uses Gradio's REST API: **submit** (POST `/call/text-to-3d`) → **poll SSE** (GET `/call/text-to-3d/{event_id}`) → **download GLB** (GET `/file=...`).
MiniMax uses a similar pattern: **submit** (POST `/v1/video_generation`) → **poll** (GET `/v1/query/video_generation`) → **retrieve file** (GET `/v1/files/retrieve`).

---

## Project Structure

```
StoryWorld/
├── StoryWorldApp.swift              # App entry point + temp file cleanup
├── Secrets.swift                    # API keys (gitignored)
│
├── AR/
│   ├── ARViewContainer.swift        # UIViewRepresentable wrapping ARView
│   └── ARSceneViewModel.swift       # AR state: placement, gestures, capture
│
├── Audio/
│   └── AudioRecorder.swift          # AVAudioRecorder (M4A, 24kHz, mono)
│
├── Views/
│   ├── MainARView.swift             # Primary UI with AR + controls overlay
│   ├── AnimateSheet.swift           # Video generation from captured frame
│   ├── GalleryView.swift            # Browse captured frames + animate
│   ├── ModelPickerSheet.swift       # Starter model browser
│   ├── VideoPlayerView.swift        # AVPlayer wrapper
│   └── VideoResultSheet.swift       # Video playback sheet + save to Photos
│
├── Models/
│   ├── PlacedCharacter.swift        # Entity + anchor + model URL
│   ├── CapturedFrame.swift          # Image + video URL + animation state
│   ├── CharacterPrompt.swift        # raw_transcript, optimized_3d_prompt, motion_prompt
│   ├── BackgroundTheme.swift        # 8 AR background themes with gradients
│   ├── GeminiModels.swift           # Gemini API response types
│   ├── FalModels.swift              # MiniMax API response types
│   └── AppError.swift               # Error enum with localized descriptions
│
├── Services/
│   ├── GeminiVoiceService.swift     # Gemini transcription + prompt enhancement
│   ├── AppleSpeechService.swift     # SFSpeechRecognizer offline fallback
│   ├── HuggingFaceModelService.swift# Shap-E 3D generation (free, no key needed)
│   ├── GLBLoader.swift              # Custom GLB binary parser → RealityKit entity
│   ├── ModelConversionService.swift # GLB → USDZ via SceneKit (fallback path)
│   ├── BackgroundRemovalService.swift# Apple Vision foreground segmentation
│   ├── VideoGenerationService.swift # MiniMax Hailuo 2.3-Fast image-to-video
│   └── (legacy: FalModelService, TripoModelService, ImageUploadService, ImageEditService)
│
├── Resources/
│   └── starter_models/
│       ├── toy_biplane_realistic.usdz
│       └── toy_car.usdz
│
└── Assets.xcassets/
```

---

## How to Use

### Place a character with voice

1. Tap the **mic button** (bottom left)
2. Describe your character: *"a golden dragon"* or *"a spider monster"*
3. Tap the mic again to stop recording
4. Wait for the pipeline (~30 seconds):
   - "Understanding your voice..."
   - "Generating 3D..."
   - "Downloading..."
   - "Preparing for AR..."
   - "Tap a surface to place your character!"
5. Tap any flat surface (table, floor, wall) to place the model
6. Drag, pinch, and rotate to adjust

### Change background theme

1. Tap the **background button** to open the theme picker
2. Choose from: Real World, Desert, Snow, Forest, Space, Ocean, Sunset, Cyberpunk
3. Captured frames will use the selected background (foreground segmentation via Apple Vision)

### Place a starter model (no API needed)

1. Tap the **model picker** button to browse bundled 3D models

### Capture & animate

1. Place characters and frame your shot
2. Tap the **camera button** to capture a frame
3. Open the **gallery** to browse captures
4. Tap any frame and choose **Animate** to generate a cinematic video
5. Wait 1-3 minutes for MiniMax to generate the video
6. Tap **Save** to save to your camera roll

### Clear the scene

Tap the **trash button** to remove all placed characters.

---

## Architecture

### Pipeline Detail

```
                    ┌──────────────┐
                    │  Mic Button  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ AudioRecorder│  M4A, 24kHz, mono
                    └──────┬───────┘
                           │ audio Data
              ┌────────────▼────────────┐
              │   GeminiVoiceService    │  Gemini 2.5 Flash
              │ extractCharacterPrompt()│
              └────────────┬────────────┘
                           │              ┌─────────────────┐
                           │  (fallback)──► AppleSpeechService│
                           │              └─────────────────┘
                           │ CharacterPrompt (simple prompt)
              ┌────────────▼────────────┐
              │ HuggingFaceModelService │  Shap-E (free)
              │    generateModel()      │  (~15-30 sec)
              └────────────┬────────────┘
                           │              ┌──────────────────┐
                           │  (fallback)──► Starter .usdz     │
                           │              └──────────────────┘
                           │ remote GLB URL
              ┌────────────▼────────────┐
              │    downloadModel()      │  Download to temp
              └────────────┬────────────┘
                           │ local GLB file
              ┌────────────▼────────────┐
              │      GLBLoader          │  Custom binary parser
              │   loadEntity(from:)     │  → RealityKit ModelEntity
              └────────────┬────────────┘
                           │ ModelEntity
              ┌────────────▼────────────┐
              │   ARSceneViewModel      │  RealityKit
              │    placeEntity()        │  + gesture support
              └────────────┬────────────┘
                           │
                    ┌──────▼───────┐
                    │ Camera Button│
                    └──────┬───────┘
                           │
              ┌────────────▼────────────┐
              │    captureFrame()       │  ARView.snapshot()
              └────────────┬────────────┘
                           │ UIImage
              ┌────────────▼────────────┐
              │ BackgroundRemovalService │  Apple Vision
              │  (if theme ≠ realWorld) │  foreground segmentation
              └────────────┬────────────┘
                           │ composited UIImage
              ┌────────────▼────────────┐
              │ VideoGenerationService  │  MiniMax Hailuo 2.3-Fast
              │   generateVideo()       │  base64 data URI (no upload)
              │                         │  (1-3 min, $0.19/video)
              └────────────┬────────────┘
                           │ video URL
              ┌────────────▼────────────┐
              │   VideoResultSheet      │  AVPlayer + Save
              └─────────────────────────┘
```

### Fallback Strategy

The app is designed to never crash and always remain functional, even when APIs are unavailable:

| Stage | Primary | Fallback |
|---|---|---|
| Voice transcription | Gemini 2.5 Flash | Apple SFSpeechRecognizer (on-device) |
| 3D generation | Shap-E via Hugging Face (free) | Bundled starter .usdz models |
| GLB loading | Custom GLBLoader (direct parse) | SceneKit/ModelIO USDZ conversion |
| Background removal | Apple Vision (iOS 17+) | Original image (no segmentation) |
| All network calls | URLSession with error handling | Friendly error message, never crashes |

### Threading

- All UI state mutations run on `@MainActor`
- Async service calls use `async/await` with structured concurrency
- AR operations dispatch to main thread via `Task { @MainActor in }`
- Progress callbacks from background polling are wrapped in `MainActor.run`

---

## Frameworks Used

| Framework | Purpose |
|---|---|
| SwiftUI | User interface |
| RealityKit | AR rendering, entity management, gestures |
| ARKit | World tracking, plane detection, raycasting |
| AVFoundation | Audio recording (AVAudioRecorder, AVAudioSession) |
| AVKit | Video playback (VideoPlayer) |
| Speech | On-device speech recognition (SFSpeechRecognizer) |
| Vision | Foreground segmentation for background themes (iOS 17+) |
| CoreImage | Image compositing (CIBlendWithMask) |
| ModelIO | 3D model format conversion (GLB to USDZ, fallback) |
| Photos | Save videos to camera roll (PHPhotoLibrary) |
| Combine | Reactive state management (@Published) |

---

## Build Configuration

| Setting | Value |
|---|---|
| iOS Deployment Target | 16.0 |
| Swift Version | 5.0 |
| Supported Devices | iPhone and iPad |
| Required Capabilities | ARKit |
| Code Signing | Automatic |
| External Dependencies | None |

### Info.plist Permissions

| Key | Description |
|---|---|
| NSCameraUsageDescription | AR camera access |
| NSMicrophoneUsageDescription | Voice recording |
| NSSpeechRecognitionUsageDescription | On-device speech recognition |
| NSPhotoLibraryAddUsageDescription | Save generated videos |

---

## Timing Expectations

| Operation | Duration |
|---|---|
| Voice transcription (Gemini) | 2-5 seconds |
| 3D model generation (Shap-E) | 15-30 seconds |
| GLB download | 2-5 seconds |
| GLB parsing (GLBLoader) | < 1 second |
| Background segmentation | 1-2 seconds |
| Video generation (MiniMax Hailuo) | 1-3 minutes |

---

## Cost Summary

| Service | Cost |
|---|---|
| Gemini 2.5 Flash | Free tier via Google AI Studio |
| Shap-E (Hugging Face) | **Free** (no API key, no credits) |
| MiniMax Hailuo 2.3-Fast | ~$0.19/video (768P, 6s) |
| Apple frameworks | Free |
| **Total for demo** | **~$0.19 per video generated** |

---

## Troubleshooting

| Problem | Solution |
|---|---|
| AR not detecting surfaces | Point at a well-lit, textured surface. Move slowly. |
| "Gemini API error (400)" | Check your API key in Secrets.swift |
| 3D model looks blobby | Shap-E is a free model — quality is basic but good for demos. Try simpler prompts. |
| Model appears very dark | The GLBLoader auto-boosts dark vertex colors. Try a different prompt. |
| Video generation seems stuck | MiniMax Hailuo takes 1-3 min. Watch the elapsed time counter. |
| App crashes on simulator | AR only works on physical devices. Use a real iPhone. |
| Model won't place | Wait for AR to detect a plane (status shows "Scanning...") |
| No sound when recording | Allow microphone permission in Settings > StoryWorld |
| Background theme not working | Requires iOS 17+ for Vision framework segmentation. |

---

## License

This project was built as a hackathon/portfolio project. All third-party APIs are used under their respective free tiers and terms of service.

- Starter 3D models: Apple AR Quick Look Gallery
- All Apple frameworks: Subject to Apple's developer license
