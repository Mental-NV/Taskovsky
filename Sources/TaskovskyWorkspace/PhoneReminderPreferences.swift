import Foundation
import CryptoKit

/// Persisted intent, not OS authorization. Contains no task data or paths.
public struct PhoneReminderPreference: Codable, Equatable, Sendable {
    public let version: Int
    public let workspaceID: UUID
    public let appScope: String
    public let enabled: Bool

    /// Stable across container relocation; not an authentication credential.
    public var requestNamespace: String {
        let scope = "\(appScope.utf8.count):\(appScope):\(workspaceID.uuidString.lowercased())"
        return "phone." + SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum PhoneReminderPreferenceError: Error, Equatable {
    case unavailableStorage, invalidRecord, writeFailed
}

/// Use exactly one actor per owned directory. Does not coordinate other
/// processes, defend against hostile file replacement, or access an OS center.
public actor PhoneReminderPreferences {
    private let directory: URL
    private let appScope: String
    private let write: @Sendable (Data, URL) throws -> Void
    private let makeID: @Sendable () -> UUID
    private var file: URL { directory.appendingPathComponent("local-notifications.json") }

    public init(directory: URL, appScope: String,
                makeID: @escaping @Sendable () -> UUID = { UUID() },
                write: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: localFileWriteOptions) }) {
        self.directory = directory; self.appScope = appScope
        self.makeID = makeID; self.write = write
    }

    public func load() throws -> PhoneReminderPreference? {
        try read().record
    }

    /// Call only for an explicit action. Missing + false remains absent/off.
    /// Acknowledges only the exact durable record, including throw-after-commit.
    @discardableResult
    public func setEnabled(_ enabled: Bool) throws -> PhoneReminderPreference? {
        let previous = try read()
        if previous.record?.enabled == enabled || (previous.record == nil && !enabled) { return previous.record }
        let next = PhoneReminderPreference(version: 1, workspaceID: previous.record?.workspaceID ?? makeID(),
                                           appScope: appScope, enabled: enabled)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(next)
        do { try write(bytes, file) } catch {
            guard (try? read().bytes) == bytes else { throw PhoneReminderPreferenceError.writeFailed }
        }
        guard let saved = try? read(), saved.bytes == bytes, saved.record == next else {
            throw PhoneReminderPreferenceError.writeFailed
        }
        return next
    }

    private func read() throws -> (bytes: Data?, record: PhoneReminderPreference?) {
        guard directory.isFileURL, !appScope.isEmpty,
              let directoryType = try? FileManager.default.attributesOfItem(atPath: directory.path)[.type] as? FileAttributeType,
              directoryType == .typeDirectory else { throw PhoneReminderPreferenceError.unavailableStorage }
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: file.path) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return (nil, nil) }
        catch { throw PhoneReminderPreferenceError.unavailableStorage }
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw PhoneReminderPreferenceError.invalidRecord
        }
        let bytes: Data
        do { bytes = try Data(contentsOf: file) } catch { throw PhoneReminderPreferenceError.unavailableStorage }
        guard JSONKeySafety.hasUniqueKeys(bytes),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(object.keys) == ["version", "workspaceID", "appScope", "enabled"],
              let record = try? JSONDecoder().decode(PhoneReminderPreference.self, from: bytes),
              record.version == 1, record.appScope == appScope else {
            throw PhoneReminderPreferenceError.invalidRecord
        }
        return (bytes, record)
    }
}
