import SwiftUI

@main
struct TagarelaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var meetings = MeetingSession()

    var body: some Scene {
        Window("Tagarela", id: "main") {
            NotetakerShell(model: meetings)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
