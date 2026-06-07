import AppKit

@main
enum LightMDReaderApp {
    @MainActor
    private static let appDelegate = AppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
