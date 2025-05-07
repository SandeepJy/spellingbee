import SwiftUI

struct CreateGameView: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var showCreateGameView: Bool
    @State private var selectedUsers = Set<SpellGameUser>()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Game")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            List(gameManager.users.filter { $0.id != gameManager.currentUser?.id }, id: \.self, selection: $selectedUsers) { user in
                Text(user.username)
                    .foregroundColor(.primary)
            }
            .environment(\.editMode, .constant(.active))
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button(action: createGame) {
                Text("Create Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func createGame() {
        if let currentUser = gameManager.currentUser {
            var participantsIDs = selectedUsers.map { $0.id }
            participantsIDs.append(currentUser.id)
            gameManager.createGame(creatorID: currentUser.id, participantsIDs: Set(participantsIDs))
            showCreateGameView = false
        }
    }
}

