import Foundation
import RealityKit

struct PlacedCharacter: Identifiable {
    let id = UUID()
    let entity: Entity
    let anchor: AnchorEntity
    let modelURL: URL
}
