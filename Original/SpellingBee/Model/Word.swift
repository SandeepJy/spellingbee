
import Foundation
import SwiftUI

// Model representing a word in the game
struct Word: Identifiable, Codable, Hashable {
    let id = UUID()  // Unique identifier for each word
    let word: String  // The actual word
    let soundURL: URL?  // Optional URL to audio pronunciation
    let level: Int  // Difficulty level of the word
    var createdBy: SpellGameUser  // User ID who added this word
    var game: MultiUserGame? //The game that this word belongs to
    
    // Equatable protocol implementation
    static func == (lhs: Word, rhs: Word) -> Bool {
        lhs.id == rhs.id
    }
    
    // Hashable protocol implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
