import AppKit
import AVFoundation
import Combine
import ServiceManagement
import SwiftUI

enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Spoke Settings"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var controller = AppController.shared
    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityOn = AXIsProcessTrusted()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Permissions") {
                permissionRow(
                    "Microphone",
                    granted: micStatus == .authorized,
                    action: micStatus == .notDetermined ? "Allow" : "Open Settings"
                ) {
                    if micStatus == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else {
                        controller.openPrivacyPane("Privacy_Microphone")
                    }
                }
                permissionRow(
                    "Accessibility (for the trigger and typing)",
                    granted: accessibilityOn,
                    action: "Open Settings"
                ) {
                    controller.requestAccessibility()
                    controller.openPrivacyPane("Privacy_Accessibility")
                }
            }

            Section("Trigger") {
                Picker("Start dictation with", selection: $settings.triggerKind) {
                    ForEach(TriggerKind.allCases) { Text($0.label).tag($0) }
                }
                if settings.triggerKind == .mouseButton {
                    HStack {
                        Text(Settings.mouseButtonName(settings.mouseButton))
                        Spacer()
                        if controller.capturingMouseButton {
                            Text("Press the mouse button you want…").foregroundStyle(.orange)
                            Button("Cancel") { controller.cancelMouseButtonCapture() }
                        } else {
                            Button("Change…") { controller.captureNextMouseButton() }
                                .disabled(!accessibilityOn)
                        }
                    }
                }
                Picker("Mode", selection: $settings.triggerMode) {
                    ForEach(TriggerMode.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Play start and stop sounds", isOn: $settings.playSounds)
            }

            Section("Speech-to-text") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(Provider.allCases) { Text($0.label).tag($0) }
                }
                switch settings.provider {
                case .groq:
                    SecureField("Groq API key (console.groq.com)", text: $settings.groqKey)
                case .openai:
                    SecureField("OpenAI API key (platform.openai.com)", text: $settings.openaiKey)
                }
            }

            Section("Cleanup (Claude)") {
                Toggle("Remove filler words, fix punctuation, apply corrections", isOn: $settings.cleanupEnabled)
                SecureField("Anthropic API key (console.anthropic.com)", text: $settings.anthropicKey)
            }

            Section("Your vocabulary") {
                TextEditor(text: $settings.vocabulary)
                    .font(.body)
                    .frame(minHeight: 70)
                Text("Names and terms to spell correctly, one per line.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open Spoke at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 640)
        .onReceive(refresh) { _ in
            micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            accessibilityOn = AXIsProcessTrusted()
        }
    }

    private func permissionRow(_ title: String, granted: Bool, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
            Spacer()
            if !granted { Button(action, action: perform) }
        }
    }
}
