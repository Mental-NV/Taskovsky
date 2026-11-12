import Foundation
import TaskovskyDomain

/// Paired description fields only; preserves raw unrelated task/workspace data.
public enum DescriptionJSONPatch {
    public static func applying(taskID: UUID, content: DescriptionSnapshot, expected: DescriptionSnapshot,
                                to bytes: Data, now: Date) throws -> Data? {
        guard JSONKeySafety.hasUniqueKeys(bytes) else { return nil }
        let original = try JSONDecoder().decode(WorkspaceData.self, from: bytes)
        guard Set(original.tasks.map(\.id)).count == original.tasks.count,
              let index = original.tasks.firstIndex(where: { $0.id == taskID }),
              original.tasks[index].deletedAt == nil,
              !original.lists.contains(where: { $0.id == original.tasks[index].listID && $0.isArchived }),
              DescriptionSnapshot(body: original.tasks[index].body, rich: original.tasks[index].richBody) == expected else { return nil }
        if content == expected { return bytes }
        var staged = original
        staged.tasks[index].body = content.body; staged.tasks[index].richBody = content.rich
        staged.tasks[index].updatedAt = now
        var root = JSONKeySafety(bytes: Array(bytes))
        guard let member = root.rootMember(named: "tasks"), !member.range.isEmpty else { return nil }
        let rawCollection = bytes.subdata(in: member.range)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encodedWorkspace = try dictionary(encoder.encode(staged))
        guard let encodedCollection = encodedWorkspace["tasks"] else { return nil }
        let rawValue = try JSONSerialization.jsonObject(with: rawCollection)
        let array: Data, envelope: Bool
        if let object = rawValue as? [String: Any] {
            guard object["format"] is String, Set(object.keys) == ["format", "records"] else { return nil }
            var collectionScanner = JSONKeySafety(bytes: Array(rawCollection))
            guard let records = collectionScanner.rootMember(named: "records"), !records.range.isEmpty else { return nil }
            array = rawCollection.subdata(in: records.range); envelope = true
        } else {
            guard rawValue is [Any] else { return nil }
            array = rawCollection; envelope = false
        }
        guard let ranges = elementRanges(array), ranges.count == original.tasks.count else { return nil }
        let updatedByID = Dictionary(uniqueKeysWithValues: staged.tasks.map { ($0.id, $0) })
        var replacements: [Int: Data] = [:]
        for index in original.tasks.indices {
            guard let updated = updatedByID[original.tasks[index].id] else { return nil }
            if original.tasks[index].id != taskID { continue }
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
        // Preserve all other task bytes while replacing only the owned record.
        var rewritten = Data(), previous = 0
        for index in ranges.indices {
            rewritten.append(array.subdata(in: previous..<ranges[index].lowerBound))
            rewritten.append(replacements[index] ?? array.subdata(in: ranges[index]))
            previous = ranges[index].upperBound
        }
        rewritten.append(array.subdata(in: previous..<array.count))
        let collection: Data
        if let encodedObject = encodedCollection as? [String: Any], let format = encodedObject["format"] as? String {
            if envelope {
                guard let records = try SettingsMemberPatch.replacing("records", in: rawCollection, with: rewritten, validate: { $0 == array }),
                      let wrapped = try SettingsMemberPatch.replacing("format", in: records, with: encoder.encode(format), validate: { _ in true }) else { return nil }
                collection = wrapped
            } else {
                collection = Data("{\"format\":".utf8) + (try encoder.encode(format)) + Data(",\"records\":".utf8) + rewritten + Data("}".utf8)
            }
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
