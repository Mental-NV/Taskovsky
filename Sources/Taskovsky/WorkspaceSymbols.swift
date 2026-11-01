import SwiftUI
import AppKit

struct ListSymbol: View {
    let symbol: String?
    var size: CGFloat = 16
    var body: some View {
        Group {
            if let symbol, !symbol.isEmpty, NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil { Text(symbol) }
            else { Image(systemName: symbol.flatMap { $0.isEmpty ? nil : $0 } ?? "list.bullet") }
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
