import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers
import TaskovskyDomain
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct TaskTimelineArrangeDrag: Codable, Transferable {
    let taskID: UUID
    let session: UUID
    let updatedAt: Date
    let revision: Data?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: UTType(exportedAs: "local.taskovsky.timeline-arrange"))
            .visibility(.ownProcess)
    }
}

struct TaskTimelineArrangeControls {
    var revision: Data?
    let drop: (TaskTimelineArrangeDrag, CalendarScheduleOperation) -> Bool
}

struct TaskTimelineView: View {
    let scope: TaskTimelineScope
    let data: WorkspaceData
    let now: Date
    let calendar: Calendar
    let color: (String) -> Color
    let open: (UUID) -> Void
    var arrange: ((UUID, Date) -> Void)?
    var capture: ((TaskDestination, Date) -> Void)?
    var beginAdjustment: ((UUID) -> ((CalendarScheduleOperation) -> Void)?)?
    var arrangement: TaskTimelineArrangeControls?
    @State private var arrangeSession = UUID()
    #if os(macOS)
    @Namespace private var arrangeSpace
    @State private var arrangeContent = CGRect.zero
    @State private var arrangeViewport = CGRect.zero
    @GestureState private var arrangePoint: CGPoint?
    @State private var arrangeSource: TaskTimelineArrangeDrag?
    private var arrangeTargeted: Bool { arrangePoint.map(arrangeViewport.contains) ?? false }
    #else
    @State private var arrangeTargeted = false
    #endif
    @State private var captureDay: Date?
    @State private var dateChoice: Date?
    @State private var showDateChoice = false
    @State private var scale = TaskTimelineScale.week
    @State private var zoom = TaskTimelineZoom.standard
    @State private var colorBy = CalendarColorMode.list
    #if os(iOS)
    @State private var showColorOptions = false
    #endif
    @State private var selectedFocus: Date?

    private var focus: Date { selectedFocus ?? now }
    private var axis: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
    }
    private var dayWidth: CGFloat {
        let base: Double = switch scale {
        case .day: 72
        case .week: 18
        case .month: 4
        }
        return CGFloat(base * zoom.factor)
    }
    private var rowHeight: CGFloat { 44 }
    private var destinations: [TaskDestination] { capture == nil ? [] : scope.captureDestinations(in: data) }

    var body: some View {
        let window = scale.window(focus: focus, calendar: calendar)
        let projection = TaskTimelineProjection(scope: scope, data: data, window: window, now: now, colorBy: colorBy)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Timeline scale", selection: $scale) {
                    ForEach(TaskTimelineScale.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("taskTimelineScale")
                #if os(iOS)
                Button { showColorOptions = true } label: {
                    Image(systemName: "paintpalette").frame(width: 44, height: 44)
                }
                .popover(isPresented: $showColorOptions, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Color by").font(.headline).padding(.horizontal, 12).padding(.vertical, 6)
                        ForEach(CalendarColorMode.allCases, id: \.self) { mode in
                            Button {
                                colorBy = mode
                                showColorOptions = false
                            } label: {
                                HStack {
                                    Text(mode.rawValue.capitalized)
                                    Spacer()
                                    if mode == colorBy { Image(systemName: "checkmark").accessibilityHidden(true) }
                                }.frame(minHeight: 44).padding(.horizontal, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityAddTraits(mode == colorBy ? .isSelected : [])
                        }
                    }.padding(8).frame(width: 180).presentationCompactAdaptation(.popover)
                }
                .accessibilityLabel("Timeline color by")
                .accessibilityValue(colorBy.rawValue.capitalized)
                .accessibilityIdentifier("taskTimelineColor")
                #else
                Menu {
                    Picker("Color by", selection: $colorBy) {
                        ForEach(CalendarColorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette").frame(minWidth: 36, minHeight: 36)
                }
                #if os(macOS)
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                #endif
                .accessibilityLabel("Timeline color by")
                    .accessibilityValue(colorBy.rawValue.capitalized)
                    .accessibilityIdentifier("taskTimelineColor")
                #endif
            }
            navigation(window)
            zoomControls
            if showDateChoice {
                HStack {
                    DatePicker("Task date", selection: Binding(get: { dateChoice ?? focus }, set: { dateChoice = $0 }),
                               displayedComponents: .date)
                        .environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone)
                    Button("Continue") {
                        showDateChoice = false
                        requestCapture(calendar.startOfDay(for: dateChoice ?? focus))
                    }
                }
            }
            ScrollView {
                let canArrange = arrangement != nil && !projection.undated.isEmpty
                if !projection.rows.isEmpty || !destinations.isEmpty || canArrange {
                    chart(window, groups: projection.groups, undated: projection.undated, canArrange: canArrange)
                }
                if projection.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No scheduled tasks in this period").foregroundStyle(.secondary)
                        if let first = projection.firstScheduledDate,
                           window.interval.map({ first < $0.start || first >= $0.end }) == true {
                            Button("Go to earliest task") { selectedFocus = first }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
                }
                if !projection.undated.isEmpty {
                    undated(projection.undated, window: window)
                }
            }.safeAreaPadding(.bottom, 90)
        }
        .padding(.horizontal, 16)
        .onChange(of: scale) { _, _ in zoom = .standard }
        #if os(macOS)
        .coordinateSpace(name: arrangeSpace)
        .overlay(alignment: .topLeading) {
            if let arrangePoint, let arrangeSource,
               let task = data.tasks.first(where: { $0.id == arrangeSource.taskID }) {
                Text(task.title).font(.caption.weight(.semibold)).lineLimit(1)
                    .padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    .position(x: arrangePoint.x, y: arrangePoint.y - 16)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .onChange(of: arrangePoint == nil) { _, inactive in if inactive { arrangeSource = nil } }
        #endif
        .confirmationDialog("Add task to list", isPresented: Binding(get: { captureDay != nil }, set: {
            if !$0 { captureDay = nil }
        }), titleVisibility: .visible, presenting: captureDay) { day in
            ForEach(destinations, id: \.self) { target in
                if case .list(let id) = target, let list = data.lists.first(where: { $0.id == id }) {
                    Button(list.name) { capture?(target, day) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func requestCapture(_ day: Date) {
        if destinations.count > 1 { captureDay = day }
        else if let target = destinations.first { capture?(target, day) }
    }

    private func navigation(_ window: TaskTimelineWindow) -> some View {
        HStack(spacing: 6) {
            pageButton(-1, label: "Previous Timeline period", symbol: "chevron.left")
            if let first = window.dates.first, let last = window.dates.last {
                Text(first.formatted(axis.month(.abbreviated).day().year()) + " – " +
                     last.formatted(axis.month(.abbreviated).day().year()))
                    .font(.caption).lineLimit(2)
                    .accessibilityIdentifier("taskTimelinePeriod")
            }
            Spacer(minLength: 0)
            Button("Today") { selectedFocus = nil }
            pageButton(1, label: "Next Timeline period", symbol: "chevron.right")
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 2) {
            Spacer()
            Button { zoom = zoom.scaled(by: 0.8) } label: {
                Image(systemName: "minus.magnifyingglass").frame(minWidth: 44, minHeight: 34)
            }
            .accessibilityLabel("Zoom task timeline out")
            .disabled(!zoom.canZoomOut)
            Button { zoom = .standard } label: {
                Text("\(zoom.percent)%").font(.caption.monospacedDigit()).frame(minWidth: 44, minHeight: 34)
            }
            .accessibilityLabel("Reset task timeline zoom")
            .accessibilityValue("\(zoom.percent) percent")
            .accessibilityIdentifier("taskTimelineZoom")
            .disabled(zoom == .standard)
            Button { zoom = zoom.scaled(by: 1.25) } label: {
                Image(systemName: "plus.magnifyingglass").frame(minWidth: 44, minHeight: 34)
            }
            .accessibilityLabel("Zoom task timeline in")
            .disabled(!zoom.canZoomIn)
        }.buttonStyle(.plain)
    }

    private func pageButton(_ direction: Int, label: String, symbol: String) -> some View {
        Button {
            selectedFocus = scale.page(from: focus, direction: direction, calendar: calendar)
        } label: {
            Image(systemName: symbol).frame(minWidth: 34, minHeight: 34)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func chart(_ window: TaskTimelineWindow, groups: [TaskTimelineGroup],
                       undated: [TaskItem], canArrange: Bool) -> some View {
        let hasRail = !destinations.isEmpty || canArrange
        let width = CGFloat(window.dates.count) * dayWidth
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Task").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(height: rowHeight, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if !destinations.isEmpty {
                    Button {
                        dateChoice = focus
                        showDateChoice.toggle()
                    } label: {
                        Label("Add on date", systemImage: "plus").font(.caption)
                            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityIdentifier("timelineChooseCaptureDate")
                } else if hasRail {
                    Text("Drop on a date").font(.caption).foregroundStyle(.secondary).frame(height: rowHeight)
                }
                ForEach(groups) { group in
                    if let title = group.title {
                        Text(title).font(.caption.weight(.semibold)).lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(group.rows) { row in
                        Button { open(row.id) } label: {
                            Text(row.entry.title).lineLimit(2)
                                .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(scheduleLabel(row.entry))
                        .accessibilityIdentifier("timelineScheduled-" + row.id.uuidString)
                        .contextMenu {
                            if let arrange { Button("Edit Schedule") { arrange(row.id, focus) } }
                        }
                    }
                }
            }.frame(width: 114, alignment: .leading).padding(.trailing, 8)
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(window.marks.enumerated()), id: \.element) { index, date in
                            let end = index + 1 < window.marks.count ? window.offset(of: window.marks[index + 1]) : Double(window.dates.count)
                            Text(mark(date)).font(.caption).lineLimit(1)
                                .frame(width: CGFloat(end - window.offset(of: date)) * dayWidth, height: rowHeight, alignment: .leading)
                                .accessibilityIdentifier("taskTimelineMark-" + String(index))
                        }
                    }
                    if hasRail {
                        chartBackground(window)
                            .overlay(alignment: .bottom) { Divider().allowsHitTesting(false) }
                            .frame(width: width, height: rowHeight)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Add on the timeline")
                            .accessibilityAddTraits(destinations.isEmpty ? [] : .isButton)
                            .accessibilityAction { requestCapture(calendar.startOfDay(for: focus)) }
                            .accessibilityIdentifier("timelineCaptureRail")
                    }
                    ForEach(groups) { group in
                        if group.title != nil {
                            Rectangle().fill(.primary.opacity(0.06))
                                .frame(width: width, height: rowHeight).accessibilityHidden(true)
                        }
                        ForEach(group.rows) { row in
                            ZStack(alignment: .topLeading) {
                                chartBackground(window)
                                Divider().frame(maxHeight: .infinity, alignment: .bottom).allowsHitTesting(false)
                                bar(row, width: width)
                                    .frame(height: rowHeight).allowsHitTesting(false).accessibilityHidden(true)
                                adjustmentHandles(row, window: window, width: width)
                            }.frame(width: width, height: rowHeight)
                        }
                    }
                }
                .background {
                    TaskTimelineZoomInput(zoom: zoom, dayWidth: dayWidth) { zoom = $0 }
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                .background(alignment: .topLeading) {
                    if arrangeTargeted { Rectangle().fill(Color.accentColor.opacity(0.07)) }
                    ForEach(window.marks, id: \.self) { date in
                        Rectangle().fill(.primary.opacity(0.12)).frame(width: 1)
                            .offset(x: CGFloat(window.offset(of: date)) * dayWidth)
                    }
                }
                #if os(macOS)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(arrangeSpace)) } action: {
                    arrangeContent = $0
                }
                #else
                .contentShape(Rectangle())
                .dropDestination(for: TaskTimelineArrangeDrag.self) { payloads, location in
                    guard canArrange, payloads.count == 1, let payload = payloads.first else { return false }
                    return arrangeDrop(payload, at: location.x, window: window, undated: undated)
                } isTargeted: { targeted in arrangeTargeted = canArrange && targeted }
                #endif
            }.id(window.dates.first).id(scale).accessibilityIdentifier("taskTimelineAxis")
            #if os(macOS)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(arrangeSpace)) } action: {
                arrangeViewport = $0
            }
            #endif
        }
    }

    private func arrangeDrop(_ payload: TaskTimelineArrangeDrag, at x: CGFloat, window: TaskTimelineWindow,
                             undated: [TaskItem]) -> Bool {
        guard payload.session == arrangeSession,
              undated.contains(where: { $0.id == payload.taskID && $0.updatedAt == payload.updatedAt }),
              let operation = window.arrange(at: Double(x / dayWidth), scale: scale)
        else { return false }
        return arrangement?.drop(payload, operation) == true
    }

    private func chartBackground(_ window: TaskTimelineWindow) -> some View {
        Rectangle().fill(.clear).contentShape(Rectangle())
            .modifier(TimelineDatePress(enabled: !destinations.isEmpty) { x in
                if let day = window.captureDay(at: Double(x / dayWidth)) { requestCapture(day) }
            })
    }

    @ViewBuilder private func adjustmentHandles(_ row: TaskTimelineRow, window: TaskTimelineWindow, width: CGFloat) -> some View {
        if let beginAdjustment, let arrange, row.entry.canSchedule {
            let start = CGFloat(row.start) * dayWidth
            let end = CGFloat(row.end) * dayWidth
            if !row.continuesBefore {
                let gripWidth = max(28, end - start)
                TimelineAdjustmentHandle(entry: row.entry, kind: .move, window: window, scale: scale,
                    dayWidth: dayWidth, calendar: calendar, width: min(width, gripWidth), begin: { beginAdjustment(row.id) },
                    edit: { arrange(row.id, focus) })
                    .offset(x: min(width - gripWidth, max(0, row.isPoint ? start - gripWidth / 2 : start)), y: 6)
            }
            if row.entry.hasDuration && !row.continuesAfter {
                TimelineAdjustmentHandle(entry: row.entry, kind: .resizeEnd, window: window, scale: scale,
                    dayWidth: dayWidth, calendar: calendar, width: 28, begin: { beginAdjustment(row.id) },
                    edit: { arrange(row.id, focus) })
                    .offset(x: min(width - 28, max(0, end - 14)), y: 27)
            }
        }
    }

    private func mark(_ date: Date) -> String {
        if scale == .month { return date.formatted(axis.month(.abbreviated)) }
        return date.formatted(axis.month(.abbreviated).day())
    }

    private func bar(_ row: TaskTimelineRow, width: CGFloat) -> some View {
        let start = CGFloat(row.start) * dayWidth
        let tint = color(row.entry.color)
        let opacity = row.entry.isCompleted ? 0.45 : 1.0
        return Group {
            if row.isPoint {
                Circle().fill(tint).frame(width: 9, height: 9)
                    .offset(x: min(width - 9, max(0, start - 4.5)))
            } else {
                Capsule().fill(tint)
                    .frame(width: max(2, CGFloat(row.end - row.start) * dayWidth), height: 15)
                    .overlay(alignment: .leading) {
                        if row.continuesBefore { Image(systemName: "chevron.left").font(.system(size: 7, weight: .bold)).padding(.leading, 3) }
                    }
                    .overlay(alignment: .trailing) {
                        if row.continuesAfter { Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold)).padding(.trailing, 3) }
                    }
                    .foregroundStyle(.white)
                    .offset(x: start)
            }
        }.opacity(opacity)
    }

    private func scheduleLabel(_ entry: CalendarEntry) -> String {
        let format = entry.isAllDay ? axis.year().month(.wide).day() : axis.year().month(.wide).day().hour().minute()
        let start = entry.start.formatted(format)
        return entry.hasDuration ? start + " – " + entry.due.formatted(format) : start
    }

    private func undated(_ tasks: [TaskItem], window: TaskTimelineWindow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Arrange Undated Tasks").font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(tasks) { task in
                HStack {
                    Button { open(task.id) } label: {
                        Text(task.title).frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("timelineUndated-" + task.id.uuidString)
                    if let arrangement {
                        arrangementGrip(task, arrangement: arrangement, tasks: tasks, window: window)
                    }
                    if let arrange {
                        Button { arrange(task.id, focus) } label: {
                            Image(systemName: "calendar.badge.plus").frame(minWidth: 44, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Schedule " + task.title)
                    }
                }
            }
        }.padding(.vertical, 12)
    }

    private func arrangementGrip(_ task: TaskItem, arrangement: TaskTimelineArrangeControls,
                                 tasks: [TaskItem], window: TaskTimelineWindow) -> some View {
        let payload = TaskTimelineArrangeDrag(taskID: task.id, session: arrangeSession,
                                              updatedAt: task.updatedAt, revision: arrangement.revision)
        return Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
            .frame(width: 32, height: rowHeight).contentShape(Rectangle())
            .accessibilityLabel("Drag " + task.title + " to Timeline")
            .accessibilityIdentifier("timelineArrangeDrag-" + task.id.uuidString)
            #if os(macOS)
            .gesture(DragGesture(minimumDistance: 5, coordinateSpace: .named(arrangeSpace))
                .updating($arrangePoint) { value, point, _ in point = value.location }
                .onChanged { _ in if arrangeSource == nil { arrangeSource = payload } }
                .onEnded { value in
                    defer { arrangeSource = nil }
                    guard let source = arrangeSource, arrangeViewport.contains(value.location) else { return }
                    _ = arrangeDrop(source, at: value.location.x - arrangeContent.minX, window: window, undated: tasks)
                })
            #else
            .draggable(payload)
            #endif
    }
}


private struct TimelineDatePress: ViewModifier {
    let enabled: Bool
    let choose: (CGFloat) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            #if os(iOS)
            content.gesture(LongPressGesture(minimumDuration: 0.35, maximumDistance: 12)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded { value in
                    guard case .second(true, let drag?) = value,
                          abs(drag.translation.width) <= 12, abs(drag.translation.height) <= 12 else { return }
                    choose(drag.startLocation.x)
                })
            #else
            content.gesture(SpatialTapGesture().onEnded { choose($0.location.x) })
            #endif
        } else {
            content.allowsHitTesting(false)
        }
    }
}

private struct TimelineAdjustmentHandle: View {
    let entry: CalendarEntry
    let kind: TaskTimelineAdjustment
    let window: TaskTimelineWindow
    let scale: TaskTimelineScale
    let dayWidth: CGFloat
    let calendar: Calendar
    let width: CGFloat
    let begin: () -> ((CalendarScheduleOperation) -> Void)?
    let edit: () -> Void
    @GestureState private var tracking = false
    @State private var finish: ((CalendarScheduleOperation) -> Void)?
    @State private var preview: Date?

    var body: some View {
        Button(action: edit) {
            Group {
                if kind == .resizeEnd {
                    Image(systemName: "arrow.left.and.right").font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else { Color.clear }
            }.frame(width: width, height: kind == .move ? 24 : 17).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((kind == .move ? "Move " : "Resize end of ") + entry.title)
        .accessibilityIdentifier((kind == .move ? "timelineMove-" : "timelineResize-") + entry.taskID.uuidString)
        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($tracking) { _, active, _ in active = true }
            .onChanged { value in
                if finish == nil { finish = begin() }
                preview = change(value)?.date
            }
            .onEnded { value in
                if let operation = change(value)?.operation { finish?(operation) }
                clear()
            })
        .onChange(of: tracking) { _, active in if !active { clear() } }
        .overlay(alignment: .topLeading) {
            if let preview {
                Text(preview.formatted(Date.FormatStyle(date: .abbreviated, time: entry.isAllDay ? .omitted : .shortened,
                                                       calendar: calendar, timeZone: calendar.timeZone)))
                    .font(.caption2).fixedSize().padding(3).background(.regularMaterial, in: Capsule())
                    .offset(y: -16).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }

    private func change(_ value: DragGesture.Value) -> TaskTimelineScheduleChange? {
        guard abs(value.translation.width) > abs(value.translation.height) else { return nil }
        return window.adjust(kind, entry: entry, by: Double(value.translation.width / dayWidth), scale: scale)
    }

    private func clear() {
        finish = nil
        preview = nil
    }
}

#if os(macOS)
private struct TaskTimelineZoomInput: NSViewRepresentable {
    let zoom: TaskTimelineZoom
    let dayWidth: CGFloat
    let change: (TaskTimelineZoom) -> Void

    func makeNSView(context: Context) -> Probe { Probe(frame: .zero) }

    func updateNSView(_ view: Probe, context: Context) {
        view.change = change
        view.update(zoom, dayWidth: dayWidth)
    }

    static func dismantleNSView(_ view: Probe, coordinator: ()) { view.stop() }

    final class Probe: NSView {
        var change: ((TaskTimelineZoom) -> Void)?
        private var zoom = TaskTimelineZoom.standard
        private var dayWidth: CGFloat = 0
        private var pendingZoom: TaskTimelineZoom?
        private var anchor: TaskTimelineZoomAnchor?
        private var scheduled = false
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.magnify, .scrollWheel]) { [weak self] event in
                self?.handle(event) == true ? nil : event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            anchor = nil
            pendingZoom = nil
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, window.isKeyWindow,
                  window.attachedSheet == nil, NSApp.modalWindow == nil, NSEvent.pressedMouseButtons == 0,
                  let clip = enclosingScrollView?.contentView,
                  clip.visibleRect.contains(clip.convert(event.locationInWindow, from: nil)) else { return false }
            let multiplier: Double
            if event.type == .magnify {
                multiplier = 1 + event.magnification
            } else {
                guard event.modifierFlags.contains(.control), event.scrollingDeltaY != 0 else { return false }
                guard event.momentumPhase.isEmpty else { return true }
                multiplier = exp(event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.008 : 0.12))
            }
            let current = pendingZoom ?? zoom
            let updated = current.scaled(by: multiplier)
            guard updated != current else { return true }
            if anchor == nil { anchor = makeAnchor(clip.convert(event.locationInWindow, from: nil), clip: clip) }
            pendingZoom = updated
            change?(updated)
            return true
        }

        func update(_ value: TaskTimelineZoom, dayWidth updatedWidth: CGFloat) {
            defer { zoom = value; dayWidth = updatedWidth }
            guard updatedWidth != dayWidth else {
                if pendingZoom == value {
                    pendingZoom = nil
                    if !scheduled { anchor = nil }
                }
                return
            }
            if anchor == nil, let clip = enclosingScrollView?.contentView {
                let rect = clip.visibleRect
                anchor = makeAnchor(CGPoint(x: rect.midX, y: rect.midY), clip: clip)
            }
            if pendingZoom == value { pendingZoom = nil }
            guard anchor != nil, !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in self?.restore() }
        }

        private func makeAnchor(_ point: CGPoint, clip: NSClipView) -> TaskTimelineZoomAnchor? {
            guard dayWidth > 0 else { return nil }
            let content = convert(point, from: clip)
            return TaskTimelineZoomAnchor(contentX: content.x - bounds.minX, dayWidth: dayWidth,
                                          viewportX: point.x - clip.bounds.minX)
        }

        private func restore() {
            scheduled = false
            if let pendingZoom, pendingZoom != zoom { return }
            defer { anchor = nil; pendingZoom = nil }
            guard let anchor, let scroll = enclosingScrollView else { return }
            window?.contentView?.layoutSubtreeIfNeeded()
            let clip = scroll.contentView
            let start = convert(bounds.origin, to: clip).x
            var proposed = clip.bounds
            proposed.origin.x = anchor.viewportOrigin(contentStart: start, dayWidth: dayWidth)
            clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
            scroll.reflectScrolledClipView(clip)
        }
    }
}
#elseif os(iOS)
private struct TaskTimelineZoomInput: UIViewRepresentable {
    let zoom: TaskTimelineZoom
    let dayWidth: CGFloat
    let change: (TaskTimelineZoom) -> Void

    func makeUIView(context: Context) -> Probe { Probe(frame: .zero) }

    func updateUIView(_ view: Probe, context: Context) {
        view.change = change
        view.update(zoom, dayWidth: dayWidth)
    }

    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.detach() }

    final class Probe: UIView {
        var change: ((TaskTimelineZoom) -> Void)?
        private weak var scroll: UIScrollView?
        private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        private var zoom = TaskTimelineZoom.standard
        private var dayWidth: CGFloat = 0
        private var pendingZoom: TaskTimelineZoom?
        private var anchor: TaskTimelineZoomAnchor?
        private var scheduled = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            connect()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            connect()
        }

        func detach() {
            scroll?.removeGestureRecognizer(pinch)
            scroll = nil
            anchor = nil
            pendingZoom = nil
        }

        private func connect() {
            guard window != nil else { detach(); return }
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            guard let target = ancestor as? UIScrollView, target !== scroll else { return }
            detach()
            scroll = target
            target.addGestureRecognizer(pinch)
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let scroll, gesture.numberOfTouches == 2,
                  gesture.state == .began || gesture.state == .changed else { return }
            let current = pendingZoom ?? zoom
            let updated = current.scaled(by: gesture.scale)
            gesture.scale = 1
            guard updated != current else { return }
            if anchor == nil { anchor = makeAnchor(gesture.location(in: scroll), scroll: scroll) }
            pendingZoom = updated
            change?(updated)
        }

        func update(_ value: TaskTimelineZoom, dayWidth updatedWidth: CGFloat) {
            defer { zoom = value; dayWidth = updatedWidth }
            guard updatedWidth != dayWidth else {
                if pendingZoom == value {
                    pendingZoom = nil
                    if !scheduled { anchor = nil }
                }
                return
            }
            if anchor == nil, let scroll {
                anchor = makeAnchor(CGPoint(x: scroll.bounds.midX, y: scroll.bounds.midY), scroll: scroll)
            }
            if pendingZoom == value { pendingZoom = nil }
            guard anchor != nil, !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in self?.restore() }
        }

        private func makeAnchor(_ point: CGPoint, scroll: UIScrollView) -> TaskTimelineZoomAnchor? {
            guard dayWidth > 0 else { return nil }
            let content = convert(point, from: scroll)
            return TaskTimelineZoomAnchor(contentX: content.x - bounds.minX, dayWidth: dayWidth,
                                          viewportX: point.x - scroll.bounds.minX)
        }

        private func restore() {
            scheduled = false
            if let pendingZoom, pendingZoom != zoom { return }
            defer { anchor = nil; pendingZoom = nil }
            guard let anchor, let scroll else { return }
            scroll.layoutIfNeeded()
            let inset = scroll.adjustedContentInset
            let start = convert(bounds.origin, to: scroll).x
            let origin = anchor.viewportOrigin(contentStart: start, dayWidth: dayWidth)
            let minimum = -inset.left
            let maximum = max(minimum, scroll.contentSize.width - scroll.bounds.width + inset.right)
            scroll.setContentOffset(CGPoint(x: min(maximum, max(minimum, origin)), y: scroll.contentOffset.y),
                                    animated: false)
        }
    }
}
#endif
