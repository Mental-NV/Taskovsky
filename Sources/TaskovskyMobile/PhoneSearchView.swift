import SwiftUI
import TaskovskyDomain

struct PhoneSearchView<TaskResults: View>: View {
    @ObservedObject var model: PhoneWorkspaceModel
    @Binding var criteria: TaskFilter
    let data: WorkspaceData
    let open: (TaskDestination) -> Void
    @ViewBuilder let taskResults: ([TaskItem], String) -> TaskResults
    @FocusState private var keyboard: Bool
    @State private var showCriteria = false
    @State private var filterRequest: PhoneFilterRequest?
    @State private var savedFilter = false

    private var query: String { criteria.keyword.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filtered: Bool {
        !criteria.listIDs.isEmpty || !criteria.tagIDs.isEmpty || criteria.tagMode != .any ||
            !criteria.dateRules.isEmpty || criteria.status != .all || !criteria.kinds.isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search tasks, lists, tags or filters", text: $criteria.keyword)
                    .textFieldStyle(.roundedBorder)
                    .focused($keyboard).submitLabel(.search)
                    .onSubmit { model.rememberSearch(query); keyboard = false }
                    .accessibilityIdentifier("workspaceSearch")
                if !criteria.keyword.isEmpty {
                    Button { criteria.keyword = "" } label: {
                        Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Clear search").accessibilityIdentifier("clearWorkspaceSearch")
                }
            }.padding(.horizontal, 16)
            HStack {
                Button {
                    keyboard = false
                    showCriteria = true
                } label: {
                    Label(filtered ? "Filters applied" : "Search Filters",
                          systemImage: filtered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .frame(minHeight: 44)
                }.accessibilityIdentifier("searchCriteria")
                Spacer()
                if savedFilter { Text("Filter saved").font(.footnote).accessibilityIdentifier("searchFilterSaved") }
                Button("Save as Filter", action: saveAsFilter)
                    .frame(minHeight: 44)
                    .disabled(query.isEmpty || !model.canBeginEditing)
                    .accessibilityIdentifier("saveSearchAsFilter")
            }.padding(.horizontal, 16)
            if query.isEmpty && !filtered {
                history
            } else {
                organizationResults
                taskResults(data.tasks.filter {
                    criteria.matches($0, lists: data.lists, now: model.now, calendar: model.calendar)
                }, query)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: criteria.keyword) { _, _ in savedFilter = false }
        .sheet(isPresented: $showCriteria) {
            PhoneSearchCriteriaSheet(criteria: criteria, data: data, now: model.now, calendar: model.calendar) { draft in
                criteria = draft
                savedFilter = false
            }
        }
        .sheet(item: $filterRequest) { request in
            PhoneFilterEditor(model: model, request: request) {
                model.rememberSearch(query)
                savedFilter = true
            }
        }
    }

    private var history: some View {
        ScrollView {
            if model.recentSearches.isEmpty {
                ContentUnavailableView("Search your workspace", systemImage: "magnifyingglass")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Recent Searches").font(.headline)
                        Spacer()
                        Button("Clear", action: model.clearSearchHistory).frame(minHeight: 44)
                            .accessibilityIdentifier("clearSearchHistory")
                    }
                    ForEach(model.recentSearches, id: \.self) { term in
                        Button {
                            criteria.keyword = term
                            keyboard = false
                        } label: {
                            Label(term, systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }
        }.scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private var organizationResults: some View {
        if !query.isEmpty {
            let lists = data.lists.filter { $0.name.localizedCaseInsensitiveContains(query) }
            let tags = data.tags.filter { $0.name.localizedCaseInsensitiveContains(query) }
            let filters = data.filters.filter { $0.name.localizedCaseInsensitiveContains(query) }
            if !lists.isEmpty || !tags.isEmpty || !filters.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(lists) { list in
                            result(list.name, kind: "List", systemImage: "list.bullet", destination: .list(list.id))
                        }
                        ForEach(tags) { tag in
                            result(tag.name, kind: "Tag", systemImage: "tag", destination: .tag(tag.id))
                        }
                        ForEach(filters) { filter in
                            result(filter.name, kind: "Filter", systemImage: "line.3.horizontal.decrease", destination: .filter(filter.id))
                        }
                    }.padding(.horizontal, 16)
                }
            }
        }
    }

    private func result(_ name: String, kind: String, systemImage: String, destination: TaskDestination) -> some View {
        Button {
            model.rememberSearch(query)
            keyboard = false
            open(destination)
        } label: {
            Label(name, systemImage: systemImage).frame(minHeight: 44)
        }.buttonStyle(.bordered).accessibilityLabel(kind + " " + name)
    }

    private func saveAsFilter() {
        guard let revision = model.document?.revision else { return }
        keyboard = false
        var draft = criteria
        draft.id = UUID()
        draft.keyword = query
        filterRequest = PhoneFilterRequest(filter: draft, creating: true, revision: revision)
    }
}

private struct PhoneSearchCriteriaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var criteria: TaskFilter
    let data: WorkspaceData
    let now: Date
    let calendar: Calendar
    let apply: (TaskFilter) -> Void

    var body: some View {
        NavigationStack {
            Form {
                PhoneNormalFilterFields(draft: $criteria, data: data, context: .search)
                if criteria.dateRules.contains(.custom) {
                    PhoneFilterDateBounds(from: $criteria.customDateFrom, to: $criteria.customDateTo, now: now)
                }
                Button("Clear Filters") { criteria = TaskFilter(name: "", status: .all, keyword: criteria.keyword) }
            }
            .environment(\.calendar, calendar)
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("cancelSearchCriteria")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !criteria.dateRules.contains(.custom) {
                            criteria.customDateFrom = nil
                            criteria.customDateTo = nil
                        }
                        apply(criteria)
                        dismiss()
                    }
                    .disabled(criteria.dateRules.contains(.custom) && criteria.customDateFrom == nil && criteria.customDateTo == nil)
                    .accessibilityIdentifier("applySearchCriteria")
                }
            }
        }
    }
}

struct PhoneSearchResultContext: View {
    let task: TaskItem
    let lists: [TaskList]
    let query: String

    var body: some View {
        let list = lists.first { $0.id == task.listID }
        if let snippet {
            Text(snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Text((list?.name ?? "Inbox") + (list?.isArchived == true ? " · Archived" : ""))
            .font(.caption).foregroundStyle(.secondary)
    }

    private var snippet: String? {
        guard !query.isEmpty else { return nil }
        for text in [task.body] + task.checklist.map(\.title) {
            guard let match = text.range(of: query, options: .caseInsensitive, locale: .current) else { continue }
            let start = text.index(match.lowerBound, offsetBy: -45, limitedBy: text.startIndex) ?? text.startIndex
            let end = text.index(match.upperBound, offsetBy: 70, limitedBy: text.endIndex) ?? text.endIndex
            return (start == text.startIndex ? "" : "…") + text[start..<end].replacingOccurrences(of: "\n", with: " ") +
                (end == text.endIndex ? "" : "…")
        }
        return nil
    }
}
