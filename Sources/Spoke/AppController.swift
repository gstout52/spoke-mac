import AppKit
import AVFoundation

/// Runs the dictation flow: trigger -> record -> transcribe -> clean up -> paste.
final class AppController: NSObject, ObservableObject {
    static let shared = AppController()

    enum State { case idle, recording, processing }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastDictation: String?
    @Published var capturingMouseButton = false

    let settings = Settings.shared
    let monitor = TriggerMonitor()
    private let recorder = Recorder()
    private let hud = HUD()
    private var meterTimer: Timer?
    private var tapRetryTimer: Timer?
    private var work: Task<Void, Never>?
    private var holdStartedAt: Date?

    /// Shown in the menu bar; updated whenever the state changes.
    var onStateChange: ((State) -> Void)?

    func start() {
        monitor.onPress = { [weak self] in self?.triggerPressed() }
        monitor.onRelease = { [weak self] in self?.triggerReleased() }
        monitor.onEscape = { [weak self] in
            guard let self, self.state == .recording else { return false }
            self.cancel()
            return true
        }
        startMonitorWhenAllowed()
    }

    /// The event tap only works once Accessibility is granted; keep trying until it is.
    private func startMonitorWhenAllowed() {
        if monitor.start() { return }
        tapRetryTimer?.invalidate()
        tapRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            if self?.monitor.start() == true { timer.invalidate() }
        }
    }

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Trigger

    private func triggerPressed() {
        switch settings.triggerMode {
        case .toggle:
            switch state {
            case .idle: beginRecording()
            case .recording: finishRecording()
            case .processing: break
            }
        case .hold:
            if state == .idle {
                holdStartedAt = Date()
                beginRecording()
            }
        }
    }

    private func triggerReleased() {
        guard settings.triggerMode == .hold, state == .recording else { return }
        // A very short press is treated as an accidental click.
        if let started = holdStartedAt, Date().timeIntervalSince(started) < 0.3 {
            cancel()
        } else {
            finishRecording()
        }
    }

    /// Menu-bar "Start/Finish Dictation" item.
    func toggleFromMenu() {
        switch state {
        case .idle: beginRecording()
        case .recording: finishRecording()
        case .processing: break
        }
    }

    // MARK: - Flow

    func beginRecording() {
        guard state == .idle else { return }
        guard !settings.transcriptionKey.isEmpty else {
            hud.show(.message("Add your API keys in Spoke Settings"))
            SettingsWindow.show()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            return
        default:
            hud.show(.message("Allow microphone access in System Settings"))
            openPrivacyPane("Privacy_Microphone")
            return
        }

        do {
            try recorder.start()
        } catch {
            hud.show(.message(error.localizedDescription))
            return
        }
        setState(.recording)
        play("Tink")
        hud.model.elapsed = 0
        hud.show(.recording)
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.hud.model.level = self.recorder.level
            self.hud.model.elapsed = self.recorder.elapsed
            if self.recorder.elapsed >= Recorder.maxDuration { self.finishRecording() }
        }
    }

    func finishRecording() {
        guard state == .recording else { return }
        meterTimer?.invalidate()
        guard let (audio, duration) = recorder.stop() else { return reset() }
        play("Pop")
        if duration < 0.4 {
            hud.show(.message("Too short. Try again."))
            return reset()
        }
        setState(.processing)
        hud.show(.processing)

        work = Task { [weak self] in
            guard let self else { return }
            defer { try? FileManager.default.removeItem(at: audio) }
            do {
                let raw = try await Transcriber.transcribe(audio, settings: settings)
                guard !raw.isEmpty else {
                    await MainActor.run { self.hud.show(.message("Didn't catch anything")); self.reset() }
                    return
                }
                var text = raw
                var note: String?
                if settings.cleanupEnabled && !settings.anthropicKey.isEmpty {
                    do {
                        text = try await Cleaner.clean(raw, settings: settings)
                    } catch {
                        note = "Cleanup failed, inserted raw text"
                    }
                }
                try Task.checkCancellation()
                let result = text
                let warning = note
                await MainActor.run {
                    self.lastDictation = result
                    Inserter.insert(result)
                    if let warning { self.hud.show(.message(warning)) } else { self.hud.hide() }
                    self.reset()
                }
            } catch is CancellationError {
                await MainActor.run { self.reset() }
            } catch {
                await MainActor.run {
                    self.hud.show(.message(error.localizedDescription))
                    self.reset()
                }
            }
        }
    }

    func cancel() {
        meterTimer?.invalidate()
        work?.cancel()
        if state == .recording {
            if let (audio, _) = recorder.stop() { try? FileManager.default.removeItem(at: audio) }
            play("Funk")
        }
        hud.show(.message("Cancelled"))
        reset()
    }

    private func reset() {
        holdStartedAt = nil
        setState(.idle)
    }

    private func setState(_ new: State) {
        state = new
        onStateChange?(new)
    }

    func copyLastDictation() {
        guard let text = lastDictation else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func captureNextMouseButton() {
        capturingMouseButton = true
        monitor.captureMouseButton = { [weak self] button in
            self?.settings.mouseButton = button
            self?.settings.triggerKind = .mouseButton
            self?.capturingMouseButton = false
        }
    }

    func cancelMouseButtonCapture() {
        monitor.captureMouseButton = nil
        capturingMouseButton = false
    }

    func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func play(_ name: String) {
        guard settings.playSounds else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
