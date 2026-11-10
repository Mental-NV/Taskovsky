import Foundation
import TaskovskyDomain

/// An immutable read session. Retains original bytes, including unrecognized
/// fields, and deliberately exposes no persistence or mutation API. This does
/// not satisfy the later metadata-write compatibility gate.
public struct ReadOnlyWorkspaceSnapshot: Sendable {
    public let workspaceBytes: Data
    public let settingsBytes: Data
    public let workspace: WorkspaceData
    public let settings: AppSettings

    public init(workspaceBytes: Data, settingsBytes: Data) throws {
        let decoder = JSONDecoder()
        let workspace = try decoder.decode(WorkspaceData.self, from: workspaceBytes)
        let settings = try decoder.decode(AppSettings.self, from: settingsBytes)
        self.workspaceBytes = workspaceBytes; self.settingsBytes = settingsBytes
        self.workspace = workspace; self.settings = settings
    }
}
