import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject var gameManager: GameManager
    let game: MultiUserGame
    @State private var currentWordIndex = 0
    @State private var userInput = ""
    @State private var isPlaying = false
    @State private var timer: Timer?
    @State private var timeElapsed: Double = 0
    @State private var score = 0
    @State private var showResult = false
    @State private var isCorrect = false
    @Environment(\.presentationMode) var presentationMode
    private let voiceVm = VoiceViewModel()
    
    private var wordsToSpell: [Word] {
        game.words.filter { $0.createdByID != gameManager.currentUser?.id }
    }
    
    private var currentWord: Word? {
        wordsToSpell.indices.contains(currentWordIndex) ? wordsToSpell[currentWordIndex] : nil
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Spell the Words")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Score: \(score)")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // Progress
                ProgressView(value: Double(currentWordIndex), total: Double(wordsToSpell.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .animation(.easeInOut, value: currentWordIndex)
                    .padding(.horizontal)
                
                Text("\(currentWordIndex + 1) of \(wordsToSpell.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Word Card
                VStack(spacing: 20) {
                    if let word = currentWord {
                        Button(action: playWord) {
                            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .background(isPlaying ? Color.orange : Color.blue)
                                .clipShape(Circle())
                                .scaleEffect(isPlaying ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isPlaying)
                        }
                        .disabled(isPlaying || timeElapsed > 0)
                        
                        TextField("Type the word", text: $userInput)
                            .textFieldStyle(ModernTextFieldStyle())
                            .disabled(timeElapsed == 0)
                            .submitLabel(.done)
                            .onSubmit { checkSpelling() }
                            .animation(.easeIn, value: timeElapsed > 0)
                        
                        if timeElapsed > 0 {
                            Text("Time: \(String(format: "%.1f", timeElapsed))s")
                                .font(.headline)
                                .foregroundColor(.red)
                                .animation(.linear, value: timeElapsed)
                        }
                    } else {
                        Text("Game Complete!")
                            .font(.title)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .shadow(radius: 5)
                
                // Result Popup
                if showResult {
                    ResultPopup(isCorrect: isCorrect, points: calculatePoints())
                        .transition(.scale)
                }
                
                // Next/Done Button
                if currentWord != nil {
                    Button(action: checkSpelling) {
                        Text("Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                            .scaleEffect(timeElapsed > 0 ? 1.0 : 0.95)
                            .animation(.spring(), value: timeElapsed > 0)
                    }
                    .disabled(timeElapsed == 0)
                } else {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Finish")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onDisappear { timer?.invalidate() }
    }
    
    private func playWord() {
        guard let word = currentWord, let url = word.soundURL else { return }
        
        isPlaying = true
        gameManager.downloadAudio(gameID: game.id, word: word.word) { downloadedUrl in
            if let downloadedUrl = downloadedUrl {
                voiceVm.startPlaying(url: downloadedUrl) {
                    DispatchQueue.main.async {
                        isPlaying = false
                        startTimer()
                    }
                }
            } else {
                isPlaying = false
            }
        }
    }
    
    private func startTimer() {
        timeElapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeElapsed += 0.1
            if timeElapsed >= 10 { // Max 10 seconds
                checkSpelling()
            }
        }
    }
    
    private func checkSpelling() {
        guard let word = currentWord else { return }
        timer?.invalidate()
        
        isCorrect = userInput.lowercased().trimmingCharacters(in: .whitespaces) == word.word.lowercased()
        score += calculatePoints()
        showResult = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showResult = false
                userInput = ""
                timeElapsed = 0
                if currentWordIndex < wordsToSpell.count - 1 {
                    currentWordIndex += 1
                }
            }
        }
    }
    
    private func calculatePoints() -> Int {
        if !isCorrect { return 0 }
        let maxPoints = 100
        let timePenalty = Int(timeElapsed * 10) // 10 points per second
        return max(0, maxPoints - timePenalty)
    }
}

// Result Popup
struct ResultPopup: View {
    let isCorrect: Bool
    let points: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(isCorrect ? .green : .red)
            
            Text(isCorrect ? "Correct!" : "Wrong!")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("+\(points) points")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}


