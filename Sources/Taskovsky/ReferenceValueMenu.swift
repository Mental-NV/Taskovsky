import SwiftUI

/// A text-only value control avoids NSPopUpButton moving the custom chevrons
/// to the leading edge or coloring every value with the app accent.
struct ReferenceValueMenu<Value: Equatable>: View {
    @Binding var selection: Value
    let options: [(String, Value)]
    var title = ""
    @State private var open = false
    @State private var highlighted = 0
    @FocusState private var keyboardFocused: Bool
    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                Text(options.first { $0.1 == selection }?.0 ?? "None").lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
            }.foregroundStyle(.secondary).frame(maxWidth: 190, alignment: .trailing).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button { selection = option.1; open = false } label: {
                            HStack(spacing: 20) {
                                Text(option.0); Spacer(minLength: 0)
                                Image(systemName: "checkmark").opacity(selection == option.1 ? 1 : 0)
                            }.foregroundStyle(selection == option.1 ? accent : .primary).padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain).background(index == highlighted ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel(title.isEmpty ? option.0 : title + ": " + option.0)
                    }
                }.font(.system(size: 14)).padding(5).fixedSize(horizontal: true, vertical: true)
                    .background(Color(nsColor: .textBackgroundColor))
                    .focusable().focusEffectDisabled().focused($keyboardFocused)
                    .onAppear { highlighted = options.firstIndex { $0.1 == selection } ?? 0; keyboardFocused = true }
                    .onKeyPress(.downArrow) { highlighted = min(options.count - 1, highlighted + 1); return .handled }
                    .onKeyPress(.upArrow) { highlighted = max(0, highlighted - 1); return .handled }
                    .onKeyPress(.return) { if options.indices.contains(highlighted) { selection = options[highlighted].1 }; open = false; return .handled }
                    .onExitCommand { open = false }
            }
    }
}
