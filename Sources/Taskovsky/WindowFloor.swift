import SwiftUI
import AppKit
import TaskovskyCore

/// Main-window-only floor bridge: enforces the exact total-window minimum
/// from measured chrome. SwiftUI's content `minHeight` cannot express the
/// frame floor — with hidden-titlebar chrome adding ~28pt, a 580pt content
/// minimum produced a 608pt frame. This measures frame-vs-content once per
/// window and pins `window.minSize` so the 580pt reference is the FRAME
/// minimum. Settings and pop-up scenes never host this view, and it never
/// touches their windows. No per-layout mutation: it runs once on attach,
/// never during layout passes.
struct WindowFloorBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { FloorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class FloorView: NSView {
        private var applied = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !applied, let window else { return }
            applied = true
            let frame = window.frame
            let contentRect = window.contentRect(forFrameRect: frame)
            let chromeHeight = frame.height - contentRect.height
            let chromeWidth = frame.width - contentRect.width
            // Exact total floor: content minimum plus measured chrome.
            let contentMin = NSSize(
                width: CGFloat(ResponsiveLayout.minWindowWidth),
                height: CGFloat(ResponsiveLayout.contentMinHeight(
                    totalHeight: ResponsiveLayout.minWindowHeight,
                    chromeHeight: Double(chromeHeight)))
            )
            window.minSize = NSSize(
                width: contentMin.width + chromeWidth,
                height: CGFloat(ResponsiveLayout.minWindowHeight)
            )
            // Narrow transition: a window restored at the OLD 382x608 floor
            // steps down to the corrected 382x580 once. Restored custom
            // sizes are never touched.
            if abs(frame.width - 382) < 0.5 && abs(frame.height - 608) < 0.5 {
                window.setFrame(
                    NSRect(origin: frame.origin, size: NSSize(
                        width: contentMin.width + chromeWidth,
                        height: CGFloat(ResponsiveLayout.minWindowHeight)
                    )),
                    display: true
                )
            }
        }
    }
}

/** Routes Escape only while the compact sidebar is mounted in its owning window. */
struct CompactSidebarEscapeInput: NSViewRepresentable {
    let dismiss: () -> Void

    func makeNSView(context: Context) -> InputView {
        let view = InputView(frame: .zero)
        view.dismiss = dismiss
        return view
    }

    func updateNSView(_ view: InputView, context: Context) { view.dismiss = dismiss }

    static func dismantleNSView(_ view: InputView, coordinator: ()) {
        view.stopMonitoring()
        view.dismiss = nil
    }

    final class InputView: NSView {
        var dismiss: (() -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.keyCode == 53,
                      event.window === window, window.isKeyWindow,
                      window.attachedSheet == nil, NSApp.modalWindow == nil,
                      let dismiss = self.dismiss else { return event }
                dismiss()
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
