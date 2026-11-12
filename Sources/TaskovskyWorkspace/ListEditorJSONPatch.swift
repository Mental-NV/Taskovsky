import Foundation
import TaskovskyDomain

/// Lossless explicit List editor creation/update only. Other operations are separate.
public enum ListEditorJSONPatch {
    public static func applying(_ value: TaskList, expected: TaskList?, to bytes: Data) throws -> Data? {
        guard JSONKeySafety.hasUniqueKeys(bytes) else { return nil }
        var staged = try JSONDecoder().decode(WorkspaceData.self, from: bytes)
        let original = staged.lists
        guard Set(original.map(\.id)).count == original.count else { return nil }
        if let expected {
            guard expected.id == value.id, let index = original.firstIndex(where: { $0.id == value.id }), original[index] == expected else { return nil }
            staged.lists[index] = value
        } else {
            guard !original.contains(where: { $0.id == value.id }) else { return nil }
            staged.lists.append(value)
        }
        var root = JSONKeySafety(bytes: Array(bytes))
        guard let member = root.rootMember(named: "lists") else { return nil }
        let array = member.range.isEmpty ? Data("[]".utf8) : bytes.subdata(in: member.range)
        guard let ranges = elementRanges(array), ranges.count == original.count else { return nil }
        var replacement = array
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if expected == nil {
            guard let created = staged.lists.last else { return nil }
            let value = try encoder.encode(created)
            // Preserve whitespace and every original record; append before ].
            var end = array.count - 1
            while end >= 0, [9, 10, 13, 32].contains(array[end]) { end -= 1 }
            guard end >= 0, array[end] == 93 else { return nil }
            replacement.insert(contentsOf: (ranges.isEmpty ? Data() : Data([44])) + value, at: end)
        } else {
            guard let index = original.firstIndex(where: { $0.id == value.id }) else { return nil }
            let old = try dictionary(encoder.encode(original[index]))
            let new = try dictionary(encoder.encode(staged.lists[index]))
            var record = array.subdata(in: ranges[index])
            for key in Set(old.keys).union(new.keys).sorted() {
                let before = try canonical(old[key] ?? NSNull()), after = try canonical(new[key] ?? NSNull())
                guard before != after else { continue }
                guard let patched = try SettingsMemberPatch.replacing(key, in: record, with: after, validate: {
                    try canonical(JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed)) == before
                }) else { return nil }
                record = patched
            }
            replacement.replaceSubrange(ranges[index], with: record)
        }
        guard let result = try SettingsMemberPatch.replacing("lists", in: bytes, with: replacement, validate: { $0 == array }),
              try JSONDecoder().decode(WorkspaceData.self, from: result) == staged else { return nil }
        return result
    }

    private static func dictionary(_ data: Data) throws -> [String: Any] {
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }
    private static func canonical(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }
    private static func elementRanges(_ data: Data) -> [Range<Int>]? {
        var scanner = JSONKeySafety(bytes: Array(data)); scanner.whitespace()
        guard scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] == 91 else { return nil }
        scanner.index += 1; scanner.whitespace()
        var result: [Range<Int>] = []
        while scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] != 93 {
            let start = scanner.index
            guard scanner.value(depth: 1) else { return nil }
            result.append(start..<scanner.index); scanner.whitespace()
            guard scanner.index < scanner.bytes.count else { return nil }
            if scanner.bytes[scanner.index] == 93 { break }
            guard scanner.bytes[scanner.index] == 44 else { return nil }
            scanner.index += 1; scanner.whitespace()
        }
        guard scanner.index < scanner.bytes.count, scanner.bytes[scanner.index] == 93 else { return nil }
        scanner.index += 1; scanner.whitespace()
        return scanner.index == scanner.bytes.count ? result : nil
    }
}
