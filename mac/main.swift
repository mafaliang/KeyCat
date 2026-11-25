import Cocoa
import WebKit

/// `KeyCat --snapshot <file.png> [--js <setup>]` renders the bundled scene in the app's own WKWebView,
/// presses a key, and writes what WebKit drew. Used to check WebGL and transparency.
@MainActor
final class SnapshotRunner: NSObject, WKNavigationDelegate {
    let output: URL
    /// Script run before the probe, e.g. `cat.options({coat: 'orange'})` (`--js`).
    let setup: String
    var window: NSWindow!
    var view: WKWebView!

    init(output: URL, setup: String) { self.output = output; self.setup = setup }

    func start() {
        // On screen but nearly invisible: WebKit throttles animation frames for off-screen windows.
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: designSize.width, height: designSize.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.02
        window.ignoresMouseEvents = true
        view = WKWebView(frame: CGRect(origin: .zero, size: designSize))
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = self
        window.contentView = view
        window.orderFrontRegardless()
        guard let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") else {
            FileHandle.standardError.write("web/index.html missing from bundle\n".data(using: .utf8)!)
            exit(1)
        }
        view.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("\(setup); cat.cursor(300, 40); cat.key('KeyF', true); cat.state.ticks = 0; 1", completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let probe = "JSON.stringify({rafPerSec: cat.state.ticks, head: cat.hitTest(171, 135), body: cat.hitTest(171, 240), empty: cat.hitTest(20, 20)})"
            webView.evaluateJavaScript(probe) { result, _ in
                print("page state after 1s:", result ?? "nil")
                self.capture()
            }
        }
    }

    func capture() {
        view.takeSnapshot(with: nil) { image, error in
            guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!)
                exit(1)
            }
            try? png.write(to: self.output)
            exit(0)
        }
    }
}

/// `KeyCat --settings-check <file.png>` opens the 调节 window, moves its first slider the way a
/// user would, prints what got saved, draws the window to the file and puts the old setting back.
@MainActor
final class SettingsCheck {
    let output: URL
    let delegate = AppDelegate()
    var saved: Any?

    init(output: URL) { self.output = output }

    func start() {
        saved = delegate.defaults.object(forKey: "tune")
        delegate.settings.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.move() }
    }

    func move() {
        let script = "const r = document.querySelector('input[type=range]'); r.value = 13; r.dispatchEvent(new Event('input')); 1"
        delegate.settings.view?.evaluateJavaScript(script) { _, error in
            if let error { print("slider script failed:", error) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.finish() }
        }
    }

    func finish() {
        print("saved tune:", delegate.tune)
        delegate.settings.view?.takeSnapshot(with: nil) { image, _ in
            if let tiff = image?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: self.output)
            }
            if let saved = self.saved { self.delegate.defaults.set(saved, forKey: "tune") } else { self.delegate.defaults.removeObject(forKey: "tune") }
            exit(0)
        }
    }
}

/// `KeyCat --pair-check <dir>` puts two cats side by side (nearly invisible), has the first swat
/// the second, prints what each page knows about the other and snapshots both into <dir>.
@MainActor
final class PairCheck {
    let delegate = AppDelegate()
    let dir: URL

    init(dir: URL) { self.dir = dir }

    func start() {
        delegate.statusReports = false
        delegate.cats = [CatPanel(app: delegate, index: 0), CatPanel(app: delegate, index: 1)]
        for (i, cat) in delegate.cats.enumerated() {
            cat.panel.setFrame(CGRect(x: CGFloat(400 - i * 260), y: 200, width: designSize.width, height: designSize.height), display: true)
            cat.panel.alphaValue = 0.02
            cat.panel.orderFrontRegardless()
        }
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { _ in MainActor.assumeIsolated { self.delegate.tick() } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.delegate.cats[1].js("const f = cat.friendEvent; cat.friendEvent = k => { window.got = k; f(k); }; 1")
            self.delegate.cats[0].js("window.webkit.messageHandlers.cat.postMessage({ friend: 'swat' })")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.report(0) }
    }

    func report(_ i: Int) {
        guard i < delegate.cats.count else { exit(0) }
        let view = delegate.cats[i].webView!
        view.evaluateJavaScript("JSON.stringify({ friend: cat.state.friend, got: window.got || null })") { result, _ in
            print("cat \(i + 1):", result ?? "nil")
            view.takeSnapshot(with: nil) { image, _ in
                if let tiff = image?.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: self.dir.appendingPathComponent("cat\(i + 1).png"))
                }
                self.report(i + 1)
            }
        }
    }
}

let app = NSApplication.shared
let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--pair-check"), i + 1 < arguments.count {
    let check = MainActor.assumeIsolated { PairCheck(dir: URL(fileURLWithPath: arguments[i + 1])) }
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated { check.start() }
    app.run()
} else if let i = arguments.firstIndex(of: "--settings-check"), i + 1 < arguments.count {
    let check = MainActor.assumeIsolated { SettingsCheck(output: URL(fileURLWithPath: arguments[i + 1])) }
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated { check.start() }
    app.run()
} else if let i = arguments.firstIndex(of: "--snapshot"), i + 1 < arguments.count {
    let setup = arguments.firstIndex(of: "--js").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil } ?? "0"
    let runner = MainActor.assumeIsolated { SnapshotRunner(output: URL(fileURLWithPath: arguments[i + 1]), setup: setup) }
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated { runner.start() }
    app.run()
} else {
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    app.delegate = delegate
    app.run()
}
