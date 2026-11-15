import SwiftUI
import VisionKit
import PhotosUI
import TipKit

struct ContentView: View {
    // Held in memory only. Nothing is saved, so closing the app clears the scan.
    @State private var items: [PageItem] = []
    @State private var pageToDelete: UUID?
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var isPoofing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pages that will be exported. New pages start selected.
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectedID: UUID?
    @State private var format: ExportFormat =
        ExportFormat(rawValue: UserDefaults.standard.string(forKey: "defaultFormat") ?? "") ?? .pdf
    @State private var exportFiles: [URL] = []
    @State private var confirmDiscard = false
    @State private var docName = ""
    @State private var showSettings = false
    @State private var backgroundedAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    @State private var quickActions = QuickActions.shared
    @AppStorage("clearAfterSeconds") private var clearAfterSeconds = 60
    @AppStorage("autoLaunchScanner") private var autoLaunch = false
    @AppStorage("defaultFormat") private var defaultFormatRaw = ExportFormat.pdf.rawValue
    @AppStorage("defaultFilter") private var defaultFilterRaw = PageFilter.original.rawValue

    // The scanner controller is kept alive so "Edit" can reopen the same session.
    @State private var scanner: VNDocumentCameraViewController? =
        DocumentScanner.isSupported ? VNDocumentCameraViewController() : nil
    @State private var isScanning = DocumentScanner.isSupported
        && (UserDefaults.standard.object(forKey: "autoLaunchScanner") as? Bool ?? false)
    @State private var screenWidth: CGFloat = 390
    // Bar and button heights grow with Dynamic Type so large text isn't clipped.
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 50
    @ScaledMetric(relativeTo: .body) private var nameHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var actionSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var emptyButtonWidth: CGFloat = 200

    /// "Share", or "Share (3)" when several images will be shared.
    private var shareTitle: String {
        format == .images && selectedItems.count > 1 ? "Share (\(selectedItems.count))" : "Share"
    }

    private var pages: [UIImage] { items.map(\.rendered) }
    private var selectedItems: [PageItem] { items.filter { selectedIDs.contains($0.id) } }
    private var selectedPages: [UIImage] { selectedItems.map(\.rendered) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                        .safeAreaInset(edge: .bottom) {
                            // Hidden once dismissed, or once the setting is already on.
                            if !autoLaunch {
                                TipView(AutoLaunchTip()) { action in
                                    if action.id == "settings" { showSettings = true }
                                }
                                .tipViewStyle(LinkTipStyle())
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                } else {
                    reviewGrid
                        // Discarding: the pages shrink away inside a puff of smoke.
                        .scaleEffect(isPoofing ? 0.4 : 1)
                        .opacity(isPoofing ? 0 : 1)
                        .blur(radius: isPoofing ? 8 : 0)
                        .overlay { if isPoofing { PoofCloud() } }
                        .allowsHitTesting(!isPoofing)
                        .safeAreaInset(edge: .bottom) { shareBar }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(item: $selectedID) { id in
                if let index = items.firstIndex(where: { $0.id == id }) {
                    PageDetailView(
                        item: items[index],
                        number: index + 1,
                        onSave: { saved in update(id) { $0 = saved } },
                        onDelete: { pageToDelete = id },
                        onClose: { selectedID = nil }
                    )
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .fullScreenCover(isPresented: $isScanning) {
            if let scanner {
                DocumentScanner(
                    controller: scanner,
                    onFinish: { images in
                        addPages(images)
                        isScanning = false
                    },
                    onCancel: { isScanning = false }
                )
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhotos, matching: .images)
        .onChange(of: pickedPhotos) { _, picked in
            guard !picked.isEmpty else { return }
            Task { await importPhotos(picked) }
        }
        .onChange(of: quickActions.importRequested, initial: true) { _, requested in
            // Long-press "Import Photo" on the app icon.
            guard requested else { return }
            quickActions.importRequested = false
            if !isScanning { showPhotoPicker = true }
        }
        .onChange(of: quickActions.scanRequested, initial: true) { _, requested in
            // Long-press "Scan a document" on the app icon.
            guard requested else { return }
            quickActions.scanRequested = false
            if !isScanning { startScan() }
        }
        .onOpenURL { url in
            // scanny://scan, used by the lock screen widget.
            guard url.scheme == "scanny", url.host == "scan", !isScanning else { return }
            startScan()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = .now
            case .active:
                guard let left = backgroundedAt else { return }
                backgroundedAt = nil
                if clearAfterSeconds > 0, !items.isEmpty, !isScanning,
                   Date.now.timeIntervalSince(left) >= Double(clearAfterSeconds) {
                    expireScan()
                }
            default:
                break
            }
        }
        .task(id: ExportKey(signature: selectedItems.map(\.signature), format: format, name: docName)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            // Encoding pages is slow; do it off the main thread so taps stay responsive.
            let (images, fmt, name) = (selectedPages, format, docName)
            let files = await Task.detached(priority: .userInitiated) {
                ScanExport.files(for: images, format: fmt, name: name)
            }.value
            guard !Task.isCancelled else { return }
            exportFiles = files
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPoofing) { _, new in new }
        .alert("Delete this scan?", isPresented: $confirmDiscard) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { discard() }
        } message: {
            Text("The scanned pages will be removed. This can't be undone.")
        }
        .alert("Delete this page?", isPresented: Binding(
            get: { pageToDelete != nil },
            set: { if !$0 { pageToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                items.removeAll { $0.id == pageToDelete }
                if let id = pageToDelete { selectedIDs.remove(id) }
                selectedID = nil
                if items.isEmpty { ScanExport.clear() }
            }
        } message: {
            Text("This page will be removed from the scan.")
        }
    }

    // MARK: Scanning

    /// Starts a brand-new scanner session. New pages are added to the document.
    private func startScan() {
        guard DocumentScanner.isSupported else { return }
        scanner = VNDocumentCameraViewController()
        isScanning = true
    }

    /// Adds scanned pages, applying the default filter. The first pages of a new
    /// scan also get an auto-generated name from the template in Settings.
    private func addPages(_ images: [UIImage], crops: [[CGPoint]?] = []) {
        if items.isEmpty {
            docName = NameTemplate.generateFromDefaults()
            format = ExportFormat(rawValue: defaultFormatRaw) ?? .pdf
        }
        let filter = PageFilter(rawValue: defaultFilterRaw) ?? .original
        let new: [PageItem] = images.enumerated().map { index, image in
            var item = PageItem(image)
            if index < crops.count, let quad = crops[index] { item.setCrop(quad) }
            if filter != .original { item.setFilter(filter) }
            return item
        }
        items.append(contentsOf: new)
        selectedIDs.formUnion(new.map(\.id))
    }

    private func importPhotos(_ picked: [PhotosPickerItem]) async {
        let results = await PhotoImport.load(picked)
        pickedPhotos = []
        guard !results.isEmpty else { return }
        addPages(results.map(\.image), crops: results.map(\.crop))
    }

    /// The app was away longer than the "clear after" setting: drop the old scan.
    private func expireScan() {
        docName = ""
        items = []
        selectedIDs = []
        exportFiles = []
        selectedID = nil
        pageToDelete = nil
        ScanExport.clear()
        if autoLaunch { startScan() }
    }

    /// Discards the scan with a puff of smoke, then returns to the home screen.
    private func discard() {
        guard !reduceMotion else { clearScan(); return }
        withAnimation(.easeIn(duration: 0.35)) { isPoofing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(850))
            clearScan()
            isPoofing = false
        }
    }

    private func clearScan() {
        AccessibilityNotification.Announcement("Scan deleted").post()
        docName = ""
        items = []
        selectedIDs = []
        exportFiles = []
        selectedID = nil
        ScanExport.clear()
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Text("Scan a document")
                .font(.title.bold())
        } description: {
            Text(DocumentScanner.isSupported
                 ? "Scans are ephemeral: Scan, share, and poof!"
                 : "Document scanning needs a device with a camera.")
            .font(.footnote)
        } actions: {
            if DocumentScanner.isSupported {
                Button { startScan() } label: {
                    Label("New Scan", systemImage: "doc.viewfinder")
                        .frame(minWidth: emptyButtonWidth)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            Button { showPhotoPicker = true } label: {
                Label("Import from Photos", systemImage: "photo.on.rectangle")
                    .frame(minWidth: emptyButtonWidth)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            #if DEBUG && targetEnvironment(simulator)
            Button("Load Sample Pages") { addPages(SamplePages.make()) }
                .buttonStyle(.glass)
            #endif
        }
    }

    // MARK: Review

    private var reviewGrid: some View {
        ScrollView {
            HStack {
                Text("\(selectedItems.count) of \(items.count) selected")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("All") { selectedIDs = Set(items.map(\.id)) }
                    .disabled(selectedIDs.count == items.count)
                    .accessibilityLabel("Select All Pages")
                Button("None") { selectedIDs = [] }
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityLabel("Deselect All Pages")
            }
            .buttonStyle(.glass)
            .controlSize(.regular)
            .padding(.horizontal)
            .padding(.top, 20)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let number = index + 1
                    let isSelected = selectedIDs.contains(item.id)
                    VStack(spacing: 10) {
                        Button { selectedID = item.id } label: {
                            // Fixed-ratio frame so rotating never changes the layout.
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                                .overlay {
                                    Image(uiImage: item.rendered)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(.rect(cornerRadius: 8))
                                        .shadow(radius: 6, y: 2)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(number)")
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .accessibilityHint("Opens the page editor")
                        // VoiceOver users can act on a page without hunting for small buttons.
                        .accessibilityAction(named: isSelected ? "Deselect" : "Select") { toggleSelection(item.id) }
                        .accessibilityAction(named: "Rotate Left") { update(item.id) { $0.rotateLeft() } }
                        .accessibilityAction(named: "Rotate Right") { update(item.id) { $0.rotate() } }
                        .accessibilityAction(named: "Delete Page") { pageToDelete = item.id }
                        .opacity(isSelected ? 1 : 0.5)
                        .overlay(alignment: .topTrailing) { selectionMark(for: item, number: number) }
                        pageActions(for: item, number: number)
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    private func selectionMark(for item: PageItem, number: Int) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        return Button {
            toggleSelection(item.id)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .symbolRenderingMode(isSelected ? .palette : .monochrome)
                // Like Photos: a white ring with a soft shadow when unselected.
                .foregroundStyle(Color.white, Color.accentColor)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .padding(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select Page \(number)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func pageActions(for item: PageItem, number: Int) -> some View {
        // One Liquid Glass capsule holding all three actions.
        HStack(spacing: 4) {
            Button("Rotate Left", systemImage: "rotate.left") {
                update(item.id) { $0.rotateLeft() }
            }
            .frame(width: actionSize, height: actionSize)
            .accessibilityLabel("Rotate Page \(number) Left")
            .accessibilityInputLabels(["Rotate Left", "Rotate Page \(number) Left"])
            Button("Rotate Right", systemImage: "rotate.right") {
                update(item.id) { $0.rotate() }
            }
            .frame(width: actionSize, height: actionSize)
            .accessibilityLabel("Rotate Page \(number) Right")
            .accessibilityInputLabels(["Rotate Right", "Rotate Page \(number) Right"])
            Button("Delete Page", systemImage: "trash", role: .destructive) {
                pageToDelete = item.id
            }
            .foregroundStyle(.red)
            .frame(width: actionSize, height: actionSize)
            .accessibilityLabel("Delete Page \(number)")
            .accessibilityInputLabels(["Delete Page", "Delete Page \(number)"])
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .glassEffect(.regular.interactive(), in: .capsule)
        .imageScale(.medium)
        .font(.body)
        .buttonBorderShape(.circle)
    }

    /// Format dropdown on the left, Share filling the remaining width.
    private var shareBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("Name")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true) // the field below carries the label
                TextField("Name", text: $docName)
                    .labelsHidden()
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: nameHeight)
            .glassEffect(.regular.interactive(), in: .capsule)
            actionRow
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            // A menu picker draws its own small pill and ignores sizing, so a Menu
            // with a glass button label is used to match the Share button's height.
            Menu {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { Text($0.title(pageCount: selectedItems.count)).tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    // Widest option laid out invisibly so the width never changes.
                    ZStack {
                        ForEach(ExportFormat.allCases) { Text($0.title(pageCount: selectedItems.count)).hidden() }
                        Text(format.title(pageCount: selectedItems.count))
                    }
                    Image(systemName: "chevron.up.chevron.down").imageScale(.small)
                }
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .frame(height: barHeight)
            .accessibilityLabel("File Type")
            .accessibilityValue(format.title(pageCount: selectedItems.count))
            .fixedSize(horizontal: true, vertical: false)

            ShareLink(items: exportFiles) {
                Label(shareTitle, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(height: barHeight)
            .disabled(exportFiles.isEmpty)
        }
    }

    private func update(_ id: UUID, _ change: (inout PageItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }

    // MARK: Toolbars

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if items.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
        }
        if !items.isEmpty {
            if DocumentScanner.isSupported {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add Pages", systemImage: "doc.badge.plus") { startScan() }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete Scan", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                    .tint(.red)
            }
        }
    }
}

private struct ExportKey: Hashable {
    let signature: [String]
    let format: ExportFormat
    let name: String
}

#if DEBUG && targetEnvironment(simulator)
enum SamplePages {
    static func make() -> [UIImage] {
        (1...3).map { n in
            let size = CGSize(width: 850, height: 1100)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor(white: 0.97, alpha: 1).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let title = "Sample page \(n)" as NSString
                title.draw(at: CGPoint(x: 80, y: 90),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 48)])
                UIColor(white: 0.7, alpha: 1).setFill()
                for row in 0..<18 {
                    ctx.fill(CGRect(x: 80, y: 220 + row * 40, width: row % 5 == 4 ? 400 : 690, height: 14))
                }
            }
        }
    }
}
#endif
