import SwiftUI

struct SearchCustomDateDraft: Equatable {
    var from: Date
    var hasFrom: Bool
    var to: Date
    var hasTo: Bool
    var canConfirm: Bool { hasFrom || hasTo }
    var lowerBound: Date? { hasFrom ? from : nil }
    var upperBound: Date? { hasTo ? to : nil }
}

struct SearchCustomDatePicker: View {
    let onApply: (SearchCustomDateDraft) -> Void
    let onCancel: () -> Void
    @State private var draft: SearchCustomDateDraft
    init(from: Date, hasFrom: Bool, to: Date, hasTo: Bool,
         onApply: @escaping (SearchCustomDateDraft) -> Void, onCancel: @escaping () -> Void) {
        self.onApply = onApply; self.onCancel = onCancel
        _draft = State(initialValue: SearchCustomDateDraft(from: from, hasFrom: hasFrom, to: to, hasTo: hasTo))
    }
    var body: some View {
        SearchCustomDateForm(draft: $draft, onApply: onApply, onCancel: onCancel)
            .frame(width: 320, height: 174)
            .accessibilityIdentifier("SearchCustomDatePicker")
    }
}
