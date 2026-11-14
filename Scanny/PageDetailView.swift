import SwiftUI

/// Full-size page with editing tools. Edits apply to a draft that is only kept
/// when the user taps the check mark.
struct PageDetailView: View {
    let item: PageItem
    let number: Int
    var onSave: (PageItem) -> Void
    var onDelete: () -> Void
    var onClose: () -> Void

    @State private var draft: PageItem
    @State private var isCropping = false
    @State private var confirmDiscard = false

    init(item: PageItem, number: Int,
         onSave: @escaping (PageItem) -> Void,
         onDelete: @escaping () -> Void,
         onClose: @escaping () -> Void) {
        self.item = item
        self.number = number
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClose = onClose
        _draft = State(initialValue: item)
    }

    private var hasChanges: Bool { draft.signature != item.signature }

    var body: some View {
        Image(uiImage: draft.rendered)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 8))
            .shadow(radius: 8, y: 2)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Page \(number)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard Changes", systemImage: "xmark") {
                        if hasChanges { confirmDiscard = true } else { onClose() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(draft)
                        onClose()
                    }
                    .buttonStyle(.glassProminent)
                }
                // One group, so the tools share a single Liquid Glass pill.
                ToolbarItemGroup(placement: .bottomBar) {
                    Menu {
                        Picker("Filter", selection: Binding(
                            get: { draft.filter },
                            set: { draft.setFilter($0) }
                        )) {
                            ForEach(PageFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Filter", systemImage: "camera.filters")
                    }
                    Button("Crop", systemImage: "crop") { isCropping = true }
                    Button("Rotate Left", systemImage: "rotate.left") { draft.rotateLeft() }
                    Button("Rotate Right", systemImage: "rotate.right") { draft.rotate() }
                    Button("Delete Page", systemImage: "trash", role: .destructive) { onDelete() }
                        .tint(.red)
                }
            }
            .fullScreenCover(isPresented: $isCropping) {
                CropView(
                    image: draft.original,
                    initial: draft.crop,
                    onApply: { quad in
                        draft.setCrop(quad)
                        isCropping = false
                    },
                    onCancel: { isCropping = false }
                )
            }
            .alert("Discard changes?", isPresented: $confirmDiscard) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) { onClose() }
            } message: {
                Text("Your edits to this page will be lost.")
            }
    }
}
