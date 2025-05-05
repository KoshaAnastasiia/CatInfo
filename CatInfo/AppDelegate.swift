import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!
    private var mainRouter: MainRouter?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize.width = 800
        window.minSize.height = 400
        window.center()
        window.title = "Cat Breeds"
        
        let serviceGraph = ServiceGraph()
        let router = MainRouter(
            window: window,
            serviceGraph: serviceGraph
        )
        
        self.mainRouter = router
        
        router.start()
        
        self.window = window
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Any cleanup needed
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

