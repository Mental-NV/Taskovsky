import Foundation

/// Pure `--workspace` / `--settings` command-line resolution for isolated
/// QA launches. The App layer delegates to this so the policy is unit
/// tested: flag presence alone (even with a missing or invalid value)
/// isolates; only an absolute file path (never a directory, never another
/// flag) counts as an explicit value. A missing/invalid value still
/// isolates — the App falls back to a fresh temp workspace, never to the
/// real one.
public struct IsolatedLaunchResolution: Sendable, Equatable {
    /// True whenever `--workspace` is present, regardless of its value.
    public var isIsolated: Bool
    /// Validated explicit workspace file, nil when missing or invalid.
    public var workspace: URL?
    /// Validated explicit settings file, nil when missing or invalid.
    public var settings: URL?
    /// The flag was present but carried no usable file value.
    public var workspaceValueInvalid: Bool
    public init(isIsolated: Bool, workspace: URL? = nil, settings: URL? = nil, workspaceValueInvalid: Bool = false) {
        self.isIsolated = isIsolated; self.workspace = workspace
        self.settings = settings; self.workspaceValueInvalid = workspaceValueInvalid
    }
}

public enum IsolatedLaunch {
    /// Resolves isolation from an argument vector (pass `CommandLine.arguments`
    /// in production, fakes in tests).
    public static func resolve(arguments: [String]) -> IsolatedLaunchResolution {
        let flagPresent = arguments.contains("--workspace")
        let rawWorkspace = rawValue(for: "--workspace", in: arguments)
        let rawSettings = rawValue(for: "--settings", in: arguments)
        let workspace = rawWorkspace.flatMap { validatedFileURL($0) }
        return IsolatedLaunchResolution(
            isIsolated: flagPresent,
            workspace: workspace,
            settings: rawSettings.flatMap { validatedFileURL($0) },
            workspaceValueInvalid: flagPresent && workspace == nil)
    }

    /// The value after the flag, or nil when the flag is absent, last, or
    /// followed by another flag (a missing value must not swallow `--x`).
    private static func rawValue(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        let raw = arguments[index + 1]
        guard !raw.hasPrefix("--") else { return nil }
        return raw
    }

    private static func validatedFileURL(_ raw: String) -> URL? {
        guard !raw.isEmpty, raw.hasPrefix("/") else { return nil }
        let url = URL(fileURLWithPath: raw)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue { return nil }
        return url
    }
}
