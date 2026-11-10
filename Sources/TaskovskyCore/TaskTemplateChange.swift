import Foundation

/// Fields the reduced template editor can change. Other values come from
/// the current template inside the revision-checked write.
public struct TaskTemplateFields: Sendable {
    public var name: String
    public var title: String
    public var body: String
    public var checklist: [ChecklistItem]
    public var priority: TaskPriority

    public init(template: TaskTemplate? = nil) {
        name = template?.name ?? ""
        title = template?.title ?? ""
        body = template?.body ?? ""
        checklist = template?.checklist ?? []
        priority = template?.priority ?? .none
    }

    /// Explicit description replacement clears the old styles on the Mac.
    /// The reduced phone editor uses the default protection for styled text.
    public func updated(id: UUID, original: TaskTemplate?, allowsReplacingStyledBody: Bool = false) -> TaskTemplate? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !title.isEmpty, Set(checklist.map(\.id)).count == checklist.count else { return nil }
        var template = original ?? TaskTemplate(id: id, name: name, title: title)
        if template.richBody != nil, !RichBody.sameCodeUnits(template.body, body) {
            guard allowsReplacingStyledBody else { return nil }
            template.richBody = nil
        }
        var steps = checklist
        for index in steps.indices {
            let item = steps[index]
            if let existing = original?.checklist.first(where: { $0.id == item.id }),
               RichBody.sameCodeUnits(existing.title, item.title) { continue }
            steps[index].title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !steps[index].title.isEmpty else { return nil }
        }
        if !RichBody.sameCodeUnits(self.name, template.name) { template.name = name }
        if !RichBody.sameCodeUnits(self.title, template.title) { template.title = title }
        template.body = body
        template.checklist = steps
        template.priority = priority
        return template
    }
}

public enum TaskTemplateChange: Sendable {
    case create(id: UUID, fields: TaskTemplateFields)
    case update(id: UUID, fields: TaskTemplateFields)
    case delete(UUID)
    case saveFromTask(taskID: UUID, templateID: UUID, name: String)
    case applyToTask(templateID: UUID, taskID: UUID)

    public func apply(to data: inout WorkspaceData, settings: AppSettings,
                      now: Date, calendar: Calendar) throws -> Bool? {
        switch self {
        case .create(let id, let fields):
            guard !data.templates.contains(where: { $0.id == id }),
                  let template = fields.updated(id: id, original: nil) else { return nil }
            data.templates.append(template)
        case .update(let id, let fields):
            guard let index = uniqueIndex(id, in: data.templates),
                  let replacement = fields.updated(id: id, original: data.templates[index]) else { return nil }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if try encoder.encode(replacement) == encoder.encode(data.templates[index]) { return false }
            data.templates[index] = replacement
        case .delete(let id):
            guard let index = uniqueIndex(id, in: data.templates) else { return nil }
            data.templates.remove(at: index)
        case .saveFromTask(let taskID, let templateID, let name):
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !data.templates.contains(where: { $0.id == templateID }),
                  let index = uniqueIndex(taskID, in: data.tasks) else { return nil }
            let task = data.tasks[index]
            guard task.deletedAt == nil, validBody(task.body, rich: task.richBody) else { return nil }
            let validTags = Set(data.tags.map(\.id))
            data.templates.append(TaskTemplate(id: templateID, name: name, title: task.title, body: task.body,
                                               checklist: task.checklist, priority: task.priority,
                                               tagIDs: task.tagIDs.filter(validTags.contains), kind: task.kind,
                                               richBody: task.richBody, customRecurrence: task.customRecurrence,
                                               scheduledDuration: task.scheduledDuration))
        case .applyToTask(let templateID, let taskID):
            guard let templateIndex = uniqueIndex(templateID, in: data.templates),
                  let taskIndex = uniqueIndex(taskID, in: data.tasks) else { return nil }
            let original = data.tasks[taskIndex]
            let template = data.templates[templateIndex]
            guard original.deletedAt == nil, !SmartListEligibility.isArchived(original, lists: data.lists),
                  !template.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  validBody(original.body, rich: original.richBody), validBody(template.body, rich: template.richBody),
                  template.customRecurrence?.isValid != false else { return nil }

            let recordCalendar = TaskCalendarProjection.taskCalendar(original, fallback: calendar)
            if let window = template.scheduledDuration, window.validated(in: recordCalendar) == nil { return nil }
            var task = original
            task.title = template.title
            task.body = template.body
            task.richBody = template.richBody
            task.checklist = template.checklist.map { ChecklistItem(title: $0.title, isCompleted: $0.isCompleted) }
            task.priority = template.priority
            let validTags = Set(data.tags.map(\.id))
            task.tagIDs = template.tagIDs.filter(validTags.contains)
            task.kind = template.kind
            task.customRecurrence = template.customRecurrence
            let schedule = TaskSchedulePolicy.coherentSchedule(dueDate: task.dueDate, hasDueTime: task.hasDueTime,
                                                               window: template.scheduledDuration, calendar: recordCalendar)
            task.dueDate = schedule.dueDate
            task.hasDueTime = schedule.hasDueTime
            task.scheduledDuration = schedule.window
            TaskSchedulePolicy.reconcileSeries(of: &task, from: original)
            TaskSchedulePolicy.reconcileReminders(of: &task, from: original, settings: settings, calendar: calendar)
            task.updatedAt = now
            data.tasks[taskIndex] = task
        }
        return true
    }

    private func uniqueIndex<Item: Identifiable>(_ id: UUID, in items: [Item]) -> Int? where Item.ID == UUID {
        let indices = items.indices.filter { items[$0].id == id }
        return indices.count == 1 ? indices.first : nil
    }

    private func validBody(_ body: String, rich: RichBody?) -> Bool {
        guard let rich else { return true }
        return RichDescriptionPreview(body: body, rich: rich) != nil
    }
}
