import AppKit
import SwiftUI

/// These controls intentionally participate in this form's key loop even when
/// the system preference limits ordinary Tab navigation to text/date controls.
final class SearchDateButton: NSButton {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    var isCancel = false
    override var acceptsFirstResponder: Bool { isEnabled && !isHidden }
    override var canBecomeKeyView: Bool { acceptsFirstResponder }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: if isCancel { onCancel?() } else { onConfirm?() }
        case 53: onCancel?()
        case 49: performClick(nil)
        default: super.keyDown(with: event)
        }
    }
}

final class SearchDateField: NSDatePicker {
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: validateEditing(); onConfirm?()
        case 53: onCancel?()
        default: super.keyDown(with: event)
        }
    }
}

struct SearchCustomDateForm: NSViewRepresentable {
    @Binding var draft: SearchCustomDateDraft
    let onApply: (SearchCustomDateDraft) -> Void
    let onCancel: () -> Void
    func makeNSView(context: Context) -> SearchDateFormView {
        let view = SearchDateFormView()
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: SearchDateFormView, context: Context) {
        view.onChange = { draft = $0 }
        view.onApply = onApply
        view.onCancel = onCancel
        view.update(draft)
    }
}

final class SearchDateFormView: NSView {
    let fromToggle = SearchDateButton(checkboxWithTitle: "Due from", target: nil, action: nil)
    let toToggle = SearchDateButton(checkboxWithTitle: "Due to", target: nil, action: nil)
    let fromDate = SearchDateField()
    let toDate = SearchDateField()
    let cancel = SearchDateButton(title: "Cancel", target: nil, action: nil)
    let confirm = SearchDateButton(title: "Confirm", target: nil, action: nil)
    let hint = NSTextField(labelWithString: "Pick at least one bound.")
    var onChange: ((SearchCustomDateDraft) -> Void)?
    var onApply: ((SearchCustomDateDraft) -> Void)?
    var onCancel: (() -> Void)?
    private var initializedFocus = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let title = NSTextField(labelWithString: "Custom Date Range")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        for field in [fromDate, toDate] {
            field.datePickerStyle = .textFieldAndStepper
            field.datePickerElements = .yearMonthDay
            field.font = .systemFont(ofSize: 13)
            field.target = self; field.action = #selector(changed)
            field.onConfirm = { [weak self] in self?.apply() }
            field.onCancel = { [weak self] in self?.onCancel?() }
        }
        fromDate.setAccessibilityLabel("Due from date")
        toDate.setAccessibilityLabel("Due to date")
        for button in [fromToggle, toToggle, cancel, confirm] {
            button.font = .systemFont(ofSize: 13)
            button.target = self
            button.onConfirm = { [weak self] in self?.apply() }
            button.onCancel = { [weak self] in self?.onCancel?() }
        }
        fromToggle.action = #selector(changed); toToggle.action = #selector(changed)
        cancel.action = #selector(cancelled); confirm.action = #selector(confirmed)
        cancel.isCancel = true
        cancel.bezelStyle = .rounded; confirm.bezelStyle = .rounded
        let first = NSStackView(views: [fromToggle, fromDate])
        let second = NSStackView(views: [toToggle, toDate])
        for row in [first, second] { row.orientation = .horizontal; row.spacing = 12; row.distribution = .fill }
        fromToggle.widthAnchor.constraint(equalToConstant: 88).isActive = true
        toToggle.widthAnchor.constraint(equalToConstant: 88).isActive = true
        let spacer = NSView()
        let footer = NSStackView(views: [spacer, cancel, confirm]); footer.spacing = 8
        let stack = NSStackView(views: [title, first, second, hint, footer])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            first.widthAnchor.constraint(equalTo: stack.widthAnchor),
            second.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !initializedFocus else { return }
        initializedFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self.fromToggle)
        }
    }
    var currentDraft: SearchCustomDateDraft {
        SearchCustomDateDraft(from: fromDate.dateValue, hasFrom: fromToggle.state == .on,
                              to: toDate.dateValue, hasTo: toToggle.state == .on)
    }
    func update(_ draft: SearchCustomDateDraft) {
        fromToggle.state = draft.hasFrom ? .on : .off
        toToggle.state = draft.hasTo ? .on : .off
        if fromDate.dateValue != draft.from { fromDate.dateValue = draft.from }
        if toDate.dateValue != draft.to { toDate.dateValue = draft.to }
        fromDate.isEnabled = draft.hasFrom; toDate.isEnabled = draft.hasTo
        confirm.isEnabled = draft.canConfirm
        hint.stringValue = draft.canConfirm ? "" : "Pick at least one bound."
        rebuildKeyLoop()
    }
    var orderedKeyViews: [NSView] {
        var result: [NSView] = [fromToggle]
        if fromDate.isEnabled { result.append(fromDate) }
        result.append(toToggle)
        if toDate.isEnabled { result.append(toDate) }
        result.append(cancel)
        if confirm.isEnabled { result.append(confirm) }
        return result
    }
    private func rebuildKeyLoop() {
        let views = orderedKeyViews
        for index in views.indices { views[index].nextKeyView = views[(index + 1) % views.count] }
    }
    @objc private func changed() {
        let draft = currentDraft
        update(draft)
        onChange?(draft)
    }
    private func apply() {
        fromDate.validateEditing(); toDate.validateEditing()
        let draft = currentDraft
        guard draft.canConfirm else { return }
        onChange?(draft); onApply?(draft)
    }
    @objc private func confirmed() { apply() }
    @objc private func cancelled() { onCancel?() }
}
