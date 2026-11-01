import SwiftUI
import TaskovskyCore

struct TemplatePicker: View {
    @ObservedObject var store: TaskStore
    let onChoose: (TaskTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task Templates").font(.system(size: 20, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if store.data.templates.isEmpty {
                Text("No templates yet. Create one in Settings.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 160), spacing: 12), count: 3), spacing: 12) {
                        ForEach(store.data.templates) { template in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(template.name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                if !template.checklist.isEmpty {
                                    ForEach(Array(template.checklist.prefix(4))) { item in
                                        HStack(alignment: .top, spacing: 5) { Image(systemName: "square"); Text(item.title).lineLimit(1) }
                                            .font(.system(size: 12)).foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text(template.body.isEmpty ? template.title : template.body)
                                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(4)
                                }
                                Spacer(minLength: 4)
                                Button("Use Template") { dismiss(); onChoose(template) }
                                    .tint(accent)
                            }.padding(14).frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }.padding(24).frame(width: 600, height: 420).tint(accent)
    }
}
