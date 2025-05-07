import SwiftUI
import AVFoundation
import Combine
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage


struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showCreateGameView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Spelling Bee")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image("SpellingBee") // Your game logo
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                    }
                    .padding(.horizontal)
                    
                    Text("Welcome, \(gameManager.currentUser?.username ?? "User")!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    // New Game Button
                    Button(action: { showCreateGameView = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Start New Game")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(gradient: Gradient(colors: [.green, .blue]),
                                           startPoint: .leading,
                                           endPoint: .trailing)
                        )
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    }
                    .sheet(isPresented: $showCreateGameView) {
                        CreateGameView(showCreateGameView: $showCreateGameView)
                            .environmentObject(gameManager)
                    }
                    .padding(.horizontal)
                    
                    // Games Display
                    VStack(spacing: 15) {
                        ForEach(gameManager.games.filter { $0.creatorID == gameManager.currentUser?.id || $0.participantsIDs.contains(where: { $0 == gameManager.currentUser?.id }) }) { game in
                            GameCardView(game: game)
                                .environmentObject(gameManager)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(
                Color(.systemBackground)
                    .overlay(
                        Image("SpellingBee") // Optional: Add a subtle game-themed background
                            .resizable()
                            .scaledToFit()
                            .opacity(0.1)
                    )
            )
            .navigationBarHidden(true)
        }
    }
}

// Game Card View
struct GameCardView: View {
    @EnvironmentObject var gameManager: GameManager
    let game: MultiUserGame
    
    var body: some View {
        NavigationLink(destination: GameDetailsView(gameManager: gameManager, game: game)) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Text("Game by \(gameManager.getCreatorName(for: game) ?? "")")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    StatusBadge(isStarted: game.isStarted)
                }
                
                // Details
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.gray)
                    Text("\(game.participantsIDs.count) Players")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(timeAgoSince(date: game.creationDate))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Word Progress
                VStack(alignment: .leading, spacing: 5) {
                    Text("Word Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(game.participantsIDs), id: \.self) { participantID in
                        if let participant = gameManager.getUser(by: participantID) {
                            WordProgressRow(participant: participant, game: game)
                        }
                    }
                }
            }
            .padding()
            .background(
                Color(.systemGray6)
                    .cornerRadius(15)
                    .shadow(color: game.isStarted ? .green.opacity(0.3) : .gray.opacity(0.2), radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(game.isStarted ? Color.green : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Prevents default NavigationLink styling
    }
    
    func timeAgoSince(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Status Badge
struct StatusBadge: View {
    let isStarted: Bool
    
    var body: some View {
        Text(isStarted ? "Active" : "Pending")
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isStarted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            .foregroundColor(isStarted ? .green : .orange)
            .cornerRadius(8)
    }
}

// Word Progress Row
struct WordProgressRow: View {
    let participant: SpellGameUser
    let game: MultiUserGame
    
    var body: some View {
        HStack(spacing: 8) {
            Text(participant.username)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)
            
            ProgressView(value: Float(wordCount), total: 5)
                .progressViewStyle(LinearProgressViewStyle(tint: wordCount == 5 ? .green : .blue))
                .frame(height: 8)
            
            Text("\(wordCount)/5")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var wordCount: Int {
        game.words.filter { $0.createdByID == participant.id }.count
    }
}

struct GameSection: View {
    let title: String
    let games: [MultiUserGame]
    let gameManager: GameManager = .init()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                ForEach(games) { game in
                    NavigationLink(destination: GameDetailsView(gameManager: gameManager, game: game)) {
                        Text("Game - Created by \(gameManager.getUser(by: game.creatorID)?.username) \(timeAgoSince(date: game.creationDate)) ago")
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(height: 150)
        }
    }
    
    func timeAgoSince(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var userManager = UserManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            if gameManager.currentUser != nil {
                MainView()
                    .environmentObject(userManager)
                    .environmentObject(gameManager)
            } else {
                LoginRegisterView()
                    .environmentObject(userManager)
                    .environmentObject(gameManager)
            }
        }
        .preferredColorScheme(colorScheme) // Adapts to system dark/light mode
    }
}




// Participant Row (reused from previous code)
struct ParticipantRow: View {
    let participant: SpellGameUser?
    let game: MultiUserGame
    
    var body: some View {
        if let participant = participant {
            HStack {
                Text(participant.username)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(wordCount)/5 words")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var wordCount: Int {
        game.words.filter { $0.createdByID == participant?.id }.count
    }
}

