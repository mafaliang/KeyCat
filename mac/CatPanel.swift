import Cocoa
import WebKit

/// One cat on screen: its floating panel and the web view drawing it. The first is the main cat;
/// with 第二只猫 on there is a second one, whose own settings carry the `cat2.` prefix.
@MainActor
final class CatPanel: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var app: AppDelegate?
    let index: Int
    let panel: NSPanel
    var webView: WebCatView!
    var pageReady = false
    var hit = "none"
    var dragging = false
    var lastCursor = CGPoint(x: -1, y: -1)
    var lastFriend: CGPoint?

    var isMain: Bool { index == 0 }
    /// Prefix of this cat's own keys in UserDefaults (look, position).
    var prefix: String { isMain ? "" : "cat2." }

    init(app: AppDelegate, index: Int) {
        self.app = app
        self.index = index
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        webView = makeWebView()
        panel.contentView = webView
    }

    private func makeWebView() -> WebCatView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(WeakScriptHandler(self), name: "cat")
        config.suppressesIncrementalRendering = true
        // The purr is Web Audio started without a click on the page itself.
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WebCatView(frame: .zero, configuration: config)
        view.cat = self
        view.setValue(false, forKey: "drawsBackground")
        view.underPageBackgroundColor = .clear
        view.navigationDelegate = self
        view.autoresizingMask = [.width, .height]
        if let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            view.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
            app?.log("loading \(index.path) for cat \(self.index + 1)")
        } else {
            app?.log("web/index.html missing from the app bundle")
        }
        return view
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        app?.log("page loaded for cat \(index + 1)")
        pageReady = true
        app?.pageLoaded(self)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        app?.log("page failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        app?.log("page failed to start: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        app?.log("web content process ended; reloading")
        pageReady = false
        webView.reload()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        app?.catMessage(self, body)
    }

    func js(_ script: String) {
        guard pageReady else { return }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// A screen point in the page's CSS pixel space (top-left origin).
    func pagePoint(screen p: CGPoint) -> CGPoint {
        let inWindow = panel.convertPoint(fromScreen: p)
        return CGPoint(x: inWindow.x.rounded(), y: (panel.frame.height - inWindow.y).rounded())
    }

    /// Roughly where the head is on screen; the scene puts it here at any size.
    var headOnScreen: CGPoint {
        CGPoint(x: panel.frame.minX + panel.frame.width * 0.49, y: panel.frame.maxY - panel.frame.height * 0.36)
    }

    /// Only the cat itself takes clicks, and in click-through mode not even that.
    func updateMouseTarget() {
        if !dragging { panel.ignoresMouseEvents = (app?.clickThrough ?? false) || hit == "none" }
    }
}
