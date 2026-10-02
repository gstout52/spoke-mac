import AppKit

/// Menu-bar app: no Dock icon, just a mic in the menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let controller = AppController.shared
    private let toggleItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")
    private let copyItem = NSMenuItem(title: "Copy Last Dictation", action: #selector(copyLast), keyEquivalent: "")
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(.idle)

        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem.target = self
        copyItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(copyItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit Spoke", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        controller.onStateChange = { [weak self] state in self?.updateIcon(state) }
        controller.start()

        let settings = Settings.shared
        if !AXIsProcessTrusted() || settings.transcriptionKey.isEmpty {
            SettingsWindow.show()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let settings = Settings.shared
        let trigger = settings.triggerKind == .mouseButton
            ? Settings.mouseButtonName(settings.mouseButton).lowercased()
            : settings.triggerKind.label
        statusLine.title = AXIsProcessTrusted()
            ? "Dictate with the \(trigger)"
            : "Needs Accessibility permission"
        toggleItem.title = controller.state == .recording ? "Finish Dictation" : "Start Dictation"
        toggleItem.isEnabled = controller.state != .processing
        copyItem.isEnabled = controller.lastDictation != nil
    }

    private func updateIcon(_ state: AppController.State) {
        guard let button = statusItem.button else { return }
        let symbol: String
        switch state {
        case .idle: symbol = "mic"
        case .recording: symbol = "mic.fill"
        case .processing: symbol = "ellipsis.circle"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Spoke")
        button.contentTintColor = state == .recording ? .systemRed : nil
    }

    @objc private func toggleDictation() { controller.toggleFromMenu() }
    @objc private func copyLast() { controller.copyLastDictation() }
    @objc private func openSettings() { SettingsWindow.show() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
