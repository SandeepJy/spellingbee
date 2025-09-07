// GameDetailsView.swift
import SwiftUI
import UIKit

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
        !game.isStarted
    }
    
    private func submitWords() {
        let dispatchGroup = DispatchGroup()
        var words: [Word] = []
        
        for recording in recordings {
            if let url = recording.url, recording.isLocal {
                dispatchGroup.enter()
                // Convert URL to Data
                if let audioData = try? Data(contentsOf: url) {
                    viewModel.uploadAudio(gameId: game.id, word: recording.word, audioData: audioData)
                    
                    if let currentUser = viewModel.currentUser {
                        let newWord = Word(
                            text: recording.word,
                            audioUrl: nil, // Will be set after upload
                            recordedBy: currentUser.id
                        )
                        words.append(newWord)
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.viewModel.addWords(to: self.game.id, words: words)
            self.presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func loadExistingWords() {
        guard let currentUser = viewModel.currentUser else { return }
        
        // Reset recordings
        recordings = Array(repeating: .init(word: "", url: nil, isLocal: true), count: 5)
        
        // Load words from game
        let userWords = game.words.filter { $0.recordedBy == currentUser.id }
        for (index, word) in userWords.enumerated() where index < 5 {
            recordings[index] = RecordingDetails(
                word: word.text,
                url: word.audioUrl != nil ? URL(string: word.audioUrl!) : nil,
                isLocal: false
            )
        }
        
        // Set current index to first empty slot or last if all filled
        currentWordIndex = min(userWords.count, 4)
    }
}

// Recording Controls
struct RecordingControls: View {
    @EnvironmentObject var viewModel: AppViewModel
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
                viewModel.downloadAudio(gameId: game.id, word: recording.word) { audioData in
                    if let audioData = audioData {
                        // Save to temporary file and play
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_\(recording.word).m4a")
                        try? audioData.write(to: tempURL)
                        voiceVm.startPlaying(url: tempURL) {}
                    }
                }
            }
        }
    }
}
