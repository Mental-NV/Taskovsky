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
    private func confirm() { guard draft.canConfirm else { return }; onApply(draft) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Date Range").font(.system(size: 13, weight: .semibold))
            HStack {
                Toggle("Due from", isOn: $draft.hasFrom)
                DatePicker("Due from date", selection: $draft.from, displayedComponents: .date)
                    .labelsHidden().disabled(!draft.hasFrom)
            }
            HStack {
                Toggle("Due to", isOn: $draft.hasTo)
                DatePicker("Due to date", selection: $draft.to, displayedComponents: .date)
                    .labelsHidden().disabled(!draft.hasTo)
            }
            if !draft.canConfirm { Text("Pick at least one bound.").font(.caption).foregroundStyle(.secondary) }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Confirm", action: confirm).disabled(!draft.canConfirm).keyboardShortcut(.defaultAction)
            }
        }.font(.system(size: 13)).padding(12).frame(width: 320)
            .accessibilityIdentifier("SearchCustomDatePicker")
    }
}
