/// Mac Calendar presentation only. This is an explicit Taskovsky approximation,
/// not a recovered TickTick cutoff. Reserve one title em beside the 10pt icon
/// and the existing 5pt gap after padding and any move grip have been removed.
/// Width is the actual timed-card allocation, never window size or title length.
public enum CalendarCardLayout {
    public static let horizontalPadding: Double = 8
    public static let completionIconWidth: Double = 10
    public static let iconSpacing: Double = 5

    public static func showsCompletionCheckbox(
        cardWidth: Double?, trailingInset: Double = 0, compact: Bool = false,
        iconsEnabled: Bool = true, forceReveal: Bool = false
    ) -> Bool {
        // Option is a transient reveal, not a mutation of the saved preference.
        if forceReveal { return true }
        guard iconsEnabled else { return false }
        // Non-timed surfaces do not opt into this bounded change.
        guard let cardWidth else { return true }
        guard cardWidth.isFinite, trailingInset.isFinite else { return false }
        let contentWidth = max(0, cardWidth - horizontalPadding - max(0, trailingInset))
        let titleEm: Double = compact ? 11 : 12
        return contentWidth >= completionIconWidth + iconSpacing + titleEm
    }
}
