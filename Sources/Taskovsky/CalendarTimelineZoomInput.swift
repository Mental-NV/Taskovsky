import AppKit
import SwiftUI
import TaskovskyCore

/// Limits the two zoom inputs to the visible hourly scroll view.
struct CalendarTimelineZoomInput: NSViewRepresentable {
    let scale: CalendarTimelineScale
    let changeScale: (CalendarTimelineScale) -> Void

    func makeNSView(context: Context) -> InputView { InputView(frame: .zero) }

    func updateNSView(_ view: InputView, context: Context) {
        view.changeScale = changeScale
        view.updateScale(scale)
    }

    static func dismantleNSView(_ view: InputView, coordinator: ()) { view.stopMonitoring() }

    final class InputView: NSView {
        private struct Anchor {
            let hour: Double
            let windowPoint: CGPoint
        }

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        var changeScale: ((CalendarTimelineScale) -> Void)?
        private var scale = CalendarTimelineScale.standard
        private var requestedScale: CalendarTimelineScale?
        private var anchor: Anchor?
        private var restoreScheduled = false
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .scrollWheel]) { [weak self] event in
                self?.handleZoom(event) == true ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            anchor = nil
            requestedScale = nil
        }

        private func handleZoom(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, window.isKeyWindow,
                  window.attachedSheet == nil, NSApp.modalWindow == nil,
                  NSEvent.pressedMouseButtons == 0,
                  let clip = enclosingScrollView?.contentView,
                  clip.visibleRect.contains(clip.convert(event.locationInWindow, from: nil)) else { return false }

            let factor: Double
            if event.type == .magnify {
                factor = 1 + event.magnification
            } else {
                guard event.modifierFlags.contains(.control), event.scrollingDeltaY != 0 else { return false }
                guard event.momentumPhase.isEmpty else { return true }
                factor = exp(event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.008 : 0.12))
            }
            let current = requestedScale ?? scale
            let updated = current.scaled(by: factor)
            guard updated != current else { return true }
            if anchor == nil { anchor = makeAnchor(at: event.locationInWindow) }
            requestedScale = updated
            changeScale?(updated)
            return true
        }

        func updateScale(_ updated: CalendarTimelineScale) {
            if updated == scale {
                // Opposite input events may cancel before SwiftUI publishes either change.
                if requestedScale == updated {
                    requestedScale = nil
                    if !restoreScheduled { anchor = nil }
                }
                return
            }
            if anchor == nil, let clip = enclosingScrollView?.contentView {
                let visible = clip.visibleRect
                anchor = makeAnchor(at: clip.convert(CGPoint(x: visible.midX, y: visible.midY), to: nil))
            }
            scale = updated
            if requestedScale == updated { requestedScale = nil }
            guard !restoreScheduled else { return }
            restoreScheduled = true
            // SwiftUI lays out the newly sized grid after updating the bridge.
            DispatchQueue.main.async { [weak self] in self?.restoreAnchor() }
        }

        private func makeAnchor(at point: CGPoint) -> Anchor {
            Anchor(hour: scale.hour(at: convert(point, from: nil).y - bounds.minY), windowPoint: point)
        }

        private func restoreAnchor() {
            restoreScheduled = false
            // A second event can arrive before SwiftUI publishes its scale.
            if let requestedScale, requestedScale != scale { return }
            defer { anchor = nil; requestedScale = nil }
            guard let anchor, let scroll = enclosingScrollView, let window else { return }
            window.contentView?.layoutSubtreeIfNeeded()
            let clip = scroll.contentView
            let target = convert(CGPoint(x: 0, y: bounds.minY + scale.offset(at: anchor.hour)), to: clip)
            let original = clip.convert(anchor.windowPoint, from: nil)
            var proposed = clip.bounds
            proposed.origin.y += target.y - original.y
            clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
            scroll.reflectScrolledClipView(clip)
        }
    }
}
