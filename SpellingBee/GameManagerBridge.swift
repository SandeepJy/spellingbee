import Foundation
import shared
import Combine

class GameManagerBridge: ObservableObject {
    @Published var users: [User] = []
    @Published var currentUser: User?
    @Published var games: [Game] = []
    
    private let kmpManager: IOSGameManager
    private var cancellables = Set<AnyCancellable>()
    
    // Define Swift versions of your models
    struct User: Identifiable, Hashable {
        let id: String
        let username: String
        let email: String
    }
    
    struct Game: Identifiable {
        let id: String
        let creatorId: String
        let participantIds: Set<String>
        let words: [GameWord]
        let creationDate: Date
        let isStarted: Bool
    }
    
    struct GameWord {
        let text: String
        let audioUrl: String?
        let recordedBy: String?
    }
    
    init() {
        kmpManager = IOSGameManager()
        setupBindings()
        loadInitialData()
    }
    
    private func setupBindings() {
        kmpManager.onUsersChanged = { [weak self] kmpUsers in
            DispatchQueue.main.async {
                self?.users = kmpUsers.map { kmpUser in
                    User(
                        id: kmpUser.id,
                        username: kmpUser.username,
                        email: kmpUser.email
                    )
                }
            }
        }
        
        kmpManager.onCurrentUserChanged = { [weak self] kmpUser in
            DispatchQueue.main.async {
                if let kmpUser = kmpUser {
                    self?.currentUser = User(
                        id: kmpUser.id,
                        username: kmpUser.username,
                        email: kmpUser.email
                    )
                } else {
                    self?.currentUser = nil
                }
            }
        }
        
        kmpManager.onGamesChanged = { [weak self] kmpGames in
            DispatchQueue.main.async {
                self?.games = kmpGames.map { self?.convertGame($0) ?? Game(id: "", creatorId: "", participantIds: [], words: [], creationDate: Date(), isStarted: false) }
            }
        }
    }
    
    private func convertGame(_ kmpGame: MultiUserGame) -> Game {
        return Game(
            id: kmpGame.id,
            creatorId: kmpGame.creatorId,
            participantIds: kmpGame.participantIds,
            words: kmpGame.words.map { word in
                GameWord(
                    text: word.text,
                    audioUrl: word.audioUrl,
                    recordedBy: word.recordedBy
                )
            },
            creationDate: Date(timeIntervalSince1970: TimeInterval(kmpGame.creationDate / 1000)),
            isStarted: kmpGame.isStarted
        )
    }
    
    private func loadInitialData() {
        kmpManager.loadUsers { }
    }
    
    func addUser(id: String, username: String, email: String) {
        kmpManager.addUser(id: id, username: username, email: email) { }
    }
    
    func createGame(creatorId: String, participantIds: Set<String>, completion: @escaping (String) -> Void) {
        kmpManager.createGame(creatorId: creatorId, participantIds: participantIds, completion: completion)
    }
    
    func setCurrentUser(_ user: User) {
        let kmpUser = SpellGameUser(id: user.id, username: user.username, email: user.email)
        kmpManager.setCurrentUser(user: kmpUser) { }
    }
    
    deinit {
        kmpManager.dispose()
    }
}
