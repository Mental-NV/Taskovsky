import SwiftUI
import TaskovskyCore

/// Illustrative local draft only: no store, gestures, focus or persistence.
/// Geometry is a Taskovsky choice, not a recovered TickTick measurement.
struct ListEditorPreview: View {
    var name: String
    var symbol: String
    var tint: Color
    var mode: TaskListViewMode
    var kind: TaskKind

    private var title: String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "List preview" : value
    }
    private var modeName: String {
        switch mode { case .list: return "List"; case .board: return "Board"; case .timeline: return "Timeline" }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preview").font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ListSymbol(symbol: symbol).foregroundStyle(tint)
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
            }
            switch mode {
            case .list:
                VStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        sampleRow(index).padding(.vertical, 12)
                        if index < 2 { Divider() }
                    }
                }
            case .board:
                HStack(alignment: .top, spacing: 8) {
                    ForEach(BoardProjection.Column.allCases, id: \.self) { column in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(column.title)
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            ForEach(0..<(column == .open ? 2 : (kind == .note ? 0 : 1)), id: \.self) { index in
                                sampleRow(index, status: column, compact: true).padding(8)
                                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            case .timeline:
                Text("Timeline arranges scheduled items horizontally. A preview is not available yet.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text("Illustrative \(modeName.lowercased()) layout. Your items are not shown.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustrative \(modeName) preview for \(title). No saved items are displayed.")
    }
    private func sampleRow(_ index: Int, status: BoardProjection.Column = .open, compact: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind == .note ? "doc.text" : status == .completed ? "checkmark.square" : status == .wontDo ? "xmark.square" : "square")
                .font(.system(size: 12)).foregroundStyle(tint)
            Text(compact ? (index == 0 ? "Plan" : "Read") : kind == .note ? "Sample note \(index + 1)" : "Sample task \(index + 1)")
                .font(.system(size: 12)).lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}
