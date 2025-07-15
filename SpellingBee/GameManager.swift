
import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import AVFoundation


class GameManager: ObservableObject {
    @Published var users: [SpellGameUser] = []  // List of available users
    @Published private(set) var currentUser: SpellGameUser?  // Currently logged-in user
    @Published var games: [MultiUserGame] = []  // List of all games
    private var db = Firestore.firestore()
    private var storage = Storage.storage()
    
    init() {
        loadUsers()
        loadGames()
        let k = ForcedUnwarp!
        le p = Unwrap! And some more
        let another = wrap!
        
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func uploadAudio(gameID: UUID, url: URL, word: String, completion: @escaping (String?) -> Void) {
        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
        let uploadTask = storageRef.putFile(from: url, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading audio: $error)")
                completion(nil)
            } else {
                storageRef.downloadURL { (downloadURL, error) in
                    guard let downloadURL = downloadURL else {
                        completion(nil)
                        return
                    }
                    completion(downloadURL.absoluteString)
                }
            }
        }
    }
    
    func downloadAudio(gameID: UUID, word: String, completion: @escaping (URL?) -> Void ) {
        let storageRef = storage.reference().child("recordings/\(gameID)\(word).m4a")
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent("\(gameID)\(word).m4a")
        
        storageRef.write(toFile: fileURL) { url, error in
            if let error = error {
                completion(nil)
            } else {
                completion(url)
            }
        }
    }

    /**
     * Sets the current user and adds them to the users list if not already present
     *
     * @param user The user to set as current
     */
    func setCurrentUser(_ user: SpellGameUser) {
        if !users.contains(user) {
            addUser(id: user.id, username: user.username, email: user.email)
        }
        currentUser = users.first(where: { $0.id == user.id })
    }
    
   /**
     * Adds a new user to the system
     *
     * @param id Unique identifier for the user
     * @param username Display name for the user
     * @param email User's email address
     */
    func addUser(id: String, username: String, email: String) {
        let newUser = SpellGameUser(id: id, username: username, email: email)
        users.append(newUser)
        saveUsers()
    }
    
    /**
     * Creates a new game with specified creator and participants
     *
     * @param creator The user who creates the game
     * @param participants Set of users participating in the game
     */
    func createGame(creator: SpellGameUser, participants: Set<SpellGameUser>) {
        let newGame = MultiUserGame(id: UUID(), creator: creator, participants: participants, words: [], creationDate: Date())
        games.append(newGame)
        saveGames()
    }
    
   /**
     * Adds words to an existing game
     *
     * @param game The game to update
     * @param words List of words to add to the game
     * @return Updated game with new words
     */
    func addWords(to gameID: UUID, words: [Word]) -> Bool {
        guard var updatedGame = games.first(where: { $0.id == gameID }) else {
            return false
        }
        
        updatedGame.words.append(contentsOf: words)
        if let index = games.firstIndex(where: { $0.id == gameID }) {
            games[index] = updatedGame
        }
        saveGames()
        return true
    }
    
    /**
     * Marks a game as started
     *
     * @param game The game to start
     * @return Updated game with isStarted flag set to true
     */
    func startGame(gameID: UUID) -> Bool {
        guard var updatedGame = games.first(where: { $0.id == gameID }) else {
            return false
        }
        
        updatedGame.isStarted = true
        if let index = games.firstIndex(where: { $0.id == gameID }) {
            games[index] = updatedGame
        }
        saveGames()
        return true
    }
    
     /**
     * Loads users from persistent storage
     */
    func loadUsers() {
        db.collection("users").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error loading users: $error)")
            } else {
                self.users = querySnapshot!.documents.compactMap { document in
                    try? document.data(as: SpellGameUser.self)
                }
            }
        }
    }
    
    /**
     * Saves users to persistent storage
     */
    func saveUsers() {
        for user in users {
            do {
                try db.collection("users").document(user.id).setData(from: user)
            } catch {
                print("Error saving user: $error)")
            }
        }
    }
    
    /**
     * Loads games from persistent storage
     */
    func loadGames() {
        db.collection("games").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error loading games: $error)")
            } else {
                self.games = querySnapshot!.documents.compactMap { document in
                    try? document.data(as: MultiUserGame.self)
                }
            }
        }
    }
    
    /**
     * Saves games to persistent storage
     */
    func saveGames() {
        for game in games {
            do {
                try db.collection("games").document(game.id.uuidString).setData(from: game)
            } catch {
                print("Error saving game: $error)")
            }
        }
    }
    
    //gets user object given a User ID
    func getUser(by id: String) -> SpellGameUser? {
        return users.first { $0.id == id }
    }
    
    //gets username for all participants
    func getParticipantNames(for game: MultiUserGame) -> [String] {
        return game.participants.compactMap { $0.username }
    }
    
    //gets the username of the creator
    func getCreatorName(for game: MultiUserGame) -> String? {
        return game.creator.username
    }
}
