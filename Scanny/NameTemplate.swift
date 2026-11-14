import Foundation

/// The pieces a file name can contain. Users can reorder them, but a name is
/// always a date + time combination. Time is one block (hours, minutes, seconds
/// always keep their order).
enum NameToken: String, CaseIterable, Identifiable {
    case year, month, day, time
    var id: String { rawValue }

    var title: String {
        switch self {
        case .year: "Year"
        case .month: "Month"
        case .day: "Date"
        case .time: "Time"
        }
    }

    var isDate: Bool { self != .time }
}

enum YearFormat: String, CaseIterable, Identifiable {
    case long, short
    var id: String { rawValue }
    var title: String { self == .long ? "YYYY (2026)" : "YY (26)" }
}

enum MonthFormat: String, CaseIterable, Identifiable {
    case numeric, abbreviated, full
    var id: String { rawValue }
    var title: String {
        switch self {
        case .numeric: "MM (11)"
        case .abbreviated: "MMM (Nov)"
        case .full: "MMMM (November)"
        }
    }
}

enum DayFormat: String, CaseIterable, Identifiable {
    case padded, plain
    var id: String { rawValue }
    var title: String { self == .padded ? "DD (01, 02, 14)" : "D (1, 2, 14)" }
}

enum NameSeparator: String, CaseIterable, Identifiable {
    case none, dash, underscore, dot
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "None"
        case .dash: "Dash ( - )"
        case .underscore: "Underscore ( _ )"
        case .dot: "Dot ( . )"
        }
    }
    var text: String {
        switch self {
        case .none: ""
        case .dash: "-"
        case .underscore: "_"
        case .dot: "."
        }
    }
}

/// Everything that shapes a generated name. Stored in UserDefaults under the
/// same keys the Settings screen binds to with @AppStorage.
struct NameStyle {
    var prefix = NameTemplate.defaultPrefix
    var order: [NameToken] = NameTemplate.defaultOrder
    var year: YearFormat = .long
    var month: MonthFormat = .numeric
    var day: DayFormat = .padded
    var use24Hour = true
    var includeSeconds = true
    var separator: NameSeparator = .none

    static func fromDefaults() -> NameStyle {
        let d = UserDefaults.standard
        var style = NameStyle()
        style.prefix = d.string(forKey: "namePrefix") ?? NameTemplate.defaultPrefix
        style.order = NameTemplate.decode(d.string(forKey: "nameOrder") ?? "")
        style.year = YearFormat(rawValue: d.string(forKey: "yearFormat") ?? "") ?? .long
        style.month = MonthFormat(rawValue: d.string(forKey: "monthFormat") ?? "") ?? .numeric
        style.day = DayFormat(rawValue: d.string(forKey: "dayFormat") ?? "") ?? .padded
        style.use24Hour = d.object(forKey: "use24Hour") as? Bool ?? true
        style.includeSeconds = d.object(forKey: "includeSeconds") as? Bool ?? true
        style.separator = NameSeparator(rawValue: d.string(forKey: "nameSeparator") ?? "") ?? .none
        return style
    }
}

enum NameTemplate {
    static let defaultPrefix = "Scan"
    static let defaultOrder: [NameToken] = [.year, .month, .day, .time]

    static func decode(_ stored: String) -> [NameToken] {
        var order: [NameToken] = []
        for part in stored.split(separator: ",") {
            if let token = NameToken(rawValue: String(part)), !order.contains(token) { order.append(token) }
        }
        // Every part stays present, so the name is always a full date and time.
        for token in defaultOrder where !order.contains(token) { order.append(token) }
        return order
    }

    static func encode(_ order: [NameToken]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    /// e.g. "Scan-20261114-080301". Consecutive date parts are joined with the
    /// chosen separator; prefix, date and time are separated by a dash.
    static func generate(style: NameStyle, date: Date = .now) -> String {
        var groups: [(isDate: Bool, parts: [String])] = []
        for token in style.order {
            let text = text(for: token, style: style, date: date)
            if token.isDate, let last = groups.last, last.isDate {
                groups[groups.count - 1].parts += text
            } else {
                groups.append((token.isDate, text))
            }
        }
        let joined = groups.map { $0.parts.joined(separator: style.separator.text) }
        return ([cleaned(style.prefix)] + joined).joined(separator: "-")
    }

    static func generateFromDefaults(date: Date = .now) -> String {
        generate(style: .fromDefaults(), date: date)
    }

    private static func text(for token: NameToken, style: NameStyle, date: Date) -> [String] {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        switch token {
        case .year:
            let y = c.year ?? 0
            return [style.year == .long ? String(format: "%04d", y) : String(format: "%02d", y % 100)]
        case .month:
            switch style.month {
            case .numeric: return [String(format: "%02d", c.month ?? 0)]
            case .abbreviated: return [monthName("MMM", date)]
            case .full: return [monthName("MMMM", date)]
            }
        case .day:
            return [style.day == .padded ? String(format: "%02d", c.day ?? 0) : String(c.day ?? 0)]
        case .time:
            let hour = c.hour ?? 0
            let shown = style.use24Hour ? hour : (hour % 12 == 0 ? 12 : hour % 12)
            var parts = [String(format: "%02d", shown), String(format: "%02d", c.minute ?? 0)]
            if style.includeSeconds { parts.append(String(format: "%02d", c.second ?? 0)) }
            if !style.use24Hour {
                // Keep AM/PM attached to the last number: 0803PM
                parts[parts.count - 1] += hour < 12 ? "AM" : "PM"
            }
            return parts
        }
    }

    private static func monthName(_ format: String, _ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    static func cleaned(_ prefix: String) -> String {
        let bad = CharacterSet(charactersIn: "/:\\")
        let trimmed = prefix.components(separatedBy: bad).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultPrefix : trimmed
    }

    static func fileSafe(_ name: String) -> String { cleaned(name) }
}
