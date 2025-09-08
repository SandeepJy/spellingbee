//import Foundation
//
///// Model to track a user's progress in a specific game
//struct UserGameProgress: Identifiable, Codable, Hashable {
//    // Combination of userID and gameID to ensure uniqueness
//    var id: String  // Format: "userID-gameID"
//    
//    let userID: String                // The user this progress belongs to
//    let gameID: UUID                  // The game this progress is for
//    var completedWordIndices: [Int]   // Indices of words the user has completed
//    var currentWordIndex: Int         // The index of the current word
//    var score: Int                    // The user's current score
//    var lastUpdated: Date             // When this progress was last updated
//    
//    init(userID: String, gameID: UUID, completedWordIndices: [Int] = [], currentWordIndex: Int = 0, score: Int = 0, lastUpdated: Date = Date()) {
//        self.userID = userID
//        self.gameID = gameID
//        self.completedWordIndices = completedWordIndices
//        self.currentWordIndex = currentWordIndex
//        self.score = score
//        self.lastUpdated = lastUpdated
//        self.id = Self.generateID(userID: userID, gameID: gameID)
//    }
//    
//    // Static function to generate consistent ID
//    static func generateID(userID: String, gameID: UUID) -> String {
//        return "\(userID)-\(gameID.uuidString)"
//    }
//    
//    // Equatable protocol implementation
//    static func == (lhs: UserGameProgress, rhs: UserGameProgress) -> Bool {
//        lhs.id == rhs.id
//    }
//    
//     Hashable protocol implementation
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
//}
