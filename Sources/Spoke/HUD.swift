import AppKit
import SwiftUI

/// Small floating pill near the bottom of the screen showing what Spoke is doing.
/// It never takes focus or clicks, so typing stays in the app you're using.
final class HUD {
    enum Phase: Equatable {
        case recording
        case processing
        case message(String)
    }

    final class Model: ObservableObject {
        @Published var phase: Phase = .recording
        @Published var elapsed: TimeInterval = 0
        @Published var level: Float = 0
    }

    let model = Model()
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
    }

    func show(_ phase: Phase) {
        hideWork?.cancel()
        model.phase = phase
        position()
        panel.orderFrontRegardless()
        if case .message = phase {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        }
    }

    func hide() {
        hideWork?.cancel()
        panel.orderOut(nil)
    }

    /// Bottom-center of the screen the mouse is on.
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 60))
    }
}

private struct HUDView: View {
    @ObservedObject var model: HUD.Model

    var body: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .recording:
                Circle().fill(Color.red).frame(width: 10, height: 10)
                LevelBars(level: model.level)
                Text(timeString(model.elapsed)).monospacedDigit()
                Spacer(minLength: 0)
                Text("esc to cancel").foregroundStyle(.secondary).font(.caption)
            case .processing:
                ProgressView().controlSize(.small)
                Text("Tidying up…")
                Spacer(minLength: 0)
            case .message(let text):
                Text(text).lineLimit(2).font(.callout)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(width: 240, height: 44)
        .background(Capsule().fill(Color.black.opacity(0.82)))
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct LevelBars: View {
    let level: Float

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { i in
                let threshold = Float(i) / 5
                Capsule()
                    .fill(Color.white.opacity(level > threshold ? 0.95 : 0.3))
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
        .frame(height: 18)
        .animation(.linear(duration: 0.08), value: level)
    }
}
