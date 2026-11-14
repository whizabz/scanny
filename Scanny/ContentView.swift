import SwiftUI
import VisionKit

struct ContentView: View {
    // Held in memory only. Nothing is saved, so closing the app clears the scan.
    @State private var items: [PageItem] = []
    @State private var pageToDelete: UUID?
    @State private var selectedID: UUID?
    @State private var format: ExportFormat = .pdf
    @State private var exportFiles: [URL] = []
    @State private var confirmDiscard = false
    @State private var docName = ""
    @State private var showSettings = false
    @State private var backgroundedAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("clearAfterMinutes") private var clearAfterMinutes = 0
    @AppStorage("autoLaunchScanner") private var autoLaunch = true
    @AppStorage("defaultFilter") private var defaultFilterRaw = PageFilter.original.rawValue

    // The scanner controller is kept alive so "Edit" can reopen the same session.
    @State private var scanner: VNDocumentCameraViewController? =
        DocumentScanner.isSupported ? VNDocumentCameraViewController() : nil
    @State private var isScanning = DocumentScanner.isSupported
        && (UserDefaults.standard.object(forKey: "autoLaunchScanner") as? Bool ?? true)
    @State private var screenWidth: CGFloat = 390

    private var pages: [UIImage] { items.map(\.rendered) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    reviewGrid
                }
            }
            .navigationTitle(items.isEmpty ? "Scanny" : "\(pages.count) \(pages.count == 1 ? "Page" : "Pages")")
            .navigationBarTitleDisplayMode(items.isEmpty ? .inline : .large)
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = .now
            case .active:
                guard let left = backgroundedAt else { return }
                backgroundedAt = nil
                if clearAfterMinutes > 0, !items.isEmpty, !isScanning,
                   Date.now.timeIntervalSince(left) >= Double(clearAfterMinutes) * 60 {
                    expireScan()
                }
            default:
                break
            }
        }
        .task(id: ExportKey(signature: items.map(\.signature), format: format, name: docName)) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            exportFiles = ScanExport.files(for: pages, format: format, name: docName)
        }
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
    private func addPages(_ images: [UIImage]) {
        if items.isEmpty {
            docName = NameTemplate.generateFromDefaults()
        }
        let filter = PageFilter(rawValue: defaultFilterRaw) ?? .original
        items.append(contentsOf: images.map { image in
            var item = PageItem(image)
            if filter != .original { item.setFilter(filter) }
            return item
        })
    }

    /// The app was away longer than the "clear after" setting: drop the old scan.
    private func expireScan() {
        docName = ""
        items = []
        exportFiles = []
        selectedID = nil
        pageToDelete = nil
        ScanExport.clear()
        if autoLaunch { startScan() }
    }

    private func discard() {
        docName = ""
        items = []
        exportFiles = []
        ScanExport.clear()
        startScan()
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Text("Scan a Document")
                .font(.title.bold())
        } description: {
            Text(DocumentScanner.isSupported
                 ? "Nothing is saved. Scans are cleared when you close the app."
                 : "Document scanning needs a device with a camera.")
            .font(.footnote)
        } actions: {
            if DocumentScanner.isSupported {
                Button("Scan", systemImage: "doc.viewfinder") { startScan() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
            #if DEBUG && targetEnvironment(simulator)
            Button("Load Sample Pages") { addPages(SamplePages.make()) }
                .buttonStyle(.glass)
            #endif
        }
    }

    // MARK: Review

    private var reviewGrid: some View {
        ScrollView {
            TextField("Name", text: $docName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(.horizontal)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 20) {
                ForEach(items) { item in
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
                        pageActions(for: item)
                    }
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func pageActions(for item: PageItem) -> some View {
        // One Liquid Glass capsule holding all three actions.
        HStack(spacing: 4) {
            Button("Rotate Left", systemImage: "rotate.left") {
                update(item.id) { $0.rotateLeft() }
            }
            .frame(width: 44, height: 40)
            Button("Rotate Right", systemImage: "rotate.right") {
                update(item.id) { $0.rotate() }
            }
            .frame(width: 44, height: 40)
            Button("Delete Page", systemImage: "trash", role: .destructive) {
                pageToDelete = item.id
            }
            .foregroundStyle(.red)
            .frame(width: 44, height: 40)
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
            // A segmented picker in a toolbar renders as the Liquid Glass pill.
            // Hiding the shared background avoids a second container behind it.
            ToolbarItem(placement: .bottomBar) {
                Picker("Share", selection: $format) {
                    ForEach(ExportFormat.allCases) { Text($0.title(pageCount: pages.count)).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: max(160, screenWidth - 130))
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .bottomBar) {
                ShareLink(items: exportFiles) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glassProminent)
                .disabled(exportFiles.isEmpty)
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
