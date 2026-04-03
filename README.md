# StoryWorld

**An AR filmmaking tool powered by AI.** Speak to create 3D characters, place them in augmented reality, frame your shot by physically moving your phone, and let AI generate cinematic video clips from your scene.

---

## Demo Pipeline

```
Speak → AI transcribes & enhances prompt → 3D model generated → Placed in AR →
Frame your shot → Capture → (Optional: cinematic stylization) → AI video generated → Play & save
```

---

## Features

- **Voice-to-3D**: Describe a character or object in natural language. Gemini 2.5 Flash transcribes your speech and enhances it into an optimized 3D generation prompt.
- **AI 3D Generation**: Hyper3D Rodin generates a textured 3D model (.glb) from your prompt, automatically converted to Apple's USDZ format for AR.
- **AR Placement**: Tap any real-world surface to place your character. Drag, pinch-to-scale, and two-finger-rotate to adjust.
- **Cinematic Video**: Capture your AR scene, optionally apply Flux 2.0 Pro cinematic styling, then Seedance 1.0 Pro generates a short cinematic video clip.
- **Offline Fallback**: If Gemini is unavailable, Apple's on-device SFSpeechRecognizer handles transcription. If 3D generation fails, bundled starter models keep the demo running.
- **Save & Share**: Generated videos can be saved directly to your camera roll.

---

## Tech Stack

| Layer | Technology | Cost |
|---|---|---|
| Speech-to-Text + Prompt Enhancement | Gemini 2.5 Flash (Google AI Studio) | Free tier |
| Offline Speech Fallback | Apple SFSpeechRecognizer | Free (on-device) |
| Text-to-3D | Hyper3D Rodin via fal.ai | Free signup credits |
| GLB-to-USDZ Conversion | Apple ModelIO | Free (on-device) |
| AR Rendering | ARKit + RealityKit | Free (iOS frameworks) |
| Image Stylization (optional) | Flux 2.0 Pro via fal.ai | Free signup credits |
| Image-to-Video | Seedance 1.0 Pro via fal.ai | Free signup credits |
| Audio Recording | AVFoundation | Free (on-device) |
| Video Playback & Save | AVKit + Photos | Free (on-device) |

**Zero external dependencies.** No CocoaPods, no SPM packages. Everything uses URLSession and built-in Apple frameworks.

---

## API Endpoints

| Service | Endpoint | Auth |
|---|---|---|
| Gemini 2.5 Flash | `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` | API key as URL param |
| Rodin 3D Generation | `queue.fal.run/fal-ai/hyper3d/rodin` | `Authorization: Key` header |
| Flux 2.0 Pro Stylization | `queue.fal.run/fal-ai/flux-2-pro/edit` | `Authorization: Key` header |
| Seedance 1.0 Pro Video | `queue.fal.run/fal-ai/bytedance/seedance/v1/pro/image-to-video` | `Authorization: Key` header |
| fal.ai Image Upload | `fal.ai/api/upload` | `Authorization: Key` header |

All fal.ai services use a queue-based pattern: **submit** (POST) -> **poll status** (GET) -> **fetch result** (GET).

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
│   ├── VideoPlayerView.swift        # AVPlayer wrapper
│   └── VideoResultSheet.swift       # Video playback sheet + save to Photos
│
├── Models/
│   ├── PlacedCharacter.swift        # Entity + anchor + model URL
│   ├── CharacterPrompt.swift        # raw_transcript, optimized_3d_prompt, motion_prompt
│   ├── GeminiModels.swift           # Gemini API response types
│   ├── FalModels.swift              # fal.ai response types (Rodin, Flux, Seedance, Upload)
│   ├── TripoModels.swift            # Tripo AI response types (alternative)
│   └── AppError.swift               # Error enum with localized descriptions
│
├── Services/
│   ├── GeminiVoiceService.swift     # Gemini transcription + prompt enhancement
│   ├── AppleSpeechService.swift     # SFSpeechRecognizer offline fallback
│   ├── FalModelService.swift        # Hyper3D Rodin 3D generation via fal.ai
│   ├── TripoModelService.swift      # Tripo AI alternative (not wired)
│   ├── ModelConversionService.swift # GLB -> USDZ via ModelIO
│   ├── ImageUploadService.swift     # Upload UIImage to fal.ai storage
│   ├── ImageEditService.swift       # Flux 2.0 Pro image stylization
│   └── VideoGenerationService.swift # Seedance 1.0 Pro image-to-video
│
├── Resources/
│   └── starter_models/
│       ├── toy_biplane_realistic.usdz
│       └── toy_car.usdz
│
└── Assets.xcassets/
```

---

## Setup & Installation

### Prerequisites

- Mac with Xcode installed
- iPhone with ARKit support (iPhone SE 2nd gen or newer)
- USB cable to connect iPhone to Mac
- Free API keys (instructions below)

### 1. Clone the repository

```bash
git clone <repo-url>
cd StoryWorld
```

### 2. Get API keys

**Gemini API Key (free):**
1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key

**fal.ai API Key (free signup credits):**
1. Go to [fal.ai](https://fal.ai)
2. Create an account
3. Go to dashboard -> API Keys
4. Copy the key

### 3. Configure secrets

Create or edit `StoryWorld/Secrets.swift`:

```swift
enum Secrets {
    static let geminiKey = "YOUR_GEMINI_API_KEY"
    static let falKey = "YOUR_FAL_AI_KEY"
}
```

### 4. Open in Xcode

```bash
open StoryWorld.xcodeproj
```

### 5. Configure signing

1. Select the **StoryWorld** target
2. Go to **Signing & Capabilities**
3. Set **Team** to your personal Apple ID
4. Xcode will auto-manage provisioning

### 6. Build & run

1. Connect your iPhone via USB
2. Select your iPhone as the run destination
3. Press **Cmd+R** to build and run
4. **Allow camera and microphone access** when prompted

---

## How to Use

### Place a character with voice

1. Tap the **mic button** (bottom left)
2. Describe your character: *"a golden dragon with red wings"*
3. Tap the mic again to stop recording
4. Wait for the pipeline (30-90 seconds):
   - "Understanding your voice..."
   - "Generating 3D..."
   - "Downloading..."
   - "Preparing for AR..."
   - "Tap a surface to place your character!"
5. Tap any flat surface (table, floor, wall) to place the model
6. Drag, pinch, and rotate to adjust

### Place a starter model (no API needed)

1. Just tap any detected surface — a bundled 3D model appears immediately

### Generate a cinematic video

1. Place at least one character in AR
2. Walk around and frame your shot
3. (Optional) Tap **"Cinematic Style"** to enable Flux 2.0 Pro stylization
4. Tap the **camera button** (center)
5. Wait 1-3 minutes for video generation
6. A sheet slides up with your video
7. Tap **Save** to save to your camera roll

### Clear the scene

Tap the **trash button** (bottom right) to remove all placed characters.

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
                           │ CharacterPrompt
              ┌────────────▼────────────┐
              │    FalModelService      │  Hyper3D Rodin
              │    generateModel()      │  (30-90 sec)
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
              │ ModelConversionService  │  Apple ModelIO
              │   convertGLBtoUSDZ()    │
              └────────────┬────────────┘
                           │ USDZ file
              ┌────────────▼────────────┐
              │   ARSceneViewModel      │  RealityKit
              │    placeModel()         │  + gesture support
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
              │  ImageUploadService     │  fal.ai storage
              └────────────┬────────────┘
                           │ hosted image URL
              ┌────────────▼────────────┐
              │  ImageEditService       │  Flux 2.0 Pro
              │  (optional, toggleable) │  (10-30 sec)
              └────────────┬────────────┘
                           │ styled image URL
              ┌────────────▼────────────┐
              │ VideoGenerationService  │  Seedance 1.0 Pro
              │   generateVideo()       │  (1-3 min)
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
| 3D generation | Hyper3D Rodin (fal.ai) | Bundled starter .usdz models |
| GLB-to-USDZ conversion | Apple ModelIO | Bundled starter .usdz models |
| Image stylization | Flux 2.0 Pro (fal.ai) | Skip — use original image (non-fatal) |
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
| ModelIO | 3D model format conversion (GLB to USDZ) |
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
| 3D model generation (Rodin) | 30-90 seconds |
| GLB download | 2-5 seconds |
| GLB-to-USDZ conversion | < 1 second |
| Image upload | 1-2 seconds |
| Image stylization (Flux) | 10-30 seconds |
| Video generation (Seedance) | 1-3 minutes |

---

## Troubleshooting

| Problem | Solution |
|---|---|
| AR not detecting surfaces | Point at a well-lit, textured surface. Move slowly. |
| "Gemini API error (400)" | Check your API key in Secrets.swift |
| "fal.ai submit failed" | Check your fal.ai key and remaining credits |
| 3D model looks wrong in AR | GLB-to-USDZ conversion is imperfect. Try a different prompt. |
| Video generation seems stuck | Seedance takes 1-3 min. Watch the elapsed time counter. |
| App crashes on simulator | AR only works on physical devices. Use a real iPhone. |
| Model won't place | Wait for AR to detect a plane (status shows "Scanning...") |
| No sound when recording | Allow microphone permission in Settings > StoryWorld |

---

## Cost Summary

| Service | Free Tier |
|---|---|
| Gemini 2.5 Flash | Generous free tier via Google AI Studio |
| fal.ai (Rodin, Flux, Seedance) | Free signup credits (~$10 worth) |
| Apple frameworks | Free |
| **Total** | **$0** |

---

## License

This project was built as a hackathon/portfolio project. All third-party APIs are used under their respective free tiers and terms of service.

- Starter 3D models: Apple AR Quick Look Gallery
- All Apple frameworks: Subject to Apple's developer license
