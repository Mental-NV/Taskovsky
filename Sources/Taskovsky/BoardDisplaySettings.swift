import SwiftUI

enum BoardColumnSize: String, CaseIterable {
    case small, medium, large

    var title: String { rawValue.capitalized }

    var width: CGFloat {
        switch self {
        case .small: 210
        case .medium: 250
        case .large: 320
        }
    }
}

struct BoardDisplaySettings: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var size: BoardColumnSize
    @Binding private var showsTaskInput: Bool
    @State private var draftSize: BoardColumnSize
    @State private var draftShowsTaskInput: Bool

    init(size: Binding<BoardColumnSize>, showsTaskInput: Binding<Bool>) {
        _size = size
        _showsTaskInput = showsTaskInput
        _draftSize = State(initialValue: size.wrappedValue)
        _draftShowsTaskInput = State(initialValue: showsTaskInput.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display Settings").font(.headline)
            Picker("Column width", selection: $draftSize) {
                ForEach(BoardColumnSize.allCases, id: \.self) { size in
                    Text(size.title).tag(size)
                }
            }.pickerStyle(.segmented)
            Toggle("Show Task Input", isOn: $draftShowsTaskInput)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") {
                    size = draftSize
                    showsTaskInput = draftShowsTaskInput
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 380)
    }
}
