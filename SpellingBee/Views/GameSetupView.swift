import SwiftUI

struct GameSetupView: View {
    @ObservedObject var gameManager: GameManager
    let game: MultiUserGame
    @Binding var recordings: [RecordingDetails]
    @Binding var currentWordIndex: Int
    @Binding var isRecording: Bool
    
    private let voiceVm = VoiceViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Game Details")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    StatusBadge(isStarted: game.isStarted)
                }
                .padding(.horizontal)
                
                Text("Created by \(gameManager.getCreatorName(for: game) ?? "")")
                    .foregroundColor(.secondary)
                
                // Participants
                VStack(alignment: .leading, spacing: 10) {
                    Text("Participants \(game.participantsIDs.count))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(Array(game.participantsIDs), id: \.self) { participantID in
                        if let participant = gameManager.getUser(by: participantID) {
                            ParticipantRow(participant: participant, game: game)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Recording Section
                VStack(spacing: 15) {
                    Text("Record Your Words \(recordedCount)/5")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter word \(currentWordIndex + 1)", text: $recordings[currentWordIndex].word)
                        .textFieldStyle(ModernTextFieldStyle())
                        .disabled(isRecording || game.isStarted)
                    
                    RecordingControls(
                        isRecording: $isRecording,
                        recording: $recordings[currentWordIndex],
                        canRecord: !recordings[currentWordIndex].word.isEmpty && !game.isStarted,
                        voiceVm: voiceVm,
                        game: game,
                        onNext: {
                            if currentWordIndex < 4 {
                                currentWordIndex += 1
                            }
                        },
                        onRerecord: {
                            recordings[currentWordIndex].url = nil // Clear existing recording
                        }
                    )
                    .environmentObject(gameManager)
                    
                    // Recorded Words List
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<5) { index in
                            RecordedWordRow(
                                recording: recordings[index],
                                index: index,
                                isCurrent: index == currentWordIndex,
                                onTap: {
                                    if !game.isStarted {
                                        currentWordIndex = index
                                    }
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Action Buttons
                if canSubmit {
                    Button(action: submitWords) {
                        Text("Submit Words")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                
                if game.creatorID == gameManager.currentUser?.id && !game.isStarted {
                    Button(action: { gameManager.startGame(gameID: game.id) }) {
                        Text("Start Game")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    var recordedCount: Int {
        recordings.filter { !$0.word.isEmpty }.count
    }
    
    var canSubmit: Bool {
        // Add your condition to check if words can be submitted
        return true
    }
    
    func submitWords() {
        // Implement the logic to submit words
    }
}


// Recorded Word Row
struct RecordedWordRow: View {
    let recording: RecordingDetails
    let index: Int
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("Word \(index + 1): \(recording.word.isEmpty ? "Not recorded" : recording.word)")
                    .foregroundColor(isCurrent ? .blue : .primary)
                
                Spacer()
                
                if recording.url != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
