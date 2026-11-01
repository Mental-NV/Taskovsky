import SwiftUI
import AppKit

struct PanelDivider: View {
    let drag: (Double, Bool) -> Void
    var body: some View {
        Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1)
            .overlay { Color.clear.frame(width: 9).contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 1).onChanged { drag($0.translation.width, false) }.onEnded { drag($0.translation.width, true) }) }
            .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .accessibilityLabel("Resize panel")
    }
}

struct TaskFeedback: Identifiable {
    enum Kind { case complete, wontDo }
    let id = UUID()
    let taskID: UUID
    let kind: Kind
    let message: String
}

@MainActor enum CompletionSound {
    static var sound: NSSound?
    static func play() {
        if let url = Bundle.main.url(forResource: "completion", withExtension: "wav") { sound = NSSound(contentsOf: url, byReference: true) }
        else { sound = NSSound(named: "Glass") }
        sound?.play()
    }
}
