import SwiftUI

/// Perspective crop: drag the four corners over the page, then apply.
struct CropView: View {
    let image: UIImage
    var onApply: ([CGPoint]?) -> Void
    var onCancel: () -> Void

    @State private var quad: [CGPoint]
    @State private var undoStack: [[CGPoint]] = []
    @State private var redoStack: [[CGPoint]] = []
    @State private var isDragging = false
    private static let full = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]

    init(image: UIImage, initial: [CGPoint]?, onApply: @escaping ([CGPoint]?) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onApply = onApply
        self.onCancel = onCancel
        _quad = State(initialValue: initial ?? Self.full)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let rect = fitted(image.size, in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                    Path { path in
                        path.move(to: mapped(quad[0], rect))
                        for i in 1..<4 { path.addLine(to: mapped(quad[i], rect)) }
                        path.closeSubpath()
                    }
                    .fill(Color.accentColor.opacity(0.15))
                    Path { path in
                        path.move(to: mapped(quad[0], rect))
                        for i in 1..<4 { path.addLine(to: mapped(quad[i], rect)) }
                        path.closeSubpath()
                    }
                    .stroke(Color.accentColor, lineWidth: 2)
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(.white)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle().inset(by: -12))
                            .position(mapped(quad[i], rect))
                            .gesture(
                                DragGesture(coordinateSpace: .named("crop"))
                                    .onChanged { value in
                                        if !isDragging {
                                            isDragging = true
                                            undoStack.append(quad)
                                            redoStack.removeAll()
                                        }
                                        quad[i] = CGPoint(
                                            x: min(max((value.location.x - rect.minX) / rect.width, 0), 1),
                                            y: min(max((value.location.y - rect.minY) / rect.height, 0), 1))
                                    }
                                    .onEnded { _ in isDragging = false }
                            )
                    }
                }
                .coordinateSpace(name: "crop")
            }
            .padding()
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark") { onCancel() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        guard let previous = undoStack.popLast() else { return }
                        redoStack.append(quad)
                        quad = previous
                    }
                    .disabled(undoStack.isEmpty)
                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        guard let next = redoStack.popLast() else { return }
                        undoStack.append(quad)
                        quad = next
                    }
                    .disabled(redoStack.isEmpty)
                    Spacer()
                    Button("Reset", systemImage: "arrow.up.left.and.arrow.down.right") {
                        guard quad != Self.full else { return }
                        undoStack.append(quad)
                        redoStack.removeAll()
                        quad = Self.full
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") {
                        onApply(quad == Self.full ? nil : quad)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func fitted(_ size: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / size.width, container.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }

    private func mapped(_ p: CGPoint, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }
}
