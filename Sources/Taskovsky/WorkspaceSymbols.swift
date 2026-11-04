import SwiftUI
import AppKit

struct ListSymbol: View {
    let symbol: String?
    var size: CGFloat = 16
    var body: some View {
        Group {
            if let symbol, !symbol.isEmpty, NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil { Text(symbol) }
            else { Image(systemName: symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "line.3.horizontal") }
        }.font(.system(size: size)).frame(width: size + 4, height: size + 4)
    }
}

struct SidebarHeading: View {
    let title: String
    @Binding var expanded: Bool
    let onAdd: () -> Void
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 5) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(expanded ? 90 : 0)).font(.system(size: 8, weight: .medium))
                    Text(title).font(.system(size: 12, weight: .medium)); Spacer()
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel((expanded ? "Collapse " : "Expand ") + title)
            Button(action: onAdd) { Image(systemName: "plus").font(.system(size: 12)) }.buttonStyle(.plain)
                .opacity(hovered ? 1 : 0).help("Add " + (title == "Tags" ? "tag" : title == "Filters" ? "filter" : "list"))
                .accessibilityLabel("Add " + (title == "Tags" ? "tag" : title == "Filters" ? "filter" : "list"))
        }.foregroundStyle(.secondary).padding(.horizontal, 5).padding(.bottom, 6).onHover { hovered = $0 }
    }
}

struct CalendarSymbol: View {
    let text: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).stroke(lineWidth: 1.3)
            VStack(spacing: 1) { Rectangle().frame(height: 1.1).padding(.top, 4); Text(text).font(.system(size: 7, weight: .semibold)); Spacer(minLength: 0) }
        }.frame(width: 16, height: 16)
    }
}

/// Measured TickTick light-mode tokens (sampled from solid glyph runs; see the
/// parent palette result file). Dark mode keeps the existing adaptive behavior.
/// Tag and list colors chosen by the user are never routed through these.
enum Palette {
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.025) : Color(hex: "#FAFAFA")
    }
    static func bodyText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .primary : Color(hex: "#191919")
    }
    static func values(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .secondary : Color(hex: "#737373")
    }
    static func explanatory(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .secondary : Color(hex: "#A0A0A0")
    }
    static func checkboxOutline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .secondary : Color(hex: "#C8C8C8")
    }
    /// Task-row/box outline: a neutral gray around #9C9C9C by same-display
    /// visual estimate (not a measured RGB claim). The measured #C8C8C8 value
    /// above came from a settings checkbox, where it stays.
    static func taskOutline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .secondary : Color(hex: "#9C9C9C")
    }
}

/// Explicitly sized checkbox: a 14pt rounded outline (corner 2-3) carrying the
/// priority color, filled pale with a white tick when completed, crossed when
/// abandoned. Font-based SF squares render smaller than their point size, so
/// the outline is drawn directly.
struct TaskCheckbox: View {
    enum State { case open, completed, wontDo }
    let state: State
    let color: Color
    var size: CGFloat = 14
    var body: some View {
        ZStack {
            switch state {
            case .open:
                RoundedRectangle(cornerRadius: 2.5).strokeBorder(color, lineWidth: 1)
            case .completed:
                RoundedRectangle(cornerRadius: 2.5).fill(Color.primary.opacity(0.12))
                Image(systemName: "checkmark").font(.system(size: size * 0.64, weight: .bold)).foregroundStyle(.white)
            case .wontDo:
                RoundedRectangle(cornerRadius: 2.5).fill(Color.secondary)
                Image(systemName: "xmark").font(.system(size: size * 0.6, weight: .bold)).foregroundStyle(.white)
            }
        }.frame(width: size, height: size)
            // The open state is only a stroked outline, so without an explicit
            // rectangular hit shape its transparent center and corners would
            // not respond to pointer clicks (plain buttons hit-test the label
            // shape, which AX press checks bypass).
            .contentShape(Rectangle())
    }
}
