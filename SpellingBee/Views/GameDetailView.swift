import SwiftUI
import shared

struct RecordingDetails {
    var word: String
    var url: URL?
    var isLocal: Bool = false
}

struct GameDetailsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let game: MultiUserGame
    @State private var recordings: [RecordingDetails] = Array(repeating: .init(word: "", url: nil, isLocal: true), count: 5)
    @State private var currentWordIndex = 0
    @State private var isRecording = false
    @Environment(\.presentationMode) var presentationMode
    private let voiceVm = VoiceViewModel()
    
    var body: some View {
        if game.isStarted {
            GamePlayView(game: game)
                .environmentObject(viewModel)
        } else {
            GameSetupView(
                game: game,
                recordings: $recordings,
                currentWordIndex: $currentWordIndex,
                isRecording: $isRecording
            )
            .environmentObject(viewModel)
            .onAppear(perform: loadExistingWords)
        }
    }
    
    private var recordedCount: Int {
        recordings.filter { $0.url != nil }.count
    }
    
    private var canSubmit: Bool {
        !game.isStarted && recordedCount > 0
    }
    
    private func submitWords() {
        let dispatchGroup = DispatchGroup()
        var words: [Word] = []
        
        for recording in recordings where recording.url != nil && recording.isLocal {
            if let url = recording.url, let audioData = try? Data(contentsOf: url) {
                dispatchGroup.enter()
                viewModel.uploadAudio(gameId: game.id, word: recording.word, audioData: audioData)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: DispatchWorkItem {
                    // Create Word with the URL from storage
                    let newWord = Word(
                        id: UUID().uuidString,
                        word: recording.word,
                        soundUrl: "https://storage.googleapis.com/recordings/\(game.id)\(recording.word).m4a",
                        level: 1,
                        createdByID: viewModel.currentUser?.id ?? "",
                        gameID: game.id
                    )
                    words.append(newWord)
                    dispatchGroup.leave()
                })
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            viewModel.addWords(to: game.id, words: words)
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func loadExistingWords() {
        guard let currentUser = viewModel.currentUser else { return }
        
        // Reset recordings
        recordings = Array(repeating: .init(word: "", url: nil, isLocal: true), count: 5)
        
        // Load words from game
        let userWords = game.words.filter { $0.createdByID == currentUser.id }
        for (index, word) in userWords.enumerated() where index < 5 {
            recordings[index] = RecordingDetails(
                word: word.word,
                url: word.soundUrl != nil ? URL(string: word.soundUrl!) : nil,
                isLocal: false
            )
        }
        
        // Set current index to first empty slot or last if all filled
        currentWordIndex = min(userWords.count, 4)
    }
    
    
}
