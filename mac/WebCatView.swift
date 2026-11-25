import Cocoa
import WebKit

/// The web scene's host view. It keeps every mouse event for itself: the page never
/// scrolls or selects; a press on the head pets the cat and a press elsewhere drags the window.
final class WebCatView: WKWebView {
    weak var cat: CatPanel?
    var app: AppDelegate? { cat?.app }
    private var dragStart: (mouse: CGPoint, origin: CGPoint)?
    private var petting = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func scrollWheel(with event: NSEvent) {}
    override func menu(for event: NSEvent) -> NSMenu? { nil }
    override func mouseMoved(with event: NSEvent) { if let cat { app?.refreshCursor(cat) } }

    /// Event location in the page's CSS pixel space (top-left origin).
    func pagePoint(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: p.x, y: bounds.height - p.y)
    }

    override func mouseDown(with event: NSEvent) {
        guard let cat, let app, let window else { return }
        if cat.hit == "pet" {
            petting = true
            app.pet(cat, down: true, x: pagePoint(event).x)
        } else {
            dragStart = (NSEvent.mouseLocation, window.frame.origin)
            cat.dragging = true
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        let m = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(x: start.origin.x + m.x - start.mouse.x, y: start.origin.y + m.y - start.mouse.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard let cat, let app else { return }
        if petting {
            petting = false
            app.pet(cat, down: false, x: 0)
        }
        if dragStart != nil {
            dragStart = nil
            cat.dragging = false
            app.saveOrigin(cat)
        }
        app.refreshCursor(cat)
    }

    override func rightMouseDown(with event: NSEvent) { app?.showMenu(event, in: self) }
}

/// Breaks the retain cycle between WKUserContentController and the app delegate.
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
