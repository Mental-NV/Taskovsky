import Foundation
import Combine
import UserNotifications
import TaskovskyWorkspace

/// Conversion is pure and testable without constructing/accessing an OS center.
enum MacNotificationRequestFactory {
    static func owns(identifier: String, metadata: [String: String], prefix: String) -> Bool {
        guard let task = metadata["task"], let uuid = UUID(uuidString: task), uuid.uuidString.lowercased() == task,
              let raw = metadata["instant"], let bits = UInt64(raw, radix: 16), raw == String(bits, radix: 16) else { return false }
        let seconds = Double(bitPattern: bits)
        guard seconds.isFinite else { return false }
        let hex = String((seconds == 0 ? 0.0 : seconds).bitPattern, radix: 16)
        return identifier == prefix + LocalReminderPlan.identifierPrefix + task + "." + String(repeating: "0", count: 16 - hex.count) + hex
    }

    static func request(_ descriptor: MacReminderNotification, now: Date) throws -> UNNotificationRequest {
        guard let raw = descriptor.metadata["instant"], let bits = UInt64(raw, radix: 16) else { throw CocoaError(.coderInvalidValue) }
        let instant = Double(bitPattern: bits)
        guard instant.isFinite, now.timeIntervalSinceReferenceDate.isFinite,
              instant > now.timeIntervalSinceReferenceDate else { throw CocoaError(.coderInvalidValue) }
        let rounded = ceil(instant)
        guard (-63_113_904_000...252_423_993_599).contains(rounded) else { throw CocoaError(.coderInvalidValue) }
        let date = Date(timeIntervalSinceReferenceDate: rounded)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.timeZone = calendar.timeZone; components.calendar = calendar
        guard let rebuilt = calendar.date(from: components), rebuilt == date,
              (1...9999).contains(components.year ?? 0) else { throw CocoaError(.coderInvalidValue) }
        let content = UNMutableNotificationContent()
        content.title = descriptor.title; content.body = descriptor.body; content.sound = .default
        content.userInfo = descriptor.metadata
        return UNNotificationRequest(identifier: descriptor.identifier, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }
}

@MainActor private final class SystemMacReminderCenter: NSObject, MacReminderCenter, UNUserNotificationCenterDelegate {
    private let prefix: String
    private var presentationEnabled = false
    init(prefix: String) { self.prefix = prefix; super.init() }
    func setPresentationEnabled(_ enabled: Bool) {
        presentationEnabled = enabled
        if enabled { center.delegate = self }
    }
    // Lazy access: constructing the service while default-off does not touch UN.
    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }
    func authorization() async throws -> MacReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }
    func pending() async throws -> [MacReminderNotification] {
        await center.pendingNotificationRequests().map { request in
            .init(identifier: request.identifier, title: request.content.title, body: request.content.body,
                  metadata: request.content.userInfo.reduce(into: [:]) { result, item in
                      if let key = item.key as? String, let value = item.value as? String { result[key] = value }
                  })
        }
    }
    func remove(identifiers: [String]) async throws { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func add(_ request: MacReminderNotification) async throws {
        let native = try MacNotificationRequestFactory.request(request, now: Date())
        center.delegate = self
        try await center.add(native)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            let metadata = notification.request.content.userInfo.reduce(into: [String: String]()) { result, item in
                if let key = item.key as? String, let value = item.value as? String { result[key] = value }
            }
            guard self.presentationEnabled,
                  MacNotificationRequestFactory.owns(identifier: notification.request.identifier, metadata: metadata, prefix: self.prefix) else { return [] }
            return [.banner, .sound]
        }
    }
}

private struct MacReminderPreference: Codable, Equatable {
    let version: Int
    let identity: String
    let enabled: Bool
}

/// File is device-local and bound to app/workspace/settings. Not shared AppSettings.
struct MacReminderPreferenceStore {
    let url: URL
    let identity: String
    var write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    func read() throws -> Bool? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let bytes = try Data(contentsOf: url)
        guard WorkspaceJSONValidation.hasUniqueObjectKeys(bytes) else { throw CocoaError(.fileReadCorruptFile) }
        let value = try JSONDecoder().decode(MacReminderPreference.self, from: bytes)
        guard value.version == 1, value.identity == identity,
              let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(object.keys) == ["version", "identity", "enabled"] else { throw CocoaError(.fileReadCorruptFile) }
        return value.enabled
    }
    func save(_ enabled: Bool) throws {
        _ = try read() // Never replace unreadable/unknown preferences with defaults.
        let bytes = try JSONEncoder().encode(MacReminderPreference(version: 1, identity: identity, enabled: enabled))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write(bytes, url)
    }
}

@MainActor public final class MacLocalNotifications: ObservableObject {
    @Published public private(set) var isEnabled = false
    @Published public private(set) var isBusy = false
    @Published public private(set) var statusText = "Off. Enable to request local reminder alerts on this Mac."
    private let coordinator: MacReminderCoordinator
    private let preference: MacReminderPreferenceStore
    private let clock: () -> Date
    private var tail: Task<Void, Never>?
    private var started = false
    private var suspendedAfterSaveFailure = false

    public convenience init(workspaceURL: URL, settingsURL: URL, appScope: String, preferenceRoot: URL) {
        let identity = MacReminderCoordinator.workspaceKey(workspaceURL: workspaceURL, settingsURL: settingsURL, appScope: appScope)
        self.init(workspaceURL: workspaceURL, settingsURL: settingsURL, appScope: appScope,
                  preference: .init(url: preferenceRoot.appendingPathComponent(identity + ".json"), identity: identity),
                  center: SystemMacReminderCenter(prefix: "taskovsky.mac-reminder.v1.\(identity)."), clock: Date.init)
    }

    init(workspaceURL: URL, settingsURL: URL, appScope: String, preference: MacReminderPreferenceStore,
         center: any MacReminderCenter, clock: @escaping () -> Date) {
        coordinator = MacReminderCoordinator(workspaceURL: workspaceURL, settingsURL: settingsURL, appScope: appScope, center: center)
        self.preference = preference; self.clock = clock
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let task = Task { @MainActor in
            if let previous { await previous.value }
            self.isBusy = true
            await operation()
            self.isBusy = false
        }
        tail = task; await task.value
    }

    public func start() async {
        guard !started else { return }; started = true
        await refresh()
    }

    public func refresh() async {
        await enqueue {
            guard !self.suspendedAfterSaveFailure else { return }
            do {
                guard let enabled = try self.preference.read() else {
                    if self.isEnabled { self.show(await self.coordinator.disable()) }
                    else { await self.coordinator.suspend(); self.show(.disabled) }
                    self.isEnabled = false
                    return
                }
                self.isEnabled = enabled
                self.show(enabled ? await self.coordinator.restoreEnabled(clock: self.clock) : await self.coordinator.disable())
            } catch {
                await self.coordinator.suspend()
                self.statusText = "Could not read local notification preferences. Scheduling is paused; existing requests are unchanged."
            }
        }
    }

    /// Must be invoked only by the user's explicit Enable/Disable action.
    public func setEnabled(_ enabled: Bool) async {
        await enqueue {
            do {
                try self.preference.save(enabled)
                self.isEnabled = enabled; self.suspendedAfterSaveFailure = false
                self.show(enabled ? await self.coordinator.enable(clock: self.clock) : await self.coordinator.disable())
            } catch {
                if enabled { await self.coordinator.suspend() }
                else { _ = await self.coordinator.disable() }
                self.suspendedAfterSaveFailure = true
                self.statusText = "Could not save notification preference. Scheduling is paused for this session; the previous preference remains on disk. Previously scheduled alerts may remain if cleanup failed."
            }
        }
    }

    private func show(_ status: MacReminderStatus) {
        switch status {
        case .disabled: statusText = "Off. Local reminder scheduling is disabled."
        case .denied: statusText = "Notifications are not authorized. Allow Taskovsky in macOS notification settings, or disable reminders here."
        case let .ready(pending, deferred):
            statusText = "\(pending) reminder requests planned; \(deferred) deferred by the app limit. Delivery depends on macOS and Focus."
        case let .failed(stage, added, removed):
            let diagnostic = coordinator.lastErrorDiagnostic.map { " \($0)." } ?? ""
            statusText = "Reminder update failed (\(stage))." + diagnostic + " \(added) additions and \(removed) removals submitted. Refresh retries; delivery is not confirmed."
        }
    }
}
