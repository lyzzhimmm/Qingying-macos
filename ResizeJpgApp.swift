import SwiftUI

@main
struct PhotoResizerApp: App {
    @StateObject private var processor = ProfessionalImageProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(processor)
        }.windowStyle(.hiddenTitleBar)
    }
}
