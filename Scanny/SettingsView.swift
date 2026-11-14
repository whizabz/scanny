import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("namePrefix") private var prefix = NameTemplate.defaultPrefix
    @AppStorage("nameOrder") private var orderStored = NameTemplate.encode(NameTemplate.defaultOrder)
    @AppStorage("yearFormat") private var yearFormat = YearFormat.long.rawValue
    @AppStorage("monthFormat") private var monthFormat = MonthFormat.numeric.rawValue
    @AppStorage("dayFormat") private var dayFormat = DayFormat.padded.rawValue
    @AppStorage("use24Hour") private var use24Hour = true
    @AppStorage("includeSeconds") private var includeSeconds = true
    @AppStorage("nameSeparator") private var separator = NameSeparator.none.rawValue
    @AppStorage("autoLaunchScanner") private var autoLaunch = true
    @AppStorage("clearAfterMinutes") private var clearAfterMinutes = 0
    @AppStorage("defaultFormat") private var defaultFormat = ExportFormat.pdf.rawValue
    @AppStorage("defaultFilter") private var filterRaw = PageFilter.original.rawValue

    @State private var showInfo = false
    @State private var confirmReset = false

    private var isDefaultName: Bool {
        prefix == NameTemplate.defaultPrefix
            && orderStored == NameTemplate.encode(NameTemplate.defaultOrder)
            && yearFormat == YearFormat.long.rawValue
            && monthFormat == MonthFormat.numeric.rawValue
            && dayFormat == DayFormat.padded.rawValue
            && separator == NameSeparator.none.rawValue
            && use24Hour && includeSeconds
    }

    private func disclosureRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    private var order: [NameToken] { NameTemplate.decode(orderStored) }

    private var style: NameStyle {
        NameStyle(
            prefix: prefix,
            order: order,
            year: YearFormat(rawValue: yearFormat) ?? .long,
            month: MonthFormat(rawValue: monthFormat) ?? .numeric,
            day: DayFormat(rawValue: dayFormat) ?? .padded,
            use24Hour: use24Hour,
            includeSeconds: includeSeconds,
            separator: NameSeparator(rawValue: separator) ?? .none
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Open Scanner at Launch", isOn: $autoLaunch)
                    Picker("Clear Previous Scan After", selection: $clearAfterMinutes) {
                        Text("Never").tag(0)
                        ForEach([1, 2, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Default Filter", selection: $filterRaw) {
                        ForEach(PageFilter.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Picker("Default File Type", selection: $defaultFormat) {
                        ForEach(ExportFormat.allCases) { Text($0.title(pageCount: 1)).tag($0.rawValue) }
                    }
                }

                Section {
                    // Plain, centred text on a clear row so it reads as a label, not a field.
                    HStack {
                        Text(NameTemplate.generate(style: style))
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Reset File Name", systemImage: "arrow.counterclockwise") {
                            confirmReset = true
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(isDefaultName)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("File Name")
                        Button("About file names", systemImage: "info.circle") { showInfo = true }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .popover(isPresented: $showInfo) {
                                Text("Names always end with a date and time. Multiple images are numbered from 1, padded to match the page count.")
                                    .font(.footnote)
                                    .padding()
                                    .frame(width: 280)
                                    .presentationCompactAdaptation(.popover)
                            }
                    }
                }

                Section {
                    LabeledContent("Prefix") {
                        TextField("Scan", text: $prefix)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    NavigationLink("Order") { orderScreen }
                    NavigationLink("Date Format") { dateFormatScreen }
                    NavigationLink("Time Format") { timeFormatScreen }
                }

            }
            .alert("Reset file name?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetFileName() }
            } message: {
                Text("The prefix, order and date and time formats go back to their defaults.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private var orderScreen: some View {
        List {
            Section("Preview") {
                Text(NameTemplate.generate(style: style))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                ForEach(order) { Text($0.title) }
                    .onMove { from, to in
                        var updated = order
                        updated.move(fromOffsets: from, toOffset: to)
                        orderStored = NameTemplate.encode(updated)
                    }
            } footer: {
                Text("Drag to reorder.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Order")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateFormatScreen: some View {
        List {
            Section("Preview") {
                Text(NameTemplate.generate(style: style))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                Picker("Year", selection: $yearFormat) {
                    ForEach(YearFormat.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Month", selection: $monthFormat) {
                    ForEach(MonthFormat.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Date", selection: $dayFormat) {
                    ForEach(DayFormat.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Separator", selection: $separator) {
                    ForEach(NameSeparator.allCases) { Text($0.title).tag($0.rawValue) }
                }
            }
        }
        .navigationTitle("Date Format")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeFormatScreen: some View {
        List {
            Section("Preview") {
                Text(NameTemplate.generate(style: style))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                Picker("Clock", selection: $use24Hour) {
                    Text("24-hour").tag(true)
                    Text("12-hour (AM/PM)").tag(false)
                }
                Toggle("Include seconds", isOn: $includeSeconds)
            }
        }
        .navigationTitle("Time Format")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Puts the prefix, order and every date/time option back to their defaults.
    private func resetFileName() {
        prefix = NameTemplate.defaultPrefix
        orderStored = NameTemplate.encode(NameTemplate.defaultOrder)
        yearFormat = YearFormat.long.rawValue
        monthFormat = MonthFormat.numeric.rawValue
        dayFormat = DayFormat.padded.rawValue
        separator = NameSeparator.none.rawValue
        use24Hour = true
        includeSeconds = true
    }
}
