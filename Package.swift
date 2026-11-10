// swift-tools-version: 6.0
import PackageDescription

// Explicit source ownership keeps stable repository paths while ensuring the
// portable product never compiles desktop services or AppKit editor code.
let domainSources = [
    "Models.swift",
    "Settings.swift",
    "Organization.swift",
    "ListOrganization.swift",
    "TaskSections.swift",
    "TagOrganization.swift",
    "RichText.swift",
    "RichDescriptionPreview.swift",
    "RichBodyEdit.swift",
    "CustomRecurrence.swift",
    "TaskCalendar.swift",
    "TaskDueCountdown.swift",
    "TaskCalendarProjection.swift",
    "TaskTimeline.swift",
    "CalendarTimeZones.swift",
    "CalendarFilterSelection.swift",
    "CalendarScheduling.swift",
    "CalendarScheduleDraft.swift",
    "ScheduleDraft.swift",
    "TaskScheduleEdit.swift",
    "FilterRuleEdit.swift",
    "SavedFilterChange.swift",
    "BoardProjection.swift",
    "SummaryReport.swift",
    "LegacyRecurrence.swift",
    "TaskDestination.swift",
    "TaskCreation.swift",
    "TaskTextBatch.swift",
    "TaskTemplateChange.swift",
    "TaskLifecycle.swift",
    "TaskBatchEdit.swift",
    "TaskMetadataChange.swift"
]
let desktopSources = [
    "AppMigration.swift",
    "DetailState.swift",
    "DragPayloads.swift",
    "IsolatedLaunch.swift",
    "ListDecorations.swift",
    "ListLayoutManager.swift",
    "ResponsiveLayout.swift",
    "RichEditorSizing.swift",
    "RichTextRender.swift",
    "TaskStore.swift",
    "URLTitle.swift",
    "Exports.swift"
]
let package = Package(
    name: "Taskovsky",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .executable(name: "Taskovsky", targets: ["Taskovsky"]),
        .library(name: "TaskovskyDomain", targets: ["TaskovskyDomain"]),
        .library(name: "TaskovskyClipboard", targets: ["TaskovskyClipboard"]),
        .library(name: "TaskovskyWorkspace", targets: ["TaskovskyWorkspace"])
    ],
    targets: [
        .target(name: "TaskovskyDomain", path: "Sources/TaskovskyCore", exclude: desktopSources, sources: domainSources),
        .target(name: "TaskovskyWorkspace", dependencies: ["TaskovskyDomain"]),
        .target(name: "TaskovskyClipboard", dependencies: ["TaskovskyDomain"]),
        .target(name: "TaskovskyCore", dependencies: ["TaskovskyDomain"], exclude: domainSources),
        .executableTarget(name: "Taskovsky", dependencies: ["TaskovskyCore", "TaskovskyClipboard"]),
        .testTarget(name: "TaskovskyCoreTests", dependencies: ["TaskovskyCore", "TaskovskyClipboard"]),
        .testTarget(name: "TaskovskyDomainTests", dependencies: ["TaskovskyDomain"]),
        .testTarget(name: "TaskovskyWorkspaceTests", dependencies: ["TaskovskyDomain", "TaskovskyWorkspace"])
    ],
    swiftLanguageModes: [.v5]
)
