import AppKit
import Foundation

/// Deterministic body-height measurement for the rich editor.
///
/// The editor must size its frame from the laid-out content height. Measuring
/// the live view's `layoutManager.usedRect` is timing-sensitive: at initial
/// load the view still has a zero frame (the text container has no usable
/// width yet), and during typing or resizes the live layout may be mid-flight.
/// This helper lays out a throwaway copy at an explicit width with unbounded
/// height, so initial load, typing, style changes, task switches, and pane
/// resizes all measure the same deterministic way. It never touches the live
/// view, so selection, caret, and undo are unaffected.
public enum RichEditorSizing {
    /// Vertical padding below the text, matching the editor frame math.
    public static let bottomPadding: CGFloat = 8
    /// `textContainerInset.height` used by the editor (top + bottom).
    public static let containerInsetHeight: CGFloat = 4
    /// `lineFragmentPadding` of a default text container (left + right).
    public static let lineFragmentPadding: CGFloat = 5

    /// Height of `content` laid out at `width` points (the editor frame
    /// width), including vertical insets and bottom padding. Widths <= 0
    /// measure at a 1pt floor so the result stays finite and non-zero.
    public static func measuredHeight(
        for content: NSAttributedString,
        width: CGFloat,
        insetHeight: CGFloat = containerInsetHeight,
        bottomPadding: CGFloat = bottomPadding
    ) -> CGFloat {
        let textWidth = max(1, width - lineFragmentPadding * 2)
        let storage = NSTextStorage(attributedString: content)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = lineFragmentPadding
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container).height
        return used + insetHeight * 2 + bottomPadding
    }
}
