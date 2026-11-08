import SwiftUI
import TaskovskyCore

struct CalendarTimeZoneSettings: View {
    @Environment(\.dismiss) private var dismiss
    @State var zones: [CalendarTimeZone]
    var primary: TimeZone
    var save: ([CalendarTimeZone]) -> Void
    @State private var picking = false
    @State private var replacing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Zone Settings").font(.headline)
            Label("Current: " + primary.identifier.replacingOccurrences(of: "_", with: " "), systemImage: "globe")
                .foregroundStyle(.secondary)
            Text("Add up to \(CalendarTimeZone.maximumCount) rulers. Labels and order apply only to Calendar; task dates stay the same.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Button(zone.identifier.replacingOccurrences(of: "_", with: " ")) {
                                    replacing = zone.identifier; picking = true
                                }.accessibilityLabel("Change time zone " + zone.identifier)
                                Spacer()
                                Button { zones.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                                    .disabled(index == 0).accessibilityLabel("Move time zone up " + zone.identifier)
                                Button { zones.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }
                                    .disabled(index == zones.count - 1).accessibilityLabel("Move time zone down " + zone.identifier)
                                Button(role: .destructive) { zones.removeAll { $0.identifier == zone.identifier } } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Remove time zone " + zone.identifier)
                            }
                            TextField("Label (optional, up to 32 characters)", text: Binding(get: {
                                zones.first { $0.identifier == zone.identifier }?.label ?? ""
                            }, set: { value in
                                if let position = zones.firstIndex(where: { $0.identifier == zone.identifier }) {
                                    zones[position].label = String(value.prefix(32))
                                }
                            })).accessibilityLabel("Time zone label " + zone.identifier)
                            if zone.identifier == primary.identifier {
                                Text("This is the current zone, so its extra ruler is hidden.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    }
                    if zones.isEmpty { Text("No additional time zones").foregroundStyle(.secondary).padding(20) }
                }
            }
            Button("Add Time Zone…") { replacing = nil; picking = true }
                .disabled(zones.count >= CalendarTimeZone.maximumCount)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save(CalendarTimeZone.normalized(zones)); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 480, height: 440)
            .textFieldStyle(.roundedBorder)
            .onAppear { zones = CalendarTimeZone.normalized(zones) }
            .sheet(isPresented: $picking) {
                CalendarTimeZonePicker(excluded: Set(zones.map(\.identifier).filter { $0 != replacing }).union([primary.identifier])) { identifier in
                    if let replacing, let index = zones.firstIndex(where: { $0.identifier == replacing }) {
                        zones[index].identifier = identifier
                    } else if zones.count < CalendarTimeZone.maximumCount {
                        zones.append(CalendarTimeZone(identifier: identifier))
                    }
                }
            }
    }
}

private struct CalendarTimeZonePicker: View {
    @Environment(\.dismiss) private var dismiss
    var excluded: Set<String>
    var select: (String) -> Void
    @State private var search = ""
    @State private var selected: String?
    private var identifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            !excluded.contains(identifier) && (search.isEmpty ||
                identifier.replacingOccurrences(of: "_", with: " ").localizedStandardContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Time Zone").font(.headline)
            TextField("Search city or region", text: $search).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search time zones")
            List(selection: $selected) {
                ForEach(identifiers, id: \.self) { identifier in
                    Text(identifier.replacingOccurrences(of: "_", with: " "))
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        .contentShape(Rectangle()).tag(identifier)
                        .accessibilityLabel("Time zone " + identifier)
                }
            }.overlay { if identifiers.isEmpty { Text("No matching time zones").foregroundStyle(.secondary) } }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Choose") {
                    if let selected, identifiers.contains(selected) { select(selected); dismiss() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(selected == nil || !identifiers.contains(selected ?? ""))
            }
        }.padding(18).frame(width: 400, height: 400)
            .onChange(of: search) { _, _ in selected = nil }
    }
}
