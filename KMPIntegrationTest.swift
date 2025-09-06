// KMPIntegrationTest.swift
// This file shows how to use your Kotlin Multiplatform code in Swift

import Foundation
// import shared  // Uncomment this after adding the XCFramework to your project

class KMPIntegrationTest {
    
    func testKMPIntegration() {
        // This is how you'll use your KMP code once integrated
        /*
        let gameManager = IOSGameManager()
        
        // Set up callbacks
        gameManager.onUsersChanged = { users in
            print("Users changed: \(users)")
        }
        
        gameManager.onGamesChanged = { games in
            print("Games changed: \(games)")
        }
        
        gameManager.onCurrentUserChanged = { user in
            print("Current user changed: \(user?.username ?? "nil")")
        }
        
        // Load users
        gameManager.loadUsers {
            print("Users loaded")
        }
        
        // Add a user
        gameManager.addUser(id: "123", username: "testuser", email: "test@example.com") {
            print("User added")
        }
        
        // Create a game
        gameManager.createGame(creatorId: "123", participantIds: ["456", "789"]) { gameId in
            print("Game created with ID: \(gameId)")
        }
        */
        
        print("KMP Integration Test - Uncomment the code above after adding XCFramework to your project")
    }
}
