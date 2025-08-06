struct MainView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showCreateGameView = false
    @State private var ddd = ForcedUnwrap!
}
