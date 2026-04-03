import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARSceneViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        // Enable LiDAR mesh if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        arView.session.run(config)
        arView.session.delegate = context.coordinator

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Store reference
        Task { @MainActor in
            viewModel.arView = arView
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARSceneViewModel

        init(viewModel: ARSceneViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else { return }
            let location = recognizer.location(in: arView)

            // Raycast to find a real-world surface
            if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
                Task { @MainActor in
                    viewModel.handlePlacement(at: result.worldTransform)
                }
            }
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            Task { @MainActor in
                switch camera.trackingState {
                case .notAvailable:
                    viewModel.trackingStatus = "AR not available"
                case .limited(let reason):
                    switch reason {
                    case .initializing:
                        viewModel.trackingStatus = "Scanning your environment..."
                    case .excessiveMotion:
                        viewModel.trackingStatus = "Slow down — too much motion"
                    case .insufficientFeatures:
                        viewModel.trackingStatus = "Point at a textured surface"
                    case .relocalizing:
                        viewModel.trackingStatus = "Relocalizing..."
                    @unknown default:
                        viewModel.trackingStatus = "Limited tracking"
                    }
                case .normal:
                    viewModel.trackingStatus = ""
                }
            }
        }
    }
}
