// GameDetailsView.swift
import SwiftUI
import UIKit

struct RecordingDetails {
    var word: String
    var url: URL?
    var isLocal: Bool = false
    var isPlaying: Bool = false
}

struct GameDetailsView: View {
    @ObservedObject var gameManager: GameManager
    let game: MultiUserGame
    @State private var recordings: [RecordingDetails] = Array(repeating: .init(word: "", url: nil, isLocal: true), count: 5)
    @State private var currentWordIndex = 0
    @State private var isRecording = false
    @Environment(\.presentationMode) var presentationMode
    private let voiceVm = VoiceViewModel()
    
    var body: some View {
        if game.isStarted {
            GamePlayView(game: game)
                .environmentObject(gameManager)
        } else {
            GameSetupView(
                gameManager: gameManager,
                game: game,
                recordings: $recordings,
                currentWordIndex: $currentWordIndex,
                isRecording: $isRecording
            )
            .onAppear(perform: loadExistingWords)
        }
    }
    
    private var recordedCount: Int {
        recordings.filter { $0.url != nil }.count
    }
    
    private var canSubmit: Bool {
        !game.isStarted
    }
    
    private func submitWords() {
        let dispatchGroup = DispatchGroup()
        var words: [Word] = []
        
        for recording in recordings {
            if let url = recording.url, recording.isLocal {
                dispatchGroup.enter()
                gameManager.uploadAudio(gameID: game.id, url: url, word: recording.word) { uploadedUrl in
                    if let uploadedUrl = uploadedUrl, let currentUser = self.gameManager.currentUser {
                        let newWord = Word(
                            word: recording.word,
                            soundURL: URL(string: uploadedUrl),
                            level: 1,
                            createdBy: currentUser,
                            game: self.game
                        )
                        words.append(newWord)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.gameManager.addWords(to: self.game.id, words: words)
            self.presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func loadExistingWords() {
        guard let currentUser = gameManager.currentUser else { return }
        
        // Reset recordings
        recordings = Array(repeating: .init(word: "", url: nil, isLocal: true), count: 5)
        
        // Load words from game
        let userWords = game.words.filter { $0.createdBy == currentUser }
        for (index, word) in userWords.enumerated() where index < 5 {
            recordings[index] = RecordingDetails(
                word: word.word,
                url: word.soundURL,
                isLocal: false
            )
        }
        
        // Set current index to first empty slot or last if all filled
        currentWordIndex = min(userWords.count, 4)
    }
}

// Recording Controls
struct RecordingControls: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var isRecording: Bool
    @Binding var recording: RecordingDetails
    let canRecord: Bool
    let voiceVm: VoiceViewModel
    let game: MultiUserGame
    let onNext: () -> Void
    let onRerecord: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            if isRecording {
                Button(action: stopRecording) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            } else {
                Button(action: startRecording) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(canRecord ? Color.green : Color.gray)
                        .clipShape(Circle())
                }
                .disabled(!canRecord)
                
                if recording.url != nil {
                    Button(action: playRecording) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    
                    Button(action: onRerecord) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    
                    Button(action: onNext) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color.gray)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func startRecording() {
        guard !recording.word.isEmpty else { return }
        voiceVm.startRecording(for: recording.word) { url in
            recording.url = url
            withAnimation { isRecording = true }
        }
    }
    
    private func stopRecording() {
        voiceVm.stopRecording()
        withAnimation { isRecording = false }
    }
    
    private func playRecording() {
        if let url = recording.url {
            if recording.isLocal {
                voiceVm.startPlaying(url: url) {}
            } else {
                // Download from Firebase if not local
                gameManager.downloadAudio(gameID: game.id, word: recording.word) { downloadedUrl in
                    if let downloadedUrl = downloadedUrl {
                        voiceVm.startPlaying(url: downloadedUrl) {}
                    }
                }
            }
        }
    }
}
