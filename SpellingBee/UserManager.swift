
import Foundation
import SwiftUI
import Firebase
import FirebaseAuth



class UserManager: ObservableObject {
    // Published property that will trigger view updates when changed
    @Published var currentUser: SpellGameUser?
    
    /**
     * Registers a new user with the given credentials
     *
     * @param username The display name for the user
     * @param email The email address for authentication
     * @param password The user's password
     * @param completion Callback with result containing User on success or Error on failure
     */
    func register(username: String, email: String, password: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = authResult?.user else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user"])))
                return
            }
            let newUser = SpellGameUser(id: user.uid, username: username, email: email)
            self.currentUser = newUser
            completion(.success(newUser))
        }
    }
    
    /**
     * Authenticates a user with provided credentials
     *
     * @param email The email address for authentication
     * @param password The user's password
     * @param completion Callback with result containing User on success or Error on failure
     */
    func login(email: String, password: String, completion: @escaping (Result<SpellGameUser, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = authResult?.user else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to sign in user"])))
                return
            }
            let loggedInUser = SpellGameUser(id: user.uid, username: "", email: email)
            self.currentUser = loggedInUser
            completion(.success(loggedInUser))
        }
    }
    
    /**
     * Signs out the current user
     */
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

