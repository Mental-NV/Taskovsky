import SwiftUI
import AppKit

/// Settings scenes retain a native title bar unless the window itself also
/// opts into full-size content. Keep the close control, without a second title.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { DispatchQueue.main.async { configure(view.window) } }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
    }
}
