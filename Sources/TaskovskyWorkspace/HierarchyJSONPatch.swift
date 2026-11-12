import Foundation
import TaskovskyDomain

/// Raw task-collection patch used only after the existing hierarchy helper
/// has produced a staged result. Not a new hierarchy policy or general editor.
public enum HierarchyJSONPatch {
    public static func applying(staged: WorkspaceData, to bytes: Data) throws -> Data? {
        guard JSONKeySafety.hasUniqueKeys(bytes) else { return nil }
        let original = try JSONDecoder().decode(WorkspaceData.self, from: bytes)
        var nonTasks = staged; nonTasks.tasks = original.tasks
        guard nonTasks == original,
              Set(original.tasks.map(\.id)).count == original.tasks.count,
              Set(staged.tasks.map(\.id)).count == staged.tasks.count else { return nil }
        let oldIDs = original.tasks.map(\.id), newIDs = staged.tasks.map(\.id)
        let oldSet = Set(oldIDs)
        let added = staged.tasks.filter { !oldSet.contains($0.id) }
        guard newIDs.filter({ oldSet.contains($0) }) == oldIDs,
              added.count <= 1, staged.tasks.count == original.tasks.count + added.count,
              added.isEmpty || newIDs.first == added[0].id || newIDs.last == added[0].id else { return nil }
        var root = JSONKeySafety(bytes: Array(bytes))
        guard let member = root.rootMember(named: "tasks"), !member.range.isEmpty else { return nil }
        let rawCollection = bytes.subdata(in: member.range)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encodedWorkspace = try dictionary(encoder.encode(staged))
        guard let encodedCollection = encodedWorkspace["tasks"] else { return nil }
        let rawValue = try JSONSerialization.jsonObject(with: rawCollection)
        let array: Data, envelope: Bool
        if let object = rawValue as? [String: Any] {
            guard let encodedObject = encodedCollection as? [String: Any],
                  let format = object["format"] as? String, format == encodedObject["format"] as? String else { return nil }
            var collectionScanner = JSONKeySafety(bytes: Array(rawCollection))
            guard let records = collectionScanner.rootMember(named: "records"), !records.range.isEmpty else { return nil }
            array = rawCollection.subdata(in: records.range); envelope = true
        } else {
            guard rawValue is [Any], encodedCollection is [Any] else { return nil }
            array = rawCollection; envelope = false
        }
        guard let ranges = elementRanges(array), ranges.count == original.tasks.count else { return nil }
        let updatedByID = Dictionary(uniqueKeysWithValues: staged.tasks.map { ($0.id, $0) })
        var replacements: [Int: Data] = [:]
        for index in original.tasks.indices {
            guard let updated = updatedByID[original.tasks[index].id] else { return nil }
            if updated == original.tasks[index] { continue }
            let old = try dictionary(encoder.encode(original.tasks[index])), new = try dictionary(encoder.encode(updated))
            var record = array.subdata(in: ranges[index])
            for key in Set(old.keys).union(new.keys).sorted() {
                let before = try canonical(old[key] ?? NSNull()), after = try canonical(new[key] ?? NSNull())
                guard before != after else { continue }
                guard let result = try SettingsMemberPatch.replacing(key, in: record, with: after, validate: {
                    try canonical(JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed)) == before
                }) else { return nil }
                record = result
            }
            replacements[index] = record
        }
        // Assemble once; moving a large subtree must not repeatedly copy the
        // complete task array for every changed descendant.
        var rewritten = Data(), previous = 0
        for index in ranges.indices {
            rewritten.append(array.subdata(in: previous..<ranges[index].lowerBound))
            rewritten.append(replacements[index] ?? array.subdata(in: ranges[index]))
            previous = ranges[index].upperBound
        }
        rewritten.append(array.subdata(in: previous..<array.count))
        if let child = added.first {
            let encoded = try encoder.encode(child)
            if newIDs.first == child.id {
                let start = try arrayContentStart(rewritten)
                rewritten.insert(contentsOf: encoded + (oldIDs.isEmpty ? Data() : Data([44])), at: start)
            } else {
                var end = rewritten.count - 1
                while end >= 0, [9, 10, 13, 32].contains(rewritten[end]) { end -= 1 }
                guard end >= 0, rewritten[end] == 93 else { return nil }
                rewritten.insert(contentsOf: (oldIDs.isEmpty ? Data() : Data([44])) + encoded, at: end)
            }
        }
        let collection: Data
        if envelope {
            guard let result = try SettingsMemberPatch.replacing("records", in: rawCollection, with: rewritten, validate: { $0 == array }) else { return nil }
            collection = result
        } else { collection = rewritten }
        guard let result = try SettingsMemberPatch.replacing("tasks", in: bytes, with: collection, validate: { $0 == rawCollection }),
              try JSONDecoder().decode(WorkspaceData.self, from: result) == staged else { return nil }
        return result
    }
    private static func dictionary(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
    private static func canonical(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }
    private static func arrayContentStart(_ data: Data) throws -> Int {
        var scanner = JSONKeySafety(bytes: Array(data)); scanner.whitespace()
        guard scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] == 91 else { throw CocoaError(.fileReadCorruptFile) }
        return scanner.index + 1
    }
    private static func elementRanges(_ data: Data) -> [Range<Int>]? {
        var scanner = JSONKeySafety(bytes: Array(data)); scanner.whitespace()
        guard scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] == 91 else { return nil }
        scanner.index += 1; scanner.whitespace(); var ranges: [Range<Int>] = []
        while scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] != 93 {
            let start = scanner.index
            guard scanner.value(depth: 1) else { return nil }
            ranges.append(start..<scanner.index); scanner.whitespace()
            guard scanner.index < scanner.bytes.count else { return nil }
            if scanner.bytes[scanner.index] == 93 { break }
            guard scanner.bytes[scanner.index] == 44 else { return nil }
            scanner.index += 1; scanner.whitespace()
        }
        guard scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] == 93 else { return nil }
        scanner.index += 1; scanner.whitespace()
        return scanner.index == scanner.bytes.count ? ranges : nil
    }
}
