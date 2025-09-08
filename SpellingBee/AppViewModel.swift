import SwiftUI
import Combine
import shared

@MainActor
class AppViewModel: ObservableObject {
    // KMP Manager
    private let kmpManager = IOSGameManager()
    
    // Published properties for UI
    @Published var currentUser: SpellGameUser?
    @Published var users: [SpellGameUser] = []
    @Published var games: [MultiUserGame] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Auth state
    @Published var isAuthLoading = false
    @Published var authError: String?
    
    // Storage state
    @Published var isUploading = false
    @Published var storageError: String?
    
    private var cancellables = Set<AnyCancellable>()
    @Published var userProgress: [String: UserGameProgress] = [:]

    
    init() {
        setupCallbacks()
        loadInitialData()
    }
    
    private func setupCallbacks() {
        // Game state callbacks
        kmpManager.onUsersChanged = { [weak self] users in
            self?.users = users
        }
        
        kmpManager.onGamesChanged = { [weak self] games in
            self?.games = games
        }
        
        kmpManager.onCurrentUserChanged = { [weak self] user in
            self?.currentUser = user
        }
        
        kmpManager.onIsLoadingChanged = { [weak self] loading in
            self?.isLoading = loading.boolValue
        }
        
        kmpManager.onErrorChanged = { [weak self] error in
            self?.errorMessage = error
        }
        
        // Auth state callbacks
        kmpManager.onAuthUserChanged = { [weak self] user in
            self?.currentUser = user
        }
        
        kmpManager.onAuthLoadingChanged = { [weak self] loading in
            self?.isAuthLoading = loading.boolValue
        }
        
        kmpManager.onAuthErrorChanged = { [weak self] error in
            self?.authError = error
        }
        
        // Storage state callbacks
        kmpManager.onStorageLoadingChanged = { [weak self] uploading in
            self?.isUploading = uploading.boolValue
        }
        
        kmpManager.onStorageErrorChanged = { [weak self] error in
            self?.storageError = error
        }

        kmpManager.onUserProgressChanged = { [weak self] progress in
            // Convert Map to Dictionary
            var progressDict: [String: UserGameProgress] = [:]
                progress.forEach { (key, value) in
                    progressDict[key] = value
                }
                self?.userProgress = progressDict
        }
    }
    
    private func loadInitialData() {
        kmpManager.loadUsers { }
        kmpManager.loadGames { }
        kmpManager.loadUserProgress { }

    }
    
    // MARK: - Authentication
    
    func register(username: String, email: String, password: String) {
        clearErrors()
        let completion: (SpellGameUser?, String?) -> Void = { [weak self] user, error in
            if let user = user {
                self?.currentUser = user
            } else if let error = error {
                self?.authError = error
            }
        }
        kmpManager.register(username: username, email: email, password: password, completion: completion)
    }
    
    func login(email: String, password: String) {
        clearErrors()
        let completion: (SpellGameUser?, String?) -> Void = { [weak self] user, error in
            if let user = user {
                self?.currentUser = user
            } else if let error = error {
                self?.authError = error
            }
        }
        kmpManager.login(email: email, password: password, completion: completion)
    }
    
    func signOut() {
        let completion: (KotlinBoolean, String?) -> Void = { [weak self] success, error in
            if success.boolValue {
                self?.currentUser = nil
            } else if let error = error {
                self?.authError = error
            }
        }
        kmpManager.signOut(completion: completion)
    }
    
    // MARK: - Game Management
    
    func createGame(creator: SpellGameUser, participants: Set<SpellGameUser>) {
        let participantIds = Set(participants.map { $0.id })
        kmpManager.createGame(creatorId: creator.id, participantIds: participantIds) { gameId in
            print("Game created with ID: \(gameId)")
            // Games will be updated via callback
        }
    }
    
    func addWords(to gameId: String, words: [Word]) {
        let completion: (KotlinBoolean) -> Void = { [weak self] success in
            if success.boolValue {
                print("Words added successfully")
            } else {
                self?.errorMessage = "Failed to add words"
            }
        }
        kmpManager.addWords(gameId: gameId, words: words, completion: completion)
    }
    
    func startGame(gameId: String) {
        let completion: (KotlinBoolean) -> Void = { [weak self] success in
            if success.boolValue {
                print("Game started successfully")
            } else {
                self?.errorMessage = "Failed to start game"
            }
        }
        kmpManager.startGame(gameId: gameId, completion: completion)
    }
    
    // MARK: - Audio Storage
    
    func uploadAudio(gameId: String, word: String, audioData: Data) {
        let byteArray = KotlinByteArray(size: Int32(audioData.count))
        for (index, byte) in audioData.enumerated() {
            byteArray.set(index: Int32(index), value: Int8(byte))
        }
        
        let completion: (String?, String?) -> Void = { [weak self] url, error in
            if let url = url {
                print("Audio uploaded: \(url)")
            } else if let error = error {
                self?.storageError = error
            }
        }
        kmpManager.uploadAudio(gameId: gameId, word: word, audioData: byteArray, completion: completion)
    }
    
    func downloadAudio(gameId: String, word: String, completion: @escaping (URL?) -> Void) {
        let kmpCompletion: (KotlinByteArray?, String?) -> Void = { data, error in
            if let data = data {
                // Convert KotlinByteArray to Swift Data
                let size = Int(data.size)
                var bytes = [UInt8](repeating: 0, count: size)
                for i in 0..<size {
                    let int8Value = data.get(index: Int32(i))
                    bytes[i] = UInt8(bitPattern: int8Value)
                }
                let swiftData = Data(bytes)

                // Save the downloaded Data to a temporary file
                let temporaryFileName = "\(UUID().uuidString).m4a"
                let temporaryDirectory = FileManager.default.temporaryDirectory
                let temporaryFileURL = temporaryDirectory.appendingPathComponent(temporaryFileName)

                do {
                    try swiftData.write(to: temporaryFileURL)
                    completion(temporaryFileURL)
                } catch {
                    print("Error saving downloaded audio to temporary file: \(error)")
                    completion(nil)
                }

            } else {
                print("Download failed: \(error ?? "Unknown error")")
                completion(nil)
            }
        }
        kmpManager.downloadAudio(gameId: gameId, word: word, completion: kmpCompletion)
    }
    
    // MARK: - Utility Methods
    
    func getParticipantNames(for game: MultiUserGame) -> [String] {
        return kmpManager.getParticipantNames(game: game)
    }
    
    func getCreatorName(for game: MultiUserGame) -> String? {
        return kmpManager.getCreatorName(game: game)
    }
    
    func getUser(by id: String) -> SpellGameUser? {
        return users.first { $0.id == id }
    }
    
    func clearErrors() {
        errorMessage = nil
        authError = nil
        storageError = nil
        kmpManager.clearAllErrors()
    }

    func getUserProgress(for gameId: String) -> UserGameProgress? {
        guard let userId = currentUser?.id else { return nil }
        let progressId = UserGameProgress.companion.generateId(userId: userId, gameId: gameId)
        return userProgress[progressId]
    }

    func updateUserProgress(gameId: String, wordIndex: Int, completedWordIndices: [Int], score: Int) -> Bool {
        guard let userId = currentUser?.id else { return false }
        
        let completion: (KotlinBoolean) -> Void = { success in
            if success.boolValue {
                print("Progress updated successfully")
            }
        }
        
        kmpManager.updateUserProgress(
            gameId: gameId,
            userId: userId,
            wordIndex: Int32(wordIndex),
            completedWordIndices: completedWordIndices.map { KotlinInt(integerLiteral: $0) },
            score: Int32(score),
            completion: completion
        )
        return true
    }
    
    deinit {
        kmpManager.dispose()
    }
}
