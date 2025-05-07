import SwiftUI
// Model representing a multiplayer game
struct MultiUserGame: Identifiable, Codable, Hashable {
    let id: UUID // Unique identifier for each game
    var creatorID: String  // User ID of the creator
    var participantsIDs: Set<String>  // Collection of user IDs participating in the game
    var words: [Word]  // List of words added to the game
    var isStarted: Bool = false  // Flag indicating if the game has started
    let creationDate: Date  // When the game was created
    
    // Equatable protocol implementation
    static func == (lhs: MultiUserGame, rhs: MultiUserGame) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable protocol implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
