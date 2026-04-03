import Foundation

struct CharacterPrompt: Codable {
    let raw_transcript: String
    let optimized_3d_prompt: String
    let motion_prompt: String
}
