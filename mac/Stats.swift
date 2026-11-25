import Cocoa
import WebKit

/// The 今日小结 window: web/stats.html shows today's counts from the cat's memory, a picture of
/// the cat, and saves the card as a picture. Opening or refreshing it asks the cat to save its
/// memory first, so the numbers are current.
@MainActor
final class StatsWindow: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var app: AppDelegate?
    var window: NSWindow?
    var view: WKWebView?
    private var loaded = false

    init(app: AppDelegate) { self.app = app }

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if loaded { refresh() }
    }

    private func build() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakScriptHandler(self), name: "stats")
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 380, height: 720), configuration: config)
        view.navigationDelegate = self
        view.setValue(false, forKey: "drawsBackground")
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "KeyCat 今日小结"
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.center()
        if let page = Bundle.main.url(forResource: "stats", withExtension: "html", subdirectory: "web") {
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        self.window = window
        self.view = view
    }

    /// The cat posts its memory and a portrait; both come back here through the app.
    func refresh() {
        app?.main.js("cat.saveMemory(); cat.portrait()")
        memoryChanged()
    }

    func memoryChanged() {
        guard loaded, window?.isVisible == true, let app else { return }
        view?.evaluateJavaScript("initStats(\(app.memoryJSON))", completionHandler: nil)
    }

    func showPortrait(_ dataURL: String) {
        guard loaded, dataURL.hasPrefix("data:image/png;base64,"),
              let data = try? JSONSerialization.data(withJSONObject: [dataURL]),
              let json = String(data: data, encoding: .utf8) else { return }
        view?.evaluateJavaScript("showPortrait(\(json)[0])", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        refresh()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let app, let body = message.body as? [String: Any] else { return }
        if let save = body["save"] as? [String: Any], let name = save["name"] as? String, let base64 = save["base64"] as? String {
            app.saveToPictures(name: name, base64: base64)
        } else if body["refresh"] != nil {
            refresh()
        }
    }
}
