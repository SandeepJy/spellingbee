import SwiftUI
import shared

struct CreateGameView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var showCreateGameView: Bool
    @State private var selectedUsers = Set<SpellGameUser>()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Game")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            List(viewModel.users.filter { $0.id != viewModel.currentUser?.id }, id: \.self, selection: $selectedUsers) { user in
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
        if let currentUser = viewModel.currentUser {
            var participants = selectedUsers
            participants.insert(currentUser)
            viewModel.createGame(creator: currentUser, participants: participants)
            showCreateGameView = false
        }
    }
}