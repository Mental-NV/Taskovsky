import SwiftUI
import TaskovskyDomain

enum TaskTextBatchSubmission {
    case saved, needsReview(String), failed(String), uncertain(String)
}

struct TaskTextBatchReview {
    let batch: TaskTextBatch
    let calendar: Calendar
    let tags: [TaskTag]
    let save: () async -> TaskTextBatchSubmission
}

struct TaskTextBatchSheet: View {
    let prepare: (String, Bool) throws -> TaskTextBatchReview

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var recognizesDetails = true
    @State private var review: TaskTextBatchReview?
    @State private var error: String?
    @State private var saving = false
    @State private var canRevise = true
    @State private var canSubmit = true
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add Multiple Tasks").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving)
            }
            if let review {
                reviewContents(review)
            } else {
                Text("Type or paste one task per line.").foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .focused($editorFocused)
                    .frame(minHeight: 128)
                    .border(.secondary.opacity(0.25))
                    .accessibilityLabel("Task titles")
                    .accessibilityIdentifier("batchCaptureInput")
                Toggle("Recognize dates and existing tags", isOn: $recognizesDetails)
            }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
                    .accessibilityIdentifier("batchCaptureError")
            }
            HStack {
                if review != nil {
                    Button("Back") {
                        review = nil
                        error = nil
                        editorFocused = true
                    }.disabled(saving || !canRevise)
                }
                Spacer()
                if let review {
                    Button("Add " + countLabel(review.batch.tasks.count)) { submit(review) }
                        .buttonStyle(.borderedProminent)
                        .disabled(saving || !canSubmit)
                        .accessibilityIdentifier("batchCaptureCommit")
                } else {
                    Button("Review Tasks", action: prepareReview)
                        .buttonStyle(.borderedProminent)
                        .disabled(TaskTextBatch.titles(in: text).isEmpty)
                        .accessibilityIdentifier("batchCaptureReview")
                }
            }
        }
        .padding(16)
        .interactiveDismissDisabled(saving)
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 510, minHeight: 330, idealHeight: 440)
        #endif
    }

    private func countLabel(_ count: Int) -> String { count == 1 ? "1 Task" : "\(count) Tasks" }

    private func prepareReview() {
        do {
            review = try prepare(text, recognizesDetails)
            error = nil
            canRevise = true
            canSubmit = true
            editorFocused = false
        } catch TaskTextBatchValidation.invalidLine(let line, .emptyTitle) {
            error = "Task \(line) needs a title after recognition. Edit the line or turn recognition off."
        } catch TaskTextBatchValidation.unavailableDestination {
            error = "This destination is no longer available."
        } catch {
            self.error = "Could not prepare these tasks. Check the text and current destination."
        }
    }

    private func reviewContents(_ review: TaskTextBatchReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add to " + review.batch.listName).font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("batchCaptureDestination")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(review.batch.tasks) { task in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                            let details = details(of: task, in: review)
                            if !details.isEmpty { Text(details).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
        }
    }

    private func details(of task: TaskItem, in review: TaskTextBatchReview) -> String {
        var values: [String] = []
        if let due = task.dueDate {
            let local = TaskCalendarProjection.taskCalendar(task, fallback: review.calendar)
            let date = Date.FormatStyle(calendar: local, timeZone: local.timeZone).month(.abbreviated).day().year()
            values.append(due.formatted(task.hasDueTime ? date.hour().minute() : date))
        }
        values.append(contentsOf: task.tagIDs.compactMap { id in review.tags.first { $0.id == id }.map { "#" + $0.name } })
        return values.joined(separator: " · ")
    }

    private func submit(_ review: TaskTextBatchReview) {
        saving = true
        error = nil
        Task { @MainActor in
            let result = await review.save()
            saving = false
            switch result {
            case .saved: dismiss()
            case .needsReview(let message): error = message; canSubmit = false; canRevise = true
            case .failed(let message): error = message; canRevise = true
            case .uncertain(let message): error = message; canRevise = false
            }
        }
    }
}
