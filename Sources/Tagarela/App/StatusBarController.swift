import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Tagarela")
                ?? NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Tagarela")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Tagarela - Ditado e Transcrição"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // Cabeçalho
        let titleItem = NSMenuItem(title: "Tagarela", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Abrir Janela Principal
        let openItem = NSMenuItem(
            title: t("Abrir Tagarela", "Open Tagarela"),
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        // Alternar Ditado
        let dictateItem = NSMenuItem(
            title: t("Iniciar / Parar Ditado", "Start / Stop Dictation"),
            action: #selector(toggleDictation),
            keyEquivalent: "d"
        )
        dictateItem.target = self
        menu.addItem(dictateItem)

        // Ajustes
        let settingsItem = NSMenuItem(
            title: t("Ajustes...", "Settings..."),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle para ocultar sempre da Dock
        let isAlwaysHidden = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        let dockItem = NSMenuItem(
            title: t("Ocultar da Dock sempre", "Always hide from Dock"),
            action: #selector(toggleAlwaysHideFromDock),
            keyEquivalent: ""
        )
        dockItem.state = isAlwaysHidden ? .on : .off
        dockItem.target = self
        menu.addItem(dockItem)

        menu.addItem(NSMenuItem.separator())

        // Encerrar definitivamente
        let quitItem = NSMenuItem(
            title: t("Encerrar Tagarela definitivamente", "Quit Tagarela completely"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openMainWindow() {
        appDelegate?.showMainWindow()
    }

    @objc private func toggleDictation() {
        NotificationCenter.default.post(name: .tagarelaToggleDictation, object: nil)
    }

    @objc private func openSettings() {
        appDelegate?.showMainWindow()
        NotificationCenter.default.post(name: .tagarelaNavigate, object: NavSection.settings)
    }

    @objc private func toggleAlwaysHideFromDock() {
        let current = UserDefaults.standard.bool(forKey: "alwaysHideFromDock")
        let newValue = !current
        UserDefaults.standard.set(newValue, forKey: "alwaysHideFromDock")
        appDelegate?.updateActivationPolicy()
    }

    @objc private func quitApp() {
        appDelegate?.terminateCompletely()
    }
}
