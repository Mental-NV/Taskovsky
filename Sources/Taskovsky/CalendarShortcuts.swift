import AppKit
import SwiftUI

private enum CalendarShortcutAction: String, CaseIterable {
    case jump, split

    var title: String { self == .jump ? "Jump to Date" : "Toggle Calendar Beside Tasks" }
    var menuTitle: String { self == .jump ? title + "…" : title }

    static let jumpPreference = "Taskovsky.calendarJumpShortcut"
    static let splitPreference = "Taskovsky.calendarSplitShortcut"
    static let defaultJump = "\(NSEvent.ModifierFlags([.command, .shift]).rawValue):j"

    var defaultBinding: String { self == .jump ? Self.defaultJump : "" }
}

private struct CalendarKeyCombination: Equatable {
    let key: Character
    let modifiers: NSEvent.ModifierFlags
    private static let allowed: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    private init?(key: String, modifiers: NSEvent.ModifierFlags) {
        guard key.utf8.count == 1, let byte = key.utf8.first, (97...122).contains(byte),
              modifiers == modifiers.intersection(Self.allowed), modifiers.contains(.command),
              modifiers != .command, let letter = key.first else { return nil }
        self.key = letter
        self.modifiers = modifiers
    }

    init?(storage: String) {
        let fields = storage.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 2, let mask = UInt(fields[0]) else { return nil }
        self.init(key: String(fields[1]), modifiers: .init(rawValue: mask))
    }

    init?(_ event: NSEvent) {
        self.init(key: event.charactersIgnoringModifiers?.lowercased() ?? "",
                  modifiers: event.modifierFlags.intersection(Self.allowed))
    }

    static func effective(_ stored: String, for action: CalendarShortcutAction) -> Self? {
        guard !stored.isEmpty else { return nil }
        return Self(storage: stored) ?? Self(storage: action.defaultBinding)
    }

    var storage: String { "\(modifiers.rawValue):\(key)" }

    var display: String {
        var names: [String] = []
        if modifiers.contains(.control) { names.append("Control") }
        if modifiers.contains(.option) { names.append("Option") }
        if modifiers.contains(.shift) { names.append("Shift") }
        names.append("Command")
        names.append(key.uppercased())
        return names.joined(separator: "–")
    }

    var shortcut: KeyboardShortcut {
        var flags: EventModifiers = .command
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return KeyboardShortcut(KeyEquivalent(key), modifiers: flags)
    }

    @MainActor func conflicts(with menu: NSMenu?) -> Bool {
        // Some commands disappear from the current Settings menu when the
        // main window is inactive. Keep their bindings reserved too.
        if modifiers == [.command, .shift], ["n", "l", "z", "g"].contains(key) { return true }
        if modifiers == [.command, .option], ["s", "w", "q", "h", "m"].contains(key) { return true }
        return menu?.items.contains { item in
            if let submenu = item.submenu, conflicts(with: submenu) { return true }
            return !CalendarShortcutAction.allCases.contains(where: { $0.menuTitle == item.title }) &&
                item.keyEquivalent.lowercased() == String(key) &&
                item.keyEquivalentModifierMask.intersection(Self.allowed) == modifiers
        } ?? false
    }
}

@MainActor
final class CalendarShortcutBindings: ObservableObject {
    private let defaults: UserDefaults
    @Published fileprivate private(set) var jump: String
    @Published fileprivate private(set) var split: String

    init() {
        let defaults = IsolatedDefaults.store
        self.defaults = defaults
        jump = defaults.string(forKey: CalendarShortcutAction.jumpPreference) ?? CalendarShortcutAction.defaultJump
        split = defaults.string(forKey: CalendarShortcutAction.splitPreference) ?? ""
    }

    fileprivate func save(_ value: String, for action: CalendarShortcutAction) {
        switch action {
        case .jump:
            defaults.set(value, forKey: CalendarShortcutAction.jumpPreference)
            jump = value
        case .split:
            defaults.set(value, forKey: CalendarShortcutAction.splitPreference)
            split = value
        }
    }
}

private struct CalendarDateJumpKey: FocusedValueKey { typealias Value = () -> Void }
private struct CalendarSplitToggleKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var calendarDateJump: (() -> Void)? {
        get { self[CalendarDateJumpKey.self] }
        set { self[CalendarDateJumpKey.self] = newValue }
    }

    var calendarSplitToggle: (() -> Void)? {
        get { self[CalendarSplitToggleKey.self] }
        set { self[CalendarSplitToggleKey.self] = newValue }
    }
}

struct CalendarNavigationCommands: Commands {
    @FocusedValue(\.calendarDateJump) private var jump
    @FocusedValue(\.calendarSplitToggle) private var split
    @ObservedObject var shortcuts: CalendarShortcutBindings

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button(CalendarShortcutAction.jump.menuTitle) { jump?() }
                .keyboardShortcut(CalendarKeyCombination.effective(shortcuts.jump, for: .jump)?.shortcut)
                .disabled(jump == nil)
                .id(shortcuts.jump)
            Button(CalendarShortcutAction.split.menuTitle) {
                guard NSApp.keyWindow?.attachedSheet == nil, NSApp.modalWindow == nil else { return }
                split?()
            }
            .keyboardShortcut(CalendarKeyCombination.effective(shortcuts.split, for: .split)?.shortcut)
            .disabled(split == nil)
            .id(shortcuts.split)
        }
    }
}

struct CalendarShortcutSettings: View {
    @ObservedObject var shortcuts: CalendarShortcutBindings
    @State private var recording: CalendarShortcutAction?
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar").font(.headline)
            Text("Use Command, another modifier, and a letter. Press Escape to cancel recording.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(CalendarShortcutAction.allCases, id: \.self) { action in
                HStack(spacing: 12) {
                    Text(action.title)
                    Spacer()
                    Text(recording == action ? "Press shortcut…" : combination(for: action)?.display ?? "Unassigned")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("calendarShortcutValue-" + action.rawValue)
                    Button(recording == action ? "Cancel" : "Record") { beginOrCancel(action) }
                        .accessibilityLabel((recording == action ? "Cancel recording " : "Record ") + action.title + " shortcut")
                    Button("Clear") { save("", for: action) }
                        .accessibilityLabel("Clear " + action.title + " shortcut")
                        .disabled(combination(for: action) == nil)
                }
                Divider()
            }
            Button("Restore Defaults") {
                shortcuts.save(CalendarShortcutAction.defaultJump, for: .jump)
                shortcuts.save("", for: .split)
                cancelRecording()
            }
            if let feedback { Text(feedback).font(.caption).foregroundStyle(.secondary) }
        }
        .background {
            if recording != nil {
                CalendarShortcutRecorder(press: record, cancel: cancelRecording)
                    .frame(width: 0, height: 0).accessibilityHidden(true)
            }
        }
    }

    private func combination(for action: CalendarShortcutAction) -> CalendarKeyCombination? {
        CalendarKeyCombination.effective(action == .jump ? shortcuts.jump : shortcuts.split, for: action)
    }

    private func beginOrCancel(_ action: CalendarShortcutAction) {
        if recording == action { cancelRecording() }
        else { recording = action; feedback = nil }
    }

    private func cancelRecording() {
        recording = nil
        feedback = nil
    }

    private func save(_ value: String, for action: CalendarShortcutAction) {
        shortcuts.save(value, for: action)
        cancelRecording()
    }

    private func record(_ event: NSEvent) {
        guard let action = recording else { return }
        if event.keyCode == 53 { cancelRecording(); return }
        guard let candidate = CalendarKeyCombination(event) else {
            feedback = "Use Command, another modifier, and a letter."
            return
        }
        let other: CalendarShortcutAction = action == .jump ? .split : .jump
        if candidate == combination(for: other) {
            feedback = "That shortcut is assigned to " + other.title + "."
        } else if candidate.conflicts(with: NSApp.mainMenu) {
            feedback = "That shortcut is already used by Taskovsky."
        } else {
            save(candidate.storage, for: action)
        }
    }
}

private struct CalendarShortcutRecorder: NSViewRepresentable {
    let press: (NSEvent) -> Void
    let cancel: () -> Void

    func makeNSView(context: Context) -> KeyView { KeyView(frame: .zero) }
    func updateNSView(_ view: KeyView, context: Context) {
        view.press = press
        view.cancel = cancel
    }
    static func dismantleNSView(_ view: KeyView, coordinator: ()) { view.stopMonitoring() }

    final class KeyView: NSView {
        var press: ((NSEvent) -> Void)?
        var cancel: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard let window else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window, window.isKeyWindow,
                      let press else { return event }
                if !event.isARepeat { press(event) }
                return nil
            }
            NotificationCenter.default.addObserver(self, selector: #selector(resignedKey),
                                                   name: NSWindow.didResignKeyNotification, object: window)
        }

        @objc private func resignedKey() { cancel?() }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        }
    }
}
